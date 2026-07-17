# TD-010: Add Catch Implementation

## Status

Approved

---

## Related Specification

* MFS-010: Add Catch

---

## Summary

Implement the user flow for adding a catch to an existing fishing spot.

This technical design adds:

* Catch creation to `CatchRepository`
* Add-catch form UI
* Fish species selection
* Catch date and time selection
* Optional weight input in kilograms
* Optional length input in centimeters
* Decimal parsing with comma and period support
* Conversion into canonical database units
* Persistence error handling
* Entry point from an existing fishing spot

This milestone does not implement catch listing, editing, deletion, photos, notes, statistics, or map markers.

---

## Architecture

Use the existing feature-first structure.

```text
lib/
├── core/
│   └── database/
│       └── app_database.dart
│
├── features/
│   ├── catches/
│   │   ├── data/
│   │   │   ├── local/
│   │   │   │   └── catches_table.dart
│   │   │   ├── catch_mapper.dart
│   │   │   └── catch_repository.dart
│   │   │
│   │   ├── domain/
│   │   │   ├── catch.dart
│   │   │   ├── fish_species.dart
│   │   │   └── fish_species_extensions.dart
│   │   │
│   │   └── presentation/
│   │       └── widgets/
│   │           └── add_catch_bottom_sheet.dart
│   │
│   └── fishing_spots/
│       └── presentation/
│           └── ...
```

Use the existing presentation patterns in the project.

Do not introduce:

* DAO abstractions
* Repository interfaces
* Service layers
* Use-case layers
* New global state-management architecture
* Catch list state
* Catch providers unless required by an already established project convention

---

## Repository Creation Operation

Update:

```text
lib/features/catches/data/catch_repository.dart
```

Add:

```dart
Future<Catch> create({
  required String fishingSpotId,
  required FishSpecies species,
  required DateTime caughtAt,
  int? weightGrams,
  int? lengthMillimeters,
});
```

The repository owns:

* Identifier generation
* Creation timestamps
* Domain object construction
* Mapping to Drift
* Database insertion
* Returning the created `Catch`

Use the same identifier-generation strategy already used by `FishingSpotRepository`.

Do not generate identifiers in the UI.

---

## Repository Validation

Before insertion, validate:

```text
fishingSpotId is not empty
weightGrams is null or greater than zero
lengthMillimeters is null or greater than zero
```

The existing `Catch` constructor assertions remain in place.

Do not rely only on assertions, because assertions may be disabled in release builds.

Use explicit argument validation where needed.

Suggested failure type:

```dart
ArgumentError
```

Do not add a validation framework.

---

## Creation Timestamp

At creation:

```text
createdAt = current time
updatedAt = createdAt
```

Use a single captured timestamp:

```dart
final now = DateTime.now();
```

Do not call `DateTime.now()` separately for the two fields.

Preserve the supplied `caughtAt` value exactly.

---

## Database Insert

Create the domain model first, then insert using the existing mapper.

Example structure:

```dart
final catchModel = Catch(
  id: generatedId,
  fishingSpotId: fishingSpotId,
  species: species,
  caughtAt: caughtAt,
  weightGrams: weightGrams,
  lengthMillimeters: lengthMillimeters,
  createdAt: now,
  updatedAt: now,
);

await _database.into(_database.catches).insert(
  _mapper.toCompanion(catchModel),
);

return catchModel;
```

Use the actual identifier implementation and repository conventions from the project.

Do not construct `CatchesCompanion` directly in presentation code.

---

## Add Catch Form

Create:

```text
lib/features/catches/presentation/widgets/add_catch_bottom_sheet.dart
```

Use a modal bottom sheet if that matches the existing fishing-spot creation flow.

The widget receives the selected fishing spot.

Suggested parameters:

```dart
class AddCatchBottomSheet extends StatefulWidget {
  const AddCatchBottomSheet({
    required this.fishingSpot,
    required this.catchRepository,
    super.key,
  });

  final FishingSpot fishingSpot;
  final CatchRepository catchRepository;
}
```

