# TD-003: User Location Implementation

## Status

Approved

## Date

2026-07-15

---

## Purpose

This document describes the technical implementation of MFS-003.

It defines the files, responsibilities, and interactions required to implement the initial User Location feature.

---

## Dependencies

Required:

- geolocator

No additional packages are introduced.

---

## Files to Create

```text
lib/
└── core/
    └── location/
        └── location_service.dart
```

---

## Files to Modify

```text
lib/
└── features/
    └── map/
        └── presentation/
            ├── map_screen.dart
            └── widgets/
                └── map_controls.dart
```

---

## Responsibilities

### LocationService

Responsible for:

- Checking whether location services are enabled
- Checking location permissions
- Requesting permissions
- Retrieving the current position

Must not:

- Access UI
- Show dialogs
- Move the map camera
- Depend on feature code

---

### MapScreen

Responsible for:

- Receiving location button events
- Calling LocationService
- Moving the MapLibre camera
- Displaying the user location layer

Must not:

- Contain permission logic
- Access Geolocator directly

---

### MapControls

Responsible for:

- Displaying the Current Location button
- Forwarding button presses

Must not:

- Access GPS
- Access permissions
- Contain business logic

---

## Data Flow

```text
User
    │
    ▼
MapControls
    │
    ▼
MapScreen
    │
    ▼
LocationService
    │
    ▼
Geolocator
```

The result flows back to the MapScreen, which updates the map camera.

---

## Error Handling

The implementation must handle:

- Location services disabled
- Permission denied
- Permission denied forever
- Position unavailable

Errors should never crash the application.

---

## Out of Scope

Do not implement:

- Continuous location updates
- Streams
- Background location
- Route recording
- Compass
- Bearing
- Speed
- Altitude
- Geofencing
- Fishing spots
- Catch logging

---

## Acceptance

The implementation is complete when:

- The Current Location button requests permission when necessary.
- The current location is obtained.
- The map centers on the user's location.
- The user location is visible on the map.
- Permission failures are handled gracefully.
- `flutter analyze` completes successfully.