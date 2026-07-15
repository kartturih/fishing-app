# Project Status

## Last Updated

2026-07-15

---

## Current Phase

The application foundation and core map functionality are complete.

The next development phase is **Fishing Spot Management**.

---

## Completed

### Project Foundation

- Git repository initialized
- GitHub repository connected
- Initial project documentation created
- Flutter project initialized
- Android development environment configured
- Riverpod integrated
- GoRouter integrated
- Feature-first project structure established
- Material 3 theme implemented
- Initial design token system created

### Architecture

- ADR-0001: Project Architecture
- ADR-0002: Map Technology
- ADR-0003: Core Services

### Feature Specifications

- MFS-001: Map Feature
- MFS-002: Map Controls
- MFS-003: User Location

### Technical Designs

- TD-003: User Location Implementation

### Implemented Features

#### Map Foundation

- MapLibre integrated
- Interactive map implemented
- Initial camera positioned over Finland
- Map configured as the application start screen
- Pan and zoom functionality verified

#### Map Controls

- Reusable MapControls widget
- Material 3 Floating Action Buttons
- SafeArea support
- Current Location button
- Map Settings placeholder button

#### User Location

- Core LocationService implemented
- Foreground location permission handling
- Location service availability detection
- Current location retrieval
- Camera centering on current location
- User location layer enabled
- Graceful handling of:
  - Disabled location services
  - Permission denied
  - Permission denied forever
  - Unavailable position

---

## Validation

Verified on a physical Android device:

- Application starts successfully
- Map loads correctly
- Pan and zoom work correctly
- Map controls function correctly
- Location permission flow verified
- Camera centers on current location
- Disabled location services handled correctly
- `flutter analyze` passes without issues

---

## Current Technical Stack

### Framework

- Flutter
- Dart

### Architecture

- Offline-first
- Feature-first
- Core Services
- Repository Pattern (planned)

### State Management

- Riverpod

### Navigation

- GoRouter

### Maps

- MapLibre GL
- maplibre_gl

### Location

- geolocator

### UI

- Material 3
- Centralized Theme
- Design Tokens

### Planned

- Drift (SQLite)
- Supabase (future)

---

## Current Application Structure

```text
lib/
├── app/
│   ├── router/
│   ├── theme/
│   └── app.dart
│
├── core/
│   └── location/
│       └── location_service.dart
│
├── features/
│   ├── home/
│   └── map/
│       └── presentation/
│           ├── map_screen.dart
│           └── widgets/
│               └── map_controls.dart
│
└── main.dart
```

---

## Current Application State

The application currently provides:

- Interactive map
- Map controls
- Current user location
- Permission handling
- Camera centering
- Physical Android support

The application is now ready for location-based fishing functionality.

---

## Android Configuration

Foreground location permissions are configured:

- ACCESS_FINE_LOCATION
- ACCESS_COARSE_LOCATION

Background location is intentionally **not** implemented.

Kotlin incremental compilation is currently disabled:

```properties
kotlin.incremental=false
```

This workaround is currently required because of a Kotlin incremental compilation issue when the project and the Pub cache are located on different Windows drives.

---

## Development Workflow

1. Architectural decision (ADR) when required
2. Feature specification (MFS)
3. Technical design (TD)
4. Claude Code implementation
5. flutter analyze
6. Architecture review
7. Physical Android testing
8. Git commit
9. Project status update

Project rules:

- Architecture decisions require an ADR.
- Features require an MFS.
- Complex implementations require a TD.
- Device features must be tested on physical hardware.
- No architectural shortcuts.
- No unnecessary abstractions.
- Keep commits small and focused.

---

## Next Planned Task

### Fishing Spot Foundation

The next feature is expected to establish the foundation for fishing spots.

Planning includes:

- Fishing Spot data model
- Marker architecture
- Marker rendering
- Spot creation workflow
- Map interaction
- Repository design
- Local persistence strategy

Before implementation:

1. Define the architecture.
2. Write ADRs if required.
3. Create MFS.
4. Create TD.
5. Implement a minimal MVP.

Future features remain postponed:

- Catch logging
- Offline maps
- Route recording
- Weather integration
- Cloud synchronization
- Social features
- Statistics