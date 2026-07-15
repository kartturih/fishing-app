# ADR-0004: Fishing Spot Domain

## Status

Accepted

## Date

2026-07-15

---

## Context

Fishing spots are a central domain concept in Fishing App.

A fishing spot may later be connected to:

- Catch records
- Lures
- Photos
- Notes
- Visit history
- Weather conditions
- Water conditions
- Statistics
- Recommendations

The application must therefore treat a fishing spot as more than a visual marker on the map.

If map markers are used as the primary data model, the domain would become tightly coupled to the map implementation and difficult to extend.

---

## Decision

A fishing spot will be represented as a persistent domain entity named `FishingSpot`.

The map marker is only a visual representation of a `FishingSpot`.

```text
FishingSpot
    ↓
Map Marker
```

The marker must never be treated as the primary source of fishing spot data.

---

## Initial Domain Model

The initial `FishingSpot` entity will contain only stable core fields:

```text
id
name
latitude
longitude
createdAt
```

Additional fields must not be added before they are required by an approved feature.

---

## Identity

Each fishing spot must have its own stable identifier.

The identifier will be used to associate future data with the fishing spot.

Examples:

```text
FishingSpot
    ├── Catch records
    ├── Photos
    ├── Notes
    ├── Visits
    └── Lure usage
```

Related entities will reference the fishing spot identifier rather than embedding all related data directly inside the `FishingSpot` model.

---

## Domain Independence

The `FishingSpot` domain model must not depend on:

- Flutter
- Material widgets
- MapLibre
- Geolocator
- Drift
- Supabase
- Platform APIs

The domain model represents application data and must remain independent of UI, map, persistence, and platform technologies.

---

## Map Representation

The Map Feature may convert `FishingSpot` data into MapLibre markers or symbols.

Map-specific properties must remain inside the Map Feature.

Examples of map-specific concerns:

- Marker icon
- Marker size
- Marker color
- Selection state
- Map layer configuration
- Symbol identifiers

These properties must not be added to the domain entity unless they later become genuine product data.

---

## Future Relationships

Future entities may reference `FishingSpot.id`.

Examples include:

```text
Catch
- id
- fishingSpotId
- species
- weight
- caughtAt
```

```text
SpotPhoto
- id
- fishingSpotId
- filePath
- createdAt
```

```text
SpotNote
- id
- fishingSpotId
- content
- createdAt
```

Exact models and persistence relationships will be defined later.

---

## Rationale

This separation provides:

- A stable source of truth for fishing spot data
- Independence from the map rendering technology
- Easier persistence and synchronization
- Clear relationships between domain entities
- Easier testing
- Support for future feature growth
- Reduced migration risk if the map implementation changes

---

## Consequences

### Positive

- Fishing spots can exist independently of the map UI
- Map markers remain presentation concerns
- Future related data can reference a stable identifier
- Domain logic remains framework independent
- Persistence technology can be changed without changing the domain concept
- The entity can support future cloud synchronization

### Trade-offs

- Mapping is required between domain objects and map markers
- Related data requires separate entities and relationships
- More structure is needed than using simple map marker objects
- Identifier generation and persistence must be decided separately

---

## Placement

The domain model will belong to the Fishing Spots feature:

```text
lib/
└── features/
    └── fishing_spots/
        └── domain/
            └── fishing_spot.dart
```

The feature owns the domain concept.

The model must not be placed in `core`, because it represents product-specific business data rather than shared technical infrastructure.

---

## Dependency Direction

The Map Feature may depend on the Fishing Spot domain model for visualization.

The Fishing Spot domain model must not depend on the Map Feature.

```text
Map Presentation
       ↓
Fishing Spot Domain
```

---

## Scope

This ADR defines:

- The meaning of a fishing spot
- The separation between domain data and map markers
- The initial stable fields
- The relationship strategy for future data

This ADR does not define:

- Identifier format
- Database schema
- Repository implementation
- Marker appearance
- Spot creation workflow
- Editing or deletion
- Cloud synchronization
- Image storage
- Catch relationships in detail

These decisions will be made when the relevant features are designed.