Adjust dependency passing to match the existing project style.

Do not query the fishing spot again from the database.

---

## Bottom Sheet Behavior

The bottom sheet must:

* Show the selected fishing spot name.
* Allow species selection.
* Default the catch time to the current local date and time.
* Allow changing date and time.
* Accept optional weight.
* Accept optional length.
* Validate before saving.
* Remain open during a failed save.
* Close only after successful persistence.
* Return the created `Catch`.

Suggested invocation result:

```dart
final createdCatch = await showModalBottomSheet<Catch>(
  context: context,
  isScrollControlled: true,
  builder: (context) => AddCatchBottomSheet(
    fishingSpot: fishingSpot,
    catchRepository: catchRepository,
  ),
);
```

Use the project’s actual modal styling and keyboard behavior.

---

## Keyboard Behavior

The project previously required:

```dart
Scaffold(
  resizeToAvoidBottomInset: false,
)
```

to prevent a black flash during keyboard opening.

Preserve that established behavior in the add-catch form.

The form content must remain accessible when the keyboard is open.

Use scrolling and bottom padding based on:

```dart
MediaQuery.viewInsetsOf(context).bottom
```

Do not reintroduce the keyboard black-flash issue.

---

## Form State

The widget should own local form state.

Required state:

```text
selectedSpecies
selectedCaughtAt
weight controller
length controller
isSaving
```

Use:

* `Form`
* `GlobalKey<FormState>`
* `TextEditingController`
* `StatefulWidget`

Do not introduce Riverpod solely for temporary form state.

Dispose controllers correctly.

---

## Initial Values

When the form opens:

```text
selectedSpecies = null
selectedCaughtAt = DateTime.now()
weight = empty
length = empty
```

The date and time shown to the user must reflect local time.

Capture the initial current time once in `initState`.

Do not continuously update it while the form remains open.

---

## Fishing Spot Context

Display the selected fishing spot clearly near the top of the form.

Example:

```text
Kalastuspaikka
Merrasjärvi
```

This is read-only.

Do not allow changing the fishing spot inside this form.

---

## Species Selector

Use all values from:

```dart
FishSpecies.values
```

Display:

```dart
species.finnishName
```

Store:

```dart
FishSpecies
```

A simple dropdown is acceptable for the current species count.

Suggested widget:

```dart
DropdownButtonFormField<FishSpecies>
```

Requirements:

* No free-text species entry.
* No `other` value.
* Show a validation error when no species is selected.
* The list order should remain stable.

Use enum declaration order unless a different existing project rule already applies.

---

## Date Selection

Provide a date-selection control.

Use Flutter’s standard date picker unless the project already has a custom component.

Suggested API:

```dart
showDatePicker(...)
```

Initial date:

```dart
selectedCaughtAt
```

When the user chooses a new date, preserve the previously selected time.

Example:

```dart
DateTime(
  selectedDate.year,
  selectedDate.month,
  selectedDate.day,
  selectedCaughtAt.hour,
  selectedCaughtAt.minute,
);
```

Do not reset time to midnight.

---

## Time Selection

Provide a time-selection control.

Use:

```dart
showTimePicker(...)
```

Initial time:

```dart
TimeOfDay.fromDateTime(selectedCaughtAt)
```

When the user chooses a new time, preserve the previously selected date.

Example:

```dart
DateTime(
  selectedCaughtAt.year,
  selectedCaughtAt.month,
  selectedCaughtAt.day,
  selectedTime.hour,
  selectedTime.minute,
);
```

Seconds and milliseconds may be set to zero after manual date or time selection.

---

## Future Catch Time

Do not prevent selecting a future date or time in this milestone unless MFS-010 explicitly requires it.

No future-time validation is required.

This can be reconsidered later if user testing shows it is needed.

---

## Weight Input

Display unit:

```text
kg
```

Use a decimal-capable keyboard.

Suggested configuration:

