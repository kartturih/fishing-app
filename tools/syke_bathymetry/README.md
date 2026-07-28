# SYKE Bathymetry MBTiles Pipeline

Developer-run, offline data-preparation tool for the SYKE lake/river
bathymetry overlay (MFS-027 Revision 7 / TD-027 §20/§21). Produces
`assets/syke_bathymetry/syke_bathymetry_v1.mbtiles`, the single bundled
asset the application reads at runtime through `SykeBathymetryTileSource` —
entirely offline, with no live SYKE WFS call anywhere in the running app.

**This tool is never run by the app, by `flutter analyze`/`flutter test`, or
by CI.** It is a plain Python script, run by hand on a developer machine
when the bundled dataset needs to be built or refreshed.

## Inputs (v1)

- `EL.ContourLine` — depth contour lines (no lake-identifying attribute of
  its own; joined to a lake below)
- `EL.Syvyysalue` — depth-area polygons (already carries `jarvitunnus` and a
  pre-classed depth range)

`EL.SpotElevation` (depth-point summary labels) is **not** included in v1 —
deferred, per MFS-027 Revision 7 / TD-027 §21's own reasoning (label
placement/collision-avoidance complexity disproportionate to v1's goal).

## Usage

```bash
cd tools/syke_bathymetry
pip install -r requirements.txt
python build_mbtiles.py
```

This fetches the complete national datasets from SYKE's public WFS 2.0.0
service (paginated, cached under `.cache/` for resumability — delete that
directory to force a fully fresh re-fetch), normalizes and spatially joins
them, and writes the finished MBTiles file to
`../../assets/syke_bathymetry/syke_bathymetry_v1.mbtiles` by default
(override with `--output`).

Expect this to take on the order of 10–20 minutes on a fresh run (national
WFS fetch + tiling at a contiguous z10–z14); a re-run with a warm `.cache/`
skips the fetch step entirely.

After building, run the contour-fidelity verification (below):

```bash
python verify_contour_fidelity.py
```

## What the pipeline does

1. **Fetch** — paginated `GetFeature` requests against
   `https://paikkatiedot.ymparisto.fi/geoserver/inspire_el/wfs`, no API key
   or registration required for this volume of ad-hoc querying (SYKE asks
   only that sustained/production integrations register with
   `gistuki@syke.fi`).
