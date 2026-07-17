# TD-011 — View Catches for Fishing Spot

## Goal

Implement a read-only catch list inside the existing Fishing Spot Details bottom sheet.

This feature allows users to view all catches recorded for a fishing spot.

---

## Scope

Implement only catch listing.

Do **not** implement:

- editing catches
- deleting catches
- catch details navigation
- notes
- photos
- statistics
- filtering
- sorting changes
- pagination
- database migrations

---

## Repository

Use the existing repository method:

```dart
Future<List<Catch>> getByFishingSpotId(String fishingSpotId)
```

Do not modify repository behavior or ordering.

The repository already returns catches in the required deterministic order:

1. `caughtAt` descending
2. `createdAt` descending
3. `id` ascending

Do not apply additional sorting in the presentation layer.

---

## Loading

Load catches once when the Fishing Spot Details bottom sheet is opened.

Use a simple Future-based implementation.

Do not introduce:

- Streams
- Riverpod providers
- state management libraries
- polling
- automatic database observation

The loading lifecycle shall remain owned by the Fishing Spot Details bottom sheet.

---

## Loading State

While catches are being loaded, display a lightweight loading indicator in the catches section.

The loading state must not block the entire bottom sheet.

Example:

```text
Catches

Loading...
```

A small `CircularProgressIndicator` is also acceptable if it matches the existing UI style.

---

## Error State

If catch loading fails:

- keep the bottom sheet open
- do not crash
- display a simple inline error message inside the catches section
- preserve the existing fishing spot information and action buttons

Example:

```text
Catches

Unable to load catches.
```

Do not add retry behavior in this feature unless it can be implemented with minimal complexity.

---

## UI Placement

Add the catches section below the existing action buttons.

Example structure:

```text
Fishing Spot

[Edit]
[Delete]
[Add Catch]

--------------------------------

Catches

Pike
3.2 kg • 78 cm
14 Jul 2026 18:34

--------------------------------

Perch
420 g
10 Jul 2026 21:10

--------------------------------

Zander
68 cm
8 Jul 2026 07:55
```

The implementation shall follow the existing visual style of the application.

Preferred widgets:

- `Padding`
- `Column`
- `Container`
- `Divider`
- `Text`
- `FutureBuilder` or an equivalent small local Future-based solution

Catch rows do not need:

- elevation
- tap handling
- hover handling
- swipe actions
- menus
- navigation

---

## Empty State

If no catches exist, display:

```text
Catches

No catches yet.
```

Do not display:

- placeholder cards
- empty dividers
- add buttons inside the empty state
- illustrations

The existing Add Catch action remains the only way to create a catch.

---

## Catch Information

Each catch shall display:

- fish species
- weight, if available
- length, if available
- catch date and time

The catch row must remain readable when either or both measurements are missing.

---

## Species

Display the existing Finnish species name:

```dart
catch.species.finnishName
```

Reuse the existing `FishSpecies` extension.

Do not duplicate species name mappings.

---

## Weight Formatting

Stored value:

```dart
weightGrams
```

Formatting rules:

| Stored value | Display |
|---:|---|
| 320 | 320 g |
| 850 | 850 g |
| 1000 | 1 kg |
| 1200 | 1.2 kg |
| 1250 | 1.25 kg |
| 2450 | 2.45 kg |
| 8000 | 8 kg |

Requirements:

- values below `1000 g` are displayed in grams
- values of `1000 g` or more are displayed in kilograms
- unnecessary trailing zeros must be removed
- no space shall appear between the numeric value and decimal separator
- use a space before the unit

Correct:

```text
1 kg
1.2 kg
2.45 kg
8 kg
```

Incorrect:

```text
1.00 kg
1.20 kg
8.0 kg
```

---

## Length Formatting

Stored value:

```dart
lengthMillimeters
```

Display length in centimeters.

Formatting rules:

| Stored value | Display |
|---:|---|
| 680 | 68 cm |
| 685 | 68.5 cm |
| 700 | 70 cm |
| 725 | 72.5 cm |

Requirements:

- convert millimeters to centimeters
- remove unnecessary trailing zeros
- use a space before the unit

Correct:

```text
68 cm
68.5 cm
70 cm
```

Incorrect:

```text
68.0 cm
70.0 cm
```

---

## Measurement Line

Supported combinations:

- weight and length
- weight only
- length only
- neither

Examples:

```text
3.2 kg • 78 cm
```

```text
3.2 kg
```

```text
78 cm
```

If both measurements are missing, omit the measurement line entirely.

