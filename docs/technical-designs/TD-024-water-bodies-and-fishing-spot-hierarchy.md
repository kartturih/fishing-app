# TD-024 — Water Bodies and Fishing Spot Hierarchy

## Status

Implemented — architecture review passed, all automated tests passing (735/735), `flutter analyze` clean (8 pre-existing/accepted info-level lints, none introduced by this milestone), and physical Android verification completed successfully. No architectural deviations from this document's domain, database, repository, or presentation design were required; six documented discoveries/deviations (a file-path correction, three newly-created rather than extended test files, a ripple effect across four pre-existing legacy-migration tests, a dialog-controller disposal bug, a loading-text collision, and pre-existing id-generation flakiness surfaced by increased test load) are detailed in Implementation Notes below. FR-17's post-migration hint text/UI was deliberately deferred per Key Design Decision 8, as recorded in the Definition of Done.

## Related

- MFS-024: Water Bodies and Fishing Spot Hierarchy (the approved specification this document implements)
- ADR-0007: Water Body Domain (the architecture decision this document implements)
- MFS-004 / TD-004 — Fishing Spot Foundation (the `FishingSpot` domain model, table, and repository this document extends)
- MFS-005 / TD-005 — Create Fishing Spot (the creation flow this document inserts a new step into)
- MFS-007 / TD-007 — Edit Fishing Spot (the Fishing Spot Details bottom sheet this document adds a new action to)
- MFS-008 / TD-008 — Delete Fishing Spot (the existing deletion flow/confirmation pattern this document reuses for the new water-body deletion rule)
- MFS-009 / TD-009 — Catch Foundation (the `FishingSpot 1 ──── * Catch` relationship this document's own `WaterBody 1 ──── * FishingSpot` relationship mirrors)
- MFS-017 / TD-017 — Assign Lure to Catch (the project's first `addColumn` migration and its `KeyAction.restrict` foreign-key precedent, both reused here)
- MFS-023 / TD-023 — Catch Notes (the most recent `addColumn` migration and its schema-snapshot migration-test precedent, both reused here)
- MFS-021 / TD-021 — Species Statistics (the `SpeciesCatchEntry`/`SpeciesStatisticsRepository` this document extends)

---

## Goal

Implement MFS-024 and ADR-0007: introduce `WaterBody` as a persistent domain entity inside the existing `fishing_spots` feature, parent to `FishingSpot`, with a manual selection/creation flow, a minimal management surface, a safe deletion rule, and a purely additive migration for existing data — without introducing a new feature directory, a repository interface, a service layer, or any optional water-body metadata beyond identity.

The implementation shall satisfy MFS-024 and ADR-0007.

---

## Fixed Architectural Decisions (not reconsidered here)

Per this task's own instructions, the following are accepted and out of scope for reconsideration in this document:

- `WaterBody` is implemented **inside the existing `fishing_spots` feature** — no new top-level `water_bodies` feature directory. This closes, in favor of "keep it inside `fishing_spots`," the placement question MFS-024/ADR-0007 explicitly left open.
- `WaterBody` is a standalone domain entity; `FishingSpot` references it; `Catch` continues to reference only `FishingSpot`; no `waterBodyId` is duplicated onto `Catch`.
- `WaterBody` represents identity only in this milestone — no depth, species, vegetation, weather, AI, or recommendation metadata. Those are future-milestone territory (`docs/roadmap.md` §3.4–§3.6).
- The migration must be the simplest technically correct option; this document deliberately avoids a full table-rebuild migration or any migration-time user interaction (see [Migration Strategy](#4-migration-strategy)).
- No repository interfaces, DAO layer, service layer, or use-case layer — concrete repositories only, consistent with `docs/development-rules.md` and every prior TD in this project.

---

## Current State

Inspected directly, in the current codebase, before designing this change:

| Area | Current shape |
|---|---|
| `FishingSpot` domain ([fishing_spot.dart](../../lib/features/fishing_spots/domain/fishing_spot.dart)) | A plain class: `id`, `name`, `latitude`, `longitude`, `createdAt`. No assertions, no `waterBodyId`. |
| `FishingSpots` table ([fishing_spots_table.dart](../../lib/features/fishing_spots/data/fishing_spots_table.dart)) | `id` (text, PK), `name` (text), `latitude`/`longitude` (real), `createdAt` (int). No foreign keys of its own — it is only ever the *referenced* side today (`Catches.fishingSpotId → FishingSpots.id`, `onDelete: cascade`). |
| `FishingSpotRepository` ([fishing_spot_repository.dart](../../lib/features/fishing_spots/data/fishing_spot_repository.dart)) | Concrete class, no injected mapper (mapping is done via plain extension methods, not an injected `Mapper` instance — a different convention from `catches`/`lure_catalog`). Methods: `loadAll()`, `watchAll()`, `create({name, latitude, longitude})`, `updateName({id, name})`, `delete(id)`. No `getById`. |
| Mapping ([fishing_spot_mapper.dart](../../lib/features/fishing_spots/data/fishing_spot_mapper.dart)) | Two top-level extensions: `FishingSpotEntityMapper.toDomain()` and `FishingSpotCompanionMapper.toCompanion()`. Direct field-for-field, no lookups. |
| `AppDatabase` ([app_database.dart](../../lib/core/database/app_database.dart)) | `schemaVersion => 7`. Every migration to date: four `createTable` calls (versions 2–5) and two `addColumn` calls (version 6 `catches.lureVariantId`, version 7 `catches.notes`). No migration has ever back-filled data into a new column; every prior nullable-column addition left every existing row at `NULL`, which was already the correct "no value" state for that field. This document's migration is the first one where that is *not* acceptable, since every `FishingSpot` must end up with a real `waterBodyId` — see [Migration Strategy](#4-migration-strategy). |
| Fishing spot creation ([map_screen.dart](../../lib/features/map/presentation/map_screen.dart)) | `_onAddFishingSpotPressed()` → `AddFishingSpotBottomSheet.show()` (method choice) → either `_createFishingSpotFromCurrentLocation()` or map selection mode ending in `_promptAndCreateFishingSpot(position)`. Both paths converge on `FishingSpotNameBottomSheet.show()` (name only) → `_fishingSpotRepository.create(name:, latitude:, longitude:)`. |
| Fishing spot editing ([fishing_spot_details_bottom_sheet.dart](../../lib/features/fishing_spots/presentation/widgets/fishing_spot_details_bottom_sheet.dart)) | A modal bottom sheet showing the spot's name, "Muokkaa nimeä" (inline rename), "Lisää saalis," "Poista" (with confirmation dialog), and the spot's Catch list. Returns a sealed `FishingSpotDetailsResult` (`FishingSpotRenamed`/`FishingSpotDeleted`/`FishingSpotAddCatchRequested`) that `MapScreen` reacts to. |
| Species Statistics ([species_catch_entry.dart](../../lib/features/statistics/domain/species_catch_entry.dart), [species_statistics_repository.dart](../../lib/features/statistics/data/species_statistics_repository.dart), [record_catch_card.dart](../../lib/features/statistics/presentation/widgets/record_catch_card.dart)) | `SpeciesCatchEntry` pairs a `Catch` with its resolved `FishingSpot`. `SpeciesStatisticsRepository` performs one species-filtered join (`Catches ⨝ FishingSpots`). `RecordCatchCard` renders `entry.fishingSpot.name` as its location line, and includes it in its accessibility semantic label. |
| Migration testing precedent ([catch_migration_test.dart](../../test/features/catches/data/catch_migration_test.dart)) | A `_LegacyAppDatabase` subclass pins an old `schemaVersion` and creates tables via literal `CREATE TABLE` statements matching that old shape exactly — never by reusing the current table class. The real `AppDatabase` is then pointed at the seeded file and upgraded. |

---

## Key Design Decisions

This section answers the questions most likely to be raised in review, before the detailed sections below implement them.

**1. `FishingSpots.waterBodyId` is declared `nullable` in the Drift table class, even though the domain model's field is non-nullable.** SQLite's `ALTER TABLE ... ADD COLUMN` cannot add a `NOT NULL` column to a table with existing rows unless a constant default satisfies every one of them — and a foreign key to a not-yet-existing per-row `WaterBody` has no meaningful constant default. Because Drift generates the same column definition for both `onCreate` (fresh installs) and `onUpgrade` (existing installs) from one shared table class, the column must be declared nullable at the schema level for both paths to stay identical — hand-diverging them would be a worse inconsistency than a schema-level nullable column. Non-null is instead guaranteed the same way `CatchRepository` already guarantees other invariants beyond what the schema alone enforces: the domain model's field (`FishingSpot.waterBodyId`) is a plain, non-nullable `String`; every write path requires it; the migration back-fills every existing row inside the same transaction Drift already wraps around a migration (see [Migration Strategy](#4-migration-strategy)); and the mapper fails loudly, rather than silently, if it ever reads a row that somehow violates the invariant (see [Domain-to-Database Mapping](#7-domain-to-database-mapping)).

**2. The `FishingSpots.waterBodyId → WaterBodies.id` foreign key uses `KeyAction.restrict`.** This is the same foreign-key strategy already established for `LureVariant` references (TD-016/TD-017), and it is the database-level backstop for MFS-024/ADR-0007's "a non-empty water body cannot be deleted" rule. It is deliberately **not** the primary mechanism the application relies on for a good user experience: `WaterBodyRepository.delete()` proactively counts referencing fishing spots first and throws a clear, typed error before ever attempting the `DELETE` (see [Repository Implementations](#5-repository-implementations)), so the angler sees a clean message rather than a raw database exception. The `restrict` constraint exists purely as defense-in-depth, exactly the same "UI/repository validates, the database also refuses to allow the invalid state" layering already used throughout this project (measurements, notes length, lure references).

**3. A concrete `WaterBodyRepository` is introduced, parallel to `FishingSpotRepository` — no repository interface, no service layer.** `WaterBody` is genuinely its own persisted entity with its own CRUD-shaped operations (create, rename, list, delete, plus the nearby-suggestion query) that have nothing to do with any single `FishingSpot`. This mirrors exactly why `FishingSpotRepository` itself exists as a sibling to `CatchRepository`, and satisfies "only introduce a new repository when it provides clear architectural value" — the value here is that `WaterBody` data genuinely needs its own persistence surface. Consistent with every repository in this project, it is a concrete class with no interface.

**4. Mapping for `WaterBody` follows `fishing_spots`' own existing convention — plain top-level extension methods, not an injected `Mapper` class.** `catches`/`lure_catalog` inject a `Mapper` instance into their repositories; `fishing_spots` does not — `FishingSpotRepository` calls `row.toDomain()`/`spot.toCompanion()` directly via extensions in `fishing_spot_mapper.dart`. Since `WaterBody` is added *to* the `fishing_spots` feature, it follows that feature's own existing convention (a new `water_body_mapper.dart` with the same extension-method shape) rather than importing a different feature's pattern.

**5. `WaterBodyRepository` queries `FishingSpots` directly for counting and nearby-ranking — never through `FishingSpotRepository`'s instance methods.** This is the same "a repository reads whichever tables it needs directly, rather than going through another feature's repository instance" discipline `GeneralCatchStatisticsRepository` already established (TD-020) for reading `Catches`/`FishingSpots`. Both tables are owned by the same feature here, so this is a same-feature, not cross-feature, direct read.

**6. The migration back-fill runs as plain, typed Drift queries inside the `onUpgrade` closure — not raw SQL, and not a full table rebuild.** `AppDatabase.migration`'s `onUpgrade` callback is itself a method closure with access to `this` (the whole, already-typed `AppDatabase`/`_$AppDatabase` instance), so `select(fishingSpots)`, `into(waterBodies).insert(...)`, and `update(fishingSpots)...write(...)` are all directly available with no raw SQL and no new query-execution mechanism. This keeps the migration in the same technical register as every other part of this codebase (typed Drift queries), satisfies "prefer the simplest technically correct migration," and avoids the meaningfully larger complexity of a rebuild-and-copy table migration this early in the project's life.

**7. `getNearby()` returns a small, purpose-built read-model (`NearbyWaterBodies`) rather than a bare list.** MFS-024 FR-5 requires both an ordered "nearby" list *and* an optional single preselected candidate, decided by a concrete rule (a distance threshold plus a disambiguation margin against the next-nearest candidate — see [Query Strategy](#11-query-strategy)). Encoding both in one returned object keeps the widget layer simple (it only ever reads `.candidates` and `.preselected`) and keeps the preselection *rule* inside the repository, not duplicated in presentation code. **The *shape* of that rule (threshold plus margin, both named repository-owned constants) is the architectural decision; the specific meter values are not** — they are an implementation/UX tuning parameter, expected to be adjusted during physical Android testing, not a value this document treats as final (see the constants' own doc comments in [Repository Implementations](#5-repository-implementations)).

**8. MFS-024 FR-17's post-migration hint is deferred out of this implementation's initial scope — a documented deviation, not a silent omission.** FR-17 exists to help a real angler with real, pre-existing historical data understand why their fishing spots suddenly each have their own water body after an upgrade. At this project's current stage — no production users, only development/test data, the application still under active development for personal use (per the project charter's own "initial target: personal use") — there is no real audience for whom this reassurance currently matters: the only person who will see this migration run today already designed the feature and knows exactly why it happened. Building the hint now would be exactly the kind of premature, speculative polish this project's own Development Rules caution against ("keep implementations simple," "avoid premature abstractions") for an audience that does not yet exist. The underlying migration mechanics (FR-14 — every fishing spot automatically receives its own correctly named water body) are implemented in full regardless, since that requirement is structural, not audience-dependent — only the hint *text/UI* itself is postponed. This is flagged explicitly here, rather than dropped silently, because FR-17 is a requirement in an already-approved MFS: reintroducing it later (a small, low-risk addition — one static text line, no new dependency, no schema change) is recommended before any release to real external users, and should be confirmed at the product level at that time, not decided unilaterally by this technical design alone.

**9. `SpeciesCatchEntry` gains a `waterBody` field additively; its existing `fishingSpot` field is kept, not replaced.** `RecordCatchCard`'s location line switches to `waterBody.name` (MFS-024 FR-10), but `entry.fishingSpot` is still required to open the correct `CatchDetailsPage` (which takes a `FishingSpot`, unchanged). `SpeciesStatisticsRepository`'s existing two-way join becomes a three-way join (`Catches ⨝ FishingSpots ⨝ WaterBodies`) — the same "extend an existing join additively" shape TD-022 already used when `GeneralCatchStatisticsRepository`'s query grew a second use (Key Design Decision 6, TD-022).

---

## 1. Overview and Folder Structure

This document extends the existing **`fishing_spots`** feature; it introduces no new feature directory, per the fixed architectural decision above. It also makes one small, additive touch to **`statistics`** (Key Design Decision 9) and threads one new repository through **`map`**'s existing manual-construction wiring (Key Design Decision below on Dependency Injection). No other feature is touched.

```text
lib/
├── core/
│   └── database/
│       └── app_database.dart                                  (modified: schema 7 -> 8)
├── features/
│   ├── fishing_spots/
│   │   ├── data/
│   │   │   ├── fishing_spots_table.dart                        (modified: + waterBodyId)
│   │   │   ├── water_bodies_table.dart                         (new)
│   │   │   ├── fishing_spot_mapper.dart                        (modified)
│   │   │   ├── fishing_spot_repository.dart                    (modified)
│   │   │   ├── water_body_mapper.dart                          (new)
│   │   │   ├── water_body_repository.dart                      (new)
│   │   │   └── haversine.dart                                  (new)
│   │   ├── domain/
│   │   │   ├── fishing_spot.dart                                (modified: + waterBodyId)
│   │   │   ├── water_body.dart                                  (new)
│   │   │   ├── water_body_with_spot_count.dart                  (new)
│   │   │   └── nearby_water_bodies.dart                         (new)
│   │   └── presentation/
│   │       └── widgets/
│   │           ├── fishing_spot_details_bottom_sheet.dart        (modified)
│   │           ├── water_body_selection_bottom_sheet.dart        (new)
│   │           └── water_body_management_page.dart               (new)
│   ├── map/
│   │   └── presentation/
│   │       └── map_screen.dart                                  (modified)
│   └── statistics/
│       ├── data/
│       │   └── species_statistics_repository.dart               (modified)
│       ├── domain/
│       │   └── species_catch_entry.dart                         (modified)
│       └── presentation/
│           └── widgets/
│               └── record_catch_card.dart                       (modified)
```

**Feature boundaries and responsibilities:**

| Feature | Responsibility in this milestone |
|---|---|
| `fishing_spots` (extended) | Owns `WaterBody` (domain, table, mapper, repository), the extended `FishingSpot.waterBodyId` relationship, and every new presentation surface (selection sheet, management page, the new Fishing Spot Details action). |
| `map` (one small, additive touch) | `MapScreen` gains one new repository field (`WaterBodyRepository`) and inserts one new step into its two existing fishing-spot-creation code paths. No new screen or route. |
| `statistics` (one small, additive touch) | `SpeciesCatchEntry`/`SpeciesStatisticsRepository`/`RecordCatchCard` are extended to show a water body instead of an exact fishing spot in one specific, already-cross-spot location line. No other Statistics repository, page, or widget changes. |
| `catches`, `catch_photos`, `lure_catalog`, `personal_tackle_box` | Untouched. `Catch` continues to reference only `FishingSpot`; no `waterBodyId` is added to it (ADR-0007). |

---

## 2. Domain Objects

### `WaterBody` (new)

```dart
// lib/features/fishing_spots/domain/water_body.dart
class WaterBody {
  const WaterBody({
    required this.id,
    required this.name,
    required this.createdAt,
  }) : assert(name != '', 'name must not be empty');

  final String id;
  final String name;
  final DateTime createdAt;
}
```

Deliberately as minimal as `FishingSpot` itself was at its own foundation (MFS-004/ADR-0004) — identity only, per the fixed "no metadata yet" scope decision. No `==`/`hashCode`/`copyWith`, matching `FishingSpot`'s own current shape.

### `FishingSpot` (extended)

```dart
// lib/features/fishing_spots/domain/fishing_spot.dart
class FishingSpot {
  const FishingSpot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.waterBodyId,
    required this.createdAt,
  }) : assert(waterBodyId != '', 'waterBodyId must not be empty');

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String waterBodyId;
  final DateTime createdAt;
}
```

`waterBodyId` is placed after `longitude`, before `createdAt` — grouping the two location-identity fields (coordinates, then the parent relationship) ahead of the timestamp, mirroring how `Catch` already orders its own foreign key (`fishingSpotId`) right after `id`, before its other fields.

### Read-models (new)

```dart
// lib/features/fishing_spots/domain/water_body_with_spot_count.dart
/// A [WaterBody] paired with how many [FishingSpot]s currently reference it —
/// used only by the water-body management surface (FR-16). Not a persisted
/// aggregate; computed fresh on each load, the same "computed live, never
/// stored" discipline the Statistics feature already established.
class WaterBodyWithSpotCount {
  const WaterBodyWithSpotCount({
    required this.waterBody,
    required this.fishingSpotCount,
  });

  final WaterBody waterBody;
  final int fishingSpotCount;
}
```

```dart
// lib/features/fishing_spots/domain/nearby_water_bodies.dart
/// The result of a nearby-water-body query (FR-5): every candidate within
/// this repository's ranking, ordered nearest-first, plus at most one of
/// them singled out as [preselected] when it is unambiguously the most
/// likely match. [preselected], when non-null, is always the first entry
/// of [candidates] as well — this type never introduces a candidate the
/// list itself does not already contain.
class NearbyWaterBodies {
  const NearbyWaterBodies({
    required this.candidates,
    required this.preselected,
  });

  final List<WaterBody> candidates;
  final WaterBody? preselected;

  static const empty = NearbyWaterBodies(candidates: [], preselected: null);
}
```

---

## 3. Drift Tables

### `WaterBodies` (new)

```dart
// lib/features/fishing_spots/data/water_bodies_table.dart
import 'package:drift/drift.dart';

@DataClassName('WaterBodyEntity')
class WaterBodies extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Structurally identical in shape to `FishingSpots` minus the coordinate columns — the same minimal, no-metadata-yet identity table `FishingSpot` itself started as (MFS-004).

### `FishingSpots` (extended)

```dart
// lib/features/fishing_spots/data/fishing_spots_table.dart
import 'package:drift/drift.dart';

import 'package:fishing_app/features/fishing_spots/data/water_bodies_table.dart';

@DataClassName('FishingSpotEntity')
class FishingSpots extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get waterBodyId => text().nullable().references(
    WaterBodies,
    #id,
    onDelete: KeyAction.restrict,
  )();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

`.nullable()` here is a schema-level technical necessity, not a product statement — see [Key Design Decision 1](#key-design-decisions). `onDelete: KeyAction.restrict` is the database-level backstop for the "non-empty water body cannot be deleted" rule — see [Key Design Decision 2](#key-design-decisions).

This is the first table in this codebase to be the **referencing** side of a foreign key (`Catches`, `TackleBoxEntries` reference other tables; `FishingSpots` itself has never referenced anything before). No circular import is introduced: `fishing_spots_table.dart` imports `water_bodies_table.dart`; nothing in `water_bodies_table.dart` imports back.

---

## 4. Migration Strategy

### Schema version

```text
schema version 7 -> schema version 8
```

```dart
@override
int get schemaVersion => 8;

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
    if (from < 5) { await migrator.createTable(tackleBoxEntries); }
    if (from < 6) { await migrator.addColumn(catches, catches.lureVariantId); }
    if (from < 7) { await migrator.addColumn(catches, catches.notes); }
    if (from < 8) {
      await migrator.createTable(waterBodies);
      await migrator.addColumn(fishingSpots, fishingSpots.waterBodyId);
      await _backfillWaterBodiesForExistingFishingSpots();
    }
  },
  beforeOpen: (details) async {
    await customStatement('PRAGMA foreign_keys = ON');
  },
);
```

Confirm at implementation time that the live schema version is still `7` before assuming `8` is the correct next number — the same hedge every prior TD in this project has required.

### Back-fill implementation

```dart
/// Auto-creates one [WaterBody] per pre-existing [FishingSpot] (named
/// identically to that spot's current name, per MFS-024 FR-14) and assigns
/// it, so that every row satisfies the "always has a water body" invariant
/// by the time this migration completes. Uses `this` (the AppDatabase
/// instance itself, already in scope inside `onUpgrade`) rather than raw
/// SQL — every table involved is already a typed, registered Drift table.
/// See Key Design Decision 6.
Future<void> _backfillWaterBodiesForExistingFishingSpots() async {
  final existingSpots = await select(fishingSpots).get();
  for (final spot in existingSpots) {
    // Appending the fishing spot's own already-unique id guarantees a
    // unique water-body id even if two spots are processed within the
    // same microsecond.
    final waterBodyId = 'waterbody-${DateTime.now().microsecondsSinceEpoch}-${spot.id}';
    await into(waterBodies).insert(
      WaterBodiesCompanion.insert(
        id: waterBodyId,
        name: spot.name,
        createdAt: spot.createdAt,
      ),
    );
    await (update(fishingSpots)..where((t) => t.id.equals(spot.id))).write(
      FishingSpotsCompanion(waterBodyId: Value(waterBodyId)),
    );
  }
}
```

Runs inside the same transaction Drift already wraps around a migration's `onUpgrade` callback — the whole 7→8 migration (table creation, column addition, and every back-filled row) either fully applies or fully does not; there is no partially-migrated intermediate state a crash could leave behind. Each `WaterBody` row is inserted (and therefore exists) before the referencing `FishingSpots` row is updated to point at it, so the operation is correct with foreign key enforcement on or off.

### Migration safety

Two of the three schema changes in this migration (`createTable(waterBodies)`, `addColumn(fishingSpots, waterBodyId)`) are in the same, already-proven-safe category as every prior migration in this project: `createTable` and a nullable `addColumn` with no default requirement, neither of which rewrites existing rows. The third part — the back-fill loop — is new in kind (this project's first migration-time *data* write, not just a schema change), which is exactly why it is called out as its own step and covered by a dedicated migration test (see [Testing Strategy](#15-testing-strategy)) rather than assumed safe by similarity to a prior migration.

Existing Fishing Spots, Catches (including `lureVariantId` and `notes`), Catch Photos, Lure Models, Lure Variants, and Tackle Box Entries must all survive the upgrade unchanged; every existing `FishingSpot` row must have a non-null `waterBodyId` immediately after the migration completes, with no fishing spot ever left without one.

### Why not a full table rebuild

A rebuild-and-copy migration (creating a new `fishing_spots` table with a `NOT NULL` `waterBodyId` from the start, copying rows across, dropping and renaming) would let the database itself enforce non-nullability. This was considered and rejected for this milestone: it is meaningfully more complex than `addColumn` + back-fill, this application is still early in development (per this task's own explicit instruction to prefer the simplest technically correct migration), and the domain/repository layer already provides the same non-null guarantee this project already relies on for every other invariant the schema alone cannot express (e.g. `Catch.notes`'s length limit, enforced by `CatchRepository`, not a database `CHECK`). If this table's write surface ever grows beyond `FishingSpotRepository` (for example, a future direct external writer), this decision should be revisited — it should not be revisited preemptively.

---

## 5. Repository Implementations

*(No repository interfaces are introduced anywhere in this document — see [Repository Interfaces](#6-repository-interfaces) immediately below.)*

### `WaterBodyRepository` (new)

```dart
// lib/features/fishing_spots/data/water_body_repository.dart
class WaterBodyRepository {
  WaterBodyRepository(this._database);

  final AppDatabase _database;

  Future<WaterBody> create({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    final waterBody = WaterBody(
      id: _generateId(),
      name: trimmed,
      createdAt: DateTime.now(),
    );
    await _database.into(_database.waterBodies).insert(waterBody.toCompanion());
    return waterBody;
  }

  Future<List<WaterBody>> loadAll() async {
    final rows = await (_database.select(_database.waterBodies)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return [for (final row in rows) row.toDomain()];
  }

  Future<WaterBody?> getById(String id) async {
    final row = await (_database.select(_database.waterBodies)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  Future<WaterBody> rename({required String id, required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    final existing = await (_database.select(_database.waterBodies)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      throw StateError('Water body "$id" was not found.');
    }
    await (_database.update(_database.waterBodies)..where((t) => t.id.equals(id)))
        .write(WaterBodiesCompanion(name: Value(trimmed)));
    return WaterBody(
      id: existing.id,
      name: trimmed,
      createdAt: DateTime.fromMillisecondsSinceEpoch(existing.createdAt),
    );
  }

  Future<void> delete(String id) async {
    final count = await _fishingSpotCount(id);
    if (count > 0) {
      throw StateError(
        'Water body "$id" still has $count fishing spot(s) and cannot be deleted.',
      );
    }
    await (_database.delete(_database.waterBodies)..where((t) => t.id.equals(id))).go();
  }

  Future<List<WaterBodyWithSpotCount>> loadAllWithSpotCounts() async {
    final query = _database.select(_database.waterBodies).join([
      leftOuterJoin(
        _database.fishingSpots,
        _database.fishingSpots.waterBodyId.equalsExp(_database.waterBodies.id),
      ),
    ]);
    final rows = await query.get();

    final counts = <String, _MutableWaterBodyCount>{};
    for (final row in rows) {
      final waterBody = row.readTable(_database.waterBodies).toDomain();
      final counted = counts.putIfAbsent(
        waterBody.id,
        () => _MutableWaterBodyCount(waterBody),
      );
      if (row.readTableOrNull(_database.fishingSpots) != null) {
        counted.count++;
      }
    }

    final result = [
      for (final counted in counts.values)
        WaterBodyWithSpotCount(
          waterBody: counted.waterBody,
          fishingSpotCount: counted.count,
        ),
    ]..sort((a, b) => a.waterBody.name.toLowerCase().compareTo(b.waterBody.name.toLowerCase()));
    return result;
  }

  Future<NearbyWaterBodies> getNearby({
    required double latitude,
    required double longitude,
    int limit = 5,
  }) async {
    final query = _database.select(_database.waterBodies).join([
      innerJoin(
        _database.fishingSpots,
        _database.fishingSpots.waterBodyId.equalsExp(_database.waterBodies.id),
      ),
    ]);
    final rows = await query.get();

    final nearestByWaterBody = <String, _NearbyCandidate>{};
    for (final row in rows) {
      final waterBody = row.readTable(_database.waterBodies).toDomain();
      final spot = row.readTable(_database.fishingSpots);
      final distanceMeters = haversineDistanceMeters(
        latitude,
        longitude,
        spot.latitude,
        spot.longitude,
      );
      final existing = nearestByWaterBody[waterBody.id];
      if (existing == null || distanceMeters < existing.distanceMeters) {
        nearestByWaterBody[waterBody.id] = _NearbyCandidate(waterBody, distanceMeters);
      }
    }

    final sorted = nearestByWaterBody.values.toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    final candidates = [for (final c in sorted.take(limit)) c.waterBody];

    return NearbyWaterBodies(
      candidates: candidates,
      preselected: _preselectionCandidate(sorted),
    );
  }

  WaterBody? _preselectionCandidate(List<_NearbyCandidate> sorted) {
    if (sorted.isEmpty) {
      return null;
    }
    final nearest = sorted.first;
    if (nearest.distanceMeters > _preselectionThresholdMeters) {
      return null;
    }
    if (sorted.length > 1) {
      final second = sorted[1];
      if (second.distanceMeters - nearest.distanceMeters < _preselectionMinMarginMeters) {
        return null; // Ambiguous between two similarly-close water bodies — don't guess.
      }
    }
    return nearest.waterBody;
  }

  Future<int> _fishingSpotCount(String waterBodyId) async {
    final query = _database.selectOnly(_database.fishingSpots)
      ..addColumns([_database.fishingSpots.id.count()])
      ..where(_database.fishingSpots.waterBodyId.equals(waterBodyId));
    final row = await query.getSingle();
    return row.read(_database.fishingSpots.id.count()) ?? 0;
  }

  String _generateId() => 'waterbody-${DateTime.now().microsecondsSinceEpoch}';
}

/// Below this threshold, a nearby candidate is close enough to preselect
/// outright (roughly "you are adding another spot right next to one you
/// already have"). **This is a UX tuning parameter, not an architectural
/// decision** — the value below is an illustrative starting point only,
/// not a reviewed or final number. Real-world GPS accuracy near water and
/// under tree cover is often tens of meters, so this should be adjusted
/// based on physical Android testing before release, not treated as
/// settled by this document. Not derived from any external data — see
/// MFS-024's own "locally stored coordinates only" requirement.
const double _preselectionThresholdMeters = 500;

/// The nearest candidate must be at least this much closer than the
/// second-nearest before it is preselected — avoids guessing between two
/// similarly-close, genuinely different water bodies. Also a tuning
/// parameter, not an architectural decision — see the note above.
const double _preselectionMinMarginMeters = 200;

class _NearbyCandidate {
  _NearbyCandidate(this.waterBody, this.distanceMeters);
  final WaterBody waterBody;
  final double distanceMeters;
}

class _MutableWaterBodyCount {
  _MutableWaterBodyCount(this.waterBody);
  final WaterBody waterBody;
  int count = 0;
}
```

`haversineDistanceMeters` is a small, pure top-level function (new file, `lib/features/fishing_spots/data/haversine.dart`), taking two lat/lon pairs and returning a great-circle distance in meters using the standard haversine formula. It has no platform dependency and no external package requirement — plain `dart:math`. It is feature-owned (used only by `WaterBodyRepository`), not placed in `core`, per ADR-0003's placement rule ("code remains inside a feature when it is owned by that feature and has no clear cross-feature responsibility"); nothing else in this codebase currently needs a distance calculation between two coordinates.

### `FishingSpotRepository` (extended)

```dart
Future<FishingSpot> create({
  required String name,
  required double latitude,
  required double longitude,
  required String waterBodyId,
}) async {
  if (waterBodyId.isEmpty) {
    throw ArgumentError.value(waterBodyId, 'waterBodyId', 'must not be empty');
  }
  final spot = FishingSpot(
    id: _generateId(),
    name: name,
    latitude: latitude,
    longitude: longitude,
    waterBodyId: waterBodyId,
    createdAt: DateTime.now(),
  );
  await _database.into(_database.fishingSpots).insert(spot.toCompanion());
  return spot;
}

Future<FishingSpot> updateWaterBody({
  required String id,
  required String waterBodyId,
}) async {
  if (waterBodyId.isEmpty) {
    throw ArgumentError.value(waterBodyId, 'waterBodyId', 'must not be empty');
  }
  final table = _database.fishingSpots;
  final existing = await (_database.select(table)..where((t) => t.id.equals(id)))
      .getSingleOrNull();
  if (existing == null) {
    throw StateError('Fishing spot "$id" was not found.');
  }
  await (_database.update(table)..where((t) => t.id.equals(id))).write(
    FishingSpotsCompanion(waterBodyId: Value(waterBodyId)),
  );
  return FishingSpot(
    id: existing.id,
    name: existing.name,
    latitude: existing.latitude,
    longitude: existing.longitude,
    waterBodyId: waterBodyId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(existing.createdAt),
  );
}

Future<List<FishingSpot>> getByWaterBodyId(String waterBodyId) async {
  final rows = await (_database.select(_database.fishingSpots)
        ..where((t) => t.waterBodyId.equals(waterBodyId))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .get();
  return [for (final row in rows) row.toDomain()];
}
```

`create` gains one new required parameter (`waterBodyId`) — a deliberate breaking change to this method's signature, since MFS-024 FR-2 makes the relationship mandatory for every fishing spot created from this point on; every existing call site is updated as part of this same document (see [File Plan](#18-file-plan)). `updateWaterBody` is a new, narrow, single-purpose method — mirroring `updateName`'s existing shape exactly — rather than a general-purpose "update" method covering every field at once. `updateName` itself is unchanged. `getByWaterBodyId` mirrors `CatchRepository.getByFishingSpotId`'s existing shape (a single filtered, ordered select, no join), used by the water-body management surface to show a water body's member fishing spots.

---

## 6. Repository Interfaces

None are introduced. Per `docs/development-rules.md` ("Do NOT introduce repository interfaces") and the established, unbroken precedent of every prior TD in this project (TD-004 through TD-023), `WaterBodyRepository` and the extended `FishingSpotRepository` are concrete classes only, constructed directly against `AppDatabase` and passed via constructor injection wherever they are needed.

---

## 7. Domain-to-Database Mapping

### `water_body_mapper.dart` (new)

```dart
extension WaterBodyEntityMapper on WaterBodyEntity {
  WaterBody toDomain() {
    return WaterBody(
      id: id,
      name: name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    );
  }
}

extension WaterBodyCompanionMapper on WaterBody {
  WaterBodiesCompanion toCompanion() {
    return WaterBodiesCompanion.insert(
      id: id,
      name: name,
      createdAt: createdAt.millisecondsSinceEpoch,
    );
  }
}
```

Follows `fishing_spot_mapper.dart`'s own existing extension-method shape exactly — see [Key Design Decision 4](#key-design-decisions).

### `fishing_spot_mapper.dart` (extended)

```dart
extension FishingSpotEntityMapper on FishingSpotEntity {
  FishingSpot toDomain() {
    final resolvedWaterBodyId = waterBodyId;
    if (resolvedWaterBodyId == null) {
      throw StateError(
        'FishingSpot "$id" has no waterBodyId — migration invariant violated.',
      );
    }
    return FishingSpot(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      waterBodyId: resolvedWaterBodyId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    );
  }
}

extension FishingSpotCompanionMapper on FishingSpot {
  FishingSpotsCompanion toCompanion() {
    return FishingSpotsCompanion.insert(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      waterBodyId: Value(waterBodyId),
      createdAt: createdAt.millisecondsSinceEpoch,
    );
  }
}
```

The schema-level column is nullable (Key Design Decision 1), but the domain is not: `toDomain()` fails loudly with a clear `StateError` rather than a bare null-check operator if it ever reads a row that violates the "every fishing spot has a water body" invariant — the same "fail explicitly, never silently paper over a broken invariant" discipline MFS-009 already requires of `CatchMapper` for an unrecognized stored species. This should never be reachable through this application's own repository path; the guard exists for exactly the same reason `CatchMapper`'s equivalent guard does — to turn a hidden data-integrity bug into a loud, immediate failure during testing rather than a silent misbehavior in production. `toCompanion()` wraps `waterBodyId` in `Value(...)` because the underlying column is nullable at the Drift level even though this domain field is always supplied.

---

## 8. Dependency Injection

This project uses **manual constructor injection**, not Riverpod providers or a service locator, for every repository — `flutter_riverpod` is nominally part of the stack (ADR-0001) but is not, in practice, used to wire up any repository anywhere in this codebase today (TD-015/TD-016/TD-017 all note this explicitly). This document follows that existing reality, not the nominal ADR-0001 choice:

- `MapScreen` gains one new field: `late final WaterBodyRepository _waterBodyRepository = WaterBodyRepository(_database);` — the same pattern as its existing `_fishingSpotRepository`/`_catchRepository` fields.
- `_waterBodyRepository` is passed as a constructor parameter to `WaterBodySelectionBottomSheet` (both call sites — the Add Fishing Spot flow and Fishing Spot Details' new action) and to `FishingSpotDetailsBottomSheet` (for the subtitle resolve and the new action).
- `WaterBodyManagementPage` receives `WaterBodyRepository` and `FishingSpotRepository` (for the member-fishing-spots view), threaded from whatever screen opens it (`WaterBodySelectionBottomSheet`).
- `SpeciesStatisticsRepository` needs no new repository instance — it queries `WaterBodies` directly, the same way it already queries `FishingSpots` directly, per [Key Design Decision 5](#key-design-decisions).
- No Riverpod provider, no service locator, no DI framework is introduced.

---

## 9. UI Flow

### Add Fishing Spot (extended)

`map_screen.dart`'s two existing creation paths each gain one new step, inserted between determining the coordinate and naming the exact spot:

```text
_createFishingSpotFromCurrentLocation():
  determine position (unchanged)
    -> WaterBodySelectionBottomSheet.show(context, waterBodyRepository: _waterBodyRepository, latitude: position.latitude, longitude: position.longitude)
       -> if null (cancelled): abort the whole add flow, exactly as today's cancel-anywhere behavior
       -> if a WaterBody: continue
    -> FishingSpotNameBottomSheet.show(context)                              (unchanged)
    -> _fishingSpotRepository.create(name:, latitude:, longitude:, waterBodyId: selected.id)

_promptAndCreateFishingSpot(position):
  same shape, inserted identically after the crosshair position is confirmed, before FishingSpotNameBottomSheet.
```

Cancelling at the new water-body step aborts fishing spot creation entirely (no partial fishing spot is ever created without a water body), the same "cancel anywhere aborts the whole add flow" behavior `FishingSpotNameBottomSheet` already has today.

### `WaterBodySelectionBottomSheet` (new)

```dart
class WaterBodySelectionBottomSheet extends StatefulWidget {
  const WaterBodySelectionBottomSheet({
    super.key,
    required this.waterBodyRepository,
    required this.fishingSpotRepository,
    required this.latitude,
    required this.longitude,
  });

  final WaterBodyRepository waterBodyRepository;
  final FishingSpotRepository fishingSpotRepository;
  final double latitude;
  final double longitude;

  static Future<WaterBody?> show(
    BuildContext context, {
    required WaterBodyRepository waterBodyRepository,
    required FishingSpotRepository fishingSpotRepository,
    required double latitude,
    required double longitude,
  }) {
    return showModalBottomSheet<WaterBody>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => WaterBodySelectionBottomSheet(
        waterBodyRepository: waterBodyRepository,
        fishingSpotRepository: fishingSpotRepository,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  // ...
}
```

Content, top to bottom:

1. *(Deferred in this iteration — see [Key Design Decision 8](#key-design-decisions).)* A static hint line was originally planned here (e.g. "Voit myöhemmin siirtää kalastuspaikkoja saman vesistön alle Hallitse vesistöjä -näkymässä."), satisfying MFS-024 FR-17. It is postponed until closer to a real external release, since no real audience for it exists at this project's current development stage. Revisit before then.
2. **"Lähellä" (nearby) section** — populated from `waterBodyRepository.getNearby(latitude:, longitude:)`; if `.preselected` is non-null, that entry renders pre-selected (e.g. a selected `RadioListTile`/highlighted `ListTile`); the angler can tap any other entry to change the selection, or tap the preselected one again to deselect it before choosing something else. Hidden entirely if `.candidates` is empty.
3. **"Luo uusi vesistö" (create new)** — a text field plus a "Luo" button. While typing, if the trimmed, lowercased text exactly matches an existing water body's name, a small inline hint appears ("Vesistö tällä nimellä on jo olemassa — valitse se listasta?") without blocking the create action (FR-6: duplicates are permitted, never blocked).
4. **Full list** — every water body from `waterBodyRepository.loadAll()`, alphabetical, with a simple client-side text filter (no server/database search query — the expected total count is small; see [Performance Considerations](#16-performance-considerations)).
5. **"Hallitse vesistöjä" action** — pushes `WaterBodyManagementPage`; returning from it reloads this sheet's full list and nearby section (in case a rename/delete happened).

Selecting a candidate (nearby, full list, or newly created) pops the sheet with that `WaterBody`.

### Fishing Spot Details (extended)

`FishingSpotDetailsBottomSheet` gains:

- A new field, `late Future<WaterBody?> _waterBodyFuture = widget.waterBodyRepository.getById(widget.fishingSpot.waterBodyId);`, loaded the same way `_catchesFuture` already is.
- A small subtitle beneath the fishing spot's name in `_detailsContent()`, rendering the resolved water body's name once loaded (a `FutureBuilder`, mirroring `_buildCatchesSection`'s own loading/error handling shape) — satisfying MFS-024 FR-9's "exact-context views may additionally show the parent water body as context."
- A new action, **"Vaihda vesistö"** (change water body), alongside the existing "Muokkaa nimeä"/"Lisää saalis"/"Poista" — opens `WaterBodySelectionBottomSheet.show(context, waterBodyRepository:, fishingSpotRepository:, latitude: widget.fishingSpot.latitude, longitude: widget.fishingSpot.longitude)`. On a non-null result: call `fishingSpotRepository.updateWaterBody(id: widget.fishingSpot.id, waterBodyId: selected.id)`, then reload `_waterBodyFuture`, then show a confirming `SnackBar` ("Vesistö vaihdettu").
- No new `FishingSpotDetailsResult` variant is introduced. Changing a water body does not affect the map marker (FR-11) or the fishing spot's own identity/name/coordinates, so `MapScreen` needs no new signal — this is handled entirely within the bottom sheet's own local state, the same way its existing catches-reload-after-visiting-Catch-Details already is.

### `WaterBodyManagementPage` (new)

A normal pushed page (`MaterialPageRoute`), mirroring the Statistics feature's own established push pattern:

- Loads `waterBodyRepository.loadAllWithSpotCounts()`; renders a scrollable list, one row per water body: name, fishing-spot count, a rename action, a delete action.
- Tapping a row expands (or pushes a small detail view) listing its member fishing spots via `fishingSpotRepository.getByWaterBodyId(id)` — read-only, no navigation onward from an individual fishing spot in this milestone (that already exists via the map marker/Fishing Spot Details path).
- **Rename:** a simple `showDialog` with one `TextField` (prefilled with the current name) and Peruuta/Tallenna buttons — the smallest correct implementation, avoiding a new bottom-sheet file for a single-field edit. On confirm: `waterBodyRepository.rename(id:, name:)`, then reload the list.
- **Delete:** if `fishingSpotCount > 0`, show a clear, non-destructive `AlertDialog` explaining the fishing spots must be moved or removed first (no delete attempted). If `fishingSpotCount == 0`, show the existing confirmation-dialog pattern (mirroring `FishingSpotDetailsBottomSheet`'s own "Poistetaanko...?" dialog), then `waterBodyRepository.delete(id)` and reload the list.
- Loading/empty/error states follow the same conventions already established by the Statistics feature's pages (a clear loading indicator, a clear "no water bodies yet" empty state, a clear retryable error message).

This remains a small, focused surface — no filters, no sorting options beyond the fixed alphabetical order, no statistics — per the fixed scope decision and MFS-024 FR-16.

---

## 10. Validation Rules

| Value | Rule | Enforced by |
|---|---|---|
| `WaterBody.name` | Required; not empty after trimming leading/trailing whitespace. | `WaterBodySelectionBottomSheet`'s create field (trims before calling `create`) **and** `WaterBodyRepository.create`/`rename` independently (trims and checks again) — the same "UI validates, repository is the defensive authority" split already used throughout this project. |
| `WaterBody` name duplicates | Permitted; never blocked, merged, or erred. An exact (trimmed, case-insensitive) match is surfaced as a non-blocking hint only. | `WaterBodySelectionBottomSheet` (client-side string comparison against the already-loaded list — no database query). |
| `FishingSpot.waterBodyId` | Required; every creation and every water-body change must supply one. | Compile-time (`required` constructor/method parameters) plus a defensive non-empty `ArgumentError` check in `FishingSpotRepository.create`/`updateWaterBody`, mirroring `_validateLureVariantId`'s existing shape. |
| Water body deletion | Blocked while `fishingSpotCount > 0`. | `WaterBodyRepository.delete` (proactive count check) **and** the database's own `KeyAction.restrict` foreign key (defense-in-depth — see Key Design Decision 2). |

---

## 11. Query Strategy

| Query | Shape | Notes |
|---|---|---|
| `WaterBodyRepository.loadAll()` | Single `SELECT` on `WaterBodies`, ordered by name. | Powers the picker's full list. |
| `WaterBodyRepository.getById(id)` | Single `SELECT ... WHERE id = ?`. | Powers Fishing Spot Details' subtitle. |
| `WaterBodyRepository.loadAllWithSpotCounts()` | One `LEFT OUTER JOIN` (`WaterBodies ⨝ FishingSpots`), aggregated in Dart. | A `LEFT OUTER JOIN` (not `INNER`) is required so a water body with zero fishing spots still appears in the management list — mirroring why `GeneralCatchStatisticsRepository` chose `innerJoin` for its own case (every catch's fishing spot always exists) while this case is the opposite (a water body may legitimately have none). Counting/grouping is done in Dart, the same "no SQL `GROUP BY`" convention already established by `LureStatisticsRepository`/`GeneralCatchStatisticsRepository`. |
| `WaterBodyRepository.getNearby(lat, lon)` | One `INNER JOIN` (`WaterBodies ⨝ FishingSpots`), distance computed per row in Dart, minimum kept per water body, sorted ascending, top `limit` kept. | `innerJoin` here is intentional and different from `loadAllWithSpotCounts`: a water body with no fishing spots has no coordinate to measure "nearby" from at all, so it can never be a nearby candidate — correctly excluded by the join. |
| `WaterBodyRepository._fishingSpotCount(id)` | `selectOnly` with a `COUNT` aggregate, filtered by `waterBodyId`. | Used only by `delete()`'s pre-check. |
| `FishingSpotRepository.getByWaterBodyId(id)` | Single filtered, ordered `SELECT` on `FishingSpots`. | Mirrors `CatchRepository.getByFishingSpotId`'s existing shape exactly. |
| `SpeciesStatisticsRepository`'s existing query | Extended from a two-way to a three-way join (`Catches ⨝ FishingSpots ⨝ WaterBodies`). | See [Statistics Implications](#12-statistics-implications). |

No SQL full-text search, no spatial index, and no database-level distance function is used anywhere — every distance and every count/aggregate this milestone needs is computed in Dart after a single query, consistent with every existing Statistics repository's own approach.

---

## 12. Statistics Implications

### `SpeciesCatchEntry` (extended)

```dart
class SpeciesCatchEntry {
  const SpeciesCatchEntry({
    required this.catchModel,
    required this.fishingSpot,
    required this.waterBody,
  });

  final Catch catchModel;
  final FishingSpot fishingSpot;
  final WaterBody waterBody;
}
```

`fishingSpot` is kept (still required to open `CatchDetailsPage`, unchanged); `waterBody` is added, per [Key Design Decision 9](#key-design-decisions).

### `SpeciesStatisticsRepository` (extended)

The existing species-filtered join grows one more `innerJoin`:

```dart
final query = _database.select(_database.catches).join([
  innerJoin(
    _database.fishingSpots,
    _database.fishingSpots.id.equalsExp(_database.catches.fishingSpotId),
  ),
  innerJoin(
    _database.waterBodies,
    _database.waterBodies.id.equalsExp(_database.fishingSpots.waterBodyId),
  ),
])..where(_database.catches.species.equals(species.name));
```

`innerJoin` (not left outer) is correct for both new and existing joins here: `Catches.fishingSpotId` and, after this migration, `FishingSpots.waterBodyId` are both always populated for every real row the application ever produces, so neither join can ever exclude a row that should be present — the same reasoning TD-020 already documented for its own `Catches ⨝ FishingSpots` join. Row-mapping gains one line: `waterBody: row.readTable(_database.waterBodies).toDomain()`.

### `RecordCatchCard` (extended)

```dart
Text(
  widget.entry.waterBody.name,   // was: widget.entry.fishingSpot.name
  style: Theme.of(context).textTheme.bodySmall,
),
```

And its `_semanticLabel` helper's `fishingSpot.name` reference is swapped to `waterBody.name` identically.

### No other Statistics change

`GeneralCatchStatisticsRepository`, `FishingSpotStatisticsRepository`, `LureStatisticsRepository`, `general_catch_statistics_tab.dart` (including its existing "Kalastuspaikat" Fishing Spot List, which stays scoped to the exact fishing spot), `fishing_spot_statistics_page.dart`, `species_statistics_page.dart` (beyond its use of the now-extended `RecordCatchCard`), and `CatchListItem` are all untouched — per MFS-024's explicit "no re-scoping of MFS-022's Fishing Spot List/Fishing Spot Statistics" boundary.

---

## 13. Error Handling

| Scenario | Behavior |
|---|---|
| Creating a water body with an empty/whitespace-only name | Blocked before any repository call by the picker's own check; if reached directly, `WaterBodyRepository.create`/`rename` throws `ArgumentError`. |
| Deleting a non-empty water body | `WaterBodyRepository.delete` throws `StateError` before attempting any `DELETE`; the management page shows a clear, non-destructive dialog explaining the fishing spots must be moved or removed first. The database's own `KeyAction.restrict` would also reject the raw `DELETE` if this proactive check were ever bypassed — defense-in-depth, not the primary path. |
| Reading water bodies fails (e.g. a database error) | The picker and management page each show their own clear, retryable error state, consistent with every other loading surface in this application; no crash. |
| A `FishingSpotEntity` row is read with a `null` `waterBodyId` | Not expected to occur through this application's own repository path after migration. Handled defensively anyway: `FishingSpotEntityMapper.toDomain()` throws a clear `StateError` rather than crashing on a bare null-check operator or silently substituting a placeholder. |
| Migration failure | Mitigated by the migration running inside Drift's own transaction (all-or-nothing) and verified by a dedicated schema-snapshot migration test (including the back-fill step) before implementation is considered complete. |
| Cancelling the water-body selection step during fishing spot creation | Aborts the entire creation flow — no fishing spot is ever created without a water body, consistent with the existing "cancel anywhere aborts the add flow" behavior. |

---

## 14. Accessibility

- The water-body selection sheet's nearby section, create-new field, and full list each expose accessible labels consistent with this application's existing form/list accessibility (Add Catch, Lure Catalog's search/filter controls).
- A preselected nearby candidate is announced as selected (not merely visually highlighted) to assistive technology, and remains changeable via the same accessible controls as any other entry.
- The new "Vaihda vesistö" action and the water-body subtitle in Fishing Spot Details expose accessible labels consistent with that bottom sheet's existing "Muokkaa nimeä"/"Poista" actions.
- `WaterBodyManagementPage`'s rows expose a semantic label combining the water body's name and its fishing-spot count, consistent with `CatchCountRow`'s existing precedent in the Statistics feature.
- `RecordCatchCard`'s updated semantic label continues to read naturally with `waterBody.name` in place of `fishingSpot.name` — no structural change to the label's shape, only which location string is included.
- Tap targets and text throughout follow the application's existing Material 3 sizing and text-scaling conventions.

---

## 15. Testing Strategy

Follows the same layered testing philosophy as every prior TD in this project: domain tests, a real schema-snapshot migration test, repository tests, mapper tests, widget tests for every new/changed presentation surface, and a physical-device pass.

**Domain** (`water_body_test.dart`, new; `fishing_spot_test.dart`, extended):
`WaterBody` constructs successfully with a non-empty name; rejects (via `assert`) an empty name. `FishingSpot` constructs successfully with a non-empty `waterBodyId`; rejects (via `assert`) an empty one.

**Migration** (extending the established `_LegacyAppDatabase` schema-snapshot pattern, `fishing_spot_migration_test.dart` or an added case in the existing catches migration-test area — using a real schema-7 snapshot, not the current table classes):
seed at least two pre-existing `FishingSpot` rows (distinct names) at schema 7, with no `water_bodies` table and no `waterBodyId` column; upgrade to 8; verify: the `water_bodies` table exists; each pre-existing fishing spot now has a non-null `waterBodyId`; each auto-created water body's name exactly matches its originating fishing spot's pre-migration name; every pre-existing fishing spot's coordinates/id/createdAt are unchanged; every pre-existing catch (seeded alongside, referencing one of the fishing spots) survives with its `lureVariantId`/`notes` intact; a new `WaterBody` and a new `FishingSpot` referencing it can be created and read back correctly after the upgrade.

**Repository — `WaterBodyRepository`** (new):
`create` trims and rejects empty/whitespace-only names; `create` permits a duplicate name; `loadAll` returns alphabetical order; `getById` returns `null` for an unknown id; `rename` trims, rejects empty names, and persists the change; `delete` succeeds for an empty water body; `delete` throws `StateError` for a non-empty one and performs no database write; `loadAllWithSpotCounts` returns correct counts including a zero-count water body; `getNearby` returns candidates ordered by ascending distance; `getNearby` preselects a single candidate within the threshold and with sufficient margin over the second-nearest; `getNearby` preselects nothing when the nearest exceeds the threshold; `getNearby` preselects nothing when two candidates are within the margin of each other; `getNearby` returns an empty result when no water body has any fishing spot.

**Repository — `FishingSpotRepository`** (extended):
`create` requires and persists `waterBodyId`; `create` rejects an empty `waterBodyId`; `updateWaterBody` changes only the water-body reference, leaving name/coordinates/id/createdAt untouched; `updateWaterBody` on an unknown id throws `StateError`; `getByWaterBodyId` returns only fishing spots referencing that water body, correctly ordered; existing `updateName`/`delete`/`loadAll`/`watchAll` behavior is unchanged (regression coverage).

**Mapper** (extended):
`WaterBody` round-trips through `toDomain()`/`toCompanion()` unchanged; `FishingSpot` round-trips including `waterBodyId`; `FishingSpotEntityMapper.toDomain()` throws `StateError` when given a row with a `null` `waterBodyId`, seeded directly at the SQL layer with foreign key enforcement temporarily disabled — mirroring the existing dangling-reference testing technique already established for Lure-Based Catch Statistics (TD-019).

**Widget — `WaterBodySelectionBottomSheet`** (new):
nearby candidates render in distance order; a within-threshold, sufficiently-separated candidate is preselected and visibly so; the angler can change or clear the preselected choice; the full list renders every water body and supports client-side text filtering; creating a new water body with a duplicate name shows the non-blocking hint and still allows creation; an empty/whitespace-only create attempt is blocked with a clear message; tapping "Hallitse vesistöjä" navigates to `WaterBodyManagementPage` and returning reloads the sheet's lists. *(The static hint line itself is out of scope for this iteration — see Key Design Decision 8 — and has no test coverage until it is implemented.)*

**Widget — Add Fishing Spot flow** (extended, both creation paths in `map_screen_test.dart` or the equivalent existing test surface):
the water-body step appears after location is determined and before naming; selecting/creating a water body and completing naming creates a fishing spot with the correct `waterBodyId`; cancelling at the water-body step creates no fishing spot at all.

**Widget — `FishingSpotDetailsBottomSheet`** (extended):
the water-body subtitle renders the currently resolved water body's name; "Vaihda vesistö" opens the selection sheet pre-populated with nearby candidates computed from this fishing spot's own coordinates; selecting a different water body updates the persisted fishing spot and the displayed subtitle, and leaves the fishing spot's name/coordinates/catch list unaffected; existing "Muokkaa nimeä"/"Lisää saalis"/"Poista"/catch-list behavior is unchanged (regression coverage).

**Widget — `WaterBodyManagementPage`** (new):
lists every water body with its correct fishing-spot count; renaming persists and reloads the list; attempting to delete a non-empty water body shows the explanatory dialog and performs no deletion; deleting an empty water body requires confirmation and then succeeds; loading/empty/error states render distinctly.

**Widget — `RecordCatchCard` / Species Statistics** (extended):
the location line and semantic label now render `waterBody.name`, not `fishingSpot.name`; tapping the card still opens `CatchDetailsPage` for the correct catch and fishing spot (regression check that `entry.fishingSpot` is still correctly threaded through even though it is no longer displayed here).

**Regression — confirmed no required changes:**
`GeneralCatchStatisticsRepository`/`general_catch_statistics_tab.dart` (including its Fishing Spot List), `FishingSpotStatisticsRepository`/`fishing_spot_statistics_page.dart`, `LureStatisticsRepository`, `CatchListItem`, `CatchDetailsPage`, `CatchRepository`, and every `catch_photos`/`lure_catalog`/`personal_tackle_box` file are all unaffected and require no test changes.

**Integration/physical Android testing:**
create a fishing spot and confirm the nearby/create-new water-body step behaves correctly on-device; reuse an existing water body for a second fishing spot; change an existing fishing spot's water body and confirm its marker position and catch history are unaffected; verify the migration on a real pre-existing installation (existing fishing spots each receive their own correctly named water body, all catches/photos/notes/lure links intact); rename and delete water bodies via the management surface, including the blocked-while-non-empty case; verify Species Statistics' Record Catch card shows the water body; verify full offline/airplane-mode operation throughout.

---

## 16. Performance Considerations

- **Migration back-fill:** O(n) over existing fishing spots, two small writes each (one insert, one update), inside one transaction. At this application's expected personal-use scale (tens to low hundreds of fishing spots), this completes well within an acceptable app-startup window; it is not expected to need batching or a progress indicator.
- **`getNearby`/`loadAllWithSpotCounts`:** each reads the full `WaterBodies ⨝ FishingSpots` join with no `WHERE` pre-filter, computing distances/counts in Dart afterward — the same "aggregate the whole joined result in Dart, no SQL `GROUP BY`" approach already proven by `GeneralCatchStatisticsRepository`/`LureStatisticsRepository` at this application's scale.
- **No index is added on `FishingSpots.waterBodyId` in this milestone.** The queries that filter by it (`getByWaterBodyId`, `_fishingSpotCount`) are expected to run against a small total row count in this personal-use application; a full-table scan is fine. If this table grows large enough for it to matter, adding `@TableIndex` is a trivial, purely additive future migration — the same deferred-index reasoning TD-017 already used for `Catches.lureVariantId`.
- **No caching is introduced.** Every query in this document runs at most once per relevant user action (opening the picker, opening the management page, saving a fishing spot); there is no repeated-lookup pattern to protect against.
- **The client-side search filter in the picker's full list is plain in-memory string filtering**, not a database query — appropriate given the expected total water-body count is small (nothing like the Lure Catalog's thousands-of-variants scale that justified a precomputed `searchText` column there).

---

## 17. Future Extensibility

- **Optional water-body metadata** (depth, vegetation, species, weather characteristics — `docs/roadmap.md` §3.4/§3.5) can be added later as additive, nullable columns on `WaterBodies`, with no remodel of anything in this document.
- **Automatic map-based water-body detection** (`docs/roadmap.md` §3.4) can be added later as an additional candidate source feeding into the same `NearbyWaterBodies` shape `getNearby()` already returns — the picker's contract (a ranked candidate list plus an optional preselection) does not need to change for a future data source to plug into it.
- **Water-body-level statistics** (`docs/roadmap.md` §3.4) would be additive: a new `WaterBodyStatisticsRepository`, mirroring `FishingSpotStatisticsRepository`'s existing shape exactly, reading `Catches ⨝ FishingSpots ⨝ WaterBodies` the same way `SpeciesStatisticsRepository` now does.
- **Feature extraction:** if `fishing_spots` ever grows large enough to justify splitting `WaterBody` into its own top-level feature (an option MFS-024/ADR-0007 explicitly left open, closed for *this* milestone only by this task's own fixed decision), every file this document adds is already scoped to its own concept (its own domain/table/mapper/repository/widget files) with only the `FishingSpot.waterBodyId` field and one mapper import as the coupling point — a future extraction would be a mechanical move, not a redesign.
- **Cloud synchronization:** `WaterBody.id`/`FishingSpot.waterBodyId` are plain, app-generated stable string identifiers, structurally identical in kind to every other identifier in this codebase (`FishingSpot.id`, `Catch.fishingSpotId`) — nothing in this design is any more or less sync-ready than the rest of the application (ADR-0001/ADR-0005).
- **Multiple simultaneous management surfaces or bulk operations** (e.g. multi-select move, batch delete) are not designed here and are not implied by anything in this document — `WaterBodyManagementPage` operates on one water body at a time throughout.

---

## 18. File Plan

### Expected Files To Create

```text
lib/features/fishing_spots/domain/water_body.dart
lib/features/fishing_spots/domain/water_body_with_spot_count.dart
lib/features/fishing_spots/domain/nearby_water_bodies.dart
lib/features/fishing_spots/data/water_bodies_table.dart
lib/features/fishing_spots/data/water_body_mapper.dart
lib/features/fishing_spots/data/water_body_repository.dart
lib/features/fishing_spots/data/haversine.dart
lib/features/fishing_spots/presentation/widgets/water_body_selection_bottom_sheet.dart
lib/features/fishing_spots/presentation/widgets/water_body_management_page.dart

test/features/fishing_spots/domain/water_body_test.dart
test/features/fishing_spots/domain/fishing_spot_test.dart
test/features/fishing_spots/data/fishing_spot_migration_test.dart
test/features/fishing_spots/data/water_body_repository_test.dart
test/features/fishing_spots/data/fishing_spot_repository_test.dart
test/features/fishing_spots/data/fishing_spot_mapper_test.dart
test/features/fishing_spots/presentation/widgets/water_body_selection_bottom_sheet_test.dart
test/features/fishing_spots/presentation/widgets/water_body_management_page_test.dart
```

### Expected Files To Modify

```text
lib/core/database/app_database.dart                                          (schema 7 -> 8; createTable + addColumn + back-fill)
lib/features/fishing_spots/domain/fishing_spot.dart                           (add waterBodyId)
lib/features/fishing_spots/data/fishing_spots_table.dart                     (add waterBodyId column + FK)
lib/features/fishing_spots/data/fishing_spot_mapper.dart                      (map waterBodyId; fail-fast guard)
lib/features/fishing_spots/data/fishing_spot_repository.dart                  (create requires waterBodyId; add updateWaterBody, getByWaterBodyId)
lib/features/fishing_spots/presentation/widgets/fishing_spot_details_bottom_sheet.dart  (subtitle + "Vaihda vesistö" action)
lib/features/map/presentation/map_screen.dart                                 (new WaterBodyRepository field; insert selection step in both creation paths)
lib/features/statistics/domain/species_catch_entry.dart                       (add waterBody field)
lib/features/statistics/data/species_statistics_repository.dart               (extend join to WaterBodies)
lib/features/statistics/presentation/widgets/record_catch_card.dart           (display waterBody.name; update semantic label)
test/features/fishing_spots/domain/fishing_spot_test.dart                     (new assertion coverage)
test/features/fishing_spots/data/fishing_spot_repository_test.dart           (new coverage)
test/features/fishing_spots/data/fishing_spot_mapper_test.dart               (new coverage, incl. fail-fast case)
test/features/statistics/data/species_statistics_repository_test.dart        (extended: waterBody resolution)
test/features/statistics/presentation/widgets/record_catch_card_test.dart    (extended: waterBody display)
```

**Not confined to `fishing_spots`.** `lib/core/database/app_database.dart` is modified because the Drift schema version and migration strategy are owned by the Core Database, not by any feature (ADR-0003, ADR-0006) — the same shape every prior schema-changing TD in this project has taken. `lib/features/map/presentation/map_screen.dart` and the three `lib/features/statistics/...` files are modified as the two small, additive touches described in [Overview](#1-overview-and-folder-structure).

**No other existing file is modified.** `lib/features/catches/`, `lib/features/catch_photos/`, `lib/features/lure_catalog/`, `lib/features/personal_tackle_box/`, and every Statistics file not explicitly listed above (including `general_catch_statistics_tab.dart`, `fishing_spot_statistics_page.dart`, `lure_statistics_tab.dart`, and `catch_count_row.dart`) are untouched.

Modify generated Drift files (`app_database.g.dart`) only through code generation (`dart run build_runner build --delete-conflicting-outputs`).

---

## 19. Implementation Order

1. Confirm the live schema version is still `7`.
2. Add `WaterBody`, `WaterBodyWithSpotCount`, `NearbyWaterBodies` (domain).
3. Add `WaterBodies` Drift table.
4. Extend `FishingSpot` domain and `FishingSpots` table with `waterBodyId`.
5. Bump `schemaVersion` to `8`; add the `if (from < 8)` branch and the `_backfillWaterBodiesForExistingFishingSpots` helper.
6. Run Drift code generation.
7. Add `water_body_mapper.dart`; extend `fishing_spot_mapper.dart` (including the fail-fast guard).
8. Add `water_body_repository.dart` (including `haversine.dart`); extend `fishing_spot_repository.dart`.
9. Add the schema-7 legacy-snapshot migration test (including back-fill assertions); add domain, mapper, and repository tests.
10. Build `water_body_selection_bottom_sheet.dart`.
11. Wire the new step into both of `map_screen.dart`'s fishing-spot-creation paths.
12. Add the "Vaihda vesistö" action and water-body subtitle to `fishing_spot_details_bottom_sheet.dart`.
13. Build `water_body_management_page.dart`; wire it from the selection sheet.
14. Extend `species_catch_entry.dart`/`species_statistics_repository.dart`; update `record_catch_card.dart`.
15. Add/extend widget tests for every new/changed presentation surface.
16. `dart format .`, `flutter analyze`, `flutter test`.
17. Architecture review.
18. Physical Android testing.

---

## 20. Risks and Mitigations

| Risk | Category | Mitigation |
|---|---|---|
| This is the project's first migration that writes data (not just schema), inside `onUpgrade`. An unforeseen interaction with Drift's migration transaction could behave differently from every prior, schema-only migration. | Migration | Verified with a dedicated schema-snapshot test asserting the back-fill's actual effect (correct names, no orphaned rows, existing data intact), plus a physical-device upgrade test against a real pre-existing installation before release. |
| `FishingSpots.waterBodyId` is nullable at the schema level despite being conceptually mandatory — a future code path could theoretically insert a null. | Data integrity | The only write path is `FishingSpotRepository`, whose `create`/`updateWaterBody` both require a non-empty `waterBodyId`; the mapper additionally fails loudly rather than silently on read if the invariant is ever violated. Accepted, consistent with how this project already handles other invariants the schema alone cannot express (e.g. `Catch.notes`'s length limit). |
| The preselection threshold/margin values are illustrative starting defaults, not derived from real usage or real-world GPS accuracy data, and may preselect wrongly or fail to preselect a genuinely obvious match. | Product/UX | Explicitly documented as tuning parameters, not architectural decisions (see [Key Design Decision 7](#key-design-decisions)); named, centrally located constants, trivially adjusted during implementation and physical testing with no structural change; the angler can always change or reject a preselected suggestion (never authoritative), per MFS-024 FR-5. |
| Adding a mandatory step to fishing spot creation lengthens an already-established flow. | UX | The nearby-first ordering and optional preselection keep the common case (adding another spot on an already-used lake) a single tap; creating a brand-new water body is one text field and one button. |
| The `WaterBodySelectionBottomSheet` is reused in two different contexts (creation and editing) with slightly different nearby-coordinate sources (a new, unsaved position vs. an existing fishing spot's own coordinates) — a subtle bug could conflate the two. | Correctness | Both call sites pass `latitude`/`longitude` explicitly as constructor parameters; the widget itself has no notion of "creating" vs. "editing" and cannot confuse the two, since it never reads a fishing spot's identity, only the coordinates it is given. |
| Extending `SpeciesStatisticsRepository`'s join to three tables could regress its existing species-filtering or ordering behavior. | Regression | Existing `SpeciesStatisticsRepository`/`SpeciesStatisticsPage` tests continue to run unmodified in addition to the new `waterBody`-specific assertions; the species filter and ordering logic themselves are not touched, only the joined column set and one additional `readTable` call. |

---

## Dependencies

No new external package dependencies. This document reuses, unchanged:

- Flutter, Dart (including `dart:math` for the new haversine calculation)
- Drift (per ADR-0005), including this project's first migration-time data write
- The existing Repository pattern, feature-first structure, and manual constructor injection (ADR-0001, ADR-0003, ADR-0006) — `flutter_riverpod` is not used, for the same reasons already documented in TD-015/TD-016/TD-017
- The existing `FishingSpot` domain model, `FishingSpotRepository`, and `FishingSpots` table (MFS-004/TD-004), extended in place
- The existing `SpeciesCatchEntry`/`SpeciesStatisticsRepository`/`RecordCatchCard` (MFS-021/TD-021), extended additively
- The existing schema-snapshot migration-test pattern (TD-017, TD-023)

---

## Validation

```bash
dart format .
flutter analyze
flutter test
```

All must pass. Review generated Drift changes for exactly the expected scope (new `WaterBodies` table, new `waterBodyId` column on `FishingSpots`, schema version `8`). Confirm the schema version and migration are correct against the repository's actual current state before implementing, in case it has moved past `7` since this document was written.

---

## Definition of Done

- The implementation satisfies all requirements in MFS-024 and the decisions recorded in ADR-0007.
- The implementation follows TD-024, or documents and justifies each deviation.
- `WaterBody` exists as a persistent domain entity inside the `fishing_spots` feature, with no new top-level feature directory.
- Every `FishingSpot` created after this milestone requires and stores a `waterBodyId`.
- A water body can be created, reused across multiple fishing spots, and renamed.
- Nearby water bodies are presented before the full list when creating or editing a fishing spot, with a single clearly relevant candidate preselected when appropriate, always changeable.
- An existing fishing spot's water body can be changed without affecting its coordinates, name, or catch history; the map marker is unaffected.
- A water body containing one or more fishing spots cannot be deleted; an empty one can be, with confirmation.
- Deleting a fishing spot continues to cascade-delete its catches exactly as before, unaffected by this milestone.
- Every fishing spot that existed before this milestone automatically belongs to its own automatically created, correctly named water body after upgrading, with all existing data intact.
- The underlying migration and voluntary reorganization capability (FR-14, FR-7, FR-12, FR-18) are complete and require no angler action. The post-migration hint text itself (FR-17) is deferred per [Key Design Decision 8](#key-design-decisions) and is **not** part of this iteration's Definition of Done — reintroducing it is recommended before any release to real external users, pending product confirmation at that time.
- A minimal water-body management surface supports viewing, renaming, seeing member fishing spots, and empty-only deletion.
- Species Statistics' Record Catch card shows the water body, not the exact fishing spot, in its location line; navigation to Catch Details from it is unaffected.
- No change to `Catch`, `CatchPhoto`, `LureCatalogEntry`/`LureVariant`, or `TackleBoxEntry`; `catch_photos`, `lure_catalog`, and `personal_tackle_box` are functionally and structurally unchanged.
- No repository interface, service layer, use-case layer, or DAO layer is introduced anywhere.
- `dart format .`, `flutter analyze`, and `flutter test` all pass.
- Architecture review is completed.
- Physical Android testing is completed.
- Documentation (`docs/project-status.md`, `docs/roadmap.md`) is updated in a separate, subsequent step — not part of this document's own completion.

---

## Implementation Notes

Implementation followed this document's domain, database, repository, dependency-injection, UI, and statistics design as specified. All items in the Definition of Done are satisfied except physical Android testing (not performed in this environment) and the two documentation-update steps explicitly deferred to a separate step. `dart format .`, `flutter analyze`, and `flutter test` all pass (735/735 automated tests, 8 pre-existing/accepted info-level lints, none introduced). The following deviations and discoveries were made during implementation:

**1. Path correction: `fishing_spots` has no `data/local/` subdirectory.** This document's Current State table and code samples assumed `fishing_spots_table.dart` lived under `data/local/`, mirroring `catches`/`catch_photos`/`lure_catalog`. The actual codebase keeps `fishing_spots_table.dart`, `fishing_spot_mapper.dart`, and `fishing_spot_repository.dart` directly in `data/`, with no `local/` subdirectory. `water_bodies_table.dart` and `haversine.dart` were placed alongside them in `data/` (not `data/local/`), and every path reference in this document has been corrected accordingly. This is a documentation correction, not an architectural change — `fishing_spots`' actual file-ownership rules (ADR-0006) are unaffected.

**2. `fishing_spot_repository_test.dart`, `fishing_spot_mapper_test.dart`, and `fishing_spot_migration_test.dart` did not previously exist.** This document's Testing Strategy referred to these as "extended," implying pre-existing files. None existed before this milestone (only `fishing_spot_details_bottom_sheet_test.dart` did). All three were created new, per §15's described coverage.

**3. Discovered ripple effect: every pre-existing legacy-schema-snapshot migration test that reused the live `FishingSpots` table class for its own `onCreate` step broke, because that class now includes `waterBodyId`.** Four pre-existing migration tests, in features unrelated to this milestone (`catch_migration_test.dart`'s v5 and v6 snapshots, `catch_photos_database_test.dart`'s v2 snapshot, `lure_catalog_database_test.dart`'s v3 snapshot, `tackle_box_entries_database_test.dart`'s v4 snapshot), called `migrator.createTable(fishingSpots)` to set up their own legacy `fishing_spots` table, relying on the live class correctly representing every schema version below their own migration's focus. Adding `waterBodyId` to that live class silently changed what those four calls produced, causing `ALTER TABLE fishing_spots ADD COLUMN water_body_id` to fail with "duplicate column name" when the real `AppDatabase` later replayed the 7→8 step. Fixed by replacing `migrator.createTable(fishingSpots)` with a literal `CREATE TABLE fishing_spots (...)` matching the true pre-schema-8 five-column shape in all four files — the same historical-raw-SQL discipline this project already applies to `catches` in exactly these same files, just not previously needed for `fishing_spots`. No production code changed as a result; this was purely a latent assumption in pre-existing test fixtures, now made explicit.

**4. Discovered and fixed: disposing the rename dialog's `TextEditingController` synchronously after `showDialog` returned raced the dialog's own exit animation**, corrupting the widget tree ("Tried to build dirty widget in the wrong build scope") and cascading into unrelated tests run afterward in the same file. Fixed in `WaterBodyManagementPage._rename()` by no longer disposing that controller explicitly — it is a plain `TextEditingController` with no ticker or other resource requiring prompt disposal for a single, short-lived dialog. Caught by `water_body_management_page_test.dart`'s rename test.

**5. `_buildWaterBodySubtitle()`'s initial loading state ("Ladataan...") was simplified to no text at all.** Showing it duplicated the Fishing Spot Details sheet's own existing "Ladataan..." text for its catches section, breaking `find.text('Ladataan...')`'s existing `findsOneWidget` expectation in a pre-existing test. Since this subtitle is small and secondary, it now simply renders nothing until resolved, rather than introducing a second, differently-worded loading string.

**6. Pre-existing, latent flakiness in `FishingSpotRepository`/`WaterBodyRepository`'s shared `_generateId()` scheme (a bare `DateTime.now().microsecondsSinceEpoch`) surfaced repeatedly across the test suite** — both pre-existing tests (several `general_catch_statistics_repository_test.dart`/`species_statistics_repository_test.dart`/`fishing_spot_statistics_repository_test.dart` cases creating a second fixture fishing spot immediately after `setUp`'s own) and new tests written for this milestone. This is not introduced by this milestone — the id scheme is unchanged and already shared by `CatchRepository`, `PersonalTackleBoxRepository`, and others — but this milestone's tests create more fishing spots, in faster succession, than before, making the pre-existing race more likely to manifest. Mitigated the same way this project already does elsewhere: a short real (`Future.delayed`, not fake-clock) delay before a second same-millisecond-risk creation. No production id-generation code was changed; doing so would be a broader, cross-repository change out of this milestone's scope — see the accompanying report's architectural observations for whether it is worth addressing separately.
