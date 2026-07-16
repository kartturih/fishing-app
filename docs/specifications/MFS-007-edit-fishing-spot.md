# MFS-007: Edit Fishing Spot

## Status

Approved

## Date

2026-07-17

---

## Purpose

The purpose of this feature is to allow users to edit an existing fishing spot after it has been created.

The initial implementation focuses on editing the fishing spot name while preserving the existing location.

---

## User Story

As a user,

I want to rename an existing fishing spot,

so that I can keep my fishing spots organized as I learn more about them.

---

## MVP Scope

The initial implementation includes:

* Selecting an existing fishing spot
* Opening a fishing spot details bottom sheet
* Editing the fishing spot name
* Saving the updated name to the local database
* Updating the marker label immediately
* Persisting the change between application launches

---

## Out of Scope

The following functionality is intentionally excluded:

* Editing coordinates
* Moving markers
* Deleting fishing spots
* Notes
* Photos
* Catch information
* Favorites
* Cloud synchronization

---

## User Flow

### Editing a Fishing Spot

1. User taps a fishing spot marker.
2. A bottom sheet displaying the fishing spot information opens.
3. User selects **Edit Name**.
4. User enters a new name.
5. User saves the changes.
6. The bottom sheet closes.
7. The marker label updates immediately.
8. The updated name is stored in the local database.

---

## User Interface

The feature introduces a fishing spot details bottom sheet.

The bottom sheet becomes the entry point for future fishing spot actions such as:

* Edit
* Delete
* Notes
* Photos
* Catch history

Only **Edit Name** is implemented in this feature.

---

## Data Storage

Only the fishing spot name is modified.

The following values remain unchanged:

* Fishing spot identifier
* Latitude
* Longitude
* Creation timestamp

---

## Architecture

The implementation follows:

* ADR-0001
* ADR-0003
* ADR-0004
* ADR-0005
* ADR-0006

The repository remains the only component responsible for updating persisted fishing spot data.

The presentation layer must not access Drift or the database directly.

---

## Acceptance Criteria

The feature is complete when:

* A fishing spot can be selected.
* The fishing spot details bottom sheet opens.
* The user can edit the fishing spot name.
* Empty or whitespace-only names are rejected.
* The updated name is saved successfully.
* The marker label updates immediately.
* The updated name remains after restarting the application.
* Existing fishing spot creation continues to work.
* Existing map functionality continues to work.
* Existing user location functionality continues to work.
* `flutter analyze` completes successfully.

---

## Validation

The feature must be tested on a physical Android device.

Validation includes:

* Create a fishing spot.
* Tap the fishing spot marker.
* Open the fishing spot details bottom sheet.
* Rename the fishing spot.
* Verify the updated name is shown immediately.
* Close and restart the application.
* Verify the updated name persists.
* Verify creating new fishing spots still works.
* Verify map and user location functionality still work.

---

## Future Extensions

This feature prepares the fishing spot details view for:

* Delete
* Notes
* Photos
* Catch history
* Favorites
* Coordinate editing
