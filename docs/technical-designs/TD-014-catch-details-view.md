# TD-014 — Catch Details View

## Status

Draft

## Related Specification

- MFS-014 — Catch Details View

---

# Goal

Introduce a dedicated read-only Catch Details screen between the Catch List and Edit Catch.

The implementation must:

- separate viewing from editing
- preserve offline-first architecture
- reuse existing repositories
- avoid domain or database changes unless absolutely necessary

---

# Architecture Impact

## Domain

No changes.

Reuse existing:

- Catch
- CatchPhoto

---

## Data Layer

No database changes.

No migrations.

Reuse:

- CatchRepository
- CatchPhotoRepository

---

## Presentation Layer

New presentation widget:

```
features/catches/presentation/widgets/catch_details_page.dart
```

Implemented as a full-screen page (`CatchDetailsPage`, pushed via
`Navigator.push(MaterialPageRoute)`), not a modal Bottom Sheet, so it can
carry a Material 3 AppBar with a Back button and overflow menu. See
Architecture Review notes.

Existing editor remains:

```
features/catches/presentation/edit_catch_bottom_sheet.dart
```

Catch List will navigate to Catch Details instead of Edit Catch.

---

# Navigation Flow

Current

```
Catch List
    ↓
Edit Catch
```

New

```
Catch List
    ↓
Catch Details
    ↓
Edit Catch
```

After Save

```
Edit Catch
    ↓
Catch Details
```

After Cancel

```
Edit Catch
    ↓
Catch Details
```

Back navigation

```
Catch Details
    ↓
Catch List
```

Android Back must behave identically.

---

# Catch Details Layout

Material 3 AppBar

Left

- Back button

Center

- Species name

Right

- Overflow menu

Body

```
Scrollable

Photo gallery

↓

Species

↓

Weight

↓

Length

↓

Date

↓

Time

↓

Lure

↓

Notes
```

The page must scroll if content exceeds screen height.

---

# Photo Gallery

Reuse existing photo loading logic.

Requirements:

- first image shown initially
- preserve sortOrder
- existing image viewer may be reused
- no new image storage

No hero animations.

No pinch-to-zoom.

---

# Overflow Menu

Actions

```
Edit

Delete
```

Edit

Opens existing Edit Catch screen.

Delete

Uses existing delete flow including confirmation dialog.

---

# Edit Flow

When Edit is selected

```
Catch Details

↓

Edit Catch
```

When Save succeeds

```
Edit Catch closes

↓

Catch Details refreshes

↓

Updated information visible
```

When Cancel

```
Return to Catch Details
```

---

# Catch List Changes

Each catch item displays

```
Photo Thumbnail

or

Placeholder
```

Thumbnail source

First CatchPhoto ordered by sortOrder.

Display

- rounded corners
- BoxFit.cover
- clipped

Placeholder

Existing fish icon.

---

# Repository Usage

Catch Details

Read

```
CatchRepository
```

Photos

```
CatchPhotoRepository
```

No repository changes required.

---

# State Management

Reuse existing presentation state.

Do not introduce

- Provider
- Riverpod
- Bloc
- Cubit
- GetX

No additional architecture layers.

---

# Files to Add

```
features/
└── catches/
    └── presentation/
        └── widgets/
            └── catch_details_page.dart
```

---

# Files to Modify

Expected

```
catch_list_bottom_sheet.dart
```

```
edit_catch_bottom_sheet.dart
```

```
catch_list_item.dart
```

Additional files may be updated if required by implementation.

---

# Error Handling

Missing catch

- close details view gracefully

Missing photos

- display placeholder

Deleted catch

- return to Catch List

Repository failure

- existing error handling

---

# Testing

Widget Tests

- open Catch Details
- render catch information
- render photos
- render placeholder
- open Edit
- delete confirmation
- back navigation

Integration Tests

- Catch List → Details
- Details → Edit
- Save → Details
- Delete → Catch List
- Android back navigation

Regression Tests

- existing Edit Catch behaviour
- existing photo viewer
- existing photo persistence
- existing delete cleanup

---

# Acceptance Checklist

- Catch opens Details instead of Edit
- Details is read-only
- AppBar implemented
- Overflow menu implemented
- Edit opens existing editor
- Save returns to Details
- Cancel returns to Details
- Delete returns to Catch List
- Catch List thumbnails implemented
- Placeholder shown when no photo exists
- Existing repositories reused
- No database migration
- No domain changes
- flutter analyze passes
- Physical Android testing completed