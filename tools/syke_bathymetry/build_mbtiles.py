#!/usr/bin/env python3
"""SYKE lake/river bathymetry -> national MBTiles pipeline (TD-027 §20/§21).

Developer-run tool. Never invoked by the application at build time or
runtime — the application only ever reads the finished, bundled
`assets/syke_bathymetry/syke_bathymetry_v1.mbtiles` file
(`SykeBathymetryTileSource`), fully offline. There is no live SYKE WFS call
anywhere in the running app.

What this does, in order:
  1. Fetch the complete, authoritative national `EL.ContourLine` and
     `EL.Syvyysalue` datasets from SYKE's public WFS 2.0.0 service
     (paginated; cached locally so a re-run/resume does not always
     re-download everything).
  2. Normalize Finnish-locale decimal-comma numeric fields to floats
     (`syvyyskayra_m`, `syvyysvali_m`), classify `Syvyysalue` polygons into
     real depth-range vs. island/"Saari" land-inclusion, and drop records
     with no usable depth value (a small, real fraction of `ContourLine` —
     confirmed ~1.3% in the source data, not a pipeline defect).
  3. Spatially join each contour line to its containing `Syvyysalue`
     polygon's `jarvitunnus`, for QA and attribute enrichment
     (`ContourLine` itself carries no lake-identifying attribute at all).
  4. Tile both layers (`depth_areas`, `contours`) into a single national
     MBTiles file at the production zoom range (a contiguous z10-z14, no
     gaps -- TD-027 §20/§22: whole-country z6/z8/z9 are dropped since the
     presentation layer itself never renders below z10, and every integer
     zoom in the tiled range must actually have data, or MapLibre's own
     vector-source tile requests at a "gap" zoom render as empty).
     Contour-line features are NOT simplified at all (product decision,
     2026-07-28: physical Android testing found even the earlier
     size-aware adaptive tolerance still visibly too angular -- accuracy
     and visual fidelity take priority over asset size for this layer).
     Each contour is tiled at its full, original `EL.ContourLine` vertex
     precision; the only geometry transformation applied is clipping to
     each tile's own bounds (required to produce valid, bounded vector
     tiles) and the MVT format's own mandatory coordinate quantization to
     its 4096-unit tile-local integer grid (an MVT-spec requirement, not a
     simplification choice -- see `build_mbtiles`'s own comment at the
     tiling loop for the full reasoning). Depth-area polygons keep their
     existing flat per-zoom simplification, unchanged and untouched by
     this decision -- their fill layer is not even part of the current map
     presentation.

Usage:
    pip install -r requirements.txt
    python build_mbtiles.py [--output ../../assets/syke_bathymetry/syke_bathymetry_v1.mbtiles]

Refreshing the dataset later: simply re-run this script. SYKE's underlying
data changes infrequently; there is no scheduled/automatic refresh -- a
refresh is a deliberate, developer-run action, followed by committing the
regenerated `.mbtiles` file and bumping `SykeBathymetryTileSource
.defaultAssetFileName`'s version suffix (e.g. `_v1` -> `_v2`) if the schema
or attribute shape of this script's own output ever changes, so a stale
extracted copy from a previous app version is never silently reused (see
`SykeBathymetryTileSource`'s own doc comment). Delete `.cache/` first to
force a fully fresh WFS re-fetch rather than reusing a previous run's cached
pages.

Not run as part of `flutter analyze`/`flutter test`/CI -- this is a Python,
developer-machine tool, entirely separate from the Flutter app's own build.
"""

from __future__ import annotations

import argparse
import glob
import hashlib
import json
import math
import os
import re
import sqlite3
import sys
import time
from collections import defaultdict

import requests
from shapely.geometry import box as shapely_box
from shapely.geometry import shape
from shapely.strtree import STRtree

WFS_BASE = "https://paikkatiedot.ymparisto.fi/geoserver/inspire_el/wfs"
PAGE_SIZE = 5000