```dart
keyboardType: const TextInputType.numberWithOptions(decimal: true)
```

Accept:

```text
2
2.4
2,4
0.85
0,85
```

An empty value means:

```dart
null
```

Convert kilograms into grams.

---

## Length Input

Display unit:

```text
cm
```

Use a decimal-capable keyboard.

Accept:

```text
68
68.5
68,5
```

An empty value means:

```dart
null
```

Convert centimeters into millimeters.

---

## Decimal Parsing

Create a small private parsing helper inside the presentation implementation unless a reusable utility already exists.

Normalize:

```dart
input.trim().replaceAll(',', '.')
```

Parse using:

```dart
double.tryParse(...)
```

Do not use locale-sensitive parsing libraries in this milestone.

---

## Weight Conversion

Convert kilograms to grams:

```dart
final grams = (kilograms * 1000).round();
```

Examples:

```text
0.85 kg → 850 g
2.45 kg → 2450 g
10 kg → 10000 g
```

Reject values resulting in:

```text
grams <= 0
```

Do not store floating-point values.

---

## Length Conversion

Convert centimeters to millimeters:

```dart
final millimeters = (centimeters * 10).round();
```

Examples:

```text
24 cm → 240 mm
68.5 cm → 685 mm
102 cm → 1020 mm
```

Reject values resulting in:

```text
millimeters <= 0
```

Do not store floating-point values.

---

## Input Precision

Because values are converted into integer canonical units:

* Weight precision is effectively one gram.
* Length precision is effectively one millimeter.

Extra decimal precision may be rounded.

Examples:

```text
1.2345 kg → 1235 g
68.56 cm → 686 mm
```

No separate warning is required for rounding.

---

## Numeric Validation

Weight validator behavior:

```text
empty → valid
not numeric → "Syötä kelvollinen paino"
numeric value <= 0 → "Painon täytyy olla suurempi kuin 0"
converted grams <= 0 → "Painon täytyy olla suurempi kuin 0"
```

Length validator behavior:

```text
empty → valid
not numeric → "Syötä kelvollinen pituus"
numeric value <= 0 → "Pituuden täytyy olla suurempi kuin 0"
converted millimeters <= 0 → "Pituuden täytyy olla suurempi kuin 0"
```

Reject:

```text
NaN
Infinity
-Infinity
```

Explicitly verify:

```dart
value.isFinite
```

---

## Date and Time Display

Use Finnish-friendly display formatting consistent with the current app.

Avoid adding a new localization or formatting dependency solely for this form.

Acceptable examples:

```text
17.7.2026
14.35
```

or the existing project’s established formatting.

Keep formatting logic separate from persisted values.

---

## Save Action

When the user taps Save:

1. Ignore repeated taps while already saving.
2. Validate the form.
3. Confirm that species is selected.
4. Parse weight.
5. Parse length.
6. Set `isSaving = true`.
7. Call `CatchRepository.create`.
8. If successful, close the bottom sheet with the created `Catch`.
9. If failed, keep the sheet open.
10. Show a user-friendly error.
11. Restore `isSaving = false` if the widget remains mounted.

Suggested success return:

```dart
Navigator.of(context).pop(createdCatch);
```

---

## Loading State

While saving:

* Disable Save.
* Disable repeated submission.
* Show a progress indicator or saving label.
* Keep entered values visible.

Do not clear the form before persistence succeeds.

---

## Save Failure

Catch repository or database failures must not close the bottom sheet.

Show a generic Finnish message such as:

```text
Saaliin tallentaminen epäonnistui. Yritä uudelleen.
```

Do not expose:

* SQL errors
* Stack traces
* Raw exception messages

The entered species, date, time, weight, and length must remain unchanged.

Use the existing error-display pattern if one exists.

---

## Cancel Behavior

Provide a close or cancel action.

Cancel closes the bottom sheet without saving.

No confirmation dialog is required for unsaved values in this milestone.

---

## Entry Point

Add an Add Catch action to the existing fishing-spot interaction UI.

