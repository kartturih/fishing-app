# Project Status

## Last Updated

2026-07-15

---

## Current Phase

The initial map foundation and map controls are complete.

The next development phase is the **User Location Feature**.

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
- Feature-first project structure created
- Initial application theme created
- Initial design tokens created

### Architecture and Specifications

- ADR-0001: Project Architecture accepted
- ADR-0002: Map Technology accepted
- MFS-001: Map Feature completed
- MFS-002: Map Controls completed

### Map Feature

- MapLibre integrated
- Initial interactive map screen implemented
- Map screen configured as the initial application route
- Initial camera position configured for Finland
- Map panning verified
- Map zooming verified
- Map controls added above the map
- Current location placeholder button added
- Map settings placeholder button added
- SafeArea support added for map controls
- Map controls extracted into a reusable presentation widget

### Validation

- Application tested on a physical Android device
- Map rendering verified
- Touch interaction verified
- Map controls verified
- `flutter analyze` passes without issues

---

## Current Technical Stack

### Framework

- Flutter
- Dart

### Architecture

- Offline-first
- Feature-first
- Repository Pattern planned

### State Management

- Riverpod

### Navigation

- GoRouter

### Maps

- MapLibre GL
- `maplibre_gl`

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
├── core/
├── features/
│   ├── home/
│   │   └── presentation/
│   └── map/
│       └── presentation/
│           ├── map_screen.dart
│           └── widgets/
│               └── map_controls.dart
└── main.dart
```

---

## Current Application State

The application starts successfully on a physical Android device.

The current application includes:

- ProviderScope
- MaterialApp.router
- GoRouter
- Centralized application theme
- Design tokens
- Interactive MapLibre map
- Map pan and zoom interaction
- Placeholder map controls

The current map style uses the MapLibre demo tile service for development purposes only.

---

## Android Build Configuration

Kotlin incremental compilation is currently disabled:

```properties
kotlin.incremental=false
```

This was required because the Kotlin compiler failed when the project and the Dart package cache were located on different Windows drives.

The current `maplibre_gl` package also produces a warning concerning future Flutter Built-in Kotlin compatibility. The warning does not currently prevent the application from building or running, but package compatibility must be reviewed during future dependency upgrades.

---

## Development Workflow

1. ChatGPT acts as Software Architect and Technical Lead.
2. A feature specification or architectural decision is created when required.
3. Claude Code implements one scoped task at a time.
4. Claude runs `flutter analyze`.
5. The implementation is reviewed.
6. The feature is tested on a physical Android device.
7. One logical change is committed at a time.

Rules:

- No architectural changes without discussion.
- No new dependencies without justification.
- No changes outside the assigned task.
- Keep commits small and focused.
- Do not implement postponed functionality early.
- Test device-dependent functionality on physical hardware.

---

## Next Planned Task

Define the **User Location Feature**.

Before implementation:

1. Define the exact MVP scope.
2. Compare suitable Flutter location packages.
3. Decide how permissions and location services are handled.
4. Define state-management responsibilities.
5. Document the feature as MFS-003.
6. Implement only the approved scope.

The initial User Location Feature is expected to include:

- Foreground location permission handling
- Detection of disabled location services
- Displaying the user's current location on the map
- Centering the map using the existing location button
- Basic denied-permission and unavailable-location states

The following functionality remains postponed:

- Background location
- Route recording
- Continuous trip tracking
- Fishing spot management
- Catch logging
- Offline map downloads
- Local database
- Cloud synchronization