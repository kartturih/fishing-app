# MFS-003: User Location

## Status

Approved

## Date

2026-07-15

---

## Purpose

The purpose of this feature is to allow the application to obtain the user's current location and center the map on it.

This feature establishes the foundation for future location-based functionality while keeping the implementation intentionally minimal.

---

## User Story

As a user,

I want to center the map on my current location,

so that I can quickly orient myself when arriving at a fishing location.

---

## MVP Scope

The initial implementation includes:

- Request foreground location permission
- Detect whether location services are enabled
- Obtain the user's current location
- Center the map on the current location
- Display the user's location on the map
- Connect the functionality to the existing location button

---

## Out of Scope

The following functionality is intentionally excluded:

- Background location
- Continuous location tracking
- Route recording
- Heading / compass
- Bearing
- Speed
- Altitude
- Geofencing
- Location history
- Fishing spots
- Catch logging

---

## User Flow

1. User presses the Current Location button.
2. The application checks whether location services are enabled.
3. If disabled, the user is informed.
4. The application checks location permission.
5. If permission has not been granted, it is requested.
6. If permission is granted, the current location is obtained.
7. The map camera moves to the user's position.
8. The user's location is displayed on the map.

---

## Permission Handling

The implementation must handle:

- Permission granted
- Permission denied
- Permission denied permanently
- Location services disabled

The application must never crash due to missing permissions.

---

## Architecture

Location access must be implemented as a Core Service according to ADR-0003.

Example structure:

```text
lib/
├── core/
│   └── location/
│       └── location_service.dart
└── features/
    └── map/
```

The Map Feature must not communicate directly with the location package.

---

## Dependencies

Required:

- geolocator

No additional state-management packages are required.

---

## Acceptance Criteria

The feature is complete when:

- Pressing the location button requests permission when necessary.
- Disabled location services are detected.
- The user's current location is obtained.
- The map centers on the user's location.
- The user's location is visible on the map.
- Permission denial is handled gracefully.
- `flutter analyze` completes successfully.

---

## Future Extensions

This feature will later support:

- Continuous location updates
- Route recording
- Navigation
- Fishing spot creation from current location
- Catch logging using current location
- Compass integration
- Background tracking
- Battery optimization