# Production zoom range (TD-027 §20/§22, revised after physical Android
# testing -- root-cause bug fix, not a stylistic choice).
#
# MUST be a CONTIGUOUS run of every integer zoom from the presentation
# layer's own minzoom (`WorldwideStyleFactory.sykeBathymetryPresentationMinZoom`,
# currently 10) through the highest zoom actually tiled. The original
# prototype-derived range ([8, 10, 12, 14], skipping every odd level) looked
# reasonable on paper but is a real bug: MapLibre vector sources request a
# tile at *every* integer zoom within the source's declared
# [minzoom, maxzoom], not merely at whichever zooms happen to have data --
# there is no "sparse pyramid" concept in the vector tile source spec.
# Physical testing confirmed exactly this: contours flickered in and out
# while zooming continuously, present at z10/12/14 and genuinely empty at
# z11/z13 (verified directly: `SELECT DISTINCT zoom_level FROM tiles`
# against the previously-shipped asset returned only 8/10/12/14, confirming
# no row exists at the skipped levels -- not a rendering artifact).
#
# z8/z9 are intentionally NOT tiled: the presentation layer's own minzoom
# (10) means MapLibre never renders (or needs to fetch) this source below
# z10 at all, regardless of what the source's own minzoom/maxzoom declare --
# tiling zooms that can never be shown would only cost build time and file
# size for zero product benefit.
#
# Nothing is tiled beyond z14: SYKE's underlying survey/contour precision
# does not have meaningfully more real detail to reveal at finer zooms (the
# z14 tiles were already the most heavily simplified in the original
# prototype build), so tiling all the way to z18 would mostly re-slice the
# same z14-level geometry into many more, smaller physical tiles for no
# real informational gain -- a materially worse size/robustness trade than
# relying on MapLibre's own standard, style-spec-guaranteed vector overzoom
# behavior above the source's declared maxzoom (a real tile at or below
# maxzoom is reused/reprojected for the closer zoom, entirely client-side,
# no additional tile request or server-side data needed) -- see
# `WorldwideStyleFactory`'s own doc comment for the full reasoning.
ZOOMS = [10, 11, 12, 13, 14]

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CACHE_DIR = os.path.join(SCRIPT_DIR, ".cache")
DEFAULT_OUTPUT = os.path.join(
    SCRIPT_DIR, "..", "..", "assets", "syke_bathymetry", "syke_bathymetry_v1.mbtiles"
)


def log(message: str) -> None:
    print(f"[syke_bathymetry] {message}", flush=True)


# ---------------------------------------------------------------------------
# 1. Fetch (paginated WFS, cached locally per page for resumability)
# ---------------------------------------------------------------------------


def fetch_all_features(type_name: str, cache_subdir: str) -> list[dict]:
    cache_path = os.path.join(CACHE_DIR, cache_subdir)
    os.makedirs(cache_path, exist_ok=True)

    features: list[dict] = []
    page = 0
    start = 0
    total = None

    while True:
        page_file = os.path.join(cache_path, f"page_{page}.json")
        if os.path.exists(page_file):
            with open(page_file, encoding="utf-8") as f:
                data = json.load(f)
            log(f"{type_name}: page {page} (cached, startIndex={start})")
        else:
            params = {
                "service": "WFS",
                "version": "2.0.0",
                "request": "GetFeature",
                "typeNames": type_name,
                "outputFormat": "application/json",
                "srsName": "EPSG:4326",
                "count": PAGE_SIZE,
                "startIndex": start,
            }
            response = requests.get(WFS_BASE, params=params, timeout=90)
            response.raise_for_status()
            data = response.json()
            with open(page_file, "w", encoding="utf-8") as f:
                json.dump(data, f)
            log(
                f"{type_name}: page {page} fetched (startIndex={start}, "
                f"returned={len(data['features'])})"
            )

        total = data.get("totalFeatures")
        n = len(data["features"])
        features.extend(data["features"])
        page += 1
        start += PAGE_SIZE
        if n < PAGE_SIZE or (total is not None and len(features) >= total):
            break

    log(f"{type_name}: {len(features)} features fetched (server total: {total})")
    return features


# ---------------------------------------------------------------------------
# 2. Normalize
# ---------------------------------------------------------------------------


def parse_finnish_decimal(raw: str | None):
    """Returns (kind, lo, hi). kind is 'single' | 'range' | 'island' | 'none'."""
    if raw is None:
        return ("none", None, None)
    s = raw.strip()
    if s.lower() == "saari":
        return ("island", None, None)
    if "-" in s:
        parts = s.split("-")
        if len(parts) == 2:
            return ("range", float(parts[0].replace(",", ".")), float(parts[1].replace(",", ".")))
    return ("single", float(s.replace(",", ".")), float(s.replace(",", ".")))


