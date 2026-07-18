# TD-016 — Personal Tackle Box Foundation

## Status

Draft

## Goal

Implement the `TackleBoxEntry` domain/persistence layer, personal photo handling (reusing the MFS-013/TD-013 architecture, not a new image system), and the grouped-browse / add / owned-entry-detail / remove presentation flow on top of the existing, unmodified read-only Lure Catalog (MFS-015/TD-015), fully satisfying MFS-016.

The implementation shall satisfy MFS-016.

---

## Scope

Implement:

- `TackleBoxEntry` domain model and `TackleBoxItem` joined read-model
- `TackleBoxEntries` Drift table, with a unique constraint on `lureVariantId`
- database migration (schema 4 → 5)
- a concrete, feature-owned `PersonalTackleBoxRepository`
- application-owned personal photo storage (`TackleBoxPhotoStorage`), reusing `CatchPhotoStorage`'s processing parameters and atomic-write pattern
- a small feature-local photo source picker (camera / gallery / skip)
- the "Add to Tackle Box" action, reachable from the Lure Catalog's variant details view without modifying that feature's domain or data layer
- the grouped (manufacturer → model → variant) Personal Tackle Box browsing screen
- the Owned Entry Detail screen (catalog details + personal photo + Remove action)
- the remove flow, with confirmation and photo cleanup
- loading, empty, and error states
- accessibility labeling
- tests

Do **not** implement:

