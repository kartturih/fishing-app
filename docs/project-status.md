# Project Status

## Last Updated

2026-08-05 (Lure Catalog Expansion & Data Management: implementation + architecture review + review fixes)

---

## Current Phase

Fishing Spot management is complete. Catch management foundation is complete. Catch Photos is implemented and validated. Catch Details View is implemented and validated. Lure Catalog Foundation (MFS-015 / TD-015) is implemented, architecture-reviewed, and validated. Personal Tackle Box Foundation (MFS-016 / TD-016) is implemented, architecture-reviewed, and validated. Assign Lure to Catch (MFS-017 / TD-017) is implemented, architecture-reviewed, and validated. Lure Catalog UX Improvements (MFS-018 / TD-018) is implemented, architecture-reviewed, and validated. Lure-Based Catch Statistics (MFS-019 / TD-019) is implemented, architecture-reviewed, and validated. General Catch Statistics (MFS-020 / TD-020) is implemented, architecture-reviewed, and validated. Species Statistics (MFS-021 / TD-021) is implemented, architecture-reviewed, lifecycle-reviewed, and validated. Fishing Spot Statistics (MFS-022 / TD-022) is implemented, architecture-reviewed, lifecycle-reviewed, and validated. Catch Notes (MFS-023 / TD-023) is implemented, architecture-reviewed, and validated. Water Bodies and Fishing Spot Hierarchy (MFS-024 / TD-024) is implemented, architecture-reviewed, and validated. Catch Search & Filtering (MFS-025 / TD-025) is implemented, architecture-reviewed, and validated. Selectable MML Base Maps (MFS-026 / TD-026, backed by ADR-0008) is implemented, architecture-reviewed, and validated. Worldwide Base-Map Coverage (MFS-027 / TD-027, backed by ADR-0008/ADR-0009) — MML v21 vector plus MapTiler worldwide fallback, and the SYKE bathymetry overlay with depth labels — is implemented and physically validated.

The application now supports full offline CRUD operations for both Fishing Spots and Catches, photo attachments on Catches, a dedicated read-only Catch Details view with a swipeable photo gallery, a shared Lure Catalog with search and filtering browsed by lure model (with a per-model Color Variants view), a Personal Tackle Box that lets an angler track which catalog lures they actually own with an optional personal photo per owned lure, the ability to assign one of those owned lures to a Catch shown in Catch Details, an optional free-form note per Catch, and a Statistics feature with two tabs: Catches (general catch statistics — a Top 3 Largest Catches "Hall of Fame," total catches, most caught species, a full per-species catch-count list, and a full per-fishing-spot catch-count list, computed live across the angler's entire catch history) and Lure Statistics (most successful lure, most successful lure type, a per-lure catch-count list, and a per-lure-type breakdown, computed live from existing catch and lure catalog data) — neither tab persists any new aggregate. Tapping a species in the Catches tab's Species List opens a pushed Species Statistics page (MFS-021) for that species, and tapping a fishing spot in the Catches tab's Fishing Spot List opens a pushed Fishing Spot Statistics page (MFS-022) for that spot: each shows its own total catch count, a Record Catch card, and its full Catch List (reusing the existing Catch list row) — Fishing Spot Statistics additionally shows a Species Breakdown and a Last Catch Date. Each entry opens the existing Catch Details view; returning refreshes both the page itself and the Catches tab it was opened from automatically. Catch Notes (MFS-023) lets an angler attach one optional, multiline, plain-text note (up to 1000 characters) to a Catch, editable during Add Catch and Edit Catch and shown as the final, selectable section of Catch Details when present. Water Bodies and Fishing Spot Hierarchy (MFS-024) introduces `WaterBody` as a new parent concept above `FishingSpot`: every fishing spot now belongs to exactly one water body, selected or created while adding the spot (with locally computed nearby-water-body suggestions), changeable afterward from Fishing Spot Details, and manageable from a minimal Water Body management surface (view, rename, member fishing spots, empty-only deletion). Every fishing spot that existed before this milestone was automatically migrated into its own correctly named water body (schema version 7 to 8), with all existing data intact. Species Statistics' Record Catch card now shows the water body instead of the exact fishing spot name; every other exact-fishing-spot-scoped view is unchanged. Catch Search & Filtering (MFS-025) adds a global catch-browsing page, reached from a new `MapScreen` AppBar entry, with an always-visible debounced text search (species, water body, fishing spot, lure brand/model) and a filter bottom sheet (water body, species, lure, date range); each result reuses the existing `CatchListItem` (additively extended) and opens the existing, unmodified Catch Details view. No new database table, column, or schema version. Selectable MML Base Maps (MFS-026) replaces the map's placeholder demo style with two real, switchable Finnish base maps from Maanmittauslaitos — Maastokartta (topographic) and Ilmakuva (aerial imagery) — reachable from a new compact upper-right layers control, with the selection persisted across restarts and every existing map capability (fishing-spot markers, labels, tap interaction, adding spots, location controls, other entry points) surviving a base-map switch with no need to leave and reopen the Map screen.

**MFS-026 (Selectable MML Base Maps) is implemented, architecture-reviewed, and validated.** **Worldwide Base-Map Coverage (MFS-027 / TD-027), including the SYKE bathymetry overlay and its depth labels, is implemented, `flutter analyze`-clean, fully covered by the automated test suite, and physically validated on Android — see the Base Maps and SYKE Bathymetry Overlay sections below. Committed and pushed (`0673b61`, `6a6cca4`).** **Lure Catalog Expansion & Data Management (MFS-028 / TD-028) is implemented, architecture-reviewed (verdict: Ready after small fixes — all required fixes and small findings have since been applied), `flutter analyze`-clean, fully covered by the automated test suite, and physically validated on Android. Ready for commit; see Next Planned Task.**

---

## Completed

### Project Foundation

* Git repository initialized
* GitHub repository connected
* Initial project documentation created
* Flutter project initialized
* Android development environment configured
* Riverpod integrated
* GoRouter integrated
* Feature-first project structure established
* Material 3 theme implemented
* Initial design token system created

### Architecture Decision Records

* ADR-0001: Project Architecture
* ADR-0002: Map Technology
* ADR-0003: Core Services
* ADR-0004: Fishing Spot Domain
* ADR-0005: Local Persistence
* ADR-0006: Database Ownership
* ADR-0007: Water Body Domain
* ADR-0008: Base Map Provider and Delivery

### Feature Specifications

* MFS-001: Map Feature
* MFS-002: Map Controls
* MFS-003: User Location
* MFS-004: Fishing Spot Foundation
* MFS-005: Create Fishing Spot
* MFS-006: Local Persistence
* MFS-007: Edit Fishing Spot
* MFS-008: Delete Fishing Spot
* MFS-009: Catch Foundation
* MFS-010: Add Catch
* MFS-011: View Catches
* MFS-012: Edit & Delete Catch
* MFS-013: Catch Photos
* MFS-014: Catch Details View
* MFS-015: Lure Catalog Foundation
* MFS-016: Personal Tackle Box Foundation
* MFS-017: Assign Lure to Catch
* MFS-018: Lure Catalog UX Improvements
* MFS-019: Lure-Based Catch Statistics
* MFS-020: General Catch Statistics
* MFS-021: Species Statistics
* MFS-022: Fishing Spot Statistics
* MFS-023: Catch Notes
* MFS-024: Water Bodies and Fishing Spot Hierarchy
* MFS-025: Catch Search & Filtering
* MFS-026: Selectable MML Base Maps
* MFS-027: Worldwide Base-Map Coverage (includes the SYKE bathymetry overlay and depth labels)

### Technical Designs

* TD-003: User Location Implementation
* TD-004: Fishing Spot Foundation Implementation
* TD-005: Create Fishing Spot Implementation
* TD-006: Local Persistence Implementation
* TD-007: Edit Fishing Spot Implementation
* TD-008: Delete Fishing Spot Implementation
* TD-009: Catch Foundation Implementation
* TD-010: Add Catch Implementation
* TD-011: View Catches Implementation
* TD-012: Edit & Delete Catch Implementation
* TD-013: Catch Photos Implementation
* TD-014: Catch Details View Implementation
* TD-015: Lure Catalog Foundation Implementation
* TD-016: Personal Tackle Box Foundation Implementation
* TD-017: Assign Lure to Catch Implementation
* TD-018: Lure Catalog UX Improvements Implementation
* TD-019: Lure-Based Catch Statistics Implementation
* TD-020: General Catch Statistics Implementation
* TD-021: Species Statistics Implementation
* TD-022: Fishing Spot Statistics Implementation
* TD-023: Catch Notes Implementation
* TD-024: Water Bodies and Fishing Spot Hierarchy Implementation
* TD-025: Catch Search & Filtering Implementation
* TD-026: Selectable MML Base Maps Implementation
* TD-027: Worldwide Base-Map Coverage Implementation (includes the SYKE bathymetry overlay and depth labels)

---

## Implemented Features

### Map

* MapLibre integrated
* Interactive map
* Finland initial camera
* Pan and zoom
* Physical Android support
* GeoJSON-based fishing spot rendering

### Base Maps

* Two selectable base maps — Maastokartta (topographic) and Ilmakuva (aerial imagery) — replacing the previous hardcoded MapLibre demo style, each now with real worldwide coverage (MFS-027/TD-027, ADR-0009; supersedes MFS-026's original MML-only raster delivery, ADR-0008's raster-WMTS choice revised for Maastokartta by TD-027 Revision 7)
* **Maastokartta:** MML's own official v21 **vector** tiles for Finnish cartography (fetched via a local, on-device loopback proxy that fetches MML's real style/tiles/glyphs and strips the API key before anything reaches MapLibre — never a raster tile-masking process, which was fully retired), with MapTiler Outdoor as an always-present worldwide underlay beneath it
* **Ilmakuva:** MapTiler Satellite Hybrid as the complete worldwide base map (MML Ortokuva is not used in this milestone — a deliberate product decision, ADR-0009)
* Maastokartta as the default for a user with no saved selection
* Compact, upper-right floating layers control (`FloatingActionButton.small`), opening a compact anchored selector, unchanged in UX from MFS-026
* Immediate, save-free switching between the two base maps, with the selection persisted across restarts (`shared_preferences`)
* Existing fishing-spot markers, labels, tap interaction, adding fishing spots, location controls, and every other `MapScreen` entry point survive a base-map switch, including the very first (cold) style load
* Required attribution (MML, MapTiler, and SYKE — see below) via a compact, tap-to-expand panel
* Non-technical, calm Finnish-language handling of missing/invalid credentials and load timeouts for either provider; no crash, no technical detail ever exposed
* MML and MapTiler API keys supplied only via `--dart-define`; never committed, logged, or hardcoded anywhere in the repository
* No offline maps, no additional base-map providers, and no custom MapTiler style — explicitly out of scope