def normalize_contours(raw_features: list[dict]) -> list[dict]:
    out = []
    dropped = 0
    for f in raw_features:
        props = f["properties"]
        raw_val = props.get("syvyyskayra_m")
        try:
            kind, lo, _hi = parse_finnish_decimal(raw_val)
        except Exception:
            dropped += 1
            continue
        if kind != "single":
            # Missing value ("none") or, unexpectedly, an island/range marker
            # on a contour line -- not usable as a depth value either way.
            dropped += 1
            continue
        try:
            geom = shape(f["geometry"])
        except Exception:
            dropped += 1
            continue
        out.append({"geom": geom, "depth_m": lo, "objectid": props.get("objectid")})
    log(f"ContourLine: {len(out)} usable, {dropped} dropped (no/unparsable depth value)")
    return out


def normalize_areas(raw_features: list[dict]) -> list[dict]:
    out = []
    dropped = 0
    kinds: dict[str, int] = defaultdict(int)
    for f in raw_features:
        props = f["properties"]
        raw_val = props.get("syvyysvali_m")
        try:
            kind, lo, hi = parse_finnish_decimal(raw_val)
        except Exception:
            dropped += 1
            continue
        kinds[kind] += 1
        try:
            geom = shape(f["geometry"])
            if not geom.is_valid:
                geom = geom.buffer(0)
        except Exception:
            dropped += 1
            continue
        out.append(
            {
                "geom": geom,
                "depth_kind": kind,
                "depth_min": lo,
                "depth_max": hi,
                "luokka": props.get("luokka"),
                "jarvitunnus": props.get("jarvitunnus"),
                "objectid": props.get("objectid"),
            }
        )
    log(f"Syvyysalue: {len(out)} usable, {dropped} dropped -- kinds: {dict(kinds)}")
    return out


# ---------------------------------------------------------------------------
# 3. Spatial join (QA + jarvitunnus enrichment for ContourLine)
# ---------------------------------------------------------------------------


def join_contours_to_lakes(contours: list[dict], areas: list[dict]) -> None:
    """Mutates each contour dict in place, adding a 'jarvitunnus' key."""
    tree = STRtree([a["geom"] for a in areas])
    joined = 0
    for c in contours:
        candidates = tree.query(c["geom"])
        match = None
        for idx in candidates:
            if areas[idx]["geom"].intersects(c["geom"]):
                match = areas[idx]["jarvitunnus"]
                break
        c["jarvitunnus"] = match
        if match:
            joined += 1
    log(
        f"Spatial join: {joined}/{len(contours)} contours matched a lake "
        f"({100 * joined / max(len(contours), 1):.1f}%)"
    )


# ---------------------------------------------------------------------------
# 4. Tile
# ---------------------------------------------------------------------------


def tile_range_for_bounds(minx, miny, maxx, maxy, z):
    n = 2**z

    def lon_to_x(lon):
        return int((lon + 180.0) / 360.0 * n)

    def lat_to_y(lat):
        lat = max(min(lat, 85.05112878), -85.05112878)
        lat_rad = math.radians(lat)
        return int((1.0 - math.log(math.tan(lat_rad) + 1 / math.cos(lat_rad)) / math.pi) / 2.0 * n)

    x0, x1 = lon_to_x(minx), lon_to_x(maxx)
    y0, y1 = lat_to_y(maxy), lat_to_y(miny)
    return max(0, x0), max(0, y0), min(n - 1, x1), min(n - 1, y1)


def tile_bounds_lonlat(z, x, y):
    n = 2**z

    def x_to_lon(xx):
        return xx / n * 360.0 - 180.0

    def y_to_lat(yy):
        yv = 1.0 - 2.0 * yy / n
        return math.degrees(math.atan(math.sinh(math.pi * yv)))

    return (x_to_lon(x), y_to_lat(y + 1), x_to_lon(x + 1), y_to_lat(y))


