# TD-012 — Edit and Delete Catch

## Goal

Implement an Edit Catch bottom sheet that allows users to update or permanently delete an existing catch.

The Edit Catch flow shall become the single place for managing an existing catch.

---

## Scope

Implement:

- editing catches
- deleting catches
- update repository support
- delete repository support
- bottom sheet coordination

Do **not** implement:

- catch photos
- catch notes
- moving catches to another fishing spot
- statistics
- database migrations
- reactive streams

---

# Repository

Extend the existing concrete `CatchRepository`.

## Update

```dart
Future<Catch> update({
  required Catch catchModel,
  required FishSpecies species,
  required DateTime caughtAt,
  int? weightGrams,
  int? lengthMillimeters,
});
```

Requirements:

- preserve `id`
- preserve `fishingSpotId`
- preserve `createdAt`
- refresh `updatedAt`
- validate updated values
- update existing database row
- return updated `Catch`

---

## Delete

```dart
Future<void> delete(String catchId);
```

Requirements:

- reject empty IDs using `ArgumentError`
- delete by primary key
- deleting a missing catch shall complete successfully
- affect only the selected catch

---

# Edit Catch Bottom Sheet

Create:

```text
lib/features/catches/presentation/widgets/edit_catch_bottom_sheet.dart
```

Parameters:

```dart
required FishingSpot fishingSpot
required Catch catchModel
required CatchRepository catchRepository
```

Provide:

```dart
static Future<EditCatchResult?> show(...)
```

following the existing project pattern.

---

# Result

A successful save shall return:

```dart
sealed class EditCatchResult {
  const EditCatchResult();
}

final class CatchUpdated extends EditCatchResult {
  const CatchUpdated(this.catchModel);

  final Catch catchModel;
}
```

A successful delete shall return:

```dart
final class CatchDeleted extends EditCatchResult {
  const CatchDeleted(this.catchId);

  final String catchId;
}
```

Cancel returns `null`.

---

# Initial State

Prefill the form from the existing catch.

Populate:

- species
- date
- time
- weight
- length

Fishing spot name is displayed read-only.

---

# Form

Display:

- Fishing spot (read-only)
- Species
- Date
- Time
- Weight (kg)
- Length (cm)

Bottom actions:

```text
[Delete]              [Save]
```

Delete shall be visually destructive.

---

# Parsing

Reuse the same parsing rules as Add Catch.

Before parsing:

```dart
replaceAll(',', '.')
```

Use:

```dart
double.tryParse()
```

Empty field:

```dart
null
```

---

# Unit Conversion

Weight:

```dart
kg -> grams
(weight * 1000).round()
```

Length:

```dart
cm -> millimeters
(length * 10).round()
```

---

# Validation

Reject:

- missing species
- zero weight
- zero length
- negative values
- invalid numeric input
- NaN
- Infinity

Preserve entered values after validation failure.

---

# Saving

Save flow:

1. Disable Save
2. Validate
3. Parse
4. Convert units
5. Combine date and time
6. Repository.update(...)
7. Close sheet with CatchUpdated

Capture only one `DateTime.now()`.

Prevent duplicate save taps.

---

# Delete Flow

Press Delete.

Show confirmation dialog:

```text
Delete catch?

This action cannot be undone.

[Cancel] [Delete]
```

If cancelled:

- close dialog
- keep edit sheet open

If confirmed:

1. Disable actions
2. Repository.delete(...)
3. Close confirmation
4. Close Edit Catch sheet
5. Return CatchDeleted

---

# Failure Handling

## Save

Keep sheet open.

Preserve:

- text fields
- selected species
- date
- time

Show error.

Allow retry.

---

## Delete

Keep Edit Catch sheet open.

Show error.

Allow retry.

Do not modify catch.

---

# Catch List

Catch rows become tappable.

Tap flow:

```text
Catch Row

↓

FishingSpotDetailsResult

↓

MapScreen

↓

EditCatchBottomSheet
```

Reuse the same coordination pattern already used by Add Catch.

Do not open nested bottom sheets.

---

# Refresh

The next time Fishing Spot Details is opened:

- updated catch is shown
- deleted catch is gone

No Streams.

No automatic observation.

---

# Architecture

Reuse:

- Catch
- CatchRepository
- FishSpecies
- Finnish species extension

Do not introduce:

- repository interfaces
- service classes
- use-case classes
- Riverpod
- Streams
- new architecture layers

Do not modify:

- schema version
- Drift schema
- cascade delete

---

# Implementation Notes

- Follow the Add Catch layout.
- Keep spacing consistent.
- Preserve keyboard fix.
- Support smaller Android screens.
- Prefer private helper methods.
- Avoid duplicated parsing logic where a small refactor is sufficient.
- Do not modify generated Drift files unless regeneration is genuinely required.

---

# Testing

## Repository

Cover:

- update species
- update date
- update weight
- update length
- clear weight
- clear length
- preserve ID
- preserve fishingSpotId
- preserve createdAt
- refresh updatedAt
- delete existing catch
- delete missing catch
- reject empty delete ID

---

## Widget

Cover:

- initial values
- edit species
- edit date
- edit time
- edit weight
- edit length
- clear weight
- clear length
- comma parsing
- period parsing
- save success
- save failure
- delete confirmation
- delete cancel
- delete success
- delete failure
- duplicate save prevention
- duplicate delete prevention

---

## Fishing Spot Details

Cover:

- tapping a catch requests Edit Catch
- correct catch returned

---

# Validation

Run:

```bash
flutter analyze
```

Run:

```bash
flutter test
```

Both must pass.

---

# Deliverables

Report:

1. Files created
2. Files modified
3. Repository changes
4. UI changes
5. Bottom sheet coordination
6. flutter analyze result
7. flutter test result
8. Number of passing tests
9. Any deviations
10. Dependencies added
11. Generated files changed
12. Database schema changes

Do not commit.

---


# Definition of Done

The feature is considered complete when:

- The implementation satisfies all requirements in MFS-012.
- The implementation follows TD-012.
- Physical Android testing has been completed successfully.
- `flutter analyze` reports no issues.
- `flutter test` passes successfully.
- The architecture review has been completed.
- No unnecessary architectural layers or dependencies were introduced.
- No unintended database schema changes were made.
- The feature is ready to be committed.