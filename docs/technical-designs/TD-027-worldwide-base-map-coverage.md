# TD-027 — Worldwide Base-Map Coverage

## Status

**Implemented and physically validated on Android (Revision 8).** MML v21 vector for Maastokartta, MapTiler Outdoor/Satellite Hybrid worldwide, and the SYKE bathymetry overlay (contour lines, unsimplified, plus depth labels) are all implemented, `flutter analyze`-clean, covered by the automated test suite, and confirmed on a physical Android device — including the SYKE-specific acceptance items (contour geometry fidelity, continuous rendering across zoom, close-zoom rendering, correct depth-label rendering). **[§27](#27-final-implementation-state--syke-bathymetry--depth-labels-revision-8) is the current, authoritative record of the shipped SYKE bathymetry/depth-label behavior** and supersedes the zoom-threshold/simplification/layer-set placeholders in [§20A](#20a-syke-mbtiles-prototype-build--real-measurements-revision-7-verification) and [§22](#22-maplibre-layer-design-for-syke-revision-7) below. [§3F](#3f-mml-v21-vector-integration-revision-7) through [§26](#26-testing-strategy-additions--revision-7) remain the authoritative design for everything else they cover (MML vector integration, MBTiles delivery architecture, data preparation, licensing/attribution, testing strategy). Revisions 1–6 below (raster WMTS + MapTiler worldwide fallback, culminating in fully content-driven on-device pixel masking) are **retained as historical record**: most of their substance (MapTiler Outdoor/Satellite Hybrid worldwide fallback, per-selection failure independence, credential/attribution mechanics) is unchanged and still applies; what Revision 7 changed is Maastokartta's own MML delivery mechanism (raster+masking → vector) and added the bathymetry overlay. See [§3F](#3f-mml-v21-vector-integration-revision-7)'s own opening paragraph for exactly what is superseded versus retained, and [§25](#25-migration--cleanup--revision-7) for the full file-by-file disposition.

Revisions 1–3 below are historical record; Revision 4's architecture was live in the codebase (implemented, not yet physically validated) as of Revision 6, refined by Revision 5, refined again by Revision 6 — **and is now itself superseded by Revision 7's vector path for the reasons in [§3F](#3f-mml-v21-vector-integration-revision-7)**. Kept in full below (see [Revision History](#revision-history), [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)'s migration plan for what Revision 4 replaced, [§3D](#3d-boundary-no-data-connected-component-refinement--presentation-minzoom-revision-5) for Revision 5's additive refinement, and [§3E](#3e-content-driven-boundary-masking--coarse-fetch-envelope-revision-6) for Revision 6's replacement of geometry-driven masking) because it represents real, physically-informed engineering work and because its geometry primitives and local-loopback-service pattern are directly reused by Revision 7, not because it remains the implementation plan.

## Related

- Implements: MFS-027 — Worldwide Base-Map Coverage, **Revision 7** (MML v21 vector for Maastokartta's Finnish layer, MapTiler Outdoor unchanged as worldwide underlay, MapTiler Satellite Hybrid unchanged for Ilmakuva, plus a new SYKE bathymetry overlay — see [Revision History](#revision-history) and [§3F](#3f-mml-v21-vector-integration-revision-7) onward)
- Authoritative, not reconsidered here: ADR-0009 — Global Base Map Coverage and Fallback (MapTiler as worldwide provider for both roles, direct-to-MapTiler HTTPS, no proxy, per-selection failure-independence principle; **the originally-relied-upon "MML transparent no-data tile" assumption for Maastokartta was disproved by physical testing and is no longer the switching mechanism — see ADR-0009 Revision Note 2**); ADR-0008 — Base Map Provider and Delivery (MML as Finnish provider, direct-to-MML, base map/overlay/application-owned-layers model — **its raster-WMTS-specific delivery-format decision is revised for Maastokartta by this document's Revision 7; see ADR-0008's own "Revision Note: Maastokartta moves to MML v21 vector"**); ADR-0002 — Map Technology (MapLibre GL)
- Depends on / extends: TD-026 — Selectable MML Base Maps (`core/map`'s existing types, the locally-generated-style-file mechanism, the generation-aware style-lifecycle/marker-restoration fix, `--dart-define`-based credential configuration, and the attribution/selector UX this document builds on rather than replaces)
- Sibling precedent: `StyleRestorationTracker`/`FishingSpotLayerPresence` (TD-026 Implementation Notes) — the verified-idempotent, generation-aware restoration idiom this document reuses without modification
- Sibling precedent: `MmlConfig` (TD-026 §8) — the exact shape this document's new `MapTilerConfig` mirrors
- **(Revision 7)** Investigation source: `investigation/v21/` (MML's real v21 TileJSON/style responses, redacted); `investigation/syke_depth/coverage_report.md` and its accompanying raw query results (SYKE coverage, licensing signal, sample data) — see [§3F](#3f-mml-v21-vector-integration-revision-7)/[§20](#20-syke-production-delivery-architecture-revision-7)–[§21](#21-syke-data-preparation-revision-7)
- **(Revision 7)** Temporary PoC, being promoted/rewritten, not left in place: `lib/core/map/mml_vector_poc_style_fetcher.dart`, `test/core/map/mml_vector_poc_style_fetcher_test.dart`, `test/core/map/mml_v21_backgroundmap_fixture_test.dart`, `test/fixtures/mml_v21_backgroundmap_style_fixture.json` — see [§25](#25-migration--cleanup--revision-7)

---

## Revision History

**This document has been revised six times.** Revisions 1–4 preceded any shipped implementation of Maastokartta's MML-coverage mechanism; Revisions 5 and 6 are post-physical-testing refinements of Revision 4's own already-implemented architecture. Recorded here so each change is visible, not silently overwritten:

- **Original design:** one shared MapTiler Outdoor worldwide layer, used identically beneath whichever of Maastokartta/Ilmakuva was selected (a single `WorldwideStyleFactory` composing "MapTiler Outdoor + selected MML fragment" for both selections).
- **Revision 1:** Maastokartta keeps that original composition (MapTiler Outdoor beneath MML Maastokartta). **Ilmakuva no longer includes MML at all** — it is now MapTiler Satellite Hybrid, used directly as the complete worldwide base map, inside Finland and everywhere else alike. See [§3](#3-per-selection-style-composition) for the resulting design, and ADR-0009/MFS-027 (both updated alongside this document) for the product-level reasoning and trade-offs. **Implemented and shipped**, independent of the Maastokartta-specific revisions below.
- **Revision 2 — architecture correction after physical Android testing:** Revision 1's Maastokartta composition relied on MML's own tiles being reliably transparent outside Finland to decide when MapTiler Outdoor should show through, verified only by narrow spot-checks (Paris, Stockholm, Haparanda). **Physical Android testing at broader geographic scale found this unreliable** — MML rendered opaque gray/white blocks and visible tile/coverage-boundary artifacts in some areas outside Finland (Sweden, the Baltic region, and elsewhere), especially visible at low zoom. Maastokartta's composition is revised again: MML's inclusion is now governed by an explicit, application-owned approximate Finland region (with hysteresis), evaluated against the viewport on camera-idle, replacing reliance on MML's own edge behavior. MapTiler Outdoor's own presence remains unconditional (unchanged). Ilmakuva is **not** revised — physical testing found no equivalent problem with its design. **Implemented** (`MmlCoverageRegion`, `MapScreen`'s `_mmlActiveForViewport`/`_onCameraIdle`), **then superseded by Revision 4 below** — see [§3A](#3a-maastokarttas-geographic-region-mechanism-revision-2) for the mechanism as originally designed and implemented, and [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4) for its migration/removal plan.
- **Revision 3 — a second architecture correction, after further physical Android testing.** Revision 2's geographic region check evaluates only the viewport's *center point*. Further physical testing found that this is not sufficient on its own: even with the center legitimately inside Finland, a low-zoom viewport can still visibly cover an area larger than Finland's own real extent, reproducing the same class of opaque gray/white blocks and tile/coverage-boundary artifacts Revision 2 was written to fix. Revision 3 proposed a zoom-activation threshold (a native, declarative MapLibre raster-**layer** `minzoom` property) alongside Revision 2's geographic check, and specified the physical test needed to determine the exact threshold. **Never implemented — superseded before that physical test was run, by the pixel-level investigation Revision 4 below is built on.** Kept in full as [§3B](#3b-maastokarttas-zoom-gated-mml-inclusion-revision-3) for its own genuine research value (in particular, the confirmed MapLibre layer-vs-source `minzoom` distinction, which remains accurate and citable regardless of this revision's fate).
- **Revision 4 — a third architecture correction, after direct pixel-level evidence, replacing both prior revisions' mechanisms rather than extending them.** Real MML WMTS tiles were decoded and inspected directly. **Every tested tile was 100% opaque — no PNG transparency chunk, no alpha channel, at any location, including a Finland/Russia border tile that was 69.81% a single flat, textureless gray corresponding exactly to Russian territory.** This proves what Revisions 2 and 3 could each only work around: MML's own out-of-coverage pixels are opaque, not transparent, so no viewport-level inclusion/exclusion rule — however precisely tuned by region, hysteresis, or zoom — can ever produce a pixel-clean border. Native MapLibre/GPU-level alternatives (style-level color-key transparency, a clip/mask layer type, a custom shader or forked renderer) were investigated and rejected — none exist in the MapLibre style specification, and the one native escape hatch found (`CustomLayer` on Android) is documented by its own maintainers as experimental and explicitly "do not use." **Maastokartta's composition is revised a third time, replacing rather than extending Revisions 2 and 3:** MML's raster source becomes unconditionally present in the composition whenever configured (exactly like MapTiler Outdoor already is), and a small, app-local, loopback-only process makes MML's own out-of-coverage pixels transparent, per tile, before MapLibre ever requests them. This eliminates the viewport-level "is MML in or out" decision entirely — there is nothing left for a hysteresis margin to stabilize or a zoom threshold to gate. See [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4) for the full design, and ADR-0009's Revision Note 4 / MFS-027's new FR-24 for the product-level reasoning.
- **Revision 5 — a refinement, not an architecture correction: physical Android testing of Revision 4 found two remaining Maastokartta-only defects, both fixed within Revision 4's existing architecture, for Maastokartta only (Ilmakuva/MapTiler untouched).** First: the 10 km geometry buffer's own approximation of Finland's coastline/border necessarily leaves a few km of real, opaque `RGB(204,204,204)` MML no-data visible inside the buffered area at its tightest margins (confirmed at the Finland/Russia border) — a **boundary-tile-only connected-component refinement** now additionally identifies and removes large, tile-edge-touching no-data blocks, verified safe against all 10 real bundled fixtures with zero false positives/negatives (see [§3D](#3d-boundary-no-data-connected-component-refinement--presentation-minzoom-revision-5)). **The 10 km buffer itself is unchanged** — it remains the authoritative classification/coverage-shape mechanism; the new refinement is strictly additive on top of it. Second: MML rendered at excessively low/world-scale zoom, where its cartographic detail is not usefully visible — a new, purely presentational MML raster-**layer** `minzoom` (independent of coverage masking, which remains fully zoom-independent) now hides the layer below that zoom, mirroring the *reasoning* (not the masking-critical *mechanism*) of the abandoned Revision 3 zoom gate. **Its final value is not yet chosen** — a placeholder (`7`) is wired in pending a physical zoom 6/7/8 comparison on a real device (§3D specifies the exact procedure).
- **Revision 6 — a third architecture correction to boundary masking, replacing rather than extending Revision 5's geometry-alpha approach.** Physical Android testing of Revision 5 found the gray-only no-data detector missed a real defect: at higher zoom (z12/13), MML's own no-data fill is a *different* color — `RGB(255,255,255)`, not gray — confirmed at three independent border crossings (Imatra, Nuijamaa, Vaalimaa), each showing the same monotonic no-data growth pattern across adjacent tiles toward foreign territory. Separately, physical testing around Åland found visibly circular/buffered-land-shaped MML cutouts around small islands — traced to `geometryAlpha` itself: a uniform-radius buffer around a scatter of small islands produces rounded shapes by construction, and real MML content was found (via a systematic Åland/archipelago/open-Baltic transect) to extend asymmetrically up to 70km beyond any buffered-land shape in places. **`geometryAlpha` — the buffered-distance rasterization at the heart of Revisions 4/5's boundary masking — is removed from the final raster output entirely, not merely refined further.** Boundary-tile visibility is now decided purely from the tile's own fetched pixel content: a whole-tile flat/generic check (MML was found to render pure single-color filler, of either no-data color, far past real content — proven by several 100%-one-color real tiles in the transect) followed by per-color confirmed no-data component removal (gray *and* white, each with its own evidence-based threshold) — everything else stays exactly as MML rendered it, fully opaque. Geometry's role narrows to a **coarse, non-visible fetch-eligibility filter only** (`MmlCoverageRegion`'s land+10km buffer for the cheap "clearly inside" fast path; a new, much larger evidence-based bounding-box envelope for "worth fetching at all") — it no longer shapes any pixel's alpha. See [§3E](#3e-content-driven-boundary-masking--coarse-fetch-envelope-revision-6) for the full design, the locked thresholds, and the 45-real-tile evidence base. Revision 5's presentation-minzoom placeholder is untouched, a deliberately separate concern. **Physical Android testing of Revision 6 was never performed — superseded by Revision 7 before that testing happened.**
- **Revision 7 — a product-direction change, not a refinement: MML raster WMTS + on-device pixel masking (Revisions 1–6) is superseded by MML v21 vector tiles for Maastokartta's Finnish cartographic layer, and a new SYKE lake/river bathymetry overlay is added.** MML v21 vector was physically tested via a temporary PoC (`MmlVectorPocStyleFetcher`) and found acceptable as the Finnish topographic rendering path; because vector tiles encode discrete features rather than pre-rendered pixels, the entire class of defect Revisions 2–6 exist to fix (opaque no-data fill baked into raster pixels) is not expected to occur at all, pending direct verification (this document's own established discipline: verify, do not assume — see [§3F](#3f-mml-v21-vector-integration-revision-7)). Separately, per product decision, SYKE's "Järvien ja jokien syvyysaineisto" bathymetry dataset is added as a new overlay above the base map and below application-owned layers — the first real occupant of the "External overlays" band ADR-0008 named but left unbuilt. At the time this revision was written, it was documentation/design only. See [§3F](#3f-mml-v21-vector-integration-revision-7)–[§26](#26-testing-strategy-additions--revision-7) for the full design, and [§25](#25-migration--cleanup--revision-7) for what is retired, retained, and reused from Revisions 1–6.
- **Revision 8 (this version) — implementation completed, physically validated, superseding Revision 7's open placeholders rather than the design itself.** Revision 7's design was implemented in full: MML v21 vector, MapTiler Outdoor/Satellite Hybrid, and the SYKE bathymetry overlay. Physical Android testing settled the questions Revision 7 deliberately left open: contour-line simplification was found visibly too angular at every tolerance tried and is **not applied at all** — contours ship at full source vertex precision, the only geometry transformation being per-tile clipping (an MVT-format requirement, not a simplification choice); the SYKE overlay's presentational `minzoom` is fixed at **10** for contour lines (depth-area fill shading was tried and found visually competing with MML's own lake rendering, so it ships disabled — data remains bundled for a possible future revision, only the fill layer is off); and a new **depth-label** refinement (line-following labels reading each contour's own `depth_m` MVT attribute, `"<depth> m"`, from `minzoom` **12**, excluding the `0 m` shoreline contour) was added, investigated, and fixed for a font-selection defect found in testing, then accepted. See [§27](#27-final-implementation-state--syke-bathymetry--depth-labels-revision-8) for the complete final-state record.

## Goal

Design the smallest, most robust extension of the existing MFS-026/TD-026 map architecture that gives both existing base-map selections real worldwide coverage:

- **Maastokartta:** MapTiler Outdoor as an always-present worldwide underlay; MML Maastokartta *also* always present, with its own out-of-coverage pixels made transparent by a small on-device process before MapLibre ever renders them — replacing both this document's original reliance on MML's own tile-transparency behavior and Revisions 2/3's viewport-level region/zoom workarounds, once direct pixel-level evidence showed the defect lives in the tile pixels themselves and no viewport-level rule could fix it (see [Revision History](#revision-history)).
- **Ilmakuva:** MapTiler Satellite Hybrid as the complete worldwide base map, replacing MML Ortokuva's role in this milestone — unaffected by any Maastokartta-specific correction; physical testing found no equivalent problem with this design.

This must satisfy MFS-027 and ADR-0009 — in particular ADR-0009's failure-independence principle, understood per-selection — without introducing a generalized provider framework, a backend/proxy (in ADR-0008/0009's sense of a remote, developer-operated server), a custom MapTiler style, a generalized geofencing or feature-flagging system, or an offline-map-download feature, beyond the one narrow, Maastokartta-specific on-device tile-masking process this document designs (§3C).

The implementation shall satisfy MFS-027.

---

## 0. Pre-Implementation Verification (completed)

ADR-0009 already established *why* MapTiler was selected; this section fixes the literal technical values needed to actually request its tiles for **both** MapTiler products this milestone now uses, verified directly against MapTiler's current official documentation (not from memory, and not solely from ADR-0009's own research).

### Confirmed from official MapTiler documentation — MapTiler Outdoor

| Value | Confirmed value | Source |
|---|---|---|
| Style identifier | **`outdoor-v4`** (a dark variant, `outdoor-v4-dark`, also exists but is not used here) | MapTiler's official Outdoor product page |
| Raster tile endpoint (the one this design uses) | `GET https://api.maptiler.com/maps/outdoor-v4/{tileSize}/{z}/{x}/{y}{scale}.{format}?key=<key>` | MapTiler Maps API docs |
| Delivery mode confirmed for this style specifically | Raster tiles (XYZ-compatible, for Leaflet/OpenLayers/etc.) explicitly listed as one of several delivery methods for Outdoor, alongside vector tiles, WMTS, and static images | MapTiler Outdoor product page |
| Declared zoom range — **resolved** | **`minzoom: 0`, `maxzoom: 22`**, confirmed directly from `outdoor-v4`'s own authenticated TileJSON response (`tilejson: 2.0.0`, worldwide Web Mercator bounds, one advertised tile URL template, attribution `© MapTiler © OpenStreetMap contributors`). No longer an open verification item. | MapTiler's first-party, authenticated TileJSON endpoint for `outdoor-v4` |

### Confirmed from official MapTiler documentation — MapTiler Satellite Hybrid

| Value | Confirmed value | Source |
|---|---|---|
| Style identifier | **`hybrid-v4`** (a dark variant, `hybrid-v4-dark`, also exists but is not used here) — distinct from plain `satellite-v4`, which has no labels/roads baked in | MapTiler's official Satellite/Hybrid product page |
| Raster tile endpoint | `GET https://api.maptiler.com/maps/hybrid-v4/{tileSize}/{z}/{x}/{y}{scale}.{format}?key=<key>` — the same generic Maps API pattern confirmed for Outdoor, applied to this style id | MapTiler Maps API docs (generic pattern); the `hybrid-v4` identifier itself confirmed from the product page |
| Delivery mode confirmed for this style family | "Leaflet, OpenLayers, XYZ" raster endpoints explicitly listed for the Satellite/Hybrid product line | MapTiler Satellite/Hybrid product page |
| Labels/roads/place names baked into the raster output | **Confirmed yes.** Hybrid "adds context by overlaying labels, roads, and borders" over the same imagery Satellite (plain) uses — described as packaging "satellite imagery with streets & placenames for context." No separate label layer needs to be composed by this project. | MapTiler's official Satellite/Hybrid product page |
| Resolution | Global coverage at **2 m/px**, with higher resolution (down to ~8 cm/px aerial) in some regions; not confirmed to be uniform, and **not separately confirmed for Finland specifically** — see [§14 Risks](#14-risks-and-mitigations) for the corresponding pre-ship verification recommendation. | MapTiler's official Satellite/Hybrid product page |
| Declared zoom range — **resolved** | **`minzoom: 0`, `maxzoom: 22`**, confirmed directly from `hybrid-v4`'s own authenticated TileJSON response (`tilejson: 2.0.0`, worldwide Web Mercator bounds, one advertised tile URL template, attribution `© MapTiler © OpenStreetMap contributors`) — identical declared range to Outdoor. This supersedes the earlier, inconsistent secondary-source figures (a general "0–22" platform-wide marketing claim vs. the unrelated "Satellite Mediumres"/aerial tiered description); the tileset's own TileJSON is authoritative and is what is used. No longer an open verification item. | MapTiler's first-party, authenticated TileJSON endpoint for `hybrid-v4` |
| Cost/quota treatment vs. Outdoor | **No difference found.** MapTiler's pricing page states map sessions cover "all preset or custom map styles" with "unlimited requests to all MapTiler tilesets" — Satellite/Hybrid is listed as a preset style alongside Streets/Outdoor with no separate billing or quota. | MapTiler's official Cloud pricing page |

### Confirmed for both products (shared platform behavior)

| Value | Confirmed value | Source |
|---|---|---|
| Allowed `tileSize` | **`256` only** — not `512` | MapTiler Maps API docs |
| Allowed `format` | `png`, `jpg`, `webp` | MapTiler Maps API docs |
| Tile token order | **Standard `{z}/{x}/{y}`** — column before row, matching MapLibre's own default token semantics directly | MapTiler Maps API docs |
| API-key parameter | Query-string parameter **`key`** (`?key=<MAPTILER_API_KEY>`) — a different parameter name from MML's own `api-key`; one key/account covers both Outdoor and Satellite Hybrid | MapTiler Maps API docs |
| 256-vs-512 zoom-numbering caveat — **resolved for this project** | MapTiler's default rasterization is 512×512, and its style-editor/style.json zoom numbering is expressed in 512-based terms (a documented +1 shift applies when translating a 512-based zoom figure to the 256px path). This caveat does **not** apply to the values actually adopted here: the authenticated TileJSON responses for both `outdoor-v4` and `hybrid-v4` were read directly, describe the tilesets themselves (not a 512-based style/editor convention), and — combined with this project's raster sources consistently using the dedicated 256px endpoint and declaring `tileSize: 256` throughout — are used as-is (`minzoom: 0`, `maxzoom: 22`) with no shift applied. The caveat is recorded here only so a future reviewer does not mistakenly re-derive or re-shift these already-resolved numbers from a differently-scoped, 512-based source later. | MapTiler's official 256/512/HiDPI guide; MapTiler's authenticated TileJSON for both styles |
| Required attribution text | **`© MapTiler © OpenStreetMap contributors`**, with `© MapTiler` linking to `https://maptiler.com/copyright` and `© OpenStreetMap contributors` linking to `https://openstreetmap.org/copyright` — identical requirement for both products; MapTiler's official copyright page does **not** require any additional imagery-provider-specific text (e.g. naming Maxar/Airbus) for its satellite/aerial products beyond this standard notice | MapTiler's official attribution guide + copyright page |
| Logo requirement | Free-tier accounts must additionally display the MapTiler logo, linking to `www.maptiler.com`; only a paid account may disable it — applies identically to both products | MapTiler's official attribution guide |
| Mobile compact/tap-to-expand attribution | Permitted generally (attribution "may be available behind a contextual popup window... openable with one click/tap" on small screens) | MapTiler's Cloud Terms and Conditions |

### Confirmed from direct inspection of the installed `maplibre_gl: ^0.26.2` plugin source

| Capability | Confirmed | Relevance |
|---|---|---|
| `controller.addSource(sourceId, RasterSourceProperties(tiles: [...], tileSize: 256, ...))` / `controller.addRasterLayer(..., belowLayerId: ...)` / `controller.removeLayer`/`removeSource` / `controller.setStyle(...)` | All exist | A *live*, incremental source/layer swap is technically possible; not adopted — see [§3](#3-per-selection-style-composition). |
| Any style-load-error, tile-error, or per-source-error callback | **Not found.** Only `onStyleLoadedCallback`, `onCameraIdle`, `onMapIdle` exist. | No tile/source-specific failure signal is available for either MapTiler product or MML — unchanged conclusion from the original verification, now confirmed to apply identically to Satellite Hybrid too. |

**Sources consulted:** MapTiler's official Maps API documentation, Outdoor product page, Satellite/Hybrid product page, official copyright page, official attribution guide, official Cloud pricing page, official 256/512/HiDPI guide, the installed `maplibre_gl-0.26.2`/`maplibre_gl_platform_interface-0.26.2` package source, and — in a final verification pass, once `MAPTILER_API_KEY` became available in the environment — MapTiler's own first-party, authenticated TileJSON responses for both `outdoor-v4` and `hybrid-v4` (`tilejson: 2.0.0`, `minzoom: 0`, `maxzoom: 22`, worldwide Web Mercator bounds, one advertised tile template, standard attribution, for each). No value above was inferred from ADR-0009's own research alone where an implementation-exact value was needed. The API key itself was never printed, logged, persisted, or included in this document.

---

## MFS-027 / ADR-0009 Changes

`docs/adr/0009-global-base-map-coverage-and-fallback.md` and `docs/specifications/MFS-027-worldwide-base-map-coverage.md` have both been updated directly (not merely recorded as resolved here) to reflect the product decision this document designs around: Ilmakuva no longer composes MapTiler with MML at all. Summary, for cross-reference:

- ADR-0009's Decision, composition-model diagrams, attribution/failure sections, Consequences, and Scope were revised to describe two distinct compositions instead of one shared worldwide layer, and to record Ilmakuva's loss of dual-provider failure independence and its now-unverified image-quality parity with MML Ortokuva as explicit, accepted trade-offs.
- MFS-027's Conceptual Model, Functional Requirements (renumbered and regrouped into Shared/Maastokartta-specific/Ilmakuva-specific), Loading and Failure Behavior table, Attribution section, Acceptance Criteria, Out of Scope, Architecture Constraints, and Design Notes were all revised accordingly. MFS-027's Status remains **Draft**; it is not marked implemented by this change.

This document's own §0 additionally resolves both MapTiler products' zoom-range questions conclusively: a final authenticated verification pass against MapTiler's own first-party TileJSON endpoints confirmed `minzoom: 0`/`maxzoom: 22` for both `outdoor-v4` and `hybrid-v4`, superseding the earlier "not confirmed, flagged for live verification" status.

**Second round of changes (Revision 2), following physical Android testing:** ADR-0009 and MFS-027 were updated again, alongside this document, to record that the "MML transparent no-data tile" assumption underlying Maastokartta's original composition was disproved at broader geographic scale (opaque gray/white blocks, visible tile/coverage-boundary artifacts around Sweden/the Baltic region — see ADR-0009's new Revision Note 2). ADR-0009's Decision item 6, Consequences, Failure Behavior, and Scope sections; and MFS-027's Conceptual Model, FR-9/FR-11/FR-12/FR-21, Attribution, Acceptance Criteria, Out of Scope, Architecture Constraints, Edge Cases, and Design Notes were all revised to require and describe the new geographic-region mechanism ([§3A](#3a-maastokarttas-geographic-region-mechanism-revision-2)) in place of the disproved assumption. Ilmakuva is explicitly unaffected by this second round — physical testing found no equivalent problem with its design.

**Third round of changes (Revision 3), following further physical Android testing.** ADR-0009 and MFS-027 were updated again, alongside this document, to record that Revision 2's geographic region check — while correct on its own terms — does not by itself prevent the reported defect at low zoom, since it evaluates only the viewport's center and has no way to express viewport *extent*. ADR-0009 gained a new Revision Note 3; MFS-027 gained a new FR-23 (placed after FR-22 to avoid renumbering already-referenced requirements) plus corresponding updates to its Conceptual Model, FR-9/FR-11/FR-12/FR-21, Attribution, Loading and Failure Behavior, Edge Cases, Architecture Constraints, Acceptance Criteria, and Design Notes. This document gained a new [§3B](#3b-maastokarttas-zoom-gated-mml-inclusion-revision-3) alongside corresponding updates to §3 (the Maastokartta style example), §9, §11, §12, §13, §14, §18, and §19. Ilmakuva is explicitly unaffected by this third round. **Unlike Revisions 1 and 2, this round of documentation updates does not itself finalize a ready-to-implement value** — the zoom activation threshold is deliberately left as an open, physical-test-gated verification item, not invented; implementation of §3B was never begun before Revision 4 superseded it.

**Fourth round of changes (Revision 4), following direct pixel-level evidence from real MML tiles.** ADR-0009 and MFS-027 were updated a third time, alongside this document, to record that neither Revision 2's region check nor Revision 3's proposed zoom threshold could ever have produced a pixel-clean border, because MML's own out-of-coverage tile pixels were found — by decoding real tiles, not by inference — to be fully opaque, never transparent. ADR-0009 gained a new Revision Note 4, superseding (not merely extending) Revision Notes 2 and 3's mechanisms; MFS-027 gained a new FR-24 (placed after FR-23, preserving the existing no-renumbering convention), with FR-11/FR-12/FR-23 revised in place to point to it, plus corresponding updates to Conceptual Model, FR-9/FR-21, Loading and Failure Behavior, Attribution, Architecture Constraints, Acceptance Criteria, Edge Cases, and Design Notes. This document gains a new [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4) — a materially larger design than either §3A or §3B, since it introduces genuinely new infrastructure (an on-device HTTP tile-transformation service) rather than a single application-side check — alongside corresponding updates to §1, §3, §5, §6, §9, §11, §12, §13, §14, §18, and §19. Ilmakuva is explicitly unaffected. **§3A and §3B are retained in full, not deleted** — both remain accurate records of real investigation and (for §3A) real, working, shipped code as of the start of this revision; §3C's own text states plainly what is superseded and why.

---

## Fixed Architectural Decisions (not reconsidered here)

Restated from ADR-0002, ADR-0008, ADR-0009, and MFS-027 — binding constraints, not open questions:

- MapLibre GL remains the renderer (ADR-0002).
- MML remains Maastokartta's Finnish data provider (ADR-0008) — unchanged by this document. **As of Revision 7, delivery format changes from raster WMTS to MML's own official v21 vector tiles** (§3F) — a revision to ADR-0008's specific "raster, not vector" delivery-format choice, made for the reasons §3F states (a real, physically-tested product improvement, and the elimination of an entire class of masking complexity), not a reopening of MML-as-provider itself. **As of Revision 4 (superseded for the raster path by Revision 7, but the pattern is retained and reused for vector), the client fetches MML through a small on-device process rather than directly** (§3C, §3F); this is a change of *client-side rendering plumbing*, not of provider, and it is not the "proxy" ADR-0008's "direct-to-MML HTTPS, no proxy" language refers to (that language is about a remote, developer-operated backend — see ADR-0009 Revision Note 4 for the explicit distinction).
- MapTiler is the provider for both Maastokartta's worldwide underlay (Outdoor) and Ilmakuva's complete worldwide base map (Satellite Hybrid), delivered directly from the client over HTTPS, no proxy introduced solely to hide either provider's key (ADR-0009). Entirely unaffected by Revision 4 — MapTiler's delivery path never touches the on-device MML process.
- Neither MML nor MapTiler credentials are ever committed to source control (ADR-0008/ADR-0009); one MapTiler credential covers both MapTiler roles. **As of Revision 4, the MML credential must additionally never appear in the on-device MapLibre style URL, any log line, cache filename, or error message** — a new, explicit requirement made necessary by the on-device fetching step existing at all (see [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)).
- ~~Revised by Revision 2: Maastokartta's inclusion of MML is now governed by an explicit, approximate Finland region with hysteresis.~~ **Superseded by Revision 4 — kept as a historical record of shipped code this revision removes; see [§3A](#3a-maastokarttas-geographic-region-mechanism-revision-2)'s own migration note.**
- ~~Revised by Revision 3: Maastokartta's inclusion of MML additionally requires the camera zoom to be at or above an activation threshold.~~ **Never implemented; superseded before implementation began — see [§3B](#3b-maastokarttas-zoom-gated-mml-inclusion-revision-3).**
- **Revised by Revision 4:** Maastokartta's MML raster source is unconditionally present whenever configured (like MapTiler Outdoor); correctness is enforced per pixel by an on-device, loopback-only tile-transformation process using the Finland/Åland coverage geometry — see [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4). No hysteresis, no zoom threshold, no viewport-triggered style regeneration for this reason. Ilmakuva needs no such mechanism at all (unchanged).
- Exactly two selectable base maps remain (Maastokartta, Ilmakuva); MapTiler is never a third selectable option (MFS-027 FR-1).
- **MML Ortokuva is not used by the Ilmakuva composition in this milestone** (product decision; ADR-0009, MFS-027).
- No custom MapTiler vector style is created (ADR-0009, MFS-027 Out of Scope) — both MapTiler products are consumed via their own documented raster tile endpoints, not authored or restyled by this project.
- No generalized map-provider framework, no offline map system, no backend/proxy (in the ADR-0008/0009 sense — a remote, developer-operated server; the on-device tile-masking process is explicitly not this, per ADR-0009 Revision Note 4), and no country/geofence detection **based on device location or location permission** — coverage geometry is evaluated purely against map tile coordinates, never the device's real-world location (MFS-027 Out of Scope, FR-22).
- No repository interface, DAO, service layer, or use-case layer — concrete classes only, per `docs/development-rules.md` and every prior TD.
- The existing MFS-026 selector, `MapControls`, and fishing-spot feature code are not redesigned (MFS-027 Out of Scope) beyond whatever small, justified attribution-related addition this document specifies.

---

## Current State

Inspected directly in the current codebase before designing this change. **This table describes the state as of Revision 2's shipped implementation (before Revision 4) — the baseline [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4) migrates away from, not the target state.**

| Area | Current shape |
|---|---|
| `MapScreen` style delivery | `_stylePathFor(BaseMap)` builds a small style JSON via `MmlStyleFactory.styleFor(baseMap)` (one raster source, one raster layer, a `glyphs` URL), writes it to a temp-directory file, and passes that file's path as `MapLibreMap`'s `styleString`. Switching Maastokartta ↔ Ilmakuva regenerates this same small file and reassigns `styleString`, which MapLibre GL Native reloads as a whole-style replacement, re-firing `onStyleLoadedCallback`. |
| Missing-MML-key handling | `MmlConfig.isMissing` is checked *before* building the MML-bearing style; if true, a minimal "blank" style (glyphs URL, empty `sources`/`layers`) is written instead. |
| Style-lifecycle/restoration | `_styleGeneration` (bumped on every *requested* switch) and `StyleRestorationTracker` (tracking which generation is *actually applied*) together guard `_addFishingSpotMarkers()` against duplicate restoration and stale-generation races. `_ensureFishingSpotLayersExist()` re-verifies actual `getSourceIds()`/`getLayerIds()` presence in a bounded, idempotent retry loop (60 attempts × 500 ms). Fishing-spot layers are added with no `belowLayerId`, appending above whatever base-style layers already exist. |
| Attribution | `MapAttribution`, a plain always-visible `Text` widget rendering `BaseMap.attributionText` (MML's three-element CC BY 4.0 string) for **either** selected `BaseMap` value today, positioned bottom-left. No tap interaction, no logo, no external link. |
| Credential configuration | `MmlConfig` reads `String.fromEnvironment('MML_API_KEY')`; `isMissing`/`apiKey` getters. |
| Persistence | `BaseMapPreferenceStore` (`shared_preferences`-backed) persists only which of `BaseMap.maastokartta`/`BaseMap.ilmakuva` is selected. |
| `maplibre_gl` version | `^0.26.2`, unchanged by this document. |
| Selector/`MapControls` | Unchanged by MFS-026's own scope discipline; this document does not touch either. |

---

## Key Design Decisions

**1. Maastokartta and Ilmakuva are built from two structurally different style documents, not one shared composition function applied to both.** Maastokartta's style contains MapTiler Outdoor plus (if configured) MML Maastokartta; Ilmakuva's style contains **only** MapTiler Satellite Hybrid. This directly reflects the product decision that Ilmakuva no longer uses MML at all — see [§3](#3-per-selection-style-composition).

**2. Both MapTiler products are consumed as plain raster tile sources embedded directly in a locally-generated style document — never as a separately-loaded remote MapTiler style, and never as a custom vector style this project authors or maintains.** This is unchanged from this document's original reasoning (MapTiler's own remote `style.json` would couple the entire map's ability to load to one external fetch, undermining failure independence) and now applies identically to Satellite Hybrid as it does to Outdoor. See [§3](#3-per-selection-style-composition).

**3. Switching Maastokartta ↔ Ilmakuva continues to regenerate the whole (still small) style file for the newly selected `BaseMap` and reassign `styleString`, exactly as TD-026 already does.** Because Ilmakuva's style is now structurally simpler (one source, not two), this remains — if anything — a smaller regeneration than before, not a more complex one. No incremental `removeLayer`/`removeSource`/`addRasterLayer` patch is introduced. See [§5](#5-style-lifecycle--generalized-not-changed)/[§6](#6-switching-mechanism-unchanged-in-shape).

**4. Fishing-spot layers remain above whatever provider layer(s) the active style contains, with no change to their own addition logic.** Because every provider layer for the active selection is already listed in the generated style document's own `layers` array before fishing-spot layers are ever added (at runtime, with no `belowLayerId`, unchanged from TD-026), they land on top automatically — by construction, regardless of whether the active style has one raster source (Ilmakuva) or two (Maastokartta). See [§3](#3-per-selection-style-composition).

**5. One MapTiler credential covers both roles; MML's credential remains entirely independent and, for Ilmakuva, is never consulted at all.** `MapTilerConfig` (unchanged shape from the original design) gates both the Outdoor fragment (Maastokartta) and the Satellite Hybrid fragment (Ilmakuva). `MmlConfig` is only ever read while building Maastokartta's style — Ilmakuva's style-building path does not reference it. See [§8](#8-credential-configuration).

**6. Failure independence is achieved by construction for Maastokartta (two independent raster sources in one locally-authored style document); for Ilmakuva, "independence" instead means the application layer stays usable despite a single-provider failure, since there is no second provider to be independent of.** This is a deliberate, accepted asymmetry between the two selections, not an oversight — see [§9](#9-loading-and-failure-behavior).

**7. Attribution is now conditional on which `BaseMap` is selected, not uniformly "MML plus MapTiler" for both.** While Maastokartta is active, both MML's existing plain-text attribution and a new, compact MapTiler notice are shown. While Ilmakuva is active, **only** the MapTiler notice is shown — MML's attribution must be actively suppressed, since MML data is not part of that composition. See [§11](#11-attribution-design).

**8. (Revision 3, never implemented) Maastokartta's proposed zoom-gated MML inclusion would have been implemented as a static, declarative property of MML's own generated raster layer.** Recorded here for its own research value (the confirmed MapLibre layer-vs-source `minzoom` distinction remains accurate and citable) even though superseded before implementation — see [§3B](#3b-maastokarttas-zoom-gated-mml-inclusion-revision-3).

**9. (Revision 4) MML's raster source becomes unconditionally present in Maastokartta's style, exactly like MapTiler Outdoor — geographic/zoom correctness moves entirely out of the style document and into a small on-device process that transforms MML's own tile bytes before MapLibre ever sees them.** This is the central architectural change of Revision 4: `WorldwideStyleFactory`'s composition logic for Maastokartta reverts to the same shape it had before Revision 2 ever existed (`mmlAvailable` is once again simply "is MML configured," nothing more) — all of the geographic/zoom complexity Revisions 2 and 3 added to the *style-building* layer is removed, not relocated. See [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4).

**10. (Revision 4) The on-device tile-transformation process is a small, self-contained local HTTP service — not a native/GPU-level solution.** A native MapLibre extension (a custom shader, a forked renderer, or the experimental, explicitly-discouraged `CustomLayer` API) was investigated first and rejected: nothing in MapLibre's style specification or compiled shader set can perform color-keyed or geometry-masked raster transparency, and the one native escape hatch that exists is documented by its own maintainers as unsafe to use. Ordinary, portable Dart code processing image bytes before handing them to MapLibre — a technique with no native-build, no-shader-fork, no per-platform-reimplementation risk — was judged the more maintainable choice despite being new infrastructure for this codebase. See [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4).

**11. (Revision 4) Most tiles need no pixel processing at all.** A tile is classified, from its `z/x/y` coordinates alone, as entirely inside real coverage (served unmodified), entirely outside it (served as one shared, pre-built transparent PNG, no MML fetch at all), or straddling the boundary (the only case that actually decodes, masks, and re-encodes a tile) — see [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4). This keeps the common case cheap and confines real image-processing cost to the minority of tiles near the coastline/border, where it is also cached so it is paid at most once per tile.

---

## 1. Overview and Folder Structure

This document extends `core/map` (populated by TD-026) with MapTiler-specific types, plus one small new attribution widget. No new top-level area, no new feature directory.

```text
lib/
├── core/
│   └── map/
│       ├── base_map.dart                   (unchanged)
│       ├── base_map_preference_store.dart  (unchanged)
│       ├── mml_config.dart                 (unchanged)
│       ├── mml_style_factory.dart          (modified by Revision 3 — adds a static `minzoom` to MML's own raster layer; see §3B)
│       ├── mml_coverage_region.dart        (unchanged by Revision 3 — geographic mechanism only, see §3A)
│       ├── maptiler_config.dart            (new — mirrors mml_config.dart; covers both MapTiler roles)
│       ├── maptiler_style_factory.dart     (new — builds Outdoor's and Satellite Hybrid's raster source/layer JSON fragments)
│       ├── worldwide_style_factory.dart    (new — builds the correct style document per selected BaseMap: Outdoor+MML for maastokartta, Hybrid-only for ilmakuva)
│       └── style_restoration_tracker.dart  (unchanged — see §5)
└── features/
    └── map/
        └── presentation/
            ├── map_screen.dart             (modified — uses WorldwideStyleFactory; conditionally renders MML attribution)
            └── widgets/
                ├── map_attribution.dart          (modified — only rendered while Maastokartta is selected; see §11)
                ├── maptiler_attribution.dart     (new — the compact, tap-to-expand MapTiler notice + logo, shown for both selections)
                ├── base_map_layers_control.dart  (unchanged)
                ├── base_map_selector_panel.dart  (unchanged)
                └── map_controls.dart             (unchanged)
```

`MmlStyleFactory` keeps its single, narrow responsibility (MML's own raster source/layer JSON) and is only ever invoked for Maastokartta. `MapTilerStyleFactory` exposes one small method per MapTiler product (an `outdoorSource()`-shaped fragment and a `satelliteHybridSource()`-shaped fragment) rather than a single generic "build a MapTiler fragment for this mapId" function — both products share the same URL-template shape, so the two methods differ only in their style id and the JSON key/source id used, but keeping them as two named methods (rather than one parameterized by a raw string mapId) makes each call site self-documenting and prevents an accidental mix-up between `outdoor-v4` and `hybrid-v4`.

---

## 2. Base-Map Model — Unchanged

`BaseMap` (`maastokartta`/`ilmakuva`) is not modified. It still models exactly the two user-selectable base-map choices (MFS-027 FR-1); MapTiler is deliberately not represented as a `BaseMap` value, since it is never user-selectable and is not part of the persisted preference (MFS-027 FR-2). `BaseMap.maastokartta`'s existing MML-specific getters (`mmlLayerId`, `tileFileExtension`, `attributionText`) are used exactly as before; `BaseMap.ilmakuva`'s equivalent MML-specific getters continue to exist on the enum (removing them is not required by this milestone) but are simply never read by `WorldwideStyleFactory`'s Ilmakuva branch — see [§3](#3-per-selection-style-composition).

---

## 3. Per-Selection Style Composition

### Why not MapTiler's hosted `style.json` as the app's base style, for either product

Unchanged reasoning from this document's original version, now confirmed to apply equally to Satellite Hybrid: using MapTiler's remote `style.json` as `MapLibreMap`'s base `styleString` would make the *entire* style's ability to load dependent on that one remote fetch succeeding. If it failed (MapTiler outage, network failure, invalid key), `onStyleLoadedCallback` would never fire, taking down fishing-spot-layer restoration along with it — exactly the outcome MFS-027's failure requirements forbid. Both MapTiler products are instead consumed as ordinary raster tile sources inside a locally-authored style document, exactly as MML already is.

### Maastokartta's style: MapTiler Outdoor + MML Maastokartta

**Revised by Revision 4 — MML's source now points at the on-device tile-masking service, on loopback, instead of at MML directly.** See [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4) for the full design; shown here for continuity with the rest of this section:

```jsonc
{
  "version": 8,
  "glyphs": "https://fonts.openmaptiles.org/{fontstack}/{range}.pbf",
  "sources": {
    // Present only if MapTilerConfig.isMissing == false.
    "maptiler-outdoor-source": {
      "type": "raster",
      "tiles": ["https://api.maptiler.com/maps/outdoor-v4/256/{z}/{x}/{y}.png?key=<MAPTILER_API_KEY>"],
      "tileSize": 256,
      "minzoom": 0,
      "maxzoom": 22
      // Confirmed directly from outdoor-v4's own authenticated TileJSON (§0) —
      // no longer an assumption or an omitted/deferred value.
    },
    // Present only if MmlConfig.isMissing == false — unconditionally
    // included otherwise (Revision 4, §3C): no region/zoom check gates
    // this anymore. The MML_API_KEY never appears here — it is used only
    // inside the local service's own outbound request to the real MML
    // endpoint, never in this style document.
    "mml-base-source": {
      "type": "raster",
      "tiles": ["http://127.0.0.1:<local-port>/mml/{z}/{x}/{y}.png"],
      "tileSize": 256,
      "minzoom": 0,
      "maxzoom": 18,
      "attribution": "<BaseMap.maastokartta.attributionText>"
    }
  },
  "layers": [
    {"id": "maptiler-outdoor-layer", "type": "raster", "source": "maptiler-outdoor-source"},
    // No layer-level "minzoom" (Revision 3's proposal, never implemented,
    // superseded — see §3B) — pixel-level masking is correct at every zoom
    // without one.
    {"id": "mml-base-layer", "type": "raster", "source": "mml-base-source"}
  ]
}
```

### Ilmakuva's style: MapTiler Satellite Hybrid only — no MML fragment at all

**New in this revision.** Ilmakuva's generated style contains at most **one** raster source — there is no MML fragment to include, ever, for this selection:

```jsonc
{
  "version": 8,
  "glyphs": "https://fonts.openmaptiles.org/{fontstack}/{range}.pbf",
  "sources": {
    // Present only if MapTilerConfig.isMissing == false. No MML source exists
    // in this document at all — MmlConfig is never consulted for Ilmakuva.
    "maptiler-hybrid-source": {
      "type": "raster",
      "tiles": ["https://api.maptiler.com/maps/hybrid-v4/256/{z}/{x}/{y}.png?key=<MAPTILER_API_KEY>"],
      "tileSize": 256,
      "minzoom": 0,
      "maxzoom": 22
      // Confirmed directly from hybrid-v4's own authenticated TileJSON (§0) —
      // identical declared range to Outdoor; no longer an assumption.
    }
  },
  "layers": [
    {"id": "maptiler-hybrid-layer", "type": "raster", "source": "maptiler-hybrid-source"}
  ]
}
```

If `MapTilerConfig.isMissing`, Ilmakuva's generated style has **no raster source at all** — structurally identical to today's existing "blank style" fallback (glyphs URL, empty `sources`/`layers`), so the native map surface still exists and can still host the fishing-spot GeoJSON layers even with zero base-map imagery.

**Both MapTiler raster sources explicitly declare `minzoom: 0`, `maxzoom: 22`, and `tileSize: 256`, per the final authenticated TileJSON verification ([§0](#0-pre-implementation-verification-completed)).** MML's own raster source keeps its already-verified, unrelated `minzoom: 0`/`maxzoom: 18`. **MML and MapTiler intentionally do not share one artificial maximum zoom:** MML's WMTS service is native only to z18 (TD-026 §0), while both MapTiler products are natively served to z22 — forcing either to adopt the other's ceiling would either needlessly cap MapTiler's real available detail at z18, or claim real MML detail up to z22 that MML's own service does not have. MapLibre's ordinary overscale-beyond-`maxzoom` behavior (already relied on for MML today) continues to apply independently to each source past its own declared maximum.

**Critical, easy-to-get-wrong detail, unchanged from the original design and now confirmed to apply to both MapTiler products identically:** the tile token order is standard `{z}/{x}/{y}` — the *opposite* of MML's reversed `{z}/{y}/{x}` `ResourceURL` convention. **Do not apply MML's row-before-column reversal to either MapTiler tile URL.**

**Layer ordering remains deterministic by construction.** For Maastokartta, MapTiler Outdoor's entry precedes MML's in the `"layers"` array. For Ilmakuva, there is only one layer, so there is nothing to order. Fishing-spot layers are still added afterward, at runtime, with no `belowLayerId`, landing above whichever layer(s) the active style already contains — identical mechanism, now simply operating over a style that sometimes has one raster layer and sometimes has two.

### `WorldwideStyleFactory`'s composition logic, revised

```dart
// lib/core/map/worldwide_style_factory.dart (sketch — not final implementation)

class WorldwideStyleFactory {
  const WorldwideStyleFactory({
    required MapTilerStyleFactory mapTilerStyleFactory,
    required MmlStyleFactory mmlStyleFactory,
  }) : _mapTiler = mapTilerStyleFactory, _mml = mmlStyleFactory;

  final MapTilerStyleFactory _mapTiler;
  final MmlStyleFactory _mml;

  String styleFor(BaseMap baseMap) {
    final sources = <String, Object>{};
    final layers = <Object>[];

    switch (baseMap) {
      case BaseMap.maastokartta:
        if (!MapTilerConfig.isMissing) {
          _mapTiler.addOutdoorFragment(sources, layers);
        }
        if (!MmlConfig.isMissing) {
          _mml.addFragment(baseMap, sources, layers);
        }
      case BaseMap.ilmakuva:
        if (!MapTilerConfig.isMissing) {
          _mapTiler.addSatelliteHybridFragment(sources, layers);
        }
        // MmlConfig is never read here — Ilmakuva has no MML fragment.
    }

    return jsonEncode({
      'version': 8,
      'glyphs': _glyphsUrl,
      'sources': sources,
      'layers': layers,
    });
  }
}
```

This is a straightforward `switch` on `baseMap`, not a generic "combine a MapTiler fragment with a per-`BaseMap` MML fragment" function as the original design used — a direct, honest reflection of the fact that the two selections are no longer symmetric. Exact method names/signatures are an implementation-time detail; the structural point (an explicit per-selection branch, MML only ever consulted for Maastokartta) is the actual design decision.

### Why this preserves failure independence, without new monitoring code

Unchanged reasoning: because every style document is authored locally and never fetched from either provider over the network, `onStyleLoadedCallback` fires based on document parsing and glyph availability, not on any provider's tile-server health. For Maastokartta, a systemic outage of either MML or MapTiler Outdoor degrades to "that source's tiles do not render," with the other continuing unaffected — direct structural failure independence. For Ilmakuva, there is only one source to begin with, so there is nothing for it to be independent *from*; what remains guaranteed is that fishing-spot layers and other application-owned content are added and restored by the same mechanism regardless of whether Ilmakuva's own single raster source is currently rendering successfully.

This also directly explains the (unchanged) resolved product decision for Maastokartta's MML failure case: since MML's raster layer sits *above* MapTiler Outdoor's in the same style, an MML tile that fails to load behaves visually identically to one that is transparent by design (ADR-0009's verified no-data-tile behavior) — MapTiler's layer beneath shows through either way, with no code change needed to make that happen.

**This "transparent tile" reasoning is exactly what physical testing disproved as a *general* switching mechanism — see [§3A](#3a-maastokarttas-geographic-region-mechanism-revision-2) immediately below.** It remains true and unproblematic as a description of what happens on a per-tile basis when MML genuinely has nothing to draw for one tile; it is no longer relied upon to decide, at the composition level, whether MML should be part of the style at all for a given viewport.

---

## 3A. Maastokartta's Geographic Region Mechanism (Revision 2)

> **Superseded by [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4).** This section describes real, shipped code (`MmlCoverageRegion`, `MapScreen`'s `_mmlActiveForViewport`/`_onCameraIdle` region logic) that Revision 4 replaces, not extends — kept in full because it is an accurate record of that implementation and the investigation behind it, and because its polygon data and point-in-polygon logic remain directly useful inputs to §3C's own masking process. Do not use this section to (re-)implement viewport-center classification; see §3C's migration plan for exactly what is removed, what is repurposed, and why.

### What physical testing found, and why §3's original mechanism is insufficient

§3's original design included MML Maastokartta in every Maastokartta style, everywhere, relying entirely on MML's own tiles being transparent outside its real coverage to avoid showing anything wrong. Physical Android testing across a broader area than the original three spot-checks (Paris, Stockholm, Haparanda) found this assumption false in practice: MML rendered opaque gray/white blocks and visible large tile/coverage-boundary artifacts in some areas outside Finland — most visibly around Sweden and the Baltic region at low zoom, where MML's actual (and evidently somewhat irregular and inconsistently-behaved) response footprint became a visibly wrong shape drawn on top of the intended worldwide MapTiler Outdoor map. See ADR-0009's Revision Note 2 for the full account.

**The fix is architectural, not a tile-level patch:** stop including MML in the composed style at all once the viewport is far enough from Finland that MML has no business being requested — so its own inconsistent edge/no-data behavior never gets a chance to render anything, right or wrong. This requires the application to decide, itself, whether the current viewport is "in Finland" for this purpose — the manually-maintained boundary this project's earlier design specifically tried to avoid, now reintroduced because the alternative it was avoiding turned out not to work.

### Why an approximate polygon, not a rectangular bounding box, and not a "multi-box" approximation

Finland's real territory is long, narrow, and irregular — a wider southern/coastal region, a much narrower northwestern arm reaching toward Lapland, and an archipelago (including Åland) extending into the Baltic Sea. Two simpler alternatives were considered and rejected:

- **A single rectangular bounding box** tight enough to include all of Finland necessarily also includes large areas of Sweden (across the Gulf of Bothnia), Norway, Russia, and the Baltic Sea — precisely the regions physical testing found the bug in. This would not reliably fix the reported problem; it would only relocate it to wherever the box's corners happen to fall.
- **A small number of piecewise rectangles** ("multi-box," e.g. a wide southern box plus a narrower northern box) was considered as a smaller-effort middle ground. It meaningfully reduces — but does not eliminate — inclusion of non-Finnish territory near the coastline, and does not scale cleanly to Finland's full irregularity (the archipelago, Åland, the long eastern border). Recorded here as an acceptable, smaller-effort **interim** implementation increment if sourcing/authoring full polygon data is deferred, but not the target design, and any such interim step must be explicitly flagged as a known-incomplete approximation in code comments and the implementation notes when this document is finalized.

**Selected dataset — verified, not invented: [Natural Earth](https://www.naturalearthdata.com/), Admin 0 Countries, 1:50m scale**, the `Finland` (`ISO_A2 = FI`) and `Åland` (`ISO_A2 = AX`) features, **combined**.

Verified directly (not assumed) by downloading and inspecting the actual dataset (`ne_50m_admin_0_countries.geojson`, via the project's official `nvkelso/natural-earth-vector` GitHub mirror):

| Item | Verified value |
|---|---|
| License | **Public domain.** Natural Earth's own terms: *"All versions of Natural Earth raster + vector map data found on this website are in the public domain... No permission is needed to use Natural Earth. Crediting the authors is unnecessary."* No attribution UI burden is introduced by using this dataset (unlike MapTiler's own, unrelated, already-designed attribution requirement). |
| Geometry format | GeoJSON, `MultiPolygon`, coordinates in `[longitude, latitude]` order (standard RFC 7946 order), decimal degrees (WGS84 / EPSG:4326) — the same coordinate convention `LatLng`/this project's existing map code already uses (accounting for the lon/lat vs. `LatLng`'s lat/lon argument order when transcribing). |
| `Finland` feature at 1:50m | `MultiPolygon` with 8 parts, no interior holes: mainland (440 vertices, the dominant shape) plus 7 smaller southwestern-archipelago/coastal islands (7–16 vertices each, including Hailuoto near Oulu) — **519 vertices total**. |
| `Åland` feature at 1:50m | A **separate** Natural Earth admin-0 feature (its own `ISO_A2 = AX`), not included within the `Finland` feature at all, despite being Finnish territory — confirmed by direct inspection. 3 parts (main island 32 vertices, 2 smaller islets 10 each) — **52 vertices total**, extending as far west as lon 19.52°, which is *west* of mainland Finland's own westernmost point (lon 20.62°). **`Finland` alone would incorrectly exclude Åland; both features must be combined.** |
| **Combined total** | **571 vertices across 11 polygon parts** (8 + 3), no interior holes. |
| Resolution comparison (verified, not assumed) | The 1:10m (more detailed) equivalent gives Finland 3,225 vertices / 42 parts and Åland 472 vertices / 16 parts — **3,697 combined**, roughly 6.5× larger, for detail this application's purpose (a coarse "is the viewport roughly in Finland" check, already backed by a multi-kilometer hysteresis margin) does not need. 1:50m is the better fit; 1:10m would be unnecessary precision at meaningfully higher bundling/runtime cost. |
| Cold-launch sanity check (verified against real ray-casting, not assumed) | `MapScreen._initialCameraPosition.target` (61.9241°N, 25.7482°E) tests **inside** the mainland polygon — confirming Revision 2's cold-launch design (MML active immediately, no flash) is correct against the actual selected dataset, not merely plausible. Helsinki, Haparanda/Tornio, and Utsjoki (far north) all correctly test inside; Stockholm and a Baltic Sea midpoint correctly test outside. |

**Bundling:** 571 `[lon, lat]` coordinate pairs is small enough to embed directly as compile-time Dart constants (a `List<List<double>>` per polygon part, or equivalent) — **no runtime GIS library, no asset file parsed at runtime, no network fetch.** This satisfies the "bundle directly as Dart constants, no runtime GIS dependency" requirement exactly. The raw GeoJSON is not shipped with the app; only the extracted coordinate arrays are, generated once at implementation time from the official Natural Earth source and never modified by hand (no hand-drawn or invented coordinates, per the task's explicit instruction).

### Hysteresis

**Resolved design — asymmetric, not a single shrink/expand pair.** An initial symmetric design (shrink the polygon inward for the entry test, expand it outward for the exit test) was considered and **rejected**: shrinking the entry boundary would mean genuinely Finnish border/coastal territory — real towns, real MML data, never the source of the reported bug — would show MapTiler Outdoor instead of MML merely for being close to the actual border, which is exactly the kind of user-visible regression this milestone must not introduce. MML's own *data* was never the problem; only its behavior *outside* Finland was.

**Selected design:**

- **Entry (inactive → active):** the **real, unshrunk** Finland+Åland polygon is the entry boundary. The instant the viewport's center is inside the real polygon, MML becomes active — immediately, with no margin-related delay. This guarantees no legitimately Finnish location is ever denied MML merely for being near the edge.
- **Exit (active → inactive):** MML remains active until the viewport's center moves more than an **exit margin** distance outside the real polygon boundary — i.e., the *exit* boundary is the real polygon **expanded outward** by the margin, not the same boundary used for entry.
- **Dead zone:** the ring of territory between the real polygon edge and the outward-expanded exit boundary. A point in this ring that was previously **active** (approached from inside) stays active. A point in this same ring that was previously **inactive** (approached from outside, not yet having crossed the real polygon edge) stays inactive — it only activates once it actually crosses into the real polygon, per the entry rule above. This is not a symmetric "dead zone around the boundary" in the traditional Schmitt-trigger sense; it is a one-sided buffer that only ever *extends* MML's visibility slightly beyond the real border, never *withholds* it from within.
- **Initial state on cold launch:** `_mmlActiveForViewport` initializes to `true` synchronously from the fixed default camera position (verified inside the real polygon — see table above), independent of the hysteresis check entirely (there is no "previous state" on cold launch).

**Distance computation for the exit check:** the perpendicular distance from the viewport's center to the **nearest point on any polygon edge** (point-to-segment distance across all ~571 segments, not merely nearest-vertex distance), using a simple equirectangular approximation (longitude delta scaled by `cos(latitude)`) rather than a precise geodesic calculation — accurate enough at Finland's latitude range for a multi-kilometer margin, and meaningfully more accurate than a nearest-vertex-only approximation would be: mainland segment lengths verified directly from the dataset average ~8.3 km with a handful up to ~30 km, so a nearest-vertex-only distance could overestimate true distance by up to roughly half the longest nearby segment (~15 km) — a large fraction of a modest margin. Nearest-edge distance avoids that error for the same, still-simple, GIS-library-free implementation cost (a loop over segments with elementary trigonometry, no external package).

**Initial exit margin: 50 km.** Reasoning, not an arbitrary guess:

- Large enough to comfortably absorb ordinary incidental panning/jitter at the zoom levels where a user would realistically be examining a border area (border towns like Haparanda/Tornio are effectively adjacent — a 50 km margin covers this and more).
- Small enough to remain far short of the scale at which the original bug was actually observed ("Sweden, the Baltic region" — locations typically hundreds of kilometers from the border at the specific spots physical testing found broken), so tolerating MML slightly past the real border for this margin does not meaningfully risk reintroducing the visible-artifact problem this revision exists to fix.
- A simple, round, easily-explained number, consistent with "prefer a simple deterministic implementation over GIS complexity" — not tuned to any particular geometric feature.

This is an **initial** value, not a final one — it must be validated (and adjusted if needed) against real physical-device behavior (checklist items 21–23), per [§14 Risks](#14-risks-and-mitigations). No **entry** margin exists to tune (entry uses the real, unshrunk polygon directly, per the asymmetric design above).

### `MmlCoverageRegion` — a new, small, pure class

```dart
// lib/core/map/mml_coverage_region.dart (sketch — not final implementation)

/// Approximates the geographic area within which MML Maastokartta should be
/// included in the composed Maastokartta style, per ADR-0009 Revision Note 2
/// / MFS-027 FR-11. The polygon data itself (combined Finland + Åland,
/// Natural Earth 1:50m Admin 0 Countries, public domain — see §3A) is not
/// MML's own coverage extent (which is exactly the unreliable-at-the-edges
/// signal this class replaces) and not a raw rectangular bounding box
/// (which would still include large areas of Sweden/Norway/Russia/the
/// Baltic Sea).
class MmlCoverageRegion {
  const MmlCoverageRegion();

  /// Initial exit margin (§3A) — the distance beyond the real polygon
  /// boundary MML remains active for, once already active. Not used for
  /// entry: entry uses the real, unshrunk polygon directly, so legitimate
  /// Finnish/Åland territory is never denied MML for being near the edge.
  static const double _exitMarginKm = 50;

  /// Whether MML should be considered active (included) for [point], given
  /// whether it [wasActive] immediately before this check. Asymmetric, not
  /// a traditional symmetric dead-zone: entry only ever requires being
  /// genuinely inside the real polygon (no margin, no delay); exit requires
  /// moving more than [_exitMarginKm] past the real polygon boundary.
  bool isMmlActiveFor(LatLng point, {required bool wasActive}) {
    if (_insideRealPolygon(point)) {
      return true; // Entry boundary is the real, unshrunk polygon.
    }
    if (!wasActive) {
      return false; // Was already inactive and still outside — no change.
    }
    // Was active; now outside the real polygon. Stay active only while
    // still within the exit margin (nearest-edge distance, not merely
    // nearest-vertex — see §3A for why).
    return _distanceToNearestEdgeKm(point) <= _exitMarginKm;
  }

  bool _insideRealPolygon(LatLng point) {
    // Standard ray-casting point-in-polygon test across all 11 combined
    // Finland+Åland parts. Pure, deterministic, no native map surface or
    // runtime GIS dependency needed — see §12.
    throw UnimplementedError('sketch only');
  }

  double _distanceToNearestEdgeKm(LatLng point) {
    // Minimum perpendicular point-to-segment distance across all ~571
    // polygon edges, using a simple equirectangular approximation
    // (longitude delta scaled by cos(latitude)) — not a precise geodesic
    // buffer, deliberately, per "prefer simple deterministic over GIS
    // complexity."
    throw UnimplementedError('sketch only');
  }
}
```

This mirrors the existing project convention of small, pure, dependency-free logic classes in `core/map/` (`StyleRestorationTracker`, `FishingSpotLayerPresence`) — kept deliberately narrow (one class, a handful of small private helpers, no generalized "geofencing framework") per the task's explicit instruction not to introduce tile-by-tile hacks or a broader abstraction than this specific problem needs.

**Unchanged by Revision 3.** Everything in this section — the polygon data, `_insideRealPolygon`, `_distanceToNearestEdgeKm`, the asymmetric entry/exit hysteresis, the 50 km exit margin — remains exactly as designed and (as of this document's prior revision) implemented. Revision 3 does not modify `MmlCoverageRegion` at all; it adds an entirely separate, independent condition, described in [§3B](#3b-maastokarttas-zoom-gated-mml-inclusion-revision-3) immediately below.

### `MapScreen` wiring

- **New state:** `bool _mmlActiveForViewport`, initialized **synchronously** from `_initialCameraPosition.target` (not left to wait for the first `onCameraIdle` firing) — so a cold launch centered on Finland shows MML immediately, with no incorrect MapTiler-only flash, exactly as MFS-027's acceptance criteria already require for the default case.
- **New wiring:** `MapLibreMap(onCameraIdle: _onCameraIdle, ...)` — confirmed to exist as a zero-argument callback on both the widget and `MapLibreMapController` in the installed `maplibre_gl: ^0.26.2` ([§0](#0-pre-implementation-verification-completed)), not previously used by this screen.
- **New method `_onCameraIdle()`:** acts only while `_selectedBaseMap == BaseMap.maastokartta` (Ilmakuva is entirely unaffected — its style-building path never reads this state). Reads `_mapController?.cameraPosition?.target` (the same accessor `_onAddHerePressed` already uses elsewhere in this file), computes the new `mmlActiveForViewport` via `MmlCoverageRegion.isMmlActiveFor(target, wasActive: _mmlActiveForViewport)`. If unchanged, does nothing — no style regeneration, no wasted work. If changed, follows **exactly** the same generation-bump / regenerate-style / write-file / `setState` pipeline `_onBaseMapSelected` already uses for a manual switch (`_styleGeneration++`, rebuild via the style factory, write the file, `setState` updating `_currentStylePath` and calling `_styleRestoration.recordStyleApplied()`) — reusing 100% of the existing stale-generation-guard and restoration machinery with no new race-condition surface, since that machinery is already generation-agnostic about *why* a new generation was requested.
- **Style-building call site changes:** `WorldwideStyleFactory`'s `buildStyle(baseMap, {required mapTilerAvailable, required mmlAvailable})` (currently annotated `@visibleForTesting` in the Revision 1 implementation) becomes `MapScreen`'s actual production entry point for Maastokartta — the `@visibleForTesting` annotation must be removed, since `mmlAvailable` now needs to be computed richer than `styleFor()`'s own internal default: `mmlAvailable: !MmlConfig.isMissing && _mmlActiveForViewport`. Ilmakuva's call site is unaffected (`mapTilerAvailable: !MapTilerConfig.isMissing`, unchanged).
- **No persistence:** `_mmlActiveForViewport` is never written to `BaseMapPreferenceStore` — it is a live, viewport-derived value recomputed fresh from wherever the camera actually is, every session, never a user preference (MFS-027's persistence scope is explicitly unchanged by this revision).

### Border-crossing and zoom behavior

- A single deliberate, sustained pan across the region boundary triggers exactly one style regeneration per direction — the same visual/perf cost as today's already-tested manual Maastokartta ↔ Ilmakuva switch, not a new or heavier operation.
- Rapid, repeated deliberate crossing of a gap *wider* than the hysteresis margin could still trigger repeated regenerations; this is an accepted trade-off, no worse than this project's already-tested tolerance for rapid manual base-map switching (TD-026's "rapid switching" regression coverage already exercises this same underlying mechanism under repeated stress).
- The check is deliberately **zoom-agnostic**, based only on the viewport's center coordinate (matching the existing `_onAddHerePressed` precedent, which also reads only `cameraPosition.target`, never full visible bounds). This is a known, accepted simplification: at very low zoom, a large visible area could span both sides of the region boundary while the center-point check reports only one binary state for the whole style. Not solved by this document — flagged as an open question in [§14 Risks](#14-risks-and-mitigations) if physical testing shows it matters in practice.
- **Attribution follow-on:** `MapAttribution`'s existing Revision 1 visibility condition (`selectedBaseMap == BaseMap.maastokartta`) must be extended to also require `_mmlActiveForViewport` — MML's attribution must not be shown when the viewport is outside the region, for exactly the same misattribution reason it must not be shown for Ilmakuva (MFS-027 FR-21, revised).
- **Superseded by Revision 3, immediately below:** the third bullet above (zoom-agnostic check, flagged as an accepted simplification) is exactly the gap [§3B](#3b-maastokarttas-zoom-gated-mml-inclusion-revision-3) closes. It is left here, struck through in spirit but not in text, as an honest record of what this document originally accepted and why that acceptance did not hold up under further physical testing.

---

## 3B. Maastokartta's Zoom-Gated MML Inclusion (Revision 3)

> **Superseded before implementation began, by [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4).** Unlike §3A, nothing described in this section was ever built. Kept in full for its own genuine research value — in particular, the confirmed MapLibre layer-vs-source `minzoom` distinction, and the geometric/physical-test reasoning about low-zoom viewport extent, both of which remain accurate regardless of this section's mechanism being abandoned.

### What further physical testing found, and why §3A alone is insufficient

§3A's region check is deliberately zoom-agnostic (by design, per the bullet immediately above): it reads only the viewport's center coordinate, exactly mirroring the existing `_onAddHerePressed` precedent. This was flagged, at the time, as a known, accepted simplification — not an oversight — with an explicit note that it would be revisited "only if physical testing shows this produces a genuinely confusing result."

**Further physical Android testing has now shown exactly that.** With Maastokartta selected and the viewport center legitimately inside the real Finland/Åland polygon — not near the region boundary, not in the hysteresis dead-zone — zooming out far enough still reproduces the defect §3A exists to fix: large opaque gray/white blocks and visible tile/coverage-boundary artifacts. The mechanism is different from what §3A fixes, but the visible symptom is the same one ADR-0009 Revision Note 2 originally documented.

**Root cause:** §3A's check answers "is the center point inside Finland," a single binary fact about one coordinate. It does not, and structurally cannot, answer "is the *entire visible viewport* inside an area MML can render cleanly." Finland's own real extent is finite — roughly 540 km east–west at its narrowest useful cross-section, roughly 1,150 km north–south. At sufficiently low zoom, a viewport centered anywhere in Finland still visibly spans a geographic area larger than that, and once MML's layer is part of the composition at all (because the center-point check says "active"), MapLibre requests and renders its tiles across the *whole* visible area — including the portions genuinely outside Finland, where MML's own edge/no-data rendering was already shown (§3A, ADR-0009 Revision Note 2) not to be reliably clean.

This is not a flaw in the polygon data, the point-in-polygon test, or the hysteresis margin — all three continue to correctly answer the question they were built to answer. The gap is that a composition-level "include MML or don't, for the whole style" decision cannot, by construction, express "include MML, but only for the part of the viewport that's actually inside Finland" — MapLibre does not offer per-pixel/per-region source clipping at that granularity as part of this project's existing raster-source approach, and building one would be exactly the kind of tile-by-tile hack this project's task instructions explicitly rule out.

### Alternatives investigated

**1. A third Dart-side check, mirroring §3A's own mechanism (rejected).** Track the current zoom (via the same `onCameraIdle` callback §3A already uses), compute `zoom >= threshold`, and fold that into the same `mmlAvailable` computation §3A's `_onBaseMapSelected`/`_onCameraIdle` already feed into `WorldwideStyleFactory.buildStyle`, triggering the same generation-bump/regenerate/write/restore pipeline on every threshold crossing. This would work, but:

- It reopens exactly the flicker/thrashing risk §3A's own hysteresis margin exists to prevent — a continuous pinch-zoom gesture can cross a fixed zoom value many times in quick succession (values are not naturally "sticky" the way panning across a wide dead-zone already is), so this approach would need its **own** zoom hysteresis design (a margin, an asymmetric entry/exit rule, or equivalent) to avoid repeated full style regenerations — including 60-attempt fishing-spot-layer restoration retries — during ordinary zooming.
- It is a second, structurally similar but independently-tuned mechanism bolted onto the first, for a condition (zoom) that MapLibre can already evaluate natively and for free.

**Rejected**, in favor of the option below, once it was confirmed to actually work.

**2. A raster *source*-level `minzoom` (investigated, found insufficient on its own).** MML's raster source in the generated style already declares `"minzoom": 0` ([§3](#3-per-selection-style-composition)). Raising this value was the first, most tempting option, since it requires touching only one existing JSON field. **Investigated directly against the MapLibre style specification** (not assumed): a source's `minzoom`/`maxzoom` describe "the zoom level for which tiles are available, as in the TileJSON spec" — i.e., a statement about tile *availability*, not layer *visibility*. The specification is explicit about the symmetric, better-documented case: above a source's `maxzoom`, "data from tiles at the maxzoom are used when displaying the map at higher zoom levels" — this is the same overscale-beyond-maximum behavior [§3](#3-per-selection-style-composition) already relies on for MML today, past its documented `maxzoom: 18`. The specification does **not** give an equally explicit statement for the *below-minzoom* case, but by direct symmetry with the documented above-maxzoom behavior — and consistent with this project's own already-relied-upon precedent for the opposite edge — the safe assumption is that a source's `minzoom` does not simply hide the source below that zoom; it more likely causes the lowest available tile to be reused/stretched to cover the extra area (the mirror image of the confirmed overscale-above-maximum behavior). A stretched, blurry version of a gray/blank low-zoom tile is not an improvement over the current defect — it could plausibly look just as bad, or worse. **Source-level `minzoom` alone is therefore not relied upon as the fix.**

**3. A raster *layer*-level `minzoom` (selected).** Distinct from the source property above, and easy to conflate with it. **Investigated directly against the MapLibre style specification:** every layer type (including `"type": "raster"`) supports a top-level `minzoom`/`maxzoom` pair with unambiguous, spec-guaranteed semantics: *"The minimum zoom level for the layer. At zoom levels less than the minzoom, the layer will be hidden."* (and the symmetric statement for `maxzoom`). This is not tile-availability metadata subject to overscale/overzoom reuse — it is a rendering-level visibility rule: below the given zoom, the layer is not rendered at all, no tiles are requested for it, and whatever is beneath it (MapTiler Outdoor, unconditionally present per [§3](#3-per-selection-style-composition)) shows through completely and cleanly. Above the given zoom, the layer renders exactly as it already does today, with no change to its own source-level `minzoom`/`maxzoom`/overscale behavior.

**Selected**, for three reasons: (a) spec-guaranteed "hidden," not an inferred/ambiguous behavior; (b) purely declarative — a single static JSON field on the layer object [§3](#3-per-selection-style-composition) already generates, requiring no new Dart state, no new `MapScreen` method, and no interaction whatsoever with `_styleGeneration`/`StyleRestorationTracker`/`onCameraIdle`'s existing regeneration pipeline; (c) because it is evaluated by MapLibre on every render pass rather than through an application-triggered state transition, there is structurally nothing to "thrash" — the zoom-hysteresis concern that alternative 1 above would have required simply does not arise. This directly satisfies the task's own instruction to prefer the simpler architecture if it reliably solves the problem.

### The chosen mechanism, precisely

```text
MML active = configured (MmlConfig) AND geographic-region-active (MmlCoverageRegion, §3A, unchanged) AND zoom >= activation threshold
```

The first two terms are evaluated in Dart, exactly as §3A already does — unchanged. The third term is **not** evaluated in Dart at all for the purpose of deciding whether MML is part of the generated style; it is expressed once, statically, as `"minzoom": <threshold>` on MML's raster layer (`lib/core/map/mml_style_factory.dart`, [§3](#3-per-selection-style-composition)'s generated JSON), and evaluated natively by MapLibre on every frame. Whenever the first two Dart-evaluated terms are both true, MML's layer is present in the generated style (exactly as §3A already causes) — but it only actually renders once the zoom term is also satisfied, with no further application involvement.

**Net implementation footprint: one new field on one already-generated JSON object, plus one already-verified constant.** No new class, no new `MapScreen` state for style-building purposes, no new regeneration trigger, no new race to reason about. This is deliberately the smallest change that closes the gap — see [§13](#13-files-affected--file-plan) for the resulting (short) file-change list.

### Why MML's own WMTS `minzoom: 0`/`maxzoom: 18` (§0/TD-026) does not already answer this

MML's WMTS `GetCapabilities` response (TD-026 §0) confirms both `maastokartta` and `ortokuva` support TileMatrix identifiers `0` through `18` — i.e., the *server responds* at every one of those zoom levels. This says nothing about whether the *content* at low zoom levels is visually complete for a given viewport; a server can validly respond to a request with a mostly-blank or gray tile without that being an error. The `0`–`18` figure answers "does MML's service exist at this zoom," which is a different question from "does MML's service look good at this zoom, for a viewport that only partially overlaps Finland" — the second question is what this section resolves, and TileMatrix availability alone cannot answer it.

### The activation threshold — not yet determined; a physical test is required, not a guess

**This document deliberately does not fix a specific zoom number.** Per the task's own explicit instruction, and consistent with how this project has already handled a comparable "we don't actually know the right number yet" situation ([§0](#0-pre-implementation-verification-completed)'s original, now-resolved MapTiler zoom-range verification), a plausible-sounding value (z7, z8, z9, or any other single figure) is not adopted here without evidence, and this document is a poor substitute for the one kind of evidence that actually settles the question: looking at real, rendered MML tiles at a range of zoom levels.

**Why this could not be determined during this investigation:** MML's WMTS tiles require a valid `MML_API_KEY`; no such key is available in the environment this investigation was performed in (checked directly — no `.env` file, no matching environment variable). This mirrors [§0](#0-pre-implementation-verification-completed)'s own earlier finding for `MAPTILER_API_KEY` before it later became available — the correct response then, as now, is to name the exact verification still needed rather than substitute a guess.

**A rough geometric estimate — shown for transparency, explicitly not a substitute for the physical test below.** Using the standard Web Mercator relationship (meters per pixel ≈ 156,543.03 × cos(latitude) / 2^zoom) at Finland's own latitude (~62°N) and a typical phone viewport width of roughly 400 logical pixels:

- Viewport width in km ≈ 400 × (156,543.03 × cos(62°) / 2^z) / 1000 ≈ 29,399 / 2^z.
- Setting this equal to Finland's own narrower (east–west) extent, ~540 km, gives 2^z ≈ 54, i.e. **z ≈ 6**.
- A wider viewport (~800 px, a large phone or tablet in landscape) shifts this to **z ≈ 7**.

This suggests the true "MML content visually fills the viewport with no non-Finland padding" crossover is *plausibly* somewhere in the range **z6–z8** — but this estimate only reasons about whole-viewport-vs-whole-country area overlap. It cannot account for two things the physical test below specifically checks: (a) MML's own tiles may show gray/blank padding *within* a single tile even before the whole viewport exceeds Finland's footprint (pushing the real threshold higher), and (b) MML's real cartographic content might not extend cleanly all the way to the coastline/land border at every zoom (also pushing it higher, in border-proximate views specifically). **Treat z6–z8 only as the range the physical test below should start sampling from, not as a candidate final answer.**

**Notable, load-bearing consequence of this range:** it is *higher* than this application's own current cold-launch zoom (`_initialCameraPosition`'s `zoom: 5`, unchanged since before this milestone). If the physically-determined threshold lands anywhere in or above the estimated range, **a cold launch will legitimately show MapTiler Outdoor only, with MML appearing once the angler zooms in past the threshold** — not a bug, but a genuine, deliberate behavior change from this document's own Revision 2 acceptance expectation ("MML shown immediately, no incorrect momentary MapTiler-only flash"). This is flagged explicitly here as a product/implementation decision point that this document does not resolve unilaterally: implementation may either (a) accept this as the new, correct cold-launch behavior, revising the relevant Revision 2 language accordingly, or (b) raise `_initialCameraPosition`'s zoom to be at or above the determined threshold, so cold launch continues to show MML immediately when centered inside Finland. See [§14 Risks](#14-risks-and-mitigations).

#### Required physical test protocol

**Purpose:** determine the lowest zoom level at which MML Maastokartta's rendered content visually fills the viewport with real cartographic detail, and no visible gray/white padding or tile-boundary seam, for a viewport centered legitimately within the Finland/Åland region.

**Setup:** a physical Android device (or an emulator with real network access) with a valid `MML_API_KEY`; Maastokartta selected; MML's layer visible at every zoom for the duration of this test (i.e., run this test *before* the layer-`minzoom` value is set to anything other than its current `0`, or temporarily override it, so the behavior being measured is not itself hidden by the very mechanism being calibrated).

**Test points** (four, chosen for stated geometric reasons, not arbitrarily):

1. **Central-southern Finland interior** (e.g., near Jyväskylä, ~62.24°N, 25.75°E) — Finland's most populated latitude band, and, per the Web Mercator relationship above, the lowest-latitude (and therefore widest-tile-per-zoom) interior test point, making it a reasonable worst-case candidate among interior points.
2. **A point near Finland's narrowest east–west cross-section** — to find where viewport width first exceeds available MML content specifically along the dimension the estimate above identifies as binding.
3. **A high-latitude interior point** (e.g., near Rovaniemi, ~66.5°N) — to check whether the higher-latitude tile-compression effect (each tile covers less ground at higher latitude, for the same zoom) meaningfully changes the answer there, confirming or correcting the assumption that the southern point is the binding case.
4. **A coastal/border-proximate point already inside the region** (e.g., near Vaasa, or the southwestern archipelago) — to check whether coastline proximity requires a *higher* threshold than a deep-interior point, since less of the viewport is genuinely "Finland" at the same zoom near a coast.

**Procedure, for each test point:** center the camera exactly on the point; starting at z3 and stepping up one level at a time through at least z9, capture a screenshot at each level; for each screenshot, record whether (a) any gray/white blank padding is visible anywhere in the viewport, (b) any visible tile-edge/coverage-boundary seam is visible, and (c) the viewport shows real, recognizable Finnish topographic content edge-to-edge. Record the lowest zoom level at which (a) and (b) are both "no" and (c) is "yes" for that point.

**Determining the threshold:** the recommended activation `minzoom` is the *highest* (most conservative) of the four per-point results — i.e., the value that is confirmed clean at every tested location, not merely the most favorable one. Round up to the next whole zoom level if the confirmed-clean result is fractional (MapLibre supports fractional zoom, but a whole-number threshold is simpler and more predictable to reason about and test).

**Additional check, same session:** at each test point, zoom slowly *through* the determined threshold (both directions) and confirm the transition is visually smooth, with no perceptible flicker, stutter, or delay beyond ordinary tile loading — this doubles as direct physical confirmation of this section's own "no zoom hysteresis needed" claim, not merely a theoretical inference from the style specification.

This protocol, and its result, must be recorded in this section once run — implementation of the `minzoom` value must not begin from an assumed or invented number.

### Interaction with §3A — independent, both required

The geographic region check ([§3A](#3a-maastokarttas-geographic-region-mechanism-revision-2)) and the zoom gate (this section) answer different questions and do not replace one another:

- §3A: is the viewport's *location* inside Finland?
- §3B: is the viewport's *extent*, at the current zoom, small enough that MML's content can be trusted to fill it cleanly?

Both must hold for MML to actually be visible. A viewport can be geographically inside Finland (§3A active) but zoomed too far out (§3B inactive) — MapTiler Outdoor alone is shown. A viewport can be zoomed in close enough (§3B satisfied) but located outside Finland entirely (§3A inactive) — MapTiler Outdoor alone is still shown, exactly as it already is today. Neither condition is a proxy for the other.

### `MapScreen` wiring

- **Style-building path: no change to the region-check machinery.** `_onBaseMapSelected`/`_onCameraIdle`/`_stylePathFor`/`WorldwideStyleFactory.buildStyle` continue to compute `mmlAvailable` exactly as [§3A](#3a-maastokarttas-geographic-region-mechanism-revision-2) already established (`!MmlConfig.isMissing && _mmlActiveForViewport`). The zoom gate is never folded into this boolean, and never triggers `_styleGeneration++` — it is not a condition the style-regeneration pipeline needs to know about at all, since MapLibre enforces it independently once the layer is present.
- **`MmlStyleFactory` change:** the generated MML raster layer object gains one new field, `"minzoom": <threshold>` (a new public constant, e.g. `MmlStyleFactory.activationMinZoom`, so it is defined once, alongside MML's other already-verified zoom facts, and referenced — not duplicated — wherever else it is needed). The generated *source* object's own `"minzoom": 0` is unchanged (§0/TD-026's already-verified WMTS availability fact; a different property, a different meaning — see above).
- **A second, narrow, non-regenerating use of the current zoom: `MapAttribution`'s visibility.** [§11](#11-attribution-design) already conditions `MapAttribution` on `_mmlActiveForViewport` (region + config). Once MML's *rendering* also depends on zoom, showing MML's attribution below the activation threshold would misattribute content that is not actually visible — the same principle §3A's own attribution follow-on already established for the region boundary. Because this decision does not drive any style regeneration, it is implemented as a small, independent read: `_onCameraIdle` (already firing at the right time, already reading `cameraPosition`) additionally reads `cameraPosition.zoom`, compares it against `MmlStyleFactory.activationMinZoom`, and updates a new, separate boolean (e.g. `_mmlZoomActive`) via a plain `setState` — no generation bump, no file write, no interaction with `StyleRestorationTracker`. `MapAttribution`'s visibility condition becomes `selectedBaseMap == BaseMap.maastokartta && _mmlActiveForViewport && _mmlZoomActive`. Cold-launch initialization mirrors `_mmlActiveForViewport`'s own pattern: computed synchronously from `_initialCameraPosition.zoom`, not left to wait for the first `onCameraIdle`.
- **This narrow attribution read needs no hysteresis of its own, for the same reason the style-rendering gate doesn't:** updating a plain boolean via `setState` is cheap (a widget rebuild, not a style reload), so even if the attribution mark toggles once or twice during a slow zoom held exactly at the threshold, the cost is a small UI flicker, not a repeated expensive reload — a materially different risk profile from what alternative 1 (a Dart-side regeneration trigger) would have created. A simpler, defensible alternative exists if even this narrow read is judged not worth its small complexity: leave `MapAttribution`'s condition as region-plus-config only, accepting that MML's attribution may occasionally be shown a little before its content is actually visible (over-attribution, not under-attribution) — recorded here as a real, available trade-off, not silently decided.

### Sources consulted for this section

The layer-vs-source `minzoom`/`maxzoom` distinction above was verified directly against MapLibre's own current style specification, not assumed from memory or inferred solely from this project's own existing (source-level) usage:

- `https://maplibre.org/maplibre-style-spec/layers/` — confirms the layer-level `minzoom`/`maxzoom` "hidden below/at-or-above" semantics quoted above, verbatim.
- `https://maplibre.org/maplibre-style-spec/sources/` — confirms the source-level `minzoom`/`maxzoom` wording ("zoom level for which tiles are available... as in the TileJSON spec") and the explicit above-`maxzoom` overscale statement; the specification does not give an equally explicit statement for the below-`minzoom` case, which is exactly why source-level `minzoom` alone was not relied upon (see "Alternatives investigated" above).

No live MML tile data was available to consult during this investigation (no `MML_API_KEY` present in the environment) — this is recorded as the reason the activation threshold itself remains an open, physical-test-gated item, not resolved by documentation research alone.

---

## 3C. On-Device Pixel-Level MML Coverage Masking (Revision 4)

### Why this section exists, in one paragraph

Direct decoding of real MML WMTS tiles found that out-of-coverage areas are rendered fully opaque — not transparent — by MML's own server, confirmed both structurally (no PNG `tRNS` chunk, no alpha channel, in any of four representative tiles) and by content (a Finland/Russia border tile was 69.81% a single, flat, textureless `RGB(204,204,204)` gray, confirmed visually to correspond exactly to Russian territory: zero roads, zero labels, zero variation). No decision about whether MML's *layer* belongs in the style — evaluated per viewport (§3A), per viewport-and-zoom (§3B), or any other way — can make already-opaque *pixels* transparent. The only way to achieve a genuinely clean border is to change the pixels themselves, before MapLibre renders them. This section designs how.

### Alternatives investigated and rejected before choosing this design

Restated briefly from the investigation that led here (full detail in the session's own record, condensed to conclusions):

1. **Native MapLibre style/expression mechanism** — rejected. The complete, verified raster paint-property list (`raster-opacity`, `-hue-rotate`, `-brightness-min/max`, `-saturation`, `-contrast`, `-resampling`, `-fade-duration`) contains nothing that maps a source color to alpha or reads a pixel's own RGB to decide transparency. No "clip" or "mask" layer type exists in MapLibre for 2D raster content.
2. **A small native extension via `CustomLayer`** — rejected. The API exists on MapLibre Native Android but is documented, verbatim, by its own maintainers as *"Experimental feature. Do not use."* Building on it would also mean writing genuinely new, non-trivial native rendering code (OpenGL on Android, a separate Metal implementation on iOS) — not a "small bridge."
3. **Forking/patching MapLibre Native's compiled raster shader** (`raster.fragment.glsl`) — rejected. Confirmed from source: the shader is a fixed hue/saturation/contrast/brightness/opacity pipeline with no color-conditional branch of any kind. Adding one means maintaining a custom-built fork of the renderer, for both platforms, indefinitely re-merged across every future MapLibre upgrade.
4. **GPU polygon masking using the Finland geometry directly** — rejected for the same reason as 1–3: no exposed hook exists to feed geometry into the raster shader at all without one of the above.
5. **Paid MML WMS with `TRANSPARENT=TRUE`** — not rejected outright, but not selected for this milestone. Confirmed technically real (MML's WMS documents `transparent=true` PNG support for `maastokartta`) and confirmed MapLibre Native's core (`src/mbgl/storage/resource.cpp`) implements the `{bbox-epsg-3857}` WMS-as-tiles token our stack would need. Not selected because it requires leaving MML's free "avoin" tier for a paid contract (minimum €247.40/year, confirmed from MML's current 2026 price list) for a benefit (whether the border is actually clean under WMS) that was never verified live, and because the on-device approach below achieves the same goal with the currently-used free service and stays fully within this project's control. Remains available for future reconsideration if real usage ever makes it more attractive than the on-device approach.
6. **On-device (client-side) tile masking — selected.** Ordinary, portable Dart code, run entirely on the angler's own device, transforming MML's already-fetched tile bytes before handing them to MapLibre. No native build risk, no shader fork, no per-platform reimplementation, no new MML cost. This is the design below.

### Coverage geometry

**Retained: the existing Natural Earth 1:50m Finland+Åland polygon (571 vertices/11 parts), unchanged from §3A.** It was originally sourced for viewport-center classification, not pixel-level rendering, so its adequacy for the new purpose needed re-examination, not an automatic pass — the following reasoning is the result of that re-examination, not an assumption that the old choice still applies unchanged in spirit.

**What changes is not the polygon's precision, but what it is used to approximate.** The mask must represent where MML's cartography is genuinely useful, and real MML tiles (confirmed during the investigation behind this revision) show meaningful content — labeled bays, straits, and open sea, not merely land — some distance beyond the immediate coastline: a border tile near Tornio showed correctly labeled "Perämeri / Bottenviken" sea content, and a tile over the Åland/SW-archipelago area showed correctly labeled "Itämeri Östersjön" Baltic Sea content well out from any coastline. **A mask that stopped exactly at the land/island polygon's own edge would incorrectly clip away real, useful MML sea content** — precisely the mistake this document's own task explicitly warns against. The mask geometry is therefore the existing land+island polygon **expanded outward by a coastal/territorial-water buffer**, not the raw polygon itself.

- **Mainland land border (Sweden, Norway, Russia):** the existing polygon's land-border edge, buffered by the same uniform amount applied everywhere, for implementation simplicity — there is no "useful sea content" argument on a pure land border, unlike the coastline, and real measurement (below) found this is in fact the *tightest* constraint on the buffer's maximum safe size, not merely a low-priority case.
- **Åland:** unchanged treatment from §3A — already included as a combined feature in the existing polygon data; the buffer applies to its coastline exactly as it does to the mainland's.
- **Archipelago and small islands:** the specific area most likely to show visible imprecision from the underlying 1:50m polygon's own simplification (very small skerries may not be individually resolved) — flagged as an accepted v1 limitation, not solved by the buffer, and the most likely trigger for a future upgrade to a higher-precision or MML-sourced polygon if physical testing shows it matters visually.
- **Territorial/coastal waters:** approximated by the outward buffer described below, not modeled as a separate, precise maritime boundary (Finland's actual territorial sea/EEZ boundary is not the same thing as "where MML's raster has useful content," and this document does not attempt to source or model the former).
- **Lakes crossing borders:** not special-cased. The existing polygon's border line already runs through such lakes correctly (unchanged from §3A); MML's own tiles render real water content on both sides of a border lake (confirmed during this investigation, via a large lake near the Finland/Russia border), so the mask simply follows the land polygon's own border line through the lake, same as anywhere else.

**Resolved: 10 km, verified directly against real MML WMTS tiles, not invented.** Six real `maastokartta` z=8 tiles (~256×256 px, ~0.26–0.31 km/px, ~66–80 km wide at these latitudes) were fetched with a real credential and analyzed pixel-by-pixel (PNG chunk parsing, RGBA decode, connected-component analysis of the flat `RGB(204,204,204)` no-data fill, and column/row-by-column gray-fraction profiling), at: the southern coast/Gulf of Finland (Helsinki), the Turku archipelago, west of Åland toward Sweden, the Bothnian Bay (Perämeri), the eastern Gulf of Finland at the Russia border (Virolahti), and a central-Baltic open-sea negative control.

**Central finding, not anticipated when this section was first written: the flat-gray no-data defect is a *land* phenomenon, not a *sea* one.** The open-sea control tile — the farthest point from any coastline tested — showed **zero** gray pixels: 100% of it was ordinary, uniform "sea" fill, the same color used for real Finnish waters. Three of the four coastal/archipelago tiles (Helsinki Gulf, Turku archipelago, Bothnian Bay) likewise showed **no meaningful gray at all** — real content (islands, labels, roads, sea) continued cleanly to the tile's edge, at least ~45–70 km from the coast in each case, with the true limit not reached within the tile. **Gray no-data only appeared adjacent to actual neighboring land** — Sweden (west of Åland) and Russia (east of the Gulf of Finland border) — confirming the buffer's real purpose is narrower than originally framed: it exists to safely bridge real Finnish/Åland *coastal water* without reaching into a *neighboring country's own unmapped land*, not to chase an open-sea cutoff that, at this zoom and these locations, does not exist.

Measured margins (real, gray-free content between the Natural Earth polygon edge and the nearest neighboring no-data land), using a column-by-column gray-fraction profile to find the true transition rather than a single eyeballed point:
- **West of Åland, toward Sweden:** gray fraction falls from 100% to under 1% over a narrow band, with clean (<0.5%) content resuming by approximately 19.24–19.30°E — a gap of **~14–18 km** from Åland's own westernmost Natural Earth vertex (19.52°E).
- **Eastern Gulf of Finland, Russia border (Virolahti, 27.68°E):** gray is negligible (<1%) until about 27.79°E, then ramps up (a gradual, not sharp, transition — consistent with a diagonal border line crossing the tile at an angle) — reaching 5% by ~27.85°E and 14% by ~27.90°E. Using "not yet meaningfully present" (≤5%) as the safety threshold gives a margin of **~6–10 km** from Virolahti's own coastal longitude — the **tightest constraint found anywhere tested**, and the value the uniform buffer is actually bounded by.
- **Helsinki Gulf, Turku archipelago, Bothnian Bay:** no gray found at all within **~45–70 km** tested in each direction — the true safe extent is larger than what was measured, not smaller.

**Buffer candidates compared against this evidence:**

| Candidate | Safe against Åland/Sweden margin (~14–18 km)? | Safe against Russia margin (~6–10 km)? | Verdict |
|---|---|---|---|
| 10 km | Yes, comfortably | At or just above the tightest measured point — some residual risk in that one specific stretch, not a comfortable margin | **Selected** — the only candidate safe almost everywhere, with one narrow, explicitly flagged exception |
| 20 km | Yes | No — already within the range where Russia-side gray is climbing past 5–14% | Rejected — reintroduces a real, if smaller-than-original, gray artifact at the eastern border |
| 30 km | Marginal/no | No — well past the point where Russia-side gray reaches 14%+ | Rejected |
| 50 km | No | No | Rejected — approaches the scale of the original defect this whole revision exists to fix |

**Recommended v1 buffer: 10 km, uniform.** It is comfortably inside the Åland/Sweden margin, and is the only tested candidate that does not clearly reintroduce a measurable amount of neighboring gray no-data at the Russia border — though it sits close enough to that specific ~6–10 km measured margin that it is not a comfortable safety cushion there, unlike everywhere else tested. **This is flagged explicitly, not smoothed over:** physical Android testing (checklist below) must specifically verify the Virolahti-area stretch shows no residual gray sliver before this is treated as fully settled; if it does, a value below 10 km (not tested here) would need to be tried, since every other tested candidate is unambiguously less safe, not more.

**A single uniform buffer is retained for v1**, per the evidence: even though the safe margin varies severalfold by direction (~6–10 km at the tightest land border vs. ~45–70 km+ untested-but-clear at sea), a uniform value calibrated to the *tightest* case is safe everywhere else by construction, and the cost of under-buffering the wide-open sea directions is low (MapTiler shows a little sooner than MML's own generic sea fill would have — a cosmetic difference, not a defect, since there is no gray to mistakenly include or exclude there in the first place). A non-uniform (land-vs-sea) geometry was considered and is not adopted for v1 on exactly this reasoning: it would add real complexity to solve a problem (short-changing open sea) that evidence shows is low-severity, not the reverse.

**Not resolved by this test, and not required to lock the distance above:** whether fishing-relevant depth markings/contours are present within the buffered zone specifically. Depth-contour-level nautical detail is generally a higher-zoom rendering than z=8; none of the six tiles analyzed here were captured at a zoom where that level of detail would be expected to appear either way. This is a separate, still-open question from "where does the flat-gray defect begin" — recommended as a targeted higher-zoom (e.g. z12+) spot-check during physical Android testing, not a blocker for implementing the buffer value now locked above.

**Whether to upgrade from Natural Earth to an official MML/NLS boundary dataset — not adopted for v1, revisited only if evidence requires it.** An authoritative MML boundary + coastline dataset is obtainable (MML's open "Division into administrative areas (vector)" product, CC BY 4.0, ETRS-TM35FIN/EPSG:3067 — though it explicitly does *not* include shorelines and would need combining with a separate MML shoreline source; MML's own open vector Maastokartta product is a more direct candidate, since it is the same underlying dataset family as the raster tiles themselves and does include waterways). This was not adopted now because: the now-locked 10 km buffer already introduces several-kilometer-scale positional uncertainty that comfortably exceeds the precision difference between Natural Earth 1:50m and a finer official source for a region the size of Finland; adopting it would add real, new sourcing work (combining two datasets, or extracting from the vector Maastokartta product) and a new CC BY 4.0 attribution obligation Natural Earth's public-domain license does not require; and it is not free of its own coordinate-system conversion work (ETRS-TM35FIN → WGS84). **The Turku archipelago and Åland tiles analyzed above both showed dense real content (small islands, skerries) not individually verified against the underlying Natural Earth vertex data** — the 10 km buffer likely absorbs most positional gaps this could cause, but this remains an accepted, not fully closed, residual risk. **Revisit this decision specifically if physical Android testing shows the *underlying polygon's own precision* — not the now-locked buffer distance — is the visible bottleneck** (most likely in the archipelago, per the bullet above).

### Local tile-masking service

Conceptually: `http://127.0.0.1:<port>/mml/{z}/{x}/{y}.png`, an app-local HTTP listener MapLibre's MML raster source points at instead of MML directly.

**Port allocation: always ephemeral (`HttpServer.bind(InternetAddress.loopbackIPv4, 0)`), never a fixed hardcoded port.** This was a genuine design question, not a default: a fixed port risks a bind failure if something else (or a not-yet-terminated previous instance of this same app) already holds it; an ephemeral port avoids that entirely, at the cost of the port varying between app sessions. That cost turns out to be negligible once the caching design below is understood: the actual expensive work (fetch/decode/mask/encode) is cached at *this service's own* disk-cache layer, keyed by `z/x/y` and independent of port — so a new port each session only means MapLibre's own internal tile cache starts cold each time (one extra fast loopback round-trip per tile that session, satisfied immediately from this service's own warm cache), not that any real work is redone.

**Lifecycle:** owned by `MapScreen`, following the same pattern already established for other per-session resources (`AppDatabase`, `CatchPhotoStorage`, etc.) — started early in `initState` (async), its actual bound port awaited before the *first* style is ever built (extending the existing `_initializeBaseMap` loading gate, not introducing a second one), and stopped in `dispose`. `WorldwideStyleFactory`/`MmlStyleFactory` receive the local base URL (`http://127.0.0.1:<port>`) as an explicit parameter — analogous to how `apiKey` is already threaded through today — rather than a compile-time constant, since the port is only known at runtime.

**What happens before the service is ready:** nothing MML-related is requested before it is, by construction — the existing loading gate already defers the first style build until initialization completes; extending it to also await the local service's own startup keeps this invariant rather than introducing a new race to reason about.

**Concurrency:** `dart:io HttpServer` already handles multiple simultaneous connections without extra work, *provided the per-request handler does not block the event loop*. The HTTP listener itself (accept, parse, route) stays on the main isolate (cheap, I/O-bound, non-blocking); the CPU-heavy part of each request (decode/rasterize-mask/encode, for boundary tiles only — see classification below) is dispatched to a worker isolate (via `compute()` or a small persistent isolate pool), so panning/zooming stays responsive even while several boundary tiles are being processed in the background. This directly addresses the explicit "must not block the Flutter UI isolate" requirement.

**Duplicate concurrent request coalescing:** an in-memory `Map<String, Future<Uint8List>>` of in-flight requests, keyed by `z/x/y`. A new request for a key already in flight awaits the same `Future` rather than starting a second fetch/mask/encode; the entry is removed once that `Future` completes (success *or* failure), so a request arriving after a failure gets a fresh attempt rather than being poisoned by a stale one.

**Cancellation:** recommended, not required for v1 correctness — if the underlying connection for a request closes early (MapLibre/the native tile pipeline no longer needs a tile the viewport has since panned away from), the in-flight fetch/processing may be aborted to save battery/CPU; if not implemented, the worst case is finishing work nobody currently needs (wasted, not incorrect — the result is still cached for potential reuse if the user pans back).

**Request timeouts:** the local service's own outbound fetch to MML uses a bounded timeout (10 s, matching the existing `_startStyleLoadTimeout` precedent already used elsewhere in this codebase, for consistency rather than a new arbitrary figure) — see Failure Behavior below for what happens when it's exceeded.

**Android/iOS loopback behavior:** same-process, same-device loopback networking, no special permission beyond the ordinary internet permission this app already requires for MapTiler/MML today. **Flagged, not silently assumed:** Android's Network Security Config cleartext-traffic (non-HTTPS) restriction is generally understood to exempt loopback addresses by default, but this has not been independently verified against this project's specific Android manifest/config and should be confirmed (or an explicit loopback exception added) during implementation, before relying on it.

**z/x/y ordering:** the local endpoint's own URL path uses the standard `{z}/{x}/{y}` order (matching MapLibre's own default substitution and this project's MapTiler convention) — the service translates this internally into MML's own reversed `{z}/{y}/{x}` `ResourceURL` convention when constructing its real upstream request, so MapLibre and MapScreen never need to know about MML's quirky ordering at all; that knowledge stays fully contained inside the local service, exactly where `MmlStyleFactory` already contains it today.

### Tile classification

For a requested `z/x/y`, computed from its Web Mercator tile bounds against the buffered coverage geometry (§3A's existing point-in-polygon primitives, reused, not reimplemented):

- **A — entirely inside coverage:** all four tile corners are inside the polygon, no polygon vertex falls within the tile's bounding box, and no polygon edge crosses any of the tile's four boundary edges. *(The full test, not a 4-corners-only shortcut — a coarser test can misclassify a tile a polygon edge dips through without touching a corner, most likely at low zoom, which is exactly the scenario this whole revision exists to get right.)* → the tile is fetched from MML and passed through **unmodified, no decode, no re-encode** — the cheapest possible path.
- **B — entirely outside coverage:** the mirror-image test (all corners outside, no vertex or edge intersects the tile bbox). → **no MML fetch at all** — return one shared, pre-built, fully-transparent 256×256 PNG, identical for every such tile, computed once.
- **C — everything else (the boundary case):** the tile genuinely straddles the coverage edge → fetch, decode, mask, re-encode (below). This is the only case that pays real image-processing cost, and it is concentrated exactly along Finland's coastline/border — a bounded, cacheable minority of all tiles, not the common case.

### Boundary-tile pixel masking algorithm

For classification-C tiles:

1. Compute the tile's Web Mercator/lon-lat bounds (standard slippy-map tile math).
2. Fetch the real MML tile through the service's own internal request (the existing WMTS URL template, API key attached server-side of this step only).
3. Decode the PNG (`package:image`, already a project dependency).
4. **Rasterize the coverage polygon into a 256×256 (or supersampled, see below) alpha mask** using a standard scanline polygon-fill algorithm (one pass over polygon edges producing per-scanline inside/outside spans, rather than naive per-pixel point-in-polygon testing against every vertex — the latter would be needlessly expensive at 65,536 pixels × ~571+ vertices per boundary tile). Multi-part geometry (Finland's 8 parts + Åland's 3) is handled the same way §3A's own `_insideRegion` already does — a pixel is inside the mask if inside *any* part; there are no interior holes in the current data, so no special hole-handling is required for it, though the standard even-odd/nonzero fill rule used generalizes correctly if that ever changes.
5. **Anti-aliasing:** rasterize at a higher internal resolution (e.g. 4×, i.e. 1024×1024 boolean inside/outside) and downsample to 256×256 by averaging each block into a fractional alpha (0–255) — a standard, simple supersample-and-average technique that avoids a visibly jagged, pixel-stair-stepped mask edge without needing exact fractional polygon-coverage math per pixel.
6. **Compose:** output RGBA = original MML pixel's RGB, **unchanged**, with alpha = the rasterized mask value (255 fully inside, 0 fully outside, smoothly graded at the edge). Inside pixels are never recolored, cropped, or otherwise altered — only their alpha channel is affected, and only at/near the boundary.
7. **Encode** as a standard RGBA (PNG color type 6) image — not palette-indexed, since the masking legitimately produces many distinct alpha values for the same source color near the edge, which palette+`tRNS` cannot represent per-pixel without artificially duplicating palette entries. The resulting file is larger than MML's own often-palette-indexed originals; accepted, since the result is cached (§ below) and this cost is paid at most once per tile.

### Caching

Two tiers, deliberately bounded (see explicit non-goal below):

- **In-memory LRU** (a few hundred tiles, a few MB) of recently-served masked/pass-through bytes — the fastest path for tiles the angler is actively panning near.
- **Disk cache**, persistent across app sessions, of the *final processed output only* — for classification-A tiles this is the pass-through bytes; for classification-C tiles it is the masked result. **No separate cache of raw/unmasked MML bytes is kept** — once a boundary tile is masked, the raw fetch has served its purpose and is discarded; keeping it would double disk usage for no benefit. Classification-B tiles need no per-tile cache entry at all — the single shared transparent PNG is reused for all of them.
- **Cache key:** `z/x/y`, namespaced by a mask/algorithm version segment in the cache directory path itself (e.g. `mml_tile_cache/v1/{z}/{x}/{y}.png`). Bumping the version (if the coverage geometry, buffer distance, or masking algorithm ever changes) naturally creates a fresh namespace — old-version files are orphaned, not silently reused incorrectly; a v1→v2-style bump should also delete the old version's directory on the next startup to reclaim space, rather than accumulating stale versions indefinitely.
- **Eviction:** LRU by last-access time, with an explicit total-size or tile-count cap. **This is an ordinary, bounded performance cache — not an offline-map-download feature**, echoing the explicit instruction not to let it become one: no tile's continued presence is guaranteed, there is no user-facing "download this area for offline use" affordance, and this remains squarely within the "ordinary client-side caching for a single end-user's own use" both MML's and MapTiler's terms already permit and this project already relies on elsewhere (see ADR-0009's updated Offline and Caching Implications).
- **Concurrent-request coalescing** is covered under the local service's own design above — it is the same mechanism, not a separate cache-layer concept.
- Boundary-mask bitmaps (the rasterized alpha grid itself, independent of a specific tile's MML pixel content) are **not** separately cached in v1 — the final composited output is already cached, which implicitly captures the mask's effect; a dedicated mask cache would only pay for itself if the same mask needed reapplying to changing source content repeatedly, which does not describe this app's usage pattern. Recorded as a considered-and-deferred optimization, not a gap.

### Performance strategy

Most tiles are cheap by construction: A tiles are forwarded with no decode/encode at all; B tiles are answered from one shared in-memory buffer with no network fetch and sub-millisecond cost. Only C tiles pay real cost, and that cost is paid **at most once per tile, ever** (subsequent requests hit the disk cache). Isolate-offloading (above) keeps even that cost off the UI thread. This should comfortably support normal pan/zoom responsiveness on a physical device, but this is an estimate, not a benchmark — see the physical testing checklist (§12) for the actual on-device verification this claim needs before it is trusted.

### MapLibre integration

`MmlStyleFactory`'s generated tile URL template changes from MML's real endpoint to the local service's loopback address (§ above); `tileSize: 256`, MML's `minzoom: 0`/`maxzoom: 18` source-level facts, and MapTiler's own unrelated `minzoom: 0`/`maxzoom: 22` are all unchanged. **MML is now available at every zoom, including low zoom, with no `activationMinZoom` of any kind** — Revision 3's entire open problem (never implemented) is resolved as a direct, structural consequence of pixel-level masking working correctly regardless of how much area a given tile spans, not by a separate zoom rule. `WorldwideStyleFactory`'s Maastokartta `mmlAvailable` computation reverts to exactly what it was before Revision 2 ever existed: `!MmlConfig.isMissing`, nothing else — MML's raster source is unconditionally present in the composition whenever configured, precisely mirroring MapTiler Outdoor's own unconditional presence.

### Failure behavior

| Situation | Behavior |
|---|---|
| MML key missing | Unchanged from today: MML's source is omitted from the style entirely (checked before the local service is ever consulted for this selection). |
| Local HTTP service fails to start | MML's source is omitted from the style, exactly as if the key were missing — MapTiler Outdoor remains fully usable. Never attempt to reference a local URL that isn't actually live. |
| A specific tile's MML fetch times out, fails, or returns malformed data | That single tile's request is answered with the same shared transparent-PNG fallback classification B already uses — MapTiler Outdoor shows through for that tile, self-healing on the next request (e.g. after a re-pan). **Not written to the persistent disk cache** under that tile's real key, so a transient failure never permanently poisons a tile that would otherwise succeed later. |
| Masking/encoding failure inside the service's own processing | Same fallback as above — logged for diagnosability (message only, never the request URL or key), never propagated as a crash. |
| MapTiler available while MML fails entirely | Unaffected — MapTiler's tiles are fetched directly from MapTiler by MapLibre and never pass through the local service at all; this holds structurally, not through any special-case code. |
| Both providers unavailable | Unchanged from the existing MFS-026/027 "map imagery unavailable" credential-missing banner logic for the missing-configuration case; the existing accepted gap (no banner for a purely transient simultaneous network failure of both, application-owned content remains usable) is unchanged. |

**The local service cannot become a single point of failure for the whole map by construction, not by special-case handling**: MapTiler's delivery path never touches it, so a total failure of the local service (crash, hang, unable to start) degrades Maastokartta to "MapTiler Outdoor only" — visually identical to being outside MML's coverage — never to a blank or broken map.

### Migration plan — what Revision 2/3 code is removed, and why

**Not performed by this document — a plan for the implementation this document still requires approval before starting.**

| Mechanism | Disposition |
|---|---|
| `MmlCoverageRegion.isMmlActiveFor` (viewport-center classification + asymmetric hysteresis) | **Removed.** No caller remains once style-level inclusion is unconditional. |
| `MmlCoverageRegion`'s polygon data and point-in-polygon primitives | **Repurposed, not deleted.** Directly reused by §3C's tile-classification and boundary-masking algorithms above — the geometry and the ray-casting logic remain valuable; only the "one binary decision per viewport, with hysteresis" API built on top of them goes away. |
| `MapScreen._mmlActiveForViewport` | **Removed.** |
| The 50 km hysteresis exit margin | **Removed as a hysteresis concept.** A conceptually different, empirically-determined coastal buffer distance replaces it, serving the mask geometry rather than a state machine — see Coverage Geometry above. |
| `MapScreen._onCameraIdle`'s region-driven style-regeneration branch | **Removed.** No further trigger for `_styleGeneration` bumps beyond an explicit user base-map switch. |
| Revision 3's proposed `activationMinZoom` / layer `minzoom` | **Abandoned as a plan.** Never implemented; nothing to remove in code. |
| Revision 3's proposed `_mmlZoomActive` | **Abandoned as a plan.** Never implemented. |
| Zoom-dependent MML attribution logic (proposed, never implemented) | **Abandoned as a plan.** `MapAttribution`'s condition reverts to "Maastokartta selected AND MmlConfig configured" — matching `MapTilerAttribution`'s own condition — since MML's rendering correctness no longer depends on anything `MapScreen` needs to track. |
| The temporary zoom debug overlay (`_debugCameraZoom`, `_onDebugCameraMove`, its `Positioned`/`Text` widget in `build()`) | **Removed.** It existed solely to support Revision 3's zoom-threshold investigation, which this revision supersedes before that investigation's own physical test was ever run. |

---

## 3D. Boundary No-Data Connected-Component Refinement + Presentation MinZoom (Revision 5)

**Scope: Maastokartta only.** Ilmakuva and MapTiler (both providers, both selections) are explicitly untouched by this revision — physical testing found no equivalent defect for either, and none was investigated here.

### Why this section exists

Physical Android testing of Revision 4 found two remaining defects, both specific to Maastokartta:

1. **An opaque gray MML no-data band is still visible near Finland's border** (confirmed at the Finland/Russia stretch). §3C's own investigation already anticipated this as a residual risk, not a surprise: the 10 km buffer is calibrated to the *tightest* measured margin (Virolahti, ~6–10 km), and was explicitly flagged there as "not a comfortable safety cushion" at that specific stretch. A geometry buffer is a shape *approximation* of a real coastline/border — it cannot itself distinguish "genuinely inside the buffer, but MML happens to have no real data here" from "genuinely inside the buffer, with real MML content." Only looking at the *pixels themselves*, as §3C's core insight already established for the original defect, can do that.
2. **MML is visible at excessively low/world-scale zoom**, rendered as a small, oddly Finland-shaped patch when the viewport spans Europe/Africa scale. Technically correct (real classification, real content) but undesirable — MapTiler Outdoor should be the only thing visible at world/continent scale; MML's own topographic cartographic detail is not usefully legible at that scale in the first place.

### Fix 1 — Boundary no-data connected-component refinement

**Does not replace or shrink the 10 km geometry buffer — layers strictly on top of it, for classification-C (boundary) tiles only.** [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)'s tile classification, the buffer distance, and the buffer's role as the authoritative coverage shape are **all unchanged**. Fully-inside and fully-outside tiles are entirely unaffected — this pass is never invoked for them (`MmlTileMaskService._computeTile` only calls `maskTile` for classification-boundary tiles, exactly as before).

**Algorithm**, applied inside `MmlTileMasker.maskTile` after decoding the real fetched tile and computing the existing geometry alpha mask:

1. Identify every decoded pixel whose RGB is **exactly `RGB(204,204,204)`** (`MmlTileMasker.noDataGray`) — MML's own confirmed flat no-data fill color (§3C). Exact match, no tolerance: MML's raster output is a deterministic PNG, not a lossily re-encoded one, and exact matching was already confirmed sufficient to reproduce the documented 69.81% `ImatraBorder.png` figure (including its own small legitimately-gray fragments) to within 0.001.
2. Run 4-connected component labeling over that color mask, at the decoded tile's own native resolution (independent of the existing alpha mask's supersample factor — a separate, much cheaper pass: 256×256 vs. the existing 1024×1024 supersampled rasterization).
3. For each component, track its pixel count and whether it touches any of the tile's 4 edges.
4. A component is **confirmed MML no-data** only if **both**: it touches a tile edge, **and** its size is **≥ 1,000 pixels** (`MmlTileMasker.noDataComponentMinPixels`).
5. `finalAlpha[y][x] = isConfirmedNoData[y][x] ? 0 : geometryAlpha[y][x]` — strictly additive: a pixel can only become *more* transparent than the geometry mask alone already decided, never less. RGB is never altered for any pixel, exactly as before — only alpha is affected.

**Why edge-touching is required, not size alone:** real MML no-data always originates from land beyond the tile — it cannot be a fully interior blob. Legitimate flat-gray cartographic content (a paved area, a plaza) is a drawn feature bounded well within the tile. This distinction is what makes the refinement safe without needing to reason about cartographic semantics at all — pure pixel connectivity and geometry are sufficient.

**Why 1,000 px, not invented:** connected-component analysis of all 10 real bundled fixtures (`test/fixtures/mml_border_test/`, `test/fixtures/mml_buffer_test/`) found:

| Fixture | Largest confirmed real no-data component | Largest legitimate component (any) | Largest legitimate edge-touching component |
|---|---|---|---|
| ImatraBorder | 45,537 px (69.48%) | — | 32 px |
| TornioBorder | 4,452 px (6.79%) | — | — |
| AlandWest | 23,941 px (36.53%) | 330 px (non-edge) | 294 px |
| GulfFinlandRussia | 2,499 px (3.81%) | — | 67 px |
| FinlandInterior, HelsinkiGulf, TurkuArchipelago, BothnianBay, OpenSeaControl | — (no real no-data present) | 190 px (HelsinkiGulf, non-edge) | 135 px (HelsinkiGulf) |

The smallest confirmed real no-data component (2,499 px) and the largest legitimate component of any kind (330 px) are separated by an **~8.5× gap**. `1,000` sits comfortably inside that gap, with margin on both sides. Against all 10 fixtures, this threshold produces **zero false positives and zero false negatives**: every confirmed real no-data component is fully removed, and every genuinely clean tile (including ones with small gray fragments touching an edge, e.g. HelsinkiGulf's 135px corner feature) is left completely unaffected.

**Cache version bumped: `v1` → `v2`.** A `v1`-cached boundary tile was masked without this refinement and must never be served again as if it already had it (`MmlTileMaskService.cacheVersion`'s own doc comment already calls for a bump "whenever... the masking algorithm changes" — this is exactly that case).

**Whether the 10 km buffer should be revisited instead of adding this refinement — considered and rejected.** The two mechanisms solve different problems: the buffer drives the inside/outside/boundary *classification* that decides whether MML is fetched from at all (an "outside" tile is never requested — no color filter can replace this without fetching every MML tile globally), and it defines the *intended* coverage shape, including real MML content that might legitimately render beyond Finland's border but isn't flat gray (e.g. a neighboring country's own roads/labels) — a color filter cannot catch that at all, only geometry can. Shrinking the buffer to chase the Virolahti margin would also sacrifice the comfortable margin already measured everywhere else (§3C). The no-data-component filter is a targeted, evidence-based cleanup layered on top of the existing, unchanged buffer — not a substitute for it.

### Fix 2 — MML presentation minzoom (placeholder, pending physical confirmation)

**A single named constant, `MmlStyleFactory.presentationMinZoom`, on MML's generated raster *layer* only** — verified against the MapLibre style specification (§3B, carried forward unchanged): a raster layer's `minzoom` is a rendering-level visibility rule ("at zoom levels less than the minzoom, the layer will be hidden") — no tiles are requested below that zoom, and MapTiler Outdoor (already unconditionally present beneath MML) shows through completely and cleanly. This is deliberately **not** applied to the raster *source*'s own `minzoom: 0` (unchanged — unrelated WMTS tile-availability metadata, not a visibility rule; conflating the two was investigated and rejected in §3B).

**No geographic viewport activation logic of any kind is reintroduced.** This is a single, static, declarative value MapLibre evaluates natively every frame — no Dart-side zoom tracking, no `onCameraIdle` involvement, no hysteresis. `MmlTileMaskService` continues to serve and mask tiles correctly at every zoom, unchanged — this constant only ever affects whether MapLibre *requests* a tile for this layer in the first place.

**Why this is lower-risk than Revision 3's abandoned zoom gate:** Revision 3's proposed zoom threshold was masking-critical — a wrong value there could have reintroduced a real coverage defect (which is exactly why it was investigated so carefully before being superseded). Revision 4's per-pixel masking already made correctness fully zoom-independent, so this new minzoom is **purely cosmetic** — a wrong value is a UX quality nit (MML appears a bit too early or too late), never a correctness regression.

**Placeholder value: `7`, not yet device-confirmed.** §3B originally estimated the "MML visually fills the viewport with no non-Finland padding" crossover at **z6–z8** from pure area-overlap reasoning (Finland's ~1,150×540 km footprint vs. viewport coverage at each zoom) — `7` is the midpoint of that range, chosen only so the constant compiles and is wired end-to-end; it is explicitly **not** a final answer, per the same reasoning §3B already gave for why "a plausible-sounding value... is not adopted here without evidence."

**Required physical test procedure before locking the final value** (reusing §3B's own already-designed protocol, never previously executed, now repurposed for a presentation-only rather than masking-critical constant):

1. Build with a valid `MML_API_KEY` and `MAPTILER_API_KEY`, Maastokartta selected.
2. Temporarily override `presentationMinZoom` to `0` for the duration of this test only (so MML's layer is visible at every zoom while comparing — the behavior being measured must not be hidden by the very mechanism being calibrated).
3. At each of at least **4 points spanning Finland's real geographic extent** — e.g. Helsinki (south), Inari (far north), Åland (west), and a point near the Russia border (east) — pan to center that point, then set the camera to exactly zoom **6**, then **7**, then **8** in turn (a fixed, reproducible zoom, not an approximate pinch gesture).
4. At each of the 12 resulting (point × zoom) views, visually judge: does MML's cartographic content look like a small, oddly-shaped, obviously-a-country-outline patch (undesirable — below the real crossover), or does it look like a normal, zoomed-in topographic map with no incongruous "tiny country blob" appearance (desirable — at or above the real crossover)?
5. **The recommended final value is the *highest* (most conservative) zoom among the 12 judgments where the result is still "undesirable"**, plus one — i.e. the lowest zoom that reads as clean at *every* one of the 4 tested points, not merely the most favorable one. Round up to the next whole zoom level if any result is ambiguous.
6. Record the result in this section (replacing the `7` placeholder and this pending-confirmation language), update `MmlStyleFactory.presentationMinZoom`'s value and doc comment accordingly, and re-run the automated test suite (the `mml_style_factory_test.dart` assertion on this constant's value will need its expectation updated to match).
7. Remove the temporary `presentationMinZoom = 0` override used in step 2 before shipping.

**What this reopens: `MapAttribution`'s zoom-independence.** Once MML's layer can be genuinely hidden below a zoom threshold, showing MML's attribution unconditionally (its current condition, TD-027 §11 — "Maastokartta selected AND MmlConfig configured," no zoom check) would let MML's attribution appear even while its layer is invisible below `presentationMinZoom` — a small misattribution, the same category of problem §3B's own (never-implemented) `_mmlZoomActive` was designed to solve. **Not implemented in this revision, by explicit instruction.** Two options exist once the final minzoom is chosen, and the choice is a product decision, not a technical one:
- **Option A (accept the residual imprecision):** leave `MapAttribution`'s condition unconditional. MFS-027 already accepts an analogous residual imprecision elsewhere ("MML's attribution may be shown even in the rare case where the current viewport happens to show none of its content... the same category of minor imprecision MapTiler's own attribution has always accepted") — this would be the same category, at low zoom instead of far pan.
- **Option B (zoom-gate attribution too):** reuse §3B's already-designed pattern almost verbatim — `MapScreen` reads `cameraPosition.zoom` in its existing `onCameraIdle`/`build()` path, compares against `MmlStyleFactory.presentationMinZoom`, and conditions `MapAttribution`'s visibility on it in addition to the existing "Maastokartta selected AND MmlConfig configured" check. Small, but not zero: unlike Revision 4's zero-Dart-side-zoom-tracking design, this reintroduces one narrow, explicit zoom read — recorded here so it is a deliberate choice if made, not a silent scope-creep.

### Interaction with existing Revision 4 architecture

Both fixes are additive refinements within Revision 4's existing architecture, not architecture corrections:
- Tile classification (§3C, inside/outside/boundary), the 10 km buffer, the coverage geometry, the local HTTP service's lifecycle/caching/concurrency design, and MML's failure behavior are **all unchanged**. **Superseded in part by Revision 6 below** — the "outside" classification and the final boundary-tile masking algorithm both change in Revision 6; the 10 km buffer's *own* value does not, but its role narrows.
- `MmlTileMaskService` continues to serve and mask tiles correctly at every zoom — the presentation minzoom is purely a MapLibre-side "don't bother asking" rule, with no effect on the service's own correctness or availability. **Unaffected by Revision 6** — still true.
- Neither fix touches Ilmakuva or MapTiler in any way. **Still true in Revision 6.**

---

## 3E. Content-Driven Boundary Masking + Coarse Fetch Envelope (Revision 6)

**Scope: Maastokartta only.** Ilmakuva and MapTiler are untouched, same as Revision 5. Revision 5's presentation-minzoom placeholder (§3D) is a separate, still-pending concern this revision does not touch.

### Why this section exists

Physical Android testing of Revision 5 found two further defects, both traced to the same root cause: **`geometryAlpha` (the buffered-distance rasterization) was never actually the right mechanism for shaping boundary-tile visibility, only a plausible-looking one.**

1. **An opaque white region near Imatra/Nuijamaa.** Revision 5's no-data detector only recognized `RGB(204,204,204)`. Real evidence at three independent border crossings (Imatra, Nuijamaa, Vaalimaa — 27 tiles at z=13) found that at this zoom, MML's own cartographic style is materially different from the z=8 style Revision 5's evidence came from: gray is nearly absent (max 17px across 35 real tiles), and the actual no-data fill is `RGB(255,255,255)` — confirmed by a clean, monotonically growing white component across adjacent tiles toward each crossing's foreign side (up to 96–98% of a tile deep in Russia).
2. **Visibly circular/buffered-land-shaped MML cutouts around Åland and Föglö.** This is a direct, structural consequence of `geometryAlpha` itself, not a tuning problem: a uniform-radius buffer (10 km) applied around a *scatter of small, separated islands* produces a union of rounded blobs by construction — there was never a buffer distance that could avoid this shape while an archipelago was involved. A systematic transect (18 real tiles at z=12, radiating out from Mariehamn across Åland/Föglö/west toward Sweden/south into open Baltic/east toward Turku) confirmed real MML content genuinely extends asymmetrically well beyond the buffered polygon in some directions (up to 70km east toward Turku; as little as ~20km southwest into open Baltic before flattening out) — no single buffer distance could ever have bounded this correctly, because the real shape isn't a buffered polygon at all.

**Both defects point to the same fix:** stop using geometry to shape final pixel alpha. Decide visibility from what MML's own fetched pixels actually contain.

### Root cause: the white no-data region (Imatra/Nuijamaa)

Confirmed via real pixel evidence, not inferred. At three independent Finnish/Russian border crossings, z=13 tiles show the identical pattern: a small (4,000–5,000px, ~6–8%) white fragment at the checkpoint tile itself, growing to a dominant (18,000–27,000px, ~28–41%) component one tile further from Finland, reaching a fully opaque 96–98% of a tile two tiles deep into Russia. This is exactly the same shape of evidence that originally confirmed `RGB(204,204,204)` at z=8 (TD-027 §3C) — just a different color, because MML's own cartographic style changes by zoom band (confirmed: sea fill is `RGB(153,224,255)` at z=8 vs. `RGB(128,255,255)` at z=12/13; land fill and other colors differ similarly). Gray detection (§3C/§3D) remains valid and unchanged for whatever zoom band it was verified at — this is an *additional* no-data color, not a replacement.

### Root cause: circular Åland/Föglö cutouts

Not a new investigation finding — a direct consequence of code already in the repository. `MmlCoverageRegion`'s buffer (`bufferKm = 10`) is a fixed-radius offset applied to the Finland+Åland polygon's vertices/edges. Buffering a handful of small, widely-separated island polygons with a uniform radius produces, by construction, a union of rounded blobs around each island — never a continuous shape. Compounded by an already-accepted residual risk (§3C: the underlying 1:50m Natural Earth polygon may not individually resolve every small skerry — an unrepresented island gets *zero* buffer at all, an even worse gap). Both causes trace to the same root: using geometry to directly gate final pixel alpha is structurally the wrong mechanism for an archipelago, regardless of how the buffer distance is tuned.

### The fix: geometry no longer shapes final pixel alpha, anywhere

`MmlTileMasker.maskTile` no longer rasterizes the coverage polygon into an alpha mask at all. `_rasterizeCoverageAlpha`, `_rasterizeInsideRaw`, `_partsNear`, `_edgesNear`, and `_expand` are removed — not refined further, removed. In their place, a two-stage, purely content-driven algorithm:

1. **Decode** the fetched tile.
2. **Whole-tile flat/generic check.** Count distinct RGB colors. If below `minDistinctColorsForContent` (**50**), the entire tile is treated as flat/generic MML background with nothing worth overlaying — the shared `transparentTile` is returned immediately, no further analysis. **Evidence:** across 45 real tiles (the original 10 fixtures + the 35 new Revision 6 tiles), every tile with genuine cartographic content had 71–198 distinct colors; every flat/generic tile — including two fully-opaque "deep Russia" no-data tiles *and* several tiles from the Åland transect that decoded to **exactly one distinct color, 100% of the pixel grid** (proving MML renders plain, information-free sea-fill filler far past real content, not just gray/white no-data) — had 1–33. A clean, non-overlapping gap; 50 sits inside it. (One notable reclassification: the original `OpenSeaControl` z=8 fixture, previously read as reassuring "legitimate open sea" evidence, has only 12 distinct colors — it is itself an example of this flat/generic category, not a counter-example. Showing MapTiler instead of MML there is not a visible regression in practice, since both render as plain blue.)
3. **Otherwise (genuine content):** for each of the two known no-data colors, find 4-connected components of exact-match pixels; a component is confirmed no-data only if it **touches a tile edge and meets its own size threshold**:
   - `RGB(204,204,204)` (gray, §3C/§3D, unchanged): **≥1,000px**. Evidence: largest legitimate component ever observed, 330px; smallest confirmed real no-data, 2,499px — ~8.5x gap.
   - `RGB(255,255,255)` (white, new): **≥10,000px**. Evidence, across all three border crossings: largest legitimate edge-touching component observed, 6,795px (Vaalimaa — this ceiling rose with each additional real sample checked: 4,457 → 5,339 → 6,795px); smallest confirmed real no-data, 14,979px (Imatra) — ~2.2x gap, tighter than gray's but real and non-overlapping. 10,000 is biased toward the safer (higher) end of the evidence range given that rising trend.
4. **Every other pixel stays exactly as MML rendered it — fully opaque, RGB bit-for-bit unchanged.**

`finalAlpha = isFlatGenericTile ? 0 : (isConfirmedNoData ? 0 : 255)` — never a smooth gradient, never a geometry-derived value.

### The coarse fetch envelope — geometry's new, narrowed role

`MmlCoverageRegion`'s land+10km-buffer test is **retained**, but purely as `classify`'s cheap "clearly inside" fast path (skip fetch/decode/inspection entirely for tiles deep in mainland Finland) — it no longer has any bearing on what counts as "outside." That question is now answered by a new, deliberately generous, non-visible bounding box:

```
fetchEnvelopeSouth = 57.45°N   fetchEnvelopeNorth = 72.09°N
fetchEnvelopeWest  = 16.08°E   fetchEnvelopeEast  = 34.59°E
```

A tile whose bounds fall entirely outside this box is never fetched from MML at all. Chosen as Finland's own mainland+Åland bounding box (59.45–70.09°N, 19.08–31.59°E) expanded by 2° latitude / 3° longitude — many times larger than the largest real MML content distance actually measured beyond Åland (70km ≈ 0.6–1.3°, depending on direction). **Precision is deliberately not the goal**: an unnecessarily-fetched tile costs one wasted request (and, if genuinely empty, is caught by the flat/generic check above at negligible extra cost); a tile wrongly excluded here would silently lose real content with no recourse. This asymmetry is why the envelope errs wide rather than tight, and why several previously-"outside"-classified real locations (deep interior Sweden and Russia near the border, open Baltic Sea near Åland) now correctly classify as `boundary` instead — they were never actually far enough from real content to be safely skipped, they were just closer to the old (too-tight) 10km land buffer than to genuinely empty territory.

**Investigated but not adopted for this envelope:** Traficom (Finnish Transport and Communications Agency — a different authority than MML/NLS) publishes an authoritative maritime boundary dataset (`avoin:TerritorialSeaArea_A`/`ExclusiveEconomicZone_A`, CC BY 4.0, EPSG:4326, open WFS, no authentication) that could in principle replace this bounding box with a real jurisdictional polygon. Not adopted here: the coarse envelope's only job is a rough "don't bother fetching Nebraska" performance filter (correctness is now guaranteed by the content-driven pipeline regardless of how generous the envelope is), so a real GML/shapefile-parsing integration is more machinery than the job currently requires. Recorded as an available upgrade path, not designed further.

### Cache

`MmlTileMaskService.cacheVersion` bumped `v2` → `v3` — boundary-tile output semantics changed completely (no more `geometryAlpha`, a new whole-tile shortcut, a second no-data color) — a `v2`-cached tile must never be served as if it already reflected any of this.

### Performance

`_maskInIsolate` no longer needs to pass `MmlCoverageRegion`'s 571-vertex polygon data across the isolate boundary at all — `maskTile` no longer consults `region` in any way, so the isolate reconstruction simplified to `const MmlTileMasker().maskTile(...)`, nothing else crossing. Per boundary tile, the new algorithm is **cheaper than Revision 5's**, not more expensive: the removed `_rasterizeCoverageAlpha` was a 1024×1024-cell (4× supersampled) scanline-fill-plus-buffer-distance computation, by far the most expensive part of the old `maskTile`; the new whole-tile histogram (a single 65,536-cell pass) and per-color component detection (also 65,536 cells each) are all cheaper than that removed step, combined. The one new cost vector is the widened "worth fetching" envelope pulling in more tiles that previously would have been skipped entirely (classification `outside`, free) — a real, but bounded, increase (the envelope is a fixed box, not unbounded), and every additional fetched-but-empty tile now resolves via the cheap whole-tile shortcut rather than the old expensive rasterization. In-memory LRU, disk cache, in-flight request coalescing, the "clearly inside" pass-through fast path, and the "clearly outside" no-fetch path are all unchanged.

### Known residual risk: cross-tile no-data fragmentation

Not new to Revision 6 — a structural property of any per-tile-only connected-component approach, now directly confirmed with real evidence rather than only theorized. At every one of the three border crossings, the checkpoint tile's own local no-data fragment (4,457–5,339px) sits well under the 10,000px white threshold, even though it is clearly part of the same real no-data mass that dominates the very next tile (18,000px+). This means a small residual no-data sliver can remain right at the tile containing the actual border line, while the surrounding tiles are correctly cleaned up — a real but much smaller and less visually alarming defect than today's full-tile white/gray blocks. **Accepted for this revision, not solved**: a neighbor-tile-aware detection scheme was considered (checking whether an under-threshold edge-touching component continues into the adjacent tile) but adds real fetch/decode cost for tiles that would otherwise stay on the cheap path, and is not designed here. Revisit if physical Android testing shows this specific residual sliver is still visually bothersome.

### Interaction with existing architecture

- Revision 4's local HTTP service (lifecycle, in-memory/disk caching, concurrent-request coalescing, isolate dispatch) is entirely unchanged in shape — only what `maskTile` computes inside the isolate changed.
- Revision 5's gray no-data detection is unchanged in value and behavior; it is now one of two colors checked, not the only one.
- Revision 5's presentation-minzoom placeholder (§3D) is untouched — still a separate, pending, purely presentational concern, unaffected by anything in this section.
- Ilmakuva and MapTiler are untouched.

---

## 3F. MML v21 Vector Integration (Revision 7)

**What this section supersedes, precisely:** [§3](#3-per-selection-style-composition)'s Maastokartta branch (MapTiler Outdoor + `MmlStyleFactory`'s raster fragment), and all of [§3A](#3a-maastokarttas-geographic-region-mechanism-revision-2)/[§3B](#3b-maastokarttas-zoom-gated-mml-inclusion-revision-3)/[§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)/[§3D](#3d-boundary-no-data-connected-component-refinement--presentation-minzoom-revision-5)/[§3E](#3e-content-driven-boundary-masking--coarse-fetch-envelope-revision-6)'s masking machinery, as the **live implementation plan** for Maastokartta's Finnish layer — all five sections are retained in full below as historical record and as the source of reusable primitives (see [§25](#25-migration--cleanup--revision-7)), not deleted. **What is unchanged:** MapTiler Outdoor's unconditional worldwide-underlay role (§3, Decision 1), the per-selection failure-independence model (§9), the credential-never-committed requirement (§8, §16), and everything about Ilmakuva (§3's second branch, entirely untouched by this section).

### Why vector, restated precisely

Revisions 2–6 exist because MML's **raster** WMTS renders out-of-coverage areas as ordinary opaque pixels — confirmed by direct PNG decoding, not inferred (ADR-0009 Revision Note 4) — so *something* had to run before MapLibre ever saw those pixels to produce a clean border. A **vector** tile is not a pre-rendered image at all: it is a small, structured payload of feature geometry plus attributes, decoded and rendered client-side by MapLibre itself, layer by layer, from a style document's own paint/filter rules. Where MML's v21 vector tileset has no features for a given tile, there is nothing to draw — no analogue of "a flat gray fill" exists in a vector protocol, because a vector tile with zero features and a vector tile that simply doesn't exist look identical to the renderer: nothing is painted, and whatever source is composited beneath it (MapTiler Outdoor) is fully visible through the empty space, by construction, with no application-side masking, alpha compositing, or geometry classification of any kind.

**This is an architectural expectation, not yet a confirmed fact, and this document does not treat it as settled without verification** — see [Pre-Implementation Verification](#pre-implementation-verification--revision-7) below, which is the direct, deliberate continuation of this project's own established discipline (the identical raster assumption in ADR-0009's original text was disproved by physical testing at broader geographic scale; this document does not repeat that mistake for vector by skipping the equivalent check).

### Basis: MML's own official v21 style document, fetched and lightly post-processed — not hand-authored

**The temporary PoC's core strategy is retained as the production strategy, unchanged in kind:** fetch MML's own real v21 "backgroundmap" style JSON (`https://avoin-karttakuva.maanmittauslaitos.fi/vectortiles/stylejson/v21/backgroundmap.json`) at runtime, rather than hand-authoring an equivalent style in Dart the way `MmlStyleFactory` does for the (now-superseded) one-source/one-layer raster fragment. MML's v21 style is a real, ~100-layer, hand-tuned cartographic product (contour lines, water fill/line, roads at every grade-separation level, buildings, land use, place-name labels — confirmed directly via `test/fixtures/mml_v21_backgroundmap_style_fixture.json` and `mml_v21_backgroundmap_fixture_test.dart`, both already present from the PoC). Reproducing that by hand in this project, the way `MmlStyleFactory`'s single raster source/layer was reasonably hand-authored, would be a large, ongoing, high-risk styling effort for zero product benefit — MML's own rendering is exactly what ADR-0008 already decided this project wants ("MML's own rendering as-is," not a self-maintained equivalent), and that reasoning applies with even more force to a ~100-layer vector style than it did to the one-layer raster case ADR-0008 was actually written about.

What changes from the PoC to production is **not** the fetch-MML's-own-style strategy — it is (1) how the resulting document's embedded credential is handled before anything touches disk ([API-Key Handling](#api-key-handling-the-plaintext-style-file-problem-and-its-fix) below), and (2) one deliberate content edit to the fetched style before use ([Composing with MapTiler Outdoor](#composing-mml-v21-vector-with-maptiler-outdoor) below).

### API-key handling: the plaintext-style-file problem, and its fix

**The problem, precisely:** MML's v21 style response embeds the caller's own authenticated `api-key` directly in two places in the JSON it returns — the vector source's `url` (a TileJSON endpoint whose own tile-template response, in turn, also carries the key) and the top-level `glyphs` URL (confirmed directly: `investigation/v21/backgroundmap_style.json` line 9 and line 12; `investigation/v21/tilejson.json` line 7). The current PoC (`MapScreen._onToggleVectorPoc`) fetches this JSON and passes it straight to `_writeStyleFile`, which writes it, key included, to an ordinary file in the app's temporary directory (`_writeStyleFile` → `File('${directory.path}/mml_style_$name.json')` → `file.writeAsString(styleJson)`) — a plaintext, on-disk, unencrypted copy of a live, working MML credential, readable by anything with filesystem access to the app's own sandbox (a rooted device, a backup extraction tool, a crash-report attachment that happens to bundle app files). This is explicitly acceptable for the PoC (a short-lived, developer-only debug tool, deleted along with the rest of the PoC per [§25](#25-migration--cleanup--revision-7)) and explicitly **not** acceptable for production, per this milestone's own instruction and per the stricter standard ADR-0009 Revision Note 4/TD-027 §16 already established for MML's raster key ("must never appear in ... any cache filename ... or error message").

**The fix: reuse this project's own already-proven local-loopback-proxy pattern (§3C), generalized from raster masking to vector proxying.** `MmlTileMaskService` already demonstrates the exact shape needed — an app-local, loopback-only HTTP listener (`http://127.0.0.1:<ephemeral-port>`) that holds the real MML credential server-side (i.e., inside this on-device process, never exposed to the client-facing style document) and answers plain, key-free requests from MapLibre. Revision 7 repurposes this shape (renamed `MmlVectorProxyService` — see [§25](#25-migration--cleanup--revision-7) for exactly what carries over from `MmlTileMaskService`'s existing implementation) for three MML v21 endpoints instead of one raster WMTS endpoint:

| MapLibre-facing local endpoint | What it does server-side | Real MML endpoint it proxies |
|---|---|---|
| `GET /mml/v21/style.json` | Fetches MML's real style once (cached — MML's style document changes rarely, unlike per-tile content), rewrites its `sources.taustakartta.url` and top-level `glyphs` to the two local endpoints below, strips the `background` layer (see [Composing with MapTiler Outdoor](#composing-mml-v21-vector-with-maptiler-outdoor)), and returns the result — **with no `api-key` anywhere in the returned document**. | `.../vectortiles/stylejson/v21/backgroundmap.json?TileMatrixSet=WGS84_Pseudo-Mercator&api-key=<real key>` |
| `GET /mml/v21/tilejson.json` | Fetches MML's real TileJSON, rewrites its own `tiles` template to point at the local tile endpoint below, returns it key-free. | `.../vectortiles/tilejson/taustakartta/1.0.0/taustakartta/default/v21/WGS84_Pseudo-Mercator/tilejson.json?api-key=<real key>` |
| `GET /mml/v21/tiles/{z}/{x}/{y}.pbf` | Attaches the real key server-side and proxies the request byte-for-byte (no decode/re-encode — vector tiles are opaque binary payloads to this service, unlike raster's boundary-masking case; see [Tile Handling](#tile-handling-proxy-not-mask) below), reversing MML's own token order internally exactly as `MmlTileMaskService` already does for raster (`{z}/{x}/{y}` in, MML's own reversed `{z}/{y}/{x}` out — confirmed unchanged in `investigation/v21/tilejson.json`'s own tile template). | `.../vectortiles/taustakartta/wmts/1.0.0/taustakartta/default/v21/WGS84_Pseudo-Mercator/{z}/{y}/{x}.pbf?api-key=<real key>` |
| `GET /mml/v21/glyphs/{fontstack}/{range}.pbf` | Attaches the real key server-side and proxies the request. | `.../vectortiles/glyphs/{fontstack}/{range}.pbf?api-key=<real key>` |

`WorldwideStyleFactory`'s Maastokartta branch no longer merges a Dart-constructed MML fragment via `MmlStyleFactory` (as it does for raster today); instead it embeds a single `sources.taustakartta` entry of `"type": "vector"` whose `url` points at `http://127.0.0.1:<port>/mml/v21/tilejson.json` — MapLibre itself resolves the TileJSON and requests tiles exactly as it would for any ordinary remote vector source, just via loopback. **No production style document, cache filename, log line, or error message generated by this milestone ever contains the real `api-key` value** — directly satisfying FR-27, and extending, not merely repeating, the identical guarantee ADR-0009 Revision Note 4/TD-027 §16 already established for MML's raster key. `MmlConfig` (unchanged, TD-026 §8) remains the sole source of the real key; only `MmlVectorProxyService` ever reads `MmlConfig.apiKey`, exactly as only `MmlTileMaskService` does today for raster.

### Composing MML v21 vector with MapTiler Outdoor

**A concrete finding, not previously documented in this project: MML's own v21 style begins with a `background`-type layer** (`{"id": "background", "type": "background", "paint": {"background-color": "#dceacc"}}` — confirmed directly, `investigation/v21/backgroundmap_style.json` lines 13–18). A MapLibre `background` layer paints its color across the **entire visible viewport**, unconditionally, independent of any source or geometry — this is a deliberate, standard MapLibre style-spec feature (every complete style needs *some* base fill), but it means naively embedding MML's style verbatim beneath/above MapTiler Outdoor would paint MML's own khaki-green background color across the whole world, every time Maastokartta is selected, hiding MapTiler Outdoor everywhere, not only where MML genuinely has no data — reintroducing, by a different mechanism, exactly the "MML obscures MapTiler outside real coverage" defect Revisions 2–6 exist to fix for the raster path.

**Fix: `MmlVectorProxyService`'s style-rewriting step (above) removes MML's own `background` layer from the served style** before MapLibre ever receives it. MapTiler Outdoor's own raster layer, listed first in the composed style (unchanged ordering convention from §3/Key Design Decision 1), then functions as the *effective* background — visible everywhere MML's own ~99 remaining data-driven layers (each filtered by `kohdeluokka`/feature-class and each drawing only where its own `source-layer` genuinely has geometry) have nothing to draw. This is the vector-path's entire "coverage boundary" mechanism: **no polygon, no buffer, no masking, no classification** — just the natural absence of vector features outside MML's coverage, once the one unconditional full-viewport layer is removed. This single, targeted edit is the full extent of this milestone's "content edit" to MML's own style (stated in [Basis](#basis-mmls-own-official-v21-style-document-fetched-and-lightly-post-processed--not-hand-authored) above) — every other one of MML's ~99 layers is passed through completely unmodified, preserving MML's own cartographic design exactly as ADR-0008 requires.

### Tile handling: proxy, not mask

Unlike raster's boundary case (§3C: fetch, decode, rasterize a coverage mask, composite alpha, re-encode), `MmlVectorProxyService`'s tile endpoint does **no content processing at all** — it attaches the real key, forwards the request to MML, and streams the response bytes back unmodified. There is nothing to decode (a `.pbf` vector tile is opaque binary to this service — it never needs to understand Protocol Buffer/MVT internals, only pass bytes through), no per-pixel alpha to compute, and therefore no anti-aliasing, no connected-component analysis, and no algorithm-version cache-key segment tied to a masking algorithm (§3C's `mml_tile_cache/v1/...` versioning existed specifically because the *masking algorithm* could change; a pure proxy cache versions only on URL-mapping changes, a much rarer event). This is a substantially simpler service than `MmlTileMaskService`'s raster masking role — see [§25](#25-migration--cleanup--revision-7) for exactly what carries over (the HTTP-listener lifecycle, ephemeral-port binding, request coalescing, LRU+disk caching shape) versus what does not (isolate-dispatched CPU-bound masking work, since there is no CPU-bound work left to dispatch).

**Caching still applies, for the same reason it did for raster:** repeated requests for the same tile (panning back over already-visited territory) should not re-fetch from MML every time. The same two-tier (in-memory LRU + persistent disk) cache shape from §3C is reused, keyed by `z/x/y`, now storing raw proxied `.pbf` bytes instead of masked PNG bytes — a smaller, simpler cache entry, since there is no separate "raw vs. processed" distinction to make (the proxied bytes *are* the final bytes).

### Failure behavior

Mirrors §3C's table, simplified (no masking-specific rows apply):

| Situation | Behavior |
|---|---|
| MML key missing | `MmlVectorProxyService` is not started for this purpose (or is started but its style/tile endpoints are never referenced) — `WorldwideStyleFactory` omits the `taustakartta` source entirely, exactly as today's `mmlAvailable` check already does. |
| Local proxy service fails to start | MML's source is omitted from the style, exactly as if the key were missing — MapTiler Outdoor remains fully usable. Never reference a local URL that isn't actually live (unchanged principle from §3C). |
| MML's real style/TileJSON/tile/glyph fetch fails, times out, or returns malformed data | That specific request fails to the client (MapLibre), which already tolerates a missing vector tile/glyph range by simply not rendering that content — no crash, no technical detail exposed, self-healing on retry/re-pan. Not written to the persistent cache under a failed key, mirroring §3C's identical rule for raster. |
| MapTiler available while MML fails entirely | Unaffected — structurally independent, exactly as §3C already established; MapTiler's delivery path never touches `MmlVectorProxyService`. |
| Both providers unavailable | Unchanged from the existing MFS-026/027 "map imagery unavailable" credential-missing banner logic. |

### Disposition of the raster masking architecture: retired, not fallback-only

**Decision: MML raster WMTS delivery and its pixel-masking machinery (`MmlTileMasker`, and `MmlTileMaskService`'s masking-specific logic) are retired from the selected path entirely — not kept as a fallback alongside vector.** This was evaluated, not assumed, against the milestone's own explicit instruction not to retain raster complexity the vector path makes unnecessary:

- **A fallback would need its own trigger and its own justification, and none exists.** Maastokartta's failure-independence guarantee (§9, unchanged) already comes from MapTiler Outdoor's *unconditional* presence — if MML (vector or, hypothetically, raster) fails entirely, MapTiler Outdoor alone continues to serve a usable, populated map, exactly as it already does today and exactly as Ilmakuva's own single-provider design already accepts as sufficient (ADR-0009). A second MML *delivery mechanism* as a fallback for the first would protect against "vector fetching works but raster fetching doesn't" or vice versa — a scenario with no plausible real-world cause (both ultimately depend on the same MML service being reachable and the same API key being valid), so the added complexity has no real failure mode it uniquely covers.
- **Maintaining two parallel MML delivery paths (raster+masking and vector+proxy) would double the ongoing maintenance surface — two style factories, two local services, two sets of tests, two things to keep in sync with any future MML product change — for a benefit (redundancy against a failure mode that isn't real) that does not exist.** This directly contradicts `docs/development-rules.md`'s "avoid premature abstractions"/"keep implementations simple" and this milestone's own explicit instruction.
- **The masking machinery's entire reason to exist (§3C's opening paragraph) was a raster-specific defect.** It has no independent value once nothing in the selected path renders raster MML tiles — keeping it "just in case vector doesn't work out" is exactly the sunk-cost reasoning the task instruction warns against, and if vector genuinely does not work out (see [Pre-Implementation Verification](#pre-implementation-verification--revision-7) below), the correct response is re-evaluating this decision explicitly, with real evidence, the same way Revisions 2/3/4/5/6 each did — not silently keeping dead code live "to be safe."

**What is retired outright:** `MmlTileMasker`'s pixel-processing algorithm (rasterization, anti-aliasing, whole-tile flat/generic detection, per-color connected-component no-data removal) and `MmlStyleFactory`'s raster style-JSON generation. **What is retained and repurposed, not deleted:** `MmlCoverageRegion`'s polygon data and point-in-polygon primitives (their fate is conditional on the verification below — see [§25](#25-migration--cleanup--revision-7)), and `MmlTileMaskService`'s local-HTTP-service *shape* (lifecycle, ephemeral port, request coalescing, caching), evolved into `MmlVectorProxyService`.

### MapTiler worldwide fallback: preserved unchanged

MapTiler Outdoor's role — unconditional worldwide underlay beneath Maastokartta's MML content, entirely independent of MML's own availability — is **not reconsidered by this section**. Every part of §3/§9's MapTiler-Outdoor reasoning (why it is always present, why its failure is independent of MML's, why it is not user-selectable) continues to apply verbatim; only what sits *above* it (raster+mask vs. vector) has changed. Ilmakuva's MapTiler Satellite Hybrid composition is entirely untouched — it was already, and remains, independent of any MML mechanism.

### Zoom range

**Verified, and corrected from this section's original assumption (evidence gathered this session, see [Pre-Implementation Verification](#pre-implementation-verification--revision-7) below).** MML v21's own TileJSON *declares* `minzoom: 0`, `maxzoom: 14` (`investigation/v21/tilejson.json`), and this section originally assumed that meant real content stops at z14, with z15+ relying on MapLibre's own client-side geometric overzoom of the z14 tile. **Direct requests against MML's real WMTS vector endpoint disprove that assumption**: fetching a Helsinki-area tile at z15, z16, z17, and z18 each returned HTTP 200 with genuinely distinct, non-trivial payloads (32.6 KB / 12.4 KB / 6.8 KB / 5.1 KB respectively, versus 97.7 KB at the declared-native z14) containing real, correctly-scoped feature subsets — roads, buildings, labels, and land-use polygons all still present and decreasing in count in a way consistent with each finer tile covering a proportionally smaller real area, not a duplicated or client-upscaled z14 payload. z19 and beyond returned HTTP 404. **MML's vector WMTS endpoint therefore genuinely serves real, server-tiled content through z18** — an identical ceiling to raster's own confirmed `0`–`18` range (§0, TD-026), not the `14` its TileJSON declares.

**Design correction:** `MmlVectorProxyService`'s generated vector source should declare `maxzoom: 18` (matching raster, and matching what the upstream service actually serves), not `14` — so MapLibre requests MML's own real z15–z18 tiles directly rather than client-side-overzooming the z14 tile unnecessarily. This is a narrow correction to this document's own stated zoom-range value, not a change to the vector-vs-raster architecture decision itself: TileJSON's declared `maxzoom` was simply conservative/inaccurate relative to the service's real behavior, exactly the kind of literal-value gap this document's own §0 discipline exists to catch before it is assumed. Whether MML's real z15–z18 *content* (not merely its presence) renders acceptably on-device — label density, symbol legibility at that scale — remains a physical Android comparison, not resolved by this evidence (see [Pre-Implementation Verification](#pre-implementation-verification--revision-7)).

### Pre-Implementation Verification — Revision 7

Following this document's own established §0 discipline (confirm against the real service, not assumption). **Desktop-verified with real data this session** (real MML v21 tile fetches, a real credential, decoded MVT payloads — not inference); physical Android rendering remains separately required per the last row and is not satisfied by what follows.

| Item | Result | Evidence |
|---|---|---|
| **Do MML v21 vector tiles outside real coverage return genuinely empty (zero-feature) tiles, not some encoded "no data" feature/fill?** | **Confirmed true.** | Real tiles fetched at z6/z8/z10/z12 for six locations: central Sweden (Stockholm), France (Paris), Moscow, and mid-Atlantic open ocean all returned zero decoded features at z8/z10/z12 (tiny, structurally-fixed payloads — e.g. Stockholm and Paris both returned byte-identical 152/229/262-byte empty responses at z8/z10/z12 respectively, and Moscow/mid-Atlantic matched the same byte counts independently) — a deterministic "empty tile" signature, not coincidence. z6 tiles are coarse enough that Stockholm's and Åland's real coordinates fall in the *same* physical tile (expected at that zoom, not a defect); France's own, genuinely different z6 tile was independently empty (133 bytes, 0 features). No no-data placeholder feature of any kind was found anywhere. |
| **Does the `background`-layer removal fully resolve the "MML obscures MapTiler outside coverage" concern, with no other unconditional MML layer discovered on closer inspection?** | **Confirmed true, with one nuance recorded below.** | MML's real, complete v21 style (`investigation/v21/backgroundmap_style.json`, 113 layers — not the trimmed fixture) was inspected programmatically: exactly **one** layer has no `source` at all (`background`); every other layer, including the 6 with no `filter`, is still scoped to a real `source-layer` and therefore only paints where that source-layer genuinely has features in a given tile. Stripping `background` alone is sufficient — no second unconditional layer exists. |
| **MML v21's overzoom behavior beyond its declared `maxzoom: 14`.** | **Assumption corrected — see [Zoom range](#zoom-range) above.** MML's real server serves genuine, distinct, correctly-scoped content through z18 (HTTP 404 at z19+), not merely client-side-overzoomed z14 content. Production should declare `maxzoom: 18`, not `14`. | Real fetches at a Helsinki tile, z14–z18: 97.7 KB / 32.6 KB / 12.4 KB / 6.8 KB / 5.1 KB, each independently decoded with distinct, decreasing, correctly-scoped feature counts (roads/buildings/labels/land-use all present through z17; roads/buildings/land-use at z18). z19–z22 all returned 404. **Visual/rendering-quality acceptability of this real content is a separate, still-open physical question** (see the last row) — this item only resolves *whether real content exists* to z18, not whether it looks good rendered. |
| **Coverage-boundary rendering at the actual Finland/Russia, Finland/Sweden, and Åland edges, at multiple zooms.** | **Content-level check done; on-device rendering check remains open.** Real tiles were fetched and decoded at Tornio (Sweden border), Imatra and Virolahti (Russia border), and west of Åland, at z6/z8/z10/z12. One notable, fully-resolved finding: a `korkeusalue` (elevation-area) polygon with attribute `kohdeluokka=52100, korkeus=0` was found spanning well past the real border at multiple crossings (at Imatra, real-world longitude 28.12–29.54°E against a tile spanning 28.13–29.53°E — i.e. nearly the *entire* tile width, deep into Russian territory). **This is not a defect**: a direct text-search of MML's complete real style confirmed `"korkeusalue"` (the source-layer this polygon belongs to) is referenced by **zero** layers anywhere in MML's own official style — the data exists in the tile but MML's own cartography never paints it, so it has no visual effect regardless of how far it extends. The other large-bbox polygon layer found (`vesisto_alue`, water fill, extending into open Baltic Sea near Åland) is consistent with, not contradicting, the already-established raster-investigation finding (TD-027 §3C) that MML's real content legitimately extends tens of km into open sea beyond the immediate coastline — expected, not a boundary defect. **What this does not yet confirm:** how this content actually *renders*, pixel-for-pixel, through MapLibre GL Native on a real device — decoded feature presence/absence is necessary but not sufficient evidence for a visually clean border. | Physical Android testing at Imatra, Nuijamaa, Vaalimaa, and Åland/Föglö (reusing the exact locations already characterized for raster in Revisions 4–6) remains required and is **not** satisfied by this session's desktop verification. |

**Contingency (unchanged, and not triggered):** the first verification item's real-world result was "genuinely empty," so the contingency for an encoded no-data indicator does not apply. `MmlCoverageRegion`'s retained geometry (§25) is therefore **not needed** for any coverage-correctness purpose in the vector path — its only remaining plausible use is a non-visible, purely-optional "skip fetching this tile at all" performance filter, which is not required by anything found this session and is not adopted here; §25's disposition (retain only if a concrete reason emerges) stands as written.

---

## 4. Persistence — Unchanged

`BaseMapPreferenceStore` is not modified. It continues to persist only the selected `BaseMap` (Maastokartta/Ilmakuva). Neither Maastokartta's MapTiler Outdoor underlay nor Ilmakuva's MapTiler Satellite Hybrid content is a separate preference — both are always included in their respective selection's style whenever `MapTilerConfig.isMissing == false` (MFS-027 FR-2).

---

## 5. Style Lifecycle — Generalized, Not Changed

`StyleRestorationTracker` and `FishingSpotLayerPresence` require **no code change**, exactly as concluded in this document's original version. Their contract — "track which style-application generation the fishing-spot layers have been restored for, verified by re-querying actual state" — does not care how many raster sources the rest of the style contains, and does not care *why* a new generation was requested. This is exactly what makes them reusable, unmodified, for the new automatic trigger introduced in [§3A](#3a-maastokarttas-geographic-region-mechanism-revision-2).

**Revision 2 adds a second trigger for `_styleGeneration` bumps beyond the original "requested base-map switch": an automatic region-driven change while Maastokartta remains selected** (`_onCameraIdle`'s hysteresis check flipping `_mmlActiveForViewport`). Both triggers feed the exact same counter, the exact same regeneration pipeline, and the exact same restoration guard — there is no separate code path, and no new kind of race to reason about beyond what TD-026 already solved (a slow-finishing regeneration for an abandoned generation is already discarded via the existing stale-generation check, regardless of which trigger caused that generation to exist).

`_ensureFishingSpotLayersExist`'s bounded, idempotent retry loop is unchanged. **The reload cadence is now potentially more frequent than before** — once at cold start, once per explicit Maastokartta ↔ Ilmakuva switch (unchanged from Revision 1), plus now also once per region-boundary crossing while Maastokartta is selected (new in Revision 2, but bounded by the hysteresis dead-zone — see [§3A](#3a-maastokarttas-geographic-region-mechanism-revision-2)). This is not expected to be materially more frequent than ordinary switching in typical use, but is flagged honestly as a real increase in reload frequency, not glossed over.

**Revision 3 adds no third trigger here.** The zoom gate ([§3B](#3b-maastokarttas-zoom-gated-mml-inclusion-revision-3)) is deliberately not a `_styleGeneration` trigger at all — it is a static layer property MapLibre evaluates natively, with no style regeneration, no `onStyleLoadedCallback` re-fire, and therefore no interaction with `StyleRestorationTracker`/`_ensureFishingSpotLayersExist` whatsoever. The reload cadence described above is unchanged by this revision.

**Revision 4 removes Revision 2's second trigger rather than adding a third.** With MML's raster source unconditionally present in the style (§3C), `_onCameraIdle`'s region-driven regeneration branch is removed entirely — there is no longer a region-boundary crossing that bumps `_styleGeneration` at all. **The reload cadence returns to exactly its original shape: once at cold start, once per explicit Maastokartta ↔ Ilmakuva switch, and never otherwise.** This is a genuine simplification, not merely a rebalancing — see [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)'s migration plan.

---

## 6. Switching Mechanism — Unchanged in Shape, Plus One New Automatic Trigger

`_onBaseMapSelected`, `_persistBaseMapSelection`, `_stylePathFor` (delegating to `WorldwideStyleFactory` instead of `MmlStyleFactory` directly), and the `_latestRequestedBaseMap`/out-of-order-persistence-write guard are **not restructured**. The only change is what `_stylePathFor(baseMap)` asks `WorldwideStyleFactory` to build — per [§3](#3-per-selection-style-composition)'s explicit per-`BaseMap` branch, rather than a uniform "MapTiler fragment plus selected-MML fragment" composition. Switching to Ilmakuva now regenerates a *smaller* style file (at most one source) than switching to Maastokartta (at most two) — if anything a cheaper operation than the original design's symmetric composition, not a more expensive one.

**New in Revision 2:** `_onCameraIdle` (see [§3A](#3a-maastokarttas-geographic-region-mechanism-revision-2)) is a second entry point into the same regeneration pipeline `_onBaseMapSelected` already uses, triggered automatically rather than by a user tap. It does **not** call `_persistBaseMapSelection` — a region-driven MML inclusion/exclusion is never a persisted preference, only which `BaseMap` (Maastokartta/Ilmakuva) is selected remains persisted, unchanged from Revision 1/TD-026.

**Revision 3 does not add a third entry point into this pipeline.** The zoom gate never calls `_stylePathFor`, never bumps `_styleGeneration`, and never regenerates a style file — see [§3B](#3b-maastokarttas-zoom-gated-mml-inclusion-revision-3). `_onCameraIdle` gains one additional, independent line of work (reading the current zoom for `MapAttribution`'s benefit), not a new branch of this switching mechanism.

**Revision 4 removes Revision 2's entry point.** `_onCameraIdle`'s region-driven call into this pipeline is deleted (§3C's migration plan) — `_onBaseMapSelected` (an explicit user tap) becomes, once again, the only way this pipeline is ever entered, exactly as in Revision 1/TD-026. `WorldwideStyleFactory`'s `buildStyle` for Maastokartta once again takes `mmlAvailable: !MmlConfig.isMissing` with nothing else folded in — the same computation `styleFor()` itself already performs, so `MapScreen` could plausibly call `styleFor()` directly again for both selections if a future cleanup pass chooses to; not required by this document, noted as a reasonable simplification opportunity.

---

## 7. Selector UX — Unchanged

`BaseMapLayersControl` and `BaseMapSelectorPanel` are not modified. MFS-027 FR-1 requires the selector to continue offering exactly two choices; MapTiler is never added as a third tile, toggle, or option, for either selection.

---

## 8. Credential Configuration

```dart
// lib/core/map/maptiler_config.dart — unchanged from the original design

class MapTilerConfig {
  const MapTilerConfig._();

  static const String _apiKey = String.fromEnvironment('MAPTILER_API_KEY');

  static bool get isMissing => _apiKey.isEmpty;

  static String get apiKey => _apiKey;
}
```

- **Configuration key name:** `MAPTILER_API_KEY` — one value, covering both the Outdoor fragment (Maastokartta) and the Satellite Hybrid fragment (Ilmakuva). This is the same MapTiler account/credential, not two separate integrations.
- **Wire format:** appended as the `key` query-string parameter on both MapTiler tile URLs ([§0](#0-pre-implementation-verification-completed)).
- **Local development command:**

  ```bash
  flutter run --dart-define=MML_API_KEY=your-mml-key --dart-define=MAPTILER_API_KEY=your-maptiler-key
  ```

- **Independence, restated:** `MapTilerConfig.isMissing` and `MmlConfig.isMissing` are checked completely separately. For Maastokartta, a missing MapTiler key omits only the Outdoor fragment; a missing MML key omits only MML's fragment. For Ilmakuva, only `MapTilerConfig.isMissing` is ever consulted — `MmlConfig` is not part of that selection's style-building path at all.
- **Not treated as cryptographically secret**, for the same accepted reason as MML's key.
- **(Revision 4)** `MmlConfig.apiKey` is now consumed *only* inside the on-device tile-masking service's own outbound request to MML's real endpoint (§3C) — it must never appear in the MapLibre style document, the local loopback URL, any log line, any cache filename, or any error message. This is a stricter, explicit requirement introduced specifically because the on-device fetching step now exists; see [§12](#12-testing-strategy) for how this is tested.

---

## 9. Loading and Failure Behavior

Restructured around the two, now-asymmetric compositions, using the same three-tier distinction TD-026 already established (individual tile failure: silent; app-detectable missing configuration: a lightweight banner; whole-style timeout: unchanged, provider-agnostic):

### Maastokartta

| Situation | Who detects it | Handling |
|---|---|---|
| ~~Viewport outside Maastokartta's Finland region ([§3A](#3a-maastokarttas-geographic-region-mechanism-revision-2))~~ / ~~camera zoom below MML's activation threshold ([§3B](#3b-maastokarttas-zoom-gated-mml-inclusion-revision-3))~~ | — | **Superseded by Revision 4 — kept as a historical record.** There is no longer a viewport-level "is MML in or out" state for either row to describe; see the pixel-level row below. |
| The viewport shows an area (fully or partially) outside real Finnish/Åland coverage, at any zoom | Not app-detected at all — the on-device tile-masking service, per tile, independent of viewport ([§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)) | **Not a failure.** Out-of-coverage MML pixels are transparent; MapTiler Outdoor shows through, per pixel, wherever that's true. No banner, no technical detail, no style regeneration, no app-level check — `MapScreen` is not involved in this decision at all under Revision 4. |
| A single MapTiler Outdoor tile fails to load (transient) | MapLibre GL Native, internally | No app-level handling — unchanged. |
| A single MML tile fails, times out, or returns malformed data at the local tile-masking service | The local service itself, per request ([§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)) | Not surfaced as an app-level failure. That tile is answered with the same shared transparent-PNG fallback classification-B tiles already use — MapTiler Outdoor shows through for that tile, self-healing on a later request. Not written to the persistent cache under that tile's key. |
| MapTiler Outdoor systemically unavailable, MML available | Not independently detectable by the app (no per-source error callback exists — [§0](#0-pre-implementation-verification-completed)) | No new banner. MapTiler Outdoor's tiles simply fail to render wherever they would have been visible; MML (and, above it, fishing spots) remain fully visible and usable — a direct structural consequence of [§3](#3-per-selection-style-composition)'s design. |
| MML systemically unavailable (e.g. the local service itself fails to start, or every upstream request fails), MapTiler Outdoor available | The app, for "local service failed to start" specifically ([§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)); otherwise not independently detectable, same as any other systemic failure | If the local service never started: MML's source is omitted from the style entirely, same effective outcome as a missing key. If the service is running but every individual MML fetch is failing: each affected tile degrades per the row above; MapTiler Outdoor's layer, sitting beneath MML's, shows through throughout — either way, MapTiler Outdoor remains fully visible and usable. |
| Missing/invalid MapTiler API key | The app, reliably, before any request (`MapTilerConfig.isMissing`) | MapTiler Outdoor's source/layer is omitted; MML (if configured) continues to work normally within its coverage. |
| Missing/invalid MML API key | The app, reliably, before any request (`MmlConfig.isMissing`) — unchanged from TD-026 | MML's source/layer is omitted from the style (the local service need not even be consulted); MapTiler Outdoor (if configured) is shown everywhere, including areas that would otherwise have shown MML. |
| Both API keys missing/invalid | The app, reliably, before any request | The existing TD-026 "Karttapohjan asetukset puuttuvat." banner is shown, using the same generalized condition described below. |
| Whole-style load never completes at all (true "no network," including the glyphs fetch stalling) | The app, heuristically, via the existing bounded timeout (`_startStyleLoadTimeout`, unchanged) | Unchanged from TD-026 — provider-agnostic, not made more or less likely by this milestone. |

### Ilmakuva

| Situation | Who detects it | Handling |
|---|---|---|
| A single MapTiler Satellite Hybrid tile fails to load (transient) | MapLibre GL Native, internally | No app-level handling. |
| MapTiler Satellite Hybrid systemically unavailable | Not independently detectable by the app | No new banner by default; the map shows no base imagery wherever tiles fail — **there is no fallback provider for this selection**, unlike Maastokartta. Application-owned content (fishing spots, controls, other entry points) remains as usable as reasonably possible regardless, per MFS-026 FR-16/FR-17's established principle. |
| Missing/invalid MapTiler API key | The app, reliably, before any request (`MapTilerConfig.isMissing`) | Ilmakuva's source is omitted entirely — the generated style has no raster source at all (structurally identical to today's existing blank-style fallback). The whole-style timeout / missing-configuration banner condition (below) applies, since Ilmakuva has nothing else to show. |
| Whole-style load never completes at all (true "no network") | The app, heuristically, via the existing bounded timeout | Unchanged mechanism; for Ilmakuva this is functionally the same observable outcome as "MapTiler key missing," since either way there is no content to render — the banner condition below covers both. |

### Shared missing-configuration banner condition

The existing TD-026 "Karttapohjan asetukset puuttuvat." banner's trigger condition is generalized from `MmlConfig.isMissing` alone to a per-selection check:

- **Maastokartta:** shown when `MmlConfig.isMissing && MapTilerConfig.isMissing` (both configurations missing) — either one alone still leaves a usable base map, so the banner is reserved for the case where neither would render anything.
- **Ilmakuva:** shown when `MapTilerConfig.isMissing` alone — since Ilmakuva has no second provider, a missing MapTiler key alone already means there is nothing to show for this selection.

Both cases reuse the exact same non-technical message, per MFS-026/MFS-027's established principle that the angler does not need provider-specific detail.

**Non-negotiable, in every row above (unchanged from TD-026):** no API key, raw request URL, HTTP status code, stack trace, or provider-specific technical string is ever shown to the user, for any provider.

**Honest limit, restated from the original design and now applying to both compositions:** no plugin-level signal exists to distinguish "a provider's tile server is systemically failing" from "this specific tile legitimately has no data" (Maastokartta only — Ilmakuva has no no-data-tile concept at all, since its coverage is uniform). A dedicated, reliably-triggered "this provider is specifically degraded right now" indicator beyond the missing-key check is not something this plugin version can build correctly, and this document does not attempt one.

---

## 10. Existing `MapControls` and Selector — Untouched

Restated for completeness: this document makes no change to `MapControls` or to `BaseMapLayersControl`/`BaseMapSelectorPanel` (the MFS-026 selector), per MFS-027's explicit scope constraint against redesigning either.

---

## 11. Attribution Design

### Requirement, restated precisely, per selection

**Simplified by Revision 4, superseding the region/zoom-dependent version Revisions 2 and 3 each required in turn (kept below as a historical record).**

- **Maastokartta, MML configured:** both MML's existing attribution (`MapAttribution`) and MapTiler's attribution (for Outdoor) must be shown — unconditionally, matching MML's own now-unconditional presence in the composition (§3C).
- **Maastokartta, MML not configured:** only MapTiler's attribution applies.
- **Ilmakuva:** only MapTiler's attribution (for Satellite Hybrid) must be shown. **MML's attribution must not be shown** — MML data is not part of this composition, and displaying its attribution would misattribute content that is not actually present.

~~Maastokartta, viewport within its Finland region, zoom at or above MML's activation threshold, and MML configured: both attributions shown; outside the region or below the threshold: only MapTiler's.~~ **Superseded by Revision 4.**

Per [§0](#0-pre-implementation-verification-completed), MapTiler's own requirement is identical for both products: the exact text `© MapTiler © OpenStreetMap contributors` (both parts linked), plus a visible MapTiler logo on the free tier this project uses. MapTiler's notice must be **continuously available** whenever MapTiler is part of the active composition (which, for both selections, is always, once configured) — not conditionally shown based on detected viewport/coverage. **MML's notice now follows the identical pattern**, restoring the "no viewport/coverage detection for either widget" property this section's own Design subsection already asserted (accurately again, as of Revision 4).

### Design

A new, small widget, `MapTilerAttribution`, is added alongside the existing `MapAttribution` — and `MapAttribution` itself gains one new condition:

- **`MapTilerAttribution`** (new, unchanged by any revision): an always-visible small MapTiler logo mark, tapping which opens a small, dismissible panel containing the full required text with both links tappable. Shown whenever `MapTilerConfig.isMissing == false`, **for both** `BaseMap` selections.
- **`MapAttribution`** (modified): rendered whenever `baseMap == BaseMap.maastokartta` **AND** `MmlConfig.isMissing == false` — nothing else. ~~Previously additionally required `_mmlActiveForViewport` (Revision 2) and `_mmlZoomActive` (Revision 3).~~ **Both removed by Revision 4** ([§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)'s migration plan) — `MapScreen` no longer tracks either, and this condition is exactly what it would have been under Revision 1, before any viewport-awareness was ever added to it.
- **No viewport/coverage detection is used** for either widget's visibility — both are driven purely by (a) which `BaseMap` is selected and (b) whether the relevant credential is configured. This sentence was already written before Revision 2 existed; Revision 4 makes it true again, not for the first time.

### Why this satisfies the requirement without clutter

Unchanged from the original design: `MapTilerAttribution`'s permanently-visible footprint is a single small logo mark, with the full text-and-links obligation satisfied on demand via tap. The one addition — conditionally hiding `MapAttribution` for Ilmakuva — actually *reduces* clutter for that selection (one attribution notice instead of two, correctly reflecting that only one provider is actually in use).

### What this document does not decide

Exact logo asset sourcing, exact panel styling, exact spacing/alignment, and the specific URL-launch package/mechanism remain implementation-time decisions, unchanged from the original design.

---

## 12. Testing Strategy

Per TD-026's own established constraint: every `MapScreen`-level test must use bounded `tester.pump(Duration(...))`, never `pumpAndSettle()`.

### New/extended pure-logic tests (deterministic, fully unit-testable)

- `maptiler_config_test.dart` — mirrors `mml_config_test.dart`: `MapTilerConfig.isMissing` is `true` when `MAPTILER_API_KEY` is not supplied.
- `maptiler_style_factory_test.dart` — using a synthetic non-empty test key: both the Outdoor and Satellite Hybrid fragment builders use the standard `{z}/{x}/{y}` order (explicitly **not** reversed the way MML's is), the correct style id each (`outdoor-v4` / `hybrid-v4`), `tileSize: 256`, `minzoom: 0`, `maxzoom: 22` (both fragments — a direct regression test for the confirmed TileJSON values), and `?key=<value>` (not `?api-key=`).
- `worldwide_style_factory_test.dart` — the composition logic itself:
  - **Maastokartta:** both MapTiler Outdoor's and MML's fragments present when both keys are configured, with Outdoor's layer entry appearing before MML's in the generated `"layers"` array; only one or the other present when the corresponding key is missing; neither present when both are missing.
  - **Ilmakuva:** only the Satellite Hybrid fragment present when the MapTiler key is configured; **no MML fragment present under any circumstance for this selection**, including a direct regression assertion that `MmlConfig`/`MmlStyleFactory` state has no effect on Ilmakuva's generated style at all; an empty `sources`/`layers` set (glyphs URL only) when the MapTiler key is missing.
  - The `glyphs` URL is present in every generated variant, for both selections, including the no-source case.
- `mml_style_factory_test.dart` (**extended, Revision 5** — Revision 3's own planned extension, described here since TD-027 §3B/§3, was never implemented at the time; Revision 5 finally adds the equivalent assertion, for a presentation-only rather than masking-critical constant) — a new assertion that MML's generated raster **layer** object carries `"minzoom": MmlStyleFactory.presentationMinZoom`, and a direct regression assertion that this is a *layer* property (present on the object in the `"layers"` array) and not merely a restatement of the *source*'s own already-existing `"minzoom": 0` (present on the object in `"sources"`) — the two must remain independently correct, per [§3B](#3b-maastokarttas-zoom-gated-mml-inclusion-revision-3)'s explicit distinction between them, carried forward into [§3D](#3d-boundary-no-data-connected-component-refinement--presentation-minzoom-revision-5). Every other existing assertion in this file is otherwise unaffected.
- `mml_coverage_region_test.dart` (**new, Revision 2**) — fully pure, deterministic, and unit-testable with no native map surface required. Both a small synthetic test polygon (to exercise the algorithm's general logic cheaply) and the real bundled Finland+Åland data (to guard against a real-data regression) are used, per the following cases:
  - A point well inside the real polygon, previously inactive, becomes active immediately (`isMmlActiveFor(..., wasActive: false) == true`) — the direct regression test for "entry never has a margin-related delay."
  - A point well outside the real polygon by more than the exit margin, previously active, becomes inactive.
  - A point outside the real polygon but within the exit margin, previously active, **stays active** — the direct regression test for the exit buffer.
  - The same within-margin point, previously **inactive**, stays inactive (it has not crossed the real entry boundary) — the direct regression test for the asymmetric design (this is *not* the same as the exit case above; conflating them would silently reintroduce the rejected symmetric-shrink design).
  - Real-data regression: Helsinki, Haparanda/Tornio, and Utsjoki all classify as inside; Stockholm and a Baltic Sea point classify as outside; the cold-launch default camera position (`_initialCameraPosition.target`) classifies as inside — mirroring the exact sanity checks already verified manually during this design's investigation (§3A), now captured as permanent regression tests.
  - A point exactly on the polygon boundary is deterministic (does not flip between test runs).
  - **Unaffected by Revision 3** — this file, and `MmlCoverageRegion` itself, needs no new cases: the zoom gate is an entirely separate condition, tested independently (see `mml_style_factory_test.dart` above).

### `MapScreen` integration tests (extended in `map_screen_test.dart`)

- With both keys configured and Maastokartta selected, the constructed style contains both a MapTiler Outdoor and an MML source.
- With Ilmakuva selected (regardless of `MmlConfig`'s state), the constructed style contains at most one source (MapTiler Satellite Hybrid) and never an MML source.
- Switching from Maastokartta to Ilmakuva and back exercises both style shapes correctly; the pre-existing switching/persistence/regression tests continue to pass unmodified.
- **Attribution:** a new test confirms `MapAttribution` is present while Maastokartta is selected with the cold-start (Finland-centered) camera position and **absent** while Ilmakuva is selected; `MapTilerAttribution` is present for both selections whenever `MapTilerConfig` is configured.
- The pre-existing `openLureToolsButton`/`openStatisticsButton`/`openCatchSearchButton` and `MapControls` regression tests continue to pass unmodified.
- **Revision 3 caveat, stated plainly:** the cold-start attribution assertion above was written against Revision 2's cold-launch expectation (`_initialCameraPosition`'s `zoom: 5`). If the physically-determined activation threshold ([§3B](#3b-maastokarttas-zoom-gated-mml-inclusion-revision-3)) turns out to be above `5` and `_initialCameraPosition`'s zoom is not also raised to match, this specific existing test's expectation ("`MapAttribution` present... with the cold-start camera position") becomes incorrect and must be updated as part of implementing Revision 3 — not silently left passing against an assumption Revision 3 has since invalidated. This is called out explicitly here so it is not missed during implementation.

### Explicitly not attempted

No deterministic unit test asserts on real MapTiler or MML network/tile availability — every failure-handling assertion is either a pure-logic test (config/factory level) or a widget-tree-level assertion, never a live network expectation.

**A genuine, `maplibre_gl`-specific headless-test limitation, new in Revision 2:** this project's headless test environment cannot drive a real `onCameraIdle` firing with a real, moved camera position — `MapLibreMap` embeds a platform view that does not actually respond to programmatic camera moves in this environment (the same underlying limitation `map_screen_test.dart`'s own file-level doc comment already documents for style loading). Revision 2's `_onCameraIdle`/`MmlCoverageRegion` interaction is therefore tested at two separate levels, not as one true end-to-end test: `MmlCoverageRegion`'s own hysteresis logic is fully covered in isolation (pure, no map surface needed — see above), and `MapScreen`'s wiring of `_onCameraIdle` to the same regeneration pipeline `_onBaseMapSelected` already uses is covered by inspection/code review plus the existing regeneration-pipeline tests, not by a widget test that actually simulates a real pan across the region boundary. This gap is explicitly called out here rather than silently assumed covered — physical Android testing (below) is where the real, end-to-end behavior is actually verified.

**The same limitation applies to Revision 3's zoom gate, for two distinct reasons, not one.** First, the same `onCameraIdle`-simulation gap above applies identically to `_mmlZoomActive`'s own wiring (a real zoom change cannot be driven programmatically in this headless environment either). Second, and more fundamentally, **the actual visual defect this revision fixes — MML's tile content rendering incompletely at low zoom — is not something any automated test in this project can observe at all**, headless or otherwise: it requires a real MML tile server response, rendered by a real MapLibre GL Native surface, visually inspected. `MmlStyleFactory`'s own test (above) can confirm the `minzoom` *value* is correctly present in the generated JSON; it cannot confirm that value is the *correct* one, or that MapLibre's layer-hiding behavior actually looks clean above it on a real device. That confirmation is exclusively the physical test's job — both the one described in [§3B](#3b-maastokarttas-zoom-gated-mml-inclusion-revision-3) that determines the threshold, and the physical Android checklist items below that verify the shipped behavior once it is set.

### Revision 4 additions — the on-device tile-masking service

**Unlike Revisions 2/3, most of Revision 4's own logic *is* fully unit-testable, with no native map surface or live network involved**, since the service is ordinary Dart code operating on bytes — a meaningful testing improvement over both prior revisions, worth noting explicitly.

New/extended pure-logic tests:

- **Tile-bounds math** — `z/x/y` → Web Mercator/lon-lat bounds, verified against hand-computed reference values (the same tile-coordinate math already used to compute this session's own real-tile test-request coordinates).
- **Classification (A/B/C)** — synthetic small polygons (fast, easy to reason about) plus the real bundled coverage geometry: a deep-Finland-interior tile classifies A; a deep-Sweden/Russia tile classifies B; a tile straddling the Finland/Russia border near Imatra and one straddling the Finland/Sweden border near Tornio both classify C; an Åland tile and an archipelago/coastline tile are exercised specifically, per the task's own explicit instruction. A fully-outside classification for a tile whose bounding box is nowhere near any polygon vertex (cheap-reject path) and a fully-inside classification for a tile entirely surrounded by polygon (no edge/vertex nearby) are both covered, not just boundary-adjacent cases.
- **Boundary masking, golden/image-level** — a small synthetic polygon and a synthetic solid-color RGBA input tile, asserting the *exact* output alpha for definitively-inside and definitively-outside pixels, and a *not-fully-binary* (intermediate) alpha for pixels in the anti-aliased edge band. A separate test asserts inside pixels' RGB is bit-for-bit unchanged from the input. **Using the four real MML tiles already captured this session (`FinlandInterior`/`ImatraBorder`/`TornioBorder`/`Stockholm`) as bundled test fixtures** (copied into `test/fixtures/`, containing no credential and requiring none to use) is explicitly recommended here: they provide real, already-analyzed MML pixel content — including the exact confirmed 69.81% `RGB(204,204,204)` Russian no-data region — to regression-test the real masking algorithm against without ever needing a live key in the test suite.
- **Cache** — a tile requested twice returns identical bytes with the underlying fetch/process function invoked only once (a call-counting fake); a version-bump changes the cache key/namespace; disk cache survives a simulated restart (same mechanism already used elsewhere in this project to avoid a real `path_provider` platform channel in tests).
- **Concurrent request coalescing** — two simultaneous requests for the same `z/x/y`, verified (via a fake with a controllable `Completer`) to invoke the underlying fetch/process function exactly once, with both callers receiving the same result.
- **MML failure / malformed PNG** — a fake fetch that times out, errors, or returns garbage bytes, asserted to produce the shared transparent-PNG fallback and **not** write anything to the persistent cache under that tile's key.
- **Service lifecycle** — starts, reports a real bound port, responds to a request, stops cleanly; a second start attempt after a stop succeeds (no leaked state).
- **Credential secrecy** — a structural, provable-by-construction test: the generated Maastokartta style JSON's MML tile URL template is asserted to **not** contain the configured `MmlConfig.apiKey` value as a substring (the local loopback URL is the only thing that should appear there). This is necessarily a partial guarantee (it cannot exhaustively prove no log line anywhere ever contains the key) but directly tests the one artifact most likely to leak it if the design were wrong.

### Revision 5 additions — boundary no-data connected-component refinement + presentation minzoom

- **Real-fixture no-data removal, `mml_tile_masker_test.dart`** — using an all-covering synthetic geometry (isolating exactly what the no-data refinement itself removes, independent of the geometry mask) against all 10 real bundled fixtures: `ImatraBorder` (45,537px removed), `TornioBorder` (4,452px removed), `AlandWest` (23,941px removed), `GulfFinlandRussia` (2,499px removed) — each an exact-count regression assertion, not a range — and `FinlandInterior`, `HelsinkiGulf`, `TurkuArchipelago`, `BothnianBay`, `OpenSeaControl` (all exactly 0px removed, confirming legitimate small/non-qualifying gray content is never touched). A separate test confirms retained pixels' RGB remains bit-for-bit unchanged even in a tile where a large no-data component was also removed.
- **Synthetic size/edge threshold, `mml_tile_masker_test.dart`** — a 999px edge-touching synthetic gray component is preserved (below `noDataComponentMinPixels`); a 1,000px edge-touching component is removed (meets both criteria); a large (22,500px) gray component that touches no tile edge is preserved regardless of size (the direct regression test for "edge-touching is required, not size alone").
- **Presentation minzoom, `mml_style_factory_test.dart`** — see the extended-test entry above.
- **Not attempted, for the same reason as every prior zoom/viewport-visual claim in this document:** no automated test can confirm the chosen `presentationMinZoom` value actually *looks* correct on a real device, or that the boundary no-data refinement actually looks clean at the Virolahti border on a real device rather than merely in a decoded-PNG pixel count. Both are exclusively the physical checklist's job (below).

### Revision 6 additions — content-driven masking, coarse fetch envelope

- **Real-fixture regression, re-verified, `mml_tile_masker_test.dart`** — all 10 original fixtures' exact-count gray-removal assertions are unchanged (confirming the new white check and whole-tile check introduce no gray regressions); `OpenSeaControl`'s expectation changed from "0px removed" to "65,536px removed, the whole tile" — a deliberate, evidence-backed behavior change (12 distinct colors, below `minDistinctColorsForContent`), not a regression, documented explicitly in the test itself.
- **Whole-tile flat/generic threshold, synthetic** — a tile with exactly 49 distinct colors is fully transparent; exactly 50 distinct colors proceeds to the content-driven path.
- **White no-data component size/edge threshold, synthetic** — a 9,999px edge-touching white component is preserved (below `noDataWhiteComponentMinPixels`); 10,000px is removed; a large (22,500px) non-edge-touching white component is preserved regardless of size — the same pattern already proven for gray.
- **Gray no-data threshold tests re-verified against a richer synthetic background** (64 distinct colors, not the prior 2-color tile) — the prior synthetic tiles used only a background color plus the no-data-color rectangle (2 distinct colors total), which would now trigger the new whole-tile flat/generic shortcut before the component check ever ran; the richer background clears that threshold so these tests continue to isolate the component-detection logic specifically.
- **Classification re-verified against the new, much larger fetch envelope** — several real locations that previously classified `outside` (deep interior Sweden, deep interior Russia, open Baltic Sea near Åland) now correctly classify `boundary`, since all three fall within the new envelope; new tests confirm genuinely far-outside locations (Gothenburg/far Sweden, far east Russia, Paris) still classify `outside`; Åland, Föglö, and a conservative nearby-sea point all classify `boundary`, matching the transect evidence.
- **A direct regression test that `maskTile` no longer produces any geometry-derived alpha gradient** — a rich, multi-color synthetic tile with no confirmed no-data component of either color is fully opaque everywhere, RGB unchanged, regardless of the (irrelevant, now-unused-by-`maskTile`) `region` parameter.
- **Service-level integration, `mml_tile_mask_service_test.dart`** — a flat, single-color upstream tile fetched for a `boundary`-classified tile now resolves (byte-for-byte, not by object identity — `Isolate.run` copies data across the isolate boundary) to the shared `transparentTile`, confirming the whole-tile check is correctly wired through the isolate dispatch.
- **`cacheVersion` bump to `v3`** — asserted the same way prior bumps were, via the existing stale-cache-pruning test (generic against whatever `cacheVersion` currently is).
- **Not attempted, same reasoning as every prior revision:** no automated test can confirm the white region is actually gone at Imatra/Nuijamaa/Vaalimaa on a real device, that Åland/Föglö render as continuous archipelago coverage without circular cutouts, or that the coarse envelope's performance impact is acceptable in practice. All exclusively the physical checklist's job (below).

### Physical Android Testing Checklist

1. Cold launch in Finland (no prior install/data) — Maastokartta shown by default, no visible flash of any placeholder.
2. Maastokartta in Finland — renders identically to the current, already-verified MFS-026 behavior (MML Maastokartta cartography).
3. Ilmakuva in Finland — **renders MapTiler Satellite Hybrid, not MML Ortokuva** — confirm this is the intended appearance, and specifically assess whether MapTiler's imagery resolution over Finland is visually acceptable compared to the previously shown MML aerial photography (see [§14 Risks](#14-risks-and-mitigations)).
4. Pan from Finland to Sweden or France with Maastokartta selected — MapTiler Outdoor becomes visible automatically, with no user action.
5. Return to Finland with Maastokartta selected — MML Maastokartta's own content is shown again, naturally.
6. Pan from Finland to Sweden or France with Ilmakuva selected — the same MapTiler Satellite Hybrid imagery continues seamlessly, with **no visible change at all** at the border (unlike Maastokartta).
7. Switch Maastokartta ↔ Ilmakuva while inside Finland — confirm the visible content changes correctly each way (MML Maastokartta ↔ MapTiler Satellite Hybrid).
8. Switch Maastokartta ↔ Ilmakuva while outside MML's coverage — confirm the map remains populated throughout (MapTiler Outdoor ↔ MapTiler Satellite Hybrid), never blank at any point.
9. Fishing spots (markers + labels) remain visible and interactable over every composition, including immediately after any switch.
10. Restart the app after selecting Ilmakuva — Ilmakuva (i.e., MapTiler Satellite Hybrid) is active again on relaunch.
11. Attribution while Maastokartta is selected: both MML's existing text and MapTiler's compact logo/attribution control are visible; tapping MapTiler's reveals the full required text with both links working.
12. Attribution while Ilmakuva is selected: **only** MapTiler's compact logo/attribution control is visible — confirm MML's attribution text does **not** appear.
13. Missing `MAPTILER_API_KEY` (build without it) with Maastokartta selected — no crash; MapTiler Outdoor's layer/attribution is absent; MML continues to work normally within its coverage.
14. Missing `MAPTILER_API_KEY` with Ilmakuva selected — no crash; the "map imagery unavailable" message appears, since Ilmakuva has nothing else to show; application-owned content (fishing spots, controls) remains usable.
15. Missing `MML_API_KEY` with Maastokartta selected — no crash; MML's layer is absent; MapTiler Outdoor shows everywhere, including within what would be MML's coverage.
16. MapTiler unreachable while Maastokartta is selected and MML is reachable — MML remains fully usable within its coverage.
17. MML unreachable while Maastokartta is selected and MapTiler Outdoor is reachable — MapTiler Outdoor is visible everywhere, including areas that would normally show MML's own cartography.
18. MapTiler unreachable while Ilmakuva is selected — no crash, no technical error, application-owned content remains usable, with no MML fallback expected or shown.
19. Rapid repeated switching between Maastokartta and Ilmakuva (regression) — no crash, no duplicated markers, no stuck intermediate state.
20. Zoom through the normal range and into close/detailed zoom levels, for both selections, both inside and outside Maastokartta's Finland region — both MapTiler products (declared native range z0–22) remain visually useful up to and beyond z22, and MML (declared native range z0–18) remains visually useful up to and beyond z18, each via MapLibre's existing overscale-beyond-maxzoom behavior.
21. **(Revision 2)** Pan from within Finland to Sweden, the Baltic region, and at least one more distant area with Maastokartta selected — confirm no opaque gray/white block, no visible tile/coverage-boundary artifact, and no MML content at all appears once clearly outside the region; this is the specific defect this revision exists to fix, so treat any recurrence as a blocking regression, not a minor cosmetic issue.
22. **(Revision 2)** Zoom out with Maastokartta selected until both Finland and clearly non-Finnish territory are visible in the same view — confirm MML content is confined to the intended region with no large, irregular, visibly-wrong shape extending beyond it.
23. **(Revision 2)** Slowly pan back and forth across the region boundary in small increments (not a large jump) — confirm the map does not flicker or repeatedly reload between MML-included and MapTiler-only content; a brief, single, sensible transition per deliberate crossing is expected, not a stable no-op for arbitrarily large movements.
24. **(Revision 2)** With Maastokartta selected, confirm MML's attribution text is visible while the viewport is within the region and disappears (leaving only MapTiler's attribution) once panned clearly outside it — the same correctness check already required for Ilmakuva, now also required for Maastokartta depending on viewport.
25. **(Revision 2)** Restart the app with Maastokartta persisted and the device's last-used camera position irrelevant (cold start always begins at the fixed default Finland-centered camera) — confirm MML is shown immediately with no incorrect momentary MapTiler-only flash. **(Revision 3 caveat: this specific outcome now depends on whether `_initialCameraPosition`'s zoom is at or above the determined activation threshold — see item 26 and [§3B](#3b-maastokarttas-zoom-gated-mml-inclusion-revision-3)'s "notable, load-bearing consequence" note. If it is not, this item's expected result changes to "MapTiler Outdoor shown immediately, MML appearing once zoomed in past the threshold" — a deliberate, not accidental, outcome.)**

**Revision 3 additions (never executed — Revision 3 was superseded before implementation began):**

~~26–30. (Determine the zoom activation threshold via physical test; confirm no gray/white block below it; confirm smooth transitions; confirm zoom-dependent attribution; confirm cold-launch behavior.)~~ **Superseded by Revision 4 below — kept as a historical record.**

**Revision 4 additions — the actual current checklist for this milestone's remaining physical validation:**

26. **Finland interior** (e.g. central/southern Finland, away from any border): MML renders exactly as before, no masking artifact anywhere in view, at any zoom.
27. **Imatra / Finland–Russia border**: pan so the border is on screen — confirm MML is visible and correct on the Finnish side, MapTiler Outdoor is visible on the Russian side within the *same viewport*, and the transition between them is clean at the pixel level — no gray/white block, no visible seam beyond the intended anti-aliased edge.
28. **Tornio / Finland–Sweden border**: same check as above, at this second, geometrically different border crossing.
29. **Åland**: confirm full, correct MML coverage across the archipelago, with no phantom-missing small islands (the specific risk flagged for the current Natural Earth-sourced polygon's precision — see [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)'s Coverage Geometry).
30. **Southern archipelago / coastline** (e.g. near Turku): confirm the coastal buffer neither clips real, useful MML sea content close to shore nor leaves a visibly-wrong gray patch — this is the specific case the buffer distance exists to get right, and the case most likely to reveal it needs adjusting.
31. **Baltic Sea / open coast, clearly beyond any real coverage**: confirm MapTiler Outdoor alone, with no residual MML artifact.
32. **Low zoom showing Finland and its neighbors simultaneously**: confirm MML content is confined precisely to real coverage at every point in the frame, with no large gray/white block anywhere — this is the original defect this entire multi-revision effort exists to fix, now checked at the zoom level it was originally observed at.
33. **Rapid pan/zoom** across and around the border, sustained: confirm smooth, responsive interaction with no perceptible jank — direct on-device confirmation of the isolate-offloading/caching performance design, which is otherwise only an estimate (§3C).
34. **Maastokartta ↔ Ilmakuva switching**, repeated, at various locations: unaffected by this revision, confirm no regression.
35. **Fishing spots remain stable, with no marker re-flash, while freely panning/zooming across the national border** — the direct, on-device confirmation that no style regeneration occurs for geographic/zoom reasons under Revision 4 (unlike Revisions 2/3, which each had exactly this kind of event by design).
36. **Network failure mid-session** (airplane mode toggle): MML tiles already rendered remain visible; newly-requested tiles degrade gracefully per [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)'s failure behavior (MapTiler shows through), no crash, no technical detail shown.
37. **Performance/memory over an extended session** (e.g. 10+ minutes of active panning across many tiles): no unbounded memory growth, no excessive battery/CPU signature attributable to the local service, disk cache size stays within its configured bound.
38. **Attribution**: MML's attribution is visible whenever Maastokartta is selected and MML is configured, regardless of where the viewport currently is — confirm this holds even when the current view happens to show no MML content at all (e.g. panned to Sweden).
39. **Resolved via remote-tile pixel analysis, not yet via on-device pan/zoom.** [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)'s Coverage Geometry section now records a locked value (10 km), determined by decoding six real MML tiles directly rather than a live device pan/zoom session. This item is retained, narrowed: confirm on a real device, specifically at the Virolahti/Russia-border stretch flagged as the tightest measured margin, that no residual gray sliver survives inside the buffered mask there — the one location the desktop analysis itself flagged as not comfortably safe. Items 27/28/30 should now be run against this real, non-placeholder value.

**Revision 5 additions — superseded in part by Revision 6 below (items 40–42 specifically targeted the now-replaced geometry-alpha/gray-only mechanism; re-tested as items 47–50):**

~~40. Virolahti/Russia-border stretch, re-tested with the Revision 5 no-data refinement active.~~ **Superseded by item 47.**
~~41. Imatra and Tornio borders, re-tested with the Revision 5 no-data refinement active.~~ **Superseded by item 48.**
~~42. A genuinely gray real MML feature near a tile edge, confirming the 1,000px/edge-touching threshold does not misfire.~~ **Superseded by item 51 (extended to both colors).**
43. **The physical zoom 6/7/8 comparison procedure specified in [§3D](#3d-boundary-no-data-connected-component-refinement--presentation-minzoom-revision-5)** — run before shipping, to replace the current `presentationMinZoom = 7` placeholder with a device-confirmed value. **Still required, unaffected by Revision 6.**
44. **MML's presentation minzoom transition, once the final value is chosen**: zoom slowly through the chosen threshold, both directions, at several points spanning Finland's extent — confirm no perceptible flicker, stutter, or delay beyond ordinary tile loading (the same "no zoom hysteresis needed" style of confirmation §3B specified for its own, different, now-superseded threshold). **Still required, unaffected by Revision 6.**
45. **World/continent-scale zoom with Maastokartta selected**: confirm MapTiler Outdoor alone is visible, with no small Finland-shaped MML patch — the original defect this revision's Fix 2 exists to remove. **Still required, unaffected by Revision 6.**
46. **Fishing spots remain stable, with no marker re-flash**, across both new behaviors (no-data removal, presentation minzoom) — confirm neither introduces any style regeneration (neither should, by design; this is the on-device confirmation of that design intent). **Still required.**

**Revision 6 additions — not yet performed at all (this revision's own remaining physical validation):**

47. **Imatra and Nuijamaa, re-tested with Revision 6's content-driven masking active**: confirm the previously-visible opaque white region is now gone — valid MML content on the Finnish side, MapTiler beyond, no gray, no white, no artificial gap. Treat any recurrence as a blocking regression.
48. **Vaalimaa** (the third border crossing used for evidence-gathering, not previously physically tested at all): same check as item 47.
49. **Åland and Föglö**: confirm continuous MML sea/archipelago coverage matching the Maastokartat reference — no circular/buffered-land-shaped cutouts around small islands, the exact defect this revision's coarse-envelope-plus-content-driven-masking change exists to fix.
50. **West of Åland toward Sweden, and the Turku archipelago approach east of Åland**: confirm the transect's asymmetric real-content extent is reflected correctly on-device — real content where the transect found it, MapTiler beyond, no artificial cutoff at a uniform distance from land in every direction.
51. **A genuinely white or gray real MML feature near a tile edge** (e.g. a paved area, plaza, or large light-colored building complex, if one can be located near Finland's border/coastline in the app): confirm it is **not** incorrectly removed by either color's threshold — the direct on-device confirmation complementing the desktop pixel-count regression tests, now covering both colors.
52. **Sustained pan/zoom specifically around the widened fetch envelope** (open Baltic Sea, deep interior Sweden/Russia near the border — areas newly reclassified from `outside` to `boundary`): performance re-benchmark, explicitly checking for the kind of severe lag Revision 4 originally caused before its caching/isolate design was tuned — confirm the new, cheaper-per-tile algorithm does not regress this.
53. **Low zoom, Maastokartta ↔ Ilmakuva switching, and fishing-spot marker stability**: general regression pass across all of Revision 6's changes, at various locations spanning the widened envelope.

---

## 13. Files Affected — File Plan

### New files

```text
lib/core/map/maptiler_config.dart
lib/core/map/maptiler_style_factory.dart
lib/core/map/worldwide_style_factory.dart
lib/features/map/presentation/widgets/maptiler_attribution.dart

test/core/map/maptiler_config_test.dart
test/core/map/maptiler_style_factory_test.dart
test/core/map/worldwide_style_factory_test.dart
test/features/map/presentation/widgets/maptiler_attribution_test.dart
```

**New in Revision 2** (in addition to the above, which Revision 1 already established and implemented — this revision's own files are the only ones not yet created as of this document):

```text
lib/core/map/mml_coverage_region.dart   (Revision 2 — repurposed, not removed, by Revision 4; see below)

test/core/map/mml_coverage_region_test.dart
```

**New in Revision 4** (superseding Revision 3's own never-created file plan):

```text
lib/core/map/mml_tile_mask_service.dart     (the local HTTP tile-masking service — lifecycle, classification, request handling, caching, coalescing)
lib/core/map/mml_tile_masker.dart           (the pure boundary-tile pixel-masking algorithm — rasterization, anti-aliasing, compositing; kept separate from the HTTP/service concerns above so the actual image-processing logic is independently unit-testable with no server involved)

test/core/map/mml_tile_mask_service_test.dart
test/core/map/mml_tile_masker_test.dart
test/fixtures/mml_border_test/FinlandInterior.png   (real MML tile fixtures, captured this session — see §12)
test/fixtures/mml_border_test/ImatraBorder.png
test/fixtures/mml_border_test/TornioBorder.png
test/fixtures/mml_border_test/Stockholm.png

test/fixtures/mml_buffer_test/HelsinkiGulf.png        (real MML tile fixtures used to determine the 10 km buffer — see §3C Coverage Geometry)
test/fixtures/mml_buffer_test/TurkuArchipelago.png
test/fixtures/mml_buffer_test/AlandWest.png
test/fixtures/mml_buffer_test/BothnianBay.png
test/fixtures/mml_buffer_test/GulfFinlandRussia.png
test/fixtures/mml_buffer_test/OpenSeaControl.png
```

**No new files in Revision 5** — both fixes extend existing Revision 4 files; all 10 real fixtures needed for regression testing were already bundled by Revision 4.

### Modified files

```text
lib/features/map/presentation/map_screen.dart          (owns the local tile-mask service's lifecycle (start in initState, awaited before the first style build, stopped in dispose); WorldwideStyleFactory/MmlStyleFactory now receive the local base URL. Revision 2/3 state and logic REMOVED, not extended: _mmlActiveForViewport, _mmlZoomActive (never built), and _onCameraIdle's region-driven regeneration branch are all deleted — see §3C's migration plan. MapAttribution's condition reverts to "Maastokartta selected AND MmlConfig configured." Temporary debug-zoom overlay (_debugCameraZoom/_onDebugCameraMove and its widget) removed once this revision ships (retained for now per explicit instruction — see §3C).)
lib/features/map/presentation/widgets/map_attribution.dart  (no internal change — unaffected by any revision; see §11)
lib/core/map/worldwide_style_factory.dart               (Revision 4: Maastokartta's mmlAvailable computation reverts to !MmlConfig.isMissing alone — the region/zoom-aware richer computation Revision 2/3 required at MapScreen's call site is no longer needed, since MML's inclusion is unconditional whenever configured. buildStyle's public, non-@visibleForTesting status from Revision 2 is unaffected — it remains real production API, just called with a simpler argument again.)
lib/core/map/mml_style_factory.dart                     (Revision 4: tile URL template points at the local service's loopback address instead of MML directly, taking the local base URL as a new constructor/method parameter. No layer-level minzoom is added — Revision 3's plan for this file is abandoned, never implemented. **Revision 5:** adds `presentationMinZoom` (placeholder `7`, pending physical confirmation — see §3D) as a new named constant, applied to the generated raster **layer** object only; the raster **source**'s own `minzoom: 0` is unchanged.)
lib/core/map/mml_coverage_region.dart                   (Revision 4: repurposed — isMmlActiveFor/hysteresis API removed (no caller remains); polygon data and point-in-polygon primitives retained and reused by mml_tile_masker.dart's rasterization. **Revision 6:** doc comments updated to reflect its narrowed role (classify's "clearly inside" fast path only — no pixel-alpha role of any kind survives); no functional change.)
lib/core/map/mml_tile_masker.dart                       (**Revision 5:** adds the boundary no-data connected-component refinement — `noDataGray`, `noDataComponentMinPixels`, `_confirmedNoDataMask`, wired into `maskTile`'s existing per-pixel alpha composition. **Revision 6:** `_rasterizeCoverageAlpha`/`_rasterizeInsideRaw`/`_partsNear`/`_edgesNear`/`_expand` — and the now-unused `supersample` field — removed entirely. `maskTile` rewritten to be purely content-driven: a new whole-tile `_distinctColorCount` check (`minDistinctColorsForContent = 50`) short-circuits flat/generic tiles to the shared `transparentTile`; `_confirmedNoDataMask` generalized to accept a target color + threshold, called once each for `noDataGray`/`noDataComponentMinPixels` (unchanged) and the new `noDataWhite`/`noDataWhiteComponentMinPixels = 10000`. New `fetchEnvelopeSouth`/`North`/`West`/`East` instance fields (defaulting to the locked `defaultFetchEnvelope*` constants) drive `classify`'s new "clearly outside" check, replacing the old land-buffer-based one; injectable purely so tests can pair a synthetic envelope with a synthetic `region`.)
lib/core/map/mml_tile_mask_service.dart                 (**Revision 5:** `cacheVersion` bumped `v1` → `v2`. **Revision 6:** bumped again, `v2` → `v3` — boundary-tile output semantics changed completely. `_maskInIsolate` simplified: no longer reconstructs `MmlCoverageRegion`/passes `regionParts` across the isolate boundary at all, since `maskTile` no longer consults `region` in any way.)
test/features/map/presentation/map_screen_test.dart     (extended: local-service-lifecycle-aware pumpMapScreen changes; existing switching/persistence/regression tests preserved; the Revision 3-flagged cold-start attribution caveat no longer applies — attribution is unconditional again, so that specific fragility is removed, not merely relocated. **Unaffected by Revisions 5/6** — attribution zoom-gating is explicitly not implemented, and Ilmakuva/MapTiler/map_screen.dart itself are untouched by Revision 6.)
test/core/map/mml_coverage_region_test.dart             (hysteresis/wasActive-specific cases removed along with the API they tested; point-in-polygon/real-data-regression cases retained, since the underlying geometry logic is still directly exercised via mml_tile_masker.dart. **Unaffected by Revision 6.**)
test/core/map/worldwide_style_factory_test.dart          (Maastokartta's mmlAvailable test matrix simplifies back to the original two-boolean shape, dropping the region/zoom-derived combinations Revision 3's own test-plan draft had proposed but never implemented. **Unaffected by Revision 6.**)
test/core/map/mml_tile_masker_test.dart                  (**Revision 5:** new real-fixture no-data-removal regression tests (all 10 bundled fixtures) and new synthetic size/edge-threshold tests. **Revision 6:** classification tests restructured around the new fetch envelope (synthetic tests now pair a matching synthetic envelope with the synthetic region; real-geometry tests updated — several former "outside" locations are now correctly "boundary"; new genuinely-far-outside tests added); masking tests rewritten around the content-driven pipeline (flat/generic synthetic tests, richer-background synthetic no-data tests so the new whole-tile check doesn't short-circuit them, new white-threshold tests, `OpenSeaControl`'s real-fixture expectation updated to fully-transparent).)
test/core/map/mml_tile_mask_service_test.dart           (**Revision 6:** default test masker gains a matching synthetic fetch envelope (same reason as above); the boundary-tile masking-pipeline test updated for content-driven behavior — a solid-color upstream tile now resolves to the shared transparent tile, asserted by value not identity, since `Isolate.run` copies data across the isolate boundary.)
test/core/map/mml_style_factory_test.dart                (**Revision 5:** new assertion that the generated MML raster layer carries `presentationMinZoom`, distinct from the source's own unrelated `minzoom: 0`. **Unaffected by Revision 6.**)
pubspec.yaml   (see §15 — no new dependency; `dart:io`/`package:image`/`path_provider` are already present and sufficient, unchanged through Revision 6)
```

**Revision 4 introduces genuinely new files, unlike Revision 3** — two new production classes (the HTTP service and the pure masking algorithm, deliberately kept separate) and their tests, plus bundled real-tile fixtures. This is a materially larger implementation footprint than either prior revision, a direct, honest consequence of choosing an on-device processing solution over a declarative style property (which Revision 3 could have used, had its underlying premise held up) — see [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)'s own alternatives-investigated section for why this trade was still the right one. **Revisions 5 and 6, by contrast, introduce no new files at all** — every fix is a refinement of already-existing Revision 4 files, reusing already-bundled fixtures (plus, for Revision 6's evidence-gathering only, 35 additional real tiles fetched and analyzed outside the repository — not bundled as test fixtures).

### Not modified

`lib/core/map/base_map.dart`, `base_map_preference_store.dart`, `mml_config.dart`, `style_restoration_tracker.dart`; `lib/features/map/presentation/widgets/base_map_layers_control.dart`, `base_map_selector_panel.dart`, `map_controls.dart`, `maptiler_attribution.dart`; `lib/core/database/app_database.dart` (no schema impact); every other feature.

### Generated files

None — no Drift table, no `build_runner` impact.

---

## 14. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| ~~Neither MapTiler Outdoor's nor Satellite Hybrid's exact native maximum zoom for the raster tile endpoint was confirmed to a specific number.~~ **Resolved.** | Confirmed directly from both styles' own authenticated TileJSON: `minzoom: 0`, `maxzoom: 22` for both `outdoor-v4` and `hybrid-v4` ([§0](#0-pre-implementation-verification-completed)). Both generated raster sources now declare these values explicitly rather than omitting them. No longer an open risk; retained here only so the record shows this was checked, not assumed. |
| **MapTiler Satellite Hybrid's imagery quality/resolution over Finland specifically has not been verified against MML Ortokuva's own dedicated Finnish aerial photography.** This is a real, user-visible product-quality risk unique to this revision: MML Ortokuva was already shipped and physically validated (MFS-026); Ilmakuva now shows a different, global product whose regional resolution is not uniform. | Recommend a dedicated pre-ship check (physical Android testing checklist item 3): view several real Finnish fishing-spot-relevant locations with Ilmakuva selected and assess whether the resulting image quality is acceptable for the feature's stated purpose (recognizing a shoreline, island, or bay from above). If unacceptable, reconsidering MML Ortokuva's role (per ADR-0009's explicitly-left-open future reconsideration) becomes a real, not merely theoretical, follow-up. |
| No plugin-level signal exists to distinguish "a provider is systemically failing" from "this tile legitimately has no data" (Maastokartta) or "there is simply nothing to show" (Ilmakuva). | Accepted, not worked around with a fragile heuristic — unchanged conclusion from the original design, now confirmed to apply to Satellite Hybrid too. |
| The attribution panel needs to open external links — no URL-launching capability exists anywhere in this codebase today. | A small, standard, widely-used URL-launch package (e.g. `url_launcher`) is the expected addition — unchanged from the original design. |
| MapTiler's raster tile format choice (`.png` vs `.jpg` vs `.webp`) was not fixed for either product. | `.png` remains the recommended default for both; `.jpg`/`.webp` remain available if bandwidth/size testing favors them — a low-risk, easily-reversible choice. |
| Conditionally hiding `MapAttribution` for Ilmakuva is a real, if small, behavior change to an already-implemented widget; a mistake here (e.g. showing MML attribution for Ilmakuva, or omitting it incorrectly for Maastokartta) would be a correctness/legal defect, not merely cosmetic. | Directly covered by a dedicated automated test ([§12](#12-testing-strategy)) and a dedicated physical-testing checklist item (11/12) — called out explicitly here so it is not treated as a minor detail during implementation review. |
| A future need to reconsider MML Ortokuva's role for Ilmakuva (e.g. layering it above MapTiler Satellite Hybrid within Finland only) is not designed here. | Explicitly left to a future milestone by ADR-0009/MFS-027; this document's per-selection `switch` structure in [§3](#3-per-selection-style-composition) would need a third branch's worth of logic (an "Ilmakuva within MML coverage" case) if that is ever pursued — not a redesign of the mechanism, but a real addition, noted here so it is not assumed to be free. |
| ~~The exact Finland-region polygon vertex data has not been sourced or authored by this document.~~ **Resolved.** | Sourced and verified directly from Natural Earth's official 1:50m Admin 0 Countries dataset (public domain): combined `Finland` (519 vertices) + `Åland` (52 vertices) features, 571 vertices/11 parts total — see [§3A](#3a-maastokarttas-geographic-region-mechanism-revision-2). Confirmed by direct inspection of the actual downloaded dataset, not assumed; cold-launch and several sanity-check coordinates were verified against it by real point-in-polygon testing. |
| **(Revision 2)** The initial 50 km exit margin is a reasoned starting estimate, not empirically tuned against a real device yet. | Must still be validated (and adjusted if needed) against real observed behavior during physical Android testing (checklist items 21–23) — too small risks the original flicker problem returning in a smaller form; too large lets MML linger visibly past the real border for longer than ideal. The *entry* side has no equivalent tuning risk, since it uses the real polygon directly with no margin. |
| The nearest-edge distance approximation (equirectangular, not geodesic) used for the exit-margin check has bounded but non-zero error, and the point-in-polygon test does not account for antimeridian wrapping (irrelevant for Finland's actual longitude range, but worth noting as a simplification). | Accepted — verified mainland segment lengths (avg. ~8.3 km, max ~30 km) make the chosen nearest-edge approach's error small relative to the 50 km margin; a full geodesic buffer was deliberately not implemented, per "prefer simple deterministic over GIS complexity." |
| **(Revision 2)** A center-point-only region check is a known simplification — at very low zoom, a large visible area can span both sides of the region boundary while the check reports one binary state for the whole style. | Accepted for now, consistent with this project's existing `cameraPosition.target`-only precedent (`_onAddHerePressed`). Revisit only if physical testing (checklist item 22) shows this produces a genuinely confusing result, not preemptively engineered around. |
| **(Revision 2)** This project's headless test environment cannot simulate a real `onCameraIdle` firing from an actual moved camera position, so `MapScreen`'s wiring of the region check to the regeneration pipeline is not covered by a true end-to-end automated test. | `MmlCoverageRegion`'s own logic is fully unit-tested in isolation; the `MapScreen` wiring is covered by code review and by the already-existing regeneration-pipeline tests (which do not care why a generation was requested). Physical Android testing (checklist items 21–25) is the actual end-to-end verification for this mechanism — this gap is recorded, not silently assumed covered. |
| ~~(Revision 3) The exact MML activation zoom threshold has not been determined; a single global threshold is a simplification; a residual boundary artifact remains possible; MmlStyleFactory.styleFor's genericness across Ortokuva is unverified; cold-launch zoom vs. threshold is an open consequence.~~ | **All four superseded by Revision 4 — kept as a historical record.** Pixel-level masking removes the zoom-threshold concept entirely; none of these risks apply to the current design. |
| ~~(Revision 4, blocking) The exact coastal/territorial-water buffer distance for the coverage geometry has not been empirically determined.~~ **Resolved.** | Determined directly from six real MML tiles (10 km, uniform — [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)'s Coverage Geometry section). Resolved via remote pixel analysis, not a live device session — see the new risk row immediately below for what remains open as a result. |
| **(Revision 4)** The locked 10 km buffer is measured to sit close to, not comfortably inside, the tightest observed safe margin (~6–10 km, at the Russia border near Virolahti) — unlike every other tested direction, where 10 km is comfortably safe. This was an explicit, evidence-based choice (every larger tested candidate was clearly less safe there), not an oversight. | Physical Android testing (checklist item 39) must specifically verify this exact stretch before treating the value as fully settled. If a residual gray sliver is found there, the fix is a smaller buffer, not a larger one — every larger tested candidate (20/30/50 km) was already shown to be worse at this specific location, not better. |
| **(Revision 4)** The buffer value was determined by decoding real MML tiles fetched and analyzed off-device (six PNG files, six locations, z=8), not by an on-device MapLibre pan/zoom session as originally planned in this section's prior draft. | Judged sufficient to lock the *value*, since the underlying pixel data is real, not simulated or inferred — but real on-device rendering (with the actual masking algorithm, actual anti-aliasing, actual MapTiler compositing beneath it) has not yet been observed at all, for any location. Physical Android testing remains fully required before this revision ships, unchanged from every prior revision's own discipline. |
| **(Revision 4)** The current Natural Earth 1:50m polygon's own precision (not the buffer) may prove visibly insufficient specifically in the archipelago, where very small islands may not be individually resolved by a 1:50m-scale simplification. | Not upgraded pre-emptively (see [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)'s explicit reasoning for staying with Natural Earth for v1). Physical testing checklist items 29/30 specifically target this; if they surface a real, visible problem, upgrading to an MML-sourced polygon becomes a concrete, evidence-driven follow-up, not a hypothetical one. |
| **(Revision 4)** The local tile-masking service is new infrastructure for this codebase — an embedded HTTP server and CPU-bound image processing, neither of which this project has done before. Real-world performance (masking latency, memory behavior, cache growth) is estimated, not benchmarked, by this document. | Physical Android testing checklist items 33/37 exist specifically to validate this before it is trusted; isolate-offloading and the classification-driven "most tiles need no processing at all" design (§3C) are the mitigations, not a substitute for measuring the real result. |
| **(Revision 4)** Android's cleartext-traffic (non-HTTPS) restriction and its treatment of loopback addresses specifically has not been independently verified against this project's own Android configuration. | Flagged explicitly in [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4) rather than silently assumed — confirm during implementation (an explicit Network Security Config loopback exception may be needed even if the platform default is expected to already exempt it). |
| **(Revision 4)** The persistent disk cache is a genuinely new, bounded-but-real amount of on-device storage this project has not previously needed to manage or communicate about. | Designed with an explicit eviction policy and size cap from the outset (§3C), and explicitly documented (here and in ADR-0009's updated Offline and Caching Implications) as an ordinary performance cache, not an offline-map feature — no user-facing "clear cache"/"download for offline" UI is introduced by this milestone, keeping it squarely inside already-accepted MML/MapTiler caching terms. |
| **(Revision 4)** MML's own out-of-coverage rendering behavior was only directly verified at z=6, for four representative locations, via the free WMTS service. Behavior at other zooms, and at the many border/coastline locations not directly sampled, is inferred, not individually confirmed. | The physical checklist (items 26–32) exercises a broader set of locations and zoom levels before this ships; the underlying architectural conclusion (out-of-coverage pixels are opaque, not transparent) does not depend on the exact zoom sampled, since it reflects how MML's tile-generation pipeline treats no-data areas structurally, not a zoom-specific rendering quirk — but this inference, not direct universal verification, is recorded honestly as what it is. |
| ~~**(Revision 5)** The no-data-component threshold (1,000 px, edge-touching required) is validated against only 10 real fixtures... A real MML feature not represented in these 10 samples... could misclassify.~~ **Partially resolved by Revision 6** — a second, independent no-data color has since been discovered (white, at higher zoom) precisely because this exact risk materialized; both colors are now validated against 45 real tiles across three border crossings. The underlying risk category (an as-yet-unseen real feature/location could still misclassify) remains real for both colors and is retained below in Revision 6's own risk entries. | Physical Android testing checklist item 51 (formerly 42) specifically targets this — locating a genuinely gray or white real feature near a tile edge on a live device and confirming it survives, now covering both colors. |
| **(Revision 5)** `MmlStyleFactory.presentationMinZoom`'s shipped value (`7`) is an explicitly documented placeholder, not a physically-confirmed number — unlike every other numeric constant this document locks (the 10 km buffer, the 1,000px threshold), this one has not yet been checked against real device rendering at all. | [§3D](#3d-boundary-no-data-connected-component-refinement--presentation-minzoom-revision-5) specifies the exact physical zoom 6/7/8 comparison procedure required before this is locked; this document explicitly does not treat `7` as settled, and neither should implementation review. Physical Android testing checklist item 43 — **untouched by Revision 6, still pending.** |
| **(Revision 5)** Whether `MapAttribution` should be zoom-gated once `presentationMinZoom` is finalized is an open product decision, deliberately left unresolved by this revision (see [§3D](#3d-boundary-no-data-connected-component-refinement--presentation-minzoom-revision-5)'s Option A/B). | Recorded explicitly so it is a deliberate follow-up decision, not a silently-dropped requirement — must be decided once the final minzoom value is chosen, before this milestone is considered fully complete. **Untouched by Revision 6.** |
| **(Revision 6)** The white no-data threshold (10,000px) is validated against only three real border crossings (Imatra, Nuijamaa, Vaalimaa), and the legitimate-content ceiling it must stay above rose with each additional sample checked (4,457 → 5,339 → 6,795px) — a fourth real sample could plausibly push this ceiling higher still, narrowing or eliminating the current ~2.2× margin. | Physical Android testing checklist item 51 directly targets this. If a real legitimate white feature is ever found to misfire, the fix is raising the threshold further (this evidence trend points in only one direction so far), not lowering it. |
| **(Revision 6)** The whole-tile flat/generic threshold (`minDistinctColorsForContent = 50`) is validated against 45 real tiles total, but the observed gap (34–70 distinct colors, empty) is narrower in absolute sample count than the color-component thresholds' own evidence base, and a genuinely sparse-but-real tile (e.g. a single small, isolated island in an otherwise-flat sea tile) could plausibly fall under 50 and be incorrectly hidden. | The closest real observed case (`aland_east_70km`, 71 distinct colors, a small residual real feature) sits comfortably above 50, giving real margin — but this should be watched during physical testing (checklist items 49/50), particularly for small, isolated skerries near the edge of real MML coverage. |
| **(Revision 6)** A known, accepted residual limitation: the tile containing the actual national border line can retain a small no-data sliver (under either color's threshold) even after this revision, since the true no-data mass may be dominant in an adjacent tile but only just beginning to enter the border tile itself — confirmed concretely at all three real crossings tested (4,457–5,339px local fragments next to 14,979px+ dominant neighbors). | Accepted for this revision, not solved — a neighbor-tile-aware detection scheme was considered but adds real fetch/decode cost and is not designed here (§3E). Much smaller and less visually alarming than the full-tile blocks this revision otherwise fixes; revisit only if physical testing (checklist items 47/48) shows it still matters visually. |
| **(Revision 6)** The new coarse fetch envelope is a plain bounding box, not a real jurisdictional or geographic boundary — chosen for implementation simplicity once correctness stopped depending on its precision (§3E). An authoritative alternative (Traficom's territorial-sea/EEZ WFS data) was identified but not integrated. | Acceptable given the envelope's now-reduced role (performance only, not correctness) — recorded as an available upgrade path if the envelope is ever found to be meaningfully too generous (excess fetch cost) or, despite the large margin, still too tight somewhere. |
| ~~**(Revision 7)** The core premise of the entire vector-path redesign — that MML v21 vector tiles are genuinely empty (not opaque/filled) outside real coverage — is an architectural expectation... not yet confirmed against MML's own real v21 responses.~~ **Resolved — confirmed true.** | Real tiles fetched at six independent outside-coverage locations (France, central Sweden, Moscow, mid-Atlantic, plus the negative-control portions of Tornio/Imatra/Virolahti border tiles) all returned genuinely zero-feature responses — see §3F's Pre-Implementation Verification table. The disproved-contingency path does not apply. |
| ~~**(Revision 7)** MML's real, complete v21 style may contain an undiscovered second unconditional (no-filter) layer beyond the one confirmed `background` layer.~~ **Resolved — confirmed false.** | MML's real, complete 113-layer style was inspected programmatically (not the trimmed fixture): exactly one layer (`background`) has no `source`; every other layer, filtered or not, is scoped to a real `source-layer`. One large-bbox layer was found referencing border-crossing geometry (`korkeusalue`) but it is confirmed unused by any style layer, hence invisible — see §3F. |
| ~~**(Revision 7)** MML v21's real `maxzoom: 14` is lower than raster's confirmed `18`; overzoom visual quality at zoom 15–18 is not yet confirmed acceptable.~~ **Partially resolved, assumption corrected.** MML's server was found to genuinely serve real, distinct, correctly-scoped content through z18 (not merely client-overzoomed z14 content) — production should declare `maxzoom: 18`. | §3F's Zoom range subsection. **Still open:** whether that real z15–z18 content *renders acceptably* (label density, symbol legibility) is a physical Android question this session's desktop verification cannot answer — unchanged mitigation: physical comparison against previously-shipped raster Maastokartta. |
| ~~**(Revision 7)** SYKE's real, post-tiling MBTiles file size is estimated, not measured.~~ **Resolved — measured.** A real national prototype (5 zoom levels, real complete source data) totals 53.16 MB; a realistic z8–z14 production range is estimated ~49.3 MB by direct subtraction, likely a conservative upper bound (§20A) given the prototype's own unoptimized, non-`tippecanoe` tiler. | §20's Storage size subsection, §20A's full build record. Classified "suitable, but noteworthy" — not blocking, but a real app-size cost worth surfacing explicitly, not silently accepted. |
| ~~**(Revision 7)** `EL.ContourLine`'s lack of any lake-identifying attribute means a small risk of preprocessing-time misassociation during the QA join.~~ **Resolved — measured directly on the complete real national dataset, not a sample.** 99.9% of contour features (89,464/89,522) joined correctly; the 0.1% (58 features) that did not are clustered at a single real location, consistent with a localized data/precision edge case, not a systemic join defect. | §20A. Low product impact confirmed empirically, not merely argued: rendering position is unaffected either way (join output is not used for placement); only the optional per-lake tagging is affected, for 0.1% of contours. Not blocking. |
| **(Revision 7, new — found during verification)** `EL.ContourLine` has a small (1.3%, 1,222 of 90,744) real rate of features with no `syvyyskayra_m` depth value at all (missing source data, not a parsing defect — confirmed by direct inspection, not assumed). | These are correctly excluded from the depth-styled output during normalization (§20A) — consistent with this project's "missing data is normal" stance; no fix needed, recorded so a future implementer does not mistake the drop rate for a normalization bug. |
| **(Revision 7, new — found during verification)** The investigation-only MBTiles prototype's own low-zoom (z6/z8) tile sizes (358 KB / 84 KB average) are large relative to higher zooms, a direct consequence of using a custom Douglas-Peucker-only tiler rather than `tippecanoe`'s own additional low-zoom feature-density dropping. | Not a defect in the *design* (§20/§21's chosen delivery architecture and preprocessing approach are unaffected) — a known limitation of *this investigation's own tooling substitution*, explicitly why the measured 53 MB/~49 MB figures are treated as a conservative upper bound, not a precise production prediction (§20A). A real `tippecanoe` build, when implementation begins, should be expected to produce a smaller file. |
| **(Revision 7)** The bathymetry overlay's own presentational zoom threshold (mirroring `presentationMinZoom`) is not yet determined. | Requires physical, on-device confirmation, per §22 — explicitly not invented here, following the same discipline already established for every other such constant in this document. |

---

## 15. Dependencies

- **New (likely):** a URL-launching package for the attribution panel's required links (e.g. `url_launcher`).
- **Unchanged:** `maplibre_gl` (no version bump required); `shared_preferences` (TD-026, unchanged use).
- **(Revision 7) No new dependency expected for SYKE tile reading.** MBTiles is an ordinary SQLite database; this project already depends on SQLite via Drift, and a plain `sqlite3`/`sqflite`-style read of a bundled asset file needs nothing beyond what a minimal SQLite bridge already provides — if Drift's own underlying SQLite binding cannot conveniently open a second, non-Drift-managed database file directly, a small, widely-used `sqlite3` Dart package (not a new ORM, not a new abstraction layer) would be the expected addition, evaluated at implementation time.
- **(Revision 7) No new dependency for MML v21 vector fetching or proxying.** `dart:io HttpServer` (already sufficient for §3C's raster service) and `dart:convert` (already used throughout `core/map`) cover everything `MmlVectorProxyService` needs — it forwards/rewrites JSON and proxies binary tile bytes, neither of which needs a new package.
- **(Revision 7) Not introduced:** any vector-tile-rendering package (MapLibre GL Native already renders vector sources natively — this is the entire reason the vector path is viable at all); any `pmtiles://`-protocol package (PMTiles was evaluated and not selected, §20); any generalized offline-tile-download package.
- **(Revision 4) No new dependency currently expected for the local tile-masking service.** `dart:io`'s `HttpServer` (SDK-provided, no package) is sufficient for the local listener; `package:image` (already a project dependency, used for photo processing) is sufficient for PNG decode/mask/encode; `path_provider` (already a dependency) is sufficient for the disk cache location. If implementation reveals a genuine need beyond these (e.g. a routing convenience package), that would be a real, if likely small, addition — not assumed necessary here.
- **Not introduced:** any HTTP client package (no outbound request library beyond what `dart:io` already provides is needed); any backend/proxy (the local service is on-device only — see ADR-0009 Revision Note 4 for the explicit distinction); any generalized provider/plugin framework; any offline-tile-caching package (the local service's own cache is bounded and ordinary, not a dedicated offline-tiles product).

---

## 16. Security and Repository Hygiene

- Nothing new needs to be added to `.gitignore` — `MAPTILER_API_KEY` exists only as a `--dart-define` value at build time.
- No real MapTiler API key value appears anywhere in this document, any test, fixture, screenshot, or log.
- CI/release builds supply both real keys via whatever secret-injection mechanism the build environment already uses.
- Neither key is treated as cryptographically secret, for the same accepted, ADR-0008/ADR-0009-acknowledged reason as MML's key today.
- **(Revision 4)** The MML key must never appear in the local service's own logging, the generated MapLibre style JSON, the local loopback URL, any cache filename, or any error message — a stricter requirement than before, made necessary by the on-device fetching step existing at all (§3C, §12's structural test). The ten bundled real-tile test fixtures (`test/fixtures/mml_border_test/*.png`, `test/fixtures/mml_buffer_test/*.png`) contain no credential of any kind — they are ordinary PNG image bytes, captured and already analyzed without ever needing to be inspected for or scrubbed of key material.

---

## 17. Documentation Impact

To be updated **after** implementation:

- `README.md` — mention worldwide base-map coverage under "Status"/feature list, once shipped; note Ilmakuva's new MapTiler-Satellite-Hybrid-based rendering explicitly, since it is a user-visible behavior change from MFS-026.
- `docs/project-status.md` — add MFS-027/TD-027 to the Completed lists and correct the Known Limitations entry; explicitly record that Ilmakuva no longer shows MML Ortokuva in this milestone.
- `docs/roadmap.md` — resolve whichever "global base-map fallback" reference this milestone now satisfies.
- A short addition to the local development setup note naming `MAPTILER_API_KEY`.
- `docs/app-structure.md` — no change expected; `core/map` was already established by TD-026.

---

## 18. Implementation Order

1. `core/map/maptiler_config.dart` (no dependency, unblocks everything else).
2. `core/map/maptiler_style_factory.dart` and its tests, exposing separate Outdoor and Satellite Hybrid fragment builders, using the confirmed mechanics from [§0](#0-pre-implementation-verification-completed) — `minzoom: 0`/`maxzoom: 22`/`tileSize: 256` for both, already confirmed via authenticated TileJSON, so no further live zoom check is required before finalizing these values. A one-time manual sanity check (request one real Outdoor tile and one real Satellite Hybrid tile using the confirmed template and visually confirm correct, unmirrored geography) remains good practice as a check on the *code* correctly reproducing this document's already-confirmed values.
3. `core/map/worldwide_style_factory.dart` and its tests — the explicit per-`BaseMap` composition `switch`, including the regression assertion that Ilmakuva's style never contains an MML fragment.
4. `MapScreen` changes: swap `MmlStyleFactory` usage for `WorldwideStyleFactory` in `_stylePathFor`; generalize the missing-configuration check per-selection ([§9](#9-loading-and-failure-behavior)); conditionally construct `MapAttribution` only for Maastokartta.
5. `maptiler_attribution.dart` and its tests; wire it into `MapScreen.build()`'s `Stack` for both selections.
6. Full regression pass: existing `map_screen_test.dart` cases, fishing-spot repository/widget tests, and the physical Android checklist ([§12](#12-testing-strategy)) — with particular attention to checklist items 3 (Ilmakuva image quality in Finland) and 11/12 (attribution correctness per selection).
7. Documentation updates ([§17](#17-documentation-impact)).

**Revision 2 additions (performed after the above, as an architecture correction, not a from-scratch build):**

8. Transcribe the already-sourced Finland+Åland polygon data (Natural Earth 1:50m Admin 0 Countries, public domain — dataset, features, and vertex counts already verified and fixed by [§3A](#3a-maastokarttas-geographic-region-mechanism-revision-2); no further sourcing decision needed) into compile-time Dart constants; `core/map/mml_coverage_region.dart` and its tests, including the asymmetric entry/exit and real-data regression cases.
9. `MapScreen` changes: add `_mmlActiveForViewport` state (initialized synchronously from `_initialCameraPosition.target`), wire `onCameraIdle` to a new `_onCameraIdle` method, extend `MapAttribution`'s visibility condition, and change the Maastokartta style-building call site to use `WorldwideStyleFactory.buildStyle` directly with the richer `mmlAvailable` computation (removing `buildStyle`'s `@visibleForTesting` annotation).
10. Full regression pass again, with particular attention to the new physical Android checklist items 21–25 (the actual defect this revision fixes, hysteresis stability, and dynamic attribution correctness) — this revision's core claim (the visual bug is fixed) can only be confirmed physically, not by any automated test in this project's headless environment.
11. Documentation updates reflecting Revision 2's own completion, once implemented and verified (not performed by this document).

**Revision 3 additions — never executed, superseded before step 12 was ever reached:**

~~12–17. (Run the zoom-threshold physical test; decide cold-launch consequence; add activationMinZoom to MmlStyleFactory; wire _mmlZoomActive; regression pass; documentation.)~~ **Superseded by Revision 4 below.**

**Revision 4 additions (the current, actual next implementation steps — supersedes Revision 3's plan above, does not follow it):**

12. ~~Blocking precondition: run the required physical test for the buffer distance.~~ **Resolved** — [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)'s Coverage Geometry section now records a locked value (10 km, uniform), determined from six real MML tiles. Implementation may proceed from this real value; the Virolahti-area on-device confirmation (checklist item 39) remains required before shipping, not before starting implementation.
13. `lib/core/map/mml_tile_masker.dart` and its tests: the pure boundary-tile masking algorithm (tile-bounds math, polygon rasterization, anti-aliasing, compositing), reusing `MmlCoverageRegion`'s existing polygon data and point-in-polygon logic. This can be built and fully unit-tested (including against the four real bundled MML tile fixtures) before any HTTP/service code exists.
14. `lib/core/map/mml_tile_mask_service.dart` and its tests: the local HTTP listener, tile classification, request coalescing, and two-tier cache, built on top of step 13's pure algorithm.
15. `lib/core/map/mml_coverage_region.dart`: remove `isMmlActiveFor`/hysteresis (no caller remains once steps 16–17 land); retain and, if useful, re-expose the polygon data/point-in-polygon primitives step 13 already depends on.
16. `lib/core/map/mml_style_factory.dart`: point the generated tile URL template at the local service's loopback address (a new parameter, not a compile-time constant); remove any remaining trace of Revision 3's abandoned `activationMinZoom` plan (never implemented, nothing to actually delete).
17. `lib/core/map/worldwide_style_factory.dart`: Maastokartta's `mmlAvailable` computation reverts to `!MmlConfig.isMissing` alone at its `MapScreen` call site.
18. `MapScreen` changes: own the local service's lifecycle (start in `initState`, await before the first style build, stop in `dispose`); **remove** `_mmlActiveForViewport`, `_onCameraIdle`'s region-driven regeneration branch, and (since neither was ever built) nothing further for Revision 3; simplify `MapAttribution`'s condition back to `baseMap == BaseMap.maastokartta && !MmlConfig.isMissing`. Leave the temporary zoom-debug overlay in place unless a separate, explicit instruction to remove it has been given.
19. Full regression pass, with particular attention to the new physical Android checklist items 26–39 — this revision's core claim (a pixel-clean border, at every zoom, with no style regeneration) can only be confirmed physically, exactly like every prior revision's own core claim.
20. Documentation updates reflecting Revision 4's own completion, once implemented and verified (not performed by this document) — including, at that point, actually removing the temporary zoom-debug overlay and its own leftover documentation references.

**Revisions 5/6 additions:** their own respective sections (§3D, §3E) fully specify the refinement steps involved; not repeated here.

**Revision 7 additions (the current, actual next implementation steps once this documentation revision itself is agreed) — supersedes continuing Revision 6's own physical-testing step (never performed) as the next action:**

21. Run §3F's Pre-Implementation Verification table (real v21 tile inspection at borders; full-style layer audit beyond the trimmed fixture; overzoom comparison) — **blocking**, mirroring how §3C's buffer distance and §3E's color thresholds were each locked only after equivalent real-evidence gathering.
22. `lib/core/map/mml_vector_proxy_service.dart` and its tests (§3F/§26) — rewritten from `mml_vector_poc_style_fetcher.dart`, retaining its fetch-MML's-own-style strategy; add the style-rewrite (URL substitution, `background`-layer removal) and the tile/glyph proxy endpoints.
23. `lib/core/map/worldwide_style_factory.dart`: Maastokartta's MML branch switches from merging `MmlStyleFactory`'s raster fragment to embedding a `vector` source pointed at `MmlVectorProxyService`'s local TileJSON endpoint.
24. Preprocessing pipeline (§21, run offline by a developer, not shipped as application code): fetch, normalize, join-for-QA, tile, producing the bundled MBTiles asset; `lib/core/map/syke_bathymetry_tile_source.dart` and its local HTTP endpoint (§20/§22); wire the `syke-bathymetry` source into `WorldwideStyleFactory` for both selections.
25. SYKE styling (§22): depth-area fill and contour-line layers, with a placeholder presentational `minzoom` pending the physical zoom comparison this step's own design leaves open.
26. Extend `MapTilerAttribution`'s panel content with SYKE's required notice (§24).
27. Remove the PoC's debug toggle (`_onToggleVectorPoc`/`_vectorPocActive`/etc.) and its `build()` button; remove the raster masking files per §25's disposition table, once their real replacements are confirmed working — not before, so there is always a working Maastokartta path during the transition.
28. Full regression pass; physical Android testing per §26 (the four-lake matrix, the reused border-crossing checklist, overzoom comparison, offline-cold-launch check).
29. Documentation updates (§25's Documentation Impact subsection).

---

## 19. Validation / Definition of Done

- `flutter analyze` passes.
- All new and existing automated tests pass, including the full pre-existing suite.
- Physical Android testing checklist ([§12](#12-testing-strategy)) completed, including an explicit judgment call recorded on Ilmakuva's Finland image quality (checklist item 3) **and explicit confirmation that the Revision 2 defect (opaque gray/white blocks, visible tile/coverage-boundary artifacts around Sweden/the Baltic region) no longer reproduces (checklist items 21–22)**.
- No real MapTiler or MML API key appears anywhere in the diff.
- Both MapTiler style identifiers (`outdoor-v4`, `hybrid-v4`), the shared raster endpoint pattern, standard `{z}/{x}/{y}` token order, `tileSize: 256`, `minzoom: 0`/`maxzoom: 22`, and `key` parameter name all match what is actually implemented.
- Ilmakuva's generated style is confirmed, by a dedicated test, to never contain an MML source/layer under any configuration.
- Attribution correctness is confirmed by a dedicated test: MML attribution shown for Maastokartta whenever MML is configured (no viewport/zoom condition, per Revision 4), MapTiler attribution shown for both selections whenever configured.
- All zoom-range verification items from [§0](#0-pre-implementation-verification-completed) are already confirmed as of this document (via authenticated TileJSON) — no further live zoom lookup remains before or during implementation.
- ~~MmlCoverageRegion's hysteresis logic is confirmed, by a dedicated test, to hold state through its dead-zone in both directions.~~ **Superseded — the hysteresis API no longer exists as of Revision 4.**
- Architecture review confirms: no new architectural layer beyond `core/map`'s existing plain-concrete-class pattern (the local tile-masking service and pure masking algorithm are both ordinary concrete classes, consistent with this); `MapControls`, the MFS-026 selector, and every other feature remain untouched; MML's and MapTiler's credentials, style fragments, and failure handling remain independently reasoned about, per ADR-0009; Ilmakuva's composition genuinely never references MML; Maastokartta's MML inclusion is genuinely never decided by relying on MML's own tile-transparency behavior, nor by any viewport-level check — only by real, verified per-pixel coverage.
- ~~(Revision 3) The MML activation zoom threshold... mml_style_factory_test.dart confirms the layer minzoom... physical Android testing confirms zoom-threshold smoothness/attribution... the cold-launch consequence has an explicit decision.~~ **All superseded by Revision 4 — kept as a historical record.**
- **(Revision 4)** The coastal/territorial-water buffer distance used in the shipped coverage geometry is 10 km — the value actually recorded in [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4), measured from six real MML tiles — not a placeholder, not an invented round number. Physical Android testing must additionally confirm no residual gray sliver at the Virolahti/Russia-border stretch specifically (the one location this value was not comfortably safe at by measurement alone) — not yet performed.
- **(Revision 4)** `mml_tile_masker_test.dart` confirms, via golden/image-level assertions (including against the four real bundled MML tile fixtures), that inside pixels are RGB-unchanged, outside pixels are fully transparent, and edge pixels are anti-aliased (not a hard binary cutoff).
- **(Revision 4)** `mml_tile_mask_service_test.dart` confirms classification correctness (A/B/C), cache-hit behavior (no reprocessing on a repeat request), concurrent-request coalescing, and graceful per-tile fallback on MML fetch failure/malformed data without polluting the persistent cache.
- **(Revision 4)** A structural test confirms the MML API key never appears in the generated Maastokartta style JSON's MML tile URL.
- **(Revision 4)** Physical Android testing explicitly confirms: no visible gray/white block or tile-boundary artifact at any zoom, at any of the checklist's specific locations (interior, both borders, Åland, archipelago); simultaneous MML/MapTiler visibility in one viewport at the border; no style regeneration or fishing-spot-marker re-flash while freely panning/zooming across the border; acceptable performance during sustained pan/zoom (checklist items 26–39).
- **(Revision 4)** `MmlCoverageRegion`'s migration is complete and verified: `isMmlActiveFor`/hysteresis removed with no remaining caller; polygon data/point-in-polygon logic confirmed still correctly exercised via `mml_tile_masker_test.dart`, not silently orphaned.
- ~~**(Revision 5)** The boundary no-data connected-component refinement is confirmed... zero false positives and zero false negatives... Physical Android testing must additionally confirm the Virolahti/Russia-border gray band is actually gone on a real device (checklist item 40).~~ **Superseded by Revision 6's own criteria below** — the mechanism this described is no longer the final one (gray-only, geometry-alpha-backed); see the Revision 6 entries.
- **(Revision 5)** `MmlStyleFactory.presentationMinZoom` is present on the generated MML raster **layer** only (not the source), confirmed by a dedicated test. **Its value (`7`) is an explicit, documented placeholder — not yet device-confirmed.** The physical zoom 6/7/8 comparison procedure ([§3D](#3d-boundary-no-data-connected-component-refinement--presentation-minzoom-revision-5)) must be run and this value updated accordingly before this criterion can be considered met — **not yet performed. Untouched by Revision 6.**
- **(Revision 5)** Whether `MapAttribution` should also be gated on the final `presentationMinZoom` is an explicit, recorded open product decision ([§3D](#3d-boundary-no-data-connected-component-refinement--presentation-minzoom-revision-5)), deliberately not resolved by this revision — must be decided (Option A or B) once the final minzoom is chosen, before this milestone is considered fully complete. **Untouched by Revision 6.**
- **(Revision 6)** `geometryAlpha` (`_rasterizeCoverageAlpha` and everything it depended on) is confirmed removed from `mml_tile_masker.dart` entirely — not merely unused — verified by direct code inspection, not just by test passage.
- **(Revision 6)** The whole-tile flat/generic check and the per-color (gray + white) confirmed-no-data-component removal are confirmed, by dedicated tests, against all 45 real tiles gathered for this revision (the original 10 fixtures + Imatra/Nuijamaa/Vaalimaa/Åland-transect) with zero observed false positives and zero observed false negatives (see [§3E](#3e-content-driven-boundary-masking--coarse-fetch-envelope-revision-6)). Physical Android testing must additionally confirm the white region is actually gone at all three border crossings, and that Åland/Föglö show continuous coverage with no circular cutouts — **not yet performed** (checklist items 47–50).
- **(Revision 6)** The coarse fetch envelope is confirmed, by dedicated tests, to reclassify previously-`outside` real locations (deep Sweden, deep Russia, open Baltic near Åland) as `boundary`, while genuinely far-outside locations (Gothenburg, far east Russia, Paris) remain `outside`. **Not a jurisdictional boundary, a deliberately generous performance filter only** — see §3E for why this is safe by construction now that correctness no longer depends on the envelope's precision.
- **(Revision 6)** `cacheVersion` bumped `v2` → `v3`, confirmed by the existing generic stale-cache-pruning test.
- **(Revision 6)** The known cross-tile no-data-fragmentation residual risk is explicitly recorded, not silently accepted — see §3E and the Risks table. Physical Android testing (checklist items 47/48) should note whether it is visually noticeable in practice.
- **(Revision 6)** Ilmakuva and MapTiler are confirmed untouched — no test, source file, or generated style for either was modified by this revision.

---

## 20. SYKE Production Delivery Architecture (Revision 7)

**Decision: a single, preprocessed MBTiles file, built offline by a developer-run pipeline and bundled as an app asset, served locally through the exact same local-loopback-HTTP-service shape already established for MML.** No live SYKE WFS request is ever made by the mobile app.

### Why not live WFS

The task instruction is explicit: do not default to live national WFS requests from the mobile app. This is also the correct technical call independent of that instruction: `investigation/syke_depth/coverage_report.md` records 63,761 `EL.Syvyysalue` features and 90,744 `EL.ContourLine` features nationally, queried over WFS 2.0.0 — a live per-viewport WFS query pattern would mean a new, unbounded, per-pan-and-zoom network dependency (a fourth external service, after MML, MapTiler, and — network-wise — nothing else this project currently depends on live), directly conflicting with this project's offline-first architecture (ADR-0002) for content that, unlike base-map imagery, has no inherent reason to require network access — SYKE's dataset is finite, national, and does not change day-to-day.

### Options compared

| Option | Verdict |
|---|---|
| **Live WFS per viewport** | Rejected — explicitly excluded by instruction; also the only option that makes bathymetry a network-dependent feature, when nothing about the data requires that. |
| **Preprocessing to vector tiles, packaged as a single local file (MBTiles), bundled as an app asset — selected** | Smallest option that is simultaneously fully offline, reuses this project's own already-built local-HTTP-service infrastructure with no new plugin/protocol risk, and matches the scale of data actually involved (estimated tens of MB post-tiling — see [Storage Size](#storage-size) below). |
| **PMTiles (single-file, HTTP-range-addressable format)** | Not selected. Technically attractive (no server process needed at all for a purely local read, since PMTiles is designed for range-request access), but would require either a `pmtiles://` custom-protocol integration in `maplibre_gl`'s Android/iOS native layer (unconfirmed to exist in the installed plugin — an unverified native-capability risk, the same category of risk this document's own §3C already investigated and avoided for raster masking) or a small local server to translate range requests anyway, which converges back to needing the same local-HTTP-service shape MBTiles already uses via a trivial SQLite read — MBTiles achieves the same offline, single-file-asset outcome with a well-understood, zero-native-risk access pattern (a single `SELECT tile_data FROM tiles WHERE zoom_level=? AND tile_column=? AND tile_row=?` query against a bundled SQLite file), so PMTiles' main advantage (no server process) is not actually realized in this codebase's context, while its main risk (unverified plugin support) would be. |
| **MBTiles unpacked to loose files at install/first-run** | Not selected — adds an unpacking step, a variable-sized unpacked footprint (worse than one compressed SQLite file), and file-count overhead with no benefit over querying the SQLite file directly, which `sqlite3`/`sqflite`-style access (this project already depends on SQLite via Drift) makes just as fast. |
| **A hosted vector tile endpoint (a small backend serving pre-tiled SYKE data over HTTPS)** | Not selected — introduces a new, developer-operated backend this project has consistently avoided (ADR-0008/ADR-0009's own "no proxy/backend solely to avoid a smaller problem" discipline), for data that is small enough, and changes infrequently enough, to simply bundle. Revisit only if national coverage ever grows to a size genuinely unfit to bundle (not indicated by current evidence) or if per-device storage becomes a demonstrated real problem. |

### Local serving mechanism

`MmlVectorProxyService` (§3F) is **not** reused directly for SYKE — it is an MML-specific credential proxy, and SYKE's bundled data needs no credential and no upstream network request at all. A separate, small, equally narrowly-scoped local HTTP endpoint is added to the same `MapScreen`-owned local service process (one loopback HTTP listener, multiple route prefixes — not two separate servers, and not a generalized "pluggable local tile server" abstraction; see the explicit instruction against a generalized bathymetry framework):

- `GET /syke/bathymetry/{z}/{x}/{y}.pbf` — reads the requested tile's blob directly from the bundled MBTiles SQLite file (a simple, synchronous-feeling but `Future`-wrapped read; no isolate dispatch needed, since this is a plain indexed database read, not CPU-bound image processing) and returns it, or an empty/`204` response if the tile genuinely has no data at that coordinate (MBTiles' own standard sparse-tile behavior — most of the world outside SYKE's coverage produces no row at all, which is the correct, expected "no data" case per FR-29, requiring no special handling beyond what an empty vector tile response already means to MapLibre).
- `WorldwideStyleFactory` adds a `syke-bathymetry` vector source (`url`: a small, locally-served TileJSON at `/syke/bathymetry/tilejson.json`, or a directly-embedded `tiles` array pointing at the endpoint above — whichever is simpler at implementation time; both are equivalent here since, unlike MML, there is no upstream TileJSON to relay) to the composed style, for **both** `BaseMap.maastokartta` and `BaseMap.ilmakuva` (see [Design Notes — Revision 7](#design-notes) in MFS-027 for why the overlay is base-map-agnostic).

### Storage size

**Measured, not extrapolated (investigation-only prototype build, this session — see [§20A](#20a-syke-mbtiles-prototype-build--real-measurements-revision-7-verification) for the full methodology and caveats).** A real national MBTiles file was built from the complete, freshly-fetched `EL.ContourLine` (90,744 source features) and `EL.Syvyysalue` (63,761 source features) datasets, at five representative zoom levels (6/8/10/12/14), using a custom investigation-only Python tiler (not tippecanoe — unavailable in this environment; see caveats below). **Result: 53.16 MB for those 5 zoom levels.** Restricting to a realistic production zoom range (z8–z14, dropping whole-country z6 — consistent with FR-30's "not useful at whole-country zoom") reduces this to **~49.3 MB** by direct subtraction of the measured z6 contribution (3.94 MB). `investigation/syke_depth/coverage_report.md`'s own prior extrapolation ("several hundred MB raw, an order of magnitude or more smaller tiled") is now superseded by this direct measurement, not merely corroborated — the real figure lands within that extrapolation's plausible range, but is no longer an estimate.

**Important caveat on this figure's direction:** this prototype used a custom, unoptimized simplification/tiling pipeline (Douglas-Peucker via Shapely, one fixed tolerance per zoom, no low-zoom feature-density dropping), not production-grade tooling (e.g. `tippecanoe`, unavailable to install in this sandboxed environment). Real `tippecanoe`-class tooling is expected to produce a **smaller**, not larger, file for the same source data — its low-zoom feature-dropping (discarding insignificant features by density/importance, not merely simplifying their geometry) is specifically effective at exactly the z6/z8 levels where this prototype's own per-tile sizes were largest (avg. 358 KB/tile at z6, 84 KB/tile at z8 — see [§20A](#20a-syke-mbtiles-prototype-build--real-measurements-revision-7-verification)). **53 MB (5 zooms) / ~49 MB (z8–14) should therefore be read as a conservative upper bound for a production build, not an underestimate.**

**Viability classification: suitable, but noteworthy** — not "clearly suitable" (this is a real, non-trivial tens-of-MB addition to the app's installed size, worth surfacing to the product owner explicitly rather than treated as free), and not "too large" (well within the range of ordinary mobile app asset budgets — many production Flutter/Android apps ship well over 50–100 MB of bundled assets; a self-contained, fully-offline, nationally-useful dataset at this size is a reasonable trade for the offline-availability guarantee it buys — see MFS-027 Revision 7/§23). **The user/product trade-off, stated plainly:** every install pays a fixed ~45–55 MB download/storage cost once, in exchange for bathymetry that works with zero network dependency, forever, unlike the base-map imagery it sits on top of. If a future national app-size budget review finds this unacceptable, the documented, smallest-first fallback (§20's original text, unchanged) is reducing v1 scope — depth-area polygons only, or restricting to the two dense coverage clusters `coverage_report.md` already identifies — not switching delivery architecture away from a bundled asset.

---

### 20A. SYKE MBTiles Prototype Build — Real Measurements (Revision 7 Verification)

**Superseded by [§27](#27-final-implementation-state--syke-bathymetry--depth-labels-revision-8) on one point: the "Geometry simplification" finding below does not describe the shipped pipeline.** Physical Android testing (Revision 8) found even this section's own size-aware adaptive tolerance still visibly too angular for contour lines; the production pipeline applies **no contour simplification at all**. Everything else below (feature counts, spatial-join validation, per-zoom tile counts, target-lake verification) remains an accurate record of this investigation and is not superseded.

**Investigation-only. Not committed, not a production asset — a temporary, disposable prototype built to close TD-027's own open sizing/feasibility question with real numbers instead of an extrapolation.**

**Method:** the complete national `EL.ContourLine` (90,744 features) and `EL.Syvyysalue` (63,761 features) datasets were fetched fresh, in full, via paginated WFS 2.0.0 requests (mirroring the technique already established in `investigation/syke_depth/`). Attributes were normalized (Finnish decimal-comma → float; `syvyysvali_m` range strings split into numeric min/max; the literal `"Saari"` value mapped to a distinct island/land-inclusion class). A spatial join (Shapely `STRtree`, point/line-in-polygon) tagged each contour line with its containing `Syvyysalue` polygon's `jarvitunnus`, for QA and attribute-enrichment purposes exactly as §21 designs. Tiles were built at z6/z8/z10/z12/z14 using a custom Python tiler (bbox-bucketing, per-tile Shapely clip, `mapbox_vector_tile` MVT encoding, standard MBTiles SQLite output) — **not** `tippecanoe` (unavailable to install in this sandboxed Windows environment; see the size caveat in [Storage size](#storage-size) above for what this means for the resulting numbers' direction).

**Source feature counts (real, not estimated):**

| Dataset | Total fetched | Usable after normalization | Notes |
|---|---|---|---|
| `EL.ContourLine` | 90,744 (matches `coverage_report.md` exactly) | 89,522 (98.7%) | 1,222 features (1.3%) had no `syvyyskayra_m` value at all (missing source data, not a decimal-comma parsing failure — every comma-formatted value parsed correctly) and were correctly excluded, consistent with this project's own "missing data is normal" stance. |
| `EL.Syvyysalue` | 63,761 (matches `coverage_report.md` exactly) | 63,754 (99.99%) | 46,682 real depth-range polygons, 17,072 `"Saari"`/island-class polygons (correctly distinguished, not treated as depth data), 7 with an unparsable value (negligible). |

**Spatial join validation (real data, not synthetic):** 89,464 of 89,522 normalized contour features (**99.9%**) matched a containing `Syvyysalue` polygon and were correctly tagged with its `jarvitunnus`; 58 (0.1%) did not, all clustered at one location (lon ≈23.07–23.08°E, lat ≈61.40–61.41°N) — consistent with a real, localized edge case (a small geometry mismatch at one lake's boundary) rather than a systemic join failure. §21's join design is validated by this result, not merely plausible.

**Per-zoom tiling results:**

| Zoom | Tiles written | Total bytes | Avg tile size | Build time |
|---|---|---|---|---|
| z6 | 11 | 3.94 MB | 358 KB | 87.8 s |
| z8 | 59 | 4.96 MB | 84.0 KB | 84.4 s |
| z10 | 428 | 6.10 MB | 14.3 KB | 83.9 s |
| z12 | 2,373 | 9.94 MB | 4.2 KB | 99.8 s |
| z14 | 12,639 | 23.10 MB | 1.8 KB | 164.2 s |
| **Total** | **15,510** | **53.16 MB** | — | **520.1 s (8.7 min)** |

**Target-lake verification (real polygon centroids, not approximate coordinates — corrected mid-investigation after an initial pass using rough guessed coordinates produced misleading "no data" results for Päijänne/Saimaa purely from imprecise point selection, not real absence):**

| Lake | Real `jarvitunnus` family matched | Result in built tiles |
|---|---|---|
| Kymijärvi | `14.164.1.*` — 42 real `Syvyysalue` features | **Present** at z10/z12/z14 (18/12/8 depth-area features, 25/22/18 contour features respectively, at the tile containing its real centroid) |
| Vesijärvi | `14.241.1.*` — **0 matches** (confirmed, consistent with `coverage_report.md`) | **No tile row at all** at z10/z12/z14, using Vesijärvi's real lake-center coordinate — genuinely absent, not malformed or empty-but-present. This is the correct, required no-data behavior (FR-29), directly confirmed against the actual built artifact, not inferred. |
| Päijänne (south basin) | `14.221.1.*` — 95 real features (exactly matching `coverage_report.md`'s own figure) | **Present** at z10/z12/z14 (92/19/18 depth-area features respectively) |
| Saimaa | `04.1*`/`04.2*`/`04.3*` — 9,625 real features (exactly matching `coverage_report.md`'s own figure) | **Present** at z10/z12/z14 (33/18/8 depth-area features respectively) |

**Attribute correctness in the final tile output (decoded directly from the built MBTiles, not from intermediate data):** a sampled Kymijärvi z12 tile's `depth_areas` layer carries correctly normalized numeric `depth_min`/`depth_max` (e.g. `0.0–1.5`, `1.5–3.0`, `3.0–6.0`, matching the depth-class scheme found in the original single-lake investigation), `luokka`, and `jarvitunnus`; its `contours` layer carries correctly normalized numeric `depth_m` values and, critically, a correctly join-tagged `jarvitunnus` — direct proof the decimal-comma normalization and the spatial join both survive all the way into the actually-queryable tile output, not just intermediate processing.

**Geometry simplification — visible-detail check:** vertex-count reduction was substantial at every tested zoom (Kymijärvi-family contours: 97.4% fewer vertices at z10, 95.3% at z12, 89.7% at z14, against a simple 1-tile-pixel-equivalent Douglas-Peucker tolerance). A rendered before/after visual comparison (raw vs. z12 vs. z10 tolerance, Kymijärvi's own contour lines and depth-area polygons, plotted directly from the same geometries used to build the tiles) shows the lake's overall shape, its internal islands, and its nested depth-band structure all remain clearly legible even at z10's coarser tolerance — some minor smoothing of small coastline inlets is visible, but no depth band or island is lost or merged incorrectly. **This is a desktop plot, not a MapLibre/Android render** — it corroborates that the simplification tolerance is not obviously destructive, but final visual acceptability (styling, line width, color contrast at real device pixel density) remains a physical Android question, not resolved by this check alone.

**What this confirms about §21's design:** decimal-comma normalization, the spatial join, and the "areas ship pre-classed, no join needed for correct rendering position" reasoning are all validated against the complete real national dataset, not merely the small Kymijärvi sample the original investigation used. Nothing here found a defect in §21's proposed approach; no change to §21 is made as a result, per this session's own "don't rewrite what survives verification" instruction.

---

## 21. SYKE Data Preparation (Revision 7)

### Source layers and their actual shape

Confirmed directly from real sample data (`investigation/syke_depth/*.geojson`), not merely from the WFS schema definitions alone:

| Source | Fields confirmed present | Lake identity? | Depth information |
|---|---|---|---|
| `EL.ContourLine` (90,744 features nationally) | `objectid`, `syvyyskayra_m` (a **Finnish-locale decimal-comma string**, e.g. `"1,5"`, `"0"` — confirmed directly, not assumed) | **No `jarvitunnus` or any other lake-identifying field.** | The contour's own depth value, as a line. |
| `EL.Syvyysalue` (63,761 features nationally) | `objectid`, `syvyysvali_m` (a depth-range string, e.g. `"3-6"`, `"1,5-3"`, or the literal `"Saari"`/island for zero-depth land inclusions), `luokka`/`luokka2` (numeric depth-class codes), `syvmittausaluetunnus`, `syvmittausaluenimi`, **`jarvitunnus`** | **Yes.** | A pre-computed depth-range polygon, already classed — no interpolation needed to render as a filled depth band. |
| `EL.SpotElevation` (1,922 features nationally) | `objectid`, `syvyys_m` (a single point depth), `syvmittausaluetunnus`, `syvmittausaluenimi`, **`jarvitunnus`**, `lahderantaviiva`, `luotaustaso`, `vesiala_ha`, `syvyyskeski_m` (mean), `syvyyssuurin_m` (max), `rantapituus_km` | **Yes.** | One summary point per named sub-basin (mean/max depth) — deferred from v1, see [Which sources ship in v1](#which-sources-ship-in-v1) below. |

### The join problem, and what it is actually for

`EL.ContourLine` carries no lake-identifying attribute of any kind — its own geometry is correctly positioned in space, but nothing in its properties says which lake (or which of a large lake system's many named sub-basins) it belongs to. **This does not block rendering**: MapLibre draws a contour line correctly, at its correct real-world position, from its geometry alone — no per-feature lake-identity attribute is required for a line to appear in the right place on the map. The join (a spatial point/line-in-polygon test against `EL.Syvyysalue`'s own lake-tagged polygons, run once during preprocessing, not at runtime) exists for a narrower, genuinely useful purpose: **data-quality validation and provenance**, not rendering necessity — confirming a batch of contour geometry actually falls within a known, named lake boundary (catching corrupt, duplicated, or wildly mispositioned source records before they reach the bundled tileset) and, optionally, tagging each contour feature with its containing lake's `jarvitunnus` in the output tileset (useful for a future per-lake "does this lake have contour data" query, e.g. for a future in-app indicator — not required by this milestone's own scope, but cheap to retain once the join is already computed for QA).

### Decimal-comma normalization

Both `syvyyskayra_m` and `syvyysvali_m` use Finnish-locale decimal commas (`"1,5"`, not `"1.5"`) in the raw WFS output — confirmed directly, not assumed. The preprocessing pipeline normalizes these to standard decimal-point numeric values (and, for `syvyysvali_m`'s range strings, splits into a numeric `min`/`max` pair, with the literal `"Saari"` case mapped to a distinct "island/land inclusion" class rather than a numeric depth) before tiling — this is an offline, one-time preprocessing concern, not application runtime logic; the app never parses Finnish-locale decimal strings at all, since the tileset it reads already contains normalized numeric attributes.

### Which sources ship in v1

**Contour lines (`EL.ContourLine`) and depth-area polygons (`EL.Syvyysalue`) ship in v1. `EL.SpotElevation` depth points/labels are deferred**, per this document's own instruction to decide this explicitly:

- Depth-area polygons are already pre-computed, pre-classed depth bands (`syvyysvali_m`/`luokka`) requiring no further interpolation to render as filled shading — the single highest-value, lowest-effort layer, and the natural default "is there bathymetry here at all" visual.
- Contour lines add readable structure (depth-band boundaries as distinct lines, useful at higher zoom where filled bands alone can look coarse) at comparatively low additional preprocessing cost (geometry + one normalized numeric value per feature; no per-feature lake join is required for correct rendering, only for the QA step above).
- Depth points/labels (`EL.SpotElevation`) are deferred because they add a genuinely different kind of complexity disproportionate to v1's goal of "one useful map solution working now": label placement, collision avoidance with MapLibre's own symbol layer (which fishing-spot markers already use — a second, competing symbol/text layer needs careful zoom-dependent decluttering design not yet attempted anywhere in this codebase), and a much lower feature count (1,922 nationally) that adds comparatively little coverage beyond what the area/contour layers already convey visually. Recorded as a named Future Extension (MFS-027 Revision 7), not silently dropped.

### Refresh process

A documented, repeatable, developer-run offline pipeline (not an in-app feature, not automated CI, not scheduled — mirroring the Lure Catalog's own precedent of a versioned, occasionally-refreshed bundled dataset, MFS-015/TD-015):

1. **Fetch** current `EL.ContourLine`, `EL.Syvyysalue` (and, if/when `EL.SpotElevation` is ever promoted out of deferred status) from SYKE's WFS 2.0.0 endpoint, paginated — the same technique the investigation scripts already used (`investigation/syke_depth/*.ps1`-equivalent tooling), run by a developer, not by the app.
2. **Normalize**: decimal-comma → numeric (above); confirm coordinate reference system is already EPSG:4326 (confirmed already true for the investigated sample data — no reprojection expected, but re-confirmed against whatever is actually fetched, not assumed stale from this document).
3. **Spatial join** contour lines against depth-area/lake polygons for QA and optional `jarvitunnus` tagging (above).
4. **Tile**: standard vector-tile tooling (e.g. `tippecanoe`) with zoom-dependent simplification, output as MBTiles — matching `coverage_report.md`'s own noted expectation of an order-of-magnitude-or-more size reduction versus raw GeoJSON.
5. **Bundle** the resulting MBTiles file as a versioned Flutter asset (`assets/syke_bathymetry/...`, or wherever `pubspec.yaml`'s existing asset convention places it), with an explicit version/date identifier tracked alongside it (e.g. a small companion metadata file or a named constant in the loading code) so a future refresh is visibly a new, versioned artifact, not a silent overwrite.
6. **Bump** a data-version constant read by `MapScreen`/the bathymetry loading code, so a stale on-device cache (if any local caching of served tile bytes is added — likely unnecessary here, since a direct SQLite read of a bundled asset is already fast, unlike a real network fetch) is not an issue; primarily so tests and documentation can assert against a known, current version.

This pipeline is **not** implemented, scripted, or run by this document — it is the design this milestone's future implementation step follows, per the task's own "documentation/design only" scope.

---

## 22. MapLibre Layer Design for SYKE (Revision 7)

**Superseded by [§27](#27-final-implementation-state--syke-bathymetry--depth-labels-revision-8) on the specific points that section locks: which layers actually ship (depth-area fill is bundled but disabled), the final `minzoom` values, and depth-label design/config.** The source-layer names, overall layer-ordering reasoning, and offline/attribution design below remain accurate.

### Source

One `vector` source, `syke-bathymetry`, tiles served locally per [§20](#20-syke-production-delivery-architecture-revision-7), containing two source-layers, named at implementation time and confirmed unchanged since: `depth_areas` (depth-area polygons) and `contours` (contour lines) — see [§27](#27-final-implementation-state--syke-bathymetry--depth-labels-revision-8) for which of these actually renders in the shipped style.

### Layer ordering

Directly fills the "External overlays" band ADR-0008 named and left empty:

```text
Application-owned layers            (fishing spots, catches, current location — unchanged, always last/topmost)
────────────────────────
SYKE bathymetry overlay             (NEW — depth-area fill, then contour lines, then base map)
────────────────────────
Composed base map                   (MML v21 vector + MapTiler Outdoor, or MapTiler Satellite Hybrid — §3F)
```

Within the SYKE overlay itself: depth-area fill layer first (bottom of the overlay band, so it does not visually cover contour lines), contour-line layer above it — mirroring the natural GIS convention (areas beneath lines) and requiring no special z-ordering logic beyond appending in that order to the style document's `layers` array, exactly like every other layer-ordering decision this document already makes by construction (Key Design Decision 4: append order determines paint order, no `belowLayerId` needed for anything added at runtime, since fishing-spot layers — the only runtime-added layers — always land above everything already in the style document).

### Styling

Modest, fishing-focused — explicitly not a reproduction of raw GIS/nautical-chart symbology, per this document's own instruction:

- **Depth-area polygons:** graduated, low-saturation blue fill shading by depth class (`luokka`/normalized `syvyysvali_m`), darker/more saturated for deeper classes — a simple `match`/`step` expression against the class attribute, not a continuous gradient requiring interpolation logic in the style itself (the source data is already discretely classed).
- **Contour lines:** thin, consistent-weight lines in a single muted blue-gray, optionally with a very sparse depth-value label at higher zoom only (a `symbol` layer with `text-field` bound to the normalized depth value) — deferred as an implementation-time refinement, not required for v1's core "where is it deep/shallow" value.
- Exact colors, opacity values, and line widths are implementation-time decisions, consistent with how this document already defers equivalent exact-styling choices elsewhere (e.g. §11's attribution panel styling) — not fixed here.

### Zoom thresholds

Bathymetry is not useful at whole-country/whole-region zoom (FR-30). Mirroring `MmlStyleFactory.presentationMinZoom`'s already-established precedent (§3D) — a static, declarative MapLibre raster/vector **layer** `minzoom` (not a source-level constraint, not application-side Dart logic) — the SYKE overlay's layers each carry a presentational `minzoom`. **No final value is locked here, consistent with this document's own discipline against inventing device-dependent numbers from desktop inspection alone** — but the real §20A prototype build narrows the candidate range from "unconstrained" to the following, evidence-informed band:

- **z6 is clearly too low**: the prototype's own z6 tiles averaged 358 KB each — the *entire* national dataset compressed into just 11 huge tiles, meaning at this zoom individual lakes are not yet visually distinguishable from one another; showing bathymetry here would be visual noise, not information, consistent with FR-30's own "not useful at whole-country zoom."
- **z8 is a plausible lower candidate**: 59 tiles, 84 KB average — dense, but each tile now covers an area small enough that individual lake systems (not yet individual lakes within a dense cluster like Saimaa) begin to separate visually.
- **z10 is a plausible, more conservative candidate**: 428 tiles, 14.3 KB average — individual lakes are clearly separable at this granularity (confirmed directly: Kymijärvi's and Vesijärvi's own real-world-centroid tiles are already *different* tiles at z10), and per-tile feature density (∼18 depth-area + ∼25 contour features for a medium lake like Kymijärvi) is low enough to plausibly avoid visual clutter.
- **z12+ is certainly acceptable** (already the zoom range where fishing-spot-level detail is typically viewed) but likely unnecessarily conservative as a *minimum* — it would hide bathymetry at zooms where it may already be useful.

**Recommended candidate range for the physical test: z8–z10.** This is narrower than "unconstrained," derived from real per-zoom tile density rather than invented, but is explicitly **not** a final value — file size and feature count are proxies for "will this look cluttered," not a substitute for seeing it rendered.

**Exact physical Android comparison still required, mirroring §3D's own established protocol for `presentationMinZoom`:** view several real lakes spanning the coverage-density spectrum (a sparse single lake like Kymijärvi; a dense cluster like Saimaa, where thousands of adjacent small polygons are the realistic worst case for visual clutter) at zoom 7, 8, 9, 10, and 11 on a real device, with the actual chosen depth-area fill/contour-line styling (not placeholder colors), and determine the lowest zoom at which the overlay reads as useful information rather than a cluttered or premature smear — exactly the judgment call §3D already establishes cannot be made from tile statistics alone. Recorded as a Revision 7 pre-implementation verification item, alongside §3F's own list.

### Fishing-spot/catch layers stay on top

Unchanged mechanism, extended to one more layer band: fishing-spot markers/labels are added at runtime, after the full style (base map + SYKE overlay) has already loaded, with no `belowLayerId` — exactly the same construction that already guarantees they land above every base-map/underlay layer today (Key Design Decision 4) guarantees they land above the new SYKE overlay layers too, with no new code path required specifically for this.

### Base-map style reload

Because switching Maastokartta ↔ Ilmakuva (or any other future full-style regeneration) destroys and rebuilds the *entire* MapLibre style — every source and every layer, base map and overlay alike — the SYKE bathymetry source/layers must be restored after every reload, exactly as fishing-spot markers already must be (MFS-026/TD-026's existing restoration guarantee, extended by FR-32). **Two composition strategies are available, and this document does not lock one over the other**, leaving the choice to implementation:

1. **Include the SYKE source/layers directly in `WorldwideStyleFactory`'s generated style document itself** (alongside the base-map fragment(s), beneath where fishing-spot layers are later appended) — the simplest option, requiring no new restoration-tracking code at all, since the existing "whole style regenerated and reloaded" mechanism already carries it through every switch by construction, exactly like MapTiler Outdoor's own unconditional presence already does.
2. **Add it at runtime after `onStyleLoadedCallback`, alongside fishing-spot markers**, reusing `StyleRestorationTracker`'s existing idempotent, generation-aware retry pattern (TD-026) if a reason emerges to keep it a step slower/independent of the base style (e.g. wanting the base map to render before a potentially larger bathymetry payload finishes loading).

**Recommendation, not a binding decision:** option 1 is simpler and consistent with how MapTiler Outdoor is already handled (an unconditional style-document member, not a runtime add-on) — it should be the default unless implementation finds a concrete reason (e.g. perceived load-time impact) to prefer option 2.

---

## 23. Offline Expectations (Revision 7)

Respecting ADR-0002's offline-first architecture directly, and improving on the base map's own accepted exception to it:

- **SYKE bathymetry is available fully offline, always, from the moment the app is installed** — it is a bundled asset (§20), not a network fetch of any kind. This is a **stronger** offline guarantee than the base-map imagery itself (MML vector, MapTiler Outdoor/Satellite Hybrid) currently has or will have after this milestone — those genuinely require network access (MFS-026's own already-documented Known Limitation), while bathymetry, once bundled, does not.
- **National coverage is bundled in full** (whatever real coverage the §21 pipeline's chosen source snapshot actually contains — which is itself incomplete by SYKE's own data reality, not an application-side limitation) — not cached opportunistically, and not downloaded on demand. There is no partial/regional download concept, no per-region "download this area" UI, and no user-facing storage-management affordance for bathymetry in this milestone, consistent with the explicit instruction not to accidentally design a full offline-map-download feature.
- **Storage-size implication:** a one-time increase to the app's installed/bundle size (§20's open verification item — the real number is not yet known), paid once at install/update time, not per-session or per-area like a cache would be.
- **First launch without network:** bathymetry renders normally and immediately (no network dependency at all); base-map imagery (MML vector, MapTiler) follows its own existing, unchanged "map imagery unavailable" treatment (MFS-026 FR-16/FR-17) if genuinely offline — the two are independent, and a first-launch-offline angler sees a working bathymetry overlay over a non-working base map, not a fully blank screen, and not a bathymetry gap layered onto a working base map either, depending on which resource is actually reachable.
- **What remains available offline, restated for clarity:** every other application feature already documented as offline-first (fishing spots, catches, statistics, lure catalog, tackle box) is entirely unaffected by this milestone — SYKE bathymetry adds to what already works offline; it does not change what does.

---

## 24. Licensing and Attribution for SYKE (Revision 7)

**SYKE's "Järvien ja jokien syvyysaineisto" (the INSPIRE `EL.*` datasets used here) is licensed CC BY 4.0** — per this project's own prior, separately-conducted SYKE licensing investigation (referenced by this milestone's own instruction as already verified; not re-derived or assumed here, and not contradicted by anything found in `investigation/syke_depth/`, whose own WFS capabilities response records the dataset as free of charge with an explicit license reference — `<ows:Fees>Maksuton</ows:Fees><ows:AccessConstraints>Lisenssi</ows:AccessConstraints>`, confirmed directly in `inspire_el_wfs_capabilities.xml` — consistent with, not merely assumed alongside, CC BY 4.0). CC BY 4.0 requires attribution naming the source and license whenever the data (or a work derived from it, including a rendered/re-tiled map layer) is displayed.

### Design

**Extend, do not triplicate, the compact attribution mechanism already designed for MapTiler (§11)** — a third permanently-visible full-text attribution block would be real, avoidable clutter on a small mobile screen, exactly the outcome §11's original design already rejected for MapTiler. Add SYKE's required notice (source name + CC BY 4.0 + link, exact wording an implementation-time decision consistent with CC BY 4.0's own attribution requirements) as an additional line inside the same tap-to-expand attribution panel `MapTilerAttribution` already introduces, rather than a new, separate always-visible widget.

### Condition

**Shown whenever the SYKE bathymetry overlay is present in the build** — this milestone ships it unconditionally bundled (§20/§23), with no per-viewport "is there actually bathymetry data visible right now" detection, mirroring MapTiler's own already-established precedent (§11: "continuously available whenever MapTiler is part of the active composition... not conditionally shown based on detected viewport/coverage") rather than reintroducing the kind of viewport-aware attribution logic Revision 4 deliberately removed as unnecessary complexity for MML's own attribution. Shown for **both** Maastokartta and Ilmakuva, matching the overlay's own base-map-agnostic presence (§20, MFS-027 Design Notes).

### What this document does not decide

Exact attribution text/wording, panel layout with three providers instead of two, and whether SYKE's logo (if it has one it requires displaying — not confirmed either way by this investigation) is needed alongside its text, remain implementation-time decisions, consistent with how §11 already defers equivalent detail for MapTiler.

---

## 25. Migration / Cleanup (Revision 7)

Full disposition of every file this section's design touches, extending §13's existing Files Affected table rather than replacing it (§13 remains an accurate record of Revisions 1–6's own file history).

### Temporary MML Vector PoC — becomes production, rewritten

| File | Disposition |
|---|---|
| `lib/core/map/mml_vector_poc_style_fetcher.dart` (`MmlVectorPocStyleFetcher`) | **Rewritten into `MmlVectorProxyService` (§3F)**, not deleted outright — the PoC's core insight (fetch MML's real style rather than hand-authoring one) is retained; what changes is that the fetched result is never handed directly to `_writeStyleFile` with its embedded key intact. The PoC's own doc comment ("safe to delete... once the comparison is done") anticipated exactly this kind of promotion-or-deletion decision; promotion is the outcome, given the physical comparison found vector acceptable. |
| `MapScreen._onToggleVectorPoc`, `_vectorPocActive`, `_vectorPocStyleFetcher`, `_vectorPocFallbackFont`, and its debug `FloatingActionButton` in `build()` | **Removed entirely.** These exist only to let a developer manually toggle between the shipped raster style and MML's vector style for comparison purposes — once vector *is* the shipped Maastokartta path (not a toggle-able alternative to it), the toggle itself has no remaining purpose. |
| `test/core/map/mml_vector_poc_style_fetcher_test.dart` | Rewritten/renamed alongside the production class it now tests (`MmlVectorProxyService`), extended to cover the new endpoints' key-stripping behavior (§26). |
| `test/core/map/mml_v21_backgroundmap_fixture_test.dart`, `test/fixtures/mml_v21_backgroundmap_style_fixture.json` | **Retained, relocated if a new test-file naming convention is adopted for the production module** — these assert real, valuable, ongoing facts about MML's actual v21 product (its layer structure, its lack of any bathymetric source-layer — directly justifying SYKE's own necessity, §3F) that remain worth regression-testing regardless of which class fetches the style. |

### Raster masking architecture — retired from the live implementation path

| File | Disposition | Why |
|---|---|---|
| `lib/core/map/mml_tile_masker.dart` (`MmlTileMasker`) | **Removed.** | Its entire purpose (per-pixel no-data detection/removal on raster tiles) has no analogue once nothing renders raster MML tiles — see §3F's Disposition subsection for the full "retired, not fallback" reasoning. |
| `lib/core/map/mml_style_factory.dart` (`MmlStyleFactory`) | **Removed.** | Raster style-JSON generation for MML has no remaining caller once Maastokartta uses vector; Ilmakuva never used it. |
| `lib/core/map/mml_tile_mask_service.dart` (`MmlTileMaskService`) | **Evolved into `MmlVectorProxyService`, not deleted wholesale** — its HTTP-listener lifecycle, ephemeral-port binding, request-coalescing map, and LRU+disk-cache shape are directly reusable infrastructure (§3F's Tile Handling subsection); its masking-specific request-handling logic (isolate dispatch to `MmlTileMasker`, the `mml_tile_cache/v1/...` masking-algorithm-versioned cache path) is removed along with `MmlTileMasker` itself. | Reuse where the underlying need (a local, loopback-only, cached HTTP proxy) is identical; remove where the need (pixel processing) no longer exists. |
| `lib/core/map/mml_coverage_region.dart` (`MmlCoverageRegion`) | **Conditionally retained**, pending §3F's own Pre-Implementation Verification: if vector tiles are confirmed to need no coverage-aware handling at all (the expected outcome), this file's polygon data/point-in-polygon primitives have no remaining caller and should be removed; if the contingency in §3F is triggered (a coarse "skip fetching this tile" optimization is wanted, or an unexpected no-data encoding needs geographic cross-referencing), the geometry is retained and reused, exactly as it already was reused once before (§3C repurposing §3A's own data). **Not decided by this document** — an explicit, evidence-gated follow-up, not a default-to-keep-just-in-case decision (consistent with §3F's own reasoning against keeping unused complexity live). |
| `android/app/src/main/res/xml/network_security_config.xml`, its `AndroidManifest.xml` reference | **Retained, unchanged.** The loopback (`127.0.0.1`) cleartext exception it grants is not raster-specific — `MmlVectorProxyService` and the new SYKE local endpoint (§20/§22) both need the identical exception, for the identical reason (an on-device HTTP listener MapLibre connects to over plain HTTP on loopback). No new manifest change is anticipated. |
| All raster-masking-specific tests (`mml_tile_masker_test.dart`, the masking-specific portions of `mml_tile_mask_service_test.dart`, `mml_style_factory_test.dart`, the real bundled tile fixtures under `test/fixtures/mml_border_test/` and `test/fixtures/mml_buffer_test/`) | **Removed alongside the code they test.** Not left passing-but-irrelevant; per this project's own testing discipline (tests exist to protect real, live behavior), a test suite asserting on retired algorithms would be actively misleading, not merely unused. | |

### New files (Revision 7)

```text
lib/core/map/mml_vector_proxy_service.dart      (§3F — rewritten from mml_vector_poc_style_fetcher.dart; local MML vector/tilejson/tile/glyph proxy with key-stripping)
lib/core/map/syke_bathymetry_tile_source.dart   (§20/§22 — reads tile blobs from the bundled MBTiles asset; deliberately narrow, SYKE-specific, not a generalized local-tile-source abstraction)
assets/syke_bathymetry/<versioned-mbtiles-file>  (§20/§21 — the bundled, preprocessed national dataset)

test/core/map/mml_vector_proxy_service_test.dart
test/core/map/syke_bathymetry_tile_source_test.dart
test/core/map/worldwide_style_factory_test.dart   (extended — SYKE source present for both selections; MML vector fragment shape for Maastokartta)
```

Exact class/file names above are proposals, not binding — implementation may adjust naming, consistent with how every prior revision's own file plan (§13) has been treated as a plan, not a contract.

### Documentation impact (extends §17)

- `README.md`, `docs/project-status.md` — once implemented: describe Maastokartta's Finnish layer as MML v21 vector (not raster WMTS), and record the new SYKE bathymetry overlay as a shipped capability, including its offline-availability property as a notable contrast to base-map imagery's own network dependency.
- `docs/roadmap.md` — resolve whichever "depth contours" future-overlay reference this milestone now satisfies (the same reference ADR-0008 originally named).
- A short addition to local development setup: no new `--dart-define` credential is needed for SYKE (bundled, not credentialed); MML's existing `MML_API_KEY` requirement is unchanged in shape, only in which class consumes it.

---

## 26. Testing Strategy Additions — Revision 7

Extends §12, following the same principles (pure-logic tests wherever possible; physical Android testing for anything requiring real device rendering or real network content; no test asserts on live MML/MapTiler/SYKE network availability).

### New/extended pure-logic tests

- `mml_vector_proxy_service_test.dart` — using a fake/injectable upstream fetcher (mirroring `MmlVectorPocStyleFetcher`'s existing injectable-`httpGetString` pattern): the served `/mml/v21/style.json` response never contains the string `api-key=` followed by a real-looking value; the `background` layer is absent from the served style while every other layer from a realistic fixture input is passed through unmodified; `sources`/`glyphs` URLs in the served output point at the local loopback address, not MML's real host; the tile/glyph proxy endpoints correctly attach the real key to the *upstream* request while never including it in any response, log line, or thrown error; token-order reversal (`{z}/{x}/{y}` in, MML's `{z}/{y}/{x}` out) is correct, mirroring the existing `MmlTileMaskService` regression test for the identical concern.
- `syke_bathymetry_tile_source_test.dart` — a small, synthetic in-memory or temp-file MBTiles fixture (not the full national dataset): a tile with a stored blob is returned correctly; a genuinely absent tile (no row) returns the documented "no data" response with no error; malformed/corrupt input is handled without a crash.
- `worldwide_style_factory_test.dart` (extended) — Maastokartta's generated style contains a `vector` source for MML (not a `raster` source, a direct regression test for the raster→vector change) pointing at the local proxy's tilejson endpoint, plus MapTiler Outdoor's existing raster fragment; both selections' generated styles contain the `syke-bathymetry` vector source, confirming the overlay's base-map-agnostic presence; Ilmakuva's style still never contains any MML fragment of any kind (existing regression assertion, now also covering vector).
- `mml_v21_backgroundmap_fixture_test.dart` (retained/extended) — existing assertions (real layer/source-layer structure, no bathymetric source-layer, no hardcoded key) continue to apply; a new assertion confirms the `background` layer is present in MML's *real, unmodified* response (so the proxy's own layer-stripping test above has something real to strip, not a fixture already missing it).

### `MapScreen` integration tests (extended)

- With Maastokartta selected, the constructed style's MML fragment is vector-sourced, and the composed style's `layers` array contains no unconditional `background`-type layer before the SYKE overlay's own layers.
- The SYKE overlay's source/layers are present in the constructed style for both Maastokartta and Ilmakuva.
- Switching Maastokartta ↔ Ilmakuva preserves the SYKE overlay exactly as it must preserve fishing-spot markers (extending the existing switching/restoration regression tests, not a new mechanism).
- Missing `MML_API_KEY`: Maastokartta's style omits the MML vector fragment entirely (MapTiler Outdoor and the SYKE overlay remain present) — the existing missing-configuration test shape, re-pointed at the new vector fragment.
- Attribution: the tap-to-expand panel's content includes a SYKE line whenever the SYKE overlay is present (this milestone: always) — extending the existing MapTiler attribution-panel test, not a new attribution mechanism.

### Explicitly not attempted

- No automated test asserts on real MML v21 vector tile content, real SYKE MBTiles content beyond a small synthetic fixture, or real network reachability of any provider — unchanged discipline from §12.
- **The core architectural claim of §3F** (MML vector tiles are genuinely empty, not opaque, outside coverage) **cannot be verified by any test in this project's headless environment**, for the same structural reason §3C/§3D/§3E's own core visual claims never could be (`MapLibreMap`'s platform view does not meaningfully render real tile content in this project's test harness) — this is exclusively the job of the Pre-Implementation Verification checks (§3F) and physical Android testing (MFS-027 Revision 7's own four-lake matrix, plus the reused border-crossing checklist).
- Bathymetry rendering legibility/zoom-threshold correctness (§22) is, likewise, a physical/visual judgment, not a headless-test-observable property — confirmed only by the physical zoom comparison procedure this section's own §22 leaves for implementation-time determination, mirroring `presentationMinZoom`'s identical precedent (§3D).

### Physical Android Testing — Revision 7 additions

Extends §12's existing checklist (Imatra/Nuijamaa/Vaalimaa/Åland border-crossing items, reused verbatim against the vector path per §3F) with:

- Kymijärvi, Vesijärvi, Päijänne, Saimaa — the four-lake bathymetry matrix specified by MFS-027 Revision 7.
- MML v21 vector visual comparison against the previously-shipped raster Maastokartta, at zoom 15–18 specifically (overzoom quality, §3F).
- SYKE overlay rendering correctly beneath fishing-spot markers and above the base map, on both Maastokartta and Ilmakuva.
- SYKE attribution reachable via the existing tap-to-expand panel.
- A cold launch with no network at all: SYKE bathymetry renders normally (bundled) while base-map imagery follows its existing offline treatment (§23) — confirming the two are genuinely independent, not merely independent on paper.

---

## 27. Final Implementation State — SYKE Bathymetry & Depth Labels (Revision 8)

**This section is the authoritative record of what actually shipped**, once implementation and physical Android testing settled every placeholder §20A/§22 had left open. It does not re-derive reasoning already covered there (why MBTiles, why a local loopback service, why no live WFS) — only the final, accepted configuration.

### Delivery

Unchanged from §20's design: a single preprocessed national MBTiles file (`assets/syke_bathymetry/syke_bathymetry_v1.mbtiles`), built offline by `tools/syke_bathymetry/build_mbtiles.py`, bundled as an app asset, served locally by `SykeBathymetryTileSource` + `MmlVectorProxyService`'s `/syke/bathymetry/{z}/{x}/{y}.pbf` route — no live SYKE WFS request from the running app, ever.

**Extracted-copy invalidation is version-sidecar-based, and is production functionality, not investigation instrumentation.** `SykeBathymetryTileSource.ensureExtracted()` compares a small `.version` sidecar (the bundled MBTiles file's own SHA-256, written at build time by `build_mbtiles.py`) against the sidecar recorded alongside a previously-extracted on-device copy, and only re-copies the ~tens-of-MB asset when they differ (or the sidecar is missing/unreadable in a way that cannot be trusted) — never on every launch, and never comparing the full file's bytes on-device. This exists because `getApplicationSupportDirectory()` survives an ordinary reinstall-over-existing-app workflow on Android: without this check, a device that had ever extracted an older bundled MBTiles would silently keep serving it forever, even after the bundled asset was updated. Confirmed by a dedicated regression test group (`syke_bathymetry_tile_source_test.dart`, "content-aware extraction invalidation").

### Contour geometry fidelity — no simplification

**Product decision (2026-07-28, confirmed after physical Android testing): contour lines are not simplified at all.** §20A's own adaptive, size-aware simplification tolerance was tried and found still visibly too angular on a real device — accuracy and visual fidelity take priority over asset size for this layer. The only geometry transformation `build_mbtiles.py` applies to a contour line, at any zoom, is clipping to each output tile's own bounds (required to produce valid, bounded vector tiles) and the MVT format's own mandatory coordinate quantization to its 4096-unit tile-local integer grid — neither is a simplification choice. Depth-area polygons (unused in the shipped presentation — see below) keep their own pre-existing, unrelated simplification, untouched by this decision.

### Zoom range

- **Tiled z10 through z14**, a contiguous range with no gaps (`ZOOMS = [10, 11, 12, 13, 14]` in `build_mbtiles.py`, matching `WorldwideStyleFactory.sykeSourceMinZoom`/`sykeSourceMaxZoom`). Earlier non-contiguous tiling (`[8, 10, 12, 14]`) was a confirmed, root-caused physical-device bug (contours flickering in and out while zooming, since MapLibre requests a vector tile at *every* integer zoom within a source's declared range, not only zooms that happen to have data) — fixed by tiling every intermediate zoom, not by changing the range's endpoints.
- **z15 through z18 are served by MapLibre's own standard vector-source overzoom** (the style spec's documented "data from the tile loaded at maxzoom is used at higher zoom levels" behavior) — not tiled further. SYKE's underlying survey precision has no meaningfully more real detail to reveal past z14, so tiling further would only re-slice the same geometry into more, smaller tiles for no informational gain.
- **Presentation (line layer) `minzoom`: 10** (`WorldwideStyleFactory.sykeBathymetryPresentationMinZoom`) — matches the source's own floor exactly, since no data exists below it anyway. This was revised down from an intermediate `11` once the depth-area fill's own visual-clutter problem (the original reason bathymetry was pushed to a higher zoom) was resolved by disabling that fill layer entirely.

### Depth-area fill — bundled, not rendered

The `depth_areas` source-layer remains fully present in the bundled MBTiles (build pipeline unchanged) and its layer id/source-layer name (`syke-depth-areas-layer`/`depth_areas`) remain defined identifiers in `WorldwideStyleFactory`, but **no fill layer is added to the generated style.** Physical testing found the fill's large, flat-colored polygons visually competing with MML's own lake rendering, especially at lower zoom — a lake that already reads correctly as "a lake" gained a second, competing blue shape on top of it. The accepted presentation shows **depth contour lines only**, in the spirit of bathymetry on a traditional Finnish topographic map, with MML's lake surface fully visible underneath. Re-enabling the fill is a possible future revision, not ruled out architecturally — the data and identifiers are kept specifically to make that cheap later.

### Depth labels

A second `symbol` layer (`syke-contour-labels-layer`), same source and `contours` source-layer as the line layer, added immediately after it in the generated style — reading the existing `depth_m` MVT attribute directly; no MBTiles/pipeline change was needed, since `normalize_contours()` already guarantees every tiled contour carries a usable `depth_m` (features with no parseable depth are dropped before tiling, never tiled with a missing attribute).

| Property | Final value |
|---|---|
| `minzoom` | **12** — one step above the line layer's own `10`; at z10–z11 a whole multi-lake area is typically in view, where every visible contour competing for label text would be clutter before symbol-spacing/collision can help |
| `filter` | `["!=", ["get", "depth_m"], 0]` — the `0 m` shoreline contour is excluded; it was found to be ~35% of all contour features and would otherwise trace "0 m" along every lake's already-visible shoreline |
| `symbol-placement` | `line` |
| `symbol-spacing` | `350` px |
| `text-field` | `["concat", ["to-string", ["get", "depth_m"]], " m"]` → renders as `"1.5 m"`, `"3 m"`, `"6 m"`, `"10 m"`, etc. |
| `text-size` | `11` px |
| `text-rotation-alignment` / `text-pitch-alignment` | `map` / `viewport` |
| `text-keep-upright`, `text-max-angle` (45), `text-padding` (2) | MapLibre's own documented defaults, set explicitly |
| `text-allow-overlap`, `text-ignore-placement` | `false`, `false` — labels participate in MapLibre's ordinary collision system, no override |
| `text-font` | **exactly one font name, never MapLibre's own two-font default** — see Font selection below |
| `paint` | `text-color: #0f5c8c`, `text-halo-color: #ffffff`, `text-halo-width: 1.2` — matches the contour line's own color |

**Layer ordering:** the label layer is always appended immediately after the contour line layer, which itself is appended after every MML/MapTiler layer already in the composed style. Because MapLibre gives placement priority to earlier-listed symbol layers, MML's own place/lake-name labels already win any on-screen collision against depth labels, with no explicit reordering or overlap override needed to keep depth labels from overwhelming existing map labels.

**Font selection — a confirmed, fixed root cause.** The label layer originally omitted `text-font`, which defaults to MapLibre's own `["Open Sans Regular", "Arial Unicode MS Regular"]` — a *combined* fontstack request against whichever `glyphs` host the active style declares. That combined request fails entirely against both glyph hosts this app ever configures (MML's own real v21 glyph host, and the default `fonts.openmaptiles.org` host), which is why labels did not render on the first physical-device test despite the contour line layer rendering correctly — a font-availability failure, not a data, filter, or collision-detection problem (confirmed directly: every visible contour around a real test lake, decoded from the bundled MBTiles, carried a usable `depth_m`). `WorldwideStyleFactory` now resolves the label layer's `text-font` to a single, verified-working font matching whichever `glyphs` root the generated style actually declares — mirroring the identical, already-established pattern `MapScreen` uses for the fishing-spot symbol layer's own `textFont`:

- Maastokartta with the MML vector fragment active → `["Liberation Sans NLSFI"]` (MML's own real glyph host).
- Ilmakuva, or Maastokartta without an MML fragment → `["Open Sans Regular"]` (`WorldwideStyleFactory.defaultGlyphsUrl`, `fonts.openmaptiles.org`).

**Depth labels are distinct from `EL.SpotElevation` sounding-point labels**, which remain deferred/out of scope exactly as §21 originally decided — depth labels here are generated purely from the `contours` source-layer's own `depth_m` attribute, not from the separate, still-unshipped `EL.SpotElevation` dataset.

### Acceptance — physical Android testing complete

Confirmed on a physical Android device and accepted as the shipping presentation:

- Contour geometry fidelity (unsimplified) is good.
- Contour lines render continuously across the tiled z10–z14 range, with no zoom-level gap.
- Close-zoom rendering (overzoom past z14) works.
- Depth labels render correctly, in the font-selection fix's corrected configuration.
- Label size (11px), spacing (350px), and styling (color/halo) are accepted as-is — not treated as needing further physical calibration.

### What remains open

Depth-area fill re-enablement (a possible future revision, not scoped here); `EL.SpotElevation` sounding-point labels (still deferred, §21); further label-density tuning if a future, denser real-world test area (e.g. dense Saimaa) is found to need it — not raised by testing so far.

---

## Non-Goals

Restated explicitly, per the task's scope constraints — none of the following is introduced, designed, or stubbed by this document:

- A third selectable base map, or any provider-selection UI.
- Reintroducing MML Ortokuva into the Ilmakuva composition (a possible future milestone, not this one).
- Any new hillshade feature beyond whatever is inherent to the MapTiler styles used. (**Depth contours are no longer a non-goal** — Revision 7 added the SYKE bathymetry overlay, implemented and physically validated by Revision 8; see [§20](#20-syke-production-delivery-architecture-revision-7)–[§27](#27-final-implementation-state--syke-bathymetry--depth-labels-revision-8). This bullet is retained, corrected, rather than silently dropped, since it accurately described Revisions 1–6's own scope.)
- Offline map downloads or any custom offline-tile-caching system. (**Not contradicted by [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)'s local tile-masking cache:** that cache is an ordinary, bounded, LRU-evictable performance optimization with no user-facing "download for offline use" affordance and no guarantee any tile remains cached — the same category of caching every MapLibre-based client, and this project, already does. See ADR-0009's updated Offline and Caching Implications.)
- A backend/proxy service. (**Not contradicted by [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4)'s local tile-masking service:** that process runs entirely on-device, in the same app process, bound to loopback only — it is not a remote, developer-operated server of any kind. See ADR-0009 Revision Note 4 for the explicit distinction.)
- Country or geofence detection based on device location or location permission. (**Not contradicted by the Finland/Åland coverage geometry** ([§3A](#3a-maastokarttas-geographic-region-mechanism-revision-2), now used by [§3C](#3c-on-device-pixel-level-mml-coverage-masking-revision-4) for pixel masking rather than viewport classification) — it is evaluated purely against map tile coordinates, never the device's real-world location or any location permission.)
- A precise, survey-grade Finland boundary, or a generalized geofencing framework beyond the one narrow, Maastokartta-specific coverage geometry and masking process this document designs.
- Navigation/routing, map search.
- Any redesign of fishing spots or of the existing MFS-026 selector/`MapControls`.
- A custom MapTiler vector style, or any modification to MapTiler's own Outdoor or Satellite Hybrid cartography.
- A generalized map-provider plugin architecture (MapTiler and MML remain independently-reasoned-about, narrowly-scoped concrete factories, not instances of a shared abstraction built for hypothetical future providers).
- **(Revision 7)** A generalized, pluggable bathymetry- or overlay-provider framework — SYKE is integrated specifically, by name, as one narrowly-scoped overlay, not an instance of an abstraction built for hypothetical future data sources (MFS-027 FR-33).
- **(Revision 7)** Live SYKE WFS requests from the mobile app at runtime, at any zoom or viewport — bathymetry is delivered exclusively as a preprocessed, bundled asset (§20).
- **(Revision 7)** Any offline-map-download feature, partial/regional download UI, or storage-management affordance for bathymetry — national coverage is bundled in full, always, with no per-area download concept (§23).
- **(Revision 7)** `EL.SpotElevation` depth points/labels, and any symbol-layer label-collision/decluttering design — deferred (§21), named only as a Future Extension.
- **(Revision 7)** A commercial/hosted gap-fill bathymetry source for lakes SYKE does not cover — explicitly named by the task as a later investigation, not this milestone's.
