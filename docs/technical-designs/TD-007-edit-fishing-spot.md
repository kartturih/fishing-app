# TD-007: Edit Fishing Spot Implementation

## Status

Approved

## Date

2026-07-17

---

## Purpose

This document describes the technical implementation of MFS-007.

It defines how existing fishing spots can be selected, renamed, persisted, and immediately reflected on the map while preserving the existing architecture.

---

## Dependencies

No new external dependencies are required.

Existing dependencies:

* Flutter
* MapLibre
* Drift

---

## Files to Create

```text
lib/
└── features/
    └── fishing_spots/
        └── presentation/
            └── widgets/
                └── fishing_spot_details_bottom_sheet.dart
```

---

## Files to Modify

```text
lib/
└── features/
    ├── fishing_spots/
    │   └── data/
    │       └── fishing_spot_repository.dart
    │
    └── map/
        └── presentation/
            └── map_screen.dart
```

No database schema changes are required.

---

## Responsibilities

### FishingSpotRepository

Add support for updating the name of an existing fishing spot.

Responsible for:

* Finding the persisted fishing spot by identifier
* Updating only the fishing spot name
* Preserving the existing identifier, coordinates, and creation timestamp
* Returning the updated `FishingSpot` domain entity

The repository remains the only component responsible for persistence.

Suggested method shape:

```dart
Future<FishingSpot> updateName({
  required String id,
  required String name,
});
```

The exact method name may follow the existing repository naming style.

---

### FishingSpotDetailsBottomSheet

Responsible for:

* Displaying the selected fishing spot name
* Providing an **Edit Name** action
* Allowing the user to enter a new name
* Rejecting empty or whitespace-only names
* Returning the updated name to the caller

Must not:

* Access Drift
* Access the database
* Access the repository
* Update map markers
* Contain persistence logic

The existing fishing spot name input widget may be reused when practical.

---

### MapScreen

Responsible for:

* Associating rendered map annotations with `FishingSpot` identifiers
* Detecting fishing spot marker taps
* Resolving the selected `FishingSpot`
* Opening the fishing spot details bottom sheet
* Calling the repository update method
* Updating the displayed marker label after a successful save
* Handling repository and marker update failures gracefully

Must not:

* Execute SQL
* Access Drift directly
* Access database tables directly
* Contain persistence mapping logic

---

## Marker Identity

MapScreen must retain enough presentation state to associate each rendered fishing spot annotation with its corresponding `FishingSpot.id`.

MapLibre annotations must not become the authoritative source of fishing spot data.

```text
FishingSpot.id
      ↓
Map annotation reference
```

The database-backed `FishingSpot` remains the source of truth.

---

## User Interaction Flow

```text
User taps fishing spot marker
              ↓
Resolve FishingSpot by marker association
              ↓
FishingSpotDetailsBottomSheet
              ↓
Edit Name
              ↓
Validate input
              ↓
FishingSpotRepository
              ↓
Drift
              ↓
SQLite
              ↓
Updated FishingSpot
              ↓
Update marker label
```

---

## Database Update

No schema migration is required.

Only the existing `name` column is updated.

The following values must remain unchanged:

* `id`
* `latitude`
* `longitude`
* `created_at`

If the fishing spot identifier does not exist, the update must fail gracefully.

---

## Marker Updates

After a successful repository update:

1. Identify the existing map annotation for the fishing spot.
2. Update or replace its text label using the new name.
3. Preserve the existing marker coordinates and visual style.
4. Preserve all other fishing spot markers.

The complete map must not be recreated solely to update one fishing spot name.

The user must see the updated name without restarting the application.

---

## State Management

No new state-management abstraction is introduced.

MapScreen may continue using its existing local state and MapLibre controller management.

Do not introduce:

* New Riverpod providers
* A DAO abstraction
* A separate update request model
* Unrelated state-management refactoring

---

## Error Handling

The implementation must handle gracefully:

* Empty or whitespace-only names
* Unknown fishing spot identifiers
* Failed database updates
* Failed marker updates
* User cancellation

Failures must not crash the application.

If persistence fails, the existing marker label must remain unchanged.

If persistence succeeds but the marker update fails, the failure should be logged and the persisted value must appear after the next reload.

---

## Out of Scope

Do not implement:

* Coordinate editing
* Marker dragging
* Deleting fishing spots
* Notes
* Photos
* Catch information
* Favorites
* Cloud synchronization
* New database tables
* Database migrations
* DAO abstractions
* Unrelated map refactoring

---

## Acceptance

The implementation is complete when:

* A fishing spot marker can be tapped.
* The correct fishing spot is selected.
* The fishing spot details bottom sheet opens.
* The current name is displayed.
* The user can edit the name.
* Empty or whitespace-only names are rejected.
* The repository updates the database.
* The marker label updates immediately.
* Other markers remain unchanged.
* The updated name persists after restarting the application.
* Existing fishing spot creation continues to work.
* Existing map and user location functionality continue to work.
* `flutter analyze` completes successfully.
* The feature is verified on a physical Android device.
