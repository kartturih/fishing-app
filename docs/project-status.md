# Project Status

## Last Updated

2026-07-21

---

## Current Phase

Fishing Spot management is complete. Catch management foundation is complete. Catch Photos is implemented and validated. Catch Details View is implemented and validated. Lure Catalog Foundation (MFS-015 / TD-015) is implemented, architecture-reviewed, and validated. Personal Tackle Box Foundation (MFS-016 / TD-016) is implemented, architecture-reviewed, and validated. Assign Lure to Catch (MFS-017 / TD-017) is implemented, architecture-reviewed, and validated. Lure Catalog UX Improvements (MFS-018 / TD-018) is implemented, architecture-reviewed, and validated. Lure-Based Catch Statistics (MFS-019 / TD-019) is implemented, architecture-reviewed, and validated. General Catch Statistics (MFS-020 / TD-020) is implemented, architecture-reviewed, and validated. Species Statistics (MFS-021 / TD-021) is implemented, architecture-reviewed, lifecycle-reviewed, and validated.

The application now supports full offline CRUD operations for both Fishing Spots and Catches, photo attachments on Catches, a dedicated read-only Catch Details view with a swipeable photo gallery, a shared Lure Catalog with search and filtering browsed by lure model (with a per-model Color Variants view), a Personal Tackle Box that lets an angler track which catalog lures they actually own with an optional personal photo per owned lure, the ability to assign one of those owned lures to a Catch shown in Catch Details, and a Statistics feature with two tabs: Catches (general catch statistics — a Top 3 Largest Catches "Hall of Fame," total catches, most caught species, and a full per-species catch-count list, computed live across the angler's entire catch history) and Lure Statistics (most successful lure, most successful lure type, a per-lure catch-count list, and a per-lure-type breakdown, computed live from existing catch and lure catalog data) — neither tab persists any new aggregate. Tapping a species in the Catches tab's Species List now opens a pushed Species Statistics page (MFS-021) for that species: its total catch count, a Record Catch card, and its full Catch List (reusing the existing Catch list row), each entry opening the existing Catch Details view and refreshing Species Statistics automatically on return.

**MFS-021 (Species Statistics) is now implemented, architecture-reviewed, lifecycle-reviewed, and validated — see the Statistics section below.** Fishing Spot Statistics has been selected as the next milestone, to be specified as MFS-022; it has not yet been drafted or approved. See `docs/roadmap.md`'s Near-Term Roadmap for its updated sequencing (MFS-022 Fishing Spot Statistics, then MFS-023 Catch Notes, then MFS-024 Catch Search & Filtering).

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

---

## Implemented Features

### Map

* MapLibre integrated
* Interactive map
* Finland initial camera
* Pan and zoom
* Physical Android support
* GeoJSON-based fishing spot rendering

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
* A small, hand-authored local seed dataset (4 models, 14 variants) — local-seed-only in this milestone; no network access, cloud sync, or user-created entries

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
* `SpeciesStatisticsPage`, pushed via the existing `Navigator.push`/`MaterialPageRoute` pattern (mirroring `CatchDetailsPage.open()`), shows a total-catches summary card, a `RecordCatchCard` (photo, weight/length, date, and fishing spot — each rendering cleanly when absent), and a full Catch List reusing `CatchListItem` completely unmodified
* Lifecycle fix found during review: the page previously loaded its summary once, in `initState`, so edits/deletes made from Catch Details were not reflected on return. Fixed by following the existing `FishingSpotDetailsBottomSheet` convention — `await CatchDetailsPage.open(...)`, check `mounted`, then reload — rather than introducing a new navigation-result type or state-management mechanism; covers both the Record Catch card and every Catch List entry from one change
* No new Drift table, column, schema version, or migration; `GeneralCatchStatisticsRepository`, `LureStatisticsRepository`, `LargestCatch`, and `GeneralCatchStatisticsSummary` are unmodified

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

### Quality

* flutter analyze passes, with 8 pre-existing/accepted info-level lints (`prefer_initializing_formals`, on constructor parameters whose external names are relied on by callers and cannot be renamed without breaking the public API — see TD-016 Implementation Notes)
* 575 automated tests passing
* Architecture review completed
* Code review completed
* Lifecycle review completed for Species Statistics (MFS-021)
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
* uuid (used for CatchPhoto and TackleBoxEntry runtime UUID v4 identifiers, and for hand-authored, compile-time Lure Catalog seed identifiers; other domain IDs in the project use a separate, pre-existing timestamp-based scheme)

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
│   └── location/
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
* Species statistics: tapping a species in the Catches tab's Species List opens a pushed page showing that species' total catch count, a Record Catch card (photo, weight/length, date, fishing spot), and its full Catch List (reusing the existing Catch list row), each entry opening the existing Catch Details view — the page refreshes automatically after returning from Catch Details

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

No additional permissions were required for Lure-Based Catch Statistics, General Catch Statistics, or Species Statistics: all three read the existing local database only, with no new hardware or system capability involved.

---

## iOS Configuration

Added for Catch Photos:

* `NSCameraUsageDescription`
* `NSPhotoLibraryUsageDescription`

No other iOS configuration changes were required, including for the Lure Catalog and the Personal Tackle Box (the latter's photo capture reuses the same `image_picker` usage descriptions already added for Catch Photos), and for Lure-Based Catch Statistics, General Catch Statistics, and Species Statistics (all three local-database-only features). Physical iOS testing has not been performed (no iOS build target/device in this environment).

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
* The Lure Catalog is local-seed data only: no network access, no cloud sync, and no user-created catalog entries.
* The Personal Tackle Box intentionally does not support search/filtering within a user's own tackle box, editing/replacing an existing personal photo, multiple photos per entry, notes, condition, or purchase information — all explicitly out of scope for MFS-016 (see its Future Extensions section).
* A small number of UI/UX refinements were consciously deferred rather than built speculatively, and are candidates for a later, separate polish task (not a change to MFS-016/TD-016 scope): the empty Personal Tackle Box state relies on standard back navigation to reach the Lure Catalog rather than a dedicated shortcut button, and the grouped browsing list shows the catalog image only — the personal photo is shown on the Owned Entry Detail screen.
* A catch may reference at most one lure (MFS-017); assigning more than one lure to a catch, showing the assigned lure in the catch list, and lure-based statistics are all explicitly out of scope for MFS-017 (see its Out of Scope section).
* Variant filtering within a single model's Color Variants list, favorite variants, stock/availability status, and quick-add shortcuts that skip Lure Model Details are all explicitly out of scope for MFS-018 (see its Out of Scope section).
* Graphs/charts, filters, percentages, averages, biggest fish, seasonal/time-based/water/weather statistics, export, and comparison features are all explicitly out of scope for MFS-019 (see its Out of Scope section); the lure list only shows lures with at least one recorded catch (zero-catch lures are a documented future extension, not a bug).

---

## Next Planned Task

MFS-021 (Species Statistics) is complete — implemented, architecture-reviewed, lifecycle-reviewed, all automated tests passing (575/575), `flutter analyze` clean, and physically verified on Android. Fishing Spot Statistics has been selected as the next milestone, to be specified as MFS-022 — not yet drafted or approved. Per this project's Development Workflow, the next step is drafting its MFS; see `docs/roadmap.md`'s Near-Term Roadmap for the updated sequencing (MFS-022, then MFS-023 Catch Notes, then MFS-024 Catch Search & Filtering).

---

## Project Metrics

Current Feature Specifications: 21

Current Technical Designs: 19

Architecture Decision Records: 6

Implemented Core Features:
* Map
* User Location
* Fishing Spot Management
* Catch Management
* Catch Photos
* Catch Details
* Lure Catalog (including MFS-018's model-grouped browsing and Lure Model Details)
* Personal Tackle Box
* Assign Lure to Catch
* Statistics (Catches — general catch statistics; Species Statistics; Lure Statistics)

Offline-first: Yes

Physical Android Validation: Completed for all currently implemented features

flutter analyze: Passing with 8 pre-existing/accepted info-level lints (`prefer_initializing_formals`)

Automated Tests: 575 Passing

Database schema version: 6
