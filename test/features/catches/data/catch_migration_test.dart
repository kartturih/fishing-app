import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';

/// A schema-5 snapshot of [AppDatabase]'s `catches` table (no
/// `lure_variant_id` column), used to seed a database file that the real
/// [AppDatabase] then upgrades to schema 6 (MFS-017/TD-017).
///
/// Unlike every prior migration in this project (each of which only ever
/// added a whole new table via `migrator.createTable`), this milestone adds
/// a column to an *existing* table. The current `Catches` table class
/// already includes `lureVariantId`, so `migrator.createTable(catches)`
/// cannot be used to represent the pre-migration shape — it would create
/// the column that shouldn't exist yet. The legacy `catches` table is
/// therefore created with a literal `CREATE TABLE` statement matching the
/// real schema-5 shape instead.
class _LegacyAppDatabase extends AppDatabase {
  _LegacyAppDatabase(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      // Legacy (pre-MFS-024) fishing_spots shape: no water_body_id
      // column existed before schema 8, so this cannot reuse the live
      // FishingSpots table class (which now has one) via
      // migrator.createTable(fishingSpots) — mirrors this file's own
      // existing raw-SQL-legacy-shape precedent for `catches`.
      await customStatement('''
        CREATE TABLE fishing_spots (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      await customStatement('''
        CREATE TABLE catches (
          id TEXT NOT NULL PRIMARY KEY,
          fishing_spot_id TEXT NOT NULL REFERENCES fishing_spots (id) ON DELETE CASCADE,
          species TEXT NOT NULL,
          caught_at INTEGER NOT NULL,
          weight_grams INTEGER NULL CHECK (weight_grams IS NULL OR weight_grams > 0),
          length_millimeters INTEGER NULL CHECK (length_millimeters IS NULL OR length_millimeters > 0),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await migrator.createTable(catchPhotos);
      await migrator.createIndex(catchPhotosCatchIdSort);
      await migrator.createTable(lureModels);
      await migrator.createTable(lureVariants);
      await migrator.createIndex(lureModelsManufacturer);
      await migrator.createIndex(lureModelsLureType);
      await migrator.createIndex(lureVariantsLureModelId);
      await migrator.createTable(tackleBoxEntries);
    },
  );
}

/// A schema-6 snapshot of [AppDatabase]'s `catches` table (`lure_variant_id`
/// present, but no `notes` column), used to seed a database file that the
/// real [AppDatabase] then upgrades to schema 7 (MFS-023/TD-023).
///
/// The current `Catches` table class already includes `notes`, so
/// `migrator.createTable(catches)` cannot represent the pre-migration shape —
/// it would create the column that shouldn't exist yet. The legacy `catches`
/// table is therefore created with a literal `CREATE TABLE` statement
/// matching the real schema-6 shape instead, mirroring `_LegacyAppDatabase`
/// above.
class _LegacySchema6AppDatabase extends AppDatabase {
  _LegacySchema6AppDatabase(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      // Legacy (pre-MFS-024) fishing_spots shape: no water_body_id
      // column existed before schema 8, so this cannot reuse the live
      // FishingSpots table class (which now has one) via
      // migrator.createTable(fishingSpots) — mirrors this file's own
      // existing raw-SQL-legacy-shape precedent for `catches`.
      await customStatement('''
        CREATE TABLE fishing_spots (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      await customStatement('''
        CREATE TABLE catches (
          id TEXT NOT NULL PRIMARY KEY,
          fishing_spot_id TEXT NOT NULL REFERENCES fishing_spots (id) ON DELETE CASCADE,
          species TEXT NOT NULL,
          caught_at INTEGER NOT NULL,
          weight_grams INTEGER NULL CHECK (weight_grams IS NULL OR weight_grams > 0),
          length_millimeters INTEGER NULL CHECK (length_millimeters IS NULL OR length_millimeters > 0),
          lure_variant_id TEXT NULL REFERENCES lure_variants (id),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await migrator.createTable(catchPhotos);
      await migrator.createIndex(catchPhotosCatchIdSort);
      await migrator.createTable(lureModels);
      await migrator.createTable(lureVariants);
      await migrator.createIndex(lureModelsManufacturer);
      await migrator.createIndex(lureModelsLureType);
      await migrator.createIndex(lureVariantsLureModelId);
      await migrator.createTable(tackleBoxEntries);
    },
  );
}

void main() {
  group('schema migration', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('catch_lure_migration');
      dbFile = File('${tempDir.path}/fishing_app.sqlite');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('upgrades a v5 database and preserves existing data', () async {
      final legacyDb = _LegacyAppDatabase(NativeDatabase(dbFile));
      await legacyDb
          .into(legacyDb.fishingSpots)
          .insert(
            FishingSpotsCompanion.insert(
              id: 'spot-1',
              name: 'Old Spot',
              latitude: 61.0,
              longitude: 25.0,
              createdAt: 1000,
            ),
          );
      // Inserted via the legacy (7-column) shape - no lure_variant_id yet.
      await legacyDb.customStatement('''
        INSERT INTO catches (
          id, fishing_spot_id, species, caught_at, weight_grams,
          length_millimeters, created_at, updated_at
        ) VALUES (
          'catch-1', 'spot-1', 'pike', 2000, 1500, 600, 2000, 2000
        )
      ''');
      await legacyDb
          .into(legacyDb.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: 'model-1',
              manufacturer: 'Rapala',
              modelName: 'X-Rap Shad XRS08',
              lureType: 'crankbait',
              searchText: 'rapala x-rap shad xrs08',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      await legacyDb
          .into(legacyDb.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'variant-1',
              lureModelId: 'model-1',
              colorName: const Value('Hot Craw'),
              searchText: 'hot craw',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      await legacyDb.close();

      final upgraded = AppDatabase(NativeDatabase(dbFile));
      addTearDown(upgraded.close);

      final spots = await upgraded.select(upgraded.fishingSpots).get();
      final models = await upgraded.select(upgraded.lureModels).get();
      final variants = await upgraded.select(upgraded.lureVariants).get();
      final catches = await upgraded.select(upgraded.catches).get();
      expect(spots, hasLength(1));
      expect(models, hasLength(1));
      expect(variants, hasLength(1));
      expect(catches, hasLength(1));
      // The pre-existing row survives the upgrade with lureVariantId = null.
      expect(catches.single.id, 'catch-1');
      expect(catches.single.weightGrams, 1500);
      expect(catches.single.lureVariantId, isNull);

      // The new column is immediately usable after upgrade.
      await (upgraded.update(upgraded.catches)
            ..where((t) => t.id.equals('catch-1')))
          .write(const CatchesCompanion(lureVariantId: Value('variant-1')));
      final updated = await (upgraded.select(
        upgraded.catches,
      )..where((t) => t.id.equals('catch-1'))).getSingle();
      expect(updated.lureVariantId, 'variant-1');
    });

    test('upgrades a v6 database and preserves existing data', () async {
      final legacyDb = _LegacySchema6AppDatabase(NativeDatabase(dbFile));
      await legacyDb
          .into(legacyDb.fishingSpots)
          .insert(
            FishingSpotsCompanion.insert(
              id: 'spot-1',
              name: 'Old Spot',
              latitude: 61.0,
              longitude: 25.0,
              createdAt: 1000,
            ),
          );
      await legacyDb
          .into(legacyDb.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: 'model-1',
              manufacturer: 'Rapala',
              modelName: 'X-Rap Shad XRS08',
              lureType: 'crankbait',
              searchText: 'rapala x-rap shad xrs08',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      await legacyDb
          .into(legacyDb.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'variant-1',
              lureModelId: 'model-1',
              colorName: const Value('Hot Craw'),
              searchText: 'hot craw',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      // Inserted via the legacy (8-column) shape - no notes column yet.
      await legacyDb.customStatement('''
        INSERT INTO catches (
          id, fishing_spot_id, species, caught_at, weight_grams,
          length_millimeters, lure_variant_id, created_at, updated_at
        ) VALUES (
          'catch-1', 'spot-1', 'pike', 2000, 1500, 600, 'variant-1', 2000, 2000
        )
      ''');
      await legacyDb.close();

      final upgraded = AppDatabase(NativeDatabase(dbFile));
      addTearDown(upgraded.close);

      final spots = await upgraded.select(upgraded.fishingSpots).get();
      final catches = await upgraded.select(upgraded.catches).get();
      expect(spots, hasLength(1));
      expect(catches, hasLength(1));
      // The pre-existing row survives the upgrade, lureVariantId intact,
      // notes = null.
      expect(catches.single.id, 'catch-1');
      expect(catches.single.weightGrams, 1500);
      expect(catches.single.lureVariantId, 'variant-1');
      expect(catches.single.notes, isNull);

      // The new column is immediately usable after upgrade.
      await (upgraded.update(
        upgraded.catches,
      )..where((t) => t.id.equals('catch-1'))).write(
        const CatchesCompanion(notes: Value('Tuulinen ilta järvellä.')),
      );
      final updated = await (upgraded.select(
        upgraded.catches,
      )..where((t) => t.id.equals('catch-1'))).getSingle();
      expect(updated.notes, 'Tuulinen ilta järvellä.');
    });
  });

  group('Catches.lureVariantId', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> insertFishingSpot(AppDatabase database) async {
      await database
          .into(database.fishingSpots)
          .insert(
            FishingSpotsCompanion.insert(
              id: 'spot-1',
              name: 'Spot',
              latitude: 61.0,
              longitude: 25.0,
              createdAt: 1000,
            ),
          );
    }

    Future<void> insertModelAndVariant(AppDatabase database) async {
      await database
          .into(database.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: 'model-1',
              manufacturer: 'Rapala',
              modelName: 'X-Rap Shad XRS08',
              lureType: 'crankbait',
              searchText: 'rapala x-rap shad xrs08',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      await database
          .into(database.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'variant-1',
              lureModelId: 'model-1',
              colorName: const Value('Hot Craw'),
              searchText: 'hot craw',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
    }

    Future<void> insertCatch(
      AppDatabase database, {
      String id = 'catch-1',
      String? lureVariantId,
    }) async {
      await insertFishingSpot(database);
      await database
          .into(database.catches)
          .insert(
            CatchesCompanion.insert(
              id: id,
              fishingSpotId: 'spot-1',
              species: 'pike',
              caughtAt: 2000,
              lureVariantId: Value(lureVariantId),
              createdAt: 2000,
              updatedAt: 2000,
            ),
          );
    }

    test('a catch can be inserted with a lureVariantId', () async {
      await insertModelAndVariant(database);
      await insertCatch(database, lureVariantId: 'variant-1');

      final rows = await database.select(database.catches).get();
      expect(rows.single.lureVariantId, 'variant-1');
    });

    test('a catch can be inserted with no lureVariantId', () async {
      await insertCatch(database);

      final rows = await database.select(database.catches).get();
      expect(rows.single.lureVariantId, isNull);
    });

    test(
      'the foreign key rejects a catch with an unknown lureVariantId',
      () async {
        await insertFishingSpot(database);
        expect(
          () => database
              .into(database.catches)
              .insert(
                CatchesCompanion.insert(
                  id: 'catch-1',
                  fishingSpotId: 'spot-1',
                  species: 'pike',
                  caughtAt: 2000,
                  lureVariantId: const Value('variant-does-not-exist'),
                  createdAt: 2000,
                  updatedAt: 2000,
                ),
              ),
          throwsA(anything),
        );
      },
    );

    test(
      'onDelete: KeyAction.restrict rejects deleting a referenced LureVariant',
      () async {
        await insertModelAndVariant(database);
        await insertCatch(database, lureVariantId: 'variant-1');

        expect(
          () => (database.delete(
            database.lureVariants,
          )..where((t) => t.id.equals('variant-1'))).go(),
          throwsA(anything),
        );

        final rows = await database.select(database.catches).get();
        expect(rows, hasLength(1));
      },
    );

    test('deleting a Catch does not affect the LureVariant', () async {
      await insertModelAndVariant(database);
      await insertCatch(database, lureVariantId: 'variant-1');

      await (database.delete(
        database.catches,
      )..where((t) => t.id.equals('catch-1'))).go();

      final variants = await database.select(database.lureVariants).get();
      expect(variants, hasLength(1));
    });
  });
}