Use the most natural existing location where the user currently views or interacts with one selected fishing spot.

Possible implementations include:

* Action in the fishing spot details bottom sheet
* Button in an existing fishing spot popup
* Context-menu action
* Existing spot-action sheet

Do not create a new fishing-spot details screen solely for this milestone.

The action label should be:

```text
Lisää saalis
```

Use an appropriate icon, such as:

```dart
Icons.add
```

or an existing fishing-related project icon.

---

## Entry Point Dependency Handling

Follow the existing dependency style.

If repositories are currently instantiated directly near the UI, keep that convention.

If an existing provider already exposes `AppDatabase` or repositories, reuse it.

Do not create a broad new dependency-injection system.

The entry point must supply:

* The selected `FishingSpot`
* A usable `CatchRepository`

---

## Navigation Result Handling

The caller may receive the created catch:

```dart
final catchModel = await showModalBottomSheet<Catch>(...);
```

No list refresh is required because catch listing does not exist yet.

The result may be used only for success feedback.

Do not add temporary catch-list state.

---

## Success Feedback

After successful creation, show a brief confirmation if the current app already uses snackbars or similar feedback.

Suggested text:

```text
Saalis tallennettu
```

Do not show feedback from inside the bottom sheet after it has already closed unless the existing navigation pattern supports it safely.

Prefer showing success feedback in the caller.

---

## Persistence Integrity

The repository insert must fail if:

* The fishing spot no longer exists.
* The foreign key is invalid.
* Measurements violate database checks.

The UI shows the generic persistence error.

Do not silently create a catch without a valid fishing spot.

---

## Cascade Delete Testing

MFS-010 makes it possible to create catch rows through production UI.

After implementing creation, test cascade deletion:

1. Create a fishing spot.
2. Add a catch to it.
3. Delete the fishing spot.
4. Verify no database error occurs.
5. Verify the spot remains deleted after restart.

Because no catch list exists yet, confirming the catch row is removed may require:

* An automated repository test
* A temporary development-only database inspection
* Another safe verification method

Do not retain temporary debug UI in production code.

---

## Tests

Add focused tests if the project already has a test structure suitable for repository or parsing tests.

High-value cases:

### Repository

* Creates a catch with the correct fishing spot ID.
* Stores the species enum name.
* Stores weight in grams.
* Stores length in millimeters.
* Sets `createdAt` and `updatedAt` equally.
* Cascade deletion removes catches.

### Parsing

* `2.45` kg becomes `2450`.
* `2,45` kg becomes `2450`.
* `68.5` cm becomes `685`.
* `68,5` cm becomes `685`.
* Empty input becomes `null`.
* Zero is rejected.
* Negative values are rejected.
* Invalid text is rejected.
* Infinity and NaN are rejected.

Do not introduce a large new testing architecture solely for this milestone.

---

## Files Expected to Change

Likely created:

```text
lib/features/catches/presentation/widgets/add_catch_bottom_sheet.dart
```

Likely modified:

```text
lib/features/catches/data/catch_repository.dart
```

One or more existing fishing-spot presentation files will also be modified to add the entry point.

Additional small private presentation helpers may be added if they clearly improve readability.

Do not modify database schema files unless an actual implementation issue requires it.

No new migration should be required.

Schema version must remain:

```text
2
```

---

## Generated Files

No Drift schema changes are expected.

Do not regenerate or modify:

```text
app_database.g.dart
```

unless the table schema itself must be corrected for a verified reason.

If generated files change unexpectedly, investigate before accepting them.

---

## Implementation Order

1. Inspect the current fishing-spot action flow.
2. Inspect repository construction and database access patterns.
3. Add `CatchRepository.create`.
4. Implement decimal parsing and canonical-unit conversion.
5. Implement add-catch bottom sheet.
6. Add species selector.
7. Add date picker.
8. Add time picker.
9. Add weight and length fields.
10. Add validation.
11. Add loading and error states.
12. Add the entry point from a fishing spot.
13. Return the created Catch from the bottom sheet.
14. Add success feedback if consistent with existing UI.
15. Format only intentionally modified files.
16. Run static analysis.
17. Perform architecture review.
18. Test on a physical Android device.

