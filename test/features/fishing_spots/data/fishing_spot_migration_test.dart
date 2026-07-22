import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';

/// A schema-7 snapshot of [AppDatabase] (no `water_bodies` table, no
/// `water_body_id` column on `fishing_spots`), used to seed a database file
/// that the real [AppDatabase] then upgrades to schema 8 (MFS-024/TD-024).
///
/// The current `FishingSpots` table class already includes `waterBodyId`,
/// so `migrator.createTable(fishingSpots)` cannot represent the
/// pre-migration shape — it would create the column that shouldn't exist
/// yet. The legacy `fishing_spots` table is therefore created with a
/// literal `CREATE TABLE` statement matching the real schema-7 shape
/// instead, mirroring the precedent already established in
/// `catch_migration_test.dart` for `catches`. `catches` itself is
/// unmodified by this milestone, so `migrator.createTable(catches)` still
/// correctly represents schema 7.
class _LegacySchema7AppDatabase extends AppDatabase {
  _LegacySchema7AppDatabase(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await customStatement('''
        CREATE TABLE fishing_spots (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      await migrator.createTable(catches);
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
      tempDir = Directory.systemTemp.createTempSync('fishing_spot_migration');
      dbFile = File('${tempDir.path}/fishing_app.sqlite');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('upgrades a v7 database, backfills a water body per existing fishing '
        'spot, and preserves all existing data', () async {
      final legacyDb = _LegacySchema7AppDatabase(NativeDatabase(dbFile));

      await legacyDb
          .into(legacyDb.fishingSpots)
          .insert(
            FishingSpotsCompanion.insert(
              id: 'spot-1',
              name: 'Koiraranta',
              latitude: 61.0,
              longitude: 25.0,
              createdAt: 1000,
            ),
          );
      await legacyDb
          .into(legacyDb.fishingSpots)
          .insert(
            FishingSpotsCompanion.insert(
              id: 'spot-2',
              name: 'Pohjoislahti',
              latitude: 62.0,
              longitude: 26.0,
              createdAt: 2000,
            ),
          );
      await legacyDb
          .into(legacyDb.catches)
          .insert(
            CatchesCompanion.insert(
              id: 'catch-1',
              fishingSpotId: 'spot-1',
              species: 'pike',
              caughtAt: 3000,
              weightGrams: const Value(2500),
              notes: const Value('Kaislikossa'),
              createdAt: 3000,
              updatedAt: 3000,
            ),
          );
      await legacyDb.close();

      // The real, un-pinned AppDatabase opens the same file and upgrades
      // it from 7 to the current schema version (8).
      final upgradedDb = AppDatabase(NativeDatabase(dbFile));
      addTearDown(upgradedDb.close);

      final spots = await (upgradedDb.select(
        upgradedDb.fishingSpots,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      expect(spots, hasLength(2));

      for (final spot in spots) {
        expect(spot.waterBodyId, isNotNull);
      }

      final waterBodies = await upgradedDb.select(upgradedDb.waterBodies).get();
      expect(waterBodies, hasLength(2));

      final waterBodiesById = {for (final wb in waterBodies) wb.id: wb};
      final spot1 = spots.firstWhere((s) => s.id == 'spot-1');
      final spot2 = spots.firstWhere((s) => s.id == 'spot-2');

      expect(waterBodiesById[spot1.waterBodyId]!.name, 'Koiraranta');
      expect(waterBodiesById[spot2.waterBodyId]!.name, 'Pohjoislahti');
      // Each fishing spot gets its own, distinct auto-created water body —
      // migration never fuzzy-merges by inferred name similarity
      // (MFS-024/TD-024).
      expect(spot1.waterBodyId, isNot(spot2.waterBodyId));

      // Existing coordinates, ids, and createdAt are unchanged.
      expect(spot1.latitude, 61.0);
      expect(spot1.longitude, 25.0);
      expect(spot1.createdAt, 1000);
      expect(spot2.latitude, 62.0);
      expect(spot2.longitude, 26.0);
      expect(spot2.createdAt, 2000);

      // The existing catch (including its notes) survives untouched.
      final catchRow = await (upgradedDb.select(
        upgradedDb.catches,
      )..where((t) => t.id.equals('catch-1'))).getSingle();
      expect(catchRow.fishingSpotId, 'spot-1');
      expect(catchRow.weightGrams, 2500);
      expect(catchRow.notes, 'Kaislikossa');

      // A new WaterBody and a new FishingSpot referencing it can be
      // created and read back correctly after the upgrade.
      await upgradedDb
          .into(upgradedDb.waterBodies)
          .insert(
            WaterBodiesCompanion.insert(
              id: 'water-body-new',
              name: 'Uusijärvi',
              createdAt: 4000,
            ),
          );
      await upgradedDb
          .into(upgradedDb.fishingSpots)
          .insert(
            FishingSpotsCompanion.insert(
              id: 'spot-new',
              name: 'Uusiranta',
              latitude: 63.0,
              longitude: 27.0,
              waterBodyId: const Value('water-body-new'),
              createdAt: 4000,
            ),
          );
      final newSpot = await (upgradedDb.select(
        upgradedDb.fishingSpots,
      )..where((t) => t.id.equals('spot-new'))).getSingle();
      expect(newSpot.waterBodyId, 'water-body-new');
    });
  });
}
