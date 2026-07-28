#!/usr/bin/env python3
"""Contour-fidelity verification for the "no simplification at all" policy
(product decision, 2026-07-28; replaces the earlier `verify_simplification.py`,
which only checked that a simplification tolerance was not *too* aggressive --
a check that no longer makes sense now that contour lines are not simplified
at all).

Developer-run tool, like `build_mbtiles.py` itself -- never invoked by the
application. Run this after any future re-run of `build_mbtiles.py` to
confirm contour lines in the built MBTiles still carry full source fidelity,
not a silently reintroduced simplification step.

What this proves, precisely, not just approximately:

For a representative contour feature at each known test location, and at
each tiled zoom, this script independently recomputes exactly what the
production pipeline's own two permitted transformations -- (1) clipping a
feature to one tile's bounds via `shapely` `intersection`, and (2) the MVT
format's own mandatory quantization to its 4096-unit tile-local integer
grid, replicated here bit-for-bit from `mapbox_vector_tile`'s own encoder
(see `_quantize_and_dedup` below) -- would produce for that feature, and
compares the result **exactly** (vertex-for-vertex, not just by count)
against what is actually present in the built `.mbtiles` file.

An exact match proves clipping + quantization are the *only* source of any
difference between the raw source geometry and the encoded tile -- i.e.
that no Douglas-Peucker or any other shape-altering simplification was
applied anywhere in between. A mismatch is a real regression: either a
simplification step was reintroduced, or the pipeline's clip/encode
behavior changed in some other way this script does not yet account for --
either way, investigate before trusting the built asset.

Test locations (TD-027 addendum, 2026-07-28 product decision to remove all
contour simplification): Kymijärvi, Kärkjärvi, Mallusjärvi, one dense Saimaa
area (Haukivesi), one Päijänne area (Salosvesi-Pettämä), one small lake
(Pieni Saarijärvi). Chosen from real `EL.Syvyysalue` `syvmittausaluenimi`
survey-area names in the cached national WFS data, not arbitrary points.

Usage:
    python verify_contour_fidelity.py [path/to/syke_bathymetry_v1.mbtiles]

Requires a warm `.cache/` (the same one `build_mbtiles.py` itself reads) --
this script loads and normalizes the raw source data itself, independently
of whatever happened to already run.
"""

from __future__ import annotations

import glob
import json
import os
import sqlite3
import sys

import mapbox_vector_tile
from shapely.geometry import box as shapely_box

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_mbtiles import (  # noqa: E402
    ZOOMS,
    fetch_all_features,
    join_contours_to_lakes,
    normalize_areas,
    normalize_contours,
    tile_bounds_lonlat,
    tile_range_for_bounds,
)

DEFAULT_MBTILES = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "..",
    "assets",
    "syke_bathymetry",
    "syke_bathymetry_v1.mbtiles",
)

EXTENTS = 4096

# Real `jarvitunnus` values for six test locations, resolved directly from
# `EL.Syvyysalue`'s own `syvmittausaluenimi` (survey-area name) field in the
# cached national WFS response -- not guessed coordinates. See this
# project's own investigation notes for how each was found.
TEST_LOCATIONS = {
    "Kymijarvi": "14.164.1.001",
    "Karkjarvi": "14.163.1.013",
    "Mallusjarvi": "18.033.1.001",
    "Saimaa (Haukivesi, dense)": "04.211.1.001",
    "Paijanne (Salosvesi-Pettama)": "14.523.1.001",
    "Small lake (Pieni Saarijarvi)": "01.043.1.012",
}


def log(message: str) -> None:
    print(f"[verify_fidelity] {message}", flush=True)


def load_target_contours() -> list[dict]:
    """Loads and normalizes the full national contour dataset, but joins it
    only against the small subset of `Syvyysalue` polygons belonging to our
    six named test locations -- correct (the join is a spatial
    intersection test, unaffected by which subset of areas is offered) and
    far cheaper than building a national-scale STRtree for a verification
    run that only cares about six lakes.
    """
    contour_raw = fetch_all_features("inspire_el:EL.ContourLine", "contourline")
    area_raw = fetch_all_features("inspire_el:EL.Syvyysalue", "syvyysalue")
    contours = normalize_contours(contour_raw)
    areas = normalize_areas(area_raw)

    target_ids = set(TEST_LOCATIONS.values())
    areas_subset = [a for a in areas if a["jarvitunnus"] in target_ids]
    log(f"{len(areas_subset)} Syvyysalue polygons belong to the six test locations")

    join_contours_to_lakes(contours, areas_subset)
    matched = [c for c in contours if c["jarvitunnus"] in target_ids]
    log(f"{len(matched)} contour features matched a test-location lake")
    return matched


def vertex_count(geom) -> int:
    if geom.geom_type == "LineString":
        return len(geom.coords)
    if geom.geom_type == "MultiLineString":
        return sum(len(part.coords) for part in geom.geoms)
    return 0