def build_mbtiles(contours: list[dict], areas: list[dict], output_path: str) -> dict:
    import mapbox_vector_tile

    if os.path.exists(output_path):
        os.remove(output_path)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    conn = sqlite3.connect(output_path)
    conn.execute("CREATE TABLE metadata (name TEXT, value TEXT)")
    conn.execute(
        "CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, "
        "tile_row INTEGER, tile_data BLOB)"
    )
    conn.execute("CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row)")
    conn.executemany(
        "INSERT INTO metadata VALUES (?, ?)",
        [
            ("name", "syke_bathymetry_v1"),
            ("format", "pbf"),
            ("minzoom", str(min(ZOOMS))),
            ("maxzoom", str(max(ZOOMS))),
            ("type", "overlay"),
            ("description", "SYKE lake/river bathymetry (contours + depth areas)"),
            ("attribution", "SYKE - Jarvien ja jokien syvyysaineisto (CC BY 4.0)"),
        ],
    )
    conn.commit()

    stats = {"zooms": {}}
    total_t0 = time.time()

    for z in ZOOMS:
        zt0 = time.time()
        span_deg = 360.0 / (2**z)
        tolerance = span_deg / 256.0

        buckets = defaultdict(list)
        for c in contours:
            # No simplification at all (product decision, 2026-07-28):
            # `c["geom"]` is used exactly as normalized from the source
            # WFS response, at every zoom -- the only transformation
            # applied to a contour line, anywhere in this pipeline, is the
            # per-tile clip below (`g.intersection(tile_poly)`), which is
            # required to bound the feature to its tile at all and is not
            # a shape simplification.
            g = c["geom"]
            if g.is_empty:
                continue
            minx, miny, maxx, maxy = g.bounds
            x0, y0, x1, y1 = tile_range_for_bounds(minx, miny, maxx, maxy, z)
            for tx in range(x0, x1 + 1):
                for ty in range(y0, y1 + 1):
                    buckets[(tx, ty)].append(("contour", c, g))

        # Depth-area polygon simplification is deliberately unchanged --
        # not implicated in the confirmed contour-ring defect, and their
        # fill layer is not even part of the current map presentation
        # (WorldwideStyleFactory), so refining it further has no visible
        # benefit and would only grow the asset for no reason.
        for a in areas:
            g = a["geom"].simplify(tolerance, preserve_topology=True)
            if g.is_empty:
                continue
            minx, miny, maxx, maxy = g.bounds
            x0, y0, x1, y1 = tile_range_for_bounds(minx, miny, maxx, maxy, z)
            for tx in range(x0, x1 + 1):
                for ty in range(y0, y1 + 1):
                    buckets[(tx, ty)].append(("area", a, g))

        tiles_written = 0
        total_bytes = 0
        for (tx, ty), items in buckets.items():
            tb = tile_bounds_lonlat(z, tx, ty)
            tile_poly = shapely_box(*tb)
            contour_feats, area_feats = [], []
            for kind, feat, g in items:
                clipped = g.intersection(tile_poly)
                if clipped.is_empty:
                    continue
                if kind == "contour":
                    contour_feats.append(
                        {
                            "geometry": clipped,
                            "properties": {
                                "depth_m": feat["depth_m"],
                                "jarvitunnus": feat.get("jarvitunnus") or "",
                            },
                        }
                    )
                else:
                    area_feats.append(
                        {
                            "geometry": clipped,
                            "properties": {
                                "depth_kind": feat["depth_kind"],
                                "depth_min": feat["depth_min"] if feat["depth_min"] is not None else -1,
                                "depth_max": feat["depth_max"] if feat["depth_max"] is not None else -1,
                                "luokka": feat["luokka"] if feat["luokka"] is not None else -1,
                                "jarvitunnus": feat.get("jarvitunnus") or "",
                            },
                        }
                    )
            if not contour_feats and not area_feats:
                continue

            layers = []
            if area_feats:
                layers.append({"name": "depth_areas", "features": area_feats})
            if contour_feats:
                layers.append({"name": "contours", "features": contour_feats})

            try:
                encoded = mapbox_vector_tile.encode(
                    layers, default_options={"quantize_bounds": tb, "extents": 4096}
                )
            except Exception as e:
                log(f"  ENCODE FAIL z{z} {tx},{ty}: {e}")
                continue

            tms_y = (2**z - 1) - ty
            conn.execute(
                "INSERT INTO tiles (zoom_level, tile_column, tile_row, tile_data) "
                "VALUES (?,?,?,?)",
                (z, tx, tms_y, sqlite3.Binary(encoded)),
            )
            tiles_written += 1
            total_bytes += len(encoded)

        conn.commit()
        dt = time.time() - zt0
        stats["zooms"][z] = {"tiles": tiles_written, "bytes": total_bytes, "seconds": dt}
        log(
            f"z{z}: {tiles_written} tiles, {total_bytes / 1024 / 1024:.2f} MB, "
            f"{dt:.1f}s"
        )

    conn.close()
    stats["total_seconds"] = time.time() - total_t0
    stats["output_bytes"] = os.path.getsize(output_path)
    return stats


