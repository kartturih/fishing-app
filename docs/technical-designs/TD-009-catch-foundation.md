# TD-009: Catch Foundation Implementation

## Status

Approved

---

## Related Specification

* MFS-009: Catch Foundation

---

## Summary

Implement the domain and persistence foundation for catches.

This technical design introduces:

* Catch domain model
* FishSpecies enum
* Finnish species display names
* Drift catches table
* Text-based enum persistence
* Fishing spot foreign key
* Cascading catch deletion
* Catch mapper
* Concrete CatchRepository
* Drift schema migration

No catch user interface is implemented in this milestone.

---

## Architecture

The catches feature is implemented as an independent feature.

```text
lib/
├── core/
│   └── database/
│       └── app_database.dart
└── features/
    └── catches/
        ├── data/
        │   ├── local/
        │   │   └── catches_table.dart
        │   ├── catch_mapper.dart
        │   └── catch_repository.dart
        └── domain/
            ├── catch.dart
            ├── fish_species.dart
            └── fish_species_extensions.dart
```

No DAO abstraction is introduced.

No repository interface is introduced.

No service or use-case layer is introduced.

---

## Domain Model

Create:

```text
lib/features/catches/domain/catch.dart
```

The model must remain independent from Flutter, Drift, and database-specific types.

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
  });

  final String id;
  final String fishingSpotId;
  final FishSpecies species;
  final DateTime caughtAt;
  final int? weightGrams;
  final int? lengthMillimeters;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

The model may include equality support if the project already uses an established equality approach.

Do not introduce a new equality dependency only for this model.

---

## Domain Validation

The domain model must not silently accept invalid measurements.

When provided:

```text
weightGrams > 0
lengthMillimeters > 0
```

Zero and negative values are invalid.

Unknown measurements must be represented as `null`.

Validation may be implemented using constructor assertions if that matches the existing project style.

Do not introduce a new validation framework.

---

## Canonical Storage

Store measurements using integer canonical units:

```text
Weight: grams
Length: millimeters
```

Examples:

```text
2450 g
685 mm
```

The presentation layer will later format these values as:

```text
2.45 kg
68.5 cm
```

Unit conversion and display formatting do not belong in the database layer.

---

## FishSpecies Enum

Create:

```text
lib/features/catches/domain/fish_species.dart
```

The enum uses stable English identifiers.

Example structure:

```dart
enum FishSpecies {
  pike,
  perch,
  zander,

  brownTrout,
  rainbowTrout,
  atlanticSalmon,
  grayling,
  whitefish,

  burbot,

  roach,
  bream,
  ide,
  rudd,
  bleak,
  tench,
  crucianCarp,
  carp,

  eel,
  asp,
}
```

The implementation may include additional species approved in MFS-009.

The final list must use authoritative Finnish species information.

Do not include a generic `other` value.

Enum identifiers are persistent database identifiers.

After release, existing enum identifiers must not be renamed without a database migration.

---

## Fish Species Display Names

Create:

```text
lib/features/catches/domain/fish_species_extensions.dart
```

Add a display-name extension:

```dart
extension FishSpeciesDisplayName on FishSpecies {
  String get finnishName {
    switch (this) {
      case FishSpecies.pike:
        return 'Hauki';
      case FishSpecies.perch:
        return 'Ahven';
      case FishSpecies.zander:
        return 'Kuha';
      case FishSpecies.asp:
        return 'Toutain';
      // Remaining species
    }
  }
}
```

Requirements:

* All enum values must have a Finnish display name.
* The switch must be exhaustive.
* Display names must not be stored in the database.
* The implementation must remain replaceable by Flutter localization later.

Do not add Flutter dependencies to the enum or extension.

---

## Drift Table

Create:

```text
lib/features/catches/data/local/catches_table.dart
```

Suggested table:

