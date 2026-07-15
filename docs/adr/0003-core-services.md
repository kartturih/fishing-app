# ADR-0003: Core Services

## Status

Accepted

## Date

2026-07-15

---

## Context

Fishing App will use several device and platform capabilities that are not owned by a single feature.

Examples include:

- Location services
- Permissions
- Local storage
- Database access
- Networking
- Logging
- Camera access
- Connectivity status

These capabilities may be required by multiple features.

For example, location data will later be used by:

- Map
- Fishing spots
- Catch logging
- Route recording
- Environmental data
- Statistics

Implementing these capabilities directly inside individual features would create duplicated logic, inconsistent behavior, and unnecessary coupling.

---

## Decision

Reusable technical capabilities that are shared across multiple features will be implemented as **Core Services** under the `lib/core` directory.

Example structure:

```text
lib/
├── core/
│   ├── location/
│   ├── storage/
│   ├── database/
│   ├── network/
│   └── logging/
└── features/
```

Features may use Core Services through abstractions and dependency injection.

A Core Service must not contain feature-specific business logic.

---

## Responsibilities

Core Services may contain:

- Platform integration
- Device capability access
- Permission handling
- Technical configuration
- Shared infrastructure
- Wrappers around external packages
- Common error translation

Core Services must not contain:

- Feature-specific UI
- Feature-specific state
- Feature-specific business rules
- Feature-specific data models unless they are genuinely shared
- Navigation logic

---

## Rationale

This approach provides:

- Reusable platform integrations
- Consistent behavior across features
- Clear separation between infrastructure and product functionality
- Easier testing
- Reduced dependency on third-party package APIs
- Easier replacement of external packages
- Better support for future features

Wrapping external packages behind Core Services also prevents package-specific APIs from spreading throughout the application.

---

## Example

Location access will be implemented under:

```text
lib/
└── core/
    └── location/
        └── location_service.dart
```

The Map Feature may use this service to center the map on the user's location.

Future features may use the same service without depending on MapLibre or map-specific code.

---

## Consequences

### Positive

- Shared technical logic is centralized
- Features remain focused on their own responsibilities
- External dependencies are easier to replace
- Platform behavior remains consistent
- Testing becomes easier
- Future features can reuse existing services

### Trade-offs

- Introduces additional abstractions
- Requires discipline to keep Core Services free of business logic
- Some capabilities may initially appear to belong to only one feature
- Incorrectly placing code in `core` can create an overly broad shared layer

---

## Placement Rule

Code belongs in `core` only when at least one of the following is true:

- It represents a device or platform capability
- It is expected to be used by multiple features
- It wraps a shared external dependency
- It provides application-wide technical infrastructure

Code should remain inside a feature when it is owned by that feature and has no clear cross-feature responsibility.

---

## Dependency Direction

Features may depend on Core Services.

Core Services must not depend on features.

```text
features
   ↓
core
```

This dependency direction must remain one-way.

---

## Scope

This ADR defines the placement and responsibility of shared technical services.

It does not define:

- The implementation of individual services
- Permission UX
- Error-handling strategy
- Logging framework
- Database technology
- Network client
- Service lifecycle
- Provider structure

These decisions may be documented separately when required.