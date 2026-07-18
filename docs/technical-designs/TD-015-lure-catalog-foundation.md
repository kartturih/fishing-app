# TD-015 — Lure Catalog Foundation

## Status

Draft (Revision 2 — see [Revision Notes](#revision-notes))

## Goal

Implement the approved two-level Lure Catalog domain model (`LureModel` → `LureVariant`), its local Drift persistence, a small versioned and idempotent development seed dataset, a read-only repository, and the browse/search/filter/details presentation, fully satisfying MFS-015.

The implementation shall satisfy MFS-015.

---

## Revision Notes

This is the second revision of TD-015, made before any implementation. Eight changes were required by architecture review of the first draft:

1. Riverpod is no longer introduced for this feature. The repository is constructed manually, exactly like every other feature in this codebase.
2. Seed insertion is no longer a one-shot `insertOrIgnore`. It is a versioned, idempotent reconciliation that can correct and extend application-managed rows without touching rows a future server sync may already own.
3. Catalog identity is no longer a human-readable slug. It is an opaque, authored UUID-style string.
4. `LureModels` now has `createdAt`/`updatedAt`, matching `LureVariants`.
5. The Map-screen entry point is now explicitly documented as temporary and not a statement that Lure Catalog is a map sub-feature.
6. File counts below are corrected and exact.
7. Finnish (ä/ö) case-insensitive search is now a concrete, designed mechanism, not an implementation-time question.
8. Obsolete seed entries are retired (hidden from browsing), never deleted, so a future reference to them cannot break.

Nothing about the approved two-level structure, the single read-only repository, the joined `LureCatalogEntry` read-model, open-string `lureType` codes, canonical millimeter/gram units, local placeholder image references, or the schema 3 → 4 version change has changed.

---

## Scope

Implement:

- `LureModel` and `LureVariant` domain models
- a `LureCatalogEntry` joined read-model for list/search/details use
- `lureType` (and `buoyancy`) handled as open, stable string codes with localized-label lookup and unknown-code fallback
- `LureModels` and `LureVariants` Drift tables, including `createdAt`/`updatedAt` on both
- database migration (schema 3 → 4)
- indexes for manufacturer, lure type, and the variant→model foreign key
- a concrete, read-only `LureCatalogRepository`, constructed the same way every other repository in this app is constructed
- a versioned, idempotent local seed reconciliation step (insert new, correct outdated, retire removed — see [Seed Data](#seed-data))
- a mapper between Drift rows and domain/read-model types
- a documented, explicitly temporary navigation entry point (see [Navigation Entry Point](#navigation-entry-point-temporary))
- catalog browse list UI with search and filter controls
- read-only Lure Details page
- loading, empty, and error states
- accessibility labeling
- tests

Do **not** implement:

- Personal Tackle Box
- assigning a lure to a catch
- any create/update/delete UI or repository operation for catalog data
- user-uploaded lure photos
- favorites
- catch statistics
- recommendations
- admin tooling
- catalog moderation
- external APIs
- web scraping
- barcode scanning
- cloud synchronization or any cloud-sync fields (remote ids, sync status, server versions)
- Riverpod, or any other DI/state-management technology not already used elsewhere in this codebase
- repository interfaces
- DAO layer
- service layer
- use-case layer
- a normalized `Manufacturer` entity
- a third (size vs. color) variant tier
- full-text search (FTS5) or any search index beyond plain B-tree indexes
- a typed `ImageReference` value object (see [Image Reference Handling](#image-reference-handling))
- global/reactive catalog state (`StateNotifier`, `AsyncNotifier`, streams)
- broader application navigation redesign (drawer, bottom navigation, tabs — see [Navigation Entry Point](#navigation-entry-point-temporary))

---

# Key Design Decisions

This section directly answers the design questions raised before implementation. The detailed sections later in this document implement these decisions.

### 1. One repository, not two

`LureCatalogRepository` owns both `LureModels` and `LureVariants`. The presentation layer never needs to separately load a `LureModel` and its `LureVariant`s and join them itself — every read method already returns fully-assembled data.

### 2. List and details queries return a joined `LureCatalogEntry`, not separate models

`LureCatalogEntry` combines a `LureVariant`'s own fields with its parent `LureModel`'s `manufacturer`/`productFamily`/`modelName`/`lureType`, plus an already-resolved `effectiveImageReference`. One SQL join produces everything a screen needs.

### 3. Search matches six columns across both tables, using precomputed lowercase search keys

A single joined query matches a Dart-lowercased search term against precomputed, Dart-lowercased `searchText` columns on both tables — not SQLite's own case-folding. See [Search and Finnish Text Matching](#search-and-finnish-text-matching) for why, and for what this deliberately does not attempt to solve.

### 4. Indexes: `LureModels.manufacturer`, `LureModels.lureType`, `LureVariants.lureModelId`

These are the three columns every query filters or joins on. SQLite does not automatically index a foreign key column.

### 5. Seed reconciliation is versioned, not one-shot `insertOrIgnore`

Each seed row carries the seed revision it was last written by (`seedVersion`). Reconciliation inserts missing rows, corrects rows that are still app-owned and out of date, and never touches a row whose `seedVersion` has been cleared (meaning something else — a future server sync — now owns it). See [Seed Data](#seed-data).

### 6. Unknown `lureType` codes round-trip because there is nothing to parse

`lureType` is a plain `String` — there is no enum to fail to match. Display falls back to a humanized version of the raw code when it isn't in the known-label lookup.

### 7. Filter options come from `SELECT DISTINCT`, not a compiled-in list

An unrecognized `lureType` value still appears as a selectable filter, labeled via the same fallback, rather than becoming invisible.

### 8. Images: a plain nullable `String`, not a typed reference

A typed `sealed class LureImageReference` would only be justified once a second kind of reference (e.g. a remote URL) actually exists. A plain `String?` interpreted as an asset path is the entire mechanism required today.

### 9. Avoiding N+1: one joined query per screen, ever

`LureCatalogEntry` already carries model-level fields, so the browse list, search results, and details page each resolve in exactly one query — never one query per row.

### 10. Obsolete seed entries are retired, never deleted

If a seed revision removes an entry that a previous revision shipped, reconciliation marks it `retiredAt` instead of deleting it. `browse()` excludes retired variants by default; `getEntryById()` does not, so a future reference to a retired variant (from Personal Tackle Box or Assign Lure to Catch) can still resolve it. See [Seed Data](#seed-data).

### 11. Identity is an opaque, authored UUID-style string, not a slug

Catalog ids never encode manufacturer/model/color text. A slug looks convenient during authoring but ties identity to display text that this project has explicitly said must be independent of it. See [Identity and ID Scheme](#identity-and-id-scheme).

### 12. Dependency construction follows the existing manual pattern, not Riverpod

Every other feature in this app constructs its repositories directly inside a `StatefulWidget`'s state. `LureCatalogRepository` does the same. See [Dependency Construction](#dependency-construction).

---

# Architecture

Lure Catalog shall be implemented as its own feature, separate from a future feature that will own personal tackle box data (per MFS-015's Feature Ownership section).

Expected structure:

```text
lib/features/lure_catalog/
  domain/
    lure_model.dart
    lure_variant.dart
    lure_catalog_entry.dart
    lure_type_labels.dart
  data/
    local/
      lure_models_table.dart
      lure_variants_table.dart
      lure_catalog_seed_data.dart
    lure_catalog_mapper.dart
    lure_catalog_repository.dart
  presentation/
    widgets/
      lure_catalog_list_page.dart
      lure_catalog_list_item.dart
      lure_catalog_filter_bar.dart
      lure_details_page.dart
      lure_image.dart
```

Exact widget file separation may be adjusted if a smaller structure is clearer, consistent with how Catch Photos' file layout was allowed to flex.

The implementation shall follow the current project architecture:

- feature-first
- offline-first
- concrete repository, no interface
- Drift accessed directly through the repository
- manual dependency construction (see [Dependency Construction](#dependency-construction)), not Riverpod
- local widget state for transient UI (search text, active filters), not a global notifier
- Material 3
- no unnecessary abstraction layers

---

# Feature Ownership

The `lure_catalog` feature owns:

- `LureModel`, `LureVariant`, `LureCatalogEntry` domain/read-model types
- `lureType`/`buoyancy` string-code display-label handling
- the `LureModels`/`LureVariants` Drift tables
- the catalog mapper
- the catalog repository, including seed reconciliation
- all catalog presentation (list, filter, details)

No other feature owns any part of the catalog. A future Personal Tackle Box feature (MFS-016) is expected to depend on `lure_catalog` (referencing `LureVariant.id`), not the other way around — the same dependency direction already established between `catches` and `fishing_spots`. The Map feature's dependency on `lure_catalog` (see [Navigation Entry Point](#navigation-entry-point-temporary)) is a one-way, temporary navigation trigger only — `lure_catalog` never depends on `map`.

---

# Dependencies

No new external package dependencies are required. This milestone reuses:

- Flutter, Dart
- Drift (existing dependency, per ADR-0005)
- `uuid` (existing dependency, already used for `CatchPhoto` ids — reused here to *author* seed ids once, not to generate ids at runtime; see [Identity and ID Scheme](#identity-and-id-scheme))

`pubspec.yaml` requires one change unrelated to packages: declaring the bundled placeholder image assets under `flutter: assets:`.

`flutter_riverpod` is **not** used by this feature. See [Dependency Construction](#dependency-construction).

---

# Domain

## LureModel

```dart
final class LureModel {
  const LureModel({
    required this.id,
    required this.manufacturer,
    required this.modelName,
    required this.lureType,
    required this.createdAt,
    required this.updatedAt,
    this.productFamily,
    this.defaultImageReference,
  }) : assert(id != '', 'id must not be empty'),
       assert(manufacturer != '', 'manufacturer must not be empty'),
       assert(modelName != '', 'modelName must not be empty'),
       assert(lureType != '', 'lureType must not be empty');

  final String id;
  final String manufacturer;
  final String modelName;
  final String lureType;
  final String? productFamily;
  final String? defaultImageReference;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

Requirements:

- the model shall not depend on Flutter or Drift
- `lureType` is a plain `String`, never an enum (see [Lure Type and Buoyancy Handling](#lure-type-and-buoyancy-handling))
- `createdAt`/`updatedAt` are plain local bookkeeping timestamps — no cloud-sync fields (no remote id, no sync status, no server version) are added in this milestone

---

## LureVariant

```dart
final class LureVariant {
  const LureVariant({
    required this.id,
    required this.lureModelId,
    required this.createdAt,
    required this.updatedAt,
    this.variantName,
    this.colorName,
    this.manufacturerColorCode,
    this.lengthMillimeters,
    this.weightGrams,
    this.minRunningDepthMillimeters,
    this.maxRunningDepthMillimeters,
    this.buoyancy,
    this.imageReference,
  }) : assert(id != '', 'id must not be empty'),
       assert(lureModelId != '', 'lureModelId must not be empty'),
       assert(
         variantName != null || colorName != null || manufacturerColorCode != null,
         'a LureVariant must have at least one of variantName, colorName, '
         'or manufacturerColorCode to be distinguishable from its siblings',
       ),
       assert(lengthMillimeters == null || lengthMillimeters > 0),
       assert(weightGrams == null || weightGrams > 0),
       assert(minRunningDepthMillimeters == null || minRunningDepthMillimeters > 0),
       assert(maxRunningDepthMillimeters == null || maxRunningDepthMillimeters > 0),
       assert(
         minRunningDepthMillimeters == null ||
             maxRunningDepthMillimeters == null ||
             minRunningDepthMillimeters <= maxRunningDepthMillimeters,
       );

  final String id;
  final String lureModelId;
  final String? variantName;
  final String? colorName;
  final String? manufacturerColorCode;
  final int? lengthMillimeters;
  final int? weightGrams;
  final int? minRunningDepthMillimeters;
  final int? maxRunningDepthMillimeters;
  final String? buoyancy;
  final String? imageReference;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

Requirements:

- the model shall not depend on Flutter or Drift
- the model shall not contain image bytes or an absolute device path
- every numeric measurement field shall be `null` or strictly greater than zero
- the distinguishing-information assertion mirrors the database-level `CHECK` constraint (see [Database Constraints](#database-constraints))
- `createdAt`/`updatedAt` are plain local bookkeeping timestamps — no cloud-sync fields in this milestone

**Neither domain model carries `seedVersion` or `retiredAt`.** Those are pure seed-lifecycle/repository bookkeeping (see [Seed Data](#seed-data)), not facts about what a lure *is* — they stay at the Drift/repository layer and never appear on `LureModel`, `LureVariant`, or `LureCatalogEntry`. If a future milestone needs to show retirement status to a user, exposing it then is a small additive change, not a remodel.

---

## LureCatalogEntry

The joined read-model returned by every browse/search/filter/details query.

```dart
final class LureCatalogEntry {
  const LureCatalogEntry({
    required this.variant,
    required this.manufacturer,
    required this.modelName,
    required this.lureType,
    required this.modelDefaultImageReference,
    this.productFamily,
  });

  final LureVariant variant;
  final String manufacturer;
  final String modelName;
  final String lureType;
  final String? productFamily;
  final String? modelDefaultImageReference;

  String get id => variant.id;

  /// The variant's own image if present, otherwise the parent model's
  /// default image. Resolved once here so presentation code never needs to
  /// know the fallback rule.
  String? get effectiveImageReference =>
      variant.imageReference ?? modelDefaultImageReference;
}
```

Display name (manufacturer, family, model, variant-distinguishing detail combined into one human string) shall be a **derived getter or a small free function**, never a stored field — consistent with MFS-015's identity requirement.

---

## Lure Type and Buoyancy Handling

`lureType` and `buoyancy` are both open, stable string codes — not closed Dart enums. Unlike `FishSpecies`, the application must never fail, throw, or block loading when it encounters a code it doesn't recognize.

```text
lib/features/lure_catalog/domain/lure_type_labels.dart
```

```dart
const Map<String, String> _knownLureTypeLabels = {
  'crankbait': 'Vaappu',
  'jerkbait': 'Jerkki',
  'spinnerbait': 'Spinneribeitti',
  'spinner': 'Lusikka',
  'spoon': 'Lusikka',
  'soft_plastic': 'Muovivetouistin',
  'jig': 'Jigi',
  'swimbait': 'Uimavetouistin',
  'topwater': 'Pintauistin',
  'wobbler': 'Vaappu',
};

String lureTypeDisplayLabel(String code) {
  return _knownLureTypeLabels[code] ?? _humanizeUnknownCode(code);
}

const Map<String, String> _knownBuoyancyLabels = {
  'floating': 'Uiva',
  'suspending': 'Neutraali',
  'slow_sinking': 'Hitaasti uppoava',
  'sinking': 'Uppoava',
};

String buoyancyDisplayLabel(String code) {
  return _knownBuoyancyLabels[code] ?? _humanizeUnknownCode(code);
}

String _humanizeUnknownCode(String code) {
  final withSpaces = code.replaceAll('_', ' ').trim();
  if (withSpaces.isEmpty) {
    return code;
  }
  return withSpaces[0].toUpperCase() + withSpaces.substring(1);
}
```

**The Finnish labels above are a draft, not an authoritative translation** (for example, "vaappu" is used for both `crankbait` and `wobbler`, which is imprecise). Treat this the same way `FishSpecies`' catalog was treated in MFS-009: a placeholder needing a review pass, not something to ship as final.

Requirements:

- an unrecognized code shall render via `_humanizeUnknownCode`, never throw, never be rejected
- the known-code maps live in the domain layer so they can be unit tested directly
- the filter UI's available lure-type/buoyancy options come from the database (see [Manufacturer and Lure-Type Filtering](#manufacturer-and-lure-type-filtering)), not from these maps

---

## Image Reference Handling

`LureModel.defaultImageReference` and `LureVariant.imageReference` are both plain nullable `String`, interpreted as a Flutter asset path (e.g. `assets/lure_catalog/placeholder_crankbait.png`).

```dart
// lib/features/lure_catalog/presentation/widgets/lure_image.dart
class LureImage extends StatelessWidget {
  const LureImage({
    super.key,
    required this.imageReference,
    required this.semanticLabel,
    this.size,
  });

  final String? imageReference;
  final String semanticLabel;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final reference = imageReference;
    if (reference == null) {
      return _LurePlaceholder(semanticLabel: semanticLabel, size: size);
    }
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Image.asset(
        reference,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _LurePlaceholder(semanticLabel: semanticLabel, size: size),
      ),
    );
  }
}
```

This is deliberately simpler than `CatchPhoto`'s image handling: `CatchPhoto` needs a repository-level storage layer because its files are dynamically written to app-owned storage at runtime. Lure Catalog images are static assets bundled at build time, so `Image.asset` is the entire resolution mechanism.

Placeholder icon: `Icons.phishing`, distinct from `CatchListItem`'s `Icons.set_meal`, so a lure and a catch are not visually conflated.

---

# Database

## Schema Version

```text
schema version 3 -> schema version 4
```

Confirm the current schema version from `lib/core/database/app_database.dart` before changing it.

---

## LureModels Table

```text
lib/features/lure_catalog/data/local/lure_models_table.dart
```

```dart
import 'package:drift/drift.dart';

@DataClassName('LureModelEntity')
@TableIndex(name: 'lure_models_manufacturer', columns: {#manufacturer})
@TableIndex(name: 'lure_models_lure_type', columns: {#lureType})
class LureModels extends Table {
  TextColumn get id => text()();
  TextColumn get manufacturer => text()();
  TextColumn get productFamily => text().nullable()();
  TextColumn get modelName => text()();
  TextColumn get lureType => text()();
  TextColumn get defaultImageReference => text().nullable()();

  /// Precomputed, Dart-lowercased concatenation of manufacturer,
  /// productFamily, and modelName. Written by the mapper, never read back
  /// into the domain layer. See [Search and Finnish Text Matching].
  TextColumn get searchText => text()();

  /// The seed revision that last wrote this row's content, or null if the
  /// row is no longer owned by the local seed process (e.g. a future
  /// server-managed row). See [Seed Data].
  IntColumn get seedVersion => integer().nullable()();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Requirements:

- `id` is the primary key, an opaque authored value (see [Identity and ID Scheme](#identity-and-id-scheme))
- `manufacturer`, `modelName`, `lureType`, `searchText`, `createdAt`, `updatedAt` are required
- `productFamily`, `defaultImageReference`, `seedVersion` are nullable
- no image blob column, no absolute path column, no cloud-sync columns (no remote id, no sync status, no server version)

---

## LureVariants Table

```text
lib/features/lure_catalog/data/local/lure_variants_table.dart
```

```dart
import 'package:drift/drift.dart';

import 'package:fishing_app/features/lure_catalog/data/local/lure_models_table.dart';

@DataClassName('LureVariantEntity')
@TableIndex(name: 'lure_variants_lure_model_id', columns: {#lureModelId})
class LureVariants extends Table {
  TextColumn get id => text()();

  TextColumn get lureModelId =>
      text().references(LureModels, #id, onDelete: KeyAction.cascade)();

  TextColumn get variantName => text().nullable()();
  TextColumn get colorName => text().nullable()();
  TextColumn get manufacturerColorCode => text().nullable()();

  IntColumn get lengthMillimeters => integer().nullable().check(
    // ignore: recursive_getters
    lengthMillimeters.isNull() | lengthMillimeters.isBiggerThanValue(0),
  )();

  IntColumn get weightGrams => integer().nullable().check(
    // ignore: recursive_getters
    weightGrams.isNull() | weightGrams.isBiggerThanValue(0),
  )();

  IntColumn get minRunningDepthMillimeters => integer().nullable().check(
    // ignore: recursive_getters
    minRunningDepthMillimeters.isNull() |
        minRunningDepthMillimeters.isBiggerThanValue(0),
  )();

  IntColumn get maxRunningDepthMillimeters => integer().nullable().check(
    // ignore: recursive_getters
    maxRunningDepthMillimeters.isNull() |
        maxRunningDepthMillimeters.isBiggerThanValue(0),
  )();

  TextColumn get buoyancy => text().nullable()();
  TextColumn get imageReference => text().nullable()();

  /// Precomputed, Dart-lowercased concatenation of variantName, colorName,
  /// and manufacturerColorCode. See [Search and Finnish Text Matching].
  TextColumn get searchText => text()();

  /// See `LureModels.seedVersion`.
  IntColumn get seedVersion => integer().nullable()();

  /// Non-null once this variant has been removed from the current seed
  /// source. Retired variants are excluded from `browse()` but remain
  /// resolvable by `getEntryById()`. See [Seed Data].
  IntColumn get retiredAt => integer().nullable()();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (variant_name IS NOT NULL OR color_name IS NOT NULL '
        'OR manufacturer_color_code IS NOT NULL)',
  ];
}
```

Requirements:

- `id` is the primary key, an opaque authored value
- `lureModelId` references `LureModels.id`, cascade delete
- every measurement column is nullable with a positive-value `CHECK`
- the table-level `CHECK` enforces the distinguishing-information rule at the database layer, mirroring the domain assertion
- `createdAt`/`updatedAt` are epoch milliseconds (`IntColumn`), matching every existing table's convention
- `retiredAt` is only ever set/cleared by seed reconciliation (see [Seed Data](#seed-data)) — no UI ever sets it directly, because no delete/retire UI exists
- `LureModels` has no `retiredAt` in this milestone: nothing browses models independently of their variants, so there is no query that needs a model-level active/retired flag yet — if every variant of a model is retired, the model row simply stops appearing in any practical browse result without needing its own flag
- no image blob column, no absolute path column, no cloud-sync columns

Confirm the actual generated SQL column names (`variant_name`, `color_name`, `manufacturer_color_code`) match Drift's default snake_case conversion before finalizing the `customConstraints` string.

---

## Database Registration

Register both tables in `AppDatabase`:

```dart
@DriftDatabase(
  tables: [FishingSpots, Catches, CatchPhotos, LureModels, LureVariants],
)
class AppDatabase extends _$AppDatabase {
  ...

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(catches);
      }
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
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
```

Regenerate Drift output using the project's established generation command. Do not manually edit generated Drift files.

---

## Migration

Requirements:

- preserve all existing Fishing Spots, Catches, and Catch Photos
- create only the two new tables and their three indexes
- do not rebuild or modify any existing table
- migration from schema version 3 succeeds
- the migration itself does **not** insert or reconcile seed data — schema creation and data seeding are deliberately separate steps (see [Seed Data](#seed-data))

---

## Database Constraints

- Positive-value checks on all four measurement columns
- Distinguishing-information `CHECK` on `LureVariants`
- Foreign key `lureModelId → LureModels.id`, `onDelete: KeyAction.cascade`

Nothing in this milestone ever deletes a `LureModel` — the cascade exists for referential consistency only, available to a future maintenance capability without this milestone needing to build one.

---

## Identity and ID Scheme

Catalog identity must be **opaque and immutable** — it must never need to change when manufacturer, model, color, or any display text changes, and it must never be derived from that text.

`LureModel.id` and `LureVariant.id` are **authored UUID v4 strings**, generated once (using the project's existing `uuid` package, run once by whoever authors a seed entry) and then hardcoded as literal string constants in the seed data source:

```text
LureModel.id example:   3f3e6a1a-8b2e-4c1a-9d7a-1a2b3c4d5e6f
LureVariant.id example:  9c7a2b4e-5d1f-4a3b-8e2c-6f7a8b9c0d1e
```

This is a deliberate departure from a kebab-case slug (e.g. `rapala-xrap-shad-xrs08`), which was considered and rejected: a slug is still derived from — and reads as a restatement of — display text, which is exactly what catalog identity must not depend on. A UUID has no relationship to manufacturer/model/color text at all, so correcting a typo in `manufacturer` or renaming a `productFamily` can never create pressure to also "fix" the id.

**Critical implementation requirement:** these ids must be **static literals in the seed data source**, never generated at runtim e via `Uuid().v4()` inside the seed list itself. A dynamically-generated id would produce a different value on every app run, which would break the versioned-reconciliation matching in [Seed Data](#seed-data) (every run would see "new" ids and insert duplicates). The `uuid` package is used only as an offline authoring tool when writing the seed file, exactly once per entry, by hand.

If a future server-managed catalog issues its own identifiers, this scheme does not need to change: Drift's `id` columns are plain `TEXT`, and reconciling a local authored UUID with a future server id is a synchronization-design problem explicitly out of scope here.

---

# Mapper

```text
lib/features/lure_catalog/data/lure_catalog_mapper.dart
```

Responsibilities:

- map a joined `(LureVariantEntity, LureModelEntity)` row pair into a `LureCatalogEntry`
- map a `LureModel` domain instance, plus a seed version, into a `LureModelsCompanion` (for seed reconciliation)
- map a `LureVariant` domain instance, plus a seed version, into a `LureVariantsCompanion` (for seed reconciliation)
- compute `searchText` for both tables (see [Search and Finnish Text Matching](#search-and-finnish-text-matching))
- keep persistence types, `seedVersion`, and `retiredAt` out of presentation code

```dart
class LureCatalogMapper {
  const LureCatalogMapper();

  LureCatalogEntry entryFromRows({
    required LureVariantEntity variantRow,
    required LureModelEntity modelRow,
  }) {
    return LureCatalogEntry(
      variant: _variantFromRow(variantRow),
      manufacturer: modelRow.manufacturer,
      productFamily: modelRow.productFamily,
      modelName: modelRow.modelName,
      lureType: modelRow.lureType,
      modelDefaultImageReference: modelRow.defaultImageReference,
    );
  }

  LureVariant _variantFromRow(LureVariantEntity row) {
    return LureVariant(
      id: row.id,
      lureModelId: row.lureModelId,
      variantName: row.variantName,
      colorName: row.colorName,
      manufacturerColorCode: row.manufacturerColorCode,
      lengthMillimeters: row.lengthMillimeters,
      weightGrams: row.weightGrams,
      minRunningDepthMillimeters: row.minRunningDepthMillimeters,
      maxRunningDepthMillimeters: row.maxRunningDepthMillimeters,
      buoyancy: row.buoyancy,
      imageReference: row.imageReference,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  LureModelsCompanion modelToCompanion(LureModel model, {required int seedVersion}) {
    return LureModelsCompanion.insert(
      id: model.id,
      manufacturer: model.manufacturer,
      productFamily: Value(model.productFamily),
      modelName: model.modelName,
      lureType: model.lureType,
      defaultImageReference: Value(model.defaultImageReference),
      searchText: _modelSearchText(model),
      seedVersion: Value(seedVersion),
      createdAt: model.createdAt.millisecondsSinceEpoch,
      updatedAt: model.updatedAt.millisecondsSinceEpoch,
    );
  }

  LureVariantsCompanion variantToCompanion(LureVariant variant, {required int seedVersion}) {
    return LureVariantsCompanion.insert(
      id: variant.id,
      lureModelId: variant.lureModelId,
      variantName: Value(variant.variantName),
      colorName: Value(variant.colorName),
      manufacturerColorCode: Value(variant.manufacturerColorCode),
      lengthMillimeters: Value(variant.lengthMillimeters),
      weightGrams: Value(variant.weightGrams),
      minRunningDepthMillimeters: Value(variant.minRunningDepthMillimeters),
      maxRunningDepthMillimeters: Value(variant.maxRunningDepthMillimeters),
      buoyancy: Value(variant.buoyancy),
      imageReference: Value(variant.imageReference),
      searchText: _variantSearchText(variant),
      seedVersion: Value(seedVersion),
      retiredAt: const Value(null),
      createdAt: variant.createdAt.millisecondsSinceEpoch,
      updatedAt: variant.updatedAt.millisecondsSinceEpoch,
    );
  }

  String _modelSearchText(LureModel model) {
    final parts = [model.manufacturer, model.productFamily, model.modelName]
        .whereType<String>()
        .where((s) => s.isNotEmpty);
    return parts.join(' ').toLowerCase();
  }

  String _variantSearchText(LureVariant variant) {
    final parts = [
      variant.variantName,
      variant.colorName,
      variant.manufacturerColorCode,
    ].whereType<String>().where((s) => s.isNotEmpty);
    return parts.join(' ').toLowerCase();
  }
}
```

`.toLowerCase()` is Dart's own (Unicode-aware) lowercasing, not SQLite's — see [Search and Finnish Text Matching](#search-and-finnish-text-matching) for why this distinction matters.

---

# Seed Data

```text
lib/features/lure_catalog/data/local/lure_catalog_seed_data.dart
```

Seed data is authored directly as `LureModel`/`LureVariant` domain instances, plus one version constant:

```dart
/// Bump whenever any seed model/variant's *content* is corrected, or when
/// entries are added/removed. Reconciliation compares this against each
/// row's stored `seedVersion` to decide whether a correction is needed.
const int currentLureCatalogSeedVersion = 1;

final List<LureModel> lureCatalogSeedModels = [
  LureModel(
    id: '3f3e6a1a-8b2e-4c1a-9d7a-1a2b3c4d5e6f',
    manufacturer: 'Rapala',
    productFamily: 'X-Rap',
    modelName: 'X-Rap Shad XRS08',
    lureType: 'crankbait',
    defaultImageReference: 'assets/lure_catalog/rapala_xrap_shad_xrs08.png',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  ),
  // ... 2-4 more models
];

final List<LureVariant> lureCatalogSeedVariants = [
  LureVariant(
    id: '9c7a2b4e-5d1f-4a3b-8e2c-6f7a8b9c0d1e',
    lureModelId: '3f3e6a1a-8b2e-4c1a-9d7a-1a2b3c4d5e6f',
    colorName: 'Hot Craw',
    manufacturerColorCode: 'HCC',
    lengthMillimeters: 80,
    weightGrams: 12,
    minRunningDepthMillimeters: 1500,
    maxRunningDepthMillimeters: 2400,
    buoyancy: 'suspending',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  ),
  // ... 9-19 more variants, spanning multiple lureType codes, with
  // some entries intentionally omitting weight/depth/buoyancy per
  // MFS-015 FR-7.
];
```

`createdAt`/`updatedAt` on the domain instances use a fixed literal `DateTime`, representing "first authored" — reconciliation (below) manages the stored `updatedAt` independently when a correction is applied.

Ids are opaque UUID v4 literals per [Identity and ID Scheme](#identity-and-id-scheme) — never slugs, never generated at runtime.

---

## Seed Reconciliation Strategy

Reconciliation replaces the earlier `insertOrIgnore`-only design. It supports three things `insertOrIgnore` alone cannot: correcting a previously-shipped row's content, extending the catalog with new rows, and never touching a row a future server sync may already own — all without a schema migration.

```dart
Future<void> ensureSeeded() async {
  await _database.transaction(() async {
    final seedModelIds = <String>{};
    for (final model in lureCatalogSeedModels) {
      seedModelIds.add(model.id);
      await _reconcileModel(model);
    }

    final seedVariantIds = <String>{};
    for (final variant in lureCatalogSeedVariants) {
      seedVariantIds.add(variant.id);
      await _reconcileVariant(variant);
    }

    await _retireRemovedVariants(stillPresentIds: seedVariantIds);
  });
}

Future<void> _reconcileModel(LureModel model) async {
  final existing = await (_database.select(
    _database.lureModels,
  )..where((t) => t.id.equals(model.id))).getSingleOrNull();

  if (existing == null) {
    await _database
        .into(_database.lureModels)
        .insert(_mapper.modelToCompanion(model, seedVersion: currentLureCatalogSeedVersion));
    return;
  }

  // A null seedVersion means something other than this seed process now
  // owns the row (e.g. a future server sync) — never touch it.
  if (existing.seedVersion == null) {
    return;
  }
  if (existing.seedVersion! >= currentLureCatalogSeedVersion) {
    return;
  }

  await (_database.update(_database.lureModels)..where((t) => t.id.equals(model.id))).write(
    _mapper.modelToCompanion(model, seedVersion: currentLureCatalogSeedVersion).copyWith(
      createdAt: Value(existing.createdAt), // preserve original createdAt
    ),
  );
}

Future<void> _reconcileVariant(LureVariant variant) async { /* same shape as
  _reconcileModel, additionally clearing retiredAt back to null: a variant
  reappearing in the current seed source is no longer retired */ }

Future<void> _retireRemovedVariants({required Set<String> stillPresentIds}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final ownedRows = await (_database.select(
    _database.lureVariants,
  )..where((t) => t.seedVersion.isNotNull() & t.retiredAt.isNull())).get();

  for (final row in ownedRows) {
    if (!stillPresentIds.contains(row.id)) {
      await (_database.update(
        _database.lureVariants,
      )..where((t) => t.id.equals(row.id))).write(
        LureVariantsCompanion(retiredAt: Value(now)),
      );
    }
  }
}
```

Requirements:

- **Insert**: a seed id with no existing row is inserted with `seedVersion: currentLureCatalogSeedVersion`.
- **Correct**: a seed id whose existing row has a non-null `seedVersion` strictly less than `currentLureCatalogSeedVersion` is updated to the seed's current content; its stored `createdAt` is preserved, `updatedAt` reflects the correction, and `seedVersion` is bumped to current.
- **Never touch server-owned rows**: a row whose stored `seedVersion` is `null` is skipped entirely — this is the mechanism that keeps reconciliation from ever overwriting a row a future synchronization process has taken ownership of.
- **Already current**: a row whose stored `seedVersion` already equals or exceeds the current constant is left untouched (this is what makes repeated calls idempotent — after the first successful reconciliation at a given seed version, subsequent calls do no writes at all).
- **Retire, don't delete**: any still-seed-owned variant row whose id is no longer present in `lureCatalogSeedVariants` is marked `retiredAt`, never deleted. A variant reappearing in a later seed revision has its `retiredAt` cleared automatically as part of the normal correct/insert path.
- The whole reconciliation runs inside one `_database.transaction()`.
- `ensureSeeded()` must be called before the first `browse()`/`getEntryById()` call each time the catalog is opened; it is **not** called at application startup (see [Performance](#performance)).

The presentation layer calls `ensureSeeded()` once, in the Catalog List page's load sequence, before its first `browse()` call.

**Deferred to a later milestone, not part of MFS-015:** any handling for `LureModels` becoming fully orphaned (every variant retired). Nothing in this milestone queries models independently of variants, so this is not a gap that affects any requirement here.

---

# LureCatalogRepository

```text
lib/features/lure_catalog/data/lure_catalog_repository.dart
```

Use a concrete class. No repository interface. Constructed exactly like every other repository in this codebase (see [Dependency Construction](#dependency-construction)).

```dart
class LureCatalogRepository {
  LureCatalogRepository(this._database, [this._mapper = const LureCatalogMapper()]);

  final AppDatabase _database;
  final LureCatalogMapper _mapper;

  Future<void> ensureSeeded() { ... }

  Future<List<LureCatalogEntry>> browse({
    String? searchText,
    String? manufacturer,
    String? lureType,
  }) { ... }

  Future<LureCatalogEntry?> getEntryById(String variantId) { ... }

  Future<List<String>> getDistinctManufacturers() { ... }

  Future<List<String>> getDistinctLureTypes() { ... }
}
```

## Repository Responsibilities

The repository owns:

- the join between `LureVariants` and `LureModels`
- search-text matching across both tables
- manufacturer/lure-type filtering
- result ordering (excluding retired variants)
- versioned, idempotent seed reconciliation
- row-to-read-model mapping

The repository does not own:

- catalog list/filter widget state
- image asset resolution (that's `LureImage`, a pure presentation concern)
- any create/update/delete operation exposed to the UI — none exist

---

## Search and Finnish Text Matching

**This is a concrete, designed mechanism, not an implementation-time question.**

SQLite's built-in `LIKE` operator is case-insensitive by default only for ASCII letters; it does not reliably fold the case of `ä`/`ö` (or other non-ASCII letters) without the ICU extension, which is not loaded in this project's sqlite3 build. Relying on SQL-side `LIKE`/`COLLATE NOCASE` for the search term itself would silently fail to match, for example, a search for `"sinivihreä"` against a stored `"Sinivihreä"`.

The fix is to never ask SQLite to fold case at all for search matching. Instead:

1. The mapper precomputes a `searchText` column on each table — a Dart-`.toLowerCase()`'d concatenation of that table's searchable fields (see [Mapper](#mapper)) — written whenever a row is inserted or corrected by reconciliation.
2. `browse(searchText: ...)` lowercases the incoming search term with Dart's own `.toLowerCase()` before building the query, then matches it with a plain `LIKE '%term%'` against the two precomputed `searchText` columns.

```dart
Future<List<LureCatalogEntry>> browse({
  String? searchText,
  String? manufacturer,
  String? lureType,
}) async {
  final query = _database.select(_database.lureVariants).join([
    innerJoin(
      _database.lureModels,
      _database.lureModels.id.equalsExp(_database.lureVariants.lureModelId),
    ),
  ])..where(_database.lureVariants.retiredAt.isNull());

  final trimmedSearch = searchText?.trim().toLowerCase();
  if (trimmedSearch != null && trimmedSearch.isNotEmpty) {
    final pattern = '%$trimmedSearch%';
    query.where(
      _database.lureModels.searchText.like(pattern) |
      _database.lureVariants.searchText.like(pattern),
    );
  }
  if (manufacturer != null) {
    query.where(_database.lureModels.manufacturer.equals(manufacturer));
  }
  if (lureType != null) {
    query.where(_database.lureModels.lureType.equals(lureType));
  }

  query.orderBy([
    OrderingTerm(expression: _database.lureModels.manufacturer.collate(Collate.noCase)),
    OrderingTerm(expression: _database.lureModels.modelName.collate(Collate.noCase)),
    OrderingTerm(expression: _database.lureVariants.id),
  ]);

  final rows = await query.get();
  return [
    for (final row in rows)
      _mapper.entryFromRows(
        variantRow: row.readTable(_database.lureVariants),
        modelRow: row.readTable(_database.lureModels),
      ),
  ];
}
```

Because both sides of the `LIKE` comparison are already lowercase (folded once, correctly, in Dart), no SQL-side case-folding is ever required for the match to succeed — this works identically for ASCII and for `ä`/`ö`.

**What this deliberately does not solve:** `ORDER BY ... COLLATE NOCASE` (used for sort order, not matching) keeps SQLite's own ASCII-only case-folding, so two entries differing only in the casing of a Finnish letter could sort slightly out of strict alphabetical order relative to each other. This is accepted as a cosmetic-only limitation for this milestone — it affects display order, not whether a search finds a result, which is the correctness property that actually matters here. If it needs correcting later, it can be revisited independently of search.

Requirements:

- an empty/whitespace-only `searchText` is treated as no search filter
- `manufacturer`/`lureType` filters are exact-match against the distinct values returned by `getDistinctManufacturers`/`getDistinctLureTypes` — unaffected by the case-folding question since they compare against a value the user selected from an exact list, not free text
- `browse()` excludes retired variants (`retiredAt IS NULL`) by default
- ordering is always applied, deterministic, and does not vary between identical queries

---

## Manufacturer and Lure-Type Filtering

```dart
Future<List<String>> getDistinctManufacturers() async {
  final query = _database.selectOnly(_database.lureModels, distinct: true)
    ..addColumns([_database.lureModels.manufacturer])
    ..orderBy([OrderingTerm(expression: _database.lureModels.manufacturer.collate(Collate.noCase))]);
  final rows = await query.get();
  return [for (final row in rows) row.read(_database.lureModels.manufacturer)!];
}

Future<List<String>> getDistinctLureTypes() async {
  final query = _database.selectOnly(_database.lureModels, distinct: true)
    ..addColumns([_database.lureModels.lureType])
    ..orderBy([OrderingTerm(expression: _database.lureModels.lureType)]);
  final rows = await query.get();
  return [for (final row in rows) row.read(_database.lureModels.lureType)!];
}
```

These back the filter dropdowns directly. Because they query actual data rather than a compiled-in list, a `lureType` value the app has no localized label for still appears (labeled via `lureTypeDisplayLabel`'s fallback) and remains selectable.

---

## Sorting

Default order for `browse()`: manufacturer (case-insensitive), then model name (case-insensitive), then variant id (stable tiebreaker). Fixed for this milestone — no user-facing sort control is in scope.

---

## Details Query/Loading Strategy

```dart
Future<LureCatalogEntry?> getEntryById(String variantId) async {
  final query = _database.select(_database.lureVariants).join([
    innerJoin(
      _database.lureModels,
      _database.lureModels.id.equalsExp(_database.lureVariants.lureModelId),
    ),
  ])..where(_database.lureVariants.id.equals(variantId));
  // Deliberately no retiredAt filter here: a future reference to a retired
  // variant (Personal Tackle Box, Assign Lure to Catch) must still resolve.

  final row = await query.getSingleOrNull();
  if (row == null) {
    return null;
  }
  return _mapper.entryFromRows(
    variantRow: row.readTable(_database.lureVariants),
    modelRow: row.readTable(_database.lureModels),
  );
}
```

The Lure Details page receives the `LureCatalogEntry` it was opened with directly (the same way `CatchDetailsPage` receives its `Catch`) and does not re-query on open. `getEntryById` exists for a future caller that only has an id.

---

# Presentation

## Dependency Construction

**Riverpod is not used by this feature.** `LureCatalogRepository` is constructed exactly the same way `CatchRepository`/`FishingSpotRepository`/`CatchPhotoRepository` already are: directly, inside the `State` of whichever widget owns the `AppDatabase` instance for that part of the widget tree — currently `MapScreen`.

```dart
// lib/features/map/presentation/map_screen.dart
late final LureCatalogRepository _lureCatalogRepository =
    LureCatalogRepository(_database);
```

`LureCatalogListPage` is a plain `StatefulWidget` that receives its `LureCatalogRepository` via a required constructor parameter, pushed with `Navigator.push`, exactly like `FishingSpotDetailsBottomSheet` receives its `CatchRepository`/`CatchPhotoRepository` from `MapScreen` today.

`flutter_riverpod` remains a declared dependency (per ADR-0001) and continues to wrap the app via `ProviderScope` in `main.dart`, but this feature does not add a new, feature-specific exception to how every other feature is wired. If the application later adopts Riverpod consistently across all features, that is a separate, deliberate migration — not something to introduce piecemeal through one new feature's technical design.

---

## Navigation Entry Point (Temporary)

MFS-015 does not specify how users navigate to the Lure Catalog, and the application currently has no dedicated navigation shell at all (no drawer, no bottom navigation, no tabs, no home menu) — `MapScreen` is, today, the entire application's one and only screen, reached via the app's single GoRouter route (`/`).

Given that, the only place available to hang *any* entry point is the current app shell. This TD adds one new `AppBar` action button to `MapScreen` that opens `LureCatalogListPage` via `Navigator.push`:

```dart
IconButton(
  key: const Key('openLureCatalogButton'),
  icon: const Icon(Icons.menu_book),
  tooltip: 'Viehekatalogi',
  onPressed: () => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => LureCatalogListPage(repository: _lureCatalogRepository),
    ),
  ),
),
```

**This must not be read as a statement that the Lure Catalog is conceptually a Map sub-feature.** It is a temporary placement of convenience, for exactly one reason: it is the only existing screen with an `AppBar` to attach a link to. The dependency this creates (`map` → `lure_catalog`, for navigation only) is one-way and is expected to be one of the first things removed or relocated once the application has real navigation (a home screen, a drawer, a bottom navigation bar, or similar) — a redesign this TD explicitly does not attempt.

Requirements:

- `MapScreen` gains exactly one new field (`_lureCatalogRepository`) and one new `AppBar` action — nothing else about `MapScreen` changes
- no GoRouter route is added for the catalog (consistent with how `CatchDetailsPage`/`CatchPhotoViewer` are already opened via plain `Navigator.push`, not routes)
- broader navigation redesign is out of scope for this TD and is not blocked or precluded by this temporary hook

---

## Catalog List Page

```text
lib/features/lure_catalog/presentation/widgets/lure_catalog_list_page.dart
```

A plain `StatefulWidget`, constructed with a required `LureCatalogRepository`, pushed via `Navigator.push(MaterialPageRoute(...))`.

```dart
class LureCatalogListPage extends StatefulWidget {
  const LureCatalogListPage({super.key, required this.repository});

  final LureCatalogRepository repository;

  ...
}
```

Local state:

```dart
String _searchText = '';
String? _manufacturerFilter;
String? _lureTypeFilter;
List<String> _manufacturers = [];
List<String> _lureTypes = [];
bool _isLoading = true;
String? _loadError;
List<LureCatalogEntry> _entries = [];
```

Load sequence (`initState`):

1. `await widget.repository.ensureSeeded();`
2. Load `_manufacturers`/`_lureTypes` via `getDistinctManufacturers`/`getDistinctLureTypes`.
3. Run the initial `browse()` with no search/filters.
4. On any failure, set `_loadError` instead of throwing.

Every subsequent search-text change or filter change re-runs `browse(searchText: ..., manufacturer: ..., lureType: ...)` and replaces `_entries` — the same "user changes input, repository re-queries, `setState` with the new list" pattern already used by, for example, `FishingSpotDetailsBottomSheet`'s catches list.

The list itself uses `ListView.builder` (lazy/virtualized — required by [Performance](#performance)), rendering one `LureCatalogListItem` per entry.

---

## Catalog List Item

```text
lib/features/lure_catalog/presentation/widgets/lure_catalog_list_item.dart
```

Mirrors `CatchListItem`'s shape: a row with a leading `LureImage` (square, `BoxFit.cover`) and a text column (manufacturer + model, then variant-distinguishing detail, e.g. color/size), tappable to open `LureDetailsPage`.

```dart
class LureCatalogListItem extends StatelessWidget {
  const LureCatalogListItem({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final LureCatalogEntry entry;
  final VoidCallback onTap;

  ...
}
```

Unlike `CatchListItem`, this widget needs no `FutureBuilder`/async image load — `entry.effectiveImageReference` is already resolved data.

---

## Filter Bar

```text
lib/features/lure_catalog/presentation/widgets/lure_catalog_filter_bar.dart
```

A small stateless widget rendering:

- a search `TextField`
- a manufacturer filter control (e.g. a `DropdownButton<String?>` populated from `_manufacturers`, with a "Kaikki valmistajat" / all-manufacturers option mapping to `null`)
- a lure-type filter control (same shape, using `lureTypeDisplayLabel` for each option's visible text, populated from `_lureTypes`)

Takes current values and `onChanged` callbacks; owns no repository or query logic itself.

---

## Lure Details Page

```text
lib/features/lure_catalog/presentation/widgets/lure_details_page.dart
```

A `Scaffold` + `AppBar` pushed via `Navigator.push(MaterialPageRoute(...))`, mirroring `CatchDetailsPage`'s "full-screen page, not a modal Bottom Sheet" precedent.

```dart
class LureDetailsPage extends StatelessWidget {
  const LureDetailsPage({super.key, required this.entry});

  final LureCatalogEntry entry;

  static Future<void> open(BuildContext context, LureCatalogEntry entry) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => LureDetailsPage(entry: entry)),
    );
  }

  ...
}
```

It is a `StatelessWidget` — no editable state, no load-on-open query, no repository dependency at all; it receives an already-resolved `LureCatalogEntry`.

Body: `SingleChildScrollView` with, in order: `LureImage` (large, prominent), manufacturer, product family (if present), model name, lure type (localized label), color (if present), length (if present, converted to cm for display), weight (if present, converted appropriately), running depth range (if present, converted to meters for display), buoyancy (localized label, if present). Missing optional fields simply omit their row.

No overflow menu, no Edit, no Delete — no actions at all beyond Back, per MFS-015 FR-5.

---

## Loading, Empty, and Error States

- **Loading**: while `ensureSeeded()`/the initial `browse()` is in flight, `LureCatalogListPage` shows a centered `CircularProgressIndicator`.
- **Empty search/filter result**: when `browse()` returns an empty list *and* `_loadError` is null, show a clear "no results" message, distinct from loading.
- **Read failure**: if `ensureSeeded()`/`browse()` throws, `_loadError` is set and the list is replaced with a clear error message; search/filter controls remain usable so the user can retry.
- A genuinely empty catalog degrades to the same "no results" message.

---

## Accessibility

- Each `LureCatalogListItem` exposes a semantic label combining manufacturer, model, and the variant's distinguishing detail.
- `LureImage` wraps its `Image.asset`/placeholder in `Semantics(label: ..., image: true)`.
- The search field and both filter controls carry accessible labels.
- Tap targets follow the same Material 3 sizing already used throughout the app.

---

## Performance

- `LureCatalogListPage`'s list uses `ListView.builder` — off-screen rows are never built or held.
- `LureImage` decodes at its requested `size`, never at arbitrary/full source resolution.
- `ensureSeeded()`/`browse()`/`getDistinctManufacturers()`/`getDistinctLureTypes()` are only ever called from `LureCatalogListPage`'s load sequence and its filter/search change handlers — never from application startup or `MapScreen`'s own initialization. Opening the map does not touch the lure catalog tables.
- At "thousands of variants" scale, the three indexes keep the manufacturer filter, lure-type filter, and the variant→model join efficient. `LIKE '%...%'` search against the precomputed `searchText` columns cannot use a B-tree index and will scan; at a few thousand rows this is expected to remain fast enough for a foreground UI interaction. SQLite FTS5 remains the named follow-up if it is not (out of scope here).

---

# Testing

## Domain Tests

```text
test/features/lure_catalog/domain/lure_model_test.dart
test/features/lure_catalog/domain/lure_variant_test.dart
test/features/lure_catalog/domain/lure_type_labels_test.dart
```

Cover:

- valid `LureModel`/`LureVariant` construction
- empty `id`/`manufacturer`/`modelName`/`lureType` rejection (`LureModel`)
- empty `id`/`lureModelId` rejection (`LureVariant`)
- the distinguishing-information assertion
- non-positive measurement rejection
- `minRunningDepthMillimeters > maxRunningDepthMillimeters` rejection
- `lureTypeDisplayLabel`/`buoyancyDisplayLabel` known-code and unknown-code-fallback behavior (must not throw)

---

## Database Tests

```text
test/features/lure_catalog/data/lure_catalog_database_test.dart
```

Cover, following `catch_photos_database_test.dart`'s pattern:

- schema migration from version 3 succeeds
- existing Fishing Spots, Catches, and Catch Photos survive the migration
- a `LureModel`/`LureVariant` row can be inserted and read back after migration
- the foreign key rejects a `LureVariant` referencing a non-existent `lureModelId`
- deleting a `LureModel` cascades its `LureVariant` rows
- inserting a `LureVariant` with all three distinguishing fields null violates the `CHECK` constraint
- inserting a non-positive measurement violates its `CHECK` constraint

---

## Mapper Tests

```text
test/features/lure_catalog/data/lure_catalog_mapper_test.dart
```

Cover:

- a joined row pair maps to the correct `LureCatalogEntry`
- `effectiveImageReference` variant-then-model fallback behavior
- `_modelSearchText`/`_variantSearchText` lowercase and concatenate the expected fields, including correct lowercasing of `ä`/`ö`
- `LureModel`/`LureVariant` → companion mapping round-trips correctly, including all-null optional fields, and stamps the given `seedVersion`

---

## Repository Tests

```text
test/features/lure_catalog/data/lure_catalog_repository_test.dart
```

Cover:

- `ensureSeeded()` inserts all seed models/variants on first call, each with `seedVersion == currentLureCatalogSeedVersion` and `retiredAt == null`
- `ensureSeeded()` called a second time performs no writes (idempotency)
- **correction**: a row whose stored `seedVersion` is lower than current is updated to the (simulated newer) seed content; `createdAt` is preserved, `updatedAt` changes
- **server-owned row untouched**: a row with `seedVersion == null` is never modified by `ensureSeeded()`, even when its id matches a current seed entry with different content
- **retirement**: a seed-owned variant id no longer present in the seed source gets `retiredAt` set, and is not deleted
- **un-retirement**: a previously retired variant id that reappears in the seed source has `retiredAt` cleared
- `browse()` excludes retired variants by default
- `getEntryById()` still returns a retired variant
- `browse()` with no arguments returns all (non-retired) entries in the documented sort order
- `browse(searchText: ...)` matches manufacturer, product family, model name, variant name, color name, and manufacturer color code independently
- `browse(searchText: ...)` correctly matches a Finnish `ä`/`ö` term regardless of the search term's case (e.g. searching `"SINIVIHREÄ"` matches a stored `"Sinivihreä"`)
- `browse(manufacturer: ...)`/`browse(lureType: ...)` filter correctly, independently and combined with search
- `browse()` for an unrecognized `lureType` value present in the data still returns matching rows
- `getEntryById()` returns `null` for an unknown id
- `getDistinctManufacturers()`/`getDistinctLureTypes()` return sorted, deduplicated values

---

## Widget Tests

```text
test/features/lure_catalog/presentation/widgets/lure_catalog_list_item_test.dart
test/features/lure_catalog/presentation/widgets/lure_catalog_list_page_test.dart
test/features/lure_catalog/presentation/widgets/lure_details_page_test.dart
```

`LureCatalogListItem` cover: renders manufacturer/model/distinguishing text; renders image when present; renders placeholder when absent; tapping invokes `onTap`.

`LureCatalogListPage` cover: loading state; full seed catalog renders after load; search narrows the list (including a Finnish-character search); manufacturer filter; lure-type filter; combined search+filters; clearing a filter restores the wider list; empty-result message; error message when the repository throws; tapping an item opens `LureDetailsPage` with the correct entry.

`LureDetailsPage` cover: renders all present fields; omits rows for absent optional fields; renders image or placeholder; Back returns to the list.

---

# Platform Testing

Physical Android testing is required.

Test:

- catalog browses correctly on first launch after upgrade (migration + initial reconciliation)
- catalog browses correctly on a second launch (idempotent reconciliation, no duplicates)
- search behaves correctly, including Finnish characters
- manufacturer filter behaves correctly
- lure-type filter behaves correctly
- combined search + filters
- details page renders correctly for a variant with all optional fields present, and for one with several absent
- placeholder image displays correctly where a seed entry has no image
- app works with the device in airplane mode
- small-screen layout for list and details
- the temporary entry point from the Map screen works

---

# Expected Files To Create

**Lib — 14 new files, plus one new asset directory:**

```text
lib/features/lure_catalog/domain/lure_model.dart
lib/features/lure_catalog/domain/lure_variant.dart
lib/features/lure_catalog/domain/lure_catalog_entry.dart
lib/features/lure_catalog/domain/lure_type_labels.dart
lib/features/lure_catalog/data/local/lure_models_table.dart
lib/features/lure_catalog/data/local/lure_variants_table.dart
lib/features/lure_catalog/data/local/lure_catalog_seed_data.dart
lib/features/lure_catalog/data/lure_catalog_mapper.dart
lib/features/lure_catalog/data/lure_catalog_repository.dart
lib/features/lure_catalog/presentation/widgets/lure_catalog_list_page.dart
lib/features/lure_catalog/presentation/widgets/lure_catalog_list_item.dart
lib/features/lure_catalog/presentation/widgets/lure_catalog_filter_bar.dart
lib/features/lure_catalog/presentation/widgets/lure_details_page.dart
lib/features/lure_catalog/presentation/widgets/lure_image.dart
assets/lure_catalog/  (a handful of placeholder image files — not Dart source)
```

**Test — 9 new files:**

```text
test/features/lure_catalog/domain/lure_model_test.dart
test/features/lure_catalog/domain/lure_variant_test.dart
test/features/lure_catalog/domain/lure_type_labels_test.dart
test/features/lure_catalog/data/lure_catalog_database_test.dart
test/features/lure_catalog/data/lure_catalog_mapper_test.dart
test/features/lure_catalog/data/lure_catalog_repository_test.dart
test/features/lure_catalog/presentation/widgets/lure_catalog_list_item_test.dart
test/features/lure_catalog/presentation/widgets/lure_catalog_list_page_test.dart
test/features/lure_catalog/presentation/widgets/lure_details_page_test.dart
```

**Total: 14 new lib Dart files + 1 new asset directory + 9 new test files = 23 new Dart files (24 new filesystem entries counting the asset directory).**

There is no `lure_catalog_providers.dart` and no `presentation/providers/` directory in this revision — that file and directory were removed along with Riverpod (see [Dependency Construction](#dependency-construction)).

Exact widget file separation may be adjusted if a smaller structure is clearer, consistent with the same allowance given in TD-013.

---

# Expected Files To Modify

**3 files:**

```text
pubspec.yaml                                    (declare assets/lure_catalog/ under flutter: assets:)
lib/core/database/app_database.dart             (register LureModels/LureVariants, schema 3 -> 4, migration)
lib/features/map/presentation/map_screen.dart   (construct LureCatalogRepository; add the temporary AppBar entry point)
```

`map_screen.dart`'s change is now two small, related additions: a `_lureCatalogRepository` field (constructed the same way `_catchRepository` already is) and one `AppBar` action button — see [Dependency Construction](#dependency-construction) and [Navigation Entry Point](#navigation-entry-point-temporary). Both are explicitly flagged as temporary/minimal, not a final design, in those sections.

Modify generated Drift files only through code generation.

---

# Implementation Stages for Claude Code

1. **Domain** — `LureModel`, `LureVariant`, `LureCatalogEntry`, `lure_type_labels.dart`, plus their unit tests.
2. **Database** — `LureModels`/`LureVariants` tables (including `searchText`, `seedVersion`, `retiredAt`), `AppDatabase` registration, schema 3→4 migration, migration/constraint tests.
3. **Mapper** — `LureCatalogMapper` (including `searchText` computation and versioned companion builders), plus mapper tests.
4. **Seed data and repository** — `lure_catalog_seed_data.dart` (with UUID-authored ids and `currentLureCatalogSeedVersion`), `LureCatalogRepository` (`ensureSeeded` with full reconciliation, `browse`, `getEntryById`, `getDistinctManufacturers`, `getDistinctLureTypes`), plus repository tests covering insert/correct/server-owned-skip/retire/un-retire and Finnish search.
5. **Presentation** — `LureImage`, `LureCatalogListItem` (+ tests), `LureCatalogFilterBar`, `LureCatalogListPage` (+ tests, manually constructed, not `ConsumerStatefulWidget`), `LureDetailsPage` (+ tests).
6. **Entry point and assets** — `MapScreen`'s `_lureCatalogRepository` field and AppBar button, `pubspec.yaml` asset declaration, placeholder image assets.
7. **Verification** — `dart format .`, `flutter analyze`, `flutter test`; fix anything introduced.
8. **Physical Android testing** per the plan above, then a Stage Report.

Each stage should be committed to working, passing state before moving to the next.

---

# Implementation Notes

- Inspect the current repository (schema version, table list) before implementation; do not assume it matches this document if time has passed.
- Follow current naming and import conventions (see `FishingSpotRepository`/`CatchRepository`/`CatchPhotoRepository`).
- Reuse the existing `AppSpacing`/`AppRadius` design tokens.
- Keep the Finnish `lureType`/`buoyancy` labels in one place (`lure_type_labels.dart`).
- Do not add `List<LureVariant>` to `LureModel`, or vice versa.
- Do not introduce repository interfaces, DAO, service, or use-case layers.
- Do not introduce Riverpod providers, `ConsumerWidget`/`ConsumerStatefulWidget`, or any other DI mechanism beyond manual construction for this feature.
- Do not introduce reactive database streams (`watch()`) for this feature.
- Do not silently catch and hide a seeding/reconciliation failure — surface it as the list's error state.
- Do not generate seed ids at runtime — they must be static literals (see [Identity and ID Scheme](#identity-and-id-scheme)).
- Prefer private helpers for focused implementation details; keep public APIs small.

---

# Validation

Run code generation using the project's established command.

Run:

```bash
dart format .
```

Run:

```bash
flutter analyze
```

Run:

```bash
flutter test
```

All must pass. Review generated Drift changes. Confirm the schema version and migration are correct.

---

# Documentation

After successful implementation, update `docs/project-status.md` with:

- Lure Catalog Foundation implementation status
- schema migration status (3 → 4)
- new bundled assets
- the temporary Map-screen entry point (flagged as temporary)
- physical testing status

Do not modify MFS-015 or TD-015 after implementation merely to match deviations — report deviations explicitly and obtain approval when required.

---

# Deliverables

Report:

1. Files created
2. Files modified
3. Platform configuration changes (asset declaration)
4. Domain models added
5. Drift tables added, including the `searchText`/`seedVersion`/`retiredAt` bookkeeping columns
6. Schema version change
7. Migration implementation
8. Repository methods added
9. Seed reconciliation behavior verified (insert, correct, server-owned-skip, retire, un-retire)
10. Presentation widgets added
11. Error handling
12. Tests added
13. `dart format` result
14. `flutter analyze` result
15. `flutter test` result and number of passing tests
16. Generated files changed
17. Physical Android test status
18. Any deviations from MFS-015
19. Any deviations from TD-015

Do not commit.

---

# Definition of Done

The feature is considered complete when:

- The implementation satisfies all requirements in MFS-015.
- The implementation follows TD-015.
- Users can browse the full seed catalog.
- Users can search the catalog across manufacturer, product family, model name, variant name, color name, and manufacturer color code, including Finnish `ä`/`ö` text, case-insensitively.
- Users can filter by manufacturer and by lure type, independently and combined.
- Users can open a read-only details page for any catalog variant.
- Missing optional fields render cleanly in both list and details views.
- No create, edit, or delete operation exists anywhere in the catalog UI or repository.
- An unrecognized `lureType`/`buoyancy` code loads, browses, filters, and displays correctly via its fallback label.
- The catalog works fully offline.
- Seed reconciliation is idempotent, can correct previously-shipped rows, never touches a row with a null `seedVersion`, and retires (never deletes) a seed entry removed from a later revision.
- Catalog identity uses opaque authored UUIDs, never slugs derived from display text.
- The database migration succeeds without losing existing Fishing Spot, Catch, or Catch Photo data.
- No repository interfaces, DAO, service, or use-case layers were introduced.
- No reactive database streams were introduced for this feature.
- No Riverpod provider or Consumer widget was introduced for this feature; the repository is constructed manually like every other repository in the app.
- The Map-screen entry point is documented as temporary, and no broader navigation redesign was attempted.
- All generated files are up to date.
- `dart format .` completes successfully.
- `flutter analyze` reports no issues.
- `flutter test` passes.
- Physical Android testing has been completed successfully.
- Architecture review has been completed.
- Code review has been completed.
- Documentation has been updated.
- The feature is ready to be committed.