```dart
class Catches extends Table {
  TextColumn get id => text()();

  TextColumn get fishingSpotId => text().references(
        FishingSpots,
        #id,
        onDelete: KeyAction.cascade,
      )();

  TextColumn get species => text()();

  DateTimeColumn get caughtAt => dateTime()();

  IntColumn get weightGrams => integer().nullable()();

  IntColumn get lengthMillimeters => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

Use the existing FishingSpots table class and import path.

The exact Drift syntax may be adjusted to match the installed Drift version.

---

## Database Constraints

Add database-level checks when practical and supported cleanly by the existing Drift setup.

Desired constraints:

```text
weightGrams IS NULL OR weightGrams > 0
lengthMillimeters IS NULL OR lengthMillimeters > 0
```

Do not add overly complex custom SQL if it would reduce maintainability.

Repository and domain validation remain required even if database checks are added.

---

## Foreign Key

Every catch belongs to one fishing spot.

The catches table references:

```text
FishingSpots.id
```

Required behavior:

```text
ON DELETE CASCADE
```

Deleting a fishing spot must automatically delete all catches associated with it.

Do not manually delete catches in FishingSpotRepository if the database cascade handles it.

Foreign key enforcement must be enabled in the Drift database configuration.

---

## Species Persistence

Store the enum using its textual name.

Examples:

```text
pike
perch
zander
brownTrout
```

Do not store enum indexes.

The mapper should use:

```dart
catchModel.species.name
```

for database writes.

For reads, convert with an explicit lookup:

```dart
FishSpecies.values.firstWhere(
  (species) => species.name == storedValue,
)
```

An unsupported stored value must cause an explicit failure.

Do not silently map unknown values to another species.

A dedicated converter may be used if it improves clarity, but a new abstraction is not required.

---

## Catch Mapper

Create:

```text
lib/features/catches/data/catch_mapper.dart
```

The mapper owns conversions between:

* Drift catch row
* Catch domain model
* Drift companion

Suggested API:

```dart
class CatchMapper {
  const CatchMapper();

  Catch toDomain(CatchRow row);

  CatchesCompanion toCompanion(Catch catchModel);
}
```

Use the actual generated Drift row type.

The mapper must:

* Preserve all timestamps.
* Preserve nullable measurements.
* Convert textual species identifiers into FishSpecies values.
* Convert FishSpecies values into stable textual names.
* Fail explicitly for unsupported stored species identifiers.

Do not put identifier generation inside the mapper.

---

## Catch Repository

Create:

```text
lib/features/catches/data/catch_repository.dart
```

Use a concrete repository.

Suggested constructor:

```dart
class CatchRepository {
  CatchRepository({
    required AppDatabase database,
    CatchMapper mapper = const CatchMapper(),
  });
}
```

Adjust constructor style to match existing repositories.

Required operations:

```dart
Future<List<Catch>> getByFishingSpotId(String fishingSpotId);

