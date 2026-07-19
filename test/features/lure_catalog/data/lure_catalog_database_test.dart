import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';

/// A schema-3 snapshot of [AppDatabase] (no `LureModels`/`LureVariants`
/// tables), used to seed a database file that the real [AppDatabase] then
/// upgrades to schema 4. Mirrors the identical helper pattern in
/// catch_photos_database_test.dart. `catches` is created with a literal
/// `CREATE TABLE` matching the real schema-3 shape (no `lure_variant_id`):
/// the current `Catches` table class already includes that column
/// (MFS-017/TD-017), so `createTable(catches)` would create it too early,
/// breaking the schema-6 `addColumn` migration this database is later
/// upgraded through.
class _LegacyAppDatabase extends AppDatabase {
  _LegacyAppDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createTable(fishingSpots);
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
    },
  );
}

void main() {
  group('schema migration', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('lure_catalog_migration');
      dbFile = File('${tempDir.path}/fishing_app.sqlite');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('upgrades a v3 database and preserves existing data', () async {
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
      await legacyDb
          .into(legacyDb.catches)
          .insert(
            CatchesCompanion.insert(
              id: 'catch-1',
              fishingSpotId: 'spot-1',
              species: 'pike',
              caughtAt: 2000,
              createdAt: 2000,
              updatedAt: 2000,
            ),
          );
      await legacyDb
          .into(legacyDb.catchPhotos)
          .insert(
            CatchPhotosCompanion.insert(
              id: 'photo-1',
              catchId: 'catch-1',
              relativePath: 'catch_photos/catch-1/photo-1.jpg',
              sortOrder: 0,
              createdAt: 3000,
            ),
          );
      await legacyDb.close();

      final upgraded = AppDatabase(NativeDatabase(dbFile));
      addTearDown(upgraded.close);

      final spots = await upgraded.select(upgraded.fishingSpots).get();
      final catches = await upgraded.select(upgraded.catches).get();
      final photos = await upgraded.select(upgraded.catchPhotos).get();
      expect(spots, hasLength(1));
      expect(catches, hasLength(1));
      expect(photos, hasLength(1));

      // The new LureModels/LureVariants tables exist and are usable
      // post-migration.
      await upgraded
          .into(upgraded.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: 'model-1',
              manufacturer: 'Rapala',
              modelName: 'X-Rap Shad XRS08',
              lureType: 'crankbait',
              searchText: 'rapala x-rap shad xrs08',
              createdAt: 4000,
              updatedAt: 4000,
            ),
          );
      await upgraded
          .into(upgraded.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'variant-1',
              lureModelId: 'model-1',
              colorName: const Value('Hot Craw'),
              searchText: 'hot craw',
              createdAt: 4000,
              updatedAt: 4000,
            ),
          );
      final models = await upgraded.select(upgraded.lureModels).get();
      final variants = await upgraded.select(upgraded.lureVariants).get();
      expect(models, hasLength(1));
      expect(variants, hasLength(1));
    });
  });

  group('LureModels/LureVariants tables', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> insertModel({String id = 'model-1'}) async {
      await database
          .into(database.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: id,
              manufacturer: 'Rapala',
              modelName: 'X-Rap Shad XRS08',
              lureType: 'crankbait',
              searchText: 'rapala x-rap shad xrs08',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
    }

    test('a LureModel row can be inserted and read back', () async {
      await insertModel();

      final rows = await database.select(database.lureModels).get();
      expect(rows, hasLength(1));
      expect(rows.single.manufacturer, 'Rapala');
    });

    test('a LureVariant row can be inserted and read back', () async {
      await insertModel();
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

      final rows = await database.select(database.lureVariants).get();
      expect(rows, hasLength(1));
      expect(rows.single.colorName, 'Hot Craw');
    });

    test(
      'the foreign key rejects a LureVariant with an unknown lureModelId',
      () async {
        expect(
          () => database
              .into(database.lureVariants)
              .insert(
                LureVariantsCompanion.insert(
                  id: 'variant-1',
                  lureModelId: 'model-does-not-exist',
                  colorName: const Value('Hot Craw'),
                  searchText: 'hot craw',
                  createdAt: 1000,
                  updatedAt: 1000,
                ),
              ),
          throwsA(anything),
        );
      },
    );

    test('deleting a LureModel cascades its LureVariant rows', () async {
      await insertModel();
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

      await (database.delete(
        database.lureModels,
      )..where((t) => t.id.equals('model-1'))).go();

      final remaining = await database.select(database.lureVariants).get();
      expect(remaining, isEmpty);
    });

    test('the CHECK constraint rejects a variant with variantName, colorName, '
        'and manufacturerColorCode all null', () async {
      await insertModel();

      expect(
        () => database
            .into(database.lureVariants)
            .insert(
              LureVariantsCompanion.insert(
                id: 'variant-1',
                lureModelId: 'model-1',
                searchText: '',
                createdAt: 1000,
                updatedAt: 1000,
              ),
            ),
        throwsA(anything),
      );
    });

    test(
      'the CHECK constraint rejects a non-positive lengthMillimeters',
      () async {
        await insertModel();

        expect(
          () => database
              .into(database.lureVariants)
              .insert(
                LureVariantsCompanion.insert(
                  id: 'variant-1',
                  lureModelId: 'model-1',
                  colorName: const Value('Hot Craw'),
                  lengthMillimeters: const Value(0),
                  searchText: 'hot craw',
                  createdAt: 1000,
                  updatedAt: 1000,
                ),
              ),
          throwsA(anything),
        );
      },
    );

    test('the CHECK constraint rejects a non-positive weightGrams', () async {
      await insertModel();

      expect(
        () => database
            .into(database.lureVariants)
            .insert(
              LureVariantsCompanion.insert(
                id: 'variant-1',
                lureModelId: 'model-1',
                colorName: const Value('Hot Craw'),
                weightGrams: const Value(-5),
                searchText: 'hot craw',
                createdAt: 1000,
                updatedAt: 1000,
              ),
            ),
        throwsA(anything),
      );
    });

    test('the CHECK constraint rejects minRunningDepthMillimeters greater than '
        'maxRunningDepthMillimeters', () async {
      await insertModel();

      expect(
        () => database
            .into(database.lureVariants)
            .insert(
              LureVariantsCompanion.insert(
                id: 'variant-1',
                lureModelId: 'model-1',
                colorName: const Value('Hot Craw'),
                minRunningDepthMillimeters: const Value(2000),
                maxRunningDepthMillimeters: const Value(1000),
                searchText: 'hot craw',
                createdAt: 1000,
                updatedAt: 1000,
              ),
            ),
        throwsA(anything),
      );
    });

    test('the CHECK constraint accepts equal minRunningDepthMillimeters and '
        'maxRunningDepthMillimeters', () async {
      await insertModel();

      await database
          .into(database.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'variant-1',
              lureModelId: 'model-1',
              colorName: const Value('Hot Craw'),
              minRunningDepthMillimeters: const Value(1000),
              maxRunningDepthMillimeters: const Value(1000),
              searchText: 'hot craw',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );

      final rows = await database.select(database.lureVariants).get();
      expect(rows, hasLength(1));
    });

    test(
      'the CHECK constraint accepts a row with only one of '
      'minRunningDepthMillimeters/maxRunningDepthMillimeters present',
      () async {
        await insertModel();

        await database
            .into(database.lureVariants)
            .insert(
              LureVariantsCompanion.insert(
                id: 'variant-1',
                lureModelId: 'model-1',
                colorName: const Value('Hot Craw'),
                minRunningDepthMillimeters: const Value(1000),
                searchText: 'hot craw',
                createdAt: 1000,
                updatedAt: 1000,
              ),
            );

        final rows = await database.select(database.lureVariants).get();
        expect(rows, hasLength(1));
      },
    );
  });
}
