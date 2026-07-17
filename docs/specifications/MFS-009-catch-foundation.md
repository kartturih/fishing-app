# MFS-009: Catch Foundation

## Status

Approved

---

## Summary

Introduce the domain and persistence foundation for recording catches.

This milestone establishes the Catch model, fish species representation, database ownership, and the relationship between catches and fishing spots.

No catch creation user interface is included in this milestone.

---

## Goals

* Define a framework-independent Catch domain model.
* Define a stable FishSpecies enum.
* Store fish species using stable textual enum names.
* Add persistent local storage for catches using Drift.
* Associate every catch with a fishing spot.
* Establish feature-first ownership for catch-related persistence.
* Prepare the application for future catch logging features.

---

## Non-Goals

This milestone does not include:

* Catch creation UI
* Catch editing UI
* Catch deletion UI
* Catch list UI
* Catch details UI
* Photos
* Notes
* Lure information
* Weather information
* Water conditions
* Statistics
* Cloud synchronization
* Changes to map rendering
* Changes to fishing spot functionality

---

## Domain Model

Create a framework-independent `Catch` domain model.

The model contains:

```text
Catch
├── id
├── fishingSpotId
├── species
├── caughtAt
├── weightGrams
├── lengthMillimeters
├── createdAt
└── updatedAt
```

### Required Fields

* `id`
* `fishingSpotId`
* `species`
* `caughtAt`
* `createdAt`
* `updatedAt`

### Optional Fields

* `weightGrams`
* `lengthMillimeters`

Weight and length are optional because a catch may be recorded without measuring it.

---

## Catch Identity

Each catch uses an application-generated unique identifier.

The repository is responsible for generating identifiers when catches are created.

Database-generated integer identifiers must not be exposed to the domain layer.

---

## Fishing Spot Relationship

Every catch belongs to exactly one fishing spot.

Relationship:

```text
FishingSpot 1 ──── * Catch
```

The Catch model stores the fishing spot identifier as:

```dart
String fishingSpotId
```

The database must enforce the relationship using a foreign key.

Deleting a fishing spot must also delete its associated catches.

This behavior must be implemented using a database-level cascading delete.

---

## Fish Species

Create a dedicated FishSpecies enum.

Suggested location:

```text
lib/features/catches/domain/fish_species.dart
```

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
  // Additional species
}
```

The final enum should include fish species that:

* Occur permanently in Finland, or
* Are established introduced species in Finland, and
* Can realistically be caught by recreational or other legal fishing methods.

Species known only from isolated or accidental observations do not need to be included in the initial application catalog.

The species catalog must be based on authoritative Finnish sources, such as:

* Finnish Biodiversity Information Facility
* Natural Resources Institute Finland

---

## Species Persistence

Fish species must be stored in the database using stable textual enum names.

Example:

```text
pike
perch
zander
brownTrout
```

Enum indexes must not be stored.

This prevents existing database values from changing if enum values are reordered or new species are added.

Existing enum names must be treated as persistent identifiers and must not be renamed without a database migration.

---

## Species Display Names

Domain identifiers remain in English.

User-facing names are separate from the enum identifiers.

Example:

```text
FishSpecies.pike   → Hauki
FishSpecies.perch → Ahven
FishSpecies.zander → Kuha
FishSpecies.asp → Toutain
```

The initial implementation may use a domain extension for Finnish display names.

Suggested location:

```text
lib/features/catches/domain/fish_species_extensions.dart
```

The implementation must remain replaceable by Flutter localization later.

UI display names must not be stored in the database.

---

## Other Species

The initial catalog does not include a generic `other` species.

The goal is to provide a sufficiently complete Finnish species catalog so that catches can be recorded using the correct species.

A generic fallback may be reconsidered later if:

* The application expands outside Finland.
* Users need to record unidentified fish.
* Users need to record species missing from the catalog.

---

## Measurements

Weight is stored as whole grams:

```dart
int? weightGrams
```

Length is stored as whole millimeters:

```dart
int? lengthMillimeters
```

The domain and database store canonical measurement units.

The presentation layer is responsible for converting values into user-friendly formats (for example, centimeters with one decimal place).

Values must follow these rules:

- Weight must be greater than zero when provided.
- Length must be greater than zero when provided.
- Missing measurements are stored as null.
- Zero must not represent an unknown measurement.

---

## Date and Time

`caughtAt` represents when the fish was caught.

`createdAt` represents when the record was created.

`updatedAt` represents when the record was last modified.

All timestamps must use Dart `DateTime`.

The persistence implementation must preserve the exact recorded instant consistently.

User-facing local time formatting belongs to the presentation layer.

---

## Persistence

Add a Drift table for catches.

Suggested table ownership:

```text
lib/features/catches/data/local/catches_table.dart
```

The table contains:

* id
* fishingSpotId
* species
* caughtAt
* weightGrams
* lengthCentimeters
* createdAt
* updatedAt

The application's central Drift database registers the feature-owned table.

---

## Database Migration

Adding the catches table requires incrementing the Drift database schema version.

The migration must:

* Create the catches table.
* Preserve all existing fishing spots.
* Preserve all existing application data.
* Enable foreign key enforcement.
* Support cascading deletion from fishing spots to catches.

The migration must be safe for users who already have fishing spots stored in the application.

---

## Repository

Create a concrete CatchRepository.

Suggested location:

```text
lib/features/catches/data/catch_repository.dart
```

No repository interface is required.

No DAO abstraction is introduced.

The repository owns:

* Domain-to-database mapping
* Database-to-domain mapping
* Catch identifier generation
* Catch persistence operations

For this foundation milestone, the repository must support:

```dart
Future<List<Catch>> getByFishingSpotId(String fishingSpotId);

Future<Catch?> getById(String id);
```

Creation, editing, and deletion operations may be introduced in later Catch CRUD milestones.

---

## Mapper

Create a dedicated mapper between the Drift model and the Catch domain model.

Suggested location:

```text
lib/features/catches/data/catch_mapper.dart
```

The mapper must:

* Convert database rows into Catch domain models.
* Convert textual species identifiers into FishSpecies values.
* Convert Catch domain values into database companions.
* Fail explicitly when an unsupported stored species identifier is encountered.

Silent fallback to another species is not allowed.

---

## Feature Ownership

The catches feature owns:

* Catch domain model
* FishSpecies enum
* Species display metadata
* Catches Drift table
* Catch mapper
* Catch repository

The core database owns:

* Database initialization
* Schema version
* Migration registration
* Database-wide configuration

The fishing spots feature does not own Catch persistence.

---

## Proposed Structure

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

Generated Drift files are not shown.

---

## Validation Criteria

The milestone is complete when:

* The Catch domain model exists.
* The Catch model contains no Flutter or Drift dependencies.
* The FishSpecies enum exists.
* Species are stored using textual identifiers.
* Finnish display names are separate from persistence values.
* The catches table exists.
* The database schema version is incremented.
* Existing fishing spots survive the database migration.
* The foreign key relationship is enforced.
* Fishing spot deletion cascades to associated catches.
* Catch database rows can be mapped into domain models.
* Catch records can be queried by fishing spot identifier.
* `flutter analyze` passes.
* Architecture review is completed.
* Migration behavior is verified on a physical Android device.

---

## Future Milestones

Expected follow-up milestones include:

* Create Catch
* Catch List
* Catch Details
* Edit Catch
* Delete Catch
* Catch Photos
* Catch Notes
* Lure Information
* Catch Statistics
* Cloud Synchronization