---

## Validation Commands

Run:

```bash
dart format <only intentionally modified Dart files>
flutter analyze
```

If tests are added:

```bash
flutter test
```

Do not use `dart format .` if it causes unrelated formatting-only changes.

---

## Physical Android Test

### Open Form

1. Open the application.
2. Select an existing fishing spot.
3. Tap `Lisää saalis`.
4. Verify the correct fishing spot name is shown.
5. Verify no fishing-spot selector is shown.

### Default Time

1. Open the form.
2. Verify date and time default approximately to the current local time.

### Species Validation

1. Leave species unselected.
2. Tap Save.
3. Verify the form shows:

```text
Valitse kalalaji
```

4. Verify the form remains open.

### Decimal Input

Test weight:

```text
2,45
```

Test length:

```text
68.5
```

Save and verify creation succeeds.

Also test period and comma variants.

### Invalid Measurements

Test:

```text
0
-1
abc
```

for both weight and length.

Verify saving is blocked and a clear error is shown.

### Optional Measurements

1. Select a species.
2. Leave weight and length empty.
3. Save.
4. Verify creation succeeds.

### Date and Time

1. Change the date.
2. Verify the selected time remains unchanged.
3. Change the time.
4. Verify the selected date remains unchanged.
5. Save successfully.

### Repeated Submission

1. Tap Save repeatedly.
2. Verify only one catch is created.
3. Verify the UI does not crash.

### Persistence Failure

Where practical, test a failed insert.

Verify:

* The form remains open.
* Entered values remain visible.
* A user-friendly error appears.
* Save can be attempted again.

### Restart

1. Save a catch.
2. Close the app.
3. Reopen the app.
4. Verify the app starts normally.

Catch visibility cannot yet be confirmed through production UI because catch listing is out of scope.

### Cascade

1. Create a new fishing spot.
2. Add a catch.
3. Delete the fishing spot.
4. Verify deletion succeeds without foreign-key errors.
5. Restart the app.
6. Verify the fishing spot remains deleted.

---

## Architecture Review Checklist

* Catch creation belongs to `CatchRepository`.
* UI does not create identifiers.
* UI does not construct Drift companions.
* UI stores `FishSpecies`, not display-name strings.
* Finnish species names come from the existing extension.
* Weight input is kilograms.
* Weight storage is grams.
* Length input is centimeters.
* Length storage is millimeters.
* Both comma and period decimal separators work.
* Non-finite values are rejected.
* Empty measurements become `null`.
* Date and time default to local current time.
* Date selection preserves time.
* Time selection preserves date.
* `createdAt` equals initial `updatedAt`.
* Save is protected against duplicate taps.
* Persistence errors preserve form state.
* Raw database errors are not exposed.
* No catch list is introduced.
* No catch edit or delete functionality is introduced.
* No new schema migration is added.
* Schema version remains 2.
* No Riverpod architecture is added solely for form state.
* No unrelated files are reformatted.
* Keyboard black flash does not return.
* `flutter analyze` passes.

---

## Completion Criteria

TD-010 is complete when:

* `CatchRepository.create` is implemented.
* The add-catch form opens from a fishing spot.
* The selected fishing spot is shown.
* Fish species selection works.
* Date and time selection works.
* Weight accepts kg decimals using comma or period.
* Length accepts cm decimals using comma or period.
* Values convert into grams and millimeters correctly.
* Optional measurements save as `null`.
* Invalid input cannot be saved.
* Save creates one correctly linked Catch.
* Duplicate save taps are prevented.
* The form closes only after successful persistence.
* Persistence failures preserve the entered values.
* Cascade deletion works after a catch has been created.
* No unrelated catch features are implemented.
* No unrelated formatting changes remain.
* `flutter analyze` passes.
* Physical Android validation passes.
