# MFS-027 — Worldwide Base-Map Coverage

## Status

**Implemented and physically validated on Android (Revision 8).** Maastokartta's Finnish cartographic path is **MML's official v21 vector tiles**, not MML raster WMTS; **SYKE lake/river bathymetry** ships as a separate overlay (contour lines, unsimplified, plus depth labels) on top of the base map, for both Maastokartta and Ilmakuva. This is a revision of this same milestone (MFS-027), not a new feature; no new MFS number was created. `flutter analyze` is clean, the full automated test suite passes, and physical Android testing — including the Revision 7 four-lake bathymetry matrix below and the SYKE-specific acceptance items (contour geometry fidelity, continuous rendering, close-zoom rendering, correct depth-label rendering) — is complete. See [Revision 7 — Vector Base Map and SYKE Bathymetry](#revision-7--vector-base-map-and-syke-bathymetry-current-direction) for the requirements this satisfies, and TD-027 §27 for the final, as-shipped configuration (zoom thresholds, depth-label design, font-selection fix).

Revisions 1–6 (raster WMTS + MapTiler worldwide fallback, culminating in on-device pixel-level MML coverage masking) are **retained below as historical record** of real, physically-tested design work — most of it (MapTiler Outdoor/Satellite Hybrid worldwide fallback, the per-selection failure-independence model, attribution scoping) remains part of the current design unchanged. What Revision 7 changed is narrower than it may first appear: **Maastokartta's Finnish MML layer changed from raster+pixel-masking to vector**, and **bathymetry was added as a new overlay**. Ilmakuva (MapTiler Satellite Hybrid) is untouched. Revisions 2–6's pixel-masking-specific code is superseded and removed (see TD-027 §25 Migration/Cleanup).

## Related

- Depends on: ADR-0002 — Map Technology (MapLibre GL as the rendering technology; unchanged by this milestone)
- Depends on: ADR-0008 — Base Map Provider and Delivery (MML raster WMTS as the Finnish base-map provider/delivery; the base map / overlay / application-owned-layers conceptual model this specification's layering builds on)
- Depends on: ADR-0009 — Global Base Map Coverage and Fallback (authoritative for **why** MapTiler was selected as the worldwide provider, the direct-to-MapTiler/no-proxy delivery architecture, and the experimentally verified MML transparent-no-data-tile behavior this milestone's automatic fallback relies on; this specification does not repeat that reasoning)
- Depends on: MFS-026 / TD-026 — Selectable MML Base Maps (the existing selector, persistence mechanism, attribution, and the fishing-spot marker/label restoration-across-style-reload behavior this milestone must not regress)
- Depends on: MFS-004 — Fishing Spot Foundation (the fishing-spot markers/labels this milestone requires to remain visible and interactive over both the MML/vector and worldwide layers, and above the new SYKE bathymetry overlay)
- **Revision 7:** Fulfills, narrowly, the "future overlay" slot ADR-0008 named and left empty (depth contours) — see [Revision 7](#revision-7--vector-base-map-and-syke-bathymetry-current-direction) below. This is the first milestone to occupy ADR-0008's "External overlays" band.
- Precedes: any future overlay beyond SYKE bathymetry (hillshade remains named only as a future extension by ADR-0008) — not numbered, not scoped, and not designed here

---

## Revision 7 — Vector Base Map and SYKE Bathymetry (current direction)

**This section is the authoritative statement of what this milestone currently builds.** Everything from "Purpose" through "Out of Scope" below (Revisions 1–6) remains as historical record of real, physically-tested design work, and most of it is unchanged in substance — MapTiler Outdoor/Satellite Hybrid worldwide fallback, the per-selection failure-independence model, the two-choice selector, and persistence are all unchanged. Read this section first; it states precisely what changes and what does not.

### What changes, in one paragraph

Maastokartta's Finnish cartographic layer changes from **MML raster WMTS** (Revisions 1–6, with on-device pixel-level coverage masking) to **MML's official v21 vector tiles**, already physically tested via a temporary proof-of-concept (`MmlVectorPocStyleFetcher`, `lib/core/map/`). MapTiler Outdoor remains the unconditional worldwide underlay beneath it, unchanged. Separately, this milestone adds **SYKE ("Järvien ja jokien syvyysaineisto") lake/river bathymetry as a new overlay** — depth contour lines and depth-area polygons — rendered above the base map and below application-owned layers, per ADR-0008's own long-standing base-map/overlay/application-layer model. Ilmakuva (MapTiler Satellite Hybrid) is **untouched** by either change.

### Why: MML v21 vector, not raster

Revisions 2–6 of this same milestone built substantial, hard-won machinery (`MmlCoverageRegion`, `MmlTileMaskService`, `MmlTileMasker`) to solve one specific defect: MML's **raster** WMTS tiles render out-of-coverage areas as opaque, flat-color pixels (confirmed by direct PNG decoding — ADR-0009 Revision Note 4), not transparency, so a viewport-level or even a per-pixel raster masking process was required to produce a clean Finland border. **MML's v21 vector tiles do not have this defect by construction**: a vector tile encodes discrete features (roads, water bodies, contours, labels), not a pre-rendered image; where MML has no data, a vector tile simply has no features to draw, and MapTiler Outdoor's own raster layer beneath it is visible through the empty space with no masking of any kind required. This is expected to eliminate the entire class of problem Revisions 2–6 exist to solve — see TD-027 §3F for the precise pre-implementation verification this expectation still requires before it is treated as settled (this project's own established discipline: verify MML's real behavior directly, never assume it).

Additionally, MML v21 vector was physically tested (per this milestone's own instruction) and found acceptable as the Finnish topographic rendering path, and — critically for this milestone's second goal — **MML v21 vector does not contain lake/river bathymetry** (confirmed directly: `test/core/map/mml_v21_backgroundmap_fixture_test.dart` asserts no `syvyys`/`bathy`-named source-layer exists in MML's own real v21 style response). This is exactly why a separate bathymetry source (SYKE) is needed at all, rather than expecting MML's own cartography to eventually supply it.

### Why: SYKE bathymetry as a separate overlay, not a new base map

ADR-0008 already established the base-map / overlay / application-owned-layers model and explicitly named "depth contours" as a possible future overlay, without designing it. This milestone is the first to occupy that overlay band. SYKE's own investigated dataset (`investigation/syke_depth/coverage_report.md`) is bathymetry-only — it does not carry roads, buildings, or general topography — so it is naturally an overlay (drawn *in addition to* whichever base map is active), never a base map of its own. It composes with **either** Maastokartta or Ilmakuva, since bathymetric depth is equally relevant whether the angler is looking at topographic or aerial imagery (see [Design Notes — Revision 7](#design-notes) for this as a recorded, reversible decision rather than an unstated assumption).

### Functional Requirements — Revision 7

Numbered continuing from FR-24 (the existing document's own no-renumbering convention), grouped as before.

#### FR-25 — MML v21 Vector Replaces MML Raster WMTS for Maastokartta

Maastokartta's Finnish cartographic content is delivered as MML's official v21 vector tile style (`.../vectortiles/stylejson/v21/backgroundmap.json`), not MML raster WMTS. MapTiler Outdoor remains the unconditional worldwide underlay beneath it, exactly as established by FR-9/FR-24 above — this requirement changes *what* renders Finland's own cartography, not the underlay/worldwide-fallback relationship itself.

#### FR-26 — No Pixel-Level Coverage Masking Required for the Vector Path

Unlike the superseded raster path (FR-24), MML's vector tiles are not expected to require an on-device pixel-masking process to produce a clean Finland border — vector tiles with no data simply contain no features, letting MapTiler Outdoor show through by construction. This expectation must be verified directly against MML's real v21 vector tile responses (TD-027 §3F) before being relied upon; it is not assumed without verification.

#### FR-27 — MML API Credential Never Written to Disk in Plaintext

The temporary PoC (`MmlVectorPocStyleFetcher`) fetches MML's real v21 style JSON, which embeds the working, authenticated `api-key` directly in its vector-source `url` and `glyphs` URL — and the PoC's current debug code then writes that JSON, key included, to a plaintext file in the device's temporary directory. **This must not carry over to production.** Production MML vector delivery must keep the MML API key out of any file written to disk, any generated MapLibre style document, any log line, and any error message — the same standard already required, and already met, for MML's raster key (ADR-0009 Revision Note 4, TD-027 §16). See TD-027 §3F for the mechanism.

#### FR-28 — SYKE Bathymetry Overlay, Where Data Exists

Wherever SYKE's bathymetry dataset has geometry for the water body currently on screen, the map shows it as depth contour lines and/or depth-area polygons, layered above the active base map (Maastokartta or Ilmakuva) and below application-owned layers (fishing-spot markers/labels, current-location indicator).

#### FR-29 — Correct No-Data Behavior for Bathymetry

Wherever SYKE has no geometry for a given lake/river (a large majority of Finland's water bodies by count, per `investigation/syke_depth/coverage_report.md` — full national coverage was never SYKE's own claim, and is not this milestone's either), the map shows that water body exactly as the base map alone already renders it, with no error, no placeholder, no "no data" indicator, and no visual distinction from a water body that was never expected to have bathymetry at all. Missing bathymetry is normal, expected behavior, not a failure state (per this milestone's own explicit product framing) and must not be presented as one.

#### FR-30 — Zoom-Dependent Readability

Bathymetry content is not shown at zoom levels where it would not be legibly useful (e.g., a whole-country or whole-region view) and becomes visible once the angler is zoomed to a level where individual water bodies and their internal structure are actually discernible. **Resolved by physical Android testing (TD-027 §27):** contour lines from `minzoom` 10, depth labels from `minzoom` 12 — depth-area shading is bundled but not part of the shipped presentation (TD-027 §27, "Depth-area fill").

#### FR-31 — Attribution for MML, SYKE, and MapTiler, as Applicable

Attribution correctness is extended, not redesigned: MML's existing attribution condition (FR-21, now driven by "Maastokartta selected AND MML configured," unaffected in shape by the raster→vector change) continues to apply. MapTiler's existing, always-present attribution (FR-21) is unchanged. **A new SYKE attribution requirement is added**: whenever the bathymetry overlay is present in the build (this milestone ships it unconditionally, with no user-facing on/off toggle — see Out of Scope), SYKE's required CC BY 4.0 attribution must be shown, using the same compact, tap-to-expand mechanism already established for MapTiler (TD-027 §11) rather than a third permanently-visible text block. Exact wording/placement is a TD-027 decision (see TD-027 §24).

#### FR-32 — No Regression to Existing Map Functionality

Fishing-spot markers/labels, tap interaction, adding fishing spots, current-location controls, other `MapScreen` entry points (Lure Tools, Statistics, Catch Search), and Maastokartta ↔ Ilmakuva base-map switching all continue to work exactly as already established by MFS-026/MFS-027 Revisions 1–6, over every composition this milestone introduces (MML v21 vector + MapTiler Outdoor + SYKE bathymetry, for Maastokartta; MapTiler Satellite Hybrid + SYKE bathymetry, for Ilmakuva). Switching base maps, or any future base-style reload, must restore the bathymetry overlay exactly as it already must restore fishing-spot markers (MFS-026/TD-026's existing restoration guarantee, extended to cover this new overlay).

#### FR-33 — No Generalized Bathymetry/Provider Framework

This milestone integrates SYKE specifically, by name, as a single narrowly-scoped overlay. It does not introduce a generalized multi-provider bathymetry abstraction, a pluggable overlay-provider interface, or any mechanism designed for a hypothetical future data source beyond SYKE — consistent with `docs/development-rules.md`'s existing prohibition on premature abstraction and this milestone's own explicit instruction.

### Physical Android Acceptance Tests — Revision 7

In addition to the existing Revisions 1–6 physical-testing checklist (TD-027 §12), the following water bodies must be verified on a physical Android device before this milestone is considered complete, chosen specifically for their differing SYKE coverage (per `investigation/syke_depth/coverage_report.md`):

| Water body | Expected SYKE result | What this verifies |
|---|---|---|
| **Kymijärvi** (Lahti) | Bathymetry visible — depth contours/areas render correctly over the lake, at the appropriate zoom, positioned correctly relative to MML's own vector shoreline. | The positive case: real geometry renders, correctly aligned, correctly styled. |
| **Vesijärvi** (Lahti/Hollola) | **No SYKE geometry** (confirmed zero depth areas/points in the investigation, despite the register recording a max-depth number with no renderable geometry) — the map must behave completely normally: no error, no placeholder, no visual gap, fishing spots/interaction unaffected. | The explicit no-data case, directly adjacent (geographically and often product-expectation-wise) to a covered lake — the most likely place a no-data bug would actually be noticed by a real angler. |
| **Päijänne** | **Mixed coverage** — the south basin has substantial contour/area coverage across several named sub-parts; the north basin has none. Both must render correctly within the same single water body/pan session, with the transition between covered and uncovered sub-basins showing no artifact. | The mid-lake transition case — geometry present in part of a body of water an angler perceives as "one lake," absent in another part. |
| **Saimaa** | **Substantial coverage** — thousands of depth-area features across many named sub-basins (Haukivesi, Pihlajavesi, Orivesi, Puruvesi, Pyhäselkä, Kallavesi, etc.). | The dense/heavy-data case — rendering performance, label/line density, and visual legibility at realistic Finnish-lake-district data volume, not just a small single-lake sample. |

### Out of Scope — Revision 7 additions

- MML raster WMTS as Maastokartta's Finnish data source (superseded by vector; see TD-027 §25 for what is retired versus retained).
- The on-device raster pixel-masking process (`MmlTileMasker`, and `MmlTileMaskService`'s masking-specific logic) as a live, in-use mechanism (superseded; see TD-027 §25).
- A generalized, pluggable bathymetry-provider or overlay-provider framework (FR-33).
- Live SYKE WFS requests from the mobile app at runtime (see TD-027 §20 for the chosen delivery architecture — a preprocessed, bundled dataset).
- A user-facing on/off toggle for the bathymetry overlay (it ships unconditionally present, wherever data exists — a future milestone could add one if real usage shows a need, not designed here).
- Sounding-value points (`EL.SpotElevation`, one summary point per named sub-basin) — deferred; see TD-027 §21 for the reasoning and Future Extensions below. **Distinct from, and not satisfied by,** the depth labels shipped on contour lines themselves (reading each contour's own `depth_m` attribute — TD-027 §27) — that is a different, later-added refinement to the `contours` source-layer already in scope, not this deferred, separate dataset.
- Any offline-map-download feature or user-facing "download this area" affordance for bathymetry (it is fully bundled, always available offline, with no partial/regional download concept — see TD-027 §23).
- Hillshade, MML Ortokuva reintroduction for Ilmakuva, navigation/routing, map search, and every other exclusion already listed in [Out of Scope](#out-of-scope-1) below, all unchanged.

### Future Extensions — Revision 7 additions

- `EL.SpotElevation` depth points/labels (max/mean depth per lake), deferred from v1 for the reasons given in TD-027 §21.
- A user-facing bathymetry visibility toggle, if real usage indicates anglers want to hide it at times.
- Reconsidering the coastal/territorial-water buffer or a higher-precision coverage geometry for the vector path, only if physical testing surfaces a real, visible problem — mirroring the same evidence-driven discipline Revisions 4–6 already established for the (now-superseded) raster path.

---

## Purpose

**Historical (Revisions 1–6).** See [Revision 7](#revision-7--vector-base-map-and-syke-bathymetry-current-direction) above for the current direction. The MapTiler worldwide-fallback purpose stated below is unchanged in substance by Revision 7; only Maastokartta's own Finnish rendering technology (raster → vector) and the addition of a bathymetry overlay have changed.

Give both existing MFS-026 base-map choices real worldwide coverage, per ADR-0009:

- **Maastokartta** gains automatic MapTiler Outdoor coverage beneath MML Maastokartta, so panning or zooming outside MML's Finland-only coverage never leaves the angler looking at an empty or blank map.
- **Ilmakuva** becomes MapTiler Satellite Hybrid, worldwide, including within Finland — a single, consistent aerial/satellite base map rather than a Finland-only MML product with no fallback outside it.

This milestone does not add a new user-facing map choice — Maastokartta and Ilmakuva remain the only two selectable options. It changes what each of them renders, so that both feel continuous and useful everywhere in the world, not just inside Finland.

---

## User Value

An angler planning a trip that crosses into Sweden, exploring the map out of curiosity, or simply panning too far while looking for a specific bay, currently hits a blank map (Maastokartta) or has no aerial-imagery option at all (Ilmakuva) the moment they leave MML's coverage. This milestone removes both dead ends: Maastokartta keeps showing a recognizable, still-navigable topographic world map everywhere, returning to full MML Finnish detail automatically back inside Finland; Ilmakuva shows one consistent worldwide aerial/satellite view everywhere, including Finland, with no coverage gap to hit in the first place.

---

## Scope

### In Scope

- **Maastokartta:** automatic MapTiler Outdoor coverage beneath MML Maastokartta, visible wherever MML Maastokartta has no imagery for the current view (unchanged in shape from this milestone's original design).
- **Ilmakuva:** MapTiler Satellite Hybrid used directly as the complete worldwide base map, everywhere, including within Finland. **MML Ortokuva is not part of Ilmakuva's rendering path in this milestone.**
- Preserving Maastokartta's existing MML-Finland behavior, exactly as implemented by MFS-026/TD-026, everywhere within MML's actual coverage.
- Loading and failure handling for both compositions, including MapTiler-specific failure/misconfiguration, following ADR-0009's failure-independence principle — understood per-selection, since Ilmakuva has only one base-imagery provider while Maastokartta has two (see [Conceptual Model](#conceptual-model)).
- Attribution correctly scoped per selection: both MML's and MapTiler's for Maastokartta; only MapTiler's for Ilmakuva (MML's must not be shown for Ilmakuva, since MML is not used by that selection).
- Preserving all existing map functionality (fishing-spot markers/labels, tap interaction, adding fishing spots, location controls, other `MapScreen` entry points, and the base-map switch/restoration behavior established by MFS-026/TD-026) over every composition, with no regression.

### Out of Scope

See [Out of Scope](#out-of-scope-1) for the complete list. Notably: MapTiler (or any global map) as a third selectable base-map option; additional global providers; any provider-selection UI; depth contours; hillshade beyond whatever is inherent in the MapTiler styles used; offline map downloads or a custom offline-caching system; navigation/routing; map search; location-permission-based or device-location-based country/geofence detection; a precise/survey-grade Finland boundary (an approximate region for Maastokartta's own MML-inclusion check is, per [FR-11](#fr-11--geographic-region-governs-mml-inclusion-for-maastokartta), now explicitly in scope — see [Conceptual Model](#maastokartta-an-explicit-geographic-region-now-governs-mmls-inclusion-revised-after-physical-testing)); backend/proxy infrastructure; any redesign of fishing spots or of the existing MFS-026 selector; MML vector maps; custom MapTiler vector styling beyond whatever minimal configuration TD-027 finds is actually required for the chosen existing styles; and reintroducing MML Ortokuva into the Ilmakuva composition (left to a possible future milestone, not this one).

---

## User Stories

**As an angler**
I want the map to keep showing useful content when I pan outside Finland
So that I'm never looking at a blank map while exploring or planning a cross-border trip.

**As an angler**
I want this to just happen automatically
So that I never have to find or switch into a separate "world map" mode.

**As an angler**
I want Maastokartta to keep working exactly as it does today inside Finland
So that this change doesn't cost me anything I already rely on when I'm looking at Finnish terrain.

**As an angler**
I want Ilmakuva to show me a consistent aerial/satellite view wherever I am, including in Finland
So that I never hit a "no aerial imagery here" gap the way I might have outside Finland before.

**As an angler**
I want my fishing spots to stay visible and tappable no matter which part of the map I'm looking at
So that switching between Finnish detail and worldwide context never costs me my existing data or workflow.

**As an angler**
I want panning back into Finland to naturally restore full Finnish detail
So that the transition feels like one continuous map, not two separate systems bolted together.

---

## Conceptual Model

ADR-0009 is authoritative for the underlying provider/delivery architecture and for the experimentally verified MML no-data-tile behavior Maastokartta's automatic fallback depends on. This section restates only what is necessary to specify user-facing behavior, following the same discipline MFS-026's own Conceptual Model section established.

### Two different compositions, not one shared worldwide layer

Maastokartta and Ilmakuva are composed differently in this milestone:

- **Maastokartta** = MML Maastokartta (within its coverage) with MapTiler Outdoor automatically visible beneath it wherever MML has no imagery. This is the "worldwide underlay beneath a selected MML layer" model.
- **Ilmakuva** = MapTiler Satellite Hybrid, worldwide, including within Finland. There is no MML sub-layer in this composition at all in this milestone.

Both remain part of what the angler perceives as *one* base map per selection — the base-map selector introduced by MFS-026 continues to offer exactly two choices (Maastokartta, Ilmakuva); MapTiler is never a separate entry in that selector, never has its own toggle, and is never named to the angler as a distinct "map" they picked, for either selection.

### Ilmakuva is worldwide MapTiler Satellite Hybrid, everywhere — including Finland

This reverses an earlier draft of this milestone's own design, recorded here for clarity rather than silently dropped: an earlier version of this specification held that "Ilmakuva does not imply worldwide satellite imagery" and used one shared, non-aerial worldwide style regardless of MML selection. That is no longer the design. **Selecting Ilmakuva now shows MapTiler Satellite Hybrid everywhere the angler pans or zooms, including inside Finland** — not MML's own Ortokuva imagery, and not a generic topographic worldwide fallback. MML Ortokuva is not used by this milestone's Ilmakuva rendering path at all. This is a deliberate, explicit product decision (see ADR-0009's Decision and Consequences sections for the full reasoning and trade-offs), not an oversight, and it means Ilmakuva's appearance changes within Finland compared to the currently shipped MFS-026/TD-026 behavior, not only outside it.

### Maastokartta: an explicit geographic region now governs MML's inclusion (revised after physical testing)

An earlier version of this specification held that MapTiler Outdoor becomes visible wherever MML Maastokartta has nothing to draw, relying entirely on MML's own transparent no-data tile behavior, with no Finland boundary, polygon, mask, geofence, or country-detection logic of any kind. **Physical Android testing has since shown this does not hold reliably at broader geographic scale** — MML was found to render opaque gray/white blocks and visible coverage-boundary artifacts in some areas outside Finland (Sweden, the Baltic region, and elsewhere), rather than the uniformly transparent behavior the original narrow spot-checks suggested. See ADR-0009's Revision Note 2 for the full account of what was observed.

**Maastokartta's composition is therefore revised:** MML Maastokartta is included in the composed base map only when the current viewport is determined to be within an approximate Finland region (not MML's own coverage, and not a raw rectangular bounding box — see [Design Notes](#design-notes) for why); outside that region, MapTiler Outdoor is shown without MML in the composition at all, so MML's own unreliable edge/no-data rendering can never be requested or displayed in the first place. This check uses hysteresis (see [FR-12](#fr-12--geographic-continuity-and-switching-stability-across-the-maastokartta-region-boundary)) so that ordinary panning near the region's edge does not cause repeated, unstable switching. MapTiler Outdoor's own presence is **not** conditioned on this check — it remains the constant, always-present underlay for Maastokartta, preserving the failure-independence guarantee ADR-0009 already established (MML can still fail even well inside the region, and MapTiler Outdoor must still be there as backup).

Ilmakuva needs no equivalent mechanism at all — physical testing found it working correctly worldwide, including within Finland, and it has nothing to fall back *from*, since it never shows MML content in the first place; its design is unchanged. Exactly how MapLibre is made to composite either provider combination, and the exact geographic/hysteresis mechanism for Maastokartta, are TD-027 concerns, not specified here.

### Maastokartta: MML inclusion also requires a minimum zoom (revised again after further physical testing)

**The region check above is necessary but, on its own, not sufficient.** Further physical Android testing found that even when the viewport's center is legitimately inside Maastokartta's Finland region, zooming far enough out reproduces the same class of defect the region check exists to fix — large opaque gray/white areas and visible tile/coverage-boundary artifacts — because a low-zoom viewport visibly covers a geographic area larger than Finland's own real extent, regardless of where its center sits. The region check only ever answers one question for the *whole* composition ("is MML part of this style or not"); it was never designed to answer "is MML part of this style *and* does the current view actually stay within the area MML can render cleanly."

**Maastokartta's composition is therefore revised again:** MML Maastokartta is included in the composed base map only while *all three* of the following hold: MML is configured, the viewport is within the Finland region ([FR-11](#fr-11--geographic-region-governs-mml-inclusion-for-maastokartta)), and the current zoom is at or above an activation threshold ([FR-23](#fr-23--zoom-gated-mml-inclusion-for-maastokartta-second-revision-after-physical-testing)). Below that threshold, MapTiler Outdoor is shown alone, exactly as it already is outside the region — this is not a new kind of unavailability, it is the same "MapTiler Outdoor alone" state the region check can already produce, now also reachable by zooming out rather than only by panning away. See [Design Notes](#design-notes) for why this is implemented as a static property of MML's own map layer rather than a third application-side check, and why it needs no additional hysteresis mechanism of its own.

Ilmakuva needs no equivalent zoom mechanism either, for the same reason it needs no geographic one: it has no MML content and no coverage-dependent behavior at any zoom.

**Both mechanisms above are superseded by [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence) below — kept here as an accurate record of what this specification required at each stage, not as the current design.**

### Maastokartta: MML pixels are masked to Finland's actual coverage (third revision, after direct pixel-level evidence)

Both mechanisms above worked at the level of the *viewport*: each decided, for the whole visible map, whether MML belonged in the composition at all. **Direct inspection of real MML tiles — not inference from symptoms — found the actual defect lives at the level of the *pixel*, not the viewport:** MML's own raster tiles render out-of-coverage areas as ordinary opaque pixels (a flat gray fill, confirmed by decoding real tiles byte-for-byte), never as transparency. No decision about whether to show MML's layer at all — however precisely the boundary or the zoom threshold is tuned — can make already-opaque pixels transparent. See ADR-0009's Revision Note 4 for the full evidence.

**Maastokartta's composition is revised a third time, and this time the fix addresses the actual defect directly:** MML Maastokartta's raster source is included in the composed base map unconditionally whenever MML is configured — exactly like MapTiler Outdoor already is — and a small process running entirely on the angler's own device makes the parts of MML's own tiles that fall outside real Finnish coverage transparent *before* the map ever displays them. There is no longer a viewport-level "is MML in or out" decision to make, so there is nothing left to make abruptly, nothing to stabilize with a margin, and no zoom range to exclude. MML and MapTiler are simultaneously visible, correctly, in the same viewport whenever the border is on screen — this was never fully achievable under either earlier mechanism, since both operated on the whole composition at once.

Ilmakuva needs no equivalent mechanism, unchanged for the same reason as always: it has no MML content at all.

### Persistence keeps its existing, narrower meaning

MFS-026's persisted base-map preference means, and continues to mean, only "which of Maastokartta/Ilmakuva is selected." Neither Maastokartta's MapTiler underlay nor Ilmakuva's MapTiler base map is a separate preference the angler sets, is paired with a new persisted value, or changes what the existing preference represents. An angler who selected Ilmakuva before this milestone existed sees the same choice name and the same persisted value after this milestone ships — what changes is what that choice now renders (see [Persistence Behavior](#persistence-behavior)).

### Switching still works, for both compositions

MFS-026/TD-026 already made switching between Maastokartta and Ilmakuva survive without losing fishing-spot markers. This milestone extends that same expectation to both of this milestone's compositions: switching must not remove or interrupt whatever content is currently visible (MapTiler Outdoor and/or MML Maastokartta for one direction, MapTiler Satellite Hybrid for the other), and fishing-spot markers/labels must still be restored exactly as they already are today. Because Ilmakuva is now uniformly MapTiler Satellite Hybrid everywhere, switching to or from Ilmakuva always visibly changes the rendered content, regardless of location — there is no longer a location-dependent case where switching to Ilmakuva looks the same as staying on Maastokartta (as could happen under the earlier, now-superseded "one shared worldwide layer" design, outside MML's coverage).

---

## Functional Requirements

Grouped by which composition each requirement governs, since Maastokartta and Ilmakuva no longer share one uniform worldwide-fallback model.

### Shared (both selections)

#### FR-1 — No New Selectable Base Map

The base-map selector continues to present exactly the two choices already established by MFS-026 (Maastokartta, Ilmakuva). MapTiler is never presented as a third selectable choice, is never named to the angler in the selector, and has no separate visibility toggle, for either composition.

#### FR-2 — Existing Selection Persistence Retains Its Existing Meaning

The base-map preference already persisted per MFS-026 FR-8 continues to mean exactly what it means today: which of Maastokartta/Ilmakuva is selected. This milestone does not introduce a new persisted preference for either composition's worldwide content, and does not change the meaning, storage, or restoration behavior of the existing preference.

#### FR-3 — Fishing-Spot Markers and Labels Remain Visible and Interactive Over Every Composition

Existing fishing-spot markers and their name labels must remain visible, correctly positioned, and tappable regardless of which composition is currently rendering (MML Maastokartta and/or MapTiler Outdoor; or MapTiler Satellite Hybrid).

#### FR-4 — No Regression to Base-Map-Switch Restoration

The existing MFS-026/TD-026 guarantee — that fishing-spot markers/labels/tap interaction survive a Maastokartta ↔ Ilmakuva switch with no need to leave and reopen the Map screen — must continue to hold in every case it already holds today, for a switch between either composition, regardless of location.

#### FR-5 — Worldwide Coverage Is Present From Initial Load

Both compositions must be part of the map's normal presentation from the very first (cold) load of a session — Maastokartta's MapTiler Outdoor underlay, and Ilmakuva's MapTiler Satellite Hybrid base map — not something that only becomes available after some other action, panel, or delayed initialization step.

#### FR-6 — Both Compositions Remain Useful Across the Normal Zoom Range

Both compositions must remain visually useful (i.e., not blank or missing) across the zoom range the map already supports today, without this specification inventing new zoom constants beyond whatever range the relevant MapTiler style(s) actually provide.

#### FR-7 — Loading Behavior

While either composition's tiles are loading — initial load, panning/zooming into a not-yet-loaded area, or switching between Maastokartta and Ilmakuva — the angler must see sensible, non-jarring behavior, not a blank or black gap presented with no indication anything is happening.

#### FR-8 — No Out-of-Scope Functionality Introduced

This milestone must not introduce any capability listed in [Out of Scope](#out-of-scope-1) — in particular, no third selectable base map, no location-permission-based or device-location-based country/geofence detection, no backend/proxy infrastructure, and no reintroduction of MML Ortokuva into the Ilmakuva composition. (A Finland/Åland coverage geometry, and the on-device, per-pixel masking process that uses it to govern Maastokartta's MML rendering, are explicitly in scope per [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence) — a narrower, revised exception to what earlier out-of-scope language prohibited; see [Conceptual Model](#maastokartta-mml-pixels-are-masked-to-finlands-actual-coverage-third-revision-after-direct-pixel-level-evidence). The on-device process is not "backend/proxy infrastructure" in the sense that item otherwise prohibits — see ADR-0009 Revision Note 4.)

### Maastokartta-specific

#### FR-9 — Automatic Worldwide Fallback for Maastokartta

Wherever the current view falls outside Maastokartta's real Finnish coverage — now enforced per pixel, per [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence), rather than per viewport — MapTiler Outdoor coverage must be visible, with no user action of any kind required. MapTiler Outdoor must also remain available as the constant underlay even where MML's own content is genuinely present, so a temporary MML failure there still leaves usable imagery visible (see [FR-16](#fr-16--mml-maastokartta-unavailable-maptiler-outdoor-available)).

#### FR-10 — Maastokartta Behavior Preserved Within the Finland Region

Within Maastokartta's Finland region, and while MML itself is available, the map continues to render and behave exactly as already implemented by MFS-026/TD-026, with no observable change.

#### FR-11 — Geographic Region Governs MML Inclusion for Maastokartta (revised after physical testing; **mechanism superseded by [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence)**)

**This requirement reverses an earlier version of this specification** — see [Conceptual Model](#maastokartta-an-explicit-geographic-region-now-governs-mmls-inclusion-revised-after-physical-testing) and ADR-0009's Revision Note 2 for why. It originally required MML's raster content to be included in the composed base map only while the current *viewport* was within an approximate Finland region. **Direct pixel-level evidence subsequently showed a viewport-level decision — however it is evaluated — cannot produce a clean result, because MML's own out-of-coverage pixels are opaque, not transparent (ADR-0009 Revision Note 4).** [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence) restates this requirement correctly, at the pixel level. The underlying geographic definition this requirement introduced (an approximate Finland/Åland region, not a raw rectangular bounding box — see [Design Notes](#design-notes)) remains in use, now as the input to that pixel-level masking rather than to a viewport check. This requirement does **not** reintroduce country/geofence detection via location permission or device location ([FR-22](#fr-22--no-location-permission-or-country-determination-required) still applies) — geography is evaluated purely against the map's own tile coordinates, never the device's real-world location.

#### FR-12 — Geographic Continuity and Switching Stability Across the Maastokartta Region Boundary (**superseded by [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence)**)

This requirement originally required a hysteresis margin (or equivalent mechanism) so that panning near a *viewport-level* region boundary would not cause unstable, repeated switching. **Under pixel-level masking (FR-24), there is no viewport-level switching of any kind to stabilize** — MML's raster source is unconditionally present in the composition, and individual pixels are transparent or opaque based purely on their own real-world location, recomputed independently for whatever tiles the current view happens to need. The goal this requirement protected — no abrupt, jarring, or repeatedly-flickering change at the border — is satisfied more completely under FR-24 than a hysteresis margin could ever guarantee, because there is no discrete state for a margin to protect. No additional application-level visual boundary indicator (a line, shading, warning banner, or similar) is introduced to mark the coverage edge, unchanged from the original requirement.

#### FR-13 — Switching to/from Maastokartta Outside MML Coverage Does Not Remove Worldwide Coverage

Switching between Maastokartta and Ilmakuva while the current view is outside MML Maastokartta's coverage must not remove, interrupt, or blank out visible map content at any point in the transition. The angler continues to see a populated, navigable map throughout and immediately after the switch (noting that, unlike this milestone's earlier design, switching to Ilmakuva now always visibly changes the rendered content to MapTiler Satellite Hybrid — see [Conceptual Model](#ilmakuva-is-worldwide-maptiler-satellite-hybrid-everywhere--including-finland)).

#### FR-14 — Switching While Inside MML Maastokartta Coverage

Switching from Maastokartta to Ilmakuva while inside MML Maastokartta's actual coverage replaces the visible MML Maastokartta (and any MapTiler Outdoor content) with MapTiler Satellite Hybrid; switching back restores MML Maastokartta (with MapTiler Outdoor remaining an inactive, non-visible underlying layer, exactly as today) — both directions behaving exactly as already implemented by MFS-026 for the MML-visible portion of the transition.

#### FR-15 — MapTiler Outdoor Unavailable, MML Maastokartta Available

If MapTiler Outdoor is unreachable or failing while MML Maastokartta is itself available and the current view is within its coverage, MML Maastokartta must remain visible and fully usable exactly as today. Only areas that would otherwise rely on the MapTiler Outdoor underlay are affected, and that condition must degrade per FR-17's non-technical treatment rather than crash or expose technical detail.

#### FR-16 — MML Maastokartta Unavailable, MapTiler Outdoor Available

If MML Maastokartta is unreachable or failing (network failure or missing/invalid configuration, per MFS-026 FR-16/FR-17), that failure must not be allowed to unnecessarily also make MapTiler Outdoor unavailable, per ADR-0009's failure-independence principle — the two providers are independent services, and one failing must not needlessly destroy the other's usable coverage merely because they are visually composited together.

#### FR-17 — Both Maastokartta Providers Unavailable

If both MML Maastokartta and MapTiler Outdoor are unreachable or failing at the same time, the application must not crash, must show no technical detail (URL, HTTP status, provider name, or provider-specific error string) from either provider, and must present the same clear, calm, Finnish-language "map imagery unavailable" treatment MFS-026 already established. Application-owned map content (fishing-spot markers, controls, and other entry points) must remain as usable as reasonably possible, exactly as required by MFS-026 FR-16/FR-17.

#### FR-18 — Missing or Invalid MapTiler Configuration (Maastokartta)

If the MapTiler API credential/configuration is missing or invalid while Maastokartta is selected, the application must not crash, must never expose the missing/invalid credential, URL, or any provider-specific error detail, and must present the same clear, calm, Finnish-language "map imagery unavailable" treatment as any other failure condition in this specification — applied to the affected (MapTiler Outdoor) coverage specifically, without necessarily treating an otherwise-healthy MML Maastokartta layer as unavailable too, per FR-16.

#### FR-23 — Zoom-Gated MML Inclusion for Maastokartta (second revision after physical testing; **superseded by [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence)**)

This requirement originally required MML's raster content to additionally depend on the current camera zoom being at or above an activation threshold, on top of FR-11's geographic condition, because a low-zoom *viewport* could span more area than Finland's own extent regardless of where its center sat. **Pixel-level masking (FR-24) makes this unnecessary: correctness is enforced per pixel, independent of how much area the current viewport happens to cover, so it holds at every zoom without a separate threshold.** No zoom-based exclusion of MML exists under the current design.

#### FR-24 — Pixel-Level MML Coverage Masking for Maastokartta (third revision, after physical evidence)

**This requirement supersedes FR-11's, FR-12's, and FR-23's mechanisms** (their underlying goals are retained, restated correctly below) — see [Conceptual Model](#maastokartta-mml-pixels-are-masked-to-finlands-actual-coverage-third-revision-after-direct-pixel-level-evidence) and ADR-0009's Revision Note 4 for the evidence and reasoning. Direct inspection of real MML tiles found the actual defect is that MML's own out-of-coverage pixels are rendered fully opaque (a flat, textureless fill), never transparent — a fact no viewport-level inclusion/exclusion rule, however precisely tuned, could ever compensate for.

MML Maastokartta's raster source must be part of Maastokartta's composition whenever MML is configured, unconditionally — the same way MapTiler Outdoor already is. Correctness of *what is visible* is instead enforced by making the parts of MML's own tiles that fall outside real Finnish/Åland coverage transparent before they are ever displayed, so that:

- Wherever real Finnish coverage exists, MML's own cartography is shown, pixel-for-pixel unchanged from what MML itself returns.
- Wherever it does not, MapTiler Outdoor is visible instead, with no opaque gray/white block, no visible tile-boundary artifact, and no dependence on MML's own edge behavior.
- At the actual border, both are visible simultaneously, correctly, within the same viewport — not merely as a coincidence of tile-loading timing, but as the intended, designed outcome.
- This holds at every zoom level and every pan position, with no separate zoom or hysteresis condition required.

The exact mechanism (where this transformation runs, how coverage is determined per pixel, caching, and performance) is a Technical Design (TD-027) concern — see TD-027 §3C. This requirement does not mandate that the transformation run on a remote server; TD-027 §3C's chosen design (an entirely on-device, loopback-only process) is binding once adopted, per [Architecture Constraints](#architecture-constraints), and does **not** constitute the backend/proxy infrastructure this specification's [Out of Scope](#out-of-scope-1) otherwise prohibits (it never leaves the device — see ADR-0009 Revision Note 4 for the distinction).

### Ilmakuva-specific

#### FR-19 — Ilmakuva Is MapTiler Satellite Hybrid Everywhere

Selecting Ilmakuva shows MapTiler Satellite Hybrid as the complete base map, uniformly, at every location — inside Finland and everywhere else — with no MML Ortokuva content, no coverage-dependent fallback logic, and no boundary of any kind.

#### FR-20 — MapTiler Satellite Hybrid Unavailable (Ilmakuva)

If MapTiler Satellite Hybrid is unreachable, failing, or its configuration is missing/invalid while Ilmakuva is selected, the application must not crash, must show no technical detail, and must present the same clear, calm, Finnish-language "map imagery unavailable" treatment MFS-026 already established for a comparable failure. **Ilmakuva has no fallback base-imagery provider in this milestone** — unlike Maastokartta, there is no second provider for this condition to degrade *to*; application-owned map content (fishing-spot markers, controls, other entry points) must remain as usable as reasonably possible, exactly as required by MFS-026 FR-16/FR-17, even while Ilmakuva's own base imagery is entirely unavailable.

### Shared, restated for both

#### FR-21 — Attribution, Scoped Per Selection and Per Actual Composition

- MapTiler's attribution requirement applies continuously whenever either MapTiler product is configured, for both selections (unchanged).
- While **Maastokartta** is selected, MML's existing, already-implemented attribution requirement (MFS-026 FR-18) applies **whenever MML is configured** — matching MapTiler's own attribution condition, and simpler than either of the two prior revisions required. **Revised, again, by [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence):** because MML's raster source is now unconditionally part of Maastokartta's composition whenever configured (its visibility governed per pixel, not per viewport — see [Conceptual Model](#maastokartta-mml-pixels-are-masked-to-finlands-actual-coverage-third-revision-after-direct-pixel-level-evidence)), "is MML part of the composition" is once again simply a configuration question, not a viewport-position or zoom question — the extra viewport/zoom-awareness two earlier revisions required for this same attribution rule is no longer needed. A residual, accepted imprecision: MML's attribution may be shown even in the rare case where the current viewport happens to show none of its content (e.g., panned entirely outside Finland while still zoomed in) — the same category of minor imprecision MapTiler's own attribution has always accepted, not a new one.
- While **Ilmakuva** is selected, the map must satisfy only MapTiler's attribution requirement (for Satellite Hybrid). MML's attribution must not be shown while Ilmakuva is selected, since MML data is never part of that composition in this milestone.

Exact wording, placement, and presentation mechanism are Technical Design (TD-027) decisions — see [Attribution](#attribution).

#### FR-22 — No Location Permission or Country Determination Required

Neither composition's availability may depend on location permission being granted, on the device's current location being known or requested for this purpose, or on any determination of which country the angler is currently viewing. (This is trivially true for Ilmakuva, which has no location-dependent behavior at all; it remains a real constraint for Maastokartta's fallback mechanism.)

---

## UI Expectations

- No new floating control, selector entry, or screen is introduced. The existing MFS-026 layers control and its selector (exactly two choices: Maastokartta, Ilmakuva) are unchanged in structure and behavior.
- Neither composition has an on-screen label, icon, or indicator identifying MapTiler as a separate "map" or provider — it simply appears as part of whichever base map is currently selected.
- Attribution is scoped per selection (both MML and MapTiler for Maastokartta; MapTiler only for Ilmakuva), using whatever compact, non-cluttering presentation TD-027 designs — exact layout is not fixed here.
- All user-visible text remains Finnish, consistent with the application's existing UI-text convention.
- No pixel dimensions, animations, or exact widget classes are specified here — implementation detail belongs to TD-027.

---

## Navigation

This milestone introduces no new screen, route, or navigation entry point. It changes only what the existing `MapScreen` renders as its base map beneath the angler's existing Maastokartta/Ilmakuva selection.

---

## Persistence Behavior

- The existing Maastokartta/Ilmakuva preference persisted per MFS-026 FR-8 is unchanged in meaning, storage, and restoration behavior.
- No new persisted value is introduced for either composition — worldwide content is not a separate choice the angler makes, so there is nothing new to remember.
- A user who has never made a base-map selection continues to see Maastokartta as the default (MFS-026 FR-2), with MapTiler Outdoor automatically available beneath it wherever MML Maastokartta itself has no imagery, from the very first launch.

---

## Loading and Failure Behavior

| Situation | Required user-facing behavior |
|---|---|
| Initial map load (either composition loading as part of normal presentation) | Sensible loading indication; no blank/black gap with no explanation (FR-5, FR-7). |
| Panning/zooming into a not-yet-loaded area (Maastokartta's MapTiler Outdoor underlay) | Sensible loading behavior for the newly revealed area; no jarring blank flash (FR-7). |
| The viewport crosses Maastokartta's real coverage boundary, at any zoom, in any direction (pan or zoom) | Not a failure — a normal, expected content change, and no longer a discrete "event" at all (FR-24 supersedes FR-11/FR-12/FR-23's viewport/zoom-level versions of this row). MML's own tiles simply render transparent outside real coverage and opaque within it, per pixel; no style regeneration, no crash, no visible artifact, no blank gap, at any zoom. |
| A specific MML tile requested by the on-device masking process fails, times out, or returns malformed data | Not exposed as a distinct failure to the angler — that specific tile degrades to showing MapTiler Outdoor beneath it (the same visual outcome as genuinely being outside coverage there), self-healing the next time the tile is requested. No crash, no technical detail, no permanent record of the transient failure (TD-027 §3C). |
| **Maastokartta:** MapTiler Outdoor unavailable, MML Maastokartta available and within its region | MML Maastokartta remains fully visible and usable; only would-be-underlay areas are affected, degrading per the "both unavailable" row rather than crashing (FR-15). |
| **Maastokartta:** MML unavailable (network failure or missing/invalid configuration), MapTiler Outdoor available | MML's own existing failure treatment (MFS-026 FR-16/FR-17) applies to the MML layer; MapTiler Outdoor's availability is not unnecessarily also destroyed by this, per ADR-0009's failure-independence principle (FR-16). |
| **Maastokartta:** both MML and MapTiler Outdoor unavailable | No crash; no technical detail from either provider; the same clear, calm, Finnish-language "map imagery unavailable" message MFS-026 already established; application-owned map content remains as usable as reasonably possible (FR-17). |
| **Maastokartta:** missing or invalid MapTiler configuration/API credential | No crash; the missing/invalid credential, URL, or any provider-specific detail is never exposed; the same "map imagery unavailable" treatment, scoped to the affected MapTiler Outdoor coverage (FR-18). |
| **Ilmakuva:** MapTiler Satellite Hybrid unavailable, misconfigured, or its credential missing/invalid | No crash; no technical detail exposed; the same clear, calm, Finnish-language "map imagery unavailable" treatment. There is no fallback provider to degrade to for this selection — application-owned map content remains as usable as reasonably possible regardless (FR-20). |

In every row above, "application-owned map content remains as usable as reasonably possible" carries the same meaning already established by MFS-026: fishing-spot markers/labels, fishing-spot tap interaction, adding fishing spots, location controls, and other Map screen entry points do not become entirely unusable purely because external base-map imagery (from any provider) failed to load.

Under no circumstance may any of the situations above surface an API key, a raw request URL, a stack trace, or a provider-specific/technical error message to the angler, for any provider.

This specification does not design retry algorithms, timeout values, or MapLibre lifecycle mechanics for any of the above — those are Technical Design (TD-027) concerns, following the same discipline MFS-026 already established for MML's own failure handling.

---

## Attribution

The map UI must satisfy each selection's attribution obligations correctly and separately — this is stated here as a user-facing and legal requirement only, per ADR-0009:

- **Maastokartta:** MapTiler's attribution requirement (for Outdoor) always applies. MML's existing, already-implemented attribution requirement (MFS-026 FR-18/TD-026 `MapAttribution`) applies whenever MML is configured — matching MapTiler's own condition, per [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence).
- **Ilmakuva:** only MapTiler's attribution requirement (for Satellite Hybrid) applies. MML's attribution must not be shown, since MML is not used by this composition.

Exact attribution text, placement, styling, whether MapTiler's notice is shown continuously or only while its content is actually on-screen, and how the per-selection MML-attribution toggle is implemented are Technical Design (TD-027) concerns. The requirement must be satisfied without unnecessary visual clutter, particularly on a mobile screen.

---

## Data Ownership

- This milestone builds on the `core/map` area TD-026 already established (per `app-structure.md`'s anticipated "Map configuration" responsibility) rather than introducing a new one. Whether the worldwide-coverage logic extends existing `core/map` types or adds new, narrowly-scoped ones alongside them is a Technical Design (TD-027) decision, not resolved here.
- No existing domain model, schema, or repository contract in `fishing_spots`, `catches`, or any other feature changes as a result of this milestone.
- No new database table, column, or schema version is assumed by this specification; if Technical Design determines one is needed, that is its decision to make and justify, not a requirement imposed here.
- Fishing-spot marker/label rendering and restoration logic already modified by TD-026 to survive a base-style reload is expected to continue working unchanged in principle; whether it requires any further adjustment to also cover the worldwide-layer composition is a Technical Design (TD-027) concern.

---

## Empty, Loading, and Error States

See [Loading and Failure Behavior](#loading-and-failure-behavior) for the states this milestone introduces. Beyond those:

- Maastokartta has no "empty" state specific to its worldwide underlay from the angler's perspective — MapTiler Outdoor either is visible (no MML content at the current view) or is not (MML content covers the current view), and both are normal, expected states, not error conditions. Ilmakuva has no equivalent coverage-dependent state at all — it is uniformly MapTiler Satellite Hybrid everywhere.
- If the persisted base-map preference is unreadable or corrupt, the existing MFS-026 fallback to the default (Maastokartta) applies unchanged; MapTiler Outdoor beneath that default continues to work exactly as it would for any other selection.

---

## Edge Cases

- Rapidly panning back and forth across the actual Finnish border must not cause visible flicker, repeated unstable switching, or an inconsistent state beyond ordinary map tile loading — under pixel-level masking ([FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence)) this holds by construction (there is no discrete included/excluded state to be unstable), not because of a tuned margin.
- Viewing the map at a low zoom level spanning both Finland and clearly non-Finnish territory must not show a large, irregular block of MML content extending into that non-Finnish territory (the original defect this milestone exists to fix) — MapTiler Outdoor must be what is shown there instead, and this must hold **regardless of where the viewport's center happens to sit**, including well inside Finland (the more specific defect [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence) was revised a third time to fix, after direct pixel-level evidence showed a viewport-level check alone — however tuned — could not).
- Zooming continuously in or out across the actual Finnish border being on screen, or in/out at any zoom while remaining inside Finland, must not produce a perceptible flicker, delay, or stutter distinct from ordinary tile loading, and must not produce any observable style reload or fishing-spot-marker re-flash — pixel-level masking involves no style regeneration at all for this reason.
- Switching between Maastokartta and Ilmakuva while a pan across Maastokartta's region boundary is still in flight must still leave the angler with a populated, navigable map, consistent with FR-4/FR-13.
- A first-ever launch with no network connection at all must still present Maastokartta as the intended default, with both MML Maastokartta and MapTiler Outdoor degrading per the "both unavailable" treatment (FR-17) rather than silently substituting a different default or crashing.
- Losing network connectivity mid-session, after tiles from either provider have already rendered successfully, must not remove already-rendered map imagery or application-owned content already on screen; it only affects imagery not yet loaded (e.g., a newly panned-to area), for each provider independently.
- Adding a fishing spot, or tapping an existing one, immediately after panning across Maastokartta's coverage boundary, immediately after a base-map switch, or while Ilmakuva's MapTiler Satellite Hybrid is unavailable, must succeed exactly as it does under normal conditions today.

---

## Accessibility Expectations

- No new interactive control is introduced by this milestone, so no new accessible label is required beyond what MFS-026 already established for the layers control and selector.
- Any new or extended attribution text remains legible, does not rely on color alone to be readable, and remains reachable via the platform's standard accessibility services, consistent with MFS-026's existing attribution treatment.
- The "map imagery unavailable" messaging introduced by this milestone's failure-handling rows follows the same non-technical, calm, accessible presentation convention MFS-026 already established for MML's own failure states.

---

## Feature Ownership and Placement

Following the existing feature-first structure and this project's architecture rules (ADR-0001, ADR-0002, ADR-0008, ADR-0009; `docs/development-rules.md`):

- No repository interface, DAO, service layer, or use-case layer is introduced, consistent with every prior milestone in this project.
- No new conceptual layering is introduced beyond what ADR-0008/ADR-0009 already establish (Maastokartta is understood as MML-plus-MapTiler-Outdoor-underlay; Ilmakuva is understood as MapTiler Satellite Hybrid directly; overlays and application-owned layers are unchanged conceptual bands).
- Exact implementation design — how each composition is technically built within MapLibre, where the corresponding code lives, the exact loading/failure-detection mechanism, and the exact attribution rendering mechanism — is a Technical Design (TD-027) concern, out of scope for this specification.

---

## Acceptance Criteria

1. On a cold launch with no previously saved base-map selection, Maastokartta is active by default (unchanged from MFS-026), with MapTiler Outdoor available as part of normal map presentation from that first load.
2. Viewing Finland with Maastokartta selected shows MML's Maastokartta cartography exactly as it does today, with no visible change.
3. Viewing Finland with Ilmakuva selected shows **MapTiler Satellite Hybrid**, not MML's Ortokuva imagery — a deliberate, intended change from MFS-026's previously shipped behavior.
4. Panning from Finland to Sweden, France, or another area clearly outside Maastokartta's Finland region, with Maastokartta selected, results in MapTiler Outdoor appearing automatically, with **no blank/empty map, no visible gray/white opaque block, no visible tile/coverage-boundary artifact**, and no user action required.
5. Panning to the same areas with Ilmakuva selected shows the same MapTiler Satellite Hybrid imagery as within Finland — no coverage-dependent change of any kind, since Ilmakuva has no boundary-dependent behavior.
6. Panning back from an area outside Maastokartta's Finland region into Finland, with Maastokartta selected, automatically restores MML Maastokartta's own content, with no manual action required and no visible artifact at the transition.
7. Panning slowly back and forth across the actual Finnish border (a small, incidental movement, not a deliberate large jump) does not cause repeated, visibly unstable switching of any kind — under pixel-level masking ([FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence)) there is no included/excluded state at the viewport level to switch between in the first place.
8. Viewing Maastokartta at low zoom, such that a large area including both Finland and clearly non-Finnish territory (e.g., Sweden, the Baltic region) is visible at once, shows MML content precisely within real Finnish/Åland coverage and MapTiler Outdoor elsewhere — no large, irregular, visibly-wrong block of MML content covering non-Finnish territory, and no gray/white opaque area of any kind, **at pixel-level precision**, even when the viewport's center itself is deep inside Finland (the specific defect direct pixel-level evidence traced to MML's own tiles, and that this milestone's final revision exists to fix — see [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence)).
9. Switching from Maastokartta to Ilmakuva, at any location, always visibly changes the rendered content to MapTiler Satellite Hybrid; switching back to Maastokartta restores MML Maastokartta (within its region) or MapTiler Outdoor (outside it) as appropriate.
10. Switching between Maastokartta and Ilmakuva while viewing an area outside Maastokartta's Finland region leaves the map populated and navigable throughout and after the switch — never a blank state at any point.
11. Switching between Maastokartta and Ilmakuva while viewing an area inside Maastokartta's Finland region continues to work correctly, with the MML-visible portion of the transition behaving exactly as already verified for MFS-026.
12. Fishing-spot markers and their labels remain visible and correctly positioned over every composition (MML Maastokartta, MapTiler Outdoor, and MapTiler Satellite Hybrid), including immediately after any base-map switch or automatic region-driven change.
13. Tapping an existing fishing-spot marker and creating a new fishing spot both continue to work correctly regardless of which composition is currently rendering.
14. The current-location control, other `MapScreen` entry points (Lure Tools, Statistics, Catch Search), and the existing MFS-026 selector's visual behavior are all unaffected by this milestone.
15. After a normal application restart, the previously selected base map (Maastokartta or Ilmakuva) is active again with no reselection required, rendering the composition appropriate to wherever the map's initial camera position places the viewport.
16. While Maastokartta is selected and MML is configured, required attribution for both MML and MapTiler is visible/reachable on-screen, without excessive visual clutter on a small mobile screen — regardless of viewport position, per [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence)'s simplified attribution condition.
17. ~~While Maastokartta is selected and the viewport is outside its Finland region, only MapTiler's attribution is visible/reachable on-screen, and MML's attribution is not shown.~~ **Superseded by [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence) — kept as a historical record.** MML's attribution no longer depends on viewport position.
18. While Ilmakuva is selected, required attribution for MapTiler is visible/reachable on-screen, and **MML's attribution is not shown**.
19. A simulated MapTiler Outdoor failure (unreachable/misconfigured) while Maastokartta is selected and MML is healthy and within its region leaves MML content fully visible and usable, does not crash the application, and shows no technical detail.
20. A simulated MML failure (network failure or missing/invalid configuration) while Maastokartta is selected and MapTiler Outdoor is healthy does not unnecessarily also remove MapTiler Outdoor's availability, does not crash the application, and shows no technical detail.
21. A simulated simultaneous failure of both Maastokartta providers does not crash the application, shows no technical detail from either provider, and presents the same calm, Finnish-language "map imagery unavailable" treatment already established by MFS-026, with application-owned map content remaining as usable as reasonably possible.
22. A simulated MapTiler Satellite Hybrid failure (unreachable/misconfigured) while Ilmakuva is selected does not crash the application, shows no technical detail, presents the same calm "map imagery unavailable" treatment, and leaves application-owned map content as usable as reasonably possible — with no MML fallback expected or shown.
23. A missing or invalid MapTiler credential does not crash the application in either selection, never exposes the credential or any technical/provider-specific detail, and presents the same calm, Finnish-language "map imagery unavailable" treatment for whichever composition it affects.
24. No manual country/provider switch, geofence prompt, or location-permission request tied to this feature exists anywhere in the application as a result of this milestone. (A Finland/Åland coverage geometry is not itself prohibited from *existing internally* — [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence) requires it to exist — but no *visible* boundary indicator is shown to the angler.)
25. The base-map selector still offers exactly two choices — Maastokartta and Ilmakuva — with no third, MapTiler-related option.
26. No hillshade-beyond-the-chosen-styles, offline-map, additional-global-provider, or other out-of-scope capability listed in [Out of Scope](#out-of-scope-1) is present; MML Ortokuva is confirmed absent from the Ilmakuva rendering path. (**Depth contours are intentionally present as of Revision 7/8** — the SYKE bathymetry overlay; this criterion predates that revision and is corrected here rather than left contradicting it.)
27. `flutter analyze` passes.
28. Automated tests cover: both compositions present alongside the default and a persisted base-map selection, the region/hysteresis pure logic (inside, outside, and dead-zone cases), continuity of fishing-spot markers/labels/tap/add across every composition, base-map switching both inside and outside Maastokartta's Finland region, per-composition attribution scoping (MML shown only when actually included), and the non-technical presentation of all failure scenarios in [Loading and Failure Behavior](#loading-and-failure-behavior) for both selections.
29. Physical Android testing is completed for this milestone, including: panning from within Finland to an area clearly outside the region and back with Maastokartta selected, with no visible artifact; slow back-and-forth panning near the region edge with no unstable switching; a low-zoom view spanning Finland and neighboring countries with no visibly-wrong MML block; and confirming Ilmakuva's uniform worldwide appearance both inside and outside Finland is unaffected by this revision.

**Added after further physical testing (second revision, [FR-23](#fr-23--zoom-gated-mml-inclusion-for-maastokartta-second-revision-after-physical-testing)) — all four items below superseded by the third revision ([FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence)); kept as a historical record, not current criteria:**

~~30. Zooming out with Maastokartta selected and the viewport centered well inside Finland still shows no large opaque gray/white block at any zoom level, via an activation threshold.~~
~~31. Zooming through MML's activation threshold produces a smooth transition with no marker re-flash.~~
~~32. MML's attribution tracks the activation threshold.~~
~~33. The activation zoom threshold and its determining physical test are recorded in TD-027 §3B.~~

**Added after direct pixel-level evidence (third revision, [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence)):**

30. Viewing Maastokartta at *any* zoom, with the viewport centered anywhere inside real Finnish/Åland coverage, shows no gray/white opaque block and no visible tile-boundary seam anywhere in the frame — verified directly against decoded MML tile pixels, not inferred from symptoms (ADR-0009 Revision Note 4).
31. At the actual Finnish border, both MML Maastokartta and MapTiler Outdoor are simultaneously visible, correctly, within the same single viewport — this is the specific outcome neither the original design nor either intermediate revision could reliably produce.
32. Zooming or panning across the actual Finnish border produces no observable style reload, no fishing-spot-marker re-flash, and no perceptible flicker or stutter beyond ordinary tile loading, at any zoom, in any direction, at any speed.
33. MML's attribution is visible whenever Maastokartta is selected and MML is configured, matching MapTiler's own attribution condition — not dependent on viewport position or zoom.
34. Panning to an area with no genuine Finnish/Åland coverage nearby (e.g. central Sweden, well away from the border) shows MapTiler Outdoor cleanly, with no residual MML artifact of any kind, confirming the masking correctly excludes non-Finnish territory and not merely correctly includes Finnish territory.
35. The coverage geometry used for masking, and any territorial-water buffering applied to it, are recorded in TD-027 §3C, along with the physical testing used to validate the border looks correct at the coastline and archipelago specifically (not only at the mainland land border) — this criterion is satisfied by that documentation and testing existing, not by specific numbers being hardcoded here.

---

## Out of Scope

- MapTiler as a third selectable base-map option
- Additional global map providers beyond MapTiler
- Any provider-selection UI (MapTiler is never user-selectable by name in this milestone, for either composition)
- Reintroducing MML Ortokuva into the Ilmakuva composition (a possible future milestone, not designed or scoped here)
- Depth contours
- Hillshade, beyond whatever is inherent in the MapTiler styles used
- Offline map downloads
- A custom offline tile-caching system
- Navigation/routing
- Map search
- Country or geofence detection based on device location or location permission (the viewport-position-based region check required by [FR-11](#fr-11--geographic-region-governs-mml-inclusion-for-maastokartta) operates purely on the map's own current camera position, never on the device's real-world location — see [FR-22](#fr-22--no-location-permission-or-country-determination-required))
- A precise, survey-grade Finland boundary, or any boundary maintained for purposes beyond deciding Maastokartta's MML-inclusion check (a simplified, approximate region is required by FR-11; a high-precision legal/administrative boundary is not)
- Backend/proxy infrastructure (per ADR-0009, the client connects to MapTiler directly, as it already does to MML)
- Any redesign of existing fishing-spot functionality (creation, editing, deletion, or statistics)
- Any redesign of the existing MFS-026 layers control or selector, beyond a small adjustment TD-027 determines is genuinely necessary to satisfy this milestone's attribution requirement
- MML vector maps (raster WMTS only, per ADR-0008, unchanged)
- Custom MapTiler vector styling, beyond whatever minimal configuration TD-027 finds is actually required to use the chosen existing MapTiler styles correctly
- Exact per-composition rendering mechanism, attribution widget design, and API-key injection mechanism (all TD-027/implementation concerns — see [Design Notes](#design-notes))

Future overlays such as depth contours and hillshade beyond what the chosen MapTiler styles already include remain acknowledged only as future extensions (see [Future Extensions](#future-extensions)); this milestone does not expand into that work.

---

## Architecture Constraints

Restated here from ADR-0008 and ADR-0009, as binding constraints on Technical Design, not merely aspirational:

- MapLibre GL remains the rendering technology (ADR-0002); this milestone does not change it.
- MML raster WMTS remains the delivery format and data source for Maastokartta (ADR-0008), unchanged by this milestone — **as of Revision 4 (ADR-0009 Revision Note 4), the client fetches it through a small on-device process rather than directly, so its own pixels can be masked to real coverage before rendering; this is not a change of provider, format, or data source, only of how the client-side rendering step consumes it.**
- MapTiler is the provider for Maastokartta's worldwide underlay (Outdoor) and for Ilmakuva's complete worldwide base map (Satellite Hybrid), delivered as MapTiler raster tiles via direct client-to-MapTiler HTTPS, with no backend/proxy introduced solely to hide its API key (ADR-0009). MapTiler's own delivery path is completely unaffected by Maastokartta's MML masking process — the two remain independent.
- MapTiler API credentials must never be committed to source control (ADR-0009), exactly like the existing MML credential requirement (ADR-0008); one MapTiler credential covers both roles. **The MML credential must never appear in the on-device style document, any local URL, log output, cache filenames, or error message (ADR-0009 Revision Note 4, TD-027 §3C) — a stricter, explicit requirement made necessary by the new on-device fetching step existing at all.**
- ~~Revised after physical testing (ADR-0009 Revision Note 2): Maastokartta's inclusion of MML is now governed by an explicit, application-owned approximate Finland region (with hysteresis), evaluated against the viewport.~~ **Superseded by Revision 4 — kept as a historical record.**
- ~~Revised again after further physical testing (ADR-0009 Revision Note 3): Maastokartta's inclusion of MML additionally requires the camera zoom to be at or above an activation threshold.~~ **Superseded by Revision 4 — kept as a historical record.**
- **Revised a third time, after direct pixel-level evidence (ADR-0009 Revision Note 4):** Maastokartta's MML raster source is unconditionally present whenever configured (like MapTiler Outdoor); correctness is enforced by an entirely on-device, loopback-only process that makes MML's own out-of-coverage pixels transparent per tile, using the Finland/Åland coverage geometry as its input. This process is not backend/proxy infrastructure in the sense this document's Out of Scope otherwise prohibits (ADR-0009 Revision Note 4). It introduces no style regeneration and needs no hysteresis or zoom-threshold mechanism, since there is no discrete per-viewport state left to stabilize. Ilmakuva is unaffected.
- MML and MapTiler Outdoor must be able to fail independently at the architecture level for Maastokartta — a failure of one must not unnecessarily destroy usable coverage from the other (ADR-0009). Ilmakuva has only one provider (MapTiler Satellite Hybrid) and therefore no second provider to be independent of; application-owned content must still remain as usable as reasonably possible if it fails.
- No new database table, column, or schema version is assumed by this specification; if Technical Design determines one is needed, that is its decision to make and justify, not a requirement imposed here.

---

## Relationship to Previous MFS Documents and ADRs

- **MFS-026 (Selectable MML Base Maps)** introduced the two selectable MML base maps, their selector, their persistence mechanism, and the fishing-spot-marker-restoration-across-style-reload fix this milestone must not regress. This milestone changes what each selection renders (Maastokartta additively; Ilmakuva by replacing MML Ortokuva with MapTiler Satellite Hybrid in this milestone) without touching the selector or persistence mechanism themselves.
- **ADR-0002 (Map Technology)** selected MapLibre GL; unchanged here.
- **ADR-0008 (Base Map Provider and Delivery)** established MML as the Finnish base-map provider and the base map / overlay / application-owned-layers conceptual model this milestone's layering builds on, and explicitly deferred "non-Finland/global base-map coverage" to a future ADR.
- **ADR-0009 (Global Base Map Coverage and Fallback)** is that future ADR, since revised: it selected MapTiler as the worldwide provider for both a Maastokartta underlay role (Outdoor) and a complete Ilmakuva base-map role (Satellite Hybrid), decided direct-to-MapTiler delivery with no proxy via MapTiler's raster tile endpoint, and established (experimentally) the MML transparent-no-data-tile behavior Maastokartta's automatic fallback is built on. This specification turns that architectural decision into a concrete, user-facing feature; it does not revisit or repeat ADR-0009's own reasoning.

---

## Dependencies

- Flutter, Dart, `maplibre_gl` — all already in use (ADR-0002).
- MML raster WMTS as the Finnish base-map data source (ADR-0008); unchanged by this milestone.
- MapTiler as the worldwide base-map data source (ADR-0009); a new external service and a new API credential, additional to the existing MML credential.
- The existing MFS-026/TD-026 base-map selector, persistence mechanism, and fishing-spot-marker-restoration mechanism, which this milestone builds on rather than replaces.
- No repository interface, DAO, service layer, or use-case layer is introduced, consistent with `docs/development-rules.md`.
- **Revision 7:** SYKE's "Järvien ja jokien syvyysaineisto" (INSPIRE `EL.ContourLine`, `EL.Syvyysalue`; `EL.SpotElevation` deferred), CC BY 4.0 — a bundled, preprocessed dataset (TD-027 §20/§21), not a live runtime dependency. `MmlVectorPocStyleFetcher` and its fixture test, already present in the working tree as a temporary PoC, are the starting point for MML v21 vector's production integration (TD-027 §25).

---

## Future Extensions

This milestone is expected to support, in later milestones, if real usage demonstrates the need:

- Overlay layers such as hillshade and depth contours, built on top of the base-map/overlay/application-owned-layers conceptual model (ADR-0008/ADR-0009). Neither is designed or scoped here, and this milestone deliberately does not expand into that work.
- Reintroducing MML Ortokuva into the Ilmakuva composition (e.g. layered above MapTiler Satellite Hybrid within Finland only, mirroring Maastokartta's own underlay model) — explicitly named as a possible future direction by ADR-0009, not designed or scoped here.
- Additional global map providers or worldwide styles, if a real need beyond MapTiler Outdoor/Satellite Hybrid emerges.
- Offline map storage, already named as a future direction by MFS-001 and explicitly deferred by ADR-0002, ADR-0008, and ADR-0009.
- A richer attribution or map-info presentation, if the per-selection attribution requirements ever need more than a compact, non-cluttering treatment.

---

## Design Notes

This section records the open judgment calls this specification surfaces explicitly rather than resolving unilaterally, following the same discipline established by MFS-026's own Design Notes section (and, before it, MFS-022/MFS-024/MFS-025).

**Maastokartta's MML-inclusion mechanism — Resolved, superseding an earlier version of this specification, following physical Android testing.** An earlier version of FR-11 required that MML's inclusion rely solely on MML's own transparent no-data tile behavior, with no Finland boundary/polygon/mask/geofence logic of any kind. Physical Android testing subsequently found this unreliable at broader geographic scale (opaque gray/white blocks, visible tile/coverage-boundary artifacts, particularly visible at low zoom near Sweden and the Baltic region) — see ADR-0009's Revision Note 2 for the full account. FR-11 now requires the opposite: an explicit, application-owned approximate Finland region (with hysteresis) must govern MML's inclusion, replacing reliance on MML's own edge behavior. This is a genuine, acknowledged reversal, not a refinement — recorded here so it is not mistaken for the original design. The exact geographic definition (polygon vertex source, simplification tolerance) and the exact hysteresis margin are left to TD-027/implementation, to be tuned against real observed behavior; this specification only establishes that a rectangular bounding box is known to be insufficient (Finland's elongated, irregular shape means any single rectangle tight enough to include all of it also includes large areas of Sweden, Norway, and the Baltic Sea — the very regions the bug was found in).

**Two compositions, not one shared worldwide layer — Resolved (supersedes this milestone's earlier design).** An earlier version of this specification used exactly one worldwide MapTiler style beneath either MML selection, with an explicit "Ilmakuva does not imply worldwide satellite imagery" decision. That has been replaced by a subsequent product decision: Maastokartta keeps the MapTiler-Outdoor-underlay model; Ilmakuva becomes MapTiler Satellite Hybrid directly, worldwide, including within Finland, with MML Ortokuva unused in this milestone. See ADR-0009's Decision and Consequences sections for the full reasoning and accepted trade-offs (in particular, Ilmakuva's rendering now changes within Finland too, and Ilmakuva loses the dual-provider failure independence Maastokartta retains).

**MapTiler attribution timing — Resolved.** MapTiler's attribution is shown continuously whenever MapTiler is part of the currently selected composition, with no viewport/coverage detection used to decide whether it should appear. For Maastokartta this is alongside MML's attribution; for Ilmakuva this is MapTiler's attribution alone, with MML's attribution suppressed. FR-21 and [Attribution](#attribution) are read accordingly. See TD-027 §11 for the compact, tap-to-expand presentation design that satisfies this without permanent visual clutter.

**MML failure inside Finland (Maastokartta) — Resolved.** If MML fails while MapTiler Outdoor remains available, the functioning MapTiler Outdoor map remains visible and usable; the application must not replace it with a blank or full-view MML-specific error state. FR-16 is read accordingly. See TD-027 §3/§9 for why this holds by construction (MapTiler's layer is never hidden in response to MML's condition) rather than through new detection/fallback code.

**Worldwide map style/schema — Resolved.** MapTiler Outdoor (style identifier `outdoor-v4`) is used for Maastokartta's worldwide underlay; MapTiler Satellite Hybrid (style identifier `hybrid-v4`) is used directly as Ilmakuva's complete worldwide base map — both verified against current official MapTiler documentation. No custom MapTiler style is created for this milestone. See TD-027 §0/§3.

**Zoom-range reconciliation — Resolved.** MapTiler and MML are not forced to share one artificial zoom range. MML retains its verified WMTS 0–18 range; MapTiler Outdoor and Satellite Hybrid each use whatever native range their own raster tile endpoints support; existing MapLibre overscaling behavior beyond any source's stated maximum continues exactly as it already does for MML today. FR-6 is read accordingly. See TD-027 §0/§14 for the remaining pre-implementation verification item this leaves (neither MapTiler product's exact native maximum zoom was pinned to a specific number and must be confirmed live before implementation finalizes it).

**Whether the existing MFS-026 selector needs any adjustment at all is not assumed here.** This specification's default expectation is that no adjustment is needed; Out of Scope explicitly limits any change to a "small adjustment TD-027 determines is genuinely necessary" for the attribution requirement specifically, not a general redesign license. TD-027 confirms no change to the selector itself is needed; a new, separate attribution widget is added alongside it instead.

~~**Maastokartta's zoom-gated MML inclusion — mechanism resolved, exact threshold pending physical verification (second revision after physical testing).**~~ **Superseded — kept as a historical record of the second revision's approach, not the current design; see the note immediately below.**

**Maastokartta's MML inclusion — resolved a third time, by direct pixel-level evidence, superseding both the region-check (Revision 2) and zoom-threshold (Revision 3) mechanisms above.** Both prior mechanisms decided, at the level of the whole viewport, whether MML belonged in the composition — the region check by position, the zoom threshold by how much area the viewport covered. Real MML WMTS tiles were decoded and inspected directly (not merely observed as symptoms): out-of-coverage areas are rendered fully opaque by MML's own server, never transparent, confirmed both by the absence of any PNG transparency chunk and by 100% opaque pixel counts across representative tiles including a Finland/Russia border tile that was measured at 69.81% flat, textureless gray corresponding exactly to Russian territory. **No viewport-level decision, however precisely tuned, can make already-opaque pixels transparent** — this is what finally explains why Revision 2 and Revision 3 each fixed a real, observed symptom without fixing the underlying defect. [FR-24](#fr-24--pixel-level-mml-coverage-masking-for-maastokartta-third-revision-after-physical-evidence) resolves this by making MML's own pixels transparent outside real coverage *before* MapLibre ever receives them, via a process that runs entirely on the angler's own device. Native MapLibre/GPU-level alternatives (a style-level color-key or clip mechanism, a custom shader, a forked renderer) were investigated first and rejected — none exist in MapLibre's style specification, and the one native escape hatch found (`CustomLayer` on Android) is documented by its own maintainers as experimental and not to be used. See ADR-0009's Revision Note 4 and TD-027 §3C for the complete evidence, the alternatives considered, and the resulting design.

**Ilmakuva's image quality/resolution within Finland compared to MML Ortokuva is not verified here.** MML Ortokuva is Finland-specific, high-resolution aerial photography; MapTiler Satellite Hybrid's imagery quality varies by region and has not been confirmed to match it over Finland specifically. This is recorded as an open verification item, not resolved by this specification — see TD-027's Risks for the corresponding recommendation to check this before shipping.

**Revision 7 — SYKE bathymetry shown over both Maastokartta and Ilmakuva — Resolved, recorded as a deliberate but reversible product decision.** The overlay/base-map model (ADR-0008) treats overlays as orthogonal to base-map selection, and depth is equally relevant whether the angler is looking at topographic or aerial imagery — a fishing decision does not change based on which base map happens to be active. No requirement in this milestone restricts the bathymetry overlay to Maastokartta only. If real usage shows this is visually cluttered over Ilmakuva specifically (e.g. contour lines competing with satellite imagery detail), restricting it to Maastokartta only is a small, contained follow-up, not a redesign.

**Revision 7 — MML v21 vector's own out-of-coverage behavior is asserted, not yet proven, at the scale this project's own discipline requires.** Revisions 2–6 of this same milestone exist entirely because an analogous assumption about MML's *raster* behavior ("out-of-coverage tiles are transparent") was disproved by physical testing at broader geographic scale, despite passing narrow spot-checks. This specification does not repeat that mistake for the vector path: FR-26 explicitly requires direct verification (TD-027 §3F) before the "vector tiles are naturally empty outside coverage, no masking needed" claim is treated as settled. This is a border/coverage-edge concern, not a bathymetry-coverage concern, so it is verified by **re-running the existing Revisions 4–6 border-crossing physical checklist (Imatra, Nuijamaa, Vaalimaa, Åland/Föglö — TD-027 §12) against the vector path**, not by the four-lake bathymetry table above (which verifies SYKE data presence/absence, a separate concern from Finland/non-Finland border rendering).
