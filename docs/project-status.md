# Project Status

## Last Updated

2026-07-19

---

## Current Phase

Fishing Spot management is complete. Catch management foundation is complete. Catch Photos is implemented and validated. Catch Details View is implemented and validated. Lure Catalog Foundation (MFS-015 / TD-015) is implemented, architecture-reviewed, and validated. Personal Tackle Box Foundation (MFS-016 / TD-016) is implemented, architecture-reviewed, and validated.

The application now supports full offline CRUD operations for both Fishing Spots and Catches, photo attachments on Catches, a dedicated read-only Catch Details view with a swipeable photo gallery, a shared, read-only Lure Catalog with search and filtering, and a Personal Tackle Box that lets an angler track which catalog lures they actually own, with an optional personal photo per owned lure.

The project is ready for the next milestone: Assign Lure to Catch (MFS-017).

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
* Lure Catalog list and details pages, with loading/empty/error states and image-load fallback to a placeholder
* A small, hand-authored local seed dataset (4 models, 14 variants) — local-seed-only in this milestone; no network access, cloud sync, or user-created entries

### Personal Tackle Box

* Framework-independent `TackleBoxEntry` domain model and `TackleBoxItem` joined read-model, reusing `lure_catalog`'s `LureCatalogEntry` by reference rather than copying catalog data
* Drift persistence (schema migrated from version 4 to version 5: `tackle_box_entries` table, `onDelete: KeyAction.restrict` foreign key to `lure_variants`, unique constraint on `lureVariantId`)
* Concrete `PersonalTackleBoxRepository` performing its own three-table join (`tackle_box_entries` ⨝ `lure_variants` ⨝ `lure_models`), reusing `lure_catalog`'s existing mapper — one query per screen, no N+1
* Duplicate-ownership prevention enforced at both the UI (`isOwned` pre-check) and database (unique constraint) layers
* Explicit "Add to Tackle Box" action reachable from the Lure Catalog's variant details view via a small optional passthrough parameter added to that feature's presentation layer only — the Lure Catalog's domain, data, and repository remain unmodified and fully read-only
* Optional personal photo capture (camera or gallery) when adding a lure, or skip entirely; application-owned photo storage mirroring Catch Photos' processing (2048px longest side, JPEG quality 85, atomic write) but with one flat file per entry (no per-entry subdirectory, since at most one photo exists)
* A narrow, retry-only `attachPhoto` operation lets a user re-attempt a failed photo attach immediately after adding a lure — not a general photo-replace feature
* Personal Tackle Box browsing view grouped by manufacturer, then model, then variant — never a flat one-row-per-variant list
* Owned Entry Detail view: resolved catalog details, personal photo (with fallback to the catalog image), and the Remove action
* Removing an owned entry requires confirmation and deletes both its database row and its personal photo file
* A `TackleBoxEntry` referencing a retired catalog variant remains fully visible, viewable, and removable
* Fully offline; no new external dependencies

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

### Quality

* flutter analyze passes, with 8 pre-existing/accepted info-level lints (`prefer_initializing_formals`, on constructor parameters whose external names are relied on by callers and cannot be renamed without breaking the public API — see TD-016 Implementation Notes)
* 380 automated tests passing
* Architecture review completed
* Code review completed
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
│   └── personal_tackle_box/
│       ├── data/
│       │   ├── local/
│       │   └── storage/
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
* Read-only Lure Catalog (browse, search, and filter by manufacturer/lure type)
* Finnish-aware, case-insensitive lure search
* Lure Catalog details view
* Personal Tackle Box (add, browse grouped by manufacturer/model, and remove owned lures)
* Optional personal photo per owned lure (camera or gallery, or skip)
* Owned Entry Detail view with resolved catalog details and personal photo

---

## Android Configuration

Configured:

* ACCESS_FINE_LOCATION
* ACCESS_COARSE_LOCATION

Background location is intentionally not implemented.

No additional permissions were required for Catch Photos: `image_picker` on Android launches the system camera app and photo picker via intents, neither of which requires a manifest permission declaration from this app.

No additional permissions were required for the Lure Catalog: it reads bundled local assets and the local database only.

No additional permissions were required for the Personal Tackle Box: it reuses the same `image_picker` camera/gallery intents already used by Catch Photos, which require no manifest permission declaration from this app.

---

## iOS Configuration

Added for Catch Photos:

* `NSCameraUsageDescription`
* `NSPhotoLibraryUsageDescription`

No other iOS configuration changes were required, including for the Lure Catalog and the Personal Tackle Box (the latter's photo capture reuses the same `image_picker` usage descriptions already added for Catch Photos). Physical iOS testing has not been performed (no iOS build target/device in this environment).

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
* The Lure Catalog is local-seed data only in this milestone: no network access, no cloud sync, and no user-created catalog entries. It is not yet associated with Catches (planned for MFS-017).
* The Personal Tackle Box intentionally does not support search/filtering within a user's own tackle box, editing/replacing an existing personal photo, multiple photos per entry, notes, condition, or purchase information — all explicitly out of scope for MFS-016 (see its Future Extensions section).
* A small number of UI/UX refinements were consciously deferred rather than built speculatively, and are candidates for a later, separate polish task (not a change to MFS-016/TD-016 scope): the empty Personal Tackle Box state relies on standard back navigation to reach the Lure Catalog rather than a dedicated shortcut button, and the grouped browsing list shows the catalog image only — the personal photo is shown on the Owned Entry Detail screen.

---

## Next Planned Task

MFS-017: Assign Lure to Catch.

Lets an angler attach a Personal Tackle Box entry to a Catch when logging it, building on the Personal Tackle Box Foundation delivered in MFS-016. Exact scope and technical design have not yet been drafted.

---

## Project Metrics

Current Feature Specifications: 16

Current Technical Designs: 14

Architecture Decision Records: 6

Implemented Core Features:
* Map
* User Location
* Fishing Spot Management
* Catch Management
* Catch Photos
* Catch Details
* Lure Catalog
* Personal Tackle Box

Offline-first: Yes

Physical Android Validation: Completed for all currently implemented features

flutter analyze: Passing with 8 pre-existing/accepted info-level lints (`prefer_initializing_formals`)

Automated Tests: 380 Passing

Database schema version: 5
