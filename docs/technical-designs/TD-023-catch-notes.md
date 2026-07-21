# TD-023 — Catch Notes

## Status

Draft

## Related

- MFS-023: Catch Notes (the approved specification this document implements)
- MFS-009 / TD-009 — Catch Foundation (the `Catch` domain model, `Catches` table, `CatchRepository`, `CatchMapper` this document extends)
- MFS-010 / TD-010 — Add Catch (the creation form this document adds one field to)
- MFS-012 / TD-012 — Edit and Delete Catch (the editing form this document adds one field to, and the `EditCatchResult` type reused unchanged)
- MFS-014 / TD-014 — Catch Details View (the read-only view this document adds one section to; the section MFS-014/TD-014 originally reserved and left unfilled)
- MFS-013 / TD-013 — Catch Photos (the most recent precedent for a "should this have a database CHECK constraint" decision resolved as "no, repository enforcement is sufficient" — see [Key Design Decisions](#key-design-decisions))
- MFS-017 / TD-017 — Assign Lure to Catch (the most recent precedent for adding one new optional field to `Catch` via a plain `addColumn` migration — the shape this document's own migration follows)

---

## Summary

Implement MFS-023: one optional, nullable, plain-text `notes` field on `Catch`, editable in Add Catch and Edit Catch, displayed read-only as the final section of Catch Details when present — via an additive schema migration (6 → 7), with no new table, no new repository, no new feature, and no new navigation result.

The implementation shall satisfy MFS-023.

---

## Current State

Inspected directly, in the current codebase, before designing this change:

| Area | Current shape |
|---|---|
| `Catch` domain model ([catch.dart](../../lib/features/catches/domain/catch.dart)) | A plain class with `id`, `fishingSpotId`, `species`, `caughtAt`, optional `weightGrams`/`lengthMillimeters`/`lureVariantId`, `createdAt`, `updatedAt`. Three constructor `assert`s guard the optional fields (non-empty/positive when present). No `notes` field. No `==`/`hashCode`/`copyWith` exists on this class today — nothing to extend. |
| `Catches` table ([catches_table.dart](../../lib/features/catches/data/local/catches_table.dart)) | `weightGrams`/`lengthMillimeters` carry a `.check(...)` CHECK constraint; `lureVariantId` is a plain nullable `TextColumn` with a `restrict` foreign key and **no** CHECK constraint. No `notes` column. |
| `CatchMapper` ([catch_mapper.dart](../../lib/features/catches/data/catch_mapper.dart)) | Direct field-for-field mapping; nullable fields (`weightGrams`, `lengthMillimeters`, `lureVariantId`) pass through via `Value(...)` with no transformation. |
| `CatchRepository` ([catch_repository.dart](../../lib/features/catches/data/catch_repository.dart)) | Concrete class. `create`/`update` each validate `weightGrams`/`lengthMillimeters` (`_validateMeasurements`, throws `ArgumentError`) and `lureVariantId` (`_validateLureVariantId`, throws `ArgumentError` on empty string) independently of any UI-side validation — the exact "repository is the defensive authority" precedent this document reuses for `notes`. |
| `AppDatabase` ([app_database.dart](../../lib/core/database/app_database.dart)) | `schemaVersion => 6`. Every migration to date is additive: four `createTable` calls (versions 2–5) and one `addColumn` call (version 6, `catches.lureVariantId` — MFS-017/TD-017). |
| Add Catch ([add_catch_bottom_sheet.dart](../../lib/features/catches/presentation/widgets/add_catch_bottom_sheet.dart)) | A `StatefulWidget`/`Form` with one `TextEditingController` per text field (`_weightController`, `_lengthController`), disposed in `dispose()`. Field order: fishing spot (read-only) → species → date/time → weight → length → assigned lure → photos → Peruuta/Tallenna. Shared helpers (`parseCatchMeasurementInput`, `validateCatchWeightInput`, `validateCatchLengthInput`, `formatCatchDate`, `formatCatchTime`) live as top-level functions at the bottom of this file specifically so `EditCatchBottomSheet` can reuse them without a new utility file. |
| Edit Catch ([edit_catch_bottom_sheet.dart](../../lib/features/catches/presentation/widgets/edit_catch_bottom_sheet.dart)) | Same shape as Add Catch, prefilled from `widget.catchModel`; `_initialMeasurementText` formats stored grams/millimeters back into editable kg/cm text. Save calls `catchRepository.update(...)` and pops `CatchUpdated(updatedCatch, ...)` — the existing, unmodified `EditCatchResult` sealed type (MFS-012). |
| Catch Details ([catch_details_page.dart](../../lib/features/catches/presentation/widgets/catch_details_page.dart)) | Renders each field conditionally via `_buildInfoRow(label, value)` (a plain `Text`/`Text` pair), except the assigned lure, which uses its own dedicated `_buildAssignedLureRow()` because it renders a widget, not a string. **The file already contains a doc comment stating `notes` is part of MFS-014's field list but intentionally not displayed, because `Catch` has never captured it** — this document is exactly that anticipated follow-up. |
| Migration testing ([catch_migration_test.dart](../../test/features/catches/data/catch_migration_test.dart)) | Established pattern: a `_LegacyAppDatabase` subclass pins an old `schemaVersion` and creates the `catches` table via a literal `CREATE TABLE` statement matching that old shape exactly (not by reusing the current `Catches` table class, which already has the new column). The real `AppDatabase` is then pointed at that seeded file and upgraded, and the result is asserted. |
| `catch_photo_limits.dart` ([catch_photo_limits.dart](../../lib/features/catch_photos/domain/catch_photo_limits.dart)) | The established "shared limit constant" precedent: a single top-level `const int maxCatchPhotos = 5;` in its own small file, with a doc comment naming the enforcing repository and the originating MFS/TD. |

---

## Proposed Design

Add `notes` to `Catch` exactly the way `lureVariantId` was added one milestone ago (MFS-017/TD-017): one new optional field, one new nullable column, one `addColumn` migration, `create`/`update` gain one new optional parameter each, both existing forms gain one new field, Catch Details gains one new conditional section. No new file category is introduced except a small limits file mirroring an already-established pattern.

### Key Design Decisions

**1. No database-level CHECK constraint on `notes`.** See the dedicated rationale in [Data and Migration Changes](#database-level-check-constraint-decision) — decided **no**, following TD-013's own precedent of relying on repository enforcement alone for an equivalent "protect against exceeding a limit" case (the 5-photo maximum).

**2. Exactly one implementation of the normalize-and-validate algorithm, inside `CatchRepository`, reused by both `create` and `update`.** Neither Add Catch nor Edit Catch performs any trimming or empty-to-`null` conversion — both simply forward the controller's raw `String` to the repository. This is the only way to satisfy MFS-023's "repository remains defensive authority" requirement literally: if the widgets did their own trimming first, the repository's own check would be validating already-cleaned input, not defending against a caller that skipped the UI. See [Validation and Normalization](#validation-and-normalization).

**3. The length limit is measured on raw, pre-trim input, per MFS-023's own explicit decision — enforced identically in two independent places that both read the same constant.** The `TextFormField`'s `validator` and `CatchRepository`'s own check both compare the raw, untrimmed value against `maxCatchNotesLength` directly, never against a trimmed intermediate value. This cannot drift, because trimming cannot lengthen a string — anything that already fits the raw-input rule still fits after trimming. **The field itself does not block input beyond the limit** (`maxLengthEnforcement: MaxLengthEnforcement.none`) — see [Key Design Decision 7](#key-design-decisions) for why blocking input would be inconsistent with MFS-023's required validation-and-message UX.

**4. The limit constant lives in its own small file, `catch_notes_limits.dart`, mirroring `catch_photo_limits.dart` exactly.** Both are consumed by a domain constructor assertion, a repository defensive check, and a presentation-layer validator — the same three-consumer shape `maxCatchPhotos` already has. Placing it in `catch.dart` itself was considered and rejected: `catch_photo_limits.dart` already establishes that a limit shared across domain/data/presentation gets its own tiny file in this codebase, and following that precedent costs nothing extra.

**5. Catch Details gets one new dedicated method, `_buildNotesRow()` — `_buildInfoRow()` itself is not modified.** `_buildInfoRow(String label, String value)` is used by four unrelated fields today (species, weight, length, date/time) and renders a plain `Text` value. Notes needs a `SelectableText` value instead, which is not a value `_buildInfoRow`'s signature can express without changing every one of its existing callers. This mirrors the exact precedent already set by `_buildAssignedLureRow()`, which exists as its own method for the identical reason (it needed to render something `_buildInfoRow` cannot). No existing row's rendering changes.

**6. No new result type anywhere.** `EditCatchResult`/`CatchUpdated` (MFS-012) and `CatchDetailsResult`/`CatchDetailsUpdated` (MFS-014) already carry the full, current `Catch` object. Because `notes` is simply one more field on that same object, both result types already transport an edited note correctly the moment `Catch` itself gains the field — nothing about either sealed type changes.

**7. The notes field must allow entering more than `maxCatchNotesLength` characters — `maxLengthEnforcement: MaxLengthEnforcement.none`, not `.enforced`.** An earlier draft of this document specified `.enforced`, which physically prevents the field from ever containing more than 1000 characters. That is inconsistent with MFS-023's own required behavior: the raw, user-entered value must be *validated*, an over-limit value must *block saving* with a visible Finnish message, and the entered content must remain available for correction. None of that is reachable if the field can never contain an over-limit value in the first place — `Form.validate()` would never see one, so `validateCatchNotesInput` could never fire, and there would be nothing for the required over-limit widget tests to exercise. With `MaxLengthEnforcement.none`, the field's built-in counter still communicates the limit (Flutter renders it in an error style once exceeded, satisfying "the counter to communicate the 1000-character limit"), but the user can keep typing or pasting past it; `validateCatchNotesInput` is what actually blocks the save, and `CatchRepository._normalizeNotes` independently rejects the same over-limit value with `ArgumentError` if ever called directly. See [Presentation Changes](#presentation-changes) and [Validation and Normalization](#validation-and-normalization).

---

## Domain Changes

### `Catch` ([catch.dart](../../lib/features/catches/domain/catch.dart))

```dart
class Catch {
  const Catch({
    required this.id,
    required this.fishingSpotId,
    required this.species,
    required this.caughtAt,
    required this.createdAt,
    required this.updatedAt,
    this.weightGrams,
    this.lengthMillimeters,
    this.lureVariantId,
    this.notes,
  }) : assert(
         weightGrams == null || weightGrams > 0,
         'weightGrams must be greater than zero when provided',
       ),
       assert(
         lengthMillimeters == null || lengthMillimeters > 0,
         'lengthMillimeters must be greater than zero when provided',
       ),
       assert(
         lureVariantId == null || lureVariantId != '',
         'lureVariantId must not be empty when provided',
       ),
       assert(
         notes == null || notes.isNotEmpty,
         'notes must not be empty when provided',
       ),
       assert(
         notes == null || notes.length <= maxCatchNotesLength,
         'notes must not exceed $maxCatchNotesLength characters',
       );

  final String id;
  final String fishingSpotId;
  final FishSpecies species;
  final DateTime caughtAt;
  final int? weightGrams;
  final int? lengthMillimeters;
  final String? lureVariantId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

- **Placement:** appended after `lureVariantId`, before `createdAt`/`updatedAt` — the same "newest optional field goes last among the optional group" placement `lureVariantId` itself used when it was added after `lengthMillimeters` (MFS-017).
- **Nullability:** always optional; `null` means "no note," never an empty string — the same convention already established for every other optional field on this class.
- **Assertions:** two, mirroring the existing style exactly — a non-empty-when-present guard (matching `lureVariantId`'s own assert) and a length guard (matching the *shape* of `weightGrams`/`lengthMillimeters`'s positivity guards, adapted to a maximum instead of a minimum). Because Dart asserts are stripped in release builds, `CatchRepository` independently re-validates both conditions (see [Repository Changes](#repository-changes)) — the same "assert for debug-time correctness, explicit check for release-time defense" split this class already uses for its other three optional fields.
- **Equality/copy conventions:** none exist on `Catch` today (no `==`, `hashCode`, or `copyWith`), and this document introduces none — there is nothing to extend, and adding one now would be unrelated scope.
- **Limit constant location — a separate file, not `catch.dart` itself:** see [Key Design Decision 4](#key-design-decisions).

### `catch_notes_limits.dart` (new)

```text
lib/features/catches/domain/catch_notes_limits.dart
```

```dart
/// The maximum number of raw, user-entered characters a Catch's [notes]
/// field may contain, measured before whitespace trimming.
///
/// This is the single shared source of truth for the limit. It is enforced
/// authoritatively by [CatchRepository] and mirrored by the Add/Edit Catch
/// presentation so the UI can block and communicate the limit before a save
/// is attempted. See MFS-023 / TD-023.
const int maxCatchNotesLength = 1000;
```

Mirrors [catch_photo_limits.dart](../../lib/features/catch_photos/domain/catch_photo_limits.dart) verbatim in structure and doc-comment style.

---

## Data and Migration Changes

### `Catches` table ([catches_table.dart](../../lib/features/catches/data/local/catches_table.dart))

```dart
TextColumn get notes => text().nullable()();
```

Added after `lureVariantId`, before `createdAt`. No `.check(...)` — see the decision immediately below.

### Database-Level CHECK Constraint Decision

**Decision: No.**

Evaluated against the four factors MFS-023 requires this decision to be based on:

| Factor | Finding |
|---|---|
| Installed Drift capabilities | `weightGrams`/`lengthMillimeters`'s existing CHECK constraints use simple numeric comparisons (`.isBiggerThanValue(0)`), already proven in this codebase. A text-length CHECK has no equivalently proven, idiomatic Drift expression already in use here — it would require a `LENGTH(notes) <= 1000`-style custom SQL expression, an unproven pattern for this codebase to introduce for the first time on what should otherwise be the safest possible category of migration (a plain nullable column, per TD-017's own `addColumn` precedent). |
| Existing validation conventions | Directly analogous precedent exists and points the same way: TD-013 evaluated the same question for the 5-photo-per-catch maximum and concluded *"Repository validation shall enforce... A database-level count constraint is not required"* — repository-level enforcement of a business-rule limit, without a matching database constraint, is already an accepted pattern in this project. |
| Migration complexity | Adding an unproven custom-SQL CHECK expression introduces avoidable risk to a migration that would otherwise be trivially safe. Omitting it keeps this migration in the same proven, low-risk shape as every `addColumn` this project has done. |
| Meaningful protection beyond repository validation | None. `CatchRepository` is the **only** code path that ever writes to the `catches` table in this application — there is no cloud sync, no other client, and no raw SQL writer anywhere in this codebase. A CHECK constraint would only ever reject input that the exclusively-used repository path has already made structurally impossible to reach it. |

Repository validation (see [Repository Changes](#repository-changes)) is therefore the sole, authoritative enforcement point for the length limit, exactly as MFS-023 requires ("persistence must still normalize the value and reject invalid input defensively" — a repository-level requirement, not a database-level one).

### Schema Version

```text
schema version 6 -> schema version 7
```

```dart
@override
int get schemaVersion => 7;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (migrator) async {
    await migrator.createAll();
  },
  onUpgrade: (migrator, from, to) async {
    if (from < 2) { await migrator.createTable(catches); }
    if (from < 3) {
      await migrator.createTable(catchPhotos);
      await migrator.createIndex(catchPhotosCatchIdSort);
    }
    if (from < 4) {
      await migrator.createTable(lureModels);
      await migrator.createTable(lureVariants);
      await migrator.createIndex(lureModelsManufacturer);
      await migrator.createIndex(lureModelsLureType);
      await migrator.createIndex(lureVariantsLureModelId);
    }
    if (from < 5) {
      await migrator.createTable(tackleBoxEntries);
    }
    if (from < 6) {
      await migrator.addColumn(catches, catches.lureVariantId);
    }
    if (from < 7) {
      await migrator.addColumn(catches, catches.notes);
    }
  },
  beforeOpen: (details) async {
    await customStatement('PRAGMA foreign_keys = ON');
  },
);
```

Confirm at implementation time that the live schema version is still `6` before assuming `7` is the correct next number — the same hedge every prior TD in this project has required.

### Migration Safety and Behavior of Existing Rows

Identical safety category to TD-017's `lureVariantId` migration: `addColumn` on a nullable text column with no default requirement does not rewrite existing rows. Every pre-existing `Catch` row is immediately valid with `notes = NULL` — the natural, correct "no note" state for data that predates this feature, requiring no backfill. No other table or column is touched. Existing Fishing Spots, Catches (including their `lureVariantId` values), Catch Photos, Lure Models, Lure Variants, and Tackle Box Entries must all survive the upgrade unchanged.

### Mapper Changes ([catch_mapper.dart](../../lib/features/catches/data/catch_mapper.dart))

```dart
Catch toDomain(CatchEntity row) {
  return Catch(
    id: row.id,
    fishingSpotId: row.fishingSpotId,
    species: _speciesFromStored(row.species),
    caughtAt: DateTime.fromMillisecondsSinceEpoch(row.caughtAt),
    weightGrams: row.weightGrams,
    lengthMillimeters: row.lengthMillimeters,
    lureVariantId: row.lureVariantId,
    notes: row.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}

CatchesCompanion toCompanion(Catch catchModel) {
  return CatchesCompanion.insert(
    id: catchModel.id,
    fishingSpotId: catchModel.fishingSpotId,
    species: catchModel.species.name,
    caughtAt: catchModel.caughtAt.millisecondsSinceEpoch,
    weightGrams: Value(catchModel.weightGrams),
    lengthMillimeters: Value(catchModel.lengthMillimeters),
    lureVariantId: Value(catchModel.lureVariantId),
    notes: Value(catchModel.notes),
    createdAt: catchModel.createdAt.millisecondsSinceEpoch,
    updatedAt: catchModel.updatedAt.millisecondsSinceEpoch,
  );
}
```

A direct passthrough with no lookup or transformation, exactly like `lureVariantId`'s own mapping — `notes` is already a plain, already-normalized string on both sides by the time it reaches the mapper (normalization happens once, earlier, in the repository — see [Validation and Normalization](#validation-and-normalization)).

### Generated-Code Implications

Running the project's established Drift generation command (`dart run build_runner build --delete-conflicting-outputs`) regenerates `app_database.g.dart`: `CatchEntity` gains a `notes` field, `CatchesCompanion` gains a `notes` field/column, and the schema-verification metadata reflects version 7. No other generated file changes. Generated files must not be hand-edited; review the diff for exactly this scope before accepting it.

---

## Repository Changes

### `CatchRepository` ([catch_repository.dart](../../lib/features/catches/data/catch_repository.dart))

```dart
Future<Catch> create({
  required String fishingSpotId,
  required FishSpecies species,
  required DateTime caughtAt,
  int? weightGrams,
  int? lengthMillimeters,
  String? lureVariantId,
  String? notes,
}) async {
  if (fishingSpotId.isEmpty) {
    throw ArgumentError.value(fishingSpotId, 'fishingSpotId', 'must not be empty');
  }
  _validateMeasurements(weightGrams: weightGrams, lengthMillimeters: lengthMillimeters);
  _validateLureVariantId(lureVariantId);
  final normalizedNotes = _normalizeNotes(notes);

  final now = DateTime.now();
  final catchModel = Catch(
    id: _generateId(),
    fishingSpotId: fishingSpotId,
    species: species,
    caughtAt: caughtAt,
    weightGrams: weightGrams,
    lengthMillimeters: lengthMillimeters,
    lureVariantId: lureVariantId,
    notes: normalizedNotes,
    createdAt: now,
    updatedAt: now,
  );

  await _database.into(_database.catches).insert(_mapper.toCompanion(catchModel));
  return catchModel;
}

Future<Catch> update({
  required Catch catchModel,
  required FishSpecies species,
  required DateTime caughtAt,
  int? weightGrams,
  int? lengthMillimeters,
  String? lureVariantId,
  String? notes,
}) async {
  _validateMeasurements(weightGrams: weightGrams, lengthMillimeters: lengthMillimeters);
  _validateLureVariantId(lureVariantId);
  final normalizedNotes = _normalizeNotes(notes);

  final updatedCatch = Catch(
    id: catchModel.id,
    fishingSpotId: catchModel.fishingSpotId,
    species: species,
    caughtAt: caughtAt,
    weightGrams: weightGrams,
    lengthMillimeters: lengthMillimeters,
    lureVariantId: lureVariantId,
    notes: normalizedNotes,
    createdAt: catchModel.createdAt,
    updatedAt: DateTime.now(),
  );

  await _database.update(_database.catches).replace(_mapper.toCompanion(updatedCatch));
  return updatedCatch;
}

/// The single canonical implementation of MFS-023's normalization rule,
/// reused by both [create] and [update] — see TD-023 Key Design Decision 2.
///
/// Validates [rawNotes] against [maxCatchNotesLength] *before* trimming (per
/// MFS-023's explicit raw-input-length rule), then trims leading/trailing
/// whitespace, preserving internal whitespace and line breaks exactly.
/// Converts an empty-after-trim result to `null`.
String? _normalizeNotes(String? rawNotes) {
  if (rawNotes == null) {
    return null;
  }
  if (rawNotes.length > maxCatchNotesLength) {
    throw ArgumentError.value(
      rawNotes,
      'notes',
      'must not exceed $maxCatchNotesLength characters',
    );
  }
  final trimmed = rawNotes.trim();
  return trimmed.isEmpty ? null : trimmed;
}
```

- `update` continues to fully replace `notes`, exactly like every other field — passing no `notes` argument clears an existing note to `null`, the same "full replace, not a partial patch" behavior already documented for `lureVariantId`.
- `getByFishingSpotId`/`getById` require no changes: both already `select(_database.catches)` and map every column through `CatchMapper.toDomain`, so `notes` rides along automatically once the mapper is updated. No new query, no join.

### Which Invalid Calls Throw `ArgumentError`

| Call | Behavior |
|---|---|
| `create`/`update` with `notes: null` | Valid — stores `null`. |
| `create`/`update` with `notes: ''` or whitespace-only | Valid — normalizes to `null` (per [Validation and Normalization](#validation-and-normalization)), no error. |
| `create`/`update` with `notes` of exactly `maxCatchNotesLength` raw characters | Valid — at the limit, not over it. |
| `create`/`update` with `notes` of `maxCatchNotesLength + 1` or more raw characters (called directly, bypassing any UI validation) | **Throws `ArgumentError`** from `_normalizeNotes`, before any database write is attempted — mirroring exactly how `_validateMeasurements`/`_validateLureVariantId` already throw `ArgumentError` for an invalid `weightGrams`/`lengthMillimeters`/`lureVariantId`. |

---

## Presentation Changes

### Add Catch ([add_catch_bottom_sheet.dart](../../lib/features/catches/presentation/widgets/add_catch_bottom_sheet.dart))

**Controller lifecycle:** add `final _notesController = TextEditingController();` alongside `_weightController`/`_lengthController`; add `_notesController.dispose();` to the existing `dispose()` method alongside the other two.

**Exact placement:** the last input section, directly above the existing Peruuta/Tallenna `Row` — after the "Kuvat" (`CatchPhotoPreviewList`) section, before the action row. Current form order (unchanged): fishing spot (read-only) → species → date/time → weight → length → assigned lure → photos → **[new] notes** → Peruuta/Tallenna.

**`TextFormField` configuration:**

```dart
Text('Muistiinpanot', style: Theme.of(context).textTheme.labelMedium),
const SizedBox(height: AppSpacing.xs),
TextFormField(
  controller: _notesController,
  enabled: !_isSaving,
  minLines: 3,
  maxLines: 8,
  keyboardType: TextInputType.multiline,
  textCapitalization: TextCapitalization.sentences,
  maxLength: maxCatchNotesLength,
  maxLengthEnforcement: MaxLengthEnforcement.none,
  decoration: const InputDecoration(
    alignLabelWithHint: true,
    border: OutlineInputBorder(),
  ),
  validator: validateCatchNotesInput,
),
```

- A visible `Text` label above the field (matching the existing "Viehe"/"Kuvat" section-label pattern in this file) rather than an inline `labelText`, since a floating label reads awkwardly against a multi-line box — the same choice already made for the "Viehe"/"Kuvat" sections immediately above it.
- **`maxLines`/`minLines`:** the field starts at 3 visible lines and grows up to 8 as the user types; content beyond 8 lines scrolls within the field's own bounds rather than pushing the Save/Cancel row far down the already-scrollable sheet.
- **`maxLength`/`maxLengthEnforcement.none`:** `maxLength` gives the built-in Flutter character counter (communicating the limit per MFS-023's UI Expectations, and rendered in Flutter's error style once exceeded). `maxLengthEnforcement.none` deliberately does **not** block typing or pasting past the limit — per [Key Design Decision 7](#key-design-decisions), the field must be able to *contain* an over-limit value so that `Form.validate()` has something to reject and the required Finnish message has something to attach to. Blocking input here (`.enforced`) would silently prevent the exact scenario MFS-023 requires to be validated and rejected.
- **`validator: validateCatchNotesInput`** (new, shared helper — see below): the actual, sole blocking mechanism for over-limit input. Because the field itself no longer prevents entering more than `maxCatchNotesLength` characters, this validator is what makes `Form.validate()` fail and keeps `_submit()` from calling the repository — mirroring exactly how `validateCatchWeightInput`/`validateCatchLengthInput` already block saving for invalid weight/length.

**New shared validator** (added to the existing shared-helpers block at the bottom of this file, alongside `validateCatchWeightInput`/`validateCatchLengthInput`, for the same reason those already live there — reuse by `EditCatchBottomSheet` with no new utility file):

```dart
String? validateCatchNotesInput(String? value) {
  final text = value ?? '';
  if (text.length > maxCatchNotesLength) {
    return 'Muistiinpanot voivat olla enintään $maxCatchNotesLength merkkiä.';
  }
  return null;
}
```

**Save integration:** the raw controller text is forwarded unmodified — no trimming, no empty check, in the widget:

```dart
createdCatch = await widget.catchRepository.create(
  fishingSpotId: widget.fishingSpot.id,
  species: species,
  caughtAt: _selectedCaughtAt,
  weightGrams: weightGrams,
  lengthMillimeters: lengthMillimeters,
  lureVariantId: _selectedLure?.catalogEntry.id,
  notes: _notesController.text,
);
```

Passing the raw (possibly empty, possibly whitespace-only) string unconditionally is correct and requires no widget-side branching: `CatchRepository._normalizeNotes` (see [Repository Changes](#repository-changes)) already converts an empty or whitespace-only value to `null` — the widget does not need to replicate that logic, per [Key Design Decision 2](#key-design-decisions).

**Preservation on save failure:** no new code is needed. The existing failure path only calls `setState(() => _isSaving = false)` — it never clears any controller — so `_notesController`'s text (like `_weightController`'s and `_lengthController`'s) survives a failed save automatically.

**Keyboard and scroll behavior on small screens:** no new handling is needed. The entire form already lives inside a `SingleChildScrollView` with `MediaQuery.viewInsetsOf(context).bottom` bottom padding (the established keyboard-black-flash fix, MFS-010/TD-010) — the new field participates in that same scroll view like every existing field.

### Edit Catch ([edit_catch_bottom_sheet.dart](../../lib/features/catches/presentation/widgets/edit_catch_bottom_sheet.dart))

**Controller initialization from nullable notes:**

```dart
late final _notesController = TextEditingController(
  text: widget.catchModel.notes ?? '',
);
```

Mirrors the exact `late final ... TextEditingController(text: ...)` shape already used for `_weightController`/`_lengthController` (which use `_initialMeasurementText` to format a nullable numeric value into text); `notes` needs no formatting step, just a null-safe fallback to an empty string.

**Add/change/clear behavior:** a plain multi-line text field already supports all three without any extra affordance or state variable — the user either types into an empty field (add), edits existing text (change), or deletes all of it (clear). This is simpler than the assigned-lure row, which needs explicit "change"/"remove" actions because a lure cannot be typed — notes require none of that.

**Passing raw text to the repository:** identical to Add Catch —

```dart
updatedCatch = await widget.catchRepository.update(
  catchModel: widget.catchModel,
  species: species,
  caughtAt: _selectedCaughtAt,
  weightGrams: weightGrams,
  lengthMillimeters: lengthMillimeters,
  lureVariantId: _selectedLureEntry?.id,
  notes: _notesController.text,
);
```

**Use of the existing `CatchUpdated` result:** unchanged. `Navigator.of(context).pop(CatchUpdated(updatedCatch, photoFailureCount: photoFailureCount));` already carries the full `updatedCatch`, which now includes its (possibly changed) `notes` value — no change to `EditCatchResult`/`CatchUpdated` itself, per [Key Design Decision 6](#key-design-decisions).

**Disposal:** add `_notesController.dispose();` to the existing `dispose()` method.

**Behavior after validation or persistence failure:** identical to Add Catch — no controller is ever cleared on a failure path in this file today, so the typed note (like every other field) is preserved automatically with no new code.

**Field placement:** same position as Add Catch — the last input section, directly above the existing Poista/Tallenna `Row`.

### Catch Details ([catch_details_page.dart](../../lib/features/catches/presentation/widgets/catch_details_page.dart))

**Exact placement after lure:**

```dart
if (_catchModel.lureVariantId != null) _buildAssignedLureRow(),
if (_catchModel.notes != null) _buildNotesRow(),
```

Added as the very last conditional row in `build()`'s `Column`, immediately after the existing lure row — the exact position MFS-014/TD-014 originally reserved.

**Omission when null:** a plain `if` guard, identical in form to every other conditional row already on this page (weight, length, lure) — no placeholder, no empty-state widget.

**New method — `_buildNotesRow()` (dedicated, not a change to `_buildInfoRow`):**

```dart
Widget _buildNotesRow() {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Muistiinpanot', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(
          _catchModel.notes!,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );
}
```

Structurally a near-copy of `_buildInfoRow`'s own `Padding`/`Column`/label-then-value shape, but using `SelectableText` for the value instead of `Text` — the same "needs its own method because it needs different content" reasoning already established by `_buildAssignedLureRow()`. See [Key Design Decision 5](#key-design-decisions). `_buildInfoRow` itself is untouched, so every field that already uses it (species, weight, length, date, time) is unaffected.

**Layout and wrapping:** no explicit `maxLines`/`overflow` is set — `SelectableText` wraps naturally within the available width, exactly like `Text` already does elsewhere on this page. The page's existing `SingleChildScrollView` means a long note never gets clipped; it simply extends the page's scrollable height.

**Accessibility semantics:** the preceding `Text('Muistiinpanot', ...)` provides the same visible, accessible label every other row on this page already has. `SelectableText` exposes its own content to assistive technology as ordinary readable text; making it selectable does not suppress or alter that. No `Semantics(button: true)` or similar is needed — unlike the Statistics feature's tappable rows, this text is not interactive in the navigation sense, only selectable.

**Behavior for long, multiline notes:** `SelectableText` renders embedded `\n` characters as real line breaks (identical to `Text`), so a note's original line breaks display exactly as entered. Combined with the page's existing scrollability, a note at the full 1000-character limit displays in full, with no truncation, ellipsis, or "show more" affordance — per MFS-023's explicit UI Expectations.

**`_buildInfoRow` reuse decision:** **not reused, minimally adapted via a new sibling method instead** — see [Key Design Decision 5](#key-design-decisions) for the full reasoning. The rest of Catch Details (app bar, photo gallery, overflow menu, delete flow) is unchanged.

---

## Navigation and Lifecycle

- **No new route is introduced.** Add Catch and Edit Catch remain modal Bottom Sheets; Catch Details remains a pushed `MaterialPageRoute` — none of these change in kind.
- **No new navigation result is needed.** `EditCatchResult`/`CatchUpdated` (MFS-012) and `CatchDetailsResult`/`CatchDetailsUpdated`/`CatchDetailsDeleted` (MFS-014) are unmodified; both already transport the complete `Catch` object, which now simply carries one more field.
- **Existing refresh behavior already carries updated notes correctly, with no code change required to prove it:** `CatchDetailsPage._openEdit()` already does, on a `CatchUpdated` result:

  ```dart
  case CatchUpdated(:final catchModel, :final hasPhotoFailures):
    setState(() {
      _catchModel = catchModel;
      _hasChanges = true;
    });
  ```

  Because `catchModel` is the exact `Catch` instance `CatchRepository.update` returned — including its new, current `notes` value — `_catchModel.notes` is correct the instant this existing `setState` runs. No change to `_openEdit()` is required.
- **Deletion behavior remains unchanged.** Deleting a catch deletes its entire row, `notes` included, through the existing `CatchRepository.delete`/cascade path — there is no separate file, child row, or cleanup step for a note (unlike photos), so nothing about the existing delete flow (confirmation dialog, `CatchPhotoRepository.deleteFilesForCatch` ordering, `CatchDeleted`/`CatchDetailsDeleted` results) needs to change.

---

## Validation and Normalization

**Canonical algorithm** (implemented once, in `CatchRepository._normalizeNotes` — see [Repository Changes](#repository-changes)):

```text
1. If the raw value is null, the note is null. Stop.
2. If the raw value's length exceeds maxCatchNotesLength (1000), throw ArgumentError. Stop.
3. Trim leading and trailing whitespace from the raw value.
   Internal whitespace and line breaks are left exactly as they are.
4. If the trimmed result is empty, the note is null.
   Otherwise, the note is the trimmed result.
```

**Why the limit check happens before trimming (step 2, not after step 3):** per MFS-023's explicit decision, the 1000-character limit is defined against the *raw* input — the same quantity the UI's character counter and `validateCatchNotesInput` already measure. Since trimming can only shorten a string, nothing that passes the raw-input check can fail an equivalent post-trim check; defining it pre-trim simply lets every layer that checks it (the UI validator, the repository) agree on one number without either needing to simulate trimming first.

**Where this logic lives, and how `create`/`update` reuse it:** entirely inside one private method, `CatchRepository._normalizeNotes(String? rawNotes)`, called identically from both `create` and `update`. Neither Add Catch nor Edit Catch implements any part of this algorithm — both simply pass their controller's raw `.text` straight through (see [Presentation Changes](#presentation-changes)). This is the only design that cannot produce "slightly different normalization logic" between the four call sites MFS-023 names, because three of those four sites (Add Catch, Edit Catch, and any other future caller) perform no normalization at all — there is nothing for them to implement differently.

**The repository remains the defensive authority even when UI validation already passed:** the `TextFormField`'s `maxLength` counter is purely informational (per [Key Design Decision 7](#key-design-decisions), `maxLengthEnforcement.none` means it never blocks input), and `validateCatchNotesInput` is what actually blocks `Form.validate()` for an over-limit value before the repository is ever called. Neither is trusted as the sole source of correctness — `_normalizeNotes` re-checks the length itself and throws `ArgumentError` if a caller (a future screen, a test, a direct repository call) supplies an over-limit value regardless of what any UI already did or did not check. This is the exact same relationship already established between `validateCatchWeightInput`/`validateCatchLengthInput` and `CatchRepository._validateMeasurements`.

---

## Error Handling

| Scenario | Behavior |
|---|---|
| A direct `CatchRepository.create`/`update` call supplies `notes` longer than `maxCatchNotesLength` (bypassing any UI) | `ArgumentError` is thrown from `_normalizeNotes`, before any database write is attempted — no partial insert/update occurs. |
| The user types or pastes past the limit in Add/Edit Catch | The field allows the over-limit text to be entered (`maxLengthEnforcement: MaxLengthEnforcement.none`), and its counter renders in Flutter's error style once exceeded. `validateCatchNotesInput` then blocks `Form.validate()` from succeeding, so `_submit()` returns early with the approved Finnish message shown and the entered text left in the field for correction — identical in shape to how an invalid weight/length already blocks saving. |
| General save failure (e.g. a database error) while a note is present | No new handling — the existing Add/Edit Catch failure path already keeps the sheet open, re-enables controls, shows the existing generic error message, and preserves every controller's text, `_notesController` included, since no controller is ever cleared on that path. |
| A catch has no note | Not an error state — Catch Details simply renders no section for it (see [Presentation Changes](#presentation-changes)), the same as any other absent optional field. |
| Migration failure | Mitigated by the migration being the safest possible category (nullable column, no default, no rewrite, no CHECK) and verified by a dedicated schema-snapshot migration test before implementation is considered complete (see [Testing Strategy](#testing-strategy)). |

---

## Accessibility

- **Add/Edit Catch:** the visible `Text('Muistiinpanot', ...)` label immediately above the `TextFormField` provides the same accessible labeling convention already used for the adjacent "Viehe"/"Kuvat" sections in both forms. The field's own built-in character counter (from `maxLength`) is exposed by Flutter's `TextFormField` semantics automatically, with no extra work required.
- **Catch Details:** the visible `Text('Muistiinpanot', ...)` label preceding the `SelectableText` value follows the same accessible-labeling convention as every other row on this page (species, weight, length, date, time, lure).
- **Selectability does not degrade accessibility:** `SelectableText` remains fully readable by assistive technology — it is a text-rendering widget with added selection interaction, not a replacement for semantic text content. No `excludeSemantics` or custom `Semantics` wrapper is introduced or needed, since — unlike the Statistics feature's tappable rows — this text has no navigation action to expose or suppress.
- **Tap targets and text scaling:** both forms' new field and Catch Details' new section follow the application's existing Material 3 sizing and text-scaling conventions, with no custom overrides.

---

## Testing Strategy

Follows the same layered testing philosophy as every prior TD in this project: domain tests for construction/assertions, a migration test against a real legacy schema snapshot, a mapper round-trip test, repository tests for behavior, widget tests for each presentation surface, and a physical-device pass at the end.

### Domain (`test/features/catches/domain/catch_test.dart`, extended)

- constructs successfully with `notes: null`
- constructs successfully with a normal, non-empty `notes` value
- constructs successfully with `notes` at exactly `maxCatchNotesLength` characters
- rejects (via `assert`) `notes` longer than `maxCatchNotesLength`
- rejects (via `assert`) an empty-string `notes`

### Migration (extending the established migration-test area, mirroring `catch_migration_test.dart`'s `_LegacyAppDatabase` pattern — **using a real schema-6 snapshot, not the current `Catches` table class**)

A new legacy snapshot subclass pins `schemaVersion => 6` and creates `catches` via a literal `CREATE TABLE` statement matching the *current, real* schema-6 shape exactly (including `lure_variant_id`, but with **no** `notes` column) — following the same discipline the existing schema-5 snapshot already established for testing the 6-column addition, not by reusing the current `Catches` table class (which already has `notes` and would defeat the point of the test). Seed at least one pre-existing `Catch` row (with a non-null `lureVariantId`, to prove that column also survives) before upgrading. Verify:

- migration from schema 6 to 7 succeeds
- the pre-existing fishing spot and catch row(s) survive the upgrade unchanged, including their `lureVariantId`
- the pre-existing catch row(s) have `notes == null` after the upgrade
- a new catch with a `notes` value can be written and read back correctly after the upgrade completes

### Mapper (`catch_mapper_test.dart` if one exists as its own file, or the equivalent coverage within `catch_repository_test.dart` — matching however `lureVariantId`'s mapping was tested)

- round-trips a non-null `notes` value unchanged
- round-trips a `null` `notes` value

### Repository (`catch_repository_test.dart`, extended, new `group('CatchRepository notes')` mirroring the existing `group('CatchRepository lureVariantId')` structure)

- `create` with `notes` omitted stores `null`
- `create` with a normal `notes` value persists it exactly
- `create` with `notes` at exactly `maxCatchNotesLength` characters succeeds
- `create` with `notes` over `maxCatchNotesLength` characters throws `ArgumentError`
- `create`/`update` trims leading and trailing whitespace from `notes` before storing
- `create`/`update` preserves internal spaces and line breaks in `notes` exactly
- `create`/`update` with a whitespace-only `notes` value stores `null`
- `update` can add a `notes` value to a catch that had none
- `update` can change an existing `notes` value to a different one
- `update` can clear an existing `notes` value to `null` by passing an empty/whitespace-only string, or by omitting it
- `update` with `notes` over `maxCatchNotesLength` characters throws `ArgumentError`
- `getByFishingSpotId`/`getById` return the correct `notes` value in every case above

### Add Catch (`add_catch_bottom_sheet_test.dart`, extended)

- the notes field renders in the correct position (after photos, before the action row)
- leaving the field empty and saving succeeds, with the created catch having `notes == null`
- entering a multi-line note and saving persists it with line breaks intact
- the character counter reflects `maxCatchNotesLength`
- a note of exactly `maxCatchNotesLength` characters saves successfully
- a note containing leading/trailing whitespace is normalized (trimmed) in the persisted `Catch`
- a save failure preserves the entered note text in the still-open form
- **over-limit input (the required six-step flow):**
  1. enter or paste 1001 characters into the notes field
  2. verify the field contains the full over-limit text (not truncated — `MaxLengthEnforcement.none` per [Key Design Decision 7](#key-design-decisions))
  3. attempt to save
  4. verify no catch is created (the repository is never called)
  5. verify the Finnish validation message ("Muistiinpanot voivat olla enintään 1000 merkkiä.") is shown
  6. verify the full 1001-character text remains in the field, available for correction

### Edit Catch (`edit_catch_bottom_sheet_test.dart`, extended)

- opening a catch with an existing note prefills the field with it
- opening a catch with no note shows an empty field
- a note can be added where none existed
- an existing note can be changed
- an existing note can be cleared by deleting all its text, and saving results in `notes == null`
- a note of exactly `maxCatchNotesLength` characters saves successfully
- saving (with or without a note change) still produces the existing `CatchUpdated` result — no new result type or field is asserted beyond the existing `catchModel`/`photoFailureCount` shape
- **over-limit input (the same required six-step flow as Add Catch):**
  1. enter or paste 1001 characters into the notes field
  2. verify the field contains the full over-limit text
  3. attempt to save
  4. verify the catch is not updated (the repository is never called) and its existing note, if any, is unchanged
  5. verify the Finnish validation message is shown
  6. verify the full 1001-character text remains in the field, available for correction

### Catch Details (`catch_details_page_test.dart`, extended)

- a catch with a note displays it, in full, as the final section, after the lure row
- a catch with no note renders no notes section at all
- a note containing line breaks displays them as real line breaks, not literal `\n` text
- a long note (at or near the limit) wraps and displays in full, with no truncation
- the displayed note text is selectable
- every existing field (species, weight, length, date, time, lure, photos) continues to render exactly as before — a direct regression check that `_buildInfoRow` and every other existing row are unaffected

### Regression — Confirmed No Required Changes

Explicitly out of scope for any code change in this milestone, and unaffected in behavior:

- **Catch List** (`CatchListItem`) — does not render notes and needs no change (MFS-023 Out of Scope: no notes indicator).
- **Statistics repositories/pages** (`GeneralCatchStatisticsRepository`, `SpeciesStatisticsRepository`, `FishingSpotStatisticsRepository`, `LureStatisticsRepository`, and every associated presentation widget) — all read `Catch` through the existing `CatchMapper`/`CatchListItem`, neither of which surfaces notes; none require any change.
- **Search/filtering** — does not exist yet in this application (MFS-024 territory); nothing to regress.
- **Catch Photos** (`catch_photos` feature) — entirely unaffected; no shared file, table, or repository between the two features changes.
- **Fishing spot data** (`fishing_spots` feature) — unaffected; `Catches.fishingSpotId` and its cascade behavior are untouched.
- **Species data** (`FishSpecies` enum/extension) — unaffected; unrelated to this field.

### Integration/Physical Android Testing

Add a note during catch creation; edit an existing catch to add, change, and clear a note; verify a note with line breaks displays correctly in Catch Details; verify the character counter and over-limit blocking on-device; verify the note persists across an application restart and across the schema 6→7 migration on a pre-existing installation with real data; verify selecting/copying note text works via the platform's native text-selection UI; verify full offline/airplane-mode operation throughout.

---

## File Plan

### Expected Files To Create

```text
lib/features/catches/domain/catch_notes_limits.dart
```

Plus extended test files under `test/features/catches/...` per [Testing Strategy](#testing-strategy) (no new test *files* are strictly required if existing files are extended in place, matching how `lureVariantId` was tested — a new migration-snapshot test may warrant its own small addition within the existing migration test file, following that file's own established per-version-snapshot pattern).

### Expected Files To Modify

```text
lib/core/database/app_database.dart                                   (schema 6 -> 7, addColumn migration)
lib/features/catches/domain/catch.dart                                 (add notes field + two assertions)
lib/features/catches/data/local/catches_table.dart                     (add notes column, no CHECK)
lib/features/catches/data/catch_mapper.dart                            (map notes, both directions)
lib/features/catches/data/catch_repository.dart                        (create/update gain notes; add _normalizeNotes)
lib/features/catches/presentation/widgets/add_catch_bottom_sheet.dart  (notes field, controller, validator, save call)
lib/features/catches/presentation/widgets/edit_catch_bottom_sheet.dart (notes field, controller, save call)
lib/features/catches/presentation/widgets/catch_details_page.dart      (notes section, _buildNotesRow)
test/features/catches/domain/catch_test.dart                           (new assertions)
test/features/catches/data/catch_migration_test.dart                   (new schema-6 snapshot, 6->7 coverage)
test/features/catches/data/catch_repository_test.dart                  (new 'CatchRepository notes' group)
test/features/catches/presentation/widgets/add_catch_bottom_sheet_test.dart   (new coverage)
test/features/catches/presentation/widgets/edit_catch_bottom_sheet_test.dart  (new coverage)
test/features/catches/presentation/widgets/catch_details_page_test.dart      (new coverage)
```

**This change is not confined to the `catches` feature directory.** `lib/core/database/app_database.dart` is expected to be modified as well, because the Drift schema version and migration strategy are owned by the Core Database, not by any individual feature (ADR-0003, ADR-0006) — exactly the same shape MFS-017/TD-017's own `lureVariantId` addition already took (its own `app_database.dart` schema-version/migration change, alongside its changes inside `catches`). Every other file listed above under "Expected Files To Modify" is inside `lib/features/catches/` or `test/features/catches/`.

No other existing file is modified. `lib/features/catch_photos/`, `lib/features/fishing_spots/`, `lib/features/lure_catalog/`, `lib/features/personal_tackle_box/`, and `lib/features/statistics/` are not touched. `lib/features/catches/presentation/widgets/catch_list_item.dart` is not touched.

---

## Implementation Order

1. Confirm the live schema version is still `6` (not moved past it since this document was written).
2. Add `catch_notes_limits.dart`.
3. Add `notes` to `Catch` (domain), with its two assertions.
4. Add the `notes` column to the `Catches` table (no CHECK).
5. Increment `schemaVersion` to `7`; add the `if (from < 7) { addColumn(...) }` branch.
6. Run Drift code generation.
7. Update `CatchMapper` (`toDomain`/`toCompanion`).
8. Add `_normalizeNotes` to `CatchRepository`; thread `notes` through `create`/`update`.
9. Add the schema-6 legacy snapshot and its 6→7 migration test.
10. Add domain and repository tests.
11. Add the notes field to `AddCatchBottomSheet` (controller, `TextFormField`, `validateCatchNotesInput`, save call, disposal).
12. Add the notes field to `EditCatchBottomSheet` (controller prefilled from `widget.catchModel.notes`, save call, disposal).
13. Add `_buildNotesRow()` and its conditional call to `CatchDetailsPage`.
14. Add/extend widget tests for Add Catch, Edit Catch, and Catch Details.
15. Run `dart format .`, `flutter analyze`, `flutter test`.
16. Perform architecture review.
17. Physical Android testing.

---

## Risks and Mitigations

| Risk | Category | Mitigation |
|---|---|---|
| A text-length CHECK constraint was considered and rejected; if a future write path bypasses `CatchRepository`, an over-limit value could reach the database uncaught. | Data integrity | Accepted explicitly — see [Database-Level CHECK Constraint Decision](#database-level-check-constraint-decision). `CatchRepository` is the sole write path in this offline, single-process application; if that ever changes (e.g. cloud sync introduces a second writer), this decision should be revisited at that time, not before. |
| With `maxLengthEnforcement.none`, a user can paste or type arbitrarily far past `maxCatchNotesLength` before validation runs (unlike `.enforced`, which caps input at the source). | UX | Bounded in practice: the field's counter turns to Flutter's error style the moment the limit is exceeded, giving immediate visual feedback well before Save is attempted. The repository-level check (`_normalizeNotes`) remains the authoritative guarantee regardless of how far over the limit the field's content goes — an arbitrarily long value is rejected exactly the same way a value one character over the limit is. |
| The new schema-6 legacy snapshot in the migration test duplicates a `CREATE TABLE` statement that must be kept in sync with the real schema-6 shape by hand. | Test maintainability | The exact same trade-off already exists for the schema-5 snapshot in the current `catch_migration_test.dart` and has not caused problems across the four migrations since — the pattern is proven, not new. |
| Adding a multi-line field lengthens both Add Catch and Edit Catch's Bottom Sheets, which are already fairly tall forms. | UX | `minLines: 3, maxLines: 8` bounds the field's own growth, and both sheets are already fully scrollable — no different in kind from how the existing forms already accommodate species, date/time, weight, length, lure, and photos. |

---

## Definition of Done

* The implementation satisfies all requirements in MFS-023.
* The implementation follows TD-023, or documents and justifies each deviation.
* `Catch` has an optional `notes` field with the two assertions specified.
* The `Catches` table has a nullable `notes` column with no CHECK constraint; schema version is `7`.
* The migration from schema 6 succeeds and preserves all existing data, verified against a real schema-6 snapshot (not the current table class).
* `CatchRepository.create`/`update` accept and correctly normalize `notes`, via the single shared `_normalizeNotes` implementation.
* A `notes` value exceeding `maxCatchNotesLength`, passed directly to the repository, throws `ArgumentError`.
* Add Catch offers an optional, multi-line `Muistiinpanot` field, positioned last before its action row; leaving it empty saves successfully with `notes == null`.
* Edit Catch prefills the existing note (if any) and supports adding, changing, and clearing it.
* Saving a note change in Edit Catch produces the existing `CatchUpdated` result — no new result type.
* Catch Details shows the note, in full and selectable, as the final section, only when present.
* No unrelated field's rendering in Catch Details changes (`_buildInfoRow` is untouched).
* No unrelated feature (`catch_photos`, `fishing_spots`, `lure_catalog`, `personal_tackle_box`, `statistics`, `catch_list_item.dart`) is modified.
* `dart format .`, `flutter analyze`, and `flutter test` all pass.
* Architecture review is completed.
* Physical Android testing is completed.
* Documentation (`docs/project-status.md`, `docs/roadmap.md`) is updated in a separate, subsequent step — not part of this document's own completion.

---

## Implementation Notes

To be completed during implementation, following the established convention of recording any deviation from this document here, with justification.
