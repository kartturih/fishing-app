# ADR-0006: Database Ownership

## Status

Accepted

## Date

2026-07-16

---

## Context

Fishing App is transitioning from temporary in-memory storage to persistent local storage using Drift.

As the application grows, multiple features will require database persistence, including:

- Fishing Spots
- Catches
- Lures
- Notes
- Photos
- Trips

A clear ownership model is required to ensure the database architecture remains modular and aligned with the project's feature-first architecture.

---

## Decision

Fishing App will separate shared database infrastructure from feature-specific persistence.

Shared database infrastructure will be implemented under:

```text
lib/
└── core/
    └── database/
```

Each feature owns its own persistence implementation.

Example:

```text
lib/
└── features/
    └── fishing_spots/
        └── data/
            ├── fishing_spots_table.dart
            ├── fishing_spot_repository.dart
            └── fishing_spot_mapper.dart
```

Future features will follow the same structure.

---

## Responsibilities

### Core Database

The Core Database is responsible for:

- Database initialization
- SQLite connection
- Database configuration
- Schema versioning
- Database migrations
- Registering feature tables

The Core Database must not contain feature-specific business logic.

---

### Feature Data Layer

Each feature owns:

- Drift table definitions
- Data mappers
- Repository implementation
- Feature-specific queries

Feature persistence code must remain inside the owning feature.

---

## Rationale

This ownership model preserves the project's feature-first architecture while keeping shared infrastructure centralized.

Benefits include:

- Clear ownership boundaries
- High feature independence
- Better scalability
- Easier maintenance
- Reduced coupling
- Easier testing

New features can introduce persistence without modifying existing feature implementations.

---

## Consequences

Positive:

- Features remain self-contained.
- Database infrastructure is centralized.
- Persistence logic follows feature ownership.
- Future features integrate consistently.
- Repository responsibilities remain clear.

Trade-offs:

- Database-related files are distributed across features.
- AppDatabase must import feature tables.
- Adding a new feature requires registering its tables.

---

## Dependency Direction

```text
Presentation
      ↓
Domain
      ↓
Data
      ↓
Core Database
```

Feature data layers may depend on the Core Database.

The Core Database must not depend on feature business logic.

---

## Scope

This decision defines:

- Ownership of database infrastructure
- Ownership of feature persistence
- Placement of Drift tables
- Placement of repositories
- Dependency direction

This decision does not define:

- Database schema
- Table implementations
- Repository APIs
- SQL queries
- Cloud synchronization

These topics are defined by feature specifications and technical designs.