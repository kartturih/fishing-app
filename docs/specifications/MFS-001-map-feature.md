# MFS-001: Map Feature

## Status

Approved

## Date

2026-07-15

---

## Purpose

The purpose of this feature is to provide the foundation of the Fishing App by introducing the application's primary map view.

This feature establishes the base for future functionality including GPS positioning, fishing spots, catch locations, offline maps, and environmental overlays.

---

## User Story

As a user,

I want to open the application and immediately see a map,

so that I can navigate to my fishing area and later interact with fishing-related information.

---

## MVP Scope

The initial implementation includes:

- Full-screen interactive map
- Pan gestures
- Zoom gestures
- Initial camera position in Finland
- Material 3 application styling
- Feature-first implementation
- Integration with the existing application router

---

## Out of Scope

The following functionality is intentionally excluded:

- User location
- GPS permissions
- Fishing spots
- Catch markers
- Route recording
- Offline maps
- Search
- Custom map layers
- Local database
- Cloud synchronization

---

## UI Layout

```text
+--------------------------------------+
| App Bar                              |
+--------------------------------------+
|                                      |
|                                      |
|                                      |
|            Interactive Map           |
|                                      |
|                                      |
|                                      |
+--------------------------------------+
```

The map occupies the remaining available screen space.

---

## Navigation

The application starts on the Map Screen.

Future navigation to additional features will be introduced later.

---

## Feature Structure

```text
features/
└── map/
    └── presentation/
        └── map_screen.dart
```

No domain or data layers are required during the first implementation.

---

## Dependencies

Required:

- maplibre_gl

Already available:

- Flutter
- Riverpod
- GoRouter
- Material 3

---

## Acceptance Criteria

The feature is complete when:

- The application opens successfully.
- The map is displayed.
- The user can pan the map.
- The user can zoom the map.
- The application builds successfully.
- `flutter analyze` completes without issues.

---

## Future Extensions

This feature will later support:

- GPS positioning
- Fishing spot markers
- Catch visualization
- Offline map storage
- Environmental overlays
- Map settings
- Custom layers
- Route recording