# TD-005: Create Fishing Spot Implementation

## Status

Approved

## Date

2026-07-15

---

## Purpose

This document describes the technical implementation of MFS-005.

It defines the files, responsibilities, state transitions, and UI interactions required to create new fishing spots.

---

## Dependencies

No new external dependencies are required.

Existing dependencies:

- Flutter
- MapLibre
- Geolocator

---

## Files to Create

```text
lib/
└── features/
    └── fishing_spots/
        └── presentation/
            └── widgets/
                ├── add_fishing_spot_bottom_sheet.dart
                └── fishing_spot_name_bottom_sheet.dart
```

---

## Files to Modify

```text
lib/
├── features/
│   ├── fishing_spots/
│   │   └── data/
│   │       └── sample_fishing_spots.dart
│   │
│   └── map/
│       └── presentation/
│           ├── map_screen.dart
│           └── widgets/
│               └── map_controls.dart
│
└── core/
    └── location/
        └── location_service.dart
```

---

## Responsibilities

### MapScreen

Responsible for:

- Opening the Add Fishing Spot menu
- Entering map selection mode
- Managing the crosshair state
- Creating new FishingSpot objects
- Rendering new markers
- Updating the temporary in-memory collection

Must not:

- Contain BottomSheet widget implementation

---

### MapControls

Responsible for:

- Displaying the Add Fishing Spot button
- Hiding controls during map selection mode
- Forwarding button presses

Must not:

- Create FishingSpot objects
- Access LocationService

---

### AddFishingSpotBottomSheet

Responsible for:

Displaying two actions:

- Current Location
- Select From Map

No business logic.

---

### FishingSpotNameBottomSheet

Responsible for:

- Asking the user for a fishing spot name
- Returning the entered name

Validation:

- Name cannot be empty
- Whitespace-only names are not allowed

No persistence logic.

---

## Temporary Storage

Fishing spots continue to exist only in memory.

No repository.

No database.

No persistence.

The existing development collection becomes mutable for the duration of the application session.

---

## Current Location Flow

```text
+
        ↓
Bottom Sheet
        ↓
Current Location
        ↓
LocationService
        ↓
FishingSpotNameBottomSheet
        ↓
Create FishingSpot
        ↓
Update marker collection
```

---

## Map Selection Flow

```text
+
        ↓
Bottom Sheet
        ↓
Select From Map
        ↓
Map Selection Mode
        ↓
Crosshair
        ↓
Add Here
        ↓
FishingSpotNameBottomSheet
        ↓
Create FishingSpot
        ↓
Update marker collection
```

---

## Map Selection Mode

When active:

- Crosshair is visible.
- The crosshair remains fixed in the center of the usable map area.
- The map remains pannable and zoomable.
- Existing fishing spot markers remain visible.
- Current Location button is hidden.
- Add Fishing Spot button is hidden.
- Settings button is hidden.

Visible controls:

- Cancel
- Add Here

Leaving map selection mode restores the normal UI.

---

## Marker Updates

After a new FishingSpot is created:

- Add the FishingSpot to the in-memory collection.
- Create one marker for the new spot.
- Existing markers must remain visible.
- Do not recreate every marker unless required.

---

## Identifier Generation

Each new FishingSpot receives:

- A simple unique String identifier.
- The current DateTime as `createdAt`.

No additional dependency is required for identifier generation.

---

## Error Handling

Handle gracefully:

- User cancels the creation method bottom sheet.
- User cancels the name bottom sheet.
- User cancels map selection.
- Empty or whitespace-only spot name.
- Location unavailable.
- Permission denied.

The application must never crash.

---

## Out of Scope

Do not implement:

- Drift
- Repository
- Editing
- Deleting
- Marker selection
- Marker details
- Photos
- Notes
- Catches
- Categories
- Cloud synchronization

---

## Acceptance

The implementation is complete when:

- The Add Fishing Spot button opens the Bottom Sheet.
- Both creation methods function correctly.
- A non-empty name is required.
- New markers appear immediately.
- Existing markers remain.
- Crosshair mode behaves correctly.
- Existing map functionality continues to work.
- `flutter analyze` completes successfully.
- The feature is verified on a physical Android device.