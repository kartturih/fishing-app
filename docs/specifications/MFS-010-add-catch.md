# MFS-010: Add Catch

## Status

Approved

---

## Summary

Allow the user to add a catch to an existing fishing spot.

A catch always belongs to one fishing spot.

The user selects the fish species and may optionally enter weight and length. The catch time defaults to the current date and time but can be changed before saving.

---

## User Story

As a user, I want to record a catch for a fishing spot so that I can build a personal fishing history.

---

## Entry Point

The add-catch flow is opened from a fishing spot.

The selected fishing spot is provided to the add-catch flow.

The user must not manually select the fishing spot again inside the form.

---

## Required Fields

### Fish species

The user must select one value from `FishSpecies`.

The UI displays Finnish species names.

The database stores the stable English enum name.

### Catch date and time

The field defaults to the current local date and time.

The user can change both the date and time.

The saved value is stored as `caughtAt`.

---

## Optional Fields

### Weight

The user may enter the catch weight.

UI unit:

```text
kg
```

The user may enter decimal values.

Examples:

```text
0.85
2.4
10
```

Before persistence, convert the value into integer grams.

Examples:

```text
0.85 kg → 850 g
2.4 kg → 2400 g
10 kg → 10000 g
```

The stored value must be greater than zero.

An empty field is stored as `null`.

### Length

The user may enter the catch length.

UI unit:

```text
cm
```

The user may enter decimal values.

Examples:

```text
24
68.5
102
```

Before persistence, convert the value into integer millimeters.

Examples:

```text
24 cm → 240 mm
68.5 cm → 685 mm
102 cm → 1020 mm
```

The stored value must be greater than zero.

An empty field is stored as `null`.

---

## Form Layout

The form contains:

1. Fishing spot name as read-only context
2. Fish species selector
3. Catch date
4. Catch time
5. Weight in kilograms
6. Length in centimeters
7. Save action
8. Cancel or close action

The fishing spot name is shown so the user knows where the catch will be saved.

---

## Species Selector

The species selector must show all current `FishSpecies` values.

Requirements:

* Display Finnish names.
* Store the selected enum value.
* Do not allow free-text species entry.
* Do not include an `other` option.
* Use a searchable selector if the final species list becomes too long for a simple dropdown.

For the current species count, either a dropdown or modal selection list is acceptable.

---

## Validation

Saving is allowed only when:

```text
species is selected
caughtAt is valid
weight is empty or greater than 0
length is empty or greater than 0
```

Invalid numeric input must show a clear validation message.

Suggested messages:

```text
Valitse kalalaji
Syötä kelvollinen paino
Painon täytyy olla suurempi kuin 0
Syötä kelvollinen pituus
Pituuden täytyy olla suurempi kuin 0
```

The form must accept both comma and period as decimal separators.

Examples:

```text
2,45
2.45
```

Both represent:

```text
2.45 kg
```

---

## Persistence

Saving creates a new `Catch` containing:

```text
id
fishingSpotId
species
caughtAt
weightGrams
lengthMillimeters
createdAt
updatedAt
```

Requirements:

* `id` uses the same identifier strategy as fishing spots.
* `fishingSpotId` is the selected fishing spot identifier.
* `createdAt` is the current time.
* `updatedAt` initially equals `createdAt`.
* The repository performs the database insertion.
* The mapper converts the domain model into a Drift companion.

---

## Repository Change

Add a creation operation to `CatchRepository`.

Suggested API:

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
* Database insertion
* Returning the created domain model

The UI must not construct database companions.

---

## Navigation Result

After a successful save:

* Close the add-catch form.
* Return the created `Catch` or a success result to the caller.
* Show a short success confirmation if that matches the existing application style.

The form must remain open if saving fails.

---

## Error Handling

If persistence fails:

* Do not close the form.
* Show a clear error message.
* Preserve the values already entered by the user.
* Allow the user to try again.

Do not expose raw database errors directly in the UI.

---

## Duplicate Catches

No duplicate detection is required.

The user may intentionally record catches with identical:

```text
species
caughtAt
weight
length
```

Each save creates a separate catch.

---

## Out of Scope

This milestone does not include:

* Catch list
* Catch details screen
* Catch editing
* Catch deletion
* Catch photos
* Notes
* Lure information
* Weather information
* Water temperature
* Depth
* Statistics
* Map markers for catches
* Automatic GPS fishing spot creation

---

## Acceptance Criteria

MFS-010 is complete when:

1. The user can open the add-catch form from a fishing spot.
2. The selected fishing spot is clearly shown.
3. A fish species is required.
4. Catch date and time default to the current local time.
5. The user can change the catch date and time.
6. Weight is optional and entered in kilograms.
7. Length is optional and entered in centimeters.
8. Comma and period decimal separators are accepted.
9. Weight is stored as integer grams.
10. Length is stored as integer millimeters.
11. Invalid measurements cannot be saved.
12. Saving creates a Catch linked to the correct fishing spot.
13. The form closes after successful persistence.
14. Entered values remain visible after a persistence failure.
15. No unrelated catch features are implemented.
16. `flutter analyze` passes.
17. The flow works on a physical Android device.
