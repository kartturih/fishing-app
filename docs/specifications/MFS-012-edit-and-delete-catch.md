# MFS-012 — Edit and Delete Catch

## Goal

Allow users to open an existing catch, edit its details, or permanently delete it.

---

## User Story

**As a fisherman**

I want to manage an existing catch

So that I can correct its details or remove it from my fishing log.

---

## Functional Requirements

### 1. Open Catch Management

Each catch row in the Fishing Spot Details bottom sheet shall be selectable.

Selecting a catch opens an Edit Catch bottom sheet.

---

### 2. Editable Fields

The user shall be able to edit:

- fish species
- catch date
- catch time
- weight
- length

The fishing spot shall remain read-only.

---

### 3. Initial Values

The edit form shall be prefilled with the catch's current values.

This includes:

- current species
- current date
- current time
- current weight
- current length

Missing optional measurements shall appear as empty fields.

---

### 4. Fishing Spot

The fishing spot name shall be displayed as read-only context.

The catch cannot be moved to another fishing spot.

---

### 5. Species

Fish species is required.

Use the existing `FishSpecies` enum and Finnish display names.

---

### 6. Date and Time

Catch date and time are required.

The user shall be able to edit both using the same date and time picker approach as the Add Catch flow.

---

### 7. Weight

Weight is optional.

The UI unit shall be kilograms.

Examples:

- `0.45`
- `1.2`
- `2.45`

Both comma and period decimal separators shall be accepted.

The stored value remains grams.

---

### 8. Length

Length is optional.

The UI unit shall be centimeters.

Examples:

- `32`
- `68.5`
- `102`

Both comma and period decimal separators shall be accepted.

The stored value remains millimeters.

---

### 9. Validation

The form shall reject:

- missing species
- invalid weight
- invalid length
- zero weight
- zero length
- negative weight
- negative length
- `NaN`
- `Infinity`

Invalid input shall not overwrite the existing catch.

---

### 10. Save Changes

Saving shall update the existing catch through `CatchRepository`.

The update shall preserve:

- catch ID
- fishing spot ID
- original `createdAt`

The update shall refresh:

- `updatedAt`

After a successful save:

- close the Edit Catch bottom sheet
- return a successful update result
- show a success message
- show the updated catch when Fishing Spot Details is opened again

---

### 11. Clear Optional Measurements

The user shall be able to remove an existing weight or length by clearing its field.

An empty optional field shall be stored as `null`.

---

### 12. Delete Action

The Edit Catch bottom sheet shall contain a clearly visible Delete action.

The Delete action shall be visually distinguishable as destructive.

Deletion shall not be available directly from the catch list.

Do not use:

- long press
- swipe actions
- inline delete icons
- context menus

---

### 13. Delete Confirmation

Before deleting, display a confirmation dialog.

Example:

```text
Delete catch?

This action cannot be undone.

Cancel   Delete
```

Deletion shall only occur after explicit confirmation.

---

### 14. Delete Catch

Confirming deletion shall permanently remove the selected catch through `CatchRepository`.

Deletion shall only affect the selected catch.

It shall not modify:

- the fishing spot
- other catches

---

### 15. Delete Success

After successful deletion:

- close the confirmation dialog
- close the Edit Catch bottom sheet
- show a success message
- the deleted catch shall no longer appear when Fishing Spot Details is opened again

---

### 16. Delete Cancel

Selecting Cancel in the confirmation dialog shall:

- close the dialog
- keep the Edit Catch bottom sheet open
- not delete the catch
- preserve all entered form values

---

### 17. Save Failure

If updating fails:

- keep the Edit Catch bottom sheet open
- preserve entered values
- re-enable controls
- allow retry
- show a clear error message

---

### 18. Delete Failure

If deleting fails:

- keep the Edit Catch bottom sheet open
- keep the catch unchanged
- preserve entered form values
- allow retry
- show a clear error message

---

### 19. Duplicate Actions

While saving or deleting:

- prevent duplicate taps
- disable conflicting actions
- do not call the repository more than once for the same action attempt

---

### 20. Cancel Editing

The user shall be able to close the Edit Catch bottom sheet without saving.

Canceling shall not modify or delete the catch.

---

### 21. Catch List Behavior

Catch rows shall remain visually simple.

Selecting a catch opens the Edit Catch bottom sheet.

Do not add:

- inline editing
- swipe actions
- delete buttons in the list
- long-press actions
- context menus

---

## Out of Scope

This feature does not include:

- moving a catch to another fishing spot
- catch notes
- catch photos
- catch details page
- duplicate catch detection
- undo after deletion
- bulk deletion
- statistics
- database migrations
- reactive database streams
- automatic reopening of Fishing Spot Details after save or delete

---

## Acceptance Criteria

- Selecting a catch opens the Edit Catch bottom sheet.
- Existing values are shown correctly.
- Species can be changed.
- Date and time can be changed.
- Weight can be changed or cleared.
- Length can be changed or cleared.
- Comma and period decimal separators are accepted.
- Invalid values are rejected.
- Catch ID remains unchanged after editing.
- Fishing spot ID remains unchanged after editing.
- `createdAt` remains unchanged after editing.
- `updatedAt` is refreshed after editing.
- Delete is available inside the Edit Catch bottom sheet.
- Delete confirmation is always shown.
- Canceling deletion does not delete the catch.
- Successful deletion removes only the selected catch.
- Save failure preserves entered values.
- Delete failure preserves the existing catch and form values.
- Duplicate save and delete taps are prevented.
- Updated or deleted data is reflected when Fishing Spot Details is opened again.
- `flutter analyze` passes.
- All tests pass.
- No database migration is required.