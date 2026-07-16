# TD-006: Local Persistence Implementation

## Status

Approved

## Date

2026-07-16

---

## Purpose

This document describes the technical implementation of MFS-006.

It defines the database structure, repository responsibilities, data flow, and file organization required to replace the temporary in-memory fishing spot storage with persistent local storage using Drift.

---

## Dependencies

Required:

- drift
- drift_flutter

Development:

- drift_dev
- build_runner

---

## Files to Create

```text
lib/
├── core/
│   └── database/
│       └── app_database.dart
│
└── features/
    └── fishing_spots/
        ├── data/
        │   ├── fishing_spots_table.dart
        │   ├── fishing_spot_repository.dart
        │   └── fishing_spot_mapper.dart
        │
        └── domain/
```

---

## Files to Modify

```text
lib/
└── features/
    ├── fishing_spots/
    │   └── data/
    │       └── sample_fishing_spots.dart
    │
    └── map/
        └── presentation/
            └── map_screen.dart
```

The temporary sample data should be removed once database-backed storage is operational.

---

## Responsibilities

### AppDatabase

Responsible for:

- Database initialization
- SQLite connection
- Database configuration
- Schema versioning
- Registering feature tables

Must not:

- Contain business logic
- Contain UI logic

---

### FishingSpotsTable

Responsible for defining the persistence model.

Columns:

- id
- name
- latitude
- longitude
- created_at

The table must not contain presentation-related fields.

---

### FishingSpotRepository

Responsible for:

- Load all fishing spots
- Watch fishing spot changes
- Create fishing spots
- Hide all persistence details from the domain and presentation layers

The repository must return domain entities instead of Drift-generated classes.

---

### FishingSpotMapper

Responsible for converting between:

```text
FishingSpot
      ⇄
FishingSpotsTableData
```

The mapper is the only component responsible for conversions between persistence models and domain entities.

No mapping logic should exist inside the repository or UI.

---

### MapScreen

Responsible for:

- Requesting fishing spots from the repository
- Rendering fishing spot markers
- Creating new fishing spots through the repository

Must not:

- Execute SQL
- Access Drift directly
- Access database tables directly

---

## Database Flow

### Application Startup

```text
SQLite
    ↓
Drift
    ↓
FishingSpotRepository
    ↓
Domain Entities
    ↓
MapScreen
    ↓
Map Markers
```

---

### Creating a Fishing Spot

```text
User
    ↓
MapScreen
    ↓
FishingSpotRepository
    ↓
Drift
    ↓
SQLite
    ↓
FishingSpotRepository
    ↓
Domain Entities
    ↓
Map Markers
```

---

## Database Schema

Initial table:

```text
FishingSpots

id TEXT PRIMARY KEY
name TEXT
latitude REAL
longitude REAL
created_at INTEGER
```

No additional columns are introduced.

---

## Identifier Strategy

The existing `FishingSpot.id` remains a `String`.

The repository generates identifiers before inserting data into the database.

The database does not generate identifiers.

---

## Source of Truth

The SQLite database is the single source of truth for persisted fishing spot data.

The application must never maintain a separate authoritative in-memory fishing spot collection.

---

## Error Handling

The implementation must handle gracefully:

- Database initialization failures
- Failed inserts
- Failed reads

Errors must never crash the application.

---

## Out of Scope

Do not implement:

- Editing fishing spots
- Deleting fishing spots
- Catch persistence
- Notes
- Photos
- Database encryption
- Cloud synchronization
- Backup
- Import / Export

---

## Acceptance

The implementation is complete when:

- Drift initializes successfully.
- The database is created automatically.
- Fishing spots are loaded from the database.
- New fishing spots are stored in the database.
- Fishing spots remain after restarting the application.
- Existing map functionality continues to work.
- Existing user location functionality continues to work.
- `flutter analyze` completes successfully.
- The feature is verified on a physical Android device.