2. **Normalize** — Finnish-locale decimal-comma numeric fields
   (`syvyyskayra_m`, `syvyysvali_m`) are converted to plain floats; the
   literal value `"Saari"` (island/land inclusion within a lake polygon) is
   classified separately from a real depth range, not treated as a parse
   failure. Records with no usable depth value at all are dropped — a real,
   small fraction of `ContourLine` (confirmed ~1.3% in the source data
   during TD-027's own verification), not a bug in this step.
3. **Spatial join** — each contour line is matched to the `Syvyysalue`
   polygon it falls within, tagging it with that polygon's `jarvitunnus`.
   `ContourLine` geometry is already correctly positioned without this join
   (MapLibre needs no lake-identity attribute to draw a line in the right
   place); the join exists for QA (catching corrupt/mispositioned records)
   and to let the bundled tiles carry lake identity on contour features too,
   not merely on depth-area polygons.
4. **Tile** — a small, self-contained tiler (bbox-based tile bucketing per
   zoom, `shapely` for per-tile clipping/simplification,
   `mapbox_vector_tile` for MVT encoding) produces one national MBTiles
   file, a **contiguous z10–z14** (no gaps). z6/z8/z9 are intentionally
   excluded: nothing below z10 is ever rendered by the presentation layer
   (`WorldwideStyleFactory.sykeBathymetryPresentationMinZoom`), so tiling
   them would only cost build time and file size for content that can
   never be shown. The pyramid must stay *contiguous* across whatever range
   it does cover — MapLibre vector sources request a tile at every integer
   zoom within the source's declared `[minzoom, maxzoom]`, not merely at
   whichever zooms happen to have data, so a gap at any zoom in that range
   (the original build used a non-contiguous `[8, 10, 12, 14]` and paid for
   it with real, confirmed contour flicker on a physical device) reappears
   as a real, visible defect, not a cosmetic one.

   Contour-line features are **not simplified at all** (product decision,
   2026-07-28): physical Android testing found that even the earlier
   size-aware adaptive-tolerance fix still made contours visibly too
   angular. Accuracy and visual fidelity outweigh asset size for this
   layer, so every contour is tiled at its full, original `EL.ContourLine`
   vertex precision — the only geometry transformation applied to a
   contour anywhere in this pipeline is per-tile clipping (required to
   bound a feature to its tile at all) and the MVT format's own mandatory
   coordinate quantization to its 4096-unit tile-local integer grid (both
   necessary to produce a valid vector tile, neither a simplification
   choice). Depth-area polygons keep their existing flat per-zoom
   simplification, unchanged — their fill layer is not even part of the
   current map presentation, and this decision does not apply to them.

   This is **not** `tippecanoe` — unavailable to install in the sandboxed
   environment TD-027's own pre-implementation verification was performed
   in, and not assumed to be available on every future developer machine
   either. If `tippecanoe` (or an equivalent production-grade tiler) is
   available when a refresh is next performed, prefer it — it is expected
   to produce a **smaller** file than this script's own simpler
   Douglas-Peucker-only simplification (see TD-027 §20/§20A's own explicit
   caveat: the measured prototype size is a conservative upper bound, not a
   precise prediction). Swapping the tiling *implementation* (step 4 only)
   for a `tippecanoe`-based one is a reasonable future improvement to this
   script; the fetch/normalize/join steps (1–3), and the size-aware
   contour-tolerance *policy* (though not necessarily this exact
   Shapely-based implementation of it), do not depend on which tiler is
   used and do not need to change.

## Two v1 layers, both in the same MBTiles source

- `depth_areas` — polygon features: `depth_kind` (`"range"` | `"island"` |
  `"none"`), `depth_min`, `depth_max` (both `-1` when not applicable),
  `luokka`, `jarvitunnus`. Bundled, but not rendered by the app's current
  presentation (`WorldwideStyleFactory`) — see TD-027 §27.
- `contours` — line features: `depth_m`, `jarvitunnus` (from the spatial
  join). `depth_m` is read twice by the app: once for the contour line
  itself, and once by a `symbol` layer that renders it as a `"<depth> m"`
  label tracing the same line (TD-027 §27) — a presentation-only feature
  requiring no change to this pipeline, since `normalize_contours()` already
  guarantees every tiled contour carries a usable `depth_m`.

## Refreshing the dataset later

Simply re-run `python build_mbtiles.py`. There is no scheduled or automatic
refresh — this is a deliberate, developer-run action. After a refresh:

1. Review the printed summary (feature counts, tile counts, output size) —
   compare against the previous run's own numbers as a basic sanity check.
2. Commit the regenerated `assets/syke_bathymetry/syke_bathymetry_v1.mbtiles`
   file.
3. **Only if this script's own output schema/attribute shape changes**
   (not merely its data content) — bump the version suffix in both the
   output filename here and `SykeBathymetryTileSource.defaultAssetFileName`
   (e.g. `_v1` → `_v2`), so a previously-extracted copy from an older app
   version is never silently reused as if it already reflected the new
   shape.

## Verification performed (not merely assumed)

Several full national builds of this pipeline have been run against the
complete real datasets, each time verified directly against the actual
output, not assumed:

- **Initial investigation build** (TD-027 §20A): 53.16 MB across 5 zoom
  levels including whole-country z6, a 99.9% contour-to-lake spatial join
  success rate, and correct positive/negative results directly confirmed
  against real polygon centroids for Kymijärvi, Vesijärvi (correctly zero
  geometry), Päijänne's covered south basin, and Saimaa.
- **Contiguous-pyramid fix**: rebuilt at a gap-free z10–z14 (68.86 MB) after
  physical Android testing found visible contour flicker traced to the
  original, non-contiguous `[8, 10, 12, 14]` range — confirmed directly
  (`SELECT DISTINCT zoom_level FROM tiles`) that the fixed range has no
  gaps, and that every tile genuinely overlapping Kymijärvi's real geometry
  is present at every zoom.
- **Size-aware contour simplification fix**: rebuilt again after physical
  Android testing found small closed bathymetric contour rings (Kymijärvi's
  own 10m/15m deep-water rings, ~70–95m across) rendering as crude 5–7-point
  "polygons" at every zoom. Verified directly against the regenerated asset:
  both known rings now had 11–12 vertices at every zoom z10–z14 (up from a
  flat 5–7), remained valid closed rings, and a larger real Kymijärvi
  contour and a 2,000-feature Saimaa sample confirmed the rule left large
  features essentially unaffected (≤11% vertex growth on the dense sample).
  Final size: 71.55 MB (+2.69 MB / +3.9% over the contiguous-pyramid build).
- **No-simplification-at-all rebuild** (current, 2026-07-28): physical
  Android testing found even the size-aware adaptive tolerance above still
  visibly too angular — product decision to remove all contour-line
  simplification entirely (accuracy/fidelity over asset size). Rebuilt at
  187.55 MB (+115.99 MB / +162.1% over the previous 71.55 MB build) — the
  full increase is expected and accepted, not a defect: every contour now
  ships at its true source vertex density. Verified with
  `verify_contour_fidelity.py` against six locations (Kymijärvi, Kärkjärvi,
  Mallusjärvi, a dense Saimaa area, a Päijänne area, one small lake): for
  two representative features per location (12 features × 5 zooms = 60
  checks), the script independently re-derives the *exact* tile-local point
  set clipping + MVT quantization alone would produce from the raw source
  geometry, and confirmed every single one matches the actual encoded tile
  vertex-for-vertex — proof no simplification (Douglas-Peucker or
  otherwise) remains anywhere in the pipeline. Tile-size distribution
  stayed healthy: only one tile nationally (a naturally lake-dense region
  at the coarsest zoom, z10) exceeds the 500KB MVT soft-limit convention
  (633.6 KB), none exceed 1MB, and per-zoom average tile size decreases
  from z10 (~67KB) to z14 (~3.7KB) as expected. Build time: 624.3s (~10.4
  min) against a warm WFS cache. Separately, direct inspection of the
  cached raw WFS response found SYKE's own `EL.ContourLine` WFS service
  itself already returns 7,306 of 90,744 national features (~8.1%) capped
  at exactly 500 vertices (only 4 features exceed that, up to 2,722) — an
  upstream source-data characteristic this pipeline has no control over,
  not something introduced by (or fixable in) this script; "preserve the
  source geometry as faithfully as the source data allows" is satisfied
  for these features by construction, since nothing more detailed than
  what SYKE's WFS itself returns is available to fetch.

See `docs/technical-designs/TD-027-worldwide-base-map-coverage.md` §20A
for the original investigation's full record.
