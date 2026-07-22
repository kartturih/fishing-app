import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';

/// A schema-4 snapshot of [AppDatabase] (no `TackleBoxEntries` table), used
/// to seed a database file that the real [AppDatabase] then upgrades to
/// schema 5. Mirrors the identical helper pattern in
/// lure_catalog_database_test.dart / catch_photos_database_test.dart.
/// `catches` is created with a literal `CREATE TABLE` matching the real
/// schema-4 shape (no `lure_variant_id`): the current `Catches` table class
/// already includes that column (MFS-017/TD-017), so `createTable(catches)`
/// would create it too early, breaking the schema-6 `addColumn` migration
/// this database is later upgraded through.
class _LegacyAppDatabase extends AppDatabase {
  _LegacyAppDatabase(super.executor);

  @override
  int get schemaVersion => 4;

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
    },
  );
}

void main() {
  Future<void> insertModel(
    AppDatabase database, {
    String id = 'model-1',
  }) async {
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

  Future<void> insertVariant(
    AppDatabase database, {
    String id = 'variant-1',
    String lureModelId = 'model-1',
  }) async {
    await database
        .into(database.lureVariants)
        .insert(
          LureVariantsCompanion.insert(
            id: id,
            lureModelId: lureModelId,
            colorName: const Value('Hot Craw'),
            searchText: 'hot craw',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
  }

  group('schema migration', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'tackle_box_entries_migration',
      );
      dbFile = File('${tempDir.path}/fishing_app.sqlite');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('upgrades a v4 database and preserves existing data', () async {
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
      await insertModel(legacyDb);
      await insertVariant(legacyDb);
      await legacyDb.close();

      final upgraded = AppDatabase(NativeDatabase(dbFile));
      addTearDown(upgraded.close);

      final spots = await upgraded.select(upgraded.fishingSpots).get();
      final models = await upgraded.select(upgraded.lureModels).get();
      final variants = await upgraded.select(upgraded.lureVariants).get();
      expect(spots, hasLength(1));
      expect(models, hasLength(1));
      expect(variants, hasLength(1));

      // The new TackleBoxEntries table exists and is usable post-migration.
      await upgraded
          .into(upgraded.tackleBoxEntries)
          .insert(
            TackleBoxEntriesCompanion.insert(
              id: 'entry-1',
              lureVariantId: 'variant-1',
              addedAt: 2000,
              createdAt: 2000,
              updatedAt: 2000,
            ),
          );
      final entries = await upgraded.select(upgraded.tackleBoxEntries).get();
      expect(entries, hasLength(1));
    });
  });

  group('TackleBoxEntries table', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('a row can be inserted and read back', () async {
      await insertModel(database);
      await insertVariant(database);

      await database
          .into(database.tackleBoxEntries)
          .insert(
            TackleBoxEntriesCompanion.insert(
              id: 'entry-1',
              lureVariantId: 'variant-1',
              addedAt: 1000,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );

      final rows = await database.select(database.tackleBoxEntries).get();
      expect(rows, hasLength(1));
      expect(rows.single.lureVariantId, 'variant-1');
      expect(rows.single.personalPhotoRelativePath, isNull);
    });

    test('a row can store a personal photo relative path', () async {
      await insertModel(database);
      await insertVariant(database);

      await database
          .into(database.tackleBoxEntries)
          .insert(
            TackleBoxEntriesCompanion.insert(
              id: 'entry-1',
              lureVariantId: 'variant-1',
              personalPhotoRelativePath: const Value(
                'tackle_box_photos/entry-1.jpg',
              ),
              addedAt: 1000,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );

      final rows = await database.select(database.tackleBoxEntries).get();
      expect(
        rows.single.personalPhotoRelativePath,
        'tackle_box_photos/entry-1.jpg',
      );
    });

    test(
      'the foreign key rejects a row with an unknown lureVariantId',
      () async {
        expect(
          () => database
              .into(database.tackleBoxEntries)
              .insert(
                TackleBoxEntriesCompanion.insert(
                  id: 'entry-1',
                  lureVariantId: 'variant-does-not-exist',
                  addedAt: 1000,
                  createdAt: 1000,
                  updatedAt: 1000,
                ),
              ),
          throwsA(anything),
        );
      },
    );

    test(
      'the unique constraint rejects a second row for the same lureVariantId',
      () async {
        await insertModel(database);
        await insertVariant(database);
        await database
            .into(database.tackleBoxEntries)
            .insert(
              TackleBoxEntriesCompanion.insert(
                id: 'entry-1',
                lureVariantId: 'variant-1',
                addedAt: 1000,
                createdAt: 1000,
                updatedAt: 1000,
              ),
            );

        expect(
          () => database
              .into(database.tackleBoxEntries)
              .insert(
                TackleBoxEntriesCompanion.insert(
                  id: 'entry-2',
                  lureVariantId: 'variant-1',
                  addedAt: 2000,
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
        await insertModel(database);
        await insertVariant(database);
        await database
            .into(database.tackleBoxEntries)
            .insert(
              TackleBoxEntriesCompanion.insert(
                id: 'entry-1',
                lureVariantId: 'variant-1',
                addedAt: 1000,
                createdAt: 1000,
                updatedAt: 1000,
              ),
            );

        expect(
          () => (database.delete(
            database.lureVariants,
          )..where((t) => t.id.equals('variant-1'))).go(),
          throwsA(anything),
        );

        final entries = await database.select(database.tackleBoxEntries).get();
        expect(entries, hasLength(1));
      },
    );

    test('deleting a TackleBoxEntry does not affect the LureVariant', () async {
      await insertModel(database);
      await insertVariant(database);
      await database
          .into(database.tackleBoxEntries)
          .insert(
            TackleBoxEntriesCompanion.insert(
              id: 'entry-1',
              lureVariantId: 'variant-1',
              addedAt: 1000,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );

      await (database.delete(
        database.tackleBoxEntries,
      )..where((t) => t.id.equals('entry-1'))).go();

      final variants = await database.select(database.lureVariants).get();
      expect(variants, hasLength(1));
    });
  });
}
