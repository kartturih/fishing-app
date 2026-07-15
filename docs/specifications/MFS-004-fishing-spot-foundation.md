# MFS-004: Fishing Spot Foundation

## Status

Approved

## Date

2026-07-15

---

## Purpose

The purpose of this feature is to introduce the first domain representation of a fishing spot and display fishing spot markers on the map.

This feature establishes the foundation for future fishing spot creation, persistence, editing, deletion, and related fishing data.

---

## User Story

As a user,

I want to see fishing spots on the map,

so that I can recognize saved fishing locations visually.

---

## MVP Scope

The initial implementation includes:

- `FishingSpot` domain entity
- A small in-memory collection of sample fishing spots
- Rendering fishing spot markers on the map
- Marker data derived from `FishingSpot` entities
- Feature-first project structure
- Framework-independent domain model

---

## Initial Domain Fields

The initial `FishingSpot` entity contains:

- `id`
- `name`
- `latitude`
- `longitude`
- `createdAt`

No additional fields are included in this version.

---

## Out of Scope

The following functionality is intentionally excluded:

- Creating fishing spots
- Editing fishing spots
- Deleting fishing spots
- Selecting markers
- Marker details
- Marker clustering
- Local database
- Repository implementation
- Cloud synchronization
- Photos
- Notes
- Catch relationships
- Lure relationships
- User accounts
- Sharing or community features

---

## Data Source

Fishing spots are provided from a small in-memory collection for development and validation purposes.

The in-memory data is temporary and will later be replaced by a repository and local database.

The UI must not treat MapLibre marker objects as the source of truth.

---

## Architecture

The implementation must follow ADR-0004.

```text
FishingSpot Domain Entity
          ↓
Map Presentation
          ↓
MapLibre Marker
```

The domain model must remain independent of Flutter, MapLibre, persistence, and platform APIs.

---

## Feature Structure

```text
lib/
└── features/
    └── fishing_spots/
        ├── domain/
        │   └── fishing_spot.dart
        └── data/
            └── sample_fishing_spots.dart
```

The map presentation may consume this data for marker rendering.

No repository layer is required in this version because persistence is not yet implemented.

---

## Map Integration

The existing Map Screen will display one marker for each sample `FishingSpot`.

Each marker must:

- Use the fishing spot coordinates
- Be derived from the domain entity
- Not contain the authoritative fishing spot data
- Use a simple default visual style

Marker interaction is not included.

---

## Sample Data

The implementation should include a small number of development fishing spots.

Sample data must:

- Use valid coordinates
- Be clearly identified as temporary development data
- Remain outside the domain model
- Be easy to remove when repository-backed data is introduced

---

## Dependencies

No new external dependencies are required.

Existing dependencies:

- Flutter
- MapLibre
- Riverpod
- GoRouter

Riverpod does not need to be introduced into this feature yet unless already required by the current implementation.

---

## Acceptance Criteria

The feature is complete when:

- A framework-independent `FishingSpot` entity exists.
- The entity contains only the approved initial fields.
- Sample fishing spot data exists outside the domain model.
- The map displays one marker for each sample fishing spot.
- Marker coordinates match the corresponding domain entity.
- Map pan, zoom, and user location continue to work.
- No persistence or creation workflow is implemented.
- The application builds successfully.
- `flutter analyze` completes without issues.

---

## Validation

The feature must be tested on a physical Android device.

Validation includes:

- Map loads correctly
- Fishing spot markers are visible
- Markers remain positioned correctly while panning and zooming
- Existing location functionality still works
- Application does not crash

---

## Future Extensions

This foundation will later support:

- Creating fishing spots from the map
- Editing fishing spot names and coordinates
- Deleting fishing spots
- Marker selection
- Fishing spot details
- Local persistence with Drift
- Photos
- Notes
- Catch records
- Lure usage
- Visit history
- Cloud synchronization