# TD-017 — Assign Lure to Catch

## Status

Draft

## Related Specification

* MFS-017: Assign Lure to Catch

---

## Goal

Implement an optional, stable reference from a `Catch` to a `LureVariant`, plus the minimal UI to assign, change, remove, and display it — fully satisfying MFS-017 — without modifying the domain, data, or repository layers of either `lure_catalog` (MFS-015) or `personal_tackle_box` (MFS-016).

The implementation shall satisfy MFS-017.

---

## Scope

Implement:

* an optional `lureVariantId` field on the `Catch` domain model and `Catches` table
* a non-destructive schema migration (version 5 → 6)
* `CatchRepository.create`/`update` accepting an optional `lureVariantId`
* `CatchMapper` round-tripping the new nullable column
* an "assign a lure" step in Add Catch, reusing the Personal Tackle Box browsing screen as the picker
* assign/change/remove of the lure in Edit Catch
* read-only display of the assigned lure in Catch Details
* one small, new, shared presentation widget for rendering an assigned/unassigned lure row, reused by all three screens above
* one new optional parameter on `PersonalTackleBoxPage` so it can also serve as a picker
* loading, empty, and error states for every new capability
* accessibility labeling
* tests

Do **not** implement:

* more than one lure per catch
* assigning a lure not currently in the Personal Tackle Box
* showing lure information in the catch list
* lure-based statistics, filtering, or recommendations
* any change to `lure_catalog`'s or `personal_tackle_box`'s domain model, tables, repository, or read-only/reference-only guarantees
* Riverpod, repository interfaces, DAO/service/use-case layers, reactive database streams (`watch()`)
* an index on `Catches.lureVariantId` (see [Key Design Decision 5](#key-design-decisions))

---

## Key Design Decisions

This section answers the questions most likely to be raised in review, before the detailed sections implement them.

**1. `Catch` references `LureVariant.id` directly, as a plain nullable column — not a new join table.** MFS-017's Conceptual Relationship resolved that a catch's lure reference must survive the referenced `TackleBoxEntry` being removed, which only a reference to the never-deleted catalog identity achieves. Because this is a 0-or-1 relationship — exactly like `Catch.fishingSpotId` is a 1-relationship today — a single nullable `TEXT` column on the existing `Catches` table is the correct shape, not a new table. This is also exactly what TD-016's own Future Extensibility section anticipated: *"`TackleBoxEntry.id`/`lureVariantId` are already stable references a future `Catch.tackleBoxEntryId` (or `Catch.lureVariantId`) column can point to, exactly like `Catch.fishingSpotId` today. No remodel of this milestone's tables is anticipated."* This design implements the `Catch.lureVariantId` branch of that note.

**2. `CatchRepository` never joins into `lure_catalog`'s tables.** `PersonalTackleBoxRepository` performs its own three-table join because it resolves *many* rows in one call (`getAll()`); avoiding an N+1 there is what justified that join (TD-016, Key Design Decision 2). This feature never resolves more than one catch's assigned lure at a time — Catch Details shows one catch, Edit Catch edits one catch, and the catch list shows no lure information at all (MFS-017 FR-5). There is no list-of-many-lures scenario here to protect against N+1, so `CatchRepository` gains no join and no new table knowledge. Resolving a `lureVariantId` into full display details is done by the presentation layer calling `LureCatalogRepository.getEntryById()` directly — already public, already a single joined query, already retired-safe (see [§8](#8-catch-details)).

**This single-record resolution is intentional and scoped to the current one-record use case, not a general-purpose lookup strategy.** `getEntryById()` is called at most once per open screen, for exactly one already-known `lureVariantId`. If a future milestone needs to resolve assigned lures for a *collection* of catches at once (Lure-Based Catch Statistics, filtering catches by lure, showing lure info in the catch list, or any other analytics use case), it must not be built by calling `getEntryById()` in a loop over that collection — that would reintroduce the exact N+1 pattern this design deliberately avoids for the single-record case. Such a future milestone should design a dedicated bulk-resolution query (e.g. a join or a batched lookup keyed by a set of `lureVariantId`s), the same way `PersonalTackleBoxRepository.getAll()` already does for tackle box browsing. This is a documentation note only; no such bulk-resolution strategy is designed or implemented here.

**3. `PersonalTackleBoxPage` gains one new optional `onSelect` callback parameter, default `null`.** This is the same shape of touch TD-016 itself used to let `personal_tackle_box` hang its own "Add" action off `lure_catalog`'s `LureDetailsPage` (TD-016, Key Design Decision 1: one optional, generic parameter, default `null` = today's exact behavior). When `onSelect` is supplied, tapping a row invokes it instead of pushing `OwnedEntryDetailPage`; when omitted, the page behaves exactly as it does today. This lets `catches` reuse the existing grouped browsing screen as its lure picker without `personal_tackle_box` gaining any knowledge of, or dependency on, `catches`.

**Regression guarantee: when `onSelect == null`, the behavior must remain byte-for-byte identical to the current implementation.** This is not a soft preference but a hard requirement — every existing caller of `PersonalTackleBoxPage` (today, only `MapScreen`'s standalone browsing entry point) passes no `onSelect`, and none of that existing behavior may change as a side effect of this milestone. The existing test suite for this page (every test in `personal_tackle_box_page_test.dart` predating this milestone) must continue to pass unmodified with `onSelect` omitted — see [§11](#11-testing-strategy).

**4. The foreign key `Catches.lureVariantId → LureVariants.id` uses `KeyAction.restrict`, not `cascade` or `setNull`.** Same rationale as TD-016, Key Design Decision 5: nothing in this codebase ever deletes a `LureVariant` row (retirement is a flag, never a `DELETE`). `restrict` documents and enforces that invariant rather than leaving an unused cascade/setNull choice in place. After this milestone, two independent `restrict` foreign keys point at `LureVariants.id` — one from `TackleBoxEntries` (TD-016), one from `Catches` (this document) — both equally preventing an accidental deletion.

**5. No index is added to `Catches.lureVariantId` in this milestone.** Nothing in MFS-017 queries `Catches` in bulk by `lureVariantId` — the catch list is unchanged (FR-5), and every resolution in this milestone starts from a single already-known `Catch` or a single already-known `lureVariantId`, never a `WHERE lureVariantId = ?` scan across catches. Adding an index now would be speculative structure for a query this milestone never issues. The roadmap's next candidate milestone, Lure-Based Catch Statistics, is exactly the kind of feature that would need one — adding `@TableIndex` at that point is a trivial, purely additive change with no migration conflict (see [§13](#13-future-compatibility)).

**6. This is the project's first `addColumn` migration.** Every migration from schema version 2 through 5 only ever added a whole new table (`createTable`). This milestone adds a nullable column to an *existing* table (`Catches`) for the first time. This is a standard, well-supported Drift/SQLite operation (`ALTER TABLE ... ADD COLUMN`, no rewrite of existing rows), but it is called out explicitly here since it is a new category of migration for this codebase, not a repetition of an already-proven pattern.

---

## 1. Overview

This milestone extends the existing **Catches** feature; it does not introduce a new feature directory. It adds a single optional relationship — `Catch.lureVariantId` — pointing at `lure_catalog`'s `LureVariant.id`, following exactly the same reference-by-id shape `Catch.fishingSpotId` already uses for `FishingSpot.id` (MFS-009/TD-009).

**Feature boundaries and responsibilities:**

| Feature | Responsibility in this milestone |
|---|---|
| `catches` (extended) | Owns the new `lureVariantId` field: the `Catch` domain model, the `Catches` table column, the migration, `CatchRepository.create`/`update`, `CatchMapper`, and the presentation flows (Add/Edit/Details) that assign, change, remove, and display it. |
| `lure_catalog` (unmodified) | Continues to own `LureVariant` and its read-only `LureCatalogRepository.getEntryById()`, now additionally called by `catches` to resolve a single assigned lure's display details. |
| `personal_tackle_box` (one small, additive touch) | Continues to own ownership data and the grouped browsing screen; `PersonalTackleBoxPage` gains one optional `onSelect` parameter (see [Key Design Decision 3](#key-design-decisions)) so `catches` can reuse it as a picker. Nothing else about this feature changes. |

**Relationship with existing features:** identical in shape to the already-accepted `personal_tackle_box → lure_catalog` relationship from TD-016 — read-only, reference-by-id, no duplicated data, dependency direction strictly one-way (`catches` depends on `lure_catalog` and `personal_tackle_box`; neither depends back on `catches`), consistent with ADR-0006.

**No new repository instances are required anywhere.** `MapScreen` already constructs and holds `CatchRepository`, `CatchPhotoRepository`, `LureCatalogRepository`, `PersonalTackleBoxRepository`, and `TackleBoxPhotoStorage` (from MFS-009/010/012/014, MFS-015, and MFS-016 respectively). This milestone only threads the already-existing `LureCatalogRepository`/`PersonalTackleBoxRepository`/`TackleBoxPhotoStorage` instances through as additional constructor parameters to the Catch presentation widgets that don't currently receive them.

---

## 2. Data Model

### Change to `Catch`

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
       );

  final String id;
  final String fishingSpotId;
  final FishSpecies species;
  final DateTime caughtAt;
  final int? weightGrams;
  final int? lengthMillimeters;
  final String? lureVariantId;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

* **Nullability:** always optional. A catch has zero or exactly one assigned lure (MFS-017 FR-8). `null` means "no lure recorded," not "unknown" or a placeholder value — the same convention already used for `weightGrams`/`lengthMillimeters`.
* **Validation:** a constructor assert mirrors the existing optional-field style on this exact class (non-empty-when-present, matching `LureVariant`/`TackleBoxEntry`'s own `id != ''`-style asserts). Because asserts are stripped in release builds, `CatchRepository` also performs an explicit, non-assert check before insert/update (mirroring the existing `_validateMeasurements` treatment of `weightGrams`/`lengthMillimeters` — see [§4](#4-repository-layer)).
* **No equality/copyWith changes required** beyond what the class already does or does not have; this field is additive to the existing shape.

### Migration strategy

Additive, non-destructive: a new nullable column on the existing `Catches` table. No existing column changes shape or meaning. No data rewrite. Every existing `Catch` row receives `lureVariantId = NULL` automatically, requiring no backfill.

### Backward compatibility

* Every existing call to `CatchRepository.create`/`update` continues to compile and behave identically: `lureVariantId` is a new, optional, named parameter with no explicit default needed (a nullable `String?` parameter's implicit default is already `null`).
* Every existing `Catch` construction elsewhere in the codebase (if any) continues to compile unchanged, since the new field is optional.
* No previously stored data is reinterpreted or migrated; `null` was always the intended "no lure" state and is what every pre-existing row already gets for free.

### Why `LureVariant`, not `TackleBoxEntry`

Resolved at the specification level (MFS-017, Conceptual Relationship) and implemented here exactly as decided: `TackleBoxEntry` rows are permanently deleted on removal (MFS-016 FR-8), while `LureVariant` identifiers are never deleted, only ever retired-and-still-resolvable (MFS-015, Identity). Anchoring `Catch`'s reference to `LureVariant.id` means removing a lure from the Personal Tackle Box, or a future catalog update retiring that variant, can never break, hide, or dangle a catch's historical lure record (MFS-017 FR-6/FR-7). See [Key Design Decision 1](#key-design-decisions) for how this also matches TD-016's own anticipated shape for this exact column.

---

## 3. Database

### Table change

```dart
@DataClassName('CatchEntity')
class Catches extends Table {
  TextColumn get id => text()();

  TextColumn get fishingSpotId =>
      text().references(FishingSpots, #id, onDelete: KeyAction.cascade)();

  TextColumn get species => text()();

  IntColumn get caughtAt => integer()();

  IntColumn get weightGrams =>
      integer().nullable()
      // ignore: recursive_getters
      .check(weightGrams.isNull() | weightGrams.isBiggerThanValue(0))();

  IntColumn get lengthMillimeters => integer().nullable().check(
    // ignore: recursive_getters
    lengthMillimeters.isNull() | lengthMillimeters.isBiggerThanValue(0),
  )();

  TextColumn get lureVariantId =>
      text().nullable().references(
        LureVariants,
        #id,
        onDelete: KeyAction.restrict,
      )();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

`catches_table.dart` gains one new import (`lure_variants_table.dart`), mirroring how `tackle_box_entries_table.dart` already imports it (TD-016).

### Migration version

```text
schema version 5 -> schema version 6
```

```dart
@override
int get schemaVersion => 6;

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
  },
  beforeOpen: (details) async {
    await customStatement('PRAGMA foreign_keys = ON');
  },
);
```

Confirm at implementation time that the live schema version is still `5` before assuming `6` is the correct next number, exactly as every prior TD in this project has required.

### Migration safety

`addColumn` on a nullable column with no default requirement is the safest category of schema change: SQLite's native `ALTER TABLE ... ADD COLUMN` does not rewrite existing rows, and every pre-existing `Catch` row is immediately valid with `lureVariantId = NULL`. No existing table is recreated, dropped, or renamed. Existing Fishing Spots, Catches, Catch Photos, Lure Models, Lure Variants, and Tackle Box Entries must all survive the upgrade unchanged, and the new column must be immediately usable — verified by a migration test mirroring the established `_LegacyAppDatabase` schema-snapshot pattern used by every prior TD (see [§11](#11-testing-strategy)).

### Foreign key strategy

`Catches.lureVariantId → LureVariants.id`, `onDelete: KeyAction.restrict` — see [Key Design Decision 4](#key-design-decisions).

### Delete/update behavior

* Deleting a `Catch` (MFS-012) removes only that catch's own row, exactly as today. It has no effect on `LureVariants`, `TackleBoxEntries`, or any other `Catch` — there is nothing new to cascade, since `Catch` is the referencing side, not the referenced side, of this relationship.
* Deleting a `LureVariant` is already impossible in this application (nothing issues that delete); after this milestone it is additionally blocked at the database layer by this new `restrict` foreign key, on top of the existing one from `TackleBoxEntries` (TD-016).
* Removing a `TackleBoxEntry` (MFS-016's existing remove flow) is entirely unaffected by this milestone: it deletes a `TackleBoxEntries` row and its photo file, neither of which `Catches.lureVariantId` references at all.
* Updating a `Catch`'s `lureVariantId` (assign/change/remove) is a plain column update through `CatchRepository.update`, no different in kind from updating `weightGrams` or `lengthMillimeters` today.

### Indexes

None added — see [Key Design Decision 5](#key-design-decisions).

---

## 4. Repository Layer

### Responsibilities and ownership

| Repository | Owns, in this milestone |
|---|---|
| `CatchRepository` (`features/catches`) | Storing and retrieving the `lureVariantId` reference itself as a plain field, alongside every other `Catch` field. Nothing more. |
| `LureCatalogRepository` (`features/lure_catalog`, unmodified) | Resolving a `lureVariantId` into full display details (`LureCatalogEntry`), via its already-existing, already-public `getEntryById()`. |
| `PersonalTackleBoxRepository` (`features/personal_tackle_box`, unmodified) | Producing the list of currently-owned lures available to assign, via its already-existing `getAll()`, surfaced through the reused `PersonalTackleBoxPage` picker. |

`CatchRepository` gains no new methods and no new imports of `lure_catalog`'s or `personal_tackle_box`'s table types. It only gains a new optional parameter on two existing methods:

```dart
Future<Catch> create({
  required String fishingSpotId,
  required FishSpecies species,
  required DateTime caughtAt,
  int? weightGrams,
  int? lengthMillimeters,
  String? lureVariantId,
});

Future<Catch> update({
  required Catch catchModel,
  required FishSpecies species,
  required DateTime caughtAt,
  int? weightGrams,
  int? lengthMillimeters,
  String? lureVariantId,
});
```

`update` replaces the previous `lureVariantId` value entirely with whatever is passed (including `null`, to remove an assignment) — the same "full replace, not a partial patch" behavior `update` already has for every other field.

### Read/write flow

* **Write:** `create`/`update` validate `lureVariantId` (non-empty when provided; see [§5](#5-mapping-layer)), construct the domain `Catch` including it, and insert/replace through the existing mapper-and-companion flow — no new step type, just one more field flowing through the same path `weightGrams`/`lengthMillimeters` already use.
* **Read:** `getByFishingSpotId`/`getById` require no changes to their query shape at all. Both already `select(_database.catches)` and map every column through `CatchMapper.toDomain` — the new `lureVariantId` column rides along automatically once the mapper is updated. No join is added to either method, so the catch list (which never displays lure information — FR-5) pays no query-shape cost from this milestone.

### Resolving the assigned lure

Not a `CatchRepository` responsibility. Presentation code (Catch Details, Edit Catch) calls `LureCatalogRepository.getEntryById(catchModel.lureVariantId!)` directly, guarded by a `lureVariantId != null` check, whenever it needs to show what the reference points to. See [Key Design Decision 2](#key-design-decisions) for why this does not need to live inside `CatchRepository` or introduce a join there.

### Avoiding feature coupling

`catches` depends on `lure_catalog` (one already-existing, read-only method) and on `personal_tackle_box` (one already-existing, read-only screen) — the same one-way dependency shape `personal_tackle_box` already has on `lure_catalog`. Neither `lure_catalog` nor `personal_tackle_box` gains any dependency on `catches`; `PersonalTackleBoxPage`'s new `onSelect` parameter is generic (a plain callback), so that file still does not import anything from `features/catches`.

---

## 5. Mapping Layer

### Entity ↔ domain changes

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
    createdAt: catchModel.createdAt.millisecondsSinceEpoch,
    updatedAt: catchModel.updatedAt.millisecondsSinceEpoch,
  );
}
```

### Nullable mapping

`row.lureVariantId` (a nullable Drift column) passes straight through to `Catch.lureVariantId` with no lookup or transformation — unlike `species`, which requires a stable-string-to-enum conversion, `lureVariantId` is already a plain opaque string identifier on both sides, exactly like `fishingSpotId`. `Value(catchModel.lureVariantId)` on the way back correctly writes `NULL` when the field is absent, mirroring the existing `weightGrams`/`lengthMillimeters` pattern.

### Validation

No new validation logic in the mapper — it is a pure, direct passthrough, consistent with how the mapper already treats every other nullable field. Validation (non-empty-when-present) lives in the domain constructor's assert and in `CatchRepository`'s explicit release-safe check, not in the mapper.

---

## 6. Add Catch Flow

`AddCatchBottomSheet` gains two new required constructor parameters — `PersonalTackleBoxRepository personalTackleBoxRepository` and `TackleBoxPhotoStorage personalTackleBoxPhotoStorage` — needed only to construct the pushed picker screen. It does not need a `LureCatalogRepository`: the picker already returns a fully-resolved `TackleBoxItem` (including its `catalogEntry`), so there is nothing left to resolve.

* **Picker launch:** a new, clearly labeled "select a lure" affordance (alongside weight/length) pushes `PersonalTackleBoxPage` as a normal page, with `onSelect` wired to pop the picker with the tapped item:

  ```dart
  final selected = await Navigator.of(context).push<TackleBoxItem>(
    MaterialPageRoute(
      builder: (context) => PersonalTackleBoxPage(
        repository: widget.personalTackleBoxRepository,
        photoStorage: widget.personalTackleBoxPhotoStorage,
        onSelect: (item) => Navigator.of(context).pop(item),
      ),
    ),
  );
  ```

* **Picker return:** a non-null `TackleBoxItem` is stored in new local state, `TackleBoxItem? _selectedLure`, and its `catalogEntry` is used immediately to render the assigned-lure row (via the new shared widget, [§1](#1-overview)) — no further repository call needed.
* **Save flow:** `CatchRepository.create(..., lureVariantId: _selectedLure?.catalogEntry.id)`. If `_selectedLure` is `null` (never picked, or explicitly cleared), the catch saves with no lure, exactly as it does today with no change to this milestone.
* **Cancel behavior:** backing out of the picker (system back or its app bar back button) returns `null` from the `push`, leaving `_selectedLure` unchanged — identical in shape to cancelling the existing date/time pickers.
* **Empty tackle box behavior:** requires no new code in `catches`. The pushed `PersonalTackleBoxPage` is completely unmodified apart from the new optional parameter, so its own existing empty state (MFS-016 — a clear message plus a path onward to the Lure Catalog) is shown automatically when the user has no owned lures yet. This satisfies MFS-017's "explicit call-to-action" requirement for the empty-tackle-box case with zero new UI.

---

## 7. Edit Catch Flow

`EditCatchBottomSheet` gains three new required constructor parameters: `LureCatalogRepository lureCatalogRepository` (to resolve the currently-assigned lure), and the same `PersonalTackleBoxRepository`/`TackleBoxPhotoStorage` pair Add Catch gains (to launch the picker for changing it).

* **Loading current assignment:** in `initState`, if `widget.catchModel.lureVariantId != null`, kick off an async `lureCatalogRepository.getEntryById(...)` call, following the same independent-async-section pattern this file already uses for photo loading (`_isLoadingPhotos`/`_photoLoadError`). New state: `LureCatalogEntry? _selectedLureEntry`, `bool _isLoadingLure`, `String? _lureLoadError`. The loading indicator is scoped to just the lure row; the rest of the form (species, date, time, weight, length, photos) is usable immediately, exactly as today.
* **Replacing:** tapping "change" pushes the same picker described in [§6](#6-add-catch-flow). A returned `TackleBoxItem` replaces `_selectedLureEntry` with `pickedItem.catalogEntry` directly — no further resolve call, since the picker already carries full catalog details.
* **Removing:** a clear "remove" affordance sets `_selectedLureEntry = null`.
* **Validation:** none beyond what already exists. The field remains fully optional; there is no new required-field rule to add to the existing validator set.
* **Save:** `catchRepository.update(..., lureVariantId: _selectedLureEntry?.id)`. Because `update` fully replaces the value (see [§4](#4-repository-layer)), removing an assignment (`_selectedLureEntry == null`) correctly clears the stored `lureVariantId` to `NULL`.

---

## 8. Catch Details

`CatchDetailsPage` gains one new required constructor parameter, `LureCatalogRepository lureCatalogRepository`.

* **Resolving assigned lure:** as part of this page's existing load sequence (alongside `_loadPhotos()`), if `_catchModel.lureVariantId != null`, resolve via `lureCatalogRepository.getEntryById(...)`. New state mirrors the existing photo-loading siblings exactly: `LureCatalogEntry? _assignedLure`, `bool _isLoadingLure`, `String? _lureLoadError`.
* **Fallback handling:**
  * `lureVariantId == null` — render nothing for the lure row, consistent with how `weightGrams`/`lengthMillimeters` are already conditionally omitted via `_buildInfoRow` (no empty placeholder for an absent optional field).
  * `lureVariantId != null` but resolution returns `null` (an unresolved reference) — render a small, clear "lure details unavailable" fallback row instead of silently omitting it. Because a stored id genuinely exists in this case, silent omission would look like unexplained data loss; MFS-016 established the same "show a clear fallback, don't hide it" choice for its own "referenced catalog variant not found" case.
* **Image priority:** MFS-017 requires only identifying text (manufacturer, model, distinguishing detail) at minimum. This page resolves the assigned lure through `LureCatalogRepository` alone, which has no access to a personal tackle-box photo (`PersonalTackleBoxRepository.getById` is keyed by `TackleBoxEntry.id`, not `lureVariantId`, and `isOwned()` returns only a `bool`). Catch Details therefore shows the **catalog image only** (`LureCatalogEntry.effectiveImageReference`), with the existing placeholder fallback when absent — it does not attempt to show the personal photo.

  **Future Improvement — personal photo in Catch Details:** displaying the user's own Personal Tackle Box photo here instead of (or alongside) the catalog image is intentionally deferred, not overlooked. It is out of scope for MFS-017. Doing so would require an additional read path — `PersonalTackleBoxRepository` currently has no way to look up a `TackleBoxEntry` by `lureVariantId` (only `isOwned()`, which returns a `bool`, and `getById()`, which is keyed by `TackleBoxEntry.id`) — so it is not something this design's current repository surface already supports. This does not change the current implementation plan; it is noted here so it is not rediscovered as a gap later.
* **Retired variants:** resolved and displayed identically to an active variant — no special-casing, because `LureCatalogRepository.getEntryById()` never filters `retiredAt` (unchanged, established behavior from TD-015).
* **Unresolved references:** covered under Fallback handling above.

The shared assigned-lure-row widget introduced in [§1](#1-overview) is reused here in its read-only mode (no change/remove affordances), consistent with `CatchDetailsPage`'s existing read-only principle (MFS-014 FR-10).

---

## 9. Error Handling

| Scenario | Behavior |
|---|---|
| Missing/unresolvable `LureVariant` | Not expected to occur: two independent `restrict` foreign keys (from `TackleBoxEntries` and now `Catches`) make deleting a referenced `LureVariant` structurally impossible. Handled defensively anyway — `getEntryById()` returns `null`, and the calling screen shows the "lure details unavailable" fallback rather than crashing (see [§8](#8-catch-details)). |
| Referenced `TackleBoxEntry` deleted (lure removed from tackle box) | Not applicable to `Catch` at all — `Catch` never references `TackleBoxEntry`, only the stable `LureVariant` (see [Key Design Decision 1](#key-design-decisions)). Removing a `TackleBoxEntry` cannot affect any catch's stored reference or its resolution. |
| Retired catalog variant | No special-casing anywhere in this feature — resolved and displayed identically to an active variant, exactly as `LureCatalogRepository.getEntryById()` already guarantees (MFS-015/MFS-016 precedent). |
| Migration failure | Mitigated by the migration being purely additive (nullable column, no rewrite) and verified by a schema-snapshot migration test before release, consistent with every prior schema change in this project (see [§11](#11-testing-strategy)). |
| Save failure while an assignment is pending (Add or Edit Catch) | No new handling required: the picked/changed/removed lure lives in the same in-memory form state as every other field (species, date, weight, length), so the existing Add/Edit Catch failure handling (form stays open, values preserved, retry available) already covers it unchanged. |
| Lure-resolution failure during Edit Catch's initial load | The lure row shows its own error/fallback state (mirroring the photo-loading error state already in this file); the rest of the form remains fully usable and saveable regardless. |

---

## 10. Performance

**Expected query count:**

* Add Catch: unchanged (`create` = one insert) unless the user opens the picker, which adds exactly one `PersonalTackleBoxRepository.getAll()` — already a single joined query (TD-016).
* Edit Catch: unchanged existing queries, plus exactly one `LureCatalogRepository.getEntryById()` only when the catch already has an assigned lure, plus one more `getAll()` only if the user opens the picker to change it.
* Catch Details: unchanged existing queries (photos), plus exactly one `getEntryById()` only when the catch has an assigned lure.
* Catch list (`getByFishingSpotId`): **zero** additional queries or columns of interest — FR-5 means no lure information is ever shown there, so browsing a fishing spot's catches has no performance impact from this milestone at all.

**Joins:** none added inside `catches`' own repository. Every join this milestone relies on already exists inside `LureCatalogRepository`/`PersonalTackleBoxRepository`, reused unchanged.

**Caching:** none needed or added. Every resolution happens for exactly one currently-open screen at a time, never in a list or a loop, so there is no repeated-lookup pattern to cache away.

**Avoiding unnecessary repository calls:** deliberately not resolving a catch's lure inside `getByFishingSpotId`/`getById` — doing so would force every catch-list load to pay for a join it never displays. Resolution only happens on the two screens that actually show it (Catch Details, Edit Catch), and only when `lureVariantId` is non-null.

**Avoiding redundant resolution within a single screen's lifetime:** once a `LureCatalogEntry` has been obtained for the currently assigned/selected lure — whether by an initial `getEntryById()` resolve (Edit Catch's existing assignment, Catch Details) or by the picker directly returning a `TackleBoxItem` (Add Catch, or Edit Catch's "change" action) — that object must be reused in memory for the remainder of the screen's lifetime, not re-fetched. Concretely: after the picker returns in Edit Catch's "change" flow, the returned `pickedItem.catalogEntry` directly replaces `_selectedLureEntry` (see [§7](#7-edit-catch-flow)); no additional `getEntryById()` call is made to re-resolve the very entry the picker just handed over. The same applies to Add Catch's `_selectedLure`. Each screen resolves its assigned lure at most once per pick/load event, never repeatedly.

**Avoiding premature optimization:** the `Catches.lureVariantId` index is explicitly deferred (see [Key Design Decision 5](#key-design-decisions)) since no query in this milestone needs it.

---

## 11. Testing Strategy

Follows the same layered testing philosophy as every prior TD in this project: domain tests for construction/assertions, a database test for the migration and constraints, a mapper test for round-tripping, repository tests for behavior, widget tests for the presentation surfaces, and a physical-device pass at the end.

**Domain** (`test/features/catches/domain/catch_test.dart`, extended):
constructs successfully with a `lureVariantId`; constructs successfully with no `lureVariantId`; rejects an empty-string `lureVariantId`.

**Database/migration** (extending the catches migration-test area, mirroring the established `_LegacyAppDatabase` schema-snapshot pattern used by every prior TD):
migration from schema 5 succeeds; existing Fishing Spot/Catch/Catch Photo/Lure Model/Lure Variant/Tackle Box Entry rows survive; the new `lureVariantId` column is immediately usable after upgrade; the foreign key rejects an unknown `lureVariantId`; attempting to delete a referenced `LureVariant` is rejected by `KeyAction.restrict` (exercised directly at the SQL layer, mirroring `tackle_box_entries_database_test.dart`'s equivalent test).

**Mapper** (`catch_mapper_test.dart`, extended):
round-trips a non-null `lureVariantId`; round-trips a `null` `lureVariantId`.

**Repository** (`catch_repository_test.dart`, extended):
`create` with a `lureVariantId` persists it; `create` with no `lureVariantId` stores `null`; `update` can assign a `lureVariantId` to a catch that had none; `update` can change an existing `lureVariantId` to a different one; `update` can clear an existing `lureVariantId` to `null`; `getByFishingSpotId`/`getById` return the correct `lureVariantId` in every case above.

**Widget — Add Catch** (`add_catch_bottom_sheet_test.dart`, extended):
selecting a lure via the picker before saving assigns it to the created catch; saving without ever opening the picker still succeeds with no lure assigned; cancelling out of the picker leaves the form's prior selection (none) unchanged.

**Widget — Edit Catch** (`edit_catch_bottom_sheet_test.dart`, extended):
opening a catch with an existing assignment shows it resolved; changing the assignment via the picker updates the saved catch; removing the assignment clears it on save; a lure-resolution failure shows the fallback state without blocking the rest of the form or the save action.

**Widget — Catch Details** (`catch_details_page_test.dart`, extended):
displays the assigned lure's details when present; renders cleanly with no lure row when absent; a retired assigned variant still displays normally; an unresolvable assigned `lureVariantId` shows the "unavailable" fallback rather than crashing or silently omitting the row.

**Widget — Personal Tackle Box picker reuse** (`personal_tackle_box_page_test.dart`, extended):
providing `onSelect` causes tapping a row to invoke it instead of navigating to `OwnedEntryDetailPage`; omitting `onSelect` (every existing test in this file) continues to behave exactly as before — a regression safety net for [Key Design Decision 3](#key-design-decisions).

**Integration/physical Android testing:**
assign a lure at creation; assign, change, and remove a lure during edit; verify the assignment persists across an application restart and across the schema 5→6 migration on a pre-existing installation; verify that removing a lure from the Personal Tackle Box leaves a previously-assigned catch's display unchanged; verify a retired catalog variant still displays correctly on an already-logged catch; verify the empty-tackle-box picker state; verify full offline/airplane-mode operation throughout.

---

## 12. Risks

| Risk | Category | Mitigation |
|---|---|---|
| Coupling `catches` to `lure_catalog` and `personal_tackle_box` could erode feature boundaries over time. | Architectural | The coupling is strictly read-only and reference-by-id only (one existing method call, one existing screen reused via one generic optional parameter) — the same shape already accepted for `personal_tackle_box → lure_catalog` in TD-016. Neither dependency runs in the opposite direction. |
| This is the project's first `addColumn`-style migration; an unforeseen Drift/SQLite interaction could behave differently from the `createTable` migrations proven four times already. | Migration | The change is the safest possible category (nullable column, no default, no rewrite). Verified with a dedicated schema-snapshot migration test before implementation is considered complete, plus a physical-device upgrade test against a real pre-existing installation. |
| Introducing a second layer of navigation (Add/Edit Catch → tackle box picker → possibly onward to the Lure Catalog if empty) could feel deep or nested. | UX | The step is entirely optional and skippable at every level, and reuses an already-familiar screen (Personal Tackle Box) rather than introducing a new one — no additional screen for the user to learn. |
| Edit Catch's async resolve step for an existing assignment introduces a loading moment not present for other fields. | UX | Scoped to just the lure row, using the same independent-loading-state pattern already accepted for photo loading in the same bottom sheet — the rest of the form remains immediately usable. |
| Users may expect removing a lure from the Personal Tackle Box to also clear it from past catches, and be surprised that it does not. | Product | This is the explicit, reasoned, documented design decision in MFS-017 (historical stability) — surfaced here so it is not rediscovered as a bug. Any clarifying UI copy is a presentation-polish concern outside this document's scope. |

---

## 13. Future Compatibility

* **Lure-Based Catch Statistics** (the roadmap's next named candidate) — needs to query/group `Catches` by `lureVariantId`. Addable as a new repository method plus, at that point, the `@TableIndex` deliberately deferred in this document ([Key Design Decision 5](#key-design-decisions)) — no remodel of this milestone's column.
* **Filtering catches by assigned lure** — same shape as above: a new query against the already-existing column, no schema change beyond the same deferred index.
* **Smart lure/fishing recommendations** — builds on the statistics above; nothing in this design blocks it, since the underlying reference data (which lure caught which fish) already exists once this milestone ships.
* **Showing lure information in the catch list** (explicitly out of scope for this milestone, FR-5) — addable later without a schema change, since `lureVariantId` is already present on every `Catch` returned by `getByFishingSpotId`; only the list item widget would need to opt in to displaying it, and only after resolving it (a new N+1 consideration to design deliberately at that time, unlike the single-screen resolutions in this document).
* **Cloud synchronization** — nothing about this design blocks it. `lureVariantId` is a plain nullable string column, structurally identical to `fishingSpotId`, and the existing repository-hides-the-data-source principle (ADR-0001, ADR-0005) applies to it exactly as it does to every other `Catch` field. Additionally, because `Catch` stores `LureVariant.id` — a globally stable catalog identifier, never reassigned and never derived from device-local state (MFS-015, Identity) — rather than a locally-generated `TackleBoxEntry.id`, this reference is already in the right shape for future cross-device sync: the same lure assignment would resolve consistently on any device once the shared Lure Catalog itself is synchronized, with no per-device remapping step required.
* **Multiple lures per catch** — the one enhancement this design does **not** accommodate without a remodel. A single nullable column can only ever represent zero-or-one; supporting more than one lure per catch would require moving the relationship into a child table (e.g. `catch_lure_assignments(catchId, lureVariantId)`), similar in shape to how `CatchPhotos` already models "many children per catch." This is called out explicitly, per MFS-017 FR-8's deliberate one-lure-per-catch scope, so it is not mistaken for something this design already supports.

---

## Dependencies

No new external package dependencies. This milestone reuses, unchanged:

* Flutter, Dart
* Drift (per ADR-0005)
* The existing Repository pattern, feature-first structure, and manual dependency construction (ADR-0001, ADR-0003, ADR-0006)
* The existing `Catch` domain model, `CatchRepository`, `CatchMapper`, and `Catches` table (MFS-009/TD-009)
* `LureCatalogRepository.getEntryById()` (MFS-015/TD-015), consumed read-only, unmodified
* `PersonalTackleBoxRepository.getAll()` and `PersonalTackleBoxPage` (MFS-016/TD-016), consumed read-only; the page gains one new optional parameter

`flutter_riverpod` is not used by this feature, for the same reasons documented in TD-015/TD-016.

---

## Expected Files To Create

```text
lib/features/catches/presentation/widgets/assigned_lure_row.dart
```

A small, shared, stateless widget rendering an assigned lure's identifying details (or an "unassigned"/"unavailable" state), with optional change/remove affordances — used read-write by Add/Edit Catch and read-only by Catch Details, avoiding duplicating the same small layout across three files.

This widget must remain a **pure presentation component**:

* it renders the assigned / unassigned / unavailable states it is given, and nothing else;
* it exposes callbacks (e.g. "change tapped," "remove tapped") for its parent to react to — it never decides what happens when they fire;
* it contains no business logic (no validation, no interpretation of what a `null` vs. an unresolved lure means beyond rendering the state it was told);
* it contains no repository access of any kind — it is handed already-resolved data (a `LureCatalogEntry?` plus a simple state flag), never a repository or an id to resolve itself;
* it contains no navigation logic — it never pushes the picker, never pops a route, and never calls `Navigator` itself.

Add Catch, Edit Catch, and Catch Details — the three parent screens — own all behavior: launching the picker, resolving a `lureVariantId`, deciding what "change"/"remove" does, and saving. The shared widget only displays what it is given and reports taps upward.

Plus mirrored/extended test files under `test/features/catches/...` per [§11](#11-testing-strategy).

## Expected Files To Modify

```text
lib/core/database/app_database.dart                                    (schema 5 -> 6, addColumn migration)
lib/features/catches/domain/catch.dart                                  (add lureVariantId)
lib/features/catches/data/local/catches_table.dart                      (add lureVariantId column + FK)
lib/features/catches/data/catch_mapper.dart                             (map lureVariantId)
lib/features/catches/data/catch_repository.dart                         (create/update gain lureVariantId + validation)
lib/features/catches/presentation/widgets/add_catch_bottom_sheet.dart   (picker + save)
lib/features/catches/presentation/widgets/edit_catch_bottom_sheet.dart  (resolve/change/remove + save)
lib/features/catches/presentation/widgets/catch_details_page.dart       (resolve + display)
lib/features/personal_tackle_box/presentation/widgets/personal_tackle_box_page.dart  (one new optional onSelect parameter)
lib/features/map/presentation/map_screen.dart                           (thread existing repositories to Catch widgets)
lib/features/fishing_spots/presentation/widgets/fishing_spot_details_bottom_sheet.dart  (thread existing repositories to Catch widgets)
```

Modify generated Drift files only through code generation.

---

## Implementation Notes

To be completed during implementation, following the established convention of recording any deviation from this document here, with justification.

---

## Validation

```bash
dart format .
flutter analyze
flutter test
```

All must pass. Review generated Drift changes. Confirm the schema version and migration are correct against the repository's actual current state before implementing, in case it has moved past `5` since this document was written.

---

## Definition of Done

* The implementation satisfies all requirements in MFS-017.
* The implementation follows TD-017, or documents and justifies each deviation.
* A catch can be created with no assigned lure, exactly as today.
* A catch can be created with exactly one assigned lure, chosen only from the current Personal Tackle Box.
* An existing catch's lure assignment can be added, changed, or removed through Edit Catch.
* The Lure Catalog is never directly reachable from the assignment flow.
* Catch Details displays the assigned lure's details when present, and renders cleanly when absent.
* The catch list is unchanged.
* Removing a lure from the Personal Tackle Box does not alter, hide, or break any catch previously assigned that lure.
* A retired Lure Catalog variant assigned to a catch remains fully resolvable and correctly displayed.
* Deleting a catch has no effect on the Personal Tackle Box, the Lure Catalog, or any other catch.
* The Lure Catalog feature and Personal Tackle Box feature are functionally and structurally unchanged apart from `PersonalTackleBoxPage`'s one new optional parameter.
* The migration from schema version 5 succeeds and preserves all existing data.
* `flutter analyze` passes.
* `flutter test` passes.
* Architecture review is completed.
* Physical Android testing is completed.
