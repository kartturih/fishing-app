# ADR-0001: Core Architecture

## Status

Accepted

## Date

2026-07-15

---

## Context

Fishing App is intended to become a long-term software product rather than a prototype or a school assignment.

The architecture must support:

- Offline usage
- Incremental feature development
- Maintainability
- Testability
- Future cloud synchronization
- AI-assisted development without sacrificing code quality

---

## Decision

The project adopts the following architectural decisions:

- Flutter as the cross-platform framework
- Dart as the programming language
- Offline-first architecture
- Feature-first project structure
- Riverpod for state management and dependency injection
- Repository pattern for data access

---

## Rationale

### Flutter

Flutter provides a mature cross-platform framework with excellent tooling, performance, and ecosystem support.

### Offline-first

Fishing often occurs in locations with unreliable or unavailable internet connectivity. The application must therefore function without network access.

### Feature-first

Organizing code by feature improves scalability and makes ownership of functionality clear.

### Riverpod

Riverpod offers compile-time safety, excellent testability, and decoupled dependency management without relying on widget context.

### Repository Pattern

Repositories abstract data sources from business logic, allowing local storage today and cloud synchronization in the future without changing the UI layer.

---

## Consequences

Positive:

- Modular architecture
- Easier testing
- Easier maintenance
- Scalable for future features
- Clear separation of responsibilities

Trade-offs:

- Slightly higher initial complexity
- More files than a simple Flutter project
- Requires architectural discipline