def write_version_sidecar(output_path: str) -> str:
    """Writes a small sidecar file next to the MBTiles output --
    `<output_path>.version`, plain text, containing only the file's own
    SHA-256 hex digest -- the dataset-version identifier
    `SykeBathymetryTileSource` compares against a previously-extracted
    copy's own sidecar to detect that the bundled asset has changed,
    *without* hashing the full ~70 MB file on every app launch (the fix for
    the confirmed stale-extracted-copy bug: the app only ever compares two
    short strings; the actual hashing happens once, here, at build time).

    Deterministic and content-derived, not hand-maintained: this project's
    prior filename-based versioning convention
    (`SykeBathymetryTileSource.defaultAssetFileName`'s `_v1` suffix) is
    correct for *schema* changes but requires a developer to remember to
    bump it -- exactly the kind of manual step that did not happen across
    two real content-changing rebuilds (the contiguous-pyramid fix, then
    the size-aware-simplification fix), which is how a physical device
    ended up silently reusing a stale, pre-fix extracted copy. A hash of
    the real output bytes cannot be forgotten to update: it is always
    correct for whatever bytes actually shipped. Because it is a pure
    function of the file's own content, a rebuild that happens to produce
    byte-identical output also produces an unchanged sidecar, so it never
    causes a spurious re-extraction on a device that already has the
    current content.

    Automatically bundled as a Flutter asset with no extra `pubspec.yaml`
    entry needed: `assets/syke_bathymetry/` is already listed as a whole
    directory.
    """
    h = hashlib.sha256()
    with open(output_path, "rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    digest = h.hexdigest()
    sidecar_path = output_path + ".version"
    with open(sidecar_path, "w", encoding="utf-8") as f:
        f.write(digest)
    log(f"Wrote version sidecar: {sidecar_path}")
    log(f"  sha256={digest}")
    return digest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--write-version-only",
        action="store_true",
        help=(
            "Skip fetch/normalize/join/tile entirely and only (re)write the "
            "`.version` sidecar for the MBTiles file already at --output. "
            "Use this to bring an existing, already-correct MBTiles file "
            "(one that does not itself need to change) up to date with the "
            "version-sidecar mechanism, without spending 10-20 minutes "
            "re-running the full national build for no content change."
        ),
    )
    args = parser.parse_args()

    output_path = os.path.abspath(args.output)

    if args.write_version_only:
        if not os.path.exists(output_path):
            log(f"ERROR: --write-version-only given but {output_path} does not exist.")
            return 1
        write_version_sidecar(output_path)
        return 0

    log("Fetching EL.ContourLine (national)...")
    contour_raw = fetch_all_features("inspire_el:EL.ContourLine", "contourline")
    log("Fetching EL.Syvyysalue (national)...")
    area_raw = fetch_all_features("inspire_el:EL.Syvyysalue", "syvyysalue")

    contours = normalize_contours(contour_raw)
    areas = normalize_areas(area_raw)

    join_contours_to_lakes(contours, areas)

    log(f"Building MBTiles at {output_path} (zooms {ZOOMS})...")
    stats = build_mbtiles(contours, areas, output_path)

    log("Done.")
    log(f"  Total build time: {stats['total_seconds']:.1f}s")
    log(f"  Output size: {stats['output_bytes'] / 1024 / 1024:.2f} MB")
    for z, zs in stats["zooms"].items():
        log(f"  z{z}: {zs['tiles']} tiles, {zs['bytes'] / 1024 / 1024:.2f} MB")

    write_version_sidecar(output_path)

    return 0


if __name__ == "__main__":
    sys.exit(main())