Never display:

```text
•
```

```text
3.2 kg •
```

```text
• 78 cm
```

```text
null
```

```text
0 g
```

```text
0 cm
```

Valid stored data is already guaranteed by the creation flow and repository validation.

---

## Date Formatting

Display the catch date and time using the following format:

```text
14 Jul 2026 18:34
```

Use:

```dart
catch.caughtAt
```

Use the project's existing date formatting approach.

If the `intl` package is already present, reuse it.

If `intl` is not currently a dependency:

- do not add it automatically
- report this before introducing a new dependency
- prefer a small local formatter only if it remains clear and maintainable

Use 24-hour time.

---

## Read-Only Behavior

Catch rows must not be interactive.

Do not add:

- `InkWell`
- `GestureDetector`
- navigation
- edit controls
- delete controls
- context menus
- swipe actions
- expansion panels

Selecting a catch shall perform no action.

---

## Refresh Behavior

After a catch is added successfully, the next time the Fishing Spot Details bottom sheet is opened, the new catch must appear.

This feature does not require the currently open Fishing Spot Details bottom sheet to refresh automatically after returning from the Add Catch flow unless the existing flow already reopens or reloads it naturally.

Do not introduce reactive database observation solely for this behavior.

---

## Architecture

- Keep repository ownership unchanged.
- Reuse the existing `Catch` domain model.
- Reuse the existing `CatchRepository`.
- Keep loading owned by the Fishing Spot Details bottom sheet.
- Do not introduce repository interfaces.
- Do not introduce service classes.
- Do not introduce Riverpod.
- Do not introduce Streams.
- Do not introduce new architectural layers.
- Do not modify the database schema.
- Do not modify the database version.
- Do not modify Drift tables.
- Do not generate a migration.
- Do not change existing repository ordering.
- Do not create generic formatting infrastructure for this feature.

Small private formatting helper functions inside the relevant presentation file are acceptable.

---

## Implementation Notes

- Follow the existing project UI style and spacing.
- Keep the implementation local and easy to read.
- Prefer small private helpers over new utility classes.
- Avoid unnecessary widget abstractions.
- Avoid duplicating existing domain or repository logic.
- Do not move catch formatting into the domain layer.
- Do not expose new public APIs unless required.
- Do not modify generated Drift files.
- Keep existing Fishing Spot Details actions working unchanged.
- Preserve the existing keyboard black-flash fix.
- Keep the bottom sheet usable on smaller Android screens.
- Ensure the catches section can scroll as part of the existing bottom sheet content if the list becomes long.
- Do not use a nested independently scrolling list unless necessary.
- If using `ListView`, configure it so it works correctly inside the bottom sheet, for example with appropriate `shrinkWrap` and scroll physics.
- A simple `Column` is acceptable for the current scope if it integrates cleanly with the existing scroll view.

---

## Testing

Add or update widget tests covering:

### Empty state

Verify:

```text
No catches yet.
```

is shown when the repository returns an empty list.

### Loading state

Verify that the catches section shows a loading indicator while the Future is unresolved.

### Error state

Verify that a repository failure shows:

```text
Unable to load catches.
```

and does not remove the rest of the bottom sheet.

### One catch

Verify that one catch displays:

- Finnish species name
- correctly formatted date
- available measurements

### Multiple catches

Verify that multiple catches are displayed in repository-provided order.

Do not duplicate repository ordering tests in widget tests beyond confirming that the returned list is rendered in the same order.

### Weight formatting

Cover at least:

```text
320 g
1 kg
1.2 kg
2.45 kg
8 kg
```

### Length formatting

Cover at least:

```text
68 cm
68.5 cm
70 cm
```

### Missing measurements

Cover:

- weight and length
- weight only
- length only
- neither

Verify that no empty separator is displayed.

### Read-only behavior

Verify that catch rows do not expose edit or delete actions.

---

## Testability

Use the existing dependency passing pattern.

Do not introduce global service lookup or new state-management mechanisms for testing.

If the bottom sheet currently receives repositories through constructor parameters or function arguments, continue using that pattern.

---

## Validation

Before completing the task, run:

```bash
flutter analyze
```

and:

```bash
flutter test
```

Both must pass without issues.

---

## Deliverables

Report:

1. Files created
2. Files modified
3. Summary of the implementation
4. `flutter analyze` result
5. `flutter test` result
6. Number of passing tests
7. Any deviations from TD-011
8. Whether any dependency was added
9. Whether any generated file changed
10. Whether the database schema version changed

Do not commit.