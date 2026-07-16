# ADR-0005: Local Persistence

## Status

Accepted

## Date

2026-07-16

---

## Context

Fishing App currently stores fishing spots only in memory.

This means all user-created fishing spots are lost when the application is closed.

The application follows an offline-first architecture and must remain fully usable without an internet connection. Fishing spots therefore require reliable local persistence before additional fishing spot features are introduced.

The persistence solution must support:

- Offline usage
- Structured relational data
- Type-safe queries
- Database migrations
- Reactive data updates
- Testing
- Future cloud synchronization
- Additional domain entities such as catches, lures, notes, and photos

---

## Decision

Fishing App will use **Drift** as its local persistence technology.

Drift will use SQLite as the underlying database.

Shared database infrastructure will be implemented under:

```text
lib/
└── core/
    └── database/
```

Fishing spot persistence will remain owned by the Fishing Spots feature:

```text
lib/
└── features/
    └── fishing_spots/
        └── data/
```

The application will access fishing spot data exclusively through a repository.

```text
Presentation
    ↓
Repository
    ↓
Drift
    ↓
SQLite
```

The user interface must never communicate directly with Drift tables or SQL queries.

---

## Rationale

Drift provides:

- Type-safe database access
- SQLite support
- Reactive query streams
- Migration support
- Excellent Flutter integration
- Good testability
- Long-term maintainability

Using a repository between the application and the database preserves the existing architecture and allows future cloud synchronization without changing the presentation layer.

Keeping shared database infrastructure inside `core` follows ADR-0003, while feature-specific persistence remains inside the owning feature according to the feature-first architecture.

---

## Consequences

Positive:

- Fishing spots persist between application launches
- Offline-first architecture is preserved
- Domain models remain independent of persistence
- Future relational entities are supported
- Database migrations are manageable
- Repository pattern remains consistent
- Future cloud synchronization is simplified

Trade-offs:

- Generated code becomes part of the project
- Build Runner is required
- Database schema changes require migrations
- Additional mapping between database models and domain models

---

## Scope

This decision defines:

- Drift as the local persistence technology
- SQLite as the underlying database
- Repository-based data access
- Separation between shared database infrastructure and feature-specific persistence

This decision does not define:

- Database schema
- Drift table definitions
- Repository implementation
- Migration strategy
- Provider structure
- Cloud synchronization

These topics will be defined by future feature specifications and technical designs.