def is_closed_ring(geom) -> bool:
    if geom.geom_type == "LineString":
        coords = list(geom.coords)
        return len(coords) > 2 and coords[0] == coords[-1]
    if geom.geom_type == "MultiLineString":
        return any(
            len(part.coords) > 2 and part.coords[0] == part.coords[-1]
            for part in geom.geoms
        )
    return False


def pick_representative_features(contours: list[dict], jarvitunnus: str) -> list[tuple[str, dict]]:
    """Picks up to two representative raw features for one test location:
    the feature with the most vertices ("largest/most complex contour",
    likely to span several tiles at high zoom -- exercises the clipping
    path), and, if one exists, the *smallest* closed ring ("small ring
    fidelity" -- direct descendant of the original Kymijärvi 10m/15m
    regression check this script replaces).

    No uniqueness requirement on `(jarvitunnus, depth_m)` -- large, complex
    lake systems (Saimaa, Mallusjärvi) routinely have several disjoint
    contour segments sharing the same depth value, and skipping those
    locations entirely would defeat the point of testing them. Matching a
    picked feature back to its encoded counterpart instead uses an exact
    geometric fingerprint (see `verify_feature`/`predicted_encoded_points`)
    -- the *coordinates* a feature clips+quantizes to are what identify it,
    not its properties, so duplicate-attribute siblings are a non-issue.
    """
    at_lake = [c for c in contours if c["jarvitunnus"] == jarvitunnus]
    if not at_lake:
        return []

    picks: list[tuple[str, dict]] = []
    largest = max(at_lake, key=lambda c: vertex_count(c["geom"]))
    picks.append(("largest/most-complex", largest))

    closed = [c for c in at_lake if is_closed_ring(c["geom"])]
    if closed:
        smallest_ring = min(closed, key=lambda c: vertex_count(c["geom"]))
        if smallest_ring is not largest:
            picks.append(("smallest closed ring", smallest_ring))
    return picks


def _quantize_and_dedup(coords: list[tuple[float, float]], tb: tuple[float, float, float, float]) -> list[tuple[int, int]]:
    """Bit-for-bit replica of `mapbox_vector_tile`'s own
    `VectorTile.quantize` (linear scale + round to the 4096-unit tile-local
    integer grid) followed by `GeometryEncoder.encode_arc`'s own
    consecutive-duplicate-point drop (a point is only ever dropped there
    when it quantizes to the exact same integer cell as the immediately
    preceding *kept* point -- never because of shape simplification).

    `GeometryEncoder.coords_on_grid` additionally flips y (`extents - y`,
    since production encodes with `y_coord_down=False`) before storing each
    delta -- but `mapbox_vector_tile.decode()` (also `y_coord_down=False`
    by default) un-flips it right back on the way out, so the values this
    script ultimately compares against are the *pre-flip* `quantize()`
    output, not the flipped, on-the-wire value. The flip is applied and
    undone entirely inside the library's own round trip; reproducing it
    here would only reintroduce a mismatch decode() itself never exposes.
    (The dedup rule is unaffected either way -- flipping is a bijection, so
    two points collide post-flip iff they already collided pre-flip.)
    """
    minx, miny, maxx, maxy = tb
    xfac = EXTENTS / (maxx - minx)
    yfac = EXTENTS / (maxy - miny)

    out: list[tuple[int, int]] = []
    for lon, lat in coords:
        x = round(xfac * (lon - minx))
        y = round(yfac * (lat - miny))
        if out and out[-1] == (x, y):
            continue
        out.append((x, y))
    return out


def predicted_encoded_points(raw_geom, tb: tuple[float, float, float, float]) -> list[tuple[int, int]]:
    """The exact tile-local integer points production would encode for
    `raw_geom` once clipped to tile bounds `tb` -- clip first (identical
    `shapely` call to `build_mbtiles.build_mbtiles`'s own tiling loop),
    then quantize+dedup (identical to `mapbox_vector_tile`'s own encoder).
    """
    tile_poly = shapely_box(*tb)
    clipped = raw_geom.intersection(tile_poly)
    if clipped.is_empty:
        return []

    points: list[tuple[int, int]] = []
    if clipped.geom_type == "LineString":
        points.extend(_quantize_and_dedup(list(clipped.coords), tb))
    elif clipped.geom_type == "MultiLineString":
        for part in clipped.geoms:
            points.extend(_quantize_and_dedup(list(part.coords), tb))
    # GeometryCollection / Point slivers from a near-tangent clip contribute
    # no line vertices and are correctly ignored, exactly as production's
    # own `mapbox_vector_tile.encode` call does for any non-line geometry.
    return points