### SYKE Bathymetry Overlay

* National lake/river depth-contour overlay (SYKE "Järvien ja jokien syvyysaineisto," CC BY 4.0), layered above the active base map and below application-owned layers (fishing-spot markers), for **both** Maastokartta and Ilmakuva (MFS-027/TD-027 Revision 7, finalized Revision 8)
* Fully offline: a single preprocessed national MBTiles file bundled as an app asset, served through the same local loopback listener used for MML — no live SYKE WFS request from the running app, ever
* Contour lines shipped **completely unsimplified** — full source vertex precision at every zoom; the only geometry transformation applied is per-tile MVT clipping, a product decision made after physical Android testing found even an adaptive, size-aware simplification tolerance still visibly too angular
* Tiled z10–z14 (a contiguous range, no gaps), with zooms 15–18 served by MapLibre's own standard vector-source overzoom; contour lines presented from `minzoom` 10
* Depth-area (fill) polygons are bundled but not rendered — physical testing found the fill visually competing with the base map's own lake rendering; contour lines only ship, in the spirit of a traditional topographic map
* Depth labels (`"<depth> m"`, e.g. `1.5 m`, `10 m`) trace each contour line directly, reading the same `depth_m` MVT attribute already used for line rendering — no MBTiles/pipeline change needed; shown from `minzoom` 12, excluding the `0 m` shoreline contour; a font-selection defect (found in physical testing — the label layer fell back to a combined default font stack unavailable on either glyph host this app uses) was root-caused and fixed by resolving a single verified-working font per the active style's glyph host, mirroring the same pattern already used for fishing-spot labels
* Content-aware, version-sidecar-based extraction invalidation on-device: a stale, previously-extracted MBTiles copy is never silently reused after the bundled asset is updated (a confirmed physical-device bug, fixed and covered by a dedicated regression test suite)
* Physical Android testing completed: contour geometry fidelity, continuous rendering across the tiled zoom range, close-zoom (overzoom) rendering, and depth-label rendering/sizing/spacing all accepted as shipped

### Map Controls

* Current Location button
* Add Fishing Spot button
* Settings button
* Selection mode controls

### User Location

* LocationService
* Permission handling
* Current location retrieval
* Camera centering
* User location layer
* Graceful error handling

### Fishing Spots

* Framework-independent FishingSpot domain model
* Drift persistence
* Repository pattern
* GeoJSON-backed marker rendering
* Marker labels
* Automatic loading on application startup
* Persistent offline storage

### Fishing Spot Management

* Create from current location
* Create from map
* Crosshair map selection
* Fishing spot naming
* Edit fishing spot names
* Delete fishing spots
* Delete confirmation dialog
* Immediate marker updates
* Immediate marker removal
* Persistent CRUD operations

### Water Bodies

