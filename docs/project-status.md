# Project Status

## Last Updated

2026-07-18

---

## Current Phase

Fishing Spot management is complete. Catch management foundation is complete. Catch Photos is implemented and validated. Catch Details View is implemented and validated.

The application now supports full offline CRUD operations for both Fishing Spots and Catches, photo attachments on Catches, and a dedicated read-only Catch Details view with a swipeable photo gallery.

The project is ready for the next Catch Management expansion feature.

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

### Quality

* flutter analyze passes, with only 5 pre-existing unrelated info-level lints
* 215 automated tests passing
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
* uuid (added for CatchPhoto UUID v4 identifiers; other domain IDs in the project use a separate, pre-existing timestamp-based scheme)

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
│   └── map/
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

---

## Android Configuration

Configured:

* ACCESS_FINE_LOCATION
* ACCESS_COARSE_LOCATION

Background location is intentionally not implemented.

No additional permissions were required for Catch Photos: `image_picker` on Android launches the system camera app and photo picker via intents, neither of which requires a manifest permission declaration from this app.

---

## iOS Configuration

Added for Catch Photos:

* `NSCameraUsageDescription`
* `NSPhotoLibraryUsageDescription`

No other iOS configuration changes were required. Physical iOS testing has not been performed (no iOS build target/device in this environment).

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

---

## Next Planned Task

Expand catch management. The next exact feature has not yet been selected.

Possible candidates:

* Catch notes
* Favorite fishing spots
* Favorite catches
* Coordinate editing
* Statistics
* Weather integration
* Offline map tiles
* Cloud synchronization

---

## Project Metrics

Current Feature Specifications: 14

Current Technical Designs: 12

Architecture Decision Records: 6

Implemented Core Features:
* Map
* User Location
* Fishing Spot Management
* Catch Management
* Catch Photos
* Catch Details

Offline-first: Yes

Physical Android Validation: Completed for all currently implemented features

flutter analyze: Passing with 5 pre-existing unrelated info-level lints

Automated Tests: 215 Passing