Future<Catch?> getById(String id);
```

### getByFishingSpotId

Requirements:

* Query only catches matching the given fishing spot identifier.
* Map all rows into domain models.
* Return a deterministic order.

Recommended ordering:

```text
caughtAt descending
```

Newest catches should appear first.

### getById

Requirements:

* Return the matching Catch domain model.
* Return `null` when no row exists.
* Do not throw for a normal not-found result.

---

## Identifier Generation

The repository will own identifier generation when catch creation is added.

MFS-009 does not require a public create operation yet.

Do not add unused identifier-generation code unless needed by the current implementation.

When creation is implemented later, use the same identifier strategy as FishingSpotRepository.

---

## AppDatabase Integration

Update:

```text
lib/core/database/app_database.dart
```

Register the Catches table in the Drift database annotation.

Example:

```dart
@DriftDatabase(
  tables: [
    FishingSpots,
    Catches,
  ],
)
```

Use the project's actual annotation structure.

Import the feature-owned catches table from:

```text
features/catches/data/local/catches_table.dart
```

The core database registers the table but does not own its feature-specific implementation.

---

## Schema Version

Increment the current Drift schema version by one.

Example:

```dart
@override
int get schemaVersion => 2;
```

Use the actual next schema version from the repository.

Do not assume version 2 if the current database version is already higher.

---

## Migration

Update the database migration strategy.

When upgrading from the previous schema version:

```dart
await migrator.createTable(catches);
```

Requirements:

* Preserve all existing fishing spots.
* Preserve all existing application data.
* Create only the new catches table.
* Do not recreate or delete the existing fishing spots table.
* Do not reset the database.
* Do not use destructive migration.

Example structure:

```dart
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (migrator) async {
    await migrator.createAll();
  },
  onUpgrade: (migrator, from, to) async {
    if (from < newSchemaVersion) {
      await migrator.createTable(catches);
    }
  },
  beforeOpen: (details) async {
    await customStatement('PRAGMA foreign_keys = ON');
  },
);
```

Adapt the condition to the actual schema version.

---

## Foreign Key Enforcement

Ensure SQLite foreign keys are enabled:

```sql
PRAGMA foreign_keys = ON
```

This must be applied whenever the database is opened.

Do not assume SQLite enables foreign keys automatically.

The implementation must preserve any existing `beforeOpen` behavior.

---

## Generated Files

After changing Drift tables or database registration, run the project's existing Drift generation command.

Typical command:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Use the command already established in the repository if different.

Generated Drift files must not be edited manually.

---

## Presentation Layer

No presentation implementation is required.

Do not add:

* Catch screens
* Catch dialogs
* Catch bottom sheets
* Catch providers
* Catch form state
* Map changes

An empty `presentation` directory is not required.

Do not create empty directories solely for future use.

---

## Riverpod

No Riverpod provider is required in this milestone unless repository dependency injection already follows an established provider pattern that requires one.

Do not introduce new state-management architecture.

---

## Error Handling

Normal not-found repository queries return `null`.

Database and mapping errors may propagate using the existing project error-handling conventions.

Unsupported species values must fail explicitly with a descriptive error.

Example:

```dart
StateError('Unsupported fish species: $storedValue')
```

Do not silently discard invalid rows.

---

## Implementation Order

1. Create FishSpecies enum.
2. Create Finnish display-name extension.
3. Create Catch domain model.
4. Create Catches Drift table.
5. Register the table in AppDatabase.
6. Increment schema version.
7. Add non-destructive migration.
8. Ensure foreign keys are enabled.
9. Run Drift code generation.
10. Create CatchMapper.
11. Create CatchRepository.
12. Run formatting.
13. Run static analysis.
14. Perform architecture review.
15. Test migration and cascade behavior on Android.

---

## Validation

Run:

```bash
dart format .
flutter analyze
```

Run Drift generation before analysis when required.

---

## Physical Android Test

Use an installation containing existing fishing spots.

### Migration Test

1. Install or open the previous application version.
2. Create at least one fishing spot.
3. Close the application.
4. Install or run the new application version without clearing application data.
5. Verify the application starts normally.
6. Verify the existing fishing spot remains available.

### Catch Persistence Test

Because no UI exists, verify through an appropriate temporary development mechanism or automated integration path.

The final production code must not retain temporary debug insertion UI.

Verify:

* A catch can be inserted into the catches table.
* The catch can be queried by fishing spot identifier.
* Species is restored correctly.
* Weight remains unchanged.
* Length remains unchanged.
* Timestamps remain unchanged.

### Cascade Test

1. Create a fishing spot.
2. Insert at least one catch referencing it.
3. Delete the fishing spot through the existing application flow.
4. Verify the related catch row no longer exists.
5. Restart the application.
6. Verify the fishing spot and related catch remain deleted.

---

## Architecture Review Checklist

* Catch domain contains no Flutter imports.
* Catch domain contains no Drift imports.
* FishSpecies identifiers are stable and English.
* Finnish display names are separate from persistence.
* Enum indexes are not stored.
* Measurements use integers.
* Catch table is owned by the catches feature.
* AppDatabase only registers and migrates the table.
* Foreign key references FishingSpots.id.
* Cascading deletion is database-driven.
* Migration is non-destructive.
* Existing fishing spots are preserved.
* Repository is concrete.
* No DAO exists.
* No repository interface exists.
* No unused layers or folders are introduced.
* No catch UI is implemented.
* `flutter analyze` passes.

---

## Completion Criteria

TD-009 is complete when:

* All specified files are implemented.
* Drift code generation succeeds.
* Existing database migration succeeds.
* Existing fishing spots are preserved.
* Catch rows can be queried by fishing spot identifier.
* Species values round-trip through the database.
* Measurements round-trip through the database.
* Deleting a fishing spot cascades to its catches.
* No temporary debug implementation remains.
* Architecture review passes.
* `flutter analyze` passes.
* Physical Android validation passes.
