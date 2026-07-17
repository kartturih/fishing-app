# MFS-011 — View Catches for Fishing Spot

## Goal

Allow users to view all catches recorded for a fishing spot.

---

## User Story

**As a fisherman**

I want to view all catches recorded for a fishing spot

So that I can review my fishing history.

---

## Functional Requirements

### 1. Catch List

Display all catches belonging to the selected fishing spot inside the existing Fishing Spot Details bottom sheet.

The list shall appear below the existing action buttons.

---

### 2. Ordering

Display catches in the following order:

1. caughtAt (newest first)
2. createdAt (newest first)
3. id (ascending)

Use the existing repository ordering.

---

### 3. Catch Information

Each catch shall display:

- Fish species
- Weight (if available)
- Length (if available)
- Catch date and time

---

### 4. Weight Display

Display weight using user-friendly formatting.

Examples:

- 320 g
- 850 g
- 1 kg
- 1.2 kg
- 2.45 kg

Trailing zeros shall not be displayed.

---

### 5. Length Display

Display length in centimeters.

Examples:

- 68 cm
- 68.5 cm
- 70 cm

Trailing zeros shall not be displayed.

---

### 6. Missing Measurements

The UI shall correctly support:

- weight + length
- weight only
- length only
- neither

No empty separators or placeholder values shall be shown.

---

### 7. Empty State

If the fishing spot has no catches, display:

> No catches yet.

---

### 8. Read Only

Users cannot:

- edit catches
- delete catches
- reorder catches

Selecting a catch shall perform no action.

---

### 9. Performance

Load catches once when the Fishing Spot Details bottom sheet is opened.

Do not introduce Streams.

---

## Out of Scope

This feature does not include:

- editing catches
- deleting catches
- catch notes
- catch photos
- filtering
- statistics
- pagination
- database changes

---

## Acceptance Criteria

- All catches for the selected fishing spot are displayed.
- Catches are ordered correctly.
- Weight formatting is correct.
- Length formatting is correct.
- Missing measurements are handled correctly.
- Empty state is shown when appropriate.
- The implementation passes flutter analyze.
- All tests pass.
- No database migration is required.