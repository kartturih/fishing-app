# TD-004: Fishing Spot Foundation Implementation

## Status

Approved

## Date

2026-07-15

---

## Purpose

This document describes the technical implementation of MFS-004.

It defines the files, responsibilities, and data flow required to introduce the `FishingSpot` domain entity and render sample fishing spot markers on the map.

---

## Dependencies

No new external dependencies are required.

Existing dependencies used:

- Flutter
- MapLibre
- Dart

Riverpod is not required for this implementation.

---

## Files to Create

```text
lib/
└── features/
    └── fishing_spots/
        ├── domain/
        │   └── fishing_spot.dart
        └── data/
            └── sample_fishing_spots.dart
```

---

## Files to Modify

```text
lib/
└── features/
    └── map/
        └── presentation/
            └── map_screen.dart
```

No other files should be modified unless required by the implementation.

---

## Domain Model

### FishingSpot

The `FishingSpot` entity must be a plain Dart class.

Required fields:

```text
id
name
latitude
longitude
createdAt
```

The model must not import:

- Flutter
- MapLibre
- Geolocator
- Drift
- Supabase
- Platform APIs

Suggested structure:

```dart
class FishingSpot {
  const FishingSpot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
}
```

No serialization, equality helpers, `copyWith`, or persistence annotations are required yet.

---

## Sample Data

### sample_fishing_spots.dart

This file contains temporary development data.

Responsibilities:

- Define a small immutable list of `FishingSpot` entities
- Use valid coordinates
- Make the development-only purpose clear
- Keep sample data separate from the domain model

Suggested shape:

```dart
const sampleFishingSpots = <FishingSpot>[
  // Development-only sample spots
];
```

Because `DateTime` cannot be used in a compile-time constant unless constructed with a constant constructor, use fixed `DateTime` values that are valid in const context or define the list as `final`.

The implementation should prefer clarity over forcing the data to be `const`.

---

## Map Integration

`MapScreen` remains responsible for map presentation.

It must:

- Read the sample fishing spot entities
- Convert each `FishingSpot` into a MapLibre symbol
- Add symbols after the map style has loaded
- Keep marker rendering separate from the domain model
- Preserve existing location functionality

The domain entity must not know anything about MapLibre symbols.

---

## MapLibre Lifecycle

Fishing spot markers must be added only after the map style is available.

Use the appropriate MapLibre lifecycle callback, such as:

```text
onStyleLoadedCallback
```

The implementation must not assume that symbols can safely be added immediately in `onMapCreated`.

Recommended lifecycle:

```text
Map created
    ↓
Controller stored
    ↓
Style loaded
    ↓
Sample FishingSpot entities converted to symbols
    ↓
Symbols added to map
```

---

## Marker Rendering

Each `FishingSpot` must produce one MapLibre symbol.

The marker must use:

- `FishingSpot.latitude`
- `FishingSpot.longitude`

Marker styling should remain minimal.

Acceptable initial styling:

- Built-in marker icon, if available
- Simple symbol icon
- Optional text label using `FishingSpot.name`

The implementation must not introduce:

- Custom asset icons
- Marker selection
- Marker tap handling
- Detail sheets
- Clustering
- Multiple marker styles

---

## Duplicate Prevention

Marker creation must not produce duplicate symbols if the map style callback runs more than once.

The implementation should use one simple mechanism, such as:

- Clearing existing symbols before re-adding
- Tracking whether sample markers have already been added
- Replacing the current symbol collection

Do not introduce a dedicated marker repository or state-management abstraction.

---

## Responsibilities

### FishingSpot

Responsible for:

- Representing fishing spot domain data

Must not:

- Render markers
- Access MapLibre
- Access UI
- Access persistence
- Generate platform-specific data

---

### Sample Fishing Spot Data

Responsible for:

- Providing temporary development entities

Must not:

- Contain MapLibre symbols
- Perform application logic
- Be treated as permanent storage

---

### MapScreen

Responsible for:

- Managing MapLibre lifecycle
- Converting fishing spots to presentation symbols
- Adding symbols to the map
- Preserving existing location and camera behavior

Must not:

- Mutate domain entities
- Treat MapLibre symbols as the source of truth
- Introduce persistence logic

---

## Data Flow

```text
sample_fishing_spots.dart
          ↓
List<FishingSpot>
          ↓
MapScreen
          ↓
MapLibre SymbolOptions
          ↓
MapLibre Map
```

The authoritative development data remains the `List<FishingSpot>`.

---

## Error Handling

Marker rendering errors must not crash the application.

The implementation may:

- Catch unexpected MapLibre symbol creation errors
- Skip invalid development entries
- Use debug logging if needed

Do not introduce a new logging framework.

Sample coordinates must be valid, so validation logic is not required in this version.

---

## Out of Scope

Do not implement:

- Spot creation
- Long-press interaction
- Marker taps
- Editing
- Deletion
- Repository pattern
- Drift
- Persistence
- Riverpod providers
- Custom marker assets
- Marker clustering
- Spot details
- Photos
- Notes
- Catches
- Lures

---

## Acceptance

The implementation is complete when:

- `FishingSpot` exists as a framework-independent domain entity.
- Sample fishing spots are defined outside the domain model.
- One map symbol is displayed for each sample fishing spot.
- Marker positions match the domain coordinates.
- Existing pan, zoom, map controls, and user location still work.
- Duplicate markers are not created.
- No new dependencies are added.
- `flutter analyze` completes successfully.
- The feature works on a physical Android device.