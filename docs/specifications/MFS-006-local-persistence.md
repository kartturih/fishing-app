# MFS-006: Local Persistence

## Status

Approved

## Date

2026-07-16

---

## Purpose

The purpose of this feature is to persist fishing spots locally so they remain available after the application is closed and reopened.

This feature replaces the temporary in-memory storage introduced during the initial fishing spot implementation.

---

## User Story

As a user,

I want my fishing spots to be saved automatically,

so that they are still available the next time I open the application.

---

## MVP Scope

The initial implementation includes:

- Local persistence using Drift
- Automatic loading of saved fishing spots when the application starts
- Automatic saving of newly created fishing spots
- Repository-based data access
- Offline-only storage

---

## Out of Scope

The following functionality is intentionally excluded:

- Cloud synchronization
- User accounts
- Editing fishing spots
- Deleting fishing spots
- Backup and restore
- Import / Export
- Catch persistence
- Lure persistence
- Notes
- Photos
- Database encryption

---

## User Flow

### Application Startup

1. User opens the application.
2. The application initializes the local database.
3. Stored fishing spots are loaded.
4. Fishing spot markers appear on the map.

---

### Creating a Fishing Spot

1. User creates a fishing spot.
2. The fishing spot is saved locally.
3. The new marker appears immediately.
4. The fishing spot is available after restarting the application.

---

## Data Storage

Fishing spots are stored in the local SQLite database using Drift.

The database becomes the authoritative source of fishing spot data.

The previous in-memory collection is removed.

---

## Architecture

The implementation follows:

- ADR-0001
- ADR-0003
- ADR-0004
- ADR-0005

Data flow:

```text
Map UI
    ↓
Repository
    ↓
Drift
    ↓
SQLite
```

The presentation layer must not communicate directly with the database.

---

## Dependencies

Required:

- Drift
- drift_flutter

Development:

- drift_dev
- build_runner

---

## Acceptance Criteria

The feature is complete when:

- Existing fishing spots are loaded automatically.
- Newly created fishing spots are stored locally.
- Fishing spots remain after restarting the application.
- Existing map functionality continues to work.
- Existing user location functionality continues to work.
- No data is stored only in memory.
- `flutter analyze` completes successfully.

---

## Validation

The feature must be tested on a physical Android device.

Validation includes:

- Create a fishing spot.
- Close the application completely.
- Reopen the application.
- Verify the fishing spot is restored.
- Create multiple fishing spots.
- Verify all are restored.
- Verify map interaction continues to function normally.

---

## Future Extensions

This feature provides the foundation for:

- Editing fishing spots
- Deleting fishing spots
- Catch persistence
- Notes
- Photos
- Favorites
- Cloud synchronization