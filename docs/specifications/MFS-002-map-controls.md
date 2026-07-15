# MFS-002: Map Controls

## Status

Approved

## Date

2026-07-15

---

## Purpose

The purpose of this feature is to introduce the first interactive controls on top of the map.

This feature establishes the standard layout for map actions while preparing the application for future GPS, layer management, and map settings.

---

## User Story

As a user,

I want the map to provide intuitive controls,

so that future navigation and map interaction feel natural and consistent.

---

## MVP Scope

The initial implementation includes:

- Floating Action Buttons displayed above the map
- SafeArea support
- Bottom-right control placement
- Placeholder button for current location
- Placeholder button for map settings
- Material 3 styling
- Responsive layout

Buttons are visual only and do not perform any actions yet.

---

## Out of Scope

The following functionality is intentionally excluded:

- GPS
- Location permissions
- Camera movement
- Map settings
- Layer switching
- Offline maps
- Compass
- Scale indicator
- Search

---

## UI Layout

```text
+--------------------------------------+
| App Bar                              |
+--------------------------------------+
|                                      |
|                                      |
|                                      |
|              Map                     |
|                                      |
|                             [⚙]      |
|                             [◎]      |
+--------------------------------------+
```

The controls remain above the map and respect the device SafeArea.

---

## Navigation

No navigation changes are introduced.

The controls remain within the existing Map Screen.

---

## Feature Structure

```text
features/
└── map/
    └── presentation/
        ├── map_screen.dart
        └── widgets/
            └── map_controls.dart
```

The controls should be extracted into their own reusable widget.

---

## Dependencies

No additional dependencies are required.

---

## Acceptance Criteria

The feature is complete when:

- The controls are displayed above the map.
- The controls do not obstruct the AppBar.
- The controls respect SafeArea.
- The buttons are visible on different screen sizes.
- Pressing the buttons has no functional effect.
- The application builds successfully.
- `flutter analyze` completes without issues.

---

## Future Extensions

The location button will later:

- Request location permission
- Center the camera on the user's location

The settings button will later:

- Open map settings
- Select map style
- Configure overlays
- Manage offline maps