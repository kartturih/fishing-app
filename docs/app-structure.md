# App Structure

## Purpose

This document defines the high-level structure of the Fishing App codebase.

The structure should support:

* Offline-first development
* Clear separation of responsibilities
* Independent feature development
* Maintainability as the application grows
* Future cloud synchronization without redesigning the whole application

## Planned Flutter Structure

```text
lib/
├── app/
├── core/
├── features/
└── shared/
```

## Directories

### `app`

Contains application-level configuration.

Examples:

* App initialization
* Routing
* Theme
* Localization configuration
* Global providers

### `core`

Contains technical components used across the application.

Examples:

* Local database
* Location services
* Map configuration
* Error handling
* Logging
* Shared constants

### `features`

Contains the main application features.

Initial features:

```text
features/
├── map/
├── fishing_spots/
├── catches/
└── lures/
```

Each feature should own its user interface, application logic, domain models, and data access code when practical.

### `shared`

Contains reusable user interface components and utilities that do not belong to one specific feature.

Examples:

* Shared widgets
* Formatters
* Validators
* Common extensions

## Structural Principle

The application will use a feature-first structure.

Code should be placed inside the feature that owns the functionality. Shared code should only be moved to `core` or `shared` when it is genuinely used by multiple features.

## Current Status

This structure is an initial architectural direction and may be refined before implementation begins.
