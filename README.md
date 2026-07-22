# Fishing App

> An offline-first mobile fishing companion built with Flutter.

## Status

🚧 Under active development — a functional Android prototype already exists.

The current version supports:

- Interactive MapLibre map
- User location
- Offline Fishing Spot CRUD
- Offline Catch CRUD
- Catch photo attachments
- Dedicated Catch Details view
- Full-screen photo viewing and zoom
- Lure Catalog with search and filtering, browsed by lure model with a per-model color-variant view
- Personal Tackle Box for tracking owned lures, with optional personal photos
- Assigning an owned lure to a catch, shown in Catch Details
- Lure-based catch statistics (most successful lure and lure type, per-lure and per-lure-type catch counts), computed live with no stored aggregate
- General, per-species, and per-fishing-spot catch statistics (Top 3 Largest Catches, most caught species, catch-count breakdowns, a record catch and full catch list per species/fishing spot), computed live with no stored aggregate
- Optional per-catch notes (multiline, up to 1000 characters), shown in Catch Details
- Water Bodies: fishing spots are grouped under a parent water body (lake, pond, river, etc.), with nearby-water-body suggestions, a management surface, and automatic migration of existing fishing spots
- Persistent Drift/SQLite storage

735 automated tests are passing. Physical Android testing has been completed for all currently implemented features. iOS physical testing has not yet been performed.

## Vision

Fishing App helps anglers make better decisions before, during and after a fishing trip by combining:

- Interactive maps
- Personal fishing history
- Catch and fishing spot management
- Lure management
- Environmental data
- Smart recommendations (future)

## Technology Stack

- Flutter
- Dart
- Riverpod
- GoRouter
- Drift / SQLite
- MapLibre GL
- geolocator
- image_picker
- Material 3
- Supabase (planned for later cloud synchronization)

## Architecture

- Offline-first
- Feature-first
- Repository pattern
- Framework-independent domain models
- Local database as the current source of truth

## Documentation

- [Project Status](docs/project-status.md)
- [Project Charter](docs/project-charter.md)
- [App Structure](docs/app-structure.md)
- [Architecture](docs/architecture.md)
- [Database](docs/database.md)
- [Roadmap](docs/roadmap.md)
- [Development Rules](docs/development-rules.md)

Also see:

- [Architecture Decision Records](docs/adr/)
- [Feature Specifications](docs/specifications/)
- [Technical Designs](docs/technical-designs/)

## Development Workflow

1. ADR when required
2. MFS
3. TD
4. Implementation
5. Architecture review
6. flutter analyze and automated tests
7. Physical Android testing
8. Git commit
9. Project status update

## License

No license has been selected yet.