* Framework-independent `WaterBody` domain model (identity only — id, name, createdAt — no depth/species/vegetation/weather metadata, per ADR-0007/MFS-024's fixed scope), owned by the existing `fishing_spots` feature rather than a new feature directory
* Drift persistence (schema migrated from version 7 to version 8: new `water_bodies` table, `waterBodyId` foreign key added to `fishing_spots` with `onDelete: KeyAction.restrict`)
* Existing-data migration: every `FishingSpot` that existed before this milestone automatically received its own correctly named `WaterBody` (named identically to that spot's current name), with no data loss and no angler action required
* `FishingSpot.waterBodyId` is non-nullable at the domain level (schema-level nullable is a SQLite `ADD COLUMN` technical necessity only); the mapper fails loudly (`StateError`) rather than silently if the invariant is ever violated
* Concrete `WaterBodyRepository` (create, rename, list, delete-when-empty, member-fishing-spot lookup, and a locally computed nearby-water-body ranking using the haversine great-circle distance formula over already-stored coordinates — no network access, no external dataset)
* Water-body selection/creation step inserted into both existing fishing-spot-creation paths (current location and map selection); nearby candidates are shown before the full browsable list, with a single clearly relevant candidate optionally preselected and always changeable
* "Vaihda vesistö" (change water body) action added to the existing Fishing Spot Details bottom sheet, alongside its existing rename/delete actions; changing a fishing spot's water body does not alter its coordinates, name, or catch history
* Minimal Water Body management surface (`WaterBodyManagementPage`): view every water body with its fishing-spot count, rename, expand to see member fishing spots, and delete once empty
* A water body containing one or more fishing spots cannot be deleted (enforced by the repository, with `KeyAction.restrict` as a database-level backstop); an empty water body can be deleted with confirmation
* Deleting a fishing spot is unaffected by this milestone and continues to cascade-delete its catches exactly as before
* Species Statistics' Record Catch card now shows the water body name, not the exact fishing spot name, in its location line; `SpeciesCatchEntry` retains its `fishingSpot` field so Catch Details navigation is unaffected
* Fully offline; no new external dependencies
* Deferred, documented deviation: MFS-024 FR-17's gentle, non-blocking post-migration reorganization hint (the hint text/UI only) was postponed per TD-024 Key Design Decision 8, since this project has no production users yet; recommended before any release to real external users

### Catch Management

* Framework-independent Catch domain model
* Drift persistence
* Repository pattern
* Add catches to fishing spots
* View catches for fishing spots
* Edit catches
* Delete catches
* Species selection
* Optional weight tracking
* Optional length tracking
* Catch date and time selection
* Immediate UI updates
* Persistent offline CRUD operations
* Optional lure assignment: a `Catch` may reference one owned `LureVariant` (schema migrated from version 5 to version 6, `lureVariantId` column on `catches`), assignable/changeable/removable from Add Catch and Edit Catch via the existing Personal Tackle Box browsing view
* The assigned lure survives its `TackleBoxEntry` being later removed from the Personal Tackle Box, and remains resolvable even if the underlying catalog variant is later retired
* Assigned lure shown read-only in Catch Details (manufacturer, model, distinguishing color/variant detail); a catch with no assigned lure renders cleanly
* Optional per-catch notes: a `Catch` may carry one optional, multiline, plain-text note up to 1000 characters (schema migrated from version 6 to version 7, nullable `notes` column on `catches`), editable in Add Catch and Edit Catch; leading/trailing whitespace is trimmed, internal whitespace and line breaks are preserved, and a whitespace-only note is stored as `null`; over-limit input blocks saving with a Finnish validation message while `CatchRepository` independently re-validates and normalizes as the defensive authority; shown as the final, selectable section of Catch Details when present, omitted entirely when absent

### Catch Photos

* Framework-independent CatchPhoto and PendingCatchPhoto domain models
* Drift persistence (schema version 3, `catch_photos` table, cascade delete from Catches)
* Concrete CatchPhotoRepository (ID generation, sort order, max 5 per Catch, storage/database failure cleanup)
* Application-owned photo storage (`getApplicationDocumentsDirectory`), never a cache directory
* Image processing: orientation correction, downscale to a 2048px longest side (no upscaling), JPEG re-encode at quality 85
* Camera and gallery selection (source-selection dialog, not a nested Bottom Sheet)
* Temporary photo handling during Add Catch (no permanent files/rows before the Catch exists)
* Persistent photo handling during Edit Catch, including confirmed deletion
* Full-screen photo viewer as a normal page (`MaterialPageRoute`), using a `PageView` with a per-page `TransformationController`
* Zoomed photos support one-finger panning in all directions (the `PageView` yields to the `InteractiveViewer` while the current photo is zoomed)
* Page navigation is handed off to the next/previous photo when dragging outward beyond the zoomed image's pan boundary
* Missing/corrupt file placeholders
* Catch deletion cleans up associated photo files before the Catch row is removed
* Partial photo failures never roll back a successfully saved/updated Catch

### Catch Details

* Dedicated read-only Catch Details page (`CatchDetailsPage`), pushed as a normal full-screen page rather than a Bottom Sheet
* Catch List → Catch Details → Edit Catch navigation, with Back/Android-back returning to the Catch list
* Catch list items display a photo thumbnail (or placeholder) alongside species, measurements, and date/time
* Catch information formatting (weight, length, date/time) shared through `catch_formatters.dart`
* Edit and Delete actions available from an overflow menu; Edit reuses the existing Edit Catch editor, Delete reuses the existing confirmation and photo-cleanup flow
* Swipeable 4:3 photo gallery (`PageView`) with a bottom-left page indicator
* `BoxFit.cover`-cropped gallery previews, centered, over a soft dark background
* Full-screen photo viewer reused unchanged for the complete, uncropped image
* Pinch-to-zoom and one-finger panning while zoomed, inherited from the shared photo viewer
* Previous/next photo navigation through edge overdrag while zoomed
* Missing/corrupt image handling
* Immediate UI updates after edits and deletion

### Catch Search & Filtering

* Global catch-browsing/search page (`CatchSearchPage`), reached from a new `MapScreen` AppBar entry (`Icons.search`, tooltip "Etsi saaliita"), following the same established navigation pattern as the Lure Tools and Statistics entries
* Always-visible text search, debounced (~280 ms), matching species (Finnish display name), water body name, fishing spot name, lure brand, and lure model/name — case-insensitive, partial-match, whitespace-trimmed, with no separate submit action
* Search-field clear ("X") button, shown only while the field has text, that clears the query and refreshes results immediately without waiting for the debounce, while preserving any active filters; tapping the field focuses it immediately
* Filter bottom sheet (water body, fish species, lure, date range), single-select per category, combined with the active text search and with each other via AND semantics; the filter icon visibly indicates when a filter is active
* Concrete `CatchSearchRepository` (a new sibling to `CatchRepository`, not a change to it) performing one joined query directly against `catches`/`fishing_spots`/`water_bodies`/`lure_variants`/`lure_models`; species/water-body/fishing-spot text matching is resolved via a bounded, in-memory scan (never a scan of the catch history itself), while lure-name matching reuses the Lure Catalog's own precomputed `searchText` columns directly — deliberately not through `LureCatalogRepository.browse()`, so a catch's assigned lure remains searchable even after the underlying catalog variant is later retired
* Each result is fully enriched (fishing spot, water body, and resolved lure when present) with no additional per-row repository call; `CatchListItem` is extended additively (optional water body/fishing spot/lure display lines) with no change to any existing caller
* Tapping a result opens the existing, unmodified Catch Details view; returning preserves the active search text and filters and refreshes the result list
* No new database table, column, index, or schema version; schema remains at version 8
* Fully offline; no new external dependencies

### Lure Catalog

* Framework-independent `LureModel`/`LureVariant` domain models, joined into a flat `LureCatalogEntry` read model for all UI-facing queries
* Drift persistence (schema migrated from version 3 to version 4: `lure_models` and `lure_variants` tables, with FK cascade delete and indexes on manufacturer/lureType/lureModelId)
* Concrete, read-only `LureCatalogRepository` (no create/update/delete operations exposed — the catalog is shared reference data, not user-owned data)
* Versioned, idempotent seed reconciliation (`ensureSeeded()`): inserts missing seed rows, corrects stale seed-owned rows while preserving `createdAt`, and never modifies a row whose `seedVersion` is `null`
* Variant retirement (soft-delete via `retiredAt`) instead of deletion, with automatic reactivation if a variant reappears in a later seed version
* Browse, search, and filter by manufacturer and lure type, backed by a single joined query (no N+1)
* Finnish (ä/ö) case-insensitive search via precomputed, Dart-lowercased `searchText` columns
* Free-text search treats `%` and `_` as literal characters, not SQL wildcards
* Filter options (manufacturer/lure type) only ever list values with at least one currently active (non-retired) variant
* Open, extensible lure type/buoyancy codes with Finnish display labels and a humanized fallback for unrecognized values
* Lure Catalog browsing list groups by lure model (one row per model, not per color variant), with a "fully owned" badge/hide-owned filter requiring every non-retired variant of a model to be owned
* Lure Model Details view: model-level information (manufacturer, model, product family, lure type) shown once, followed by a lazily-rendered Color Variants list (image, color, length, weight, owned indicator, add action per variant)
* Opening a model's details always shows its complete, unfiltered variant set — regardless of what search/filter was active on the browsing list — via a dedicated `LureCatalogRepository.getVariantsForModel()` query, unaffected by search/filter state
* Full single-variant detail (including running depth, buoyancy, manufacturer color code) remains reachable by tapping a Color Variant row
* Lure Catalog list and details pages, with loading/empty/error states and image-load fallback to a placeholder
* A small, hand-authored local seed dataset (4 models, 14 variants) — local-seed-only in this milestone; no network access, cloud sync, or user-created entries. **Superseded by Lure Catalog Expansion & Data Management (MFS-028) below**: the catalog's content source and import mechanism have since changed; every other bullet above (domain models, schema, repository query methods, browsing/search/filter/details UX) is unchanged.

### Lure Catalog Expansion & Data Management

* Replaces the hand-written Dart seed literals with a structured, offline authoring pipeline (MFS-028 / TD-028): per-manufacturer JSON source files under `assets/lure_catalog/source/` (not bundled with the app), validated and merged by a new developer-run Python tool (`tools/lure_catalog/build_catalog.py`, following the existing `tools/syke_bathymetry/` precedent) into one bundled, deterministic, versioned asset, `assets/lure_catalog/catalog_v1.json`
* `LureCatalogRepository.ensureSeeded()` generalized to reconcile against the bundled asset instead of Dart literals: loads it via a new `LureCatalogAssetLoader`, short-circuits via a new `shared_preferences`-backed `LureCatalogVersionStore` fast-path cache (modeled on the existing `BaseMapPreferenceStore`) when nothing has changed, and otherwise reconciles inside one atomic transaction using two batched full-table reads and a single batched write — insert new / correct catalog-owned rows in place / retire (never delete) removed variants / never touch a row whose `seedVersion` is `null`, exactly the same rules as before, generalized rather than replaced
* `lure_catalog_seed_data.dart` deleted; the one-time transition to the new asset was verified to be a lossless, zero-write no-op against an already-seeded database (same manufacturers, models, variants, and ids as the original 4-model/14-variant seed — catalog content itself is unchanged in this milestone, only its authoring/import mechanism)
* No database schema or migration change: `LureModels`/`LureVariants` are untouched; schema remains at version 8
* Existing `TackleBoxEntry`/`Catch` references to a catalog variant, and existing search/filter/browse behavior and Lure Statistics, verified unaffected by a catalog content update
* Architecture-reviewed (verdict: Ready after small fixes); every required fix and small finding from that review has been applied: `ensureSeeded()` decomposed into small, named planning/apply helpers; three independently-duplicated test-double classes consolidated into one shared `test/support/lure_catalog_test_doubles.dart`; a new automated test keeps `tools/lure_catalog/known_lure_types.json` and `lure_type_labels.dart`'s known codes in sync; stale "seed data" wording corrected in `lure_catalog_mapper.dart`
* Fully offline; no new external dependencies (the Python tooling uses only the standard library)
* `flutter analyze` clean; full automated test suite passing
* Physical Android testing completed: catalog loading, search and filtering, model/variant browsing, adding/removing an owned lure, owned status persisting across a restart, assigning a lure to a catch, Catch Details lure resolution, lure statistics resolution, airplane-mode operation, and no row duplication across repeated app launches were all verified on a physical device. **Ready for commit.**

### Personal Tackle Box

* Framework-independent `TackleBoxEntry` domain model and `TackleBoxItem` joined read-model, reusing `lure_catalog`'s `LureCatalogEntry` by reference rather than copying catalog data
* Drift persistence (schema migrated from version 4 to version 5: `tackle_box_entries` table, `onDelete: KeyAction.restrict` foreign key to `lure_variants`, unique constraint on `lureVariantId`)
* Concrete `PersonalTackleBoxRepository` performing its own three-table join (`tackle_box_entries` ⨝ `lure_variants` ⨝ `lure_models`), reusing `lure_catalog`'s existing mapper — one query per screen, no N+1
* Duplicate-ownership prevention enforced at both the UI (`isOwned` pre-check) and database (unique constraint) layers
* Explicit "Add to Tackle Box" action reachable per-variant from the Lure Catalog's Color Variants list via a small optional passthrough parameter added to that feature's presentation layer only — the Lure Catalog's domain, data, and repository remain unmodified and fully read-only
* `AddToTackleBoxAction` accepts an optional `initialIsOwned` parameter so a caller that already knows a variant's owned state (e.g. rendering many rows from one already-loaded set) can skip its own `isOwned()` query — avoiding N+1 queries across the Color Variants list; omitted, it queries as before
* Optional personal photo capture (camera or gallery) when adding a lure, explicit "No Photo," or skip entirely; application-owned photo storage mirroring Catch Photos' processing (2048px longest side, JPEG quality 85, atomic write) but with one flat file per entry (no per-entry subdirectory, since at most one photo exists)
* The add-photo dialog distinguishes an explicit "No Photo" choice from a dismissal: tapping outside the dialog, the Android system back gesture, and an explicit Cancel option all cancel the entire add with no `TackleBoxEntry` created — only Camera, Gallery, or explicit "No Photo" complete it
* A narrow, retry-only `attachPhoto` operation lets a user re-attempt a failed photo attach immediately after adding a lure — not a general photo-replace feature
* Personal Tackle Box browsing view grouped by manufacturer, then model, then variant — never a flat one-row-per-variant list
* Owned Entry Detail view: resolved catalog details, personal photo (with fallback to the catalog image), and the Remove action
* Removing an owned entry requires confirmation and deletes both its database row and its personal photo file
* A `TackleBoxEntry` referencing a retired catalog variant remains fully visible, viewable, and removable
* Fully offline; no new external dependencies

### Statistics

* `statistics` feature with two tabs: **Catches** (general catch statistics, MFS-020, first/default tab) and **Lure Statistics** (MFS-019, second tab, functionally unchanged by MFS-020 other than its tab position)
* A pushed **Species Statistics** page (MFS-021), reached by tapping a species row in the Catches tab's Species List — not a third tab
* A pushed **Fishing Spot Statistics** page (MFS-022), reached by tapping a fishing spot row in the Catches tab's new Fishing Spot List — not a third tab
* Every tab/page computes its statistics live on each open; no cached, stored, or persisted aggregate of any kind anywhere in the feature
* Reachable via a new, temporary `MapScreen` AppBar entry point, following the same pattern already established for the Lure Catalog and Personal Tackle Box
* No new database table, column, schema version, or migration from any tab or page — schema remains at version 6
* Fully offline; no new external dependencies

#### Lure Statistics (MFS-019)

* Framework-independent `LureCatchStatistic`, `LureTypeCatchStatistic`, and `LureStatisticsSummary` read-model types; `lure_catalog`'s `LureCatalogEntry` reused by reference, never duplicated
* Concrete, read-only `LureStatisticsRepository` performing its own join directly against `catches`/`lure_variants`/`lure_models` (two plain queries — one count, one joined select — no SQL `GROUP BY`), reusing `lure_catalog`'s existing `LureCatalogMapper.entryFromRows()`
* Deterministic tie-breaking (manufacturer → model → distinguishing detail → id for lures; lure type code for lure types), so ranking never varies across runs
* Statistics reflect full catch history independent of current Personal Tackle Box membership: removing a `TackleBoxEntry` never changes a lure's catch count
* Retired catalog variants and unresolvable lure references are handled without special-casing or crashing
* Two summary cards (most successful lure, most successful lure type), a per-lure catch-count list, and a per-lure-type catch-count breakdown
* Summary cards redesigned after physical Android testing: the original three-card row (including a total-linked-catches count) was replaced with two full-width, stacked cards for the two ranking statistics, improving readability for long lure names — a presentation-only refinement with no change to computed data or repository behavior

#### General Catch Statistics (MFS-020)

* Framework-independent `LargestCatch`, `SpeciesCatchStatistic`, and `GeneralCatchStatisticsSummary` read-model types; `catches`' own `Catch` and `fishing_spots`' own `FishingSpot` reused by reference, never duplicated
* Concrete, read-only `GeneralCatchStatisticsRepository` performing one joined query directly against `catches`/`fishing_spots` (`Catches.fishingSpotId` is a required foreign key, so the join never excludes a row), reusing `catches`' existing `CatchMapper` and `fishing_spots`' `FishingSpotEntityMapper`
* Statistics span the angler's entire catch history across every fishing spot, not one fishing spot at a time — the first Statistics view to do so
* Deterministic tie-breaking (weight → caughtAt → createdAt → id for largest catches; catch count → species identifier for species), so ranking never varies across runs
* Top 3 Largest Catches: the three catches with the greatest recorded weight, descending; a catch with no recorded weight is never included
* Two summary cards, rendered at equal height (total catches, most caught species — species name as the primary value, catch count as secondary text)
* A full Species List (species and catch count, sorted by catch count descending); rows were visually prepared for a future per-species statistics page (now delivered by MFS-021 — see the Species Statistics subsection below) but performed no navigation and were not exposed to assistive technology as buttons within this milestone's own scope
* Selecting a Top 3 Largest Catches entry opens the existing, unmodified Catch Details view (MFS-014) for that catch
* Presentation redesigned after physical Android testing, entirely within the presentation layer with no change to the repository, domain models, or navigation: each Top 3 entry reuses `catches`' own `CatchListItem` completely unmodified, now presented inside a "Hall of Fame" card with a full gold/silver/bronze medal-colored border and a floating rank badge centered above the card's top border; 1st place has a thicker border, higher elevation, and a subtle warm-tinted background blended from the medal gold onto the theme's own surface color

#### Species Statistics (MFS-021)

* Framework-independent `SpeciesCatchEntry` (a `Catch` paired with its `FishingSpot`, unlike `LargestCatch` allowing no recorded weight) and `SpeciesStatisticsSummary` (a species plus its full, already-sorted catch list, with `totalCatches`/`recordCatch` as derived getters) read-model types
* Concrete, read-only `SpeciesStatisticsRepository` performing one species-filtered joined query directly against `catches`/`fishing_spots`, resolving every returned catch's fishing spot (not only the Record Catch's), so any Catch List entry can open Catch Details with no additional lookup
* Deterministic ordering: recorded weight descending (a catch with no recorded weight sorts after every catch that has one), then catch date descending, then catch id ascending — applied to both the Record Catch and the full Catch List, since the Record Catch is simply the first entry of that same ordered list, never separately computed
* Wires up the navigation MFS-020's Species List rows were built to anticipate: rows are now real, tappable buttons (explicit `Semantics(button: true)`, added after a widget test showed `InkWell` alone does not expose button semantics) opening the new page for that species
* `SpeciesStatisticsPage`, pushed via the existing `Navigator.push`/`MaterialPageRoute` pattern (mirroring `CatchDetailsPage.open()`), shows a total-catches summary card, a `RecordCatchCard` (photo, weight/length, date, and water body — each rendering cleanly when absent), and a full Catch List reusing `CatchListItem` completely unmodified
* Lifecycle fix found during review: the page previously loaded its summary once, in `initState`, so edits/deletes made from Catch Details were not reflected on return. Fixed by following the existing `FishingSpotDetailsBottomSheet` convention — `await CatchDetailsPage.open(...)`, check `mounted`, then reload — rather than introducing a new navigation-result type or state-management mechanism; covers both the Record Catch card and every Catch List entry from one change
* No new Drift table, column, schema version, or migration; `GeneralCatchStatisticsRepository`, `LureStatisticsRepository`, `LargestCatch`, and `GeneralCatchStatisticsSummary` are unmodified

#### Fishing Spot Statistics (MFS-022)

* A new **Fishing Spot List** within the Catches tab (name and catch count, sorted by catch count descending, ties broken by name then id), tappable from the start — the first list in this feature introduced and wired in the same milestone, rather than shipped inert first
* Framework-independent `FishingSpotCatchStatistic` (a `FishingSpot` paired with its catch count) and `FishingSpotStatisticsSummary` (a fishing spot's full, already-sorted catch list, its species breakdown, and its Last Catch Date, with `totalCatches`/`recordCatch` as derived getters) read-model types
* Concrete, read-only `FishingSpotStatisticsRepository` — the simplest repository in this feature, reading only `Catches` filtered by fishing spot id, no join, since every catch it returns already shares the one fishing spot the calling page already holds
* `GeneralCatchStatisticsRepository`'s existing joined query and aggregation loop extended additively (unconditional `FishingSpot` resolution, a second running count map) to also produce the Fishing Spot List, with no second query
* `SpeciesCatchStatisticRow` generalized in place into `CatchCountRow` (label/catchCount instead of a domain-typed statistic, `onTap` made nullable) — reused for the Species List, the new Fishing Spot List, and the new, deliberately static Species Breakdown, with no change to the Species List's existing visual, semantic, or navigation behavior
* `FishingSpotStatisticsPage`, pushed via the existing `Navigator.push`/`MaterialPageRoute` pattern, shows two summary cards (total catches, Last Catch Date), a `FishingSpotRecordCatchCard` (species, weight/length, date — no location, since the page's own context already is one fishing spot), a static Species Breakdown, and a full Catch List reusing `CatchListItem` completely unmodified
* Deterministic ordering (weight descending, missing-weight-last, catch date descending, catch id ascending) applies unchanged from MFS-021; Last Catch Date is a running maximum of `caughtAt` tracked in the same single pass that builds the Catch List and Species Breakdown, never derived from the (weight-ordered) `catches.first`
* `CatchCountRow`'s trailing chevron made conditional on `onTap` during architecture review — a chevron on the static Species Breakdown would misleadingly imply navigation that does not exist; the Species List and Fishing Spot List, both tappable, are unaffected
* Lifecycle fix found during physical Android testing: `CatchDetailsPage` could pop before its own in-flight delete had completed if the user navigated away independently while it was running (no loading indicator was shown during that window), leaving a caller's post-return reload reading pre-deletion data with nothing to correct it afterward. Fixed with an explicit `CatchDetailsResult` (mirroring `EditCatchResult`'s existing shape) and a `PopScope` guard that blocks back-navigation while a delete is in flight — the underlying `await → mounted → _load()` refresh convention was already correct
* Lifecycle fix found during physical Android testing: `GeneralCatchStatisticsTab` did not reload its own summary after returning from either Fishing Spot Statistics or Species Statistics, leaving its total, Fishing Spot List, and Species List stale until Statistics was closed and reopened. Fixed by applying the same `await → mounted → _load()` pattern already used for Catch Details visits to `_openSpeciesStatistics`/`_openFishingSpotStatistics`, unconditionally rather than only for deletions
* No new Drift table, column, schema version, or migration; `SpeciesStatisticsRepository`, `SpeciesStatisticsPage`, `RecordCatchCard`, and `LureStatisticsRepository` are unmodified; `GeneralCatchStatisticsRepository`'s existing total/Top-3/Species List computation is unchanged in behavior

---

## Validation

Verified on physical Android devices.

### Map

* Map loads correctly
* Pan works
* Zoom works
* Marker rendering verified
* Marker updates verified

### User Location

* Permission flow works
* Camera centers correctly
* Location failures handled correctly

### Fishing Spots

* Fishing spots persist after restarting
* Create from current location works
* Create from map selection works
* Edit works
* Delete works
* Delete confirmation works
* Crosshair mode verified
* Existing markers preserved
* Marker labels update immediately

### Catch Management

* Add Catch verified
* View Catch list verified
* Edit Catch verified
* Delete Catch verified
* Measurement validation verified
* Repository tests completed
* Widget tests completed

### Catch Photos

* Domain, database/migration, storage, and repository tests completed
* Add/Edit Catch and full-screen viewer widget tests completed
* flutter analyze passes; all automated tests pass
* Physical Android testing completed

### Catch Details

* Catch Details navigation verified
* Catch information rendering verified
* Catch list thumbnails verified
* Edit navigation and returned updates verified
* Delete flow verified
* Photo gallery swiping verified
* Portrait and landscape image presentation verified
* Full-screen viewer verified
* Pinch zoom verified
* One-finger zoomed-image panning verified
* Edge navigation between photos verified
* Widget tests completed

### Lure Catalog

* Schema migration (v3 → v4) verified: existing Fishing Spot/Catch/Catch Photo data preserved across the upgrade, new tables usable immediately after
* Domain, database/migration, mapper, search-text, and repository tests completed
* Presentation widget tests completed (list, filter, details, loading/empty/error states)
* Architecture review completed; the 4 Important findings raised (LIKE wildcard escaping, running-depth CHECK constraint, stale out-of-order search results, filter options with no active variants) were all implemented and verified
* flutter analyze passes; all automated tests pass
* Physical Android testing completed

### Personal Tackle Box

* Schema migration (v4 → v5) verified: existing Fishing Spot/Catch/Catch Photo/Lure Catalog data preserved across the upgrade, new `tackle_box_entries` table usable immediately after; verified both in an automated migration test and on a physical Android device
* Domain, database/migration, mapper, storage, and repository tests completed (including `attachPhoto`'s narrow retry behavior and duplicate-prevention at the database layer)
* Presentation widget tests completed (grouped list, owned entry detail, add flow — loading/empty/error states, photo capture, remove confirmation)
* Discovered during widget-test verification: real `dart:io` file operations (photo store/delete) awaited directly inside a `testWidgets()` body hang indefinitely unless wrapped in `tester.runAsync()` — a stricter variant of the real-I/O pattern already used in `edit_catch_bottom_sheet_test.dart`/`catch_photo_viewer_test.dart`
* Architecture review completed; no architectural deviations required in production code
* flutter analyze passes; all automated tests pass
* Physical Android testing completed: add with camera/gallery/no photo, duplicate-add blocked, persistence across the schema-5 migration, remove with file cleanup, airplane mode, both new `MapScreen` entry points

### Assign Lure to Catch

* Schema migration (v5 → v6) verified: `lureVariantId` column added to `catches`, existing data preserved across the upgrade
* Domain, mapper, and repository tests completed for the new optional reference
* Add Catch / Edit Catch widget tests completed: assigning, changing, and removing a lure via the reused Personal Tackle Box picker
* Catch Details rendering verified with and without an assigned lure
* Historical stability verified: removing a `TackleBoxEntry` does not alter a catch that already referenced its `LureVariant`; a retired variant remains resolvable
* flutter analyze passes; all automated tests pass
* Physical Android testing completed

### Lure Catalog UX Improvements

* Lure Catalog browsing list rewritten to group by model (in memory, from the existing `browse()` result); `LureCatalogListItem` renamed and refactored in place to `LureCatalogModelListItem` (no old/new widget left coexisting)
* Lure Model Details (`LureModelDetailsPage`) and the lazily-rendered Color Variants list (`ColorVariantRow`) added; `LureDetailsPage` reused completely unchanged as the full single-variant detail view
* `LureCatalogRepository.getVariantsForModel()` added (a documented TD-018 deviation) so opening a model's details always shows its complete variant set even when the browsing list's active search/filter matched only some of them (FR-6) — verified by a dedicated regression test
* `AddToTackleBoxAction`'s optional `initialIsOwned` parameter lets the Color Variants list render every row's owned state from one already-loaded set, with no per-row query
* Add-photo dialog corrected: tapping outside, the Android back gesture, and an explicit Cancel option all cancel the add with no `TackleBoxEntry` created; only Camera, Gallery, or explicit "No Photo" complete it
* `AutomaticKeepAliveClientMixin` added to `LureCatalogListPage` (a documented TD-018 deviation) — search text, manufacturer filter, hide-owned state, and scroll position all verified to survive switching to the Personal Tackle Box tab and back
* Post-implementation duplication audit completed: no competing grouping logic, navigation path, or leftover pre-refactor widget found
* Architecture review completed; two implementation deviations documented in TD-018 (`getVariantsForModel()`, `AutomaticKeepAliveClientMixin`)
* flutter analyze passes; all automated tests pass
* Physical Android testing completed

### Lure-Based Catch Statistics

* Domain, repository, and widget tests completed, including deterministic tie-break coverage, retired-variant inclusion, historical-stability-after-tackle-box-removal, and a dangling-lure-reference edge case (seeded directly at the SQL layer with foreign key enforcement temporarily disabled, mirroring the technique already established for testing `restrict` foreign keys)
* Architecture review completed; no schema/migration impact, no change to `catches`, `lure_catalog`, or `personal_tackle_box`
* flutter analyze passes; all automated tests pass
* Physical Android testing completed; one UI refinement (removing the total-linked-catches summary card in favor of two full-width ranking cards) was made afterward and re-verified with a full test run

### General Catch Statistics

* Domain, repository, and widget tests completed, including deterministic tie-break coverage for both the Top 3 Largest Catches (weight → caughtAt → createdAt → id) and the Species List (catch count → species identifier), weight-based exclusion (fewer-than-three and zero-weighted-catches cases), and recomputation after a catch is created, edited, or deleted
* Architecture review completed; no schema/migration impact, no change to `catches`, `catch_photos`, `fishing_spots`, `lure_catalog`, or `personal_tackle_box`; `CatchListItem` reused completely unmodified
* flutter analyze passes; all automated tests pass (535/535)
* Physical Android testing completed across three rounds, each re-verified with a full test run afterward: (1) equal-height summary cards and an initial numbered-badge Top 3 redesign; (2) a full "Hall of Fame" redesign — medal-colored card borders, a rank badge floating above and centered on each card's top border, and centered card layout; (3) a brightened gold border and a subtle warm-tinted background for the 1st-place card

### Species Statistics

* Domain, repository, and widget tests completed, including deterministic ordering coverage (weight descending, missing-weight-sorts-last, catch date descending, catch id ascending), Record Catch derivation from the already-sorted list, fishing-spot resolution for every catch (not only the Record Catch), and recomputation after a catch of that species is created, edited, deleted, or reassigned to a different species
* Navigation-wiring tests confirm Species List rows now open Species Statistics for the correct species, and both the Record Catch card and Catch List entries open Catch Details for the correct catch and fishing spot
* Lifecycle review found that the page did not refresh after returning from Catch Details; fixed by reusing the existing `FishingSpotDetailsBottomSheet` reload convention (see the Species Statistics subsection above). Four widget tests cover it directly: an edit reflected on return via the Record Catch card path, a delete reflected on return, a Record Catch/ordering swap reflected on return via the Catch List path, and no `setState` after the page is disposed while a post-return reload is still pending
* Accessibility correction found during testing: `SpeciesCatchStatisticRow` and `RecordCatchCard` needed an explicit `Semantics(button: true)` — an `InkWell` alone does not expose button semantics — verified by a dedicated semantics test
* Architecture review completed; no schema/migration impact, no change to `catches`, `catch_photos`, `fishing_spots`, `lure_catalog`, or `personal_tackle_box`; `GeneralCatchStatisticsRepository`, `LureStatisticsRepository`, `LargestCatch`, and `GeneralCatchStatisticsSummary` unmodified; `CatchListItem` reused completely unmodified
* flutter analyze passes; all automated tests pass (575/575)
* Physical Android testing completed

### Fishing Spot Statistics

* Domain, repository, and widget tests completed, including deterministic ordering coverage (weight descending, missing-weight-sorts-last, catch date descending, catch id ascending), Record Catch derivation from the already-sorted list, Last Catch Date computed independently of that weight-based order, Species Breakdown aggregation/ordering, Fishing Spot List aggregation/ordering/zero-catch exclusion (including two fishing spots sharing the same display name), and recomputation after a catch at that fishing spot is created, edited, or deleted
* Navigation-wiring tests confirm Fishing Spot List rows open Fishing Spot Statistics for the correct fishing spot, and both the Record Catch card and Catch List entries open Catch Details for the correct catch
* Architecture review completed; one UX refinement (`CatchCountRow`'s chevron made conditional on `onTap`) and no architectural deviations otherwise; no schema/migration impact; no change to `catches`, `catch_photos`, `fishing_spots`, `lure_catalog`, or `personal_tackle_box`; `SpeciesStatisticsRepository`, `SpeciesStatisticsPage`, `RecordCatchCard`, and `LureStatisticsRepository` unmodified; `CatchListItem` reused completely unmodified
* Lifecycle bugs found during physical Android testing and fixed, each with a dedicated regression test reproducing it through the real UI (not a direct repository call) and confirmed to fail without the fix and pass with it: `CatchDetailsPage` could pop before its own in-flight delete completed if the user navigated away independently while it was running (closed with an explicit `CatchDetailsResult` and a `PopScope` guard); `GeneralCatchStatisticsTab` did not reload after returning from Fishing Spot Statistics or Species Statistics, leaving its total, Fishing Spot List, and Species List stale (closed by applying the existing post-navigation-refresh convention to both entry points)
* flutter analyze passes; all automated tests pass (640/640)
* Physical Android testing completed

### Catch Notes

* Domain, migration, and repository tests completed, including exactly-1000/over-1000 boundary coverage, whitespace-only-input-becomes-null normalization, internal whitespace/line-break preservation, and a real schema-6 legacy-snapshot migration test (not a reconstruction via the current table class) confirming existing catches survive with `notes == null` and remain writable immediately afterward
* Add Catch / Edit Catch widget tests completed: field placement, empty/multiline/exactly-1000-character saves, the full six-step over-limit flow (field retains the complete over-limit text, saving is blocked, the Finnish message is shown, the text remains for correction, and the repository's call count is asserted at zero), and persistence-failure preservation of the entered note (repository called exactly once, sheet remains open, complete multiline text retained)
* Catch Details widget tests completed: displayed only when present, full text with line breaks preserved, no truncation, selectable text, correct position after the lure row, and no change to any other row's rendering
* Architecture review completed; no architectural deviations from TD-023's domain, database, repository, or presentation design; no database-level CHECK constraint added, per TD-023's own decision that repository-level enforcement is the sole defensive authority
* flutter analyze passes; all automated tests pass (682/682)
* Physical Android testing completed

### Water Bodies

* Schema migration (v7 → v8) verified with a dedicated schema-snapshot migration test (not a reconstruction via the current table class): existing Fishing Spot/Catch/Catch Photo/Lure Catalog/Personal Tackle Box data preserved across the upgrade, every pre-existing fishing spot receiving its own correctly named water body with no orphaned rows
* Domain, database, mapper (including the fail-fast guard on a null `waterBodyId`), and repository tests completed for both `WaterBody` and the extended `FishingSpot`/`FishingSpotRepository`, including nearby-water-body ranking/preselection and empty-only deletion enforcement
* Presentation widget tests completed: the water-body selection/creation step, the Fishing Spot Details "Vaihda vesistö" action, and the Water Body management page (list, rename, member fishing spots, blocked-while-non-empty deletion, confirmed empty deletion)
* Statistics widget/repository tests extended: `SpeciesStatisticsRepository`'s join and `RecordCatchCard` updated to cover water-body resolution and display
* Four pre-existing legacy-schema-snapshot migration tests, in features unrelated to this milestone, needed correction after `FishingSpots` gained `waterBodyId` — a ripple effect discovered and fixed during implementation, documented in TD-024 Implementation Notes item 3
* Architecture review completed; no architectural deviations from TD-024's domain, database, repository, or presentation design; MFS-024 FR-17's post-migration hint text/UI was deliberately deferred (TD-024 Key Design Decision 8)
* flutter analyze passes; all automated tests pass (735/735)
* Physical Android testing completed

### Catch Search & Filtering

* Domain tests completed for `CatchSearchCriteria` (empty/active-filter detection, `copyWith`'s unset-vs-explicitly-cleared semantics, `clearFilters`, value equality)
* Repository tests completed: every searchable field individually and in combination (species by Finnish name, water body name, fishing spot name, lure brand, lure model), case-insensitivity, whitespace trimming, each filter individually and combined (AND semantics), inclusive date-range boundaries, a retired lure remaining searchable by name, a dangling `lureVariantId` reference resolving safely with no lure shown, deterministic ordering, filter-option generation (only values with at least one catch), and live updates after a catch is created, edited, or deleted
* Widget tests completed for `CatchSearchPage` and `CatchFilterBottomSheet`: always-visible search field, immediate tap-to-focus, clear-button visibility and immediate-refresh-while-preserving-filters behavior, debounce timing (no query before ~280 ms, exactly one after), stale-response protection (a slow, superseded query cannot overwrite a faster, later result), loading/empty-database/no-match/error states, active-filter indicator, applying and clearing filters, opening a result into Catch Details, and a full round trip through Catch Details preserving search text and filters
* `MapScreen` widget tests added (no such test file existed before this milestone): the new Catch Search AppBar action (icon, tooltip, navigation, `CatchSearchRepository` wiring), and regression coverage confirming the pre-existing Lure Tools and Statistics actions are unaffected
* `CatchListItem` widget tests extended for its three new optional display lines; every pre-existing test continues to pass unmodified
* `flutter analyze` passes; all automated tests pass (818/818)
* Architecture review completed
* Physical Android testing completed

### Base Maps

**MFS-026's own validation record, below — MML raster WMTS.** Maastokartta's Finnish cartography has since moved to MML v21 vector (MFS-027/TD-027 Revision 7, finalized Revision 8); see the Worldwide Base-Map Coverage & SYKE Bathymetry subsection following this one for that later milestone's own validation. This record is retained as an accurate history of MFS-026 itself, not as a description of the currently shipped rendering path for Maastokartta's Finnish layer.

* WMTS raster mechanics (matrix set identifier `WGS84_Pseudo-Mercator`, `{z}/{y}/{x}` tile-token order, zoom 0–18, 256×256 tiles, Maastokartta `.png`/Ortokuva `.jpg`) verified directly against MML's live `WMTSCapabilities.xml` and confirmed accurate throughout implementation with no correction needed
* Domain, config, persistence, and style-factory tests completed (`BaseMap`, `MmlConfig`, `BaseMapPreferenceStore`, `MmlStyleFactory`, `StyleRestorationTracker`/`FishingSpotLayerPresence`)
* Selector and layers-control widget tests completed, including the final vertical, image-only, fixed-dimension layout, semantic-label retention with no visible text, and the subtle border/tint active-state treatment
* Architecture review found and fixed three races, each with a dedicated regression test: a style-generation/restoration race (a delayed callback for an older, superseded style could satisfy the restoration guard for a newer one), an out-of-order base-map-preference persistence race (an older save completing after a newer one), and a no-op-detection bug in rapid re-selection
* Three rounds of physical Android testing found and fixed: fishing-spot markers permanently disappearing after a base-map switch (native `addSource`/`addLayer` silently no-op'ing when the style was not yet fully loaded — fixed with an idempotent, source/layer-presence-verifying restoration loop); fishing-spot markers not appearing on the very first (cold) app launch despite the same mechanism working after a later switch (the restoration retry bound was tuned for a warm switch; widened to account for first-time native/network initialization cost); and fishing-spot labels not rendering at all, then still not rendering after a first fix (missing `glyphs` URL, then a broken multi-font `textFont` combination verified via direct `curl` testing against the glyph host — resolved to a single verified-working font)
* Preview assets verified as real, licensed MML-derived crops: CC BY 4.0's own legal text confirmed cropped/adapted derivatives are permitted and that the existing always-visible `MapAttribution` notice reasonably satisfies attribution for them; both crops were fetched once outside the application using a developer's own MML API key, never via a live request from the app itself
* `flutter analyze` passes; all automated tests pass (878/878)
* Architecture review completed
* Physical Android testing completed across three rounds: Maastokartta and Ilmakuva both load correctly, switching works in both directions, fishing-spot circles and labels appear correctly on initial launch and after switching, fishing-spot interaction is unaffected, the selection persists across restart, the layers control and selector work correctly, attribution is visible, missing-key behavior is handled non-technically, and no credential appears anywhere in the repository

### Worldwide Base-Map Coverage & SYKE Bathymetry (MFS-027 / TD-027)

* Raster WMTS + on-device pixel-masking (Revisions 1–6) was fully implemented, then superseded and retired in favor of MML's own official v21 vector tiles for Maastokartta (Revision 7) — vector tiles have no opaque out-of-coverage fill to mask, eliminating the defect class the retired masking machinery existed to fix; the retired code and its dedicated tests were removed, not left passing-but-irrelevant
* MapTiler Outdoor (Maastokartta's worldwide underlay) and MapTiler Satellite Hybrid (Ilmakuva's complete worldwide base map) verified directly against MapTiler's own authenticated TileJSON responses
* The MML API credential is proxied through a local, on-device loopback service that strips it before anything reaches MapLibre or disk — never written to a plaintext style file
* SYKE bathymetry (national lake/river depth contours, CC BY 4.0) added as a new overlay, bundled fully offline as a single preprocessed MBTiles asset, served through the same local loopback listener as MML — no live SYKE WFS request from the running app
* Contour-line simplification was tried (an adaptive, size-aware tolerance) and rejected after physical Android testing found it still visibly too angular; contours ship completely unsimplified, full source vertex precision, with only per-tile MVT clipping applied
* Depth-area (fill) polygons are bundled but not rendered in the shipped presentation — found visually competing with the base map's own lake rendering; contour lines only ship
* Depth labels (reading each contour's own `depth_m` MVT attribute, `"<depth> m"`, excluding the `0 m` shoreline contour) were added, found not rendering on first physical test, root-caused to a font-selection defect (the label layer's default font stack is unavailable on either glyph host this app uses), and fixed by resolving a single verified-working font per the active style's glyph host — the same pattern already used for fishing-spot labels
* Content-aware, version-sidecar-based extraction invalidation for the bundled MBTiles verified by a dedicated regression test suite (first extraction, idempotent reuse, stale-version replacement, failed-replacement-preserves-previous-copy, zero-length/missing-target/no-sidecar edge cases)
* Temporary `[SYKE_TILE]`/`[MAP_ZOOM]` debug logging, added during investigation of an earlier zoom-disappearance defect, was removed once the defect was root-caused and fixed (root cause: non-contiguous tiled zoom range) — production code retains only the version-sidecar invalidation fix itself, not the diagnostic logging used to find it
* `flutter analyze` passes; all automated tests pass
* Architecture review completed
* Physical Android testing completed: MML v21 vector renders correctly for Maastokartta with MapTiler Outdoor as worldwide fallback; MapTiler Satellite Hybrid renders correctly for Ilmakuva; the four-lake SYKE coverage matrix (Kymijärvi, Vesijärvi, Päijänne, Saimaa) confirmed correct positive/no-data/mixed-coverage/dense-data behavior; contour geometry fidelity, continuous rendering across the tiled zoom range, close-zoom (overzoom) rendering, and depth-label rendering/sizing/spacing are all confirmed and accepted as shipped

### Quality

* flutter analyze passes, with 11 pre-existing/accepted info-level lints (`prefer_initializing_formals`, on constructor parameters whose external names are relied on by callers and cannot be renamed without breaking the public API — see TD-016 Implementation Notes)
* 981 automated tests passing
* Architecture review completed
* Code review completed
* Lifecycle review completed for Species Statistics (MFS-021) and Fishing Spot Statistics (MFS-022)
* Physical Android testing completed for all currently implemented Android features

---

## Current Technical Stack

### Framework

* Flutter
* Dart

### Architecture

* Offline-first
* Feature-first
* Core Services

### State Management

* Riverpod

### Navigation

* GoRouter

### Maps

* MapLibre GL
* GeoJSON Sources & Layers

### Local Database

* Drift
* SQLite

### Location

* geolocator

### Photos

* image_picker
* path_provider
* path
* image
* uuid (used for CatchPhoto and TackleBoxEntry runtime UUID v4 identifiers, and for hand-authored Lure Catalog identifiers — originally compile-time Dart literals, now authored directly into the JSON source files read by `tools/lure_catalog/build_catalog.py`, MFS-028 / TD-028 — never generated at runtime; other domain IDs in the project use a separate, pre-existing timestamp-based scheme)

### UI

* Material 3
* Design Tokens

### Planned

* Supabase

---

## Current Application Structure

```text
lib/
├── app/
├── core/
│   ├── database/
│   ├── location/
│   └── map/
├── features/
│   ├── catch_photos/
│   │   ├── data/
│   │   │   ├── local/
│   │   │   └── storage/
│   │   ├── domain/
│   │   └── presentation/
│   │       └── widgets/
│   ├── catches/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── fishing_spots/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── home/
│   ├── lure_catalog/
│   │   ├── data/
│   │   │   └── local/
│   │   ├── domain/
│   │   └── presentation/
│   │       └── widgets/
│   ├── map/
│   │   └── presentation/
│   │       └── widgets/
│   ├── personal_tackle_box/
│   │   ├── data/
│   │   │   ├── local/
│   │   │   └── storage/
│   │   ├── domain/
│   │   └── presentation/
│   │       └── widgets/
│   └── statistics/
│       ├── data/
│       ├── domain/
│       └── presentation/
│           └── widgets/
└── main.dart
```

---

## Current Application State

The application currently supports:

* Interactive map
* Selectable MML base maps: Maastokartta (topographic) and Ilmakuva (aerial imagery), switchable from a compact upper-right layers control with a vertically stacked, image-only selector; the selection persists across restarts, and existing fishing-spot markers/labels/interaction, location controls, and other entry points survive every base-map switch
* User location
* Persistent offline fishing spots
* Fishing Spot CRUD
* Persistent offline catches
* Catch CRUD
* Species selection
* Weight tracking
* Length tracking
* Catch date and time
* Create fishing spots from current location
* Create fishing spots from map
* Crosshair map selection
* Automatic loading of stored fishing spots
* Automatic loading of catches
* Catch photos (camera and gallery, up to 5 per Catch)
* Full-screen photo viewer with zoom
* Photo cleanup on Catch deletion
* Dedicated Catch Details view
* Catch list photo thumbnails
* Swipeable catch photo gallery
* One-finger panning of zoomed photos
* Edge handoff between zoomed photos
* Lure Catalog (search and filter by manufacturer/lure type), browsed one row per lure model
* Finnish-aware, case-insensitive lure search
* Lure Model Details view with a Color Variants list (per-variant image, color, length, weight, owned indicator, add action); full single-variant detail remains reachable from each row
* Personal Tackle Box (add, browse grouped by manufacturer/model, and remove owned lures)
* Optional personal photo per owned lure (camera, gallery, explicit no-photo, or skip/cancel with no lure added)
* Owned Entry Detail view with resolved catalog details and personal photo
* Assigning an owned lure to a Catch (Add Catch or Edit Catch), shown read-only in Catch Details
* Lure-based catch statistics: most successful lure and lure type summary cards, a per-lure catch-count list, and a per-lure-type catch-count breakdown, computed live with no stored aggregate
* General catch statistics: a Top 3 Largest Catches "Hall of Fame" (medal-bordered cards, each opening the existing Catch Details view), equal-height total-catches/most-caught-species summary cards, and a full per-species catch-count list, computed live across the angler's entire catch history with no stored aggregate
* Species statistics: tapping a species in the Catches tab's Species List opens a pushed page showing that species' total catch count, a Record Catch card (photo, weight/length, date, water body), and its full Catch List (reusing the existing Catch list row), each entry opening the existing Catch Details view — the page refreshes automatically after returning from Catch Details
* Fishing spot statistics: tapping a fishing spot in the Catches tab's Fishing Spot List opens a pushed page showing that spot's total catch count, Last Catch Date, a Record Catch card (photo, species, weight/length, date — no location, since the page's own context already is one fishing spot), a static Species Breakdown, and its full Catch List (reusing the existing Catch list row), each entry opening the existing Catch Details view — both the page and the Catches tab it was opened from refresh automatically after returning from Catch Details or from Fishing Spot Statistics itself
* Catch Notes: one optional, multiline, plain-text note (up to 1000 characters) per Catch, added or edited via Add Catch/Edit Catch, shown as the final selectable section of Catch Details when present and omitted entirely when absent
* Water Bodies: every fishing spot belongs to exactly one water body, selected or created while adding the spot (with locally computed nearby-water-body suggestions) or changed afterward from Fishing Spot Details; a minimal management surface lists, renames, and deletes (once empty) water bodies; every pre-existing fishing spot was automatically migrated into its own water body with no data loss; Species Statistics' Record Catch card shows the water body instead of the exact fishing spot name
* Catch Search & Filtering: a global catch-browsing page (reached from a new `MapScreen` AppBar entry) with an always-visible, debounced text search across species, water body, fishing spot, and lure brand/model, and a filter bottom sheet (water body, species, lure, date range); each result shows species, date, weight/length, water body, fishing spot, and lure when available, and opens the existing Catch Details view

---

## Android Configuration

Configured:

* ACCESS_FINE_LOCATION
* ACCESS_COARSE_LOCATION

Background location is intentionally not implemented.

No additional permissions were required for Catch Photos: `image_picker` on Android launches the system camera app and photo picker via intents, neither of which requires a manifest permission declaration from this app.

No additional permissions were required for the Lure Catalog: it reads bundled local assets and the local database only.

No additional permissions were required for the Personal Tackle Box: it reuses the same `image_picker` camera/gallery intents already used by Catch Photos, which require no manifest permission declaration from this app.

No additional permissions were required for Assign Lure to Catch or Lure Catalog UX Improvements: both are presentation/data-layer changes over the existing local database and photo intents, with no new hardware or system capability involved.

No additional permissions were required for Lure-Based Catch Statistics, General Catch Statistics, Species Statistics, or Fishing Spot Statistics: all four read the existing local database only, with no new hardware or system capability involved.

No additional permissions were required for Catch Notes: it is a local database schema addition and form field only, with no new hardware or system capability involved.

No additional permissions were required for Water Bodies: it is a local database schema addition and new presentation surfaces over the existing local database only, with no new hardware or system capability involved.

No additional permissions were required for Catch Search & Filtering: it reads the existing local database only, with no new hardware or system capability involved.

No `AndroidManifest.xml` change was required for Selectable MML Base Maps: `MapScreen` already made network requests over HTTPS to load its previous placeholder demo style, so this milestone's MML tile requests introduce no new network-access requirement or manifest entry.

---

## iOS Configuration

Added for Catch Photos:

* `NSCameraUsageDescription`
* `NSPhotoLibraryUsageDescription`

No other iOS configuration changes were required, including for the Lure Catalog and the Personal Tackle Box (the latter's photo capture reuses the same `image_picker` usage descriptions already added for Catch Photos), for Lure-Based Catch Statistics, General Catch Statistics, Species Statistics, and Fishing Spot Statistics (all four local-database-only features), and for Catch Notes, Water Bodies, and Catch Search & Filtering (also local-database-only). No iOS configuration change was required for Selectable MML Base Maps either: it makes ordinary HTTPS requests, exactly like the placeholder demo style it replaces, and its style-delivery mechanism was deliberately chosen ([TD-026](docs/technical-designs/TD-026-selectable-mml-base-maps.md) Implementation Notes) to remain cross-platform rather than relying on an Android-only plugin API. Physical iOS testing has not been performed (no iOS build target/device in this environment).

---

## Development Workflow

1. ADR (when required)
2. MFS
3. TD
4. Claude Code implementation
5. Architecture review
6. flutter analyze
7. Physical Android testing
8. Git commit
9. Project status update

---

## Known Limitations

* iOS has not been physically tested for any feature in this project.
* The Lure Catalog remains local, bundled content only (now generated from JSON authoring files rather than hand-written Dart literals, MFS-028 / TD-028): no network access, no cloud sync, no server-managed synchronization, and no user-created catalog entries.
* The Personal Tackle Box intentionally does not support search/filtering within a user's own tackle box, editing/replacing an existing personal photo, multiple photos per entry, notes, condition, or purchase information — all explicitly out of scope for MFS-016 (see its Future Extensions section).
* A small number of UI/UX refinements were consciously deferred rather than built speculatively, and are candidates for a later, separate polish task (not a change to MFS-016/TD-016 scope): the empty Personal Tackle Box state relies on standard back navigation to reach the Lure Catalog rather than a dedicated shortcut button, and the grouped browsing list shows the catalog image only — the personal photo is shown on the Owned Entry Detail screen.
* A catch may reference at most one lure (MFS-017); assigning more than one lure to a catch, showing the assigned lure in the catch list, and lure-based statistics are all explicitly out of scope for MFS-017 (see its Out of Scope section).
* Variant filtering within a single model's Color Variants list, favorite variants, stock/availability status, and quick-add shortcuts that skip Lure Model Details are all explicitly out of scope for MFS-018 (see its Out of Scope section).
* Graphs/charts, filters, percentages, averages, biggest fish, seasonal/time-based/water/weather statistics, export, and comparison features are all explicitly out of scope for MFS-019 (see its Out of Scope section); the lure list only shows lures with at least one recorded catch (zero-catch lures are a documented future extension, not a bug).
* Selectable MML Base Maps (MFS-026) is the first feature in this project requiring live network access — MML base-map imagery does not work offline (a clear, non-technical message is shown instead; every other application feature, including fishing spots/catches/statistics/lure catalog, remains fully usable). Offline map support remains explicitly out of scope (ADR-0008, MFS-026), consistent with this project's existing offline-first-for-*data* (not necessarily base-map-imagery) architecture.
* Worldwide Base-Map Coverage (MFS-027 / TD-027, Revision 8, implemented and physically validated) gives both base maps real worldwide coverage — MapTiler Outdoor/Satellite Hybrid everywhere, with MML's own official v21 **vector** tiles (not raster) for Maastokartta's Finnish cartography, fetched through a local, on-device loopback proxy that strips the API key before anything reaches MapLibre. The earlier raster-WMTS-plus-pixel-masking architecture (Revisions 1–6) was fully retired, not merely superseded — vector tiles have no opaque out-of-coverage fill to mask in the first place, eliminating that entire defect class. Ilmakuva does not use MML Ortokuva at all in this milestone (MapTiler Satellite Hybrid only, worldwide) — a deliberate product decision (ADR-0009), not a defect. A SYKE lake/river bathymetry overlay (contour lines, unsimplified, plus depth labels) ships above the base map for both selections — see the SYKE Bathymetry Overlay section above; `EL.SpotElevation` sounding-point labels remain deferred/out of scope.

---

## Next Planned Task

MFS-026 (Selectable MML Base Maps) is complete — implemented, architecture-reviewed, all automated tests passing, `flutter analyze` clean, and physically verified on Android across three rounds.

**Worldwide Base-Map Coverage (MFS-027 / TD-027) is complete through Revision 8** — MML v21 vector for Maastokartta, MapTiler Outdoor/Satellite Hybrid worldwide, and the SYKE bathymetry overlay with depth labels are all implemented, `flutter analyze`-clean, covered by the full automated test suite, and physically validated on Android (contour geometry fidelity, continuous zoom-range rendering, close-zoom/overzoom rendering, and depth-label rendering all accepted as shipped). See `docs/technical-designs/TD-027-worldwide-base-map-coverage.md` §27 and `docs/specifications/MFS-027-worldwide-base-map-coverage.md` for full detail. Committed and pushed (`0673b61`, `6a6cca4`).

**The current milestone is Lure Catalog Expansion & Data Management (MFS-028 / TD-028).** Its feature specification (`docs/specifications/MFS-028-lure-catalog-expansion-and-data-management.md`) and Technical Design (`docs/technical-designs/TD-028-lure-catalog-expansion-and-data-management.md`, Revision 2) are both written, and **implementation is now complete**: the hand-written Dart seed literals are replaced by per-manufacturer JSON authoring files, a developer-run Python build/validation tool (`tools/lure_catalog/`), and one generated, bundled `catalog_v1.json` asset, reconciled at runtime by a generalized `LureCatalogRepository.ensureSeeded()` — see the Lure Catalog Expansion & Data Management section above for full detail. `lure_catalog_seed_data.dart` has been deleted; the transition preserves every existing manufacturer/model/variant id, and no database schema or migration change was required (schema remains at version 8).

**Architecture review completed with verdict "Ready after small fixes."** All required fixes and small findings have since been applied: `ensureSeeded()` decomposed into small, named, independently-reasoned-about planning/apply helpers (previously one ~130-line method); the three test-double classes independently duplicated across `lure_catalog_repository_test.dart`, `lure_catalog_list_page_test.dart`, and `lure_tools_page_test.dart` consolidated into one shared `test/support/lure_catalog_test_doubles.dart`; the large-scale (1,000-model/10,000-variant) performance test strengthened (a documented, evidence-based timing threshold instead of an unverified loose one, and an `updatedAt`-stability check for its second-pass idempotency claim instead of a row-count-only check); a new automated test keeps `tools/lure_catalog/known_lure_types.json` and `lure_type_labels.dart`'s known lure-type codes from silently drifting apart; and stale "seed data" wording corrected in `lure_catalog_mapper.dart`.

**`flutter analyze` is clean (only the 11 pre-existing/accepted info-level lints below) and the full automated test suite (996 tests) is passing.** **Physical Android testing has now been completed**: catalog loading, search and filtering, model/variant browsing, adding/removing an owned lure, owned status persisting across a restart, assigning a lure to a catch, Catch Details lure resolution, lure statistics resolution, airplane-mode operation, and no row duplication across repeated app launches were all verified on a physical device. Every step of this project's own Development Workflow (README.md) through "Physical Android testing" is now complete for this milestone — **ready for commit**. See `docs/roadmap.md` §3.5.

---

## Project Metrics

Current Feature Specifications: 28

Current Technical Designs: 26

Architecture Decision Records: 9

Implemented Core Features:
* Map
* Base Maps (selectable Maastokartta/Ilmakuva, worldwide coverage — MML v21 vector + MapTiler)
* SYKE Bathymetry Overlay (contour lines, depth labels)
* User Location
* Fishing Spot Management (including Water Bodies)
* Catch Management (including Catch Notes)
* Catch Photos
* Catch Details
* Catch Search & Filtering
* Lure Catalog (including MFS-018's model-grouped browsing and Lure Model Details)
* Personal Tackle Box
* Assign Lure to Catch
* Statistics (Catches — general catch statistics; Species Statistics; Fishing Spot Statistics; Lure Statistics)

Offline-first: Yes (base-map imagery is the sole exception — see Known Limitations)

Physical Android Validation: Completed for all shipped features, including Worldwide Base-Map Coverage (MFS-027 / TD-027) and its SYKE bathymetry overlay/depth labels, and Lure Catalog Expansion & Data Management (MFS-028 / TD-028) — implemented, architecture-reviewed, fully automated-test-covered, and now physically verified on Android; ready for commit. See Next Planned Task.

flutter analyze: Passing with 11 pre-existing/accepted info-level lints (`prefer_initializing_formals`)

Automated Tests: 996 Passing

Database schema version: 8 (unchanged by MFS-028 / TD-028)
