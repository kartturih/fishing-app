# TD-008: Delete Fishing Spot Implementation

## Status

Approved

## Date

2026-07-17

---

## Purpose

This document describes the technical implementation of MFS-008.

It defines how an existing fishing spot is permanently deleted from the local database and removed from the map while preserving the existing architecture.

---

## Dependencies

No new external dependencies are required.

Existing dependencies:

* Flutter
* MapLibre
* Drift

---

## Files to Modify

```text
lib/
└── features/
    ├── fishing_spots/
    │   ├── data/
    │   │   └── fishing_spot_repository.dart
    │   │
    │   └── presentation/
    │       └── widgets/
    │           └── fishing_spot_details_bottom_sheet.dart
    │
    └── map/
        └── presentation/
            └── map_screen.dart
```

No new files are required.

No database schema changes are required.

---

## Responsibilities

### FishingSpotRepository

Add support for deleting an existing fishing spot.

Responsible for:

* Finding the persisted fishing spot by identifier
* Removing the fishing spot from the database
* Reporting success or failure

The repository remains the only component responsible for persistence.

Suggested method shape:

```dart
Future<void> delete(String id);
```

The exact method name may follow the existing repository naming style.

---

### FishingSpotDetailsBottomSheet

Responsible for:

* Displaying a **Delete** action
* Requesting user confirmation before deletion
* Returning the deletion result to the caller

Must not:

* Access Drift
* Access the database
* Access the repository
* Remove map markers
* Contain persistence logic

---

### MapScreen

Responsible for:

* Opening the delete confirmation flow
* Calling the repository delete method
* Removing the deleted fishing spot from the local presentation state
* Updating the GeoJSON source immediately

Must not:

* Execute SQL
* Access Drift directly
* Access database tables directly

---

## User Interaction Flow

```text
User taps fishing spot
            ↓
Fishing Spot Details Bottom Sheet
            ↓
Delete
            ↓
Confirmation Dialog
            ↓
Repository
            ↓
Drift
            ↓
SQLite
            ↓
Remove from presentation state
            ↓
Refresh GeoJSON source
```

---

## Database Update

No schema migration is required.

The selected fishing spot row is permanently removed.

If the fishing spot identifier does not exist, the operation must fail gracefully.

---

## Map Updates

After a successful deletion:

1. Remove the fishing spot from the presentation state.
2. Refresh the GeoJSON source.
3. Remove both the marker and label immediately.
4. Preserve all remaining fishing spot markers.

The map must not be recreated.

---

## State Management

No new state-management abstraction is introduced.

Continue using the existing local state within `MapScreen`.

Do not introduce:

* Riverpod providers
* DAO abstractions
* Additional repositories
* Unrelated refactoring

---

## Error Handling

The implementation must handle gracefully:

* Unknown fishing spot identifiers
* Failed database deletion
* Failed GeoJSON updates
* User cancellation

Failures must not crash the application.

If deletion fails, the fishing spot must remain visible.

---

## Out of Scope

Do not implement:

* Undo
* Soft delete
* Batch deletion
* Coordinate editing
* Notes
* Photos
* Catch information
* Cloud synchronization
* Database migrations

---

## Acceptance

The implementation is complete when:

* A fishing spot can be selected.
* The delete action is available.
* User confirmation is required.
* The repository removes the fishing spot.
* The marker and label disappear immediately.
* Remaining fishing spots remain visible.
* The deleted fishing spot does not return after restarting the application.
* Existing create and edit functionality continue to work.
* Existing map and user location functionality continue to work.
* `flutter analyze` completes successfully.
* The feature is verified on a physical Android device.
