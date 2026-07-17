# Development Rules

## General

- Follow the existing project architecture.
- Prefer consistency over cleverness.
- Do not introduce new architectural layers without explicit approval.
- Always run `flutter analyze` before considering a task complete.
- Run relevant tests for every feature.

---

## Architecture

- Feature-first architecture.
- Offline-first application.
- Drift database.
- Material 3.
- CRUD operations are primarily performed using Bottom Sheets.

### Data layer

- Use concrete repositories.
- Do NOT introduce repository interfaces.
- Do NOT introduce DAO abstractions.
- Do NOT introduce service or use-case layers.

Repositories are responsible for persistence logic.

---

## UI

- All user-visible UI text must be written in Finnish.
- Keep wording consistent across the application.
- Do not introduce localization (ARB, intl, localization delegates) unless explicitly requested.

---

## Code Style

- Prefer small, focused widgets.
- Reuse existing helper functions instead of duplicating logic.
- Keep implementations simple.
- Avoid premature abstractions.

---

## Features

Every new feature follows this workflow:

1. MFS (Feature Specification)
2. TD (Technical Design)
3. Implementation
4. Code Review
5. flutter analyze
6. Tests
7. Manual Android testing
8. Commit

Do not skip steps.

---

## Database

- Avoid unnecessary schema changes.
- Do not regenerate Drift files unless required.

---

## Testing

Every feature should include appropriate tests.

Prefer:

- repository tests
- widget tests

when applicable.

---

## Git

Do not commit automatically.

Wait for approval after implementation and review.

---

## Existing Code

Always inspect existing code before implementing a feature.

Prefer extending existing implementations instead of creating new parallel solutions.

Avoid duplicate helper functions, duplicate widgets, and duplicate business logic.