# MFS-008: Delete Fishing Spot

## Status

Approved

## Date

2026-07-17

---

## Purpose

The purpose of this feature is to allow users to permanently delete an existing fishing spot.

Deletion removes the fishing spot from the local database and the map immediately.

---

## User Story

As a user,

I want to delete a fishing spot,

so that I can remove locations I no longer want to keep.

---

## MVP Scope

The initial implementation includes:

* Selecting an existing fishing spot
* Opening the fishing spot details bottom sheet
* Deleting the selected fishing spot
* Confirming the deletion before removing the fishing spot
* Removing the marker immediately
* Persisting the deletion between application launches

---

## Out of Scope

The following functionality is intentionally excluded:

* Undo
* Soft delete
* Batch deletion
* Coordinate editing
* Notes
* Photos
* Catch information
* Cloud synchronization

---

## User Flow

### Deleting a Fishing Spot

1. User taps a fishing spot marker.
2. The fishing spot details bottom sheet opens.
3. User selects **Delete**.
4. A confirmation dialog is displayed.
5. User confirms the deletion.
6. The fishing spot is removed from the database.
7. The marker disappears immediately.
8. The deletion persists after restarting the application.

---

## User Interface

The existing Fishing Spot Details Bottom Sheet is extended with a **Delete** action.

Deletion must always require user confirmation.

---

## Data Storage

The selected fishing spot is permanently removed from the local database.

---

## Architecture

The implementation follows:

* ADR-0001
* ADR-0003
* ADR-0004
* ADR-0005
* ADR-0006

The repository remains the only component responsible for persistence.

---

## Acceptance Criteria

The feature is complete when:

* A fishing spot can be selected.
* The details bottom sheet opens.
* The user can delete the fishing spot.
* Confirmation is required.
* The fishing spot is removed from the database.
* The marker disappears immediately.
* The deleted fishing spot does not return after restarting the application.
* Existing create and edit functionality continue to work.
* Existing map functionality continues to work.
* `flutter analyze` completes successfully.

---

## Validation

The feature must be tested on a physical Android device.

Validation includes:

* Create a fishing spot.
* Delete the fishing spot.
* Verify the marker disappears.
* Restart the application.
* Verify the fishing spot remains deleted.
* Verify create and edit still function correctly.

---

## Future Extensions

Possible future improvements include:

* Undo
* Soft delete
* Batch deletion
* Trash / recycle bin