- quantity, price, condition, or notes fields
- editing/replacing a photo on an already-saved entry, beyond the narrow same-operation retry described in [Error Handling](#9-error-handling)
- search or filtering within the Personal Tackle Box
- assigning a lure to a catch (MFS-017)
- statistics or recommendations
- cloud synchronization
- any change to `lure_catalog`'s domain model, tables, repository, or read-only guarantees
- Riverpod, repository interfaces, DAO/service/use-case layers, reactive database streams (`watch()`)
- broader navigation redesign (drawer, bottom navigation, tabs)

---

## Key Design Decisions

This section answers the questions most likely to be raised in review, before the detailed sections implement them.

**1. The Lure Catalog's presentation layer gains two small, generic, optional parameters — nothing else about it changes.**
MFS-016 requires the "Add to Tackle Box" action to be reachable from viewing a color variant (its own Navigation diagram shows the action directly after "Select a color variant"), while also requiring `lure_catalog` to remain untouched and to never depend on `personal_tackle_box`. Both are satisfiable together only if the touch is generic: `LureDetailsPage` gains one optional `actionsBuilder` parameter (default `null`, i.e. today's exact behavior), threaded through from `LureCatalogListPage`. Neither file imports anything from `personal_tackle_box`; the builder itself is constructed by whoever pushes `LureCatalogListPage` (currently `MapScreen`, per TD-015's temporary entry point), exactly the same shape TD-015 already used to hang its own entry point off `MapScreen`. **This is the one deliberate exception to "untouched" and should be explicitly confirmed at review** — the alternative (no touch at all) would leave FR-3 with no way to be wired up.

**2. One feature-owned join, not a dependency on `LureCatalogRepository`'s instance methods.**
`PersonalTackleBoxRepository` joins `TackleBoxEntries` ⨝ `LureVariants` ⨝ `LureModels` directly, reusing `lure_catalog`'s already-public `LureCatalogMapper.entryFromRows` for the catalog portion. Calling `LureCatalogRepository.getEntryById()` once per tackle box row would be an N+1 query pattern; a direct three-table join keeps every screen at one query, consistent with the precedent `LureCatalogRepository.browse()`/`getEntryById()` already established.

**3. Grouping is a presentation-only concern.** The repository returns one flat list sorted manufacturer → model → variant (the same sort `LureCatalogRepository.browse()` already uses). The browsing screen groups it into sections with a single pass detecting boundary changes in the already-sorted list — no `GROUP BY`, no persisted grouping entity, per MFS-016's Conceptual Data Model.

**4. Duplicate prevention is a database unique constraint, not just an app-level check.** `TackleBoxEntries.lureVariantId` carries a table-level `uniqueKeys` constraint, satisfying MFS-016 FR-7's "independently of the UI" requirement and closing the race a UI-only check cannot.

**5. The foreign key to `LureVariants` uses `KeyAction.restrict`, not `cascade`.** Every existing catalog foreign key in this codebase (`LureVariants.lureModelId → LureModels.id`) cascades, but nothing in the codebase ever deletes a `LureModel` or `LureVariant` — retirement is a flag (`retiredAt`), never a `DELETE`. If that ever changed, a cascading foreign key would silently destroy a user's ownership record as a side effect of a catalog change; `restrict` instead makes that impossible by construction and forces any future catalog-deletion feature to handle tackle box cleanup explicitly, rather than inheriting silent cascade behavior it may not have intended.

**6. A small feature-local photo picker, not a reused `catch_photos` class.** `CatchPhotoPicker` supports multi-select and up-to-5 capacity math that a single-photo entry never needs, and importing it would create a `personal_tackle_box → catch_photos` dependency that MFS-016 does not call for (the declared dependency is `personal_tackle_box → lure_catalog` only). `TackleBoxPhotoPicker` mirrors the same package (`image_picker`), the same sealed-outcome pattern, and the same permission/cancellation handling — reusing the *architecture*, per MFS-016, without reusing or duplicating another feature's public class.

**7. One photo, one flat path — no per-entry subdirectory.** `CatchPhotoStorage` uses `<root>/catch_photos/<catch-id>/<photo-id>.jpg` because a Catch can hold up to five photos. A `TackleBoxEntry` holds at most one, so `TackleBoxPhotoStorage` uses `<root>/tackle_box_photos/<tackle-box-entry-id>.jpg` directly — no subdirectory, no photo-id filename, because there is nothing to disambiguate.

---

## 1. Feature Overview

Personal Tackle Box is implemented as its own feature, `lib/features/personal_tackle_box/`, depending on `lure_catalog` (for `LureVariant`/`LureCatalogEntry`/`LureCatalogMapper`/`LureImage`) and on nothing else. It owns a new Drift table (`TackleBoxEntries`), a personal-photo storage component mirroring `CatchPhotoStorage`, a concrete repository, and three presentation surfaces: a grouped browsing screen, an owned-entry detail screen, and a small add flow triggered from the Lure Catalog's existing details view.

Every capability is local-only: no network calls, no cloud fields, no authentication. The feature follows the same construction, ownership, and layering conventions as every other feature in this codebase — concrete repository, no interface, Drift accessed directly, manual dependency construction, Material 3, no unnecessary abstraction layers.

---

## 2. Folder Structure

```text
lib/features/personal_tackle_box/
  domain/
    tackle_box_entry.dart
    tackle_box_item.dart
  data/
    local/
      tackle_box_entries_table.dart
    storage/
      tackle_box_photo_storage.dart
    personal_tackle_box_mapper.dart
    personal_tackle_box_repository.dart
  presentation/
    widgets/
      tackle_box_photo_picker.dart
      add_to_tackle_box_action.dart
      personal_tackle_box_page.dart
      owned_entry_detail_page.dart
```

No `domain/value_objects/`, no `presentation/providers/`, no `data/dao/` — nothing in this feature needs them. Exact widget file separation may be adjusted if a smaller structure is clearer, consistent with the same allowance given in TD-013 and TD-015.

---

## 3. Domain Layer

### TackleBoxEntry

```dart
final class TackleBoxEntry {
  const TackleBoxEntry({
    required this.id,
    required this.lureVariantId,
    required this.addedAt,
    required this.createdAt,
    required this.updatedAt,
    this.personalPhotoRelativePath,
  }) : assert(id != '', 'id must not be empty'),
       assert(lureVariantId != '', 'lureVariantId must not be empty');

  final String id;
  final String lureVariantId;
  final String? personalPhotoRelativePath;
  final DateTime addedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

Requirements:

- shall not depend on Flutter or Drift
- shall not contain image bytes or an absolute device path
- shall not contain quantity, price, condition, or notes fields (MFS-016)
- `addedAt` is set once, at creation, and never changes — it represents "owned since," independent of `updatedAt`, which may later change if [`attachPhoto`](#attachphoto-narrow-retry-only) succeeds after an initial photo failure

### TackleBoxItem

The joined read-model returned by every browse/get query — mirrors `LureCatalogEntry`'s role in `lure_catalog`.

```dart
final class TackleBoxItem {
  const TackleBoxItem({required this.entry, required this.catalogEntry});

  final TackleBoxEntry entry;
  final LureCatalogEntry catalogEntry;

  String get id => entry.id;
  String? get personalPhotoRelativePath => entry.personalPhotoRelativePath;
}
```

`catalogEntry` is `lure_catalog`'s own `LureCatalogEntry` — reused directly, not duplicated. This is the concrete expression of MFS-016's "reference, not copy" data rule: nothing in `personal_tackle_box` ever stores manufacturer, model name, color, or any other catalog field itself.

### No value objects

Neither type needs a value object in this milestone: `lureVariantId` is a plain opaque `String` (identical treatment to `LureVariant.id` and `LureVariant.lureModelId` in `lure_catalog`), and `personalPhotoRelativePath` is a plain nullable `String`, identical in shape to `CatchPhoto.relativePath`. Introducing wrapper types here would not enforce anything the assertions and the database constraints don't already enforce.

### Repository "interface"

None. `PersonalTackleBoxRepository` is a concrete class, constructed manually — consistent with `FishingSpotRepository`, `CatchRepository`, `CatchPhotoRepository`, and `LureCatalogRepository`, none of which have an interface.

### Business rules enforced by the domain/repository layer

- A `LureVariant` can back at most one `TackleBoxEntry` (FR-7) — enforced at both the repository (pre-check) and database (`uniqueKeys`) layers; see [Duplicate Prevention](#duplicate-prevention).
- Adding never requires a photo; skipping is a first-class, fully valid outcome (FR-3/FR-4).
- Removing an entry always removes its personal photo file, when one exists (FR-8/FR-9 of MFS-016's numbering — see MFS-016 §Data Requirements).
- A retired catalog variant is resolved by `personal_tackle_box` exactly like an active one — no `retiredAt` filtering anywhere in this feature (FR-9).

---

## 4. Data Layer

### TackleBoxEntries table

```text
lib/features/personal_tackle_box/data/local/tackle_box_entries_table.dart
```

```dart
import 'package:drift/drift.dart';

import 'package:fishing_app/features/lure_catalog/data/local/lure_variants_table.dart';

@DataClassName('TackleBoxEntryEntity')
class TackleBoxEntries extends Table {
  TextColumn get id => text()();

  TextColumn get lureVariantId =>
      text().references(LureVariants, #id, onDelete: KeyAction.restrict)();

  TextColumn get personalPhotoRelativePath => text().nullable()();

  IntColumn get addedAt => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {lureVariantId},
  ];
}
```

| Decision | Why |
|---|---|
| `id` primary key, opaque runtime-generated UUID | Unlike catalog ids (authored literals for seed matching, see TD-015), `TackleBoxEntry` is user-created runtime data — generated the same way `CatchPhoto.id` is, via `Uuid().v4()` inside the repository. |
| `lureVariantId` references `LureVariants.id`, `onDelete: KeyAction.restrict` | See [Key Design Decision 5](#key-design-decisions). |
| `uniqueKeys = [{lureVariantId}]` | Enforces FR-7 at the database layer. A `UNIQUE` constraint creates its own index in SQLite, so no separate `@TableIndex` is needed for lookups by `lureVariantId` — unlike a plain (non-unique) foreign key column, which SQLite does not auto-index. |
| `personalPhotoRelativePath` nullable `TEXT` | No photo is a normal, expected state (MFS-016). No image blob column — mirrors `CatchPhotos.relativePath`. |
| `addedAt`/`createdAt`/`updatedAt` as `IntColumn` (epoch ms) | Matches the existing convention used by every other table in this database (`LureModels`, `LureVariants`, etc.), not `DateTimeColumn`. |
| No `seedVersion`, no `retiredAt` | Those are catalog seed-lifecycle bookkeeping specific to shared reference data (TD-015). A `TackleBoxEntry` is user data with no seed source and nothing to retire. |

No `@TableIndex` is declared beyond the automatic one from `uniqueKeys`. Nothing in this feature queries `TackleBoxEntries` by any other column.

### Schema version

```text
schema version 4 -> schema version 5
```

Register in `AppDatabase`:

```dart
@DriftDatabase(
  tables: [
    FishingSpots,
    Catches,
    CatchPhotos,
    LureModels,
    LureVariants,
    TackleBoxEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  ...
  @override
  int get schemaVersion => 5;

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
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
```

Confirm the actual current schema version in `lib/core/database/app_database.dart` before implementing — it was `4` at the time this document was written.

Migration requirements:

- preserve all existing Fishing Spots, Catches, Catch Photos, Lure Models, and Lure Variants
- create only `TackleBoxEntries`
- do not rebuild or modify any existing table
- migration from schema version 4 succeeds
- the migration creates the empty table only — there is no seed data to reconcile (unlike `lure_catalog`, `personal_tackle_box` has no shipped content; it starts empty for every user)

### Repository implementation

```text
lib/features/personal_tackle_box/data/personal_tackle_box_repository.dart
```

```dart
class PersonalTackleBoxRepository {
  PersonalTackleBoxRepository(
    this._database,
    this._storage, {
    PersonalTackleBoxMapper mapper = const PersonalTackleBoxMapper(),
    LureCatalogMapper catalogMapper = const LureCatalogMapper(),
    Uuid uuid = const Uuid(),
    DateTime Function()? now,
  }) : _mapper = mapper,
       _catalogMapper = catalogMapper,
       _uuid = uuid,
       _now = now ?? DateTime.now;

  final AppDatabase _database;
  final TackleBoxPhotoStorage _storage;
  final PersonalTackleBoxMapper _mapper;
  final LureCatalogMapper _catalogMapper;
  final Uuid _uuid;
  final DateTime Function() _now;

  Future<bool> isOwned(String lureVariantId) { ... }

  Future<AddTackleBoxEntryResult> add({
    required LureCatalogEntry catalogEntry,
    PendingTackleBoxPhoto? pendingPhoto,
  }) { ... }

  Future<List<TackleBoxItem>> getAll() { ... }

  Future<TackleBoxItem?> getById(String tackleBoxEntryId) { ... }

  Future<void> attachPhoto({
    required String tackleBoxEntryId,
    required PendingTackleBoxPhoto pendingPhoto,
  }) { ... }

  Future<void> remove(String tackleBoxEntryId) { ... }
}
```

```dart
final class AddTackleBoxEntryResult {
  const AddTackleBoxEntryResult({required this.item, required this.photoFailed});

  final TackleBoxItem item;
  final bool photoFailed;
}
```

`AddTackleBoxEntryResult` mirrors `AddCatchPhotosResult`/`CatchCreated`'s partial-failure reporting shape from TD-013 — reused pattern, not a new one.

Repository responsibilities:

- `TackleBoxEntry` id generation
- duplicate pre-check and the authoritative database-level uniqueness guarantee
- coordination between database and `TackleBoxPhotoStorage`
- the manufacturer → model → variant sort order for `getAll()`
- row-to-domain / row-to-read-model mapping

The repository does not own: grouping (presentation concern), the photo source picker UI, or the "Add to Tackle Box" button's ownership-state display (the button queries `isOwned` itself).

### Entity ↔ domain mapper

```text
lib/features/personal_tackle_box/data/personal_tackle_box_mapper.dart
```

```dart
class PersonalTackleBoxMapper {
  const PersonalTackleBoxMapper();

  TackleBoxEntry entryFromRow(TackleBoxEntryEntity row) => TackleBoxEntry(
    id: row.id,
    lureVariantId: row.lureVariantId,
    personalPhotoRelativePath: row.personalPhotoRelativePath,
    addedAt: DateTime.fromMillisecondsSinceEpoch(row.addedAt),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );

  TackleBoxEntriesCompanion toInsertCompanion(TackleBoxEntry entry) =>
      TackleBoxEntriesCompanion.insert(
        id: entry.id,
        lureVariantId: entry.lureVariantId,
        personalPhotoRelativePath: Value(entry.personalPhotoRelativePath),
        addedAt: entry.addedAt.millisecondsSinceEpoch,
        createdAt: entry.createdAt.millisecondsSinceEpoch,
        updatedAt: entry.updatedAt.millisecondsSinceEpoch,
      );
}
```

`TackleBoxItem` assembly (`entry` + the joined `LureCatalogEntry`) happens directly in the repository's query methods, calling `_catalogMapper.entryFromRows(...)` — there is no separate `itemFromRows` wrapper needed beyond that one call, so none is added.

---

## 5. Personal Photo Handling

Reuses the architecture from MFS-013/TD-013 exactly: `image_picker` for capture/selection, the `image` package for decode/orient/resize/encode, `path_provider`'s application documents directory as the storage root, and the same atomic temp-file-then-rename write pattern. No new image system, no new packages.

### Image storage

```text
lib/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart
```

```dart
class TackleBoxPhotoStorage {
  TackleBoxPhotoStorage({
    required Future<Directory> Function() rootDirectoryProvider,
    int maxLongestSide = defaultMaxLongestSide,
    int jpegQuality = defaultJpegQuality,
  });

  static const int defaultMaxLongestSide = 2048;
  static const int defaultJpegQuality = 85;
  static const String photosDirectoryName = 'tackle_box_photos';

  Future<String> store({
    required String tackleBoxEntryId,
    required String sourcePath,
  });

  Future<File> resolve(String relativePath);

  Future<void> delete(String relativePath);
}
```

Layout: `<application-documents>/tackle_box_photos/<tackle-box-entry-id>.jpg`. The database persists only `tackle_box_photos/<tackle-box-entry-id>.jpg` (POSIX-separated), identical in spirit to `CatchPhotoStorage` but flat — no per-entry subdirectory and no `deleteEntryDirectory` method, because there is exactly one photo per entry, never up to five (see [Key Design Decision 7](#key-design-decisions)).

Processing parameters are identical to `CatchPhotoStorage`: longest side capped at 2048px (no upscaling), JPEG quality 85, orientation baked in before resizing. The decode/resize/encode private implementation is duplicated from `CatchPhotoStorage`, not extracted into a shared `lib/core/` utility — consistent with TD-013's explicit rule against a `lib/core/storage/` abstraction, and with this project's preference for small, feature-owned components over a shared abstraction serving only two call sites.

### Ownership

Once a photo is successfully written to `tackle_box_photos/`, the application exclusively owns that file. The original camera/gallery source remains outside application ownership: deleting the personal photo never touches the original, and the original becoming unavailable never affects the stored copy.

### Lifecycle and cleanup

- **Create**: photo processed and written atomically (temp file, then rename) as part of `PersonalTackleBoxRepository.add()`; if the database insert then fails, the just-written file is deleted before the error is rethrown (mirrors `CatchPhotoRepository._storeAndInsert`).
- **Add without a photo, or a failed photo**: does *not* fail the whole operation. Per MFS-016's Error Handling, a photo failure during add still yields a saved `TackleBoxEntry`; `AddTackleBoxEntryResult.photoFailed` communicates the outcome to the presentation layer.
- **Remove**: `PersonalTackleBoxRepository.remove()` loads the row, deletes the photo file if `personalPhotoRelativePath` is non-null (a missing file is treated as already deleted — no error), then deletes the database row. If file deletion fails for a reason other than "already gone," the row is preserved, the failure is surfaced, and the user can retry — the row is never left pointing at a file that was known to survive a failed delete.
- **Missing/corrupt file for an existing entry**: `Owned Entry Detail` catches the resolve/decode failure and renders a placeholder (or falls back to the catalog image) rather than crashing; the database row and its `personalPhotoRelativePath` are left untouched, exactly like `CatchPhoto`'s missing-file handling.

### `attachPhoto` — narrow, retry-only

`PersonalTackleBoxRepository.attachPhoto({tackleBoxEntryId, pendingPhoto})` exists **only** to satisfy MFS-016's own Error Handling requirement — "photo storage failure after the entry was created... the user can attempt to add a photo again later" — for a single reason: it is a *recovery* path, not a general edit feature. It:

- throws `StateError` if the entry already has a `personalPhotoRelativePath` (never silently overwrites — replacing an existing photo remains out of scope per MFS-016),
- is exercised by exactly one UI affordance: a "Yritä uudelleen" (try again) action shown only in the confirmation immediately following an `add()` call whose `photoFailed` was `true`,
- is never exposed from `OwnedEntryDetailPage` or any other persistent, general-purpose control.

This keeps the feature consistent with MFS-016's explicit Out-of-Scope item ("editing or replacing a personal photo on an already-saved entry... removing and re-adding the entry is the only supported way") while still satisfying the one Error Handling sentence that implies a retry must be possible.

---

## 6. Presentation Layer

All screens are manually constructed and pushed with `Navigator.push` — no GoRouter routes, no Riverpod, consistent with every other detail/list page in this app.

### Grouped list screen — `PersonalTackleBoxPage`

```text
lib/features/personal_tackle_box/presentation/widgets/personal_tackle_box_page.dart
```

A `StatefulWidget` constructed with a required `PersonalTackleBoxRepository` and `TackleBoxPhotoStorage`.

Load sequence (`initState`): `await repository.getAll()` → on success, group the already-sorted flat list into manufacturer → model sections with one linear pass (compare each item's manufacturer/model to the previous item's; open a new section whenever either changes) → `setState`. No repository call happens per group; grouping is pure, in-memory, O(n).

Rendering: a single `ListView.builder` over a flattened "section header / item" render list (manufacturer header, model sub-header, one row per owned variant) — lazy/virtualized, following the same performance discipline as `LureCatalogListPage`. Tapping a variant row opens `OwnedEntryDetailPage` with the already-loaded `TackleBoxItem` (no re-query, mirroring `LureDetailsPage` receiving an already-resolved `LureCatalogEntry`).

**Loading**: centered `CircularProgressIndicator`.
**Empty** (`getAll()` returns `[]` and no error): a clear "no lures added yet" message with a way back to the Lure Catalog.
**Error**: `getAll()` throwing sets a load-error message; the page never silently shows a partial or stale list.

### Detail view — `OwnedEntryDetailPage`

```text
lib/features/personal_tackle_box/presentation/widgets/owned_entry_detail_page.dart
```

Per MFS-016's clarification, this is a thin presentation layer over the existing `TackleBoxItem` — not a separate feature — limited in this milestone to exactly three responsibilities:

1. display resolved catalog details (reusing the same field set and layout approach as `LureDetailsPage`'s info rows, and reusing `lure_catalog`'s `LureImage` widget for the image fallback),
2. display the personal photo when present (`Image.file` via `TackleBoxPhotoStorage.resolve`, with an `errorBuilder` falling back to the catalog image/placeholder on a missing or corrupt file), and
3. provide the "Poista vieherasiasta" (Remove from Tackle Box) action.

A `StatefulWidget` only to track a single `_isRemoving` bool (preventing duplicate remove taps while the operation is in flight) — no other mutable state. It receives an already-resolved `TackleBoxItem`, `PersonalTackleBoxRepository`, and `TackleBoxPhotoStorage` via constructor; no load-on-open query.

### Add flow — `AddToTackleBoxAction`

```text
lib/features/personal_tackle_box/presentation/widgets/add_to_tackle_box_action.dart
```

A small self-contained widget, built by the callback threaded into `LureDetailsPage` (see [Navigation](#7-navigation)). On `initState`, calls `repository.isOwned(catalogEntry.id)` to decide its own initial state:

- **already owned** → renders disabled/muted ("Vieherasiassa"), not tappable — this is how FR-6's "reflect existing ownership state" is satisfied at the UI layer.
- **not owned** → renders as an enabled "Lisää vieherasiaan" action.

Tapping when enabled opens a small dialog (mirroring `showCatchPhotoSourceDialog`'s shape) offering **Kamera / Galleria / Ei kuvaa** (camera / gallery / no photo). Selecting an option immediately proceeds — there is no separate "confirm" step beyond the photo choice itself, since [MFS-016 FR-3](../specifications/MFS-016-personal-tackle-box-foundation.md) already treats the add action itself as the deliberate step; a second confirmation would be redundant.

On completion, the widget calls `repository.add(catalogEntry: ..., pendingPhoto: ...)`, then:

- on success with no photo failure: shows a brief confirmation and flips its own state to "already owned,"
- on success with `photoFailed == true`: shows the same confirmation plus a "Yritä uudelleen" action wired to `attachPhoto` (see [`attachPhoto`](#attachphoto-narrow-retry-only)),
- on failure (entry could not be created at all): shows a clear error and leaves its state as "not owned," so the user can retry.

### Remove flow

From `OwnedEntryDetailPage`: an AppBar action opens a confirmation dialog ("Poista vieherasiasta? / Tätä toimintoa ei voi perua." — Cancel / Poista, destructive styling on Poista), consistent with the confirmation pattern MFS-013 already established for persistent photo deletion. On confirm: disable the action, call `repository.remove(entry.id)`, and on success pop back to `PersonalTackleBoxPage`, which reloads its list. On failure: re-enable the action, show a clear error, leave the entry and its photo fully intact.

### Empty / Loading / Error summary

| State | Where | Behavior |
|---|---|---|
| Loading | `PersonalTackleBoxPage` | Centered progress indicator |
| Empty (no owned entries) | `PersonalTackleBoxPage` | Distinct message + path back to Lure Catalog |
| Load error | `PersonalTackleBoxPage` | Distinct error message, no partial/stale list shown |
| No personal photo | `OwnedEntryDetailPage` | Falls back to catalog image / placeholder — a normal state, not an error |
| Missing/corrupt photo file | `OwnedEntryDetailPage` | Falls back to catalog image / placeholder, no crash |

---

## 7. Navigation

```text
Lure Catalog (browse/search)        [lure_catalog, unchanged]
        ↓
Lure Model → Lure Details           [lure_catalog's LureDetailsPage, + one optional actionsBuilder]
        ↓
AddToTackleBoxAction                [personal_tackle_box — built by the caller of LureDetailsPage]
        ↓ (dialog: Kamera / Galleria / Ei kuvaa)
repository.add(...)                 [personal_tackle_box]
```

```text
MapScreen (temporary entry point)   [existing, unchanged pattern from TD-015]
        ↓ (new AppBar action)
PersonalTackleBoxPage               [personal_tackle_box]
        ↓ (tap a grouped row)
OwnedEntryDetailPage                [personal_tackle_box]
        ↓ (Remove, with confirmation)
back to PersonalTackleBoxPage (reloaded)
```

Concretely:

- `MapScreen` constructs `_tackleBoxPhotoStorage` and `_personalTackleBoxRepository` the same way it already constructs `_catchPhotoStorage`/`_catchPhotoRepository`/`_lureCatalogRepository` — manual construction, no Riverpod.
- `MapScreen` gains one more temporary `AppBar` action (alongside the existing catalog entry point from TD-015) that pushes `PersonalTackleBoxPage` via `Navigator.push(MaterialPageRoute(...))`.
- `MapScreen` builds the `actionsBuilder` it passes down into `LureCatalogListPage` → `LureDetailsPage`; that builder constructs an `AddToTackleBoxAction` wired to `_personalTackleBoxRepository`/`_tackleBoxPhotoStorage`. `LureCatalogListPage` and `LureDetailsPage` only forward this optional parameter — they never import `personal_tackle_box`.
- `OwnedEntryDetailPage` is opened the same way `LureDetailsPage` is (`Navigator.push`, receiving an already-resolved object) — no GoRouter route.
- No broader navigation redesign is attempted; both new entry points are explicitly temporary, exactly like TD-015's.

---

## 8. Queries

All queries live on `PersonalTackleBoxRepository`.

| Query | Purpose | Why it exists |
|---|---|---|
| `isOwned(lureVariantId)` | `SELECT` existence check on `TackleBoxEntries.lureVariantId` | Lets `AddToTackleBoxAction` reflect ownership state before any add attempt (FR-6), without loading a full `TackleBoxItem`. |
| `add(catalogEntry, pendingPhoto)` | `INSERT`, after the `isOwned` pre-check | The pre-check gives a clean, immediate "already owned" outcome; the `uniqueKeys` constraint is the authoritative, race-safe backstop if two adds for the same variant are ever in flight together. |
| `getAll()` | `TackleBoxEntries ⨝ LureVariants ⨝ LureModels`, ordered manufacturer → model (case-insensitive) → variant id | One query for the entire grouped browsing screen — no N+1, and the sort order matches `LureCatalogRepository.browse()` so grouping boundaries fall out of a single linear pass. |
| `getById(tackleBoxEntryId)` | Same three-table join, filtered by `TackleBoxEntries.id` | Used wherever a screen only has an id and needs the full `TackleBoxItem` again (e.g. re-entering `OwnedEntryDetailPage` from a saved reference) without reloading the whole list. |
| `remove(tackleBoxEntryId)` | Load row → delete photo file (if any) → `DELETE` row | Centralizes the file-then-row deletion order that keeps a failed delete from ever leaving a row pointing at a known-gone file. |

**Catalog joins never filter on `LureVariants.retiredAt`** — every query above resolves a retired variant exactly like an active one (MFS-016 FR-9). This mirrors `LureCatalogRepository.getEntryById()`'s deliberate omission of the same filter, for the same reason.

---

## 9. Error Handling

| Scenario | Behavior |
|---|---|
| Duplicate add attempt | `AddToTackleBoxAction` never offers the action once `isOwned` is `true`; a race that slips past that pre-check hits the `uniqueKeys` constraint, which the repository catches and reports as "already owned" — never a raw database error surfaced to the user. |
| Missing personal photo file | `OwnedEntryDetailPage`'s `Image.file` `errorBuilder` catches it and falls back to the catalog image/placeholder; the database row is left untouched, and the entry remains fully usable and removable. |
| Missing catalog reference | Not expected to occur: the `restrict` foreign key and the fact that `lure_catalog` never deletes a row make an orphaned `TackleBoxEntry` structurally impossible in this milestone. Queries defensively use an `INNER JOIN`, so if it ever did occur, the entry simply and safely does not appear in any listing, rather than surfacing a null-catalog crash. |
| Retired catalog variant | No special-casing anywhere in this feature — resolved and displayed identically to an active variant (FR-9). |
| Photo storage failure during `add()` | Caught inside `add()`; the `TackleBoxEntry` is still created without a photo; `AddTackleBoxEntryResult.photoFailed = true` drives the retry affordance described in [§5](#attachphoto-narrow-retry-only). |
| Photo storage failure during `attachPhoto()` retry | Propagated to the caller; the entry is left exactly as it was (photo-less, still owned); a clear error is shown and the retry action remains available. |
| Remove failure (genuine file-deletion error) | The database row is preserved, the error is surfaced, and the user can retry — the row is never deleted while its photo file might still exist unaccounted for. |
| Camera/gallery permission denial or cancellation during add | The dialog closes (cancellation) or shows a clear message (denial); in both cases the underlying "Add to Tackle Box" action remains available, and choosing to continue without a photo is always offered. |

---

## 10. Testing Strategy

Follows the same layered testing philosophy as TD-013/TD-015: domain tests for construction/assertions, database tests for schema and constraints, storage tests against a temporary directory, repository tests for behavior, widget tests for the presentation surfaces, and a physical-device pass at the end.

**Domain** (`test/features/personal_tackle_box/domain/`):
`tackle_box_entry_test.dart` — valid construction; empty `id`/`lureVariantId` rejection. `tackle_box_item_test.dart` — `id`/`personalPhotoRelativePath` delegate correctly to the wrapped `entry`.

**Database** (`tackle_box_entries_database_test.dart`):
migration from schema 4 succeeds; existing Fishing Spot/Catch/CatchPhoto/LureModel/LureVariant data survives; a `TackleBoxEntry` row can be inserted and read back; the foreign key rejects an unknown `lureVariantId`; a second row for the same `lureVariantId` violates the unique constraint; attempting to delete a referenced `LureVariant` is rejected by `KeyAction.restrict` (exercised directly at the SQL layer, since nothing in the application issues that delete).

**Mapper** (`personal_tackle_box_mapper_test.dart`):
row ↔ domain round-trip, including a `null` `personalPhotoRelativePath`; companion mapping preserves all fields.

**Storage** (`tackle_box_photo_storage_test.dart`, using a temp directory, mirroring `catch_photo_storage_test.dart`):
store/resolve/delete; the flat `tackle_box_photos/<id>.jpg` path (no subdirectory); atomic temp-then-rename; no upscaling; corrupt/undecodable source; missing source; deleting an already-missing file is a no-op.

**Repository** (`personal_tackle_box_repository_test.dart`):
`isOwned` true/false; `add` creates an entry with no photo; `add` creates an entry with a photo; `add` with a failing storage still creates the entry and reports `photoFailed = true`; `add` for an already-owned variant is rejected before touching storage; a race (row inserted directly, then `add` called) is rejected by the database constraint; `getAll` returns a manufacturer → model → variant sorted list; `getAll` includes an entry whose catalog variant is retired; `getById` returns `null` for an unknown id; `remove` deletes the row and its photo file; `remove` of an unknown id is a no-op; `remove` preserves the row when file deletion genuinely fails; `attachPhoto` succeeds exactly once and rejects a second call on the same entry.

**Widget** (`test/features/personal_tackle_box/presentation/widgets/`):
`personal_tackle_box_page_test.dart` — loading, empty, error, grouped rendering (multiple manufacturers/models), tapping a row opens `OwnedEntryDetailPage` with the correct item. `owned_entry_detail_page_test.dart` — renders catalog details and personal photo (or fallback); remove confirmation shown; cancel leaves the entry; confirmed remove pops and the entry is gone; remove failure keeps the entry and shows an error. `add_to_tackle_box_action_test.dart` — initial not-owned/owned states from `isOwned`; skip-photo add; camera add; gallery add; already-owned renders disabled and is not tappable; photo failure shows the retry affordance and `attachPhoto` succeeds on retry. Photo picker interactions are mocked via `ImagePickerPlatform.instance`, exactly as `catch_photos`' widget tests already do — no real camera in tests.

**Integration/physical Android testing**: add with camera photo; add with gallery photo; add with no photo; duplicate-add attempt blocked; grouped browsing after app restart (persistence across the schema-5 migration); remove with confirmation and file cleanup verified; airplane mode; small-screen layout for the grouped list and detail view; both new `MapScreen` entry points.

---

## 11. Future Extensibility

None of the following are implemented now; each is called out so the current design is checked against not blocking it later.

- **Notes** — an additional nullable column on `TackleBoxEntries`, addable without touching `id`/`lureVariantId`/photo semantics.
- **Condition** — same shape: an additive nullable column, likely an open string code (mirroring `lureType`'s pattern) rather than a closed enum, whenever it's actually needed.
- **Purchase information** — naturally a separate, additive 1:1 table keyed by `tackleBoxEntryId` (mirroring how `CatchPhotos` is keyed by `catchId`), deliberately kept out of `TackleBoxEntries` itself so this milestone's table stays minimal.
- **Photo replacement** — `TackleBoxPhotoStorage` already owns exactly one well-known path per entry; a future "replace" operation is "store over the same relative path, or delete-then-store," addable as one new repository method with no schema change.
- **Multiple photos** — would follow `catch_photos`' own precedent exactly: a child table (photo id, `tackleBoxEntryId`, `sortOrder`), a per-entry subdirectory, and a shared max-count constant — a deliberate non-goal now because MFS-016 scopes exactly one photo per entry.
- **Catch integration (MFS-017)** — `TackleBoxEntry.id`/`lureVariantId` are already stable references a future `Catch.tackleBoxEntryId` (or `Catch.lureVariantId`) column can point to, exactly like `Catch.fishingSpotId` today. No remodel of this milestone's tables is anticipated.

---

## Dependencies

No new external package dependencies. This milestone reuses, unchanged:

- Flutter, Dart
- Drift (per ADR-0005)
- `image_picker`, `image`, `path`, `path_provider`, `uuid` — all already declared in `pubspec.yaml` for `catch_photos`
- the existing Repository pattern, feature-first structure, and manual dependency construction (ADR-0001, ADR-0003, ADR-0006)
- `lure_catalog`'s domain/data/presentation types consumed read-only (`LureVariant`, `LureCatalogEntry`, `LureCatalogMapper`, `LureImage`)

`flutter_riverpod` is not used by this feature, for the same reasons documented in TD-015.

---

## Expected Files To Create

```text
lib/features/personal_tackle_box/domain/tackle_box_entry.dart
lib/features/personal_tackle_box/domain/tackle_box_item.dart
lib/features/personal_tackle_box/data/local/tackle_box_entries_table.dart
lib/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart
lib/features/personal_tackle_box/data/personal_tackle_box_mapper.dart
lib/features/personal_tackle_box/data/personal_tackle_box_repository.dart
lib/features/personal_tackle_box/presentation/widgets/tackle_box_photo_picker.dart
lib/features/personal_tackle_box/presentation/widgets/add_to_tackle_box_action.dart
lib/features/personal_tackle_box/presentation/widgets/personal_tackle_box_page.dart
lib/features/personal_tackle_box/presentation/widgets/owned_entry_detail_page.dart
```

Plus mirrored test files under `test/features/personal_tackle_box/...` per [§10](#10-testing-strategy).

## Expected Files To Modify

```text
lib/core/database/app_database.dart                            (register TackleBoxEntries, schema 4 -> 5, migration)
lib/features/lure_catalog/presentation/widgets/lure_details_page.dart      (one optional actionsBuilder parameter — see Key Design Decision 1)
lib/features/lure_catalog/presentation/widgets/lure_catalog_list_page.dart (forward the same optional parameter)
lib/features/map/presentation/map_screen.dart                   (construct new repository/storage; one new AppBar entry point; build the actionsBuilder)
```

Modify generated Drift files only through code generation.

---

## Validation

```bash
dart format .
flutter analyze
flutter test
```

All must pass. Review generated Drift changes. Confirm the schema version and migration are correct against the repository's actual current state before implementing, in case it has moved past `4` since this document was written.

---

## Definition of Done

- The implementation satisfies all requirements in MFS-016.
- The implementation follows TD-016, or documents and justifies each deviation.
- A `LureVariant` can be added to the Personal Tackle Box only through the explicit "Add to Tackle Box" action; viewing/selecting a color never creates an entry.
- Adding supports camera, gallery, and no-photo, and skipping never blocks the add.
- One `LureVariant` can be owned at most once, enforced at the database layer, not only the UI.
- The browsing screen groups owned entries by manufacturer, then model — never a flat one-row-per-variant list.
- Removing an entry requires confirmation and deletes both its database row and its photo file, when present.
- A `TackleBoxEntry` referencing a retired catalog variant remains visible, viewable, and removable.
- `lure_catalog`'s domain model, database, and repository are unmodified; its presentation layer gained only the two documented optional passthrough parameters.
- Every capability works with no network connection.
- The database migration (4 → 5) succeeds without losing existing data.
- No repository interfaces, DAO, service, or use-case layers were introduced.
- No Riverpod provider or Consumer widget was introduced.
- `dart format .`, `flutter analyze`, and `flutter test` all pass.
- Physical Android testing has been completed successfully.
- Architecture review has been completed, with explicit sign-off on Key Design Decision 1 (the `lure_catalog` presentation touch).
- Documentation (`docs/project-status.md`) has been updated.
