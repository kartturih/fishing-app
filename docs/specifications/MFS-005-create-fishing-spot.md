# MFS-005: Create Fishing Spot

## Status

Approved

## Date

2026-07-15

---

## Purpose

The purpose of this feature is to allow the user to create new fishing spots.

A fishing spot can be created either from the user's current location or by selecting a position on the map.

This feature establishes the foundation for personal fishing spot management.

---

## User Story

As a user,

I want to create a fishing spot,

so that I can save important fishing locations for future trips.

---

## MVP Scope

The initial implementation includes:

- Add Fishing Spot button
- Bottom sheet for creation method selection
- Create spot from current location
- Create spot by selecting a location on the map
- Crosshair-based map selection
- Spot name input
- Temporary in-memory storage
- Immediate marker rendering

---

## Creation Methods

### Current Location

Workflow:

1. Press the Add Fishing Spot button.
2. Select **Current Location**.
3. Enter a fishing spot name.
4. Save.
5. A new fishing spot marker appears on the map.

---

### Select From Map

Workflow:

1. Press the Add Fishing Spot button.
2. Select **Select From Map**.
3. Enter map selection mode.
4. A crosshair appears in the center of the screen.
5. Move the map until the desired location is under the crosshair.
6. Press **Add Here**.
7. Enter a fishing spot name.
8. Save.
9. A new fishing spot marker appears on the map.

---

## Map Selection Mode

While selecting a location from the map:

- The crosshair remains fixed in the center of the screen.
- The map moves beneath the crosshair.
- Existing fishing spot markers remain visible.
- Existing map gestures remain available.

The following controls are temporarily hidden:

- Current Location
- Add Fishing Spot
- Settings

Only the controls required for map selection are visible.

---

## Spot Name

The user must provide a name before saving.

No validation beyond requiring a non-empty name is required.

---

## Data Storage

Fishing spots are stored only in memory.

Persistence is intentionally excluded from this feature.

---

## Out of Scope

The following functionality is intentionally excluded:

- Drift database
- Repository implementation
- Editing fishing spots
- Deleting fishing spots
- Photos
- Notes
- Catch records
- Favorites
- Categories
- Cloud synchronization
- Import / Export
- Marker interaction

---

## Architecture

The implementation must follow ADR-0004.

The authoritative data remains the `FishingSpot` domain entity.

Map markers are generated from domain objects.

---

## Dependencies

No new external dependencies are required.

---

## Acceptance Criteria

The feature is complete when:

- The Add Fishing Spot button opens the creation menu.
- The user can create a fishing spot using the current location.
- The user can create a fishing spot by selecting a location on the map.
- A name is required before saving.
- The new marker appears immediately.
- Existing markers remain visible.
- Existing location functionality continues to work.
- Existing map controls continue to work outside map selection mode.
- `flutter analyze` completes successfully.

---

## Validation

The feature must be tested on a physical Android device.

Validation includes:

- Creating a spot from the current location.
- Creating a spot from the map.
- Verifying the new marker appears immediately.
- Verifying existing markers remain.
- Verifying map selection mode behaves correctly.
- Verifying normal map controls return after leaving selection mode.

---

## Future Extensions

This feature will later support:

- Local persistence with Drift
- Editing fishing spots
- Deleting fishing spots
- Marker selection
- Fishing spot details
- Photos
- Notes
- Catch records
- Favorite spots
- Cloud synchronization
- Shared fishing spots