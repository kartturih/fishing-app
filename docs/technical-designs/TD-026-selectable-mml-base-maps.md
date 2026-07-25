# TD-026 — Selectable MML Base Maps

## Status

Draft — not yet implemented. Designs MFS-026's approved MVP scope. **All WMTS service-mechanics verification is now complete** — the values in [§0](#0-pre-implementation-verification-completed) were confirmed directly against MML's live `WMTSCapabilities.xml`, retrieved using the user's own API key, and cross-checked against separate official MML documentation for the two items (the API-key request parameter and the CC BY 4.0 attribution requirement) a capabilities document does not itself cover. The only items still open are two narrow, non-WMTS `maplibre_gl` plugin-API questions (§0), which do not block writing `MmlStyleFactory`/`BaseMapPreferenceStore`/`MmlConfig` as designed — only the small fallback path noted in [§3](#3-mml-wmts-integration) if one of them resolves unfavorably. This document is implementation-ready.

## Related

- Implements: MFS-026 — Selectable MML Base Maps (the approved specification this document designs)
- Authoritative, not reconsidered here: ADR-0008 — Base Map Provider and Delivery (MML raster WMTS, direct-to-MML HTTPS, no proxy, credential-never-committed, base map/overlay/application-owned-layers layering model); ADR-0002 — Map Technology (MapLibre GL)
- Depends on: MFS-001 — Map Feature (`MapScreen`, the `MapLibreMap` widget this document reconfigures)
- Depends on: MFS-002 — Map Controls (`MapControls`, the existing bottom-right floating-control convention this document's upper-right layers control sits alongside without modifying)
- Depends on: MFS-004 — Fishing Spot Foundation (the GeoJSON-backed fishing-spot marker/label rendering this document must make resilient to a base-style reload)
- Sibling precedent: `lib/core/location/location_service.dart` — the established "plain concrete class under `core/`, no interface" pattern this document's new `core/map/` types follow
- Sibling precedent: `LureCatalogListPage`'s `_requestId` stale-response guard, and TD-025's `CatchSearchPageState` debounce/generation handling — the established stale-async-guard idiom this document reuses for style-load races (see [§5](#5-maplibre-style-lifecycle--the-fix)/[§6](#6-base-map-switching-mechanism))
- Sibling precedent: `Catches.species` storing `FishSpecies.name` directly (TD-025 Current State) — the established "persist the enum's own name string" convention this document's `BaseMap` persistence follows

---

## Goal

Implement MFS-026: replace `MapScreen`'s hardcoded MapLibre demo style with two selectable MML raster WMTS base maps (Maastokartta, Ilmakuva), reachable from a new upper-right floating layers control with a compact anchored selector; persist the selection across restarts; keep every existing map capability (fishing-spot markers/labels/tap/add, location controls, other `MapScreen` entry points) working across a base-map switch with no need to leave and reopen the Map screen; and handle loading/failure/attribution per MFS-026's requirements — entirely within ADR-0008's established architecture (MapLibre GL, MML raster WMTS, direct client-to-MML HTTPS, no proxy).

The implementation shall satisfy MFS-026.

---

## 0. Pre-Implementation Verification (completed)

ADR-0008 and MFS-026 are authoritative for *why* MML raster WMTS was chosen; this section fixes the literal technical values a raster tile source needs. All WMTS service-mechanics values below were verified by directly inspecting MML's own live `WMTSCapabilities.xml` (open interface, `https://avoin-karttakuva.maanmittauslaitos.fi/avoin/wmts/1.0.0/WMTSCapabilities.xml`), retrieved using the user's own valid API key. No value below was inferred, guessed, or taken from a secondary/third-party source. Two items a capabilities document does not itself cover (the API-key request parameter; the CC BY 4.0 attribution requirement) were separately confirmed against other official MML documentation — clearly labeled as such, not presented as GetCapabilities findings.

### Confirmed from live GetCapabilities (`WMTSCapabilities.xml`)

| Value | Confirmed value | XML evidence |
|---|---|---|
| Layer identifier — Maastokartta | `maastokartta` | `<Layer><ows:Identifier>maastokartta</ows:Identifier>` |
| Layer identifier — Ortokuva/Ilmakuva | `ortokuva` | `<Layer><ows:Identifier>ortokuva</ows:Identifier>` (MFS-026's user-facing "Ilmakuva" and ADR-0008's "Ortokuva" name this same MML layer — see MFS-026 Conceptual Model) |
| Advertised format — Maastokartta | `image/png` | `<Layer>...<ows:Identifier>maastokartta</ows:Identifier>...<Format>image/png</Format>` |
| Advertised format — Ortokuva | `image/jpeg` | `<Layer>...<ows:Identifier>ortokuva</ows:Identifier>...<Format>image/jpeg</Format>` |
| TileMatrixSet links, both layers | `ETRS-TM35FIN` and `WGS84_Pseudo-Mercator` | Each `<Layer>` carries two `<TileMatrixSetLink><TileMatrixSet>...</TileMatrixSet></TileMatrixSetLink>` entries, one per matrix set, with no `TileMatrixSetLimits` narrowing either. |
| Exact Web Mercator TileMatrixSet identifier | **`WGS84_Pseudo-Mercator`** (underscore, hyphen — exactly as already used for the `_matrixSet` constant in [§3](#3-mml-wmts-integration)) | `<TileMatrixSet><ows:Identifier>WGS84_Pseudo-Mercator</ows:Identifier>` |
| Exact TileMatrix identifiers in that set | Plain integers `0` through `18` (19 levels), no prefix | 19 `<TileMatrix><ows:Identifier>N</ows:Identifier>` entries, `N` = `0`…`18` |
| Zoom/matrix range through the open service | **0–18, identical for both layers** | Both layers' `TileMatrixSetLink` to `WGS84_Pseudo-Mercator` carries no per-layer `TileMatrixSetLimits`, so both get the full 0–18 range the shared `<TileMatrixSet>` block defines. |
| TileWidth / TileHeight | `256` / `256`, at every level 0–18, both layers | `<TileMatrix><TileWidth>256</TileWidth><TileHeight>256</TileHeight>` (identical at every level) |
| TopLeftCorner | `-20037508.342789 20037508.342789` at every level | `<TileMatrix><TopLeftCorner>-20037508.342789 20037508.342789</TopLeftCorner>` — the standard full-world Web Mercator northwest corner |
| MatrixWidth/MatrixHeight pattern | `2^z × 2^z` per level (`1,1` at z=0 … `262144,262144` at z=18) | `<MatrixWidth>`/`<MatrixHeight>` double at every successive `<TileMatrix>` |
| Tiling scheme | **Standard XYZ — no Y-axis inversion needed** | `ows:BoundingBox` is the canonical full Web Mercator extent (±20037508.342789) and `TopLeftCorner` is the northwest corner with a standard doubling pyramid — bit-for-bit the same addressing convention MapLibre's default raster `scheme: "xyz"` already assumes. **Do not set `"scheme": "tms"`.** |
| Exact `ResourceURL` template — Maastokartta | `.../maastokartta/default/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.png` (`format="image/png"`) | `<ResourceURL format="image/png" resourceType="tile" template="https://avoin-karttakuva.maanmittauslaitos.fi/avoin/wmts/1.0.0/maastokartta/default/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.png"/>` |
| Exact `ResourceURL` template — Ortokuva | `.../ortokuva/default/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.jpg` (`format="image/jpeg"`) | `<ResourceURL format="image/jpeg" resourceType="tile" template="https://avoin-karttakuva.maanmittauslaitos.fi/avoin/wmts/1.0.0/ortokuva/default/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.jpg"/>` |
| TileMatrix/TileRow/TileCol token order | **`{TileMatrix}/{TileRow}/{TileCol}` — TileRow before TileCol** | Read directly from both `ResourceURL` templates above. This is the *opposite* of the generic OGC-default order (`{TileMatrix}/{TileCol}/{TileRow}`) this document originally assumed. |
| MapLibre raster tile template mapping | **`{TileMatrix}` → `{z}`, `{TileRow}` → `{y}`, `{TileCol}` → `{x}` — i.e. the MapLibre template must read `{z}/{y}/{x}`, not `{z}/{x}/{y}`** | Direct consequence of the confirmed token order plus the confirmed standard-XYZ scheme (row = MapLibre's `y`, column = MapLibre's `x`, no inversion). |
| File extension / content type | Maastokartta: `.png` / `image/png`. Ortokuva: `.jpg` / `image/jpeg` | Confirmed twice over — the `<Format>` element and the `ResourceURL`'s own `format=` attribute agree for each layer. |
| Layer-to-layer difference relevant to implementation | Format/extension only (`png` vs. `jpg`) — zoom range, tile size, matrix set, and scheme are identical | Direct comparison of the two `<Layer>` blocks. |

### Confirmed from other official MML documentation (not from GetCapabilities)

A capabilities document does not describe *how* to authenticate a request or state licensing terms — both were confirmed separately, directly from MML's own official pages, and are labeled as such rather than presented as capabilities findings:

| Value | Confirmed value | Source |
|---|---|---|
| API-key request parameter name | Query-string parameter **`api-key`** (e.g. `?api-key=<key>`); MML also documents HTTP Basic Authentication (API key as username, empty password) as an alternative mechanism | MML's official "Instructions for using the API key" page — a separate document from `WMTSCapabilities.xml`, which does not itself describe authentication mechanics beyond stating (`ows:AccessConstraints`: `"Vaatii käyttäjätunnuksen"`) that a credential is required. |
| CC BY 4.0 attribution requirement | Three required elements — the licensor's name (Maanmittauslaitos), the dataset's name, and the period MML supplied the dataset — **not one fixed universal sentence**. MML's own example: *"sisältää Maanmittauslaitoksen Maastotietokannan 06/2014 aineistoa"* | MML's official CC BY 4.0 license page (`maanmittauslaitos.fi/avoindata-lisenssi-cc40`). See [§2](#2-base-map-model) for how this document turns those three required elements into a concrete, practical string per base map. |
| Open-interface service-level guarantee | The open WMTS interface is "freely usable, but not intended for use by high-volume services," with **no guaranteed capacity, availability, or user support** | MML's official Map Image Service (WMS/WMTS/Vector Tiles) overview page — directly relevant to ADR-0008's own anticipated "large-scale production usage may later require reassessing MML's service tier" (see [§14 Risks](#14-risks-and-mitigations)). |

### Still open — not WMTS mechanics, unrelated to GetCapabilities

| Value | Status | Detail |
|---|---|---|
| `maplibre_gl` inline-JSON `styleString` support | **Moderate confidence — confirm against installed 0.26.2 API/source** | This design's primary approach ([§3](#3-mml-wmts-integration)) assumes `MapLibreMap.styleString` accepts a raw JSON-encoded style string directly (not only a URL or a bundled-asset path) — consistent with the behavior of the wider Mapbox-GL-Flutter-derived plugin family this package descends from. **Confirm this against the installed `maplibre_gl: ^0.26.2` source/docs before implementation.** If unsupported, [§3](#3-mml-wmts-integration) documents a fallback (a generated style file written to the application's temporary directory and referenced by path). This is a Flutter-plugin-API question, not a WMTS-service question — it cannot be answered by MML's capabilities document. |
| `maplibre_gl` explicit style-load-error callback | **Not found — assume none available** | No explicit "style failed to load" callback was confirmed for this package version. [§9](#9-loading-and-failure-behavior) designs failure detection around a bounded timeout instead of assuming such a callback exists, so the design does not depend on this being confirmed either way — but confirm during implementation in case a more precise signal is actually available. Also a plugin-API question, not a WMTS-service question. |

**Sources consulted:** MML's live `WMTSCapabilities.xml` (open interface), retrieved and inspected directly using the user's own API key — the credential was used only to authenticate the retrieval and was never printed, logged, persisted, or written into this document or any repository file. MML's official "Instructions for using the API key" page and official CC BY 4.0 license page (`avoindata-lisenssi-cc40`), for the two items above that GetCapabilities does not itself cover. No third-party or secondary source was used for any value in the two tables above.

---

## Fixed Architectural Decisions (not reconsidered here)

Restated from ADR-0008 and MFS-026 — binding constraints, not open questions:

- MapLibre GL remains the renderer (ADR-0002); no change to the rendering technology.
- MML raster WMTS, not vector tiles, for Maastokartta and Ilmakuva/Ortokuva (ADR-0008) — this document does not build or evaluate a vector style.
- Direct client-to-MML HTTPS; no backend/proxy is introduced (ADR-0008/MFS-026).
- MML API credentials must never be committed to source control (ADR-0008/MFS-026).
- Exactly one base map active at a time; overlays and their UI are explicitly future work, not designed or stubbed with real functionality here (ADR-0008/MFS-026).
- Maastokartta is the default for a user with no saved preference (MFS-026 FR-2).
- No depth contours, hillshade, offline maps, offline tile caching, additional base-map providers, MML vector maps, custom Fishing App vector styling, or any of MFS-026's other explicitly out-of-scope items.
- No repository interface, DAO, service layer, or use-case layer — concrete classes only, per `docs/development-rules.md` and every prior TD in this project.
- No generalized map-provider/plugin architecture for hypothetical future providers (MFS-026/task brief) — `BaseMap` models exactly two known values, not an extensible provider registry.
- No Riverpod/Bloc/state-management migration and no unrelated `MapScreen` refactoring — this document changes only what MFS-026 requires.

---

## Constraint Compliance Summary

| Constraint (ADR-0008 / MFS-026 / task brief) | How this design satisfies it |
|---|---|
| MapLibre GL unchanged | No new rendering technology; all changes are to `styleString` content and `MapScreen`'s own lifecycle handling. |
| MML raster WMTS only | The style JSON built in [§3](#3-mml-wmts-integration) contains exactly one `raster` source per base map; no vector source, no vector style. |
| Direct-to-MML, no proxy | Tile URL templates point directly at `avoin-karttakuva.maanmittauslaitos.fi`; no intermediary service is introduced. |
| Credential never committed | API key is supplied only via `--dart-define` at build time ([§8](#8-mml-api-key-configuration)); no key value appears anywhere in source, tests, fixtures, or this document. |
| Application-owned layers survive every base-style reload | [§5](#5-maplibre-style-lifecycle--the-fix) replaces the one-shot `_fishingSpotMarkersAdded` guard with a generation-aware guard that re-triggers on every genuine style change. |
| No requirement to leave/reopen `MapScreen` | The switch is implemented entirely by changing the `styleString` value passed into the already-mounted `MapLibreMap` widget ([§6](#6-base-map-switching-mechanism)) — no navigation, no widget recreation. |
| Persistence, mechanism unspecified by MFS-026 | A new, minimal `shared_preferences`-backed `BaseMapPreferenceStore` is introduced and justified in [§4](#4-persistence). |
| No generalized provider architecture | `BaseMap` is a two-value enum with no plugin/registry abstraction ([§2](#2-base-map-model)). |
| No two live MapLibre instances for previews | The selector uses static bundled preview images, never a second map widget ([§7](#7-selector-ux-implementation)). |
| No disruptive dialogs for transient tile failures | Individual tile failures are handled entirely inside MapLibre GL Native's raster rendering (already true today); only two coarser, app-detectable conditions surface a lightweight, non-blocking message ([§9](#9-loading-and-failure-behavior)). |
| No schema/migration impact assumed | Confirmed not needed — see [§4](#4-persistence); `AppDatabase.schemaVersion` stays at `8`. |

---

## Current State

Inspected directly in the current codebase before designing this change:

| Area | Current shape |
|---|---|
| `MapScreen` ([map_screen.dart](../../lib/features/map/presentation/map_screen.dart)) | `StatefulWidget`; `_MapScreenState` holds `AppDatabase` and every feature repository as `late final` fields, constructed directly (no DI/Riverpod). `build()` returns one `Scaffold` with an AppBar (3 icon buttons: Lure Tools, Statistics, Catch Search) and a `body: Stack([MapLibreMap(...), if (_isSelectionMode) a crosshair overlay, MapControls(...)])`. |
| `MapLibreMap` construction | `initialCameraPosition` fixed to Finland; `styleString: 'https://demotiles.maplibre.org/style.json'` — a hardcoded literal, the value this document replaces. `onMapCreated` stores the controller and registers `controller.onFeatureTapped.add(_onFishingSpotFeatureTapped)` **once**, at controller-creation time — not tied to style load. `onStyleLoadedCallback: _addFishingSpotMarkers`. |
| Fishing-spot marker lifecycle | `_addFishingSpotMarkers()` loads all spots, builds a GeoJSON `FeatureCollection`, and calls `controller.addGeoJsonSource(_fishingSpotsSourceId, ...)` + two `controller.addLayer(...)` calls (a `CircleLayerProperties` layer and a `SymbolLayerProperties` layer), **guarded by `bool _fishingSpotMarkersAdded`, set to `true` once and never reset.** This is the documented bug this TD must fix (ADR-0008, MFS-026 Conceptual Model). |
| Marker update paths | `_addFishingSpotFeature()`/`_renameFishingSpot()`/`_deleteFishingSpot()` all call `controller.setGeoJsonSource(_fishingSpotsSourceId, ...)` or `controller.setGeoJsonFeature(...)` directly against the fixed source id — valid only while that source currently exists in the active style. |
| `MapControls` ([map_controls.dart](../../lib/features/map/presentation/widgets/map_controls.dart)) | Stateless, bottom-right, `SafeArea` + `Align(Alignment.bottomRight)`. Default mode: settings FAB (`onPressed: () {}`, a documented no-op placeholder), add-fishing-spot FAB, current-location FAB. Selection mode: cancel/confirm FABs. Callback-driven; no repository/service access of its own. |
| MFS-002's stated intent for the settings FAB | "The settings button will later: Open map settings, Select map style, Configure overlays, Manage offline maps" (MFS-002 Future Extensions) — written before MFS-026 existed, and before MFS-026 fixed the new control's location as upper-right with a *layers* icon, distinct from this existing bottom-right gear icon. See [§10](#10-existing-mapcontrols-decision). |
| Dependencies (`pubspec.yaml`) | `maplibre_gl: ^0.26.2`, `drift`/`drift_flutter`, `geolocator`, `image_picker`, `path_provider`, `path`, `image`, `uuid`, `flutter_riverpod` (present but, per TD-025's own audit, used nowhere except wrapping `main.dart`), `go_router`. **No local key-value preference package** (no `shared_preferences` or equivalent) exists today. **No `--dart-define`/`String.fromEnvironment` usage** exists anywhere in the codebase — this document introduces the project's first build-time configuration convention. |
| Assets (`pubspec.yaml`) | One existing assets folder, `assets/lure_catalog/` (4 placeholder PNGs, bundled via a plain `assets:` list entry) — the precedent this document's `assets/map/` preview images follow. |
| `AppDatabase` ([app_database.dart](../../lib/core/database/app_database.dart)) | `schemaVersion == 8`. All 7 existing tables are relational, feature-owned domain data (fishing spots, catches, photos, lure catalog, tackle box, water bodies) — no existing precedent for a single scalar UI preference living in Drift. |
| `core/` today ([app-structure.md](../../docs/app-structure.md)) | Contains only `core/database/` and `core/location/`. `app-structure.md` explicitly anticipates a future `core/map` ("Map configuration") responsibility that does not exist yet — this document is the first to populate it. `LocationService` ([location_service.dart](../../lib/core/location/location_service.dart)) is the existing precedent for a `core/`-level type: a plain `const` concrete class, no interface, no DI container. |
| Existing `_isSelectionMode`/toggle-boolean precedent | `_MapScreenState` already holds `bool _isSelectionMode` and toggles it via `setState` to switch which `MapControls` button set is shown — the exact pattern this document's `_layersPanelOpen` boolean follows for the new selector. |
| Test conventions ([map_screen_test.dart](../../test/features/map/presentation/map_screen_test.dart)) | The only existing `MapScreen` test file. Its own header comment documents that `MapLibreMap` embeds a platform view that never settles in this headless test environment, so every test uses bounded `tester.pump(Duration(...))` calls, never `pumpAndSettle()`. This document's own `MapScreen`-level tests must follow the same convention (see [§11](#11-testing-strategy)). |
| Stale-async-guard precedent | `LureCatalogListPage`'s `_requestId` increment-and-compare guard (documented in TD-025's Current State) is the established idiom for "a slow async operation must not act on stale state" in this codebase — reused here as `_styleGeneration` (see [§5](#5-maplibre-style-lifecycle--the-fix)). |

---

## Key Design Decisions

**1. The base-map style is a small, locally-built raster style JSON per selection — not a fetched remote `style.json`, and not two hand-authored static style files.** ADR-0008 already decided raster over vector specifically to use MML's own rendered cartography rather than build a vector style; this decision is about *how the raster style document itself is produced*. Two candidates were considered: (a) hosting/fetching a pre-built `style.json` per base map from somewhere, or (b) constructing the (very small — one source, one layer, one attribution string) style JSON directly in Dart at the moment it is needed. (b) is chosen: it needs no external hosting, it lets the MML API key be injected into the tile URL template at runtime without a network round trip just to fetch a style document, and the style itself is genuinely tiny (a single raster source/layer, unlike a full vector style with dozens of layers) — building it locally is the smaller, not the larger, option here. See [§3](#3-mml-wmts-integration).

**2. Only the `WGS84_Pseudo-Mercator`-aligned MML matrix set is used — never `ETRS-TM35FIN`/`ETRS-GK`.** MapLibre GL's raster source model assumes standard Web Mercator (EPSG:3857) tile addressing (zoom/column/row, whatever token names are used to write the URL template); MML's native `ETRS-TM35FIN`/`ETRS-GK` matrix sets use a different grid entirely and are not directly consumable by a MapLibre raster source without a reprojection step this project has no reason to build. MML's `WGS84_Pseudo-Mercator` matrix set exists specifically so external web/mobile map tools can consume MML data without that step, and is confirmed by the live capabilities XML to use the same standard Web Mercator extent, top-left origin, and doubling tile pyramid MapLibre's default XYZ scheme already assumes ([§0](#0-pre-implementation-verification-completed)) — the correct, and only sensible, choice here.

**3. Switching base maps changes the `styleString` value passed to the already-mounted `MapLibreMap` widget — no navigation, no widget recreation, no second `MapScreen` instance.** MapLibre GL Native already reloads the active style (destroying and rebuilding every style-owned source/layer) whenever its style input changes, and already re-fires `onStyleLoadedCallback` when that happens — this is the exact mechanism ADR-0008 already identified as the reason application-owned layers must be made restorable. This document uses that same mechanism deliberately, rather than working around it, because it is the smallest possible change: `MapScreen.build()` simply computes a different `styleString` argument from `_selectedBaseMap`, exactly as it already computes other widget properties from state.

**4. The one-shot `_fishingSpotMarkersAdded` boolean is replaced by a generation-aware guard, not deleted outright.** Simply removing the guard would risk a duplicate-add crash if `onStyleLoadedCallback` ever fires twice for the *same* style (already a real possibility the original guard existed to prevent). The fix must distinguish "this callback fires for a style we've already restored markers for" (skip) from "this callback fires for a genuinely new style" (restore) — see [§5](#5-maplibre-style-lifecycle--the-fix).

**5. Persisting the base-map selection uses a new, minimal dependency (`shared_preferences`), not Drift.** See [§4](#4-persistence) for the full justification; in short, Drift exists in this project for structured, relational, feature-owned domain data with real query/join needs (fishing spots, catches, lure catalog, tackle box) — every existing table models a real domain entity with a lifecycle. A single scalar UI preference ("which of two enum values is active") has none of that shape; modeling it as a one-row (or worse, a schema-migrated) Drift table would be over-fitting this project's existing tool to a problem it does not have, and would force an unrelated schema-version bump for a UI-only concern. `shared_preferences` is the Flutter-ecosystem-standard, minimal, purpose-built tool for exactly this shape of data (a handful of simple key/value settings, platform-backed, no query capability needed) and introduces no schema/migration surface at all.

**6. The MML API key is supplied via `--dart-define` and read once via `String.fromEnvironment`, following the smallest configuration mechanism Flutter itself already provides — no new package, no `.env` file, no code generation.** See [§8](#8-mml-api-key-configuration). This project has no existing build-time configuration convention to extend, so the smallest correct option is Flutter's own built-in mechanism rather than introducing a new dependency (e.g. `flutter_dotenv`) whose only job would be to do something `--dart-define` already does natively.

**7. Attribution is rendered as a small, explicit, always-visible `Text` widget inside `MapScreen`'s own `Stack` — not relied upon as a MapLibre-native built-in control.** Whether `maplibre_gl` 0.26.2 exposes and correctly surfaces a built-in attribution control was not confirmed with certainty (see [§0](#0-pre-implementation-verification-completed)). Building it explicitly, driven by a plain Dart string keyed off `_selectedBaseMap`, guarantees correctness regardless of that plugin detail, and trivially stays correct across a base-map switch since it is just re-rendered from current state like any other widget. MML's CC BY 4.0 license specifies three required *elements* (licensor name, dataset name, supply date) rather than one fixed universal sentence ([§0](#0-pre-implementation-verification-completed)) — [§2](#2-base-map-model) turns those three elements into a concrete `BaseMap.attributionText` string and a small `MapAttribution` widget, rather than leaving attribution as an unresolved placeholder.

**8. The selector is a plain `Positioned`/`Stack`-based panel toggled by a boolean field on `_MapScreenState` — not an `OverlayEntry`/`CompositedTransformFollower` portal, and not a second live `MapLibreMap`.** The control and its panel both live inside the same `Stack` `MapScreen.build()` already constructs; anchoring a `Positioned` panel near a `Positioned` control in the same `Stack` needs no portal/overlay machinery. This mirrors the existing `_isSelectionMode` boolean-toggle precedent exactly, and is the smallest widget structure that satisfies "compact anchored visual selector" from MFS-026. See [§7](#7-selector-ux-implementation).

**9. The persisted base-map selection is written as soon as the user makes a choice, not only after that choice's style finishes loading successfully.** The angler's *intent* ("I want Ilmakuva") is what MFS-026 requires to be remembered — not a report card on whether that particular load happened to succeed. Gating persistence on load success would mean a selection made with a flaky connection is silently forgotten even though the angler's choice was completely clear, which is worse UX than remembering the choice and letting normal load/failure handling ([§9](#9-loading-and-failure-behavior)) apply exactly as it would for the default base map on any other launch.

**10. The existing bottom-right settings FAB (`MapControls`) is left completely untouched.** See [§10](#10-existing-mapcontrols-decision) for the full reasoning: MFS-026 places its new control in a different location with a different icon, and does not ask for the gear button to be relocated, removed, or repurposed; MFS-002 reserved that button for a broader future "map settings" surface this milestone does not attempt to become.

---

## 1. Overview and Folder Structure

This document introduces a new `core/map` area (anticipated by `app-structure.md`, not previously populated) for the provider-agnostic-in-name-only (per MFS-026's explicit "no generalized provider architecture" constraint) base-map model, style construction, and persistence — plus new presentation widgets inside the existing `features/map` feature for the control/selector UI. No other feature is touched.

```text
lib/
├── core/
│   └── map/
│       ├── base_map.dart                  (new — BaseMap enum + labels/preview paths)
│       ├── base_map_preference_store.dart  (new — persistence)
│       ├── mml_config.dart                 (new — API key access)
│       └── mml_style_factory.dart          (new — style JSON construction)
└── features/
    └── map/
        └── presentation/
            ├── map_screen.dart             (modified)
            └── widgets/
                ├── map_controls.dart               (unchanged)
                ├── base_map_layers_control.dart     (new — the upper-right icon button)
                ├── base_map_selector_panel.dart     (new — the anchored panel + option tiles)
                └── map_attribution.dart             (new — the small attribution Text widget)
```

---

## 2. Base-Map Model

```dart
// lib/core/map/base_map.dart

/// The two MML base maps this milestone supports. Deliberately not an
/// extensible provider registry — MFS-026 explicitly scopes this to exactly
/// Maastokartta and Ilmakuva; a third base map or a different provider is a
/// future milestone's decision, not something this enum is pre-built to
/// accommodate speculatively.
enum BaseMap {
  maastokartta,
  ilmakuva;

  static const BaseMap fallback = BaseMap.maastokartta;

  /// User-facing Finnish label (MFS-026 FR-5).
  String get label => switch (this) {
    BaseMap.maastokartta => 'Maastokartta',
    BaseMap.ilmakuva => 'Ilmakuva',
  };

  /// MML's own WMTS layer identifier for this base map (see §0/§3).
  String get mmlLayerId => switch (this) {
    BaseMap.maastokartta => 'maastokartta',
    BaseMap.ilmakuva => 'ortokuva',
  };

  /// Bundled static preview asset for the selector (MFS-026 FR-5); no live
  /// tile request is ever made for this preview (§9/§11) — illustrative
  /// artwork, not a crop of real MML tiles (see §11).
  String get previewAssetPath => switch (this) {
    BaseMap.maastokartta => 'assets/map/maastokartta_preview.png',
    BaseMap.ilmakuva => 'assets/map/ilmakuva_preview.png',
  };

  /// MML's WMTS tile file extension for this base map — confirmed from live
  /// GetCapabilities (§0): Maastokartta's tiles are `image/png` (`.png`),
  /// Ortokuva's are `image/jpeg` (`.jpg`). Used by `MmlStyleFactory` (§3) to
  /// build the correct tile URL per base map; the two layers do **not**
  /// share one hardcoded extension.
  String get tileFileExtension => switch (this) {
    BaseMap.maastokartta => '.png',
    BaseMap.ilmakuva => '.jpg',
  };

  /// The dataset-name element MML's CC BY 4.0 attribution requires (§0) —
  /// not the WMTS layer id (`mmlLayerId`), which is a technical identifier,
  /// not a human-readable dataset name suitable for attribution text.
  String get _mmlDatasetName => switch (this) {
    BaseMap.maastokartta => 'Maastokartta',
    BaseMap.ilmakuva => 'Ortokuva',
  };

  /// The attribution sentence shown by `MapAttribution` (below) whenever
  /// this base map is active (MFS-026 FR-18).
  ///
  /// MML's CC BY 4.0 license requires three elements — the licensor's name
  /// (Maanmittauslaitos), the dataset's name, and the period MML supplied
  /// the dataset — **not one fixed universal sentence** (confirmed from
  /// MML's own license page, not GetCapabilities — see §0). This follows
  /// the exact three-element pattern MML's own license page demonstrates by
  /// example ("sisältää Maanmittauslaitoksen Maastotietokannan 06/2014
  /// aineistoa").
  ///
  /// One judgment call, made explicitly rather than glossed over: MML's own
  /// example addresses a *downloaded dataset snapshot* (dated to the month
  /// it was downloaded). This feature instead consumes a *continuously
  /// updated live tile service*, which has no equivalent discrete "supply
  /// date." The current year is used as the "period supplied" element — a
  /// reasonable, license-compliant reading for a live service, following
  /// the same convention many map applications use for live basemap
  /// attribution, but it is this document's own interpretation, not an
  /// MML-published exact string for this scenario.
  String get attributionText =>
      'Sisältää Maanmittauslaitoksen $_mmlDatasetName-aineistoa '
      '${DateTime.now().year}';
}
```

```dart
// lib/features/map/presentation/widgets/map_attribution.dart

/// The small, always-visible attribution text required while an MML base
/// map is active (MFS-026 FR-18; §0). Renders `BaseMap.attributionText`
/// directly — no MapLibre-native attribution control is relied upon (Key
/// Design Decision 7) — so it stays correct across a base-map switch by
/// simply re-rendering from current state, like any other widget.
/// Positioned bottom-left, deliberately away from the existing bottom-right
/// `MapControls` and the new upper-right `BaseMapLayersControl`.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, required this.baseMap});

  final BaseMap baseMap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(
            baseMap.attributionText,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }
}
```

This is the entire domain model this feature needs: two values, six derived getters (one of which — `attributionText` — is itself built from two smaller ones), plus one small presentation widget. No class hierarchy, no provider interface, no configuration object beyond what `mml_style_factory.dart`/`mml_config.dart` already need for their own narrow purpose.

---

## 3. MML WMTS Integration

```dart
// lib/core/map/mml_style_factory.dart

/// Builds a minimal MapLibre GL style document for a single MML raster WMTS
/// base map. One source, one layer — this is not a general-purpose style
/// builder, and it is not meant to grow beyond what these two base maps need
/// (ADR-0008: raster, not vector; no custom Fishing App styling).
class MmlStyleFactory {
  const MmlStyleFactory({required this.apiKey});

  final String apiKey;

  /// WMTS REST base path. Confirmed against live GetCapabilities (§0); the
  /// exact `ResourceURL` templates for both layers are:
  /// `.../maastokartta/default/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.png`
  /// and
  /// `.../ortokuva/default/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.jpg`.
  static const _wmtsBase =
      'https://avoin-karttakuva.maanmittauslaitos.fi/avoin/wmts/1.0.0';

  /// Confirmed exact identifier from live GetCapabilities (§0). Substituted
  /// directly for MML's generic `{TileMatrixSet}` template token, since this
  /// factory only ever targets this one matrix set (Key Design Decision 2).
  static const _matrixSet = 'WGS84_Pseudo-Mercator';

  /// Confirmed from live GetCapabilities (§0): both `maastokartta` and
  /// `ortokuva` support TileMatrix identifiers `0` through `18` under
  /// `WGS84_Pseudo-Mercator`, with no per-layer restriction — both base maps
  /// genuinely share this exact range, not merely assumed to.
  static const _minZoom = 0;
  static const _maxZoom = 18;

  static const _sourceId = 'mml-base-source';
  static const _layerId = 'mml-base-layer';

  /// Returns a JSON-encoded MapLibre GL style document for [baseMap].
  ///
  /// The tile URL template's token order is `{z}/{y}/{x}` — **not**
  /// `{z}/{x}/{y}`. This is confirmed directly from live GetCapabilities
  /// (§0): MML's own `ResourceURL` templates order `{TileMatrix}/{TileRow}/{TileCol}`
  /// (row before column, the opposite of the generic OGC-default order),
  /// and the confirmed standard-XYZ scheme means `{TileRow}` is MapLibre's
  /// `{y}` and `{TileCol}` is MapLibre's `{x}` with no further inversion.
  /// Getting this order wrong silently produces a mirrored/transposed map
  /// with no error thrown — see [§0](#0-pre-implementation-verification-completed).
  ///
  /// The file extension is **not** the same for both base maps — Maastokartta
  /// is `.png`, Ortokuva is `.jpg` (confirmed from live GetCapabilities, §0)
  /// — hence branching on `baseMap.tileFileExtension` below rather than a
  /// single hardcoded extension.
  String styleFor(BaseMap baseMap) {
    final tileUrl =
        '$_wmtsBase/${baseMap.mmlLayerId}/default/$_matrixSet/{z}/{y}/{x}'
        '${baseMap.tileFileExtension}'
        // Confirmed from MML's own API-key instructions page, not from
        // GetCapabilities (§0) — GetCapabilities only states that a
        // credential is required (`ows:AccessConstraints`), not how to
        // supply one.
        '?api-key=$apiKey';

    final style = {
      'version': 8,
      'sources': {
        _sourceId: {
          'type': 'raster',
          'tiles': [tileUrl],
          'tileSize': 256, // confirmed 256×256 for both layers, all levels (§0)
          'minzoom': _minZoom,
          'maxzoom': _maxZoom,
          'attribution': baseMap.attributionText, // see §2
        },
      },
      'layers': [
        {'id': _layerId, 'type': 'raster', 'source': _sourceId},
      ],
    };

    return jsonEncode(style);
  }
}
```

**Why a locally built style JSON, not a fetched `style.json` or two hand-authored asset files:** see Key Design Decision 1. The style is small enough (one source, one layer) that generating it in Dart, with the API key already interpolated, is simpler than hosting or bundling an equivalent document and templating a key into it separately.

**Primary mechanism — `styleString` accepts inline JSON.** `MapScreen` passes `MmlStyleFactory(apiKey: ...).styleFor(_selectedBaseMap!)` directly as `MapLibreMap`'s `styleString` argument. This assumes `maplibre_gl: ^0.26.2`'s `styleString` accepts a raw JSON string — the one remaining open item in this design, and a `maplibre_gl` plugin-API question rather than a WMTS-service question (§0). If confirmed unsupported, the fallback is: write the generated JSON to a file in the application's temporary directory (via the already-used `path_provider`/`getApplicationDocumentsDirectory`-style APIs) once per session/selection, and pass that file's path as `styleString` instead — the rest of this document (lifecycle, switching, persistence, attribution) is unaffected by which of these two delivery mechanisms is used, since both still result in `styleString` changing when `_selectedBaseMap` changes.

**Tile size, zoom range, matrix set identifier, tile-token axis order, and per-layer file extension are all now confirmed values, not assumptions** ([§0](#0-pre-implementation-verification-completed)), each isolated to a single named constant or getter in exactly one place (`MmlStyleFactory`/`BaseMap`) — so if MML ever changes one of them, correcting it remains a one-line change, not a design change.

---

## 4. Persistence

```dart
// lib/core/map/base_map_preference_store.dart

/// Persists the angler's selected [BaseMap] across application restarts
/// (MFS-026 FR-8). Stores the enum's own `.name` string — the same
/// established convention already used for `Catches.species`
/// (`FishSpecies.name`, TD-025 Current State) — rather than an integer index
/// (fragile if enum order ever changes) or a custom string constant.
class BaseMapPreferenceStore {
  const BaseMapPreferenceStore();

  static const _key = 'selected_base_map';

  /// Returns the persisted [BaseMap], or [BaseMap.fallback] (Maastokartta)
  /// if nothing is stored, or the stored value is unreadable/unrecognized.
  Future<BaseMap> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      return BaseMap.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => BaseMap.fallback,
      );
    } catch (_) {
      return BaseMap.fallback;
    }
  }

  Future<void> save(BaseMap baseMap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, baseMap.name);
  }
}
```

**Why `shared_preferences`, not Drift (see also Key Design Decision 5):** every existing `AppDatabase` table models a real, relational, feature-owned domain entity with its own lifecycle and query needs. A single scalar "which of two enum values is currently selected" preference has none of that shape — modeling it as a Drift table would force an unrelated schema-version bump (`AppDatabase.schemaVersion` would need to move to `9` for a UI preference, not a domain change) purely to store one string. `shared_preferences` is the standard, minimal, purpose-built Flutter tool for exactly this shape of data, is platform-backed (Android `SharedPreferences`, iOS `NSUserDefaults`) with no query capability needed or wanted, and introduces no schema/migration surface. This is a new dependency, but a justified one — `docs/development-rules.md` does not prohibit new dependencies, only new *architectural layers* (repository interfaces, DAOs, service layers), none of which this introduces.

**Corrupt/missing/unknown values fall back to Maastokartta** (`BaseMap.fallback`), per MFS-026 — both a missing key (first-ever launch) and an unrecognized stored string (e.g. a future value from a newer app version, or corruption) resolve identically to the same safe default via `orElse`.

**Initialization timing — no visible wrong-then-switch flash (MFS-026's explicit requirement):**

- `_MapScreenState` adds `BaseMap? _selectedBaseMap` (`null` means "not yet loaded from persistence").
- `initState()` kicks off `unawaited(_loadBaseMapPreference())`, which awaits `BaseMapPreferenceStore().load()` and then, if `mounted`, calls `setState(() => _selectedBaseMap = loaded)`.
- `build()` checks `_selectedBaseMap == null` **before** constructing `MapLibreMap` at all: while `null`, it returns a minimal `Scaffold(body: Center(child: CircularProgressIndicator()))` (no `MapLibreMap` widget exists yet, so no style — right or wrong — has been requested). Once `_selectedBaseMap` is set, the full `Scaffold` (AppBar, `MapLibreMap` constructed with the now-correctly-known style, `MapControls`, the new layers control) is built for the first time.
- Reading one small local preference is fast (no I/O contention comparable to, say, opening the Drift database), so this loading gate is brief and appears only once per cold start — it replaces "load the wrong default, then immediately switch," which is exactly what MFS-026 asks to avoid, with "load once, correctly, slightly after the very first frame."

This mirrors the project's existing `await → mounted → setState` convention (already used throughout, e.g. `FishingSpotDetailsBottomSheet`'s reload convention, TD-021's lifecycle fix) rather than introducing a new async-initialization pattern.

---

## 5. MapLibre Style Lifecycle — the fix

**The bug, restated precisely (ADR-0008):** `_addFishingSpotMarkers()` is guarded by `bool _fishingSpotMarkersAdded`, set to `true` the first time it successfully runs and never reset. `onStyleLoadedCallback` fires again every time the active style is replaced (MapLibre destroys all style-owned sources/layers on a style change), but the guard silently prevents the method from doing anything on that second and every subsequent call — so fishing-spot markers/labels disappear permanently after the *first* base-map switch, with no way back short of restarting the app.

**The fix:** replace the one-shot boolean with a **generation-aware** guard that distinguishes "already restored for the currently active style" (skip) from "a genuinely new style just loaded" (restore) — reproducing the original guard's only real purpose (don't add a duplicate source/layer if the callback fires twice for the same style) while correctly re-triggering on an actual style change.

```dart
// New/changed state on _MapScreenState

int _styleGeneration = 0;            // bumped every time the active base map changes
int _markersRestoredForGeneration = -1; // guards duplicate/stale restoration
```

```dart
Future<void> _addFishingSpotMarkers() async {
  final controller = _mapController;
  if (controller == null) return;

  final generation = _styleGeneration;
  if (_markersRestoredForGeneration == generation) return; // already done for this style

  List<FishingSpot> spots;
  try {
    // Reuse the already-loaded cache on every style load after the first —
    // fishing spots don't change just because the base map did, so only the
    // very first load (cache empty) needs to hit the repository.
    spots = _fishingSpotsById.isNotEmpty
        ? _fishingSpotsById.values.toList()
        : await _fishingSpotRepository.loadAll();
  } catch (error) {
    debugPrint('Failed to load fishing spots: $error');
    return;
  }

  if (!mounted || _styleGeneration != generation) return; // a newer switch has since occurred

  for (final spot in spots) {
    _fishingSpotsById[spot.id] = spot;
  }

  try {
    await controller.addGeoJsonSource(
      _fishingSpotsSourceId,
      _buildFeatureCollection(_fishingSpotsById.values),
      promoteId: 'id',
    );
    await controller.addLayer(_fishingSpotsSourceId, _fishingSpotsCircleLayerId, /* unchanged */);
    await controller.addLayer(_fishingSpotsSourceId, _fishingSpotsSymbolLayerId, /* unchanged */);

    if (_styleGeneration == generation) {
      _markersRestoredForGeneration = generation;
    }
  } catch (error) {
    debugPrint('Failed to set up fishing spot markers: $error');
  }
}
```

This is the entire fix in terms of new *mechanism* — no new lifecycle framework, no per-layer registry, exactly the smallest change the task brief asked to prefer. Walking through the required scenarios:

- **Initial style load:** `_styleGeneration` starts at `0`; `_markersRestoredForGeneration` starts at `-1` (never equal), so the very first `onStyleLoadedCallback` proceeds normally.
- **Maastokartta → Ilmakuva:** selecting a new base map increments `_styleGeneration` to `1` ([§6](#6-base-map-switching-mechanism)); the new style loads, `onStyleLoadedCallback` fires, `_markersRestoredForGeneration (0) != 1`, so markers/layers are re-added against the *new* style (whose sources/layers were freshly torn down by MapLibre when the style changed).
- **Ilmakuva → Maastokartta:** generation becomes `2`; same re-add path runs again.
- **Repeated switching:** generation strictly increases on every switch, so this keeps working indefinitely, and a slow-finishing add for an already-abandoned generation is caught by the `_styleGeneration != generation` check after the `await` and aborts without touching the controller — the same stale-async-guard idiom `LureCatalogListPage`'s `_requestId` already establishes in this codebase (see Current State).
- **Feature tapping:** `controller.onFeatureTapped.add(_onFishingSpotFeatureTapped)` is registered once, in `_onMapCreated`, against the **controller** — not the style. It is never destroyed by a style change and needs no re-registration; it keeps matching taps against `_fishingSpotsCircleLayerId`/`_fishingSpotsSymbolLayerId`, which are stable constants re-used identically every time markers are re-added. No change needed here beyond confirming this remains true.
- **No duplicate sources/layers:** guaranteed by the generation guard exactly as the original boolean guaranteed "no duplicate on the very first style," now correctly scoped to "no duplicate per style" instead of "no duplicate ever."

**Existing create/rename/delete marker-update paths** (`_addFishingSpotFeature`, `_renameFishingSpot`, `_deleteFishingSpot`) are unchanged and remain valid, *provided* the fishing-spot source already exists for the currently active style — true in the overwhelming majority of real usage, since restoring markers after a switch is a fast, local (no-network) GeoJSON operation. The one theoretical edge case — the angler triggers an add/rename/delete in the narrow window between selecting a new base map and `_addFishingSpotMarkers` finishing its re-add for that style — is accepted as-is: these methods already wrap their controller calls in `try`/`catch` and already show a Finnish failure `SnackBar` ("...epäonnistui. Yritä uudelleen.") on any failure, so a mutation attempted in that narrow window degrades gracefully into an already-existing, already-tested error path rather than crashing. Given the window's real-world duration (local GeoJSON operations, no network involved), adding explicit queuing/blocking machinery for this edge case would be exactly the kind of premature complexity `docs/development-rules.md` cautions against; it is flagged here and in [§14 Risks](#14-risks-and-mitigations) so reviewers/testers know to check it deliberately rather than encounter it as a surprise.

---

## 6. Base-Map Switching Mechanism

**What state changes when a base map is selected:**

```dart
void _onBaseMapSelected(BaseMap newBaseMap) {
  setState(() => _layersPanelOpen = false); // close the selector regardless (see §7)

  if (newBaseMap == _selectedBaseMap) return; // re-selecting the active choice is a no-op switch

  setState(() {
    _selectedBaseMap = newBaseMap;
    _styleGeneration++;
  });

  unawaited(_baseMapPreferenceStore.save(newBaseMap)); // Key Design Decision 9 — write immediately
}
```

**How MapLibre receives the new configuration:** `build()` computes `styleString: _mmlStyleFactory.styleFor(_selectedBaseMap!)` as one of `MapLibreMap`'s constructor arguments, exactly like every other property already computed from state in this widget. Flutter's normal widget-rebuild diffing passes the new `styleString` value down to the already-mounted `MapLibreMap`, which (per MapLibre GL Native's existing, already-relied-upon behavior — see ADR-0008) reloads the style and re-fires `onStyleLoadedCallback`. No navigation, no `Key` change forcing recreation, no second `MapLibreMap` instance.

**Loading behavior during style replacement:** MapLibre GL Native's own raster-layer rendering already shows previously-rendered tiles fading to newly-requested ones as a style/source changes — ordinary raster-layer behavior requiring no custom code. `MapScreen` additionally shows the small, non-blocking loading/failure treatment described in [§9](#9-loading-and-failure-behavior) if the new style does not finish loading within a bounded timeout.

**Stale/racing style-load protection during rapid switching:** already covered by `_styleGeneration` in [§5](#5-maplibre-style-lifecycle--the-fix) — every in-flight async operation tied to a specific style load captures the generation value at its start and re-checks it after every `await`, so a slow-finishing operation for an abandoned selection can never clobber a newer one's state.

**How failure to load the new base map affects the previous/current selection:** the selection itself (`_selectedBaseMap`, and the persisted preference) is **not** rolled back on a load failure. The angler explicitly chose the new base map; a transient network hiccup loading its tiles does not mean they want the old one back — it means tiles are temporarily unavailable, exactly the same condition as MFS-026's "temporary network failure" state for *any* base map, including one loaded from a fresh persisted preference on next launch (Key Design Decision 9).

**When the persisted selection is updated:** immediately, in `_onBaseMapSelected`, independent of whether that particular style load later succeeds or fails (Key Design Decision 9) — not deferred until `onStyleLoadedCallback` confirms success.

---

## 7. Selector UX Implementation

```dart
// lib/features/map/presentation/widgets/base_map_layers_control.dart

/// The upper-right floating control (MFS-026). Stateless and callback-driven,
/// exactly mirroring MapControls' existing shape — no repository/service
/// access of its own.
class BaseMapLayersControl extends StatelessWidget {
  const BaseMapLayersControl({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FloatingActionButton(
            heroTag: 'baseMapLayersButton',
            tooltip: 'Karttatasot',
            onPressed: onPressed,
            child: const Icon(Icons.layers),
          ),
        ),
      ),
    );
  }
}
```

```dart
// lib/features/map/presentation/widgets/base_map_selector_panel.dart

/// The compact anchored selector opened by BaseMapLayersControl (MFS-026).
/// Positioned in the same Stack as the control — no OverlayEntry/portal
/// needed (Key Design Decision 8). Deliberately built as a small list of
/// option tiles so a later milestone can append overlay toggles below the
/// two base-map tiles without restructuring this widget (MFS-026: "keep
/// expandable for future overlay controls without implementing overlays
/// now") — no overlay-specific code exists yet, only room for it.
class BaseMapSelectorPanel extends StatelessWidget {
  const BaseMapSelectorPanel({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final BaseMap selected;
  final ValueChanged<BaseMap> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final baseMap in BaseMap.values)
              _BaseMapOptionTile(
                baseMap: baseMap,
                isActive: baseMap == selected,
                onTap: () => onSelected(baseMap),
              ),
          ],
        ),
      ),
    );
  }
}
```

`_BaseMapOptionTile` (private to the same file) renders `Image.asset(baseMap.previewAssetPath)`, a `Text(baseMap.label)` beneath it, and a visible active-state treatment (e.g. a colored border/checkmark) when `isActive` — exact visual styling (border width, checkmark icon, spacing) is an implementation-time/design detail, not fixed further here, per MFS-026's own "do not over-specify pixel dimensions/colors" instruction.

**Widget ownership and anchoring:** `_layersPanelOpen` (bool) and `_selectedBaseMap` both live on `_MapScreenState`, following the exact existing `_isSelectionMode` precedent. `MapScreen.build()`'s `Stack` gains two more children: `BaseMapLayersControl(onPressed: () => setState(() => _layersPanelOpen = !_layersPanelOpen))`, and, conditionally, `if (_layersPanelOpen) Positioned(top: ..., right: ..., child: BaseMapSelectorPanel(...))` positioned just below the control. Both widgets are plain, stateless, presentation-only — identical in spirit to `MapControls`.

**Dismissal behavior:** tapping a choice calls `_onBaseMapSelected` (which already closes the panel — [§6](#6-base-map-switching-mechanism)); tapping anywhere else on the map while the panel is open should also dismiss it. The simplest implementation is a transparent, full-size `GestureDetector` placed in the `Stack` immediately behind the panel (and above the map) whenever `_layersPanelOpen` is true, calling `setState(() => _layersPanelOpen = false)` on tap-through — a common, minimal popover-dismissal pattern requiring no new package.

**Whether the selector remains open or closes after selection — closes, with justification:** MFS-026 requires the switch to apply immediately with no separate confirm step; once a choice is made, the action is already complete, and a compact popover lingering open only occupies map space for no further purpose (echoing MFS-026's own "must not unnecessarily consume permanent map space" requirement for the control itself). This also matches the closest familiar precedent named in MFS-026 ("inspired by familiar map applications") — general-purpose map apps' own layer pickers close immediately after a selection.

**Accessibility/semantics:** the control carries a `tooltip`/semantic label ("Karttatasot"); each option tile is wrapped so it exposes `Semantics(button: true, label: '<name>, <valittu/ei valittu>')` conveying both identity and active state to assistive technology, not only a visual border — mirroring the existing `Semantics(button: true)` precedent already established for `SpeciesCatchStatisticRow`/`RecordCatchCard` (an `InkWell` alone does not expose button semantics, per that prior finding).

---

## 8. MML API-Key Configuration

**Mechanism: `--dart-define`, read via `String.fromEnvironment` — the smallest option Flutter already provides, no new package.**

```dart
// lib/core/map/mml_config.dart

/// Reads the MML WMTS API key supplied at build time. Never hardcode a real
/// key here or anywhere else in source, tests, fixtures, or documentation.
class MmlConfig {
  const MmlConfig._();

  static const String _apiKey = String.fromEnvironment('MML_API_KEY');

  /// True when no key was supplied at build time (an unconfigured
  /// development/test build). Checked *before* any MML tile request is
  /// attempted (§9) — this is a reliably, cheaply, entirely
  /// Dart-side-detectable condition, unlike a network/tile failure.
  static bool get isMissing => _apiKey.isEmpty;

  static String get apiKey => _apiKey;
}
```

- **Configuration key name:** `MML_API_KEY` — this project's own `--dart-define` variable name, not MML's request-parameter name (see below).
- **How Dart accesses it:** `String.fromEnvironment('MML_API_KEY')` — a compile-time constant; there is no runtime `.env` file to read, and nothing to await.
- **How the key reaches MML on the wire:** `MmlStyleFactory` ([§3](#3-mml-wmts-integration)) appends it as the `api-key` query-string parameter on every tile URL. That parameter name is confirmed from MML's own official "Instructions for using the API key" page, not from `WMTSCapabilities.xml` (which only states a credential is required, not how to supply one — [§0](#0-pre-implementation-verification-completed)). MML's documentation also names HTTP Basic Authentication as an alternative mechanism, but `maplibre_gl`'s raster source is a plain tile-URL-template list with no documented custom-header hook, so the query-parameter form is the one this design actually uses.
- **Local development command:**

  ```bash
  flutter run --dart-define=MML_API_KEY=your-local-development-key
  ```

- **Release/CI builds:** the same flag is passed to `flutter build apk`/`flutter build ios` (or equivalent), with the real key supplied by whatever secret-storage mechanism the build environment already uses (e.g. a CI secret injected as a shell variable and interpolated into the build command: `--dart-define=MML_API_KEY=$MML_API_KEY_SECRET`). This document does not mandate a specific CI product — only that the key never appears as a literal in any versioned file.
- **Template/example documentation:** a short "Local Development Setup" note (naming the exact flag and variable above, with a placeholder value only) should be added to the project's developer-facing documentation once this feature is implemented — see [§17](#17-documentation-impact). No such file is created by this TD.
- **The key is not presented as cryptographically secret.** A `--dart-define` value is compiled into the release binary and is recoverable by anyone who decompiles/inspects it — exactly like any other mobile-app API key used for direct client-to-service calls (ADR-0008 already accepts this as the initial architecture's trade-off, to be revisited only if/when scale requires a proxy). This document does not attempt to hide the key from a determined actor; it only keeps it out of source control and off developer/CI screens where avoidable.

**Behavior when the key is missing (`MmlConfig.isMissing == true`):** see [§9](#9-loading-and-failure-behavior) — detected before any MML network request is attempted, never surfaced as a raw error.

---

## 9. Loading and Failure Behavior

**Distinguishing app-detectable failures from MapLibre-internal ones (task brief's explicit requirement):**

| Failure | Who detects it | Handling |
|---|---|---|
| A single tile fails to load (one HTTP request among many, e.g. transient blip) | MapLibre GL Native, internally | No app-level handling exists or is needed — this is ordinary raster-layer behavior today (the demo style could already suffer this) and must not surface any dialog/banner; it self-heals as MapLibre retries/pans/zooms. |
| Missing/invalid MML API key | The app, reliably, before any request | `MmlConfig.isMissing` is checked before constructing the style/attempting to load any MML tiles. If true, `MapScreen` shows a persistent, non-blocking, dismissible banner ("Karttapohjan asetukset puuttuvat.") instead of ever attempting a doomed request, and application-owned content (markers, controls, other entry points) remains fully usable underneath it. |
| Whole-style load never completes (no network, DNS failure, MML outage) | The app, heuristically, via a bounded timeout | No confirmed explicit "style failed" callback exists for this plugin version (§0). `MapScreen` starts a short `Timer` (e.g. 8–10 seconds — exact value an implementation detail) whenever `_styleGeneration` changes; if `onStyleLoadedCallback` for that same generation has not fired by the time it elapses, a lightweight, non-blocking, dismissible message ("Karttakuvia ei voitu ladata juuri nyt.") is shown. The timer is cancelled/ignored if the callback fires first, or if a newer switch has since superseded that generation (same `_styleGeneration` comparison as §5/§6). |
| Malformed/unexpected external response (e.g. MML returns an unexpected content type or a capabilities-mismatch error page instead of a tile) | MapLibre GL Native, internally, in the overwhelming majority of cases | Treated the same as an individual tile failure — no app-level handling; MapLibre's raster layer does not crash the host application for a bad tile response. If a systemic version of this occurs (every tile fails, not sporadically), it manifests as the whole-style timeout above and is handled identically. |

**Non-negotiable, in every row above:** no API key, raw request URL, HTTP status code, stack trace, or MapLibre/MML-specific technical string is ever shown to the user. Every user-facing message is a short, calm, Finnish sentence. `MapScreen` itself must not crash under any of these conditions — nothing above throws past a `try`/`catch` boundary into widget-build code.

**Avoiding disruptive dialogs for transient individual tile failures:** resolved structurally — individual tile failures are never surfaced by this design at all (first row above); only the two coarser, genuinely app-detectable conditions (missing key; whole-style timeout) ever produce a user-visible message, and both use a lightweight banner/snackbar-style treatment, never a blocking modal `AlertDialog` that would demand dismissal before the angler could keep using the map.

---

## 10. Existing `MapControls` Decision

**Decision: the existing bottom-right settings FAB (`MapControls`) is left completely untouched — not removed, not repurposed, not relocated.**

Reasoning, per the task's explicit instruction to base this on documented existing intent and scope rather than a silent change:

- MFS-026's own UX requirements place the new control in the **upper-right**, using a **layers-style icon** — a different location and a different icon from the existing bottom-right gear icon. MFS-026 never asks for the settings FAB itself to change.
- MFS-002 (Map Controls) explicitly reserved the settings button for a *broader* future surface: "Open map settings, Select map style, Configure overlays, Manage offline maps" — of which base-map selection is only one item among several (overlay configuration and offline-map management remain unbuilt and unscoped). Repurposing that button now for base-map selection alone would prematurely narrow a scope MFS-002 already documented as broader than this milestone, and would likely need to be "un-repurposed" again once a real map-settings surface (as opposed to just base-map selection) is eventually built.
- The task brief explicitly warns against silently changing unrelated controls; touching the gear button was not requested by MFS-026's UX section, so it is not touched.

This milestone therefore ships with two independent, non-overlapping floating controls: the existing bottom-right settings/add-spot/location column (`MapControls`, unchanged) and the new upper-right layers control (`BaseMapLayersControl`, new). A future "real" map-settings feature remains free to repurpose the gear button later, entirely independently of this decision.

---

## 11. Preview Assets

Per the task brief, this TD specifies the plan only — no image files are added by this document.

- Two new static, bundled assets: `assets/map/maastokartta_preview.png`, `assets/map/ilmakuva_preview.png`, added to `pubspec.yaml`'s existing `assets:` list (mirroring the established `assets/lure_catalog/` entry).
- No live tile request is ever made to produce or display these previews — they are static images shipped with the app, exactly like the existing lure-catalog placeholder images.
- **Decision: both preview images are locally bundled, illustrative artwork created for this application — not screenshots or crops of actual MML map tiles.** MML's WMTS data is CC BY 4.0-licensed ([§0](#0-pre-implementation-verification-completed)), and a real crop of MML imagery would very likely be covered by the same on-screen attribution requirement already satisfied by `MapAttribution` ([§2](#2-base-map-model)) — but resolving that question is unnecessary complexity this milestone does not need to take on. The Maastokartta preview only needs to visually communicate "topographic map" (e.g. contour-line/terrain-style illustration); the Ilmakuva preview only needs to communicate "aerial imagery" (e.g. a stylized satellite/aerial-photo look) — neither needs to contain real MML data, real coordinates, or a recognizable real place. This resolves conservatively, avoids any additional attribution/licensing question for these two specific assets, and avoids any network request to produce them.
- Correct Flutter asset inclusion (`pubspec.yaml` `assets:` entry, exact file naming) is a one-line addition at implementation time, following the existing `assets/lure_catalog/` precedent exactly.

---

## 12. Testing Strategy

Per `map_screen_test.dart`'s own documented constraint, `MapLibreMap` embeds a platform view that never settles in this headless test environment — every `MapScreen`-level test below must use bounded `tester.pump(Duration(...))` calls, never `pumpAndSettle()`, exactly as the existing file already does.

### Domain/config/persistence tests (new — `base_map_test.dart`, `base_map_preference_store_test.dart`, `mml_config_test.dart`)

- `BaseMap.fallback` is `BaseMap.maastokartta`.
- `BaseMap.maastokartta.tileFileExtension` is `.png`; `BaseMap.ilmakuva.tileFileExtension` is `.jpg` — the two must differ (a regression here would silently reintroduce the format bug this document's verification corrected).
- `BaseMap.attributionText` contains "Maanmittauslaitos" and the correct dataset name ("Maastokartta"/"Ortokuva") for each value.
- `BaseMapPreferenceStore.load()` returns `BaseMap.fallback` when nothing is stored.
- `save()` then `load()` round-trips correctly for both values (using `SharedPreferences.setMockInitialValues({})` — the package's own standard test seam, no new test infrastructure needed).
- `load()` returns `BaseMap.fallback` when the stored string does not match any `BaseMap.name` (simulated corruption/unknown future value).
- `MmlConfig.isMissing` is `true` when `MML_API_KEY` is not supplied (the default in a plain `flutter test` invocation) — confirms the missing-configuration path is exercised by default, not only when deliberately testing it.
- `MmlStyleFactory.styleFor()` (`mml_style_factory_test.dart`, using a synthetic non-empty test key, never a real one — [§16](#16-security-and-repository-hygiene)): the generated tile URL places tokens in `{z}/{y}/{x}` order (not `{z}/{x}/{y}`) for both base maps; Maastokartta's URL ends in `.png`, Ortokuva's ends in `.jpg`; `WGS84_Pseudo-Mercator` and the confirmed `0`/`18` zoom bounds appear verbatim in the generated style JSON.

### Selector widget tests (new — `base_map_layers_control_test.dart`, `base_map_selector_panel_test.dart`)

- The layers control is present, uses `Icons.layers`, and exposes the "Karttatasot" tooltip/semantic label.
- Tapping the control opens the anchored `BaseMapSelectorPanel`.
- Both `BaseMapOptionTile`s show their preview image and label.
- The currently active choice is identifiable (e.g. its distinguishing decoration/semantics differ from the inactive one).
- Tapping the inactive choice fires the `onSelected` callback with the correct `BaseMap`.
- Tapping outside the panel (or re-tapping the control) dismisses it without firing `onSelected`.
- Accessibility: each tile's `Semantics` label conveys both name and active state.

### `MapScreen` integration tests (new/extended in `map_screen_test.dart`)

- With no stored preference, the map is constructed with the Maastokartta style once loading completes (verified via the widget's own `styleString`/constructor argument, not by inspecting native map state, consistent with this project's existing "assert on the widget tree, not on the platform view" testing limitation).
- With a persisted Ilmakuva preference (seeded via `SharedPreferences.setMockInitialValues`), the map is constructed with the Ilmakuva style after the loading gate resolves.
- Selecting the other base map from the panel updates the `styleString` argument the `MapLibreMap` widget is rebuilt with.
- `_styleGeneration`/`_markersRestoredForGeneration`-driven behavior is exercised at the unit level by extracting the guard logic into a small, directly testable pure function/class where practical, given the existing headless-test limitation on asserting real native marker presence — mirroring how this project has already worked around equivalent native-surface limitations elsewhere (e.g., asserting on repository calls/state rather than rendered platform output).
- Repeated switching (A→B→A→B) does not throw and leaves `_styleGeneration` strictly increasing.
- The pre-existing `openLureToolsButton`/`openStatisticsButton`/`openCatchSearchButton` regression tests (already in `map_screen_test.dart`) continue to pass unmodified — confirms this milestone does not disturb existing entry points.
- The existing bottom-right `MapControls` (settings/add-fishing-spot/current-location FABs) remain present and unchanged, confirming [§10](#10-existing-mapcontrols-decision)'s "left untouched" decision holds in practice.

### Physical Android testing checklist

1. First launch, no prior install/data — Maastokartta is shown by default with no visible flash of the old demo map.
2. The layers control appears in the upper-right, using a layers icon, not overlapping the AppBar.
3. Opening the selector shows both previews and labels, with Maastokartta indicated as active.
4. Selecting Ilmakuva switches the visible map immediately, with sensible loading behavior, no crash.
5. Selecting Maastokartta again switches back correctly.
6. Repeated rapid switching (several times in a row) does not corrupt the map, duplicate markers, or crash.
7. Fishing spots (markers + labels) are present both before and immediately after a switch, with no need to leave/reopen the Map screen.
8. Adding a new fishing spot works correctly after a switch.
9. Renaming and deleting a fishing spot both work correctly after a switch.
10. The current-location control and camera centering work correctly regardless of the active base map.
11. Restarting the app after selecting Ilmakuva shows Ilmakuva active on relaunch (persistence).
12. Airplane mode / no network: a clear, calm, non-technical message appears; existing fishing-spot markers, controls, and other entry points remain usable.
13. A development build launched with no `MML_API_KEY` supplied shows the missing-configuration message, not a crash or a raw error.
14. Attribution text is visible and legible for both Maastokartta and Ilmakuva, and updates correctly when switching between them.
15. Different screen sizes/orientations (at minimum: one phone in portrait, one in landscape if practical) — the layers control and selector panel remain reachable and do not overlap the AppBar, `MapControls`, or the attribution text.

---

## 13. Files Affected — File Plan

### New files

```text
lib/core/map/base_map.dart
lib/core/map/base_map_preference_store.dart
lib/core/map/mml_config.dart
lib/core/map/mml_style_factory.dart
lib/features/map/presentation/widgets/base_map_layers_control.dart
lib/features/map/presentation/widgets/base_map_selector_panel.dart
lib/features/map/presentation/widgets/map_attribution.dart

test/core/map/base_map_test.dart
test/core/map/base_map_preference_store_test.dart
test/core/map/mml_config_test.dart
test/core/map/mml_style_factory_test.dart
test/features/map/presentation/widgets/base_map_layers_control_test.dart
test/features/map/presentation/widgets/base_map_selector_panel_test.dart
```

### Modified files

```text
lib/features/map/presentation/map_screen.dart   (styleString source, style-lifecycle guard, new state/widgets)
test/features/map/presentation/map_screen_test.dart  (extended, existing tests preserved unmodified)
pubspec.yaml                                    (new dependency: shared_preferences; new assets/map/ entry)
```

### Not modified

`lib/features/map/presentation/widgets/map_controls.dart` (per [§10](#10-existing-mapcontrols-decision)), `lib/core/database/app_database.dart` (no schema change — see [§4](#4-persistence)), every other feature (`fishing_spots`, `catches`, `catch_photos`, `lure_catalog`, `personal_tackle_box`, `statistics`).

### Generated files

None — no code generation is introduced by this milestone (no new Drift table, no `build_runner` impact).

---

## 14. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| ~~Several MML-specific technical values were not independently confirmed against the primary capabilities XML.~~ **Resolved.** | All WMTS service-mechanics values (matrix-set identifier, REST token order, zoom range, tile size, scheme, per-layer format) are now confirmed directly from live GetCapabilities — see [§0](#0-pre-implementation-verification-completed). No longer an open risk; retained here only so the record shows this was checked, not assumed. |
| MML's own documentation states its open WMTS interface is "intended for testing and small-scale use," with no guaranteed availability — a real production-readiness risk beyond ordinary transient network failures. | Already anticipated by ADR-0008 ("large-scale production usage may later require reassessing MML's service tier"); confirmed as MML's own stated position, not a secondary-source claim ([§0](#0-pre-implementation-verification-completed)). This document's failure handling ([§9](#9-loading-and-failure-behavior)) already degrades gracefully under sustained unavailability, and a future milestone can reassess the service tier/delivery approach without this design needing to change. |
| `maplibre_gl: ^0.26.2`'s `styleString` may not accept inline JSON directly. | [§3](#3-mml-wmts-integration) names an explicit fallback (a generated style file in the temp directory) that preserves every other part of this design unchanged. This is a plugin-API question, unaffected by the WMTS verification above. |
| No confirmed explicit "style load failed" callback exists in this plugin version. | [§9](#9-loading-and-failure-behavior)'s timeout-based detection does not depend on such a callback existing at all. Also a plugin-API question, unaffected by the WMTS verification above. |
| A narrow race exists between a base-map switch starting and an add/rename/delete-fishing-spot action completing before markers are restored for the new style. | Accepted, documented explicitly in [§5](#5-maplibre-style-lifecycle--the-fix); degrades into the existing, already-tested failure `SnackBar` rather than crashing; window is small (local GeoJSON operation, no network). Flagged in the physical-testing checklist (§12, item 6/8/9 combined scenario) for deliberate verification. |
| A static crop of real MML imagery, if used for the selector previews, could raise its own attribution question beyond the live on-screen attribution. | **Resolved by decision, not merely mitigated:** [§11](#11-preview-assets) decides both previews are locally bundled, illustrative artwork created for this application — never a crop of real MML tiles — sidestepping the question entirely rather than relying on an assumption that on-screen attribution would also cover a derived asset. |
| Introducing `shared_preferences` is this project's first non-Drift persistence dependency. | Justified explicitly in Key Design Decision 5/[§4](#4-persistence) as the smallest tool matching this specific problem's shape; no other persistence need in the project is redirected to it. |
| MML's CC BY 4.0 license specifies required attribution *elements* rather than one fixed universal sentence, and has no published exact phrase for a live (as opposed to downloaded-snapshot) tile service. | [§2](#2-base-map-model) builds a concrete `BaseMap.attributionText` from the three confirmed required elements (licensor, dataset name, supply period), using the current year for "supply period" as an explicit, documented interpretation for a live service — not a gap, and not an invented legal claim beyond what the three required elements demand. |

---

## 15. Dependencies

- **New:** `shared_preferences` (exact version to be selected at implementation time against the project's current Flutter/Dart SDK constraints) — justified in Key Design Decision 5/[§4](#4-persistence). No other new package is introduced.
- **Unchanged:** `maplibre_gl` (already present, per ADR-0002); no version bump is required by this design, only confirmation of existing API behavior (§0).
- **Not introduced:** any HTTP client package (raster tile URLs are handled entirely internally by `maplibre_gl`/MapLibre GL Native — this design never issues its own HTTP requests), any `.env`/secrets-management package (Flutter's built-in `--dart-define` suffices — Key Design Decision 6), any state-management package beyond what already exists (no Riverpod/Bloc migration).

---

## 16. Security and Repository Hygiene

- **Nothing new needs to be added to `.gitignore`.** The MML API key is never written to a file inside the repository at all (it exists only as a `--dart-define` value supplied on the command line at build time); there is no `.env`-style file this design introduces that would need excluding.
- **No real API key value appears anywhere in this document, in any test, fixture, screenshot, or log produced by this milestone.** Tests use `MmlConfig` with no key supplied (exercising the "missing configuration" path, which is also the default/safe state for `flutter test`) or a synthetic placeholder string where a non-empty key is needed to exercise `MmlStyleFactory`'s URL construction (e.g. `'test-key'`) — never a real credential.
- **Developer setup:** documented in [§8](#8-mml-api-key-configuration) (the exact flag, variable name, and example command); a short pointer to this should be added to the project's developer-facing documentation post-implementation (see [§17](#17-documentation-impact)).
- **CI/release builds** supply the real key via whatever secret-injection mechanism the build environment already uses, interpolated into the same `--dart-define=MML_API_KEY=...` flag — no new secret-storage product is mandated by this design.
- **The key is not treated as if it were cryptographically secret** (see Key Design Decision 6/[§8](#8-mml-api-key-configuration)) — hygiene here means "never committed, never logged, never pasted into a doc," not "impossible for a determined actor to extract from a shipped binary," which is an accepted, ADR-0008-acknowledged trade-off of the direct-to-MML architecture.

---

## 17. Documentation Impact

To be updated **after** implementation (not during this TD, and not marking any feature complete prematurely):

- `README.md` — mention selectable MML base maps under "Status"/feature list, once shipped.
- `docs/project-status.md` — add MFS-026/TD-026 to the Completed lists, and the new `core/map` files to "Current Application Structure," following this project's existing convention of updating this file only once a milestone is actually validated.
- `docs/roadmap.md` — remove/update whichever "richer maps" reference this milestone now satisfies, consistent with its own maintenance rules.
- A short **local development setup note** naming the `MML_API_KEY` `--dart-define` flag ([§8](#8-mml-api-key-configuration)) — likely a new, small section in `docs/development-rules.md` or a dedicated setup doc; exact placement is an implementation-time documentation decision, not fixed here.
- `docs/database.md` — no change expected (no schema impact), but worth a pass to confirm it does not need a line noting the new, non-Drift, non-database preference now exists.

---

## 18. Implementation Order

1. `core/map/base_map.dart`, `mml_config.dart` (no external dependency, unblocks everything else).
2. `core/map/base_map_preference_store.dart` (+ add `shared_preferences` to `pubspec.yaml`) and its tests.
3. `core/map/mml_style_factory.dart` and its tests, using the WMTS mechanics already confirmed in [§0](#0-pre-implementation-verification-completed) (matrix set, zoom range, tile size, `{z}/{y}/{x}` order, per-layer extension) — no further capabilities-XML lookup needed before writing this file.
4. `MapScreen` changes: initialization-timing loading gate ([§4](#4-persistence)), the `_styleGeneration`/`_markersRestoredForGeneration` fix ([§5](#5-maplibre-style-lifecycle--the-fix)), and the switching mechanism ([§6](#6-base-map-switching-mechanism)) — verify against the existing `map_screen_test.dart` suite continuously.
5. `base_map_layers_control.dart`, `base_map_selector_panel.dart`, `map_attribution.dart` and their tests.
6. Wire the new widgets into `MapScreen.build()`'s `Stack`.
7. Preview asset placeholders (simple generic artwork, per [§11](#11-preview-assets)) and the `pubspec.yaml` `assets:` entry.
8. Full regression pass: existing `map_screen_test.dart` cases, fishing-spot repository/widget tests, and the physical Android checklist ([§12](#12-testing-strategy)).
9. Documentation updates ([§17](#17-documentation-impact)).

---

## 19. Validation / Definition of Done

- `flutter analyze` passes.
- All new and existing automated tests pass, including the full pre-existing suite (no regression in fishing spots, catches, statistics, lure catalog, tackle box, or catch search).
- Physical Android testing checklist ([§12](#12-testing-strategy)) completed.
- No real MML API key appears anywhere in the diff.
- All WMTS service-mechanics values in [§0](#0-pre-implementation-verification-completed) are already confirmed as of this document — no capabilities-XML lookup remains before or during implementation. A one-time manual sanity check (request one real Maastokartta tile and one real Ortokuva tile using the confirmed template and visually confirm correct, unmirrored Finnish geography) is still good practice during implementation, as a check on the *code* correctly reproducing this document's already-confirmed values — not as a further verification of the values themselves.
- The two remaining `maplibre_gl` plugin-API items in [§0](#0-pre-implementation-verification-completed) (inline-JSON `styleString` support; style-load-error callback) have been checked against the installed package version, and `MmlStyleFactory`'s delivery mechanism adjusted per [§3](#3-mml-wmts-integration)'s documented fallback if needed.
- Architecture review confirms no schema/migration impact, no new architectural layer beyond `core/map`'s plain concrete classes, and that `MapControls`/other features remain untouched.

---

## Non-Goals

Restated explicitly, per the task brief's scope constraints — none of the following is introduced, designed, or stubbed by this document:

- Depth contours, hillshade, or any other map overlay's real functionality (the selector's structure only leaves *room* for future overlay entries — [§7](#7-selector-ux-implementation) — nothing overlay-specific is implemented).
- Offline map support or offline tile caching.
- Additional base-map providers beyond MML.
- MML vector maps or any custom Fishing App vector styling.
- A backend/proxy service.
- A generalized map-provider plugin architecture.
- Any Riverpod/Bloc/state-management migration.
- Any refactoring of `MapScreen` unrelated to this milestone's own requirements.

---

## Implementation Notes

This section is intentionally left for whoever implements TD-026 to fill in (deviations found during implementation, physical-testing outcomes, and the resolution of the two remaining `maplibre_gl` plugin-API items noted in [§0](#0-pre-implementation-verification-completed)) — following this project's existing convention of recording implementation notes in the TD itself once work is underway. Nothing is recorded here yet, since this document precedes implementation.