def decoded_candidate_features(
    mbtiles_path: str, z: int, tx: int, ty: int, jarvitunnus: str, depth_m: float
) -> list[list[tuple[int, int]]]:
    """Each encoded `contours` feature at `(z, tx, ty)` whose properties
    match `(jarvitunnus, depth_m)`, as one pooled tile-local point list per
    feature (matching `predicted_encoded_points`'s own coordinate space and
    per-feature pooling of multi-part geometry).

    Property matching is only a cheap pre-filter here, not the actual
    identity check -- a busy lake can have several disjoint raw contour
    segments sharing one depth value, so more than one candidate can come
    back for the same `(jarvitunnus, depth_m)`. `verify_feature` decides
    identity the strict way: by testing each candidate's own exact
    coordinate set against this script's independently clip+quantize
    predicted set for the one specific raw feature being checked.
    """
    conn = sqlite3.connect(mbtiles_path)
    tms_y = (2**z - 1) - ty
    row = conn.execute(
        "SELECT tile_data FROM tiles WHERE zoom_level=? AND tile_column=? AND tile_row=?",
        (z, tx, tms_y),
    ).fetchone()
    conn.close()
    if row is None:
        return []

    decoded = mapbox_vector_tile.decode(row[0])
    contours = decoded.get("contours", {}).get("features", [])
    candidates: list[list[tuple[int, int]]] = []
    for f in contours:
        props = f["properties"]
        if props.get("jarvitunnus") != jarvitunnus:
            continue
        if props.get("depth_m") != depth_m:
            continue
        geom = f["geometry"]
        pooled: list[tuple[int, int]] = []
        if geom["type"] == "LineString":
            pooled.extend(tuple(pt) for pt in geom["coordinates"])
        elif geom["type"] == "MultiLineString":
            for part in geom["coordinates"]:
                pooled.extend(tuple(pt) for pt in part)
        candidates.append(pooled)
    return candidates


def verify_feature(mbtiles_path: str, label: str, jarvitunnus: str, feat: dict) -> int:
    geom = feat["geom"]
    depth_m = feat["depth_m"]
    raw_vertices = vertex_count(geom)
    closed = is_closed_ring(geom)
    minx, miny, maxx, maxy = geom.bounds

    print(
        f"  [{label}] depth_m={depth_m} raw_vertices={raw_vertices} "
        f"closed_ring={closed} bounds=({minx:.5f},{miny:.5f},{maxx:.5f},{maxy:.5f})"
    )

    failures = 0
    for z in ZOOMS:
        x0, y0, x1, y1 = tile_range_for_bounds(minx, miny, maxx, maxy, z)
        tile_count = (x1 - x0 + 1) * (y1 - y0 + 1)

        predicted_total = 0
        actual_total = 0
        exact_match = True
        tiles_with_data = 0

        for tx in range(x0, x1 + 1):
            for ty in range(y0, y1 + 1):
                tb = tile_bounds_lonlat(z, tx, ty)
                predicted = predicted_encoded_points(geom, tb)
                if not predicted:
                    continue
                tiles_with_data += 1
                predicted_total += len(predicted)
                predicted_sorted = sorted(predicted)

                candidates = decoded_candidate_features(
                    mbtiles_path, z, tx, ty, jarvitunnus, depth_m
                )
                # This exact raw feature is proven present in this tile iff
                # at least one candidate's own coordinate set is an exact,
                # vertex-for-vertex match (sorted first: production may
                # split one clipped LineString into a MultiLineString whose
                # part order is not guaranteed to match this script's own
                # single predicted sequence one-for-one, but the *set* of
                # tile-local points actually drawn must still match exactly
                # either way) -- other candidates sharing the same
                # (jarvitunnus, depth_m) are simply different raw features
                # and are expected not to match.
                match = next(
                    (c for c in candidates if sorted(c) == predicted_sorted), None
                )
                if match is None:
                    exact_match = False
                    actual_total += max((len(c) for c in candidates), default=0)
                else:
                    actual_total += len(match)

        status = "OK" if exact_match else "MISMATCH"
        print(
            f"    z{z}: candidate_tiles={tile_count} tiles_with_data={tiles_with_data} "
            f"predicted_encoded_vertices={predicted_total} "
            f"actual_encoded_vertices={actual_total} [{status}]"
        )
        if not exact_match:
            failures += 1
            print(
                "      FAIL: actual encoded points differ from the exact "
                "clip+quantize prediction -- a transformation beyond "
                "clipping/quantization is being applied somewhere"
            )

    return failures


def main() -> int:
    mbtiles_path = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_MBTILES)
    if not os.path.exists(mbtiles_path):
        log(f"ERROR: {mbtiles_path} does not exist")
        return 1
    log(f"Verifying against {mbtiles_path}")

    contours = load_target_contours()

    total_failures = 0
    for name, jarvitunnus in TEST_LOCATIONS.items():
        print(f"\n=== {name} (jarvitunnus={jarvitunnus}) ===")
        picks = pick_representative_features(contours, jarvitunnus)
        if not picks:
            print("  NOTE: no unambiguously-matchable feature found; skipped")
            continue
        for label, feat in picks:
            total_failures += verify_feature(mbtiles_path, label, jarvitunnus, feat)

    print()
    if total_failures:
        print(
            f"{total_failures} check(s) FAILED -- unsimplified-contour fidelity "
            f"could not be proven for at least one feature/zoom. Investigate "
            f"before trusting this asset; do not silently reintroduce "
            f"simplification to make this pass."
        )
        return 1

    print("All checks passed: every sampled contour feature is encoded with "
          "exactly the vertices clipping + MVT quantization predict -- no "
          "additional simplification is being applied anywhere in the "
          "pipeline.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
