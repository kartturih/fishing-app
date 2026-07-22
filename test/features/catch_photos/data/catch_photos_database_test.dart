import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_mapper.dart';

/// A schema-2 snapshot of [AppDatabase] (no `CatchPhotos` table), used to seed
/// a database file that the real [AppDatabase] then upgrades to schema 3.
/// Reuses the production-generated `fishingSpots` table accessor, but
/// `catches` is created with a literal `CREATE TABLE` matching the real
/// schema-2 shape (no `lure_variant_id`): the current `Catches` table class
/// already includes that column (MFS-017/TD-017), so `createTable(catches)`
/// would create it too early, breaking the schema-6 `addColumn` migration
/// this same database is later upgraded through. See the identical fix in
/// catch_migration_test.dart.
class _LegacyAppDatabase extends AppDatabase {
  _LegacyAppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

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
    },
  );
}

void main() {
  const mapper = CatchPhotoMapper();

  group('schema migration', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('catch_photos_migration');
      dbFile = File('${tempDir.path}/fishing_app.sqlite');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('upgrades a v2 database and preserves existing Catch data', () async {
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
      await legacyDb.close();

      final upgraded = AppDatabase(NativeDatabase(dbFile));
      addTearDown(upgraded.close);

      final spots = await upgraded.select(upgraded.fishingSpots).get();
      final catches = await upgraded.select(upgraded.catches).get();
      expect(spots, hasLength(1));
      expect(spots.single.id, 'spot-1');
      expect(catches, hasLength(1));
      expect(catches.single.id, 'catch-1');

      // The new CatchPhotos table exists and is usable post-migration.
      await upgraded
          .into(upgraded.catchPhotos)
          .insert(
            CatchPhotosCompanion.insert(
              id: 'photo-1',
              catchId: 'catch-1',
              relativePath: 'catch_photos/catch-1/photo-1.jpg',
              sortOrder: 0,
              createdAt: 3000,
            ),
          );
      final photos = await upgraded.select(upgraded.catchPhotos).get();
      expect(photos, hasLength(1));
    });
  });

  group('CatchPhotos table', () {
    late AppDatabase database;
    const fishingSpotId = 'spot-1';
    const catchId = 'catch-1';

    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      await database
          .into(database.fishingSpots)
          .insert(
            FishingSpotsCompanion.insert(
              id: fishingSpotId,
              name: 'Test Spot',
              latitude: 61.0,
              longitude: 25.0,
              createdAt: 1000,
            ),
          );
      await database
          .into(database.catches)
          .insert(
            CatchesCompanion.insert(
              id: catchId,
              fishingSpotId: fishingSpotId,
              species: 'pike',
              caughtAt: 2000,
              createdAt: 2000,
              updatedAt: 2000,
            ),
          );
    });

    tearDown(() async {
      await database.close();
    });

    test('a CatchPhoto row can be inserted and maps correctly', () async {
      await database
          .into(database.catchPhotos)
          .insert(
            CatchPhotosCompanion.insert(
              id: 'photo-1',
              catchId: catchId,
              relativePath: 'catch_photos/catch-1/photo-1.jpg',
              sortOrder: 0,
              createdAt: 4000,
            ),
          );

      final row = await (database.select(
        database.catchPhotos,
      )..where((t) => t.id.equals('photo-1'))).getSingle();
      final photo = mapper.toDomain(row);

      expect(photo.id, 'photo-1');
      expect(photo.catchId, catchId);
      expect(photo.relativePath, 'catch_photos/catch-1/photo-1.jpg');
      expect(photo.sortOrder, 0);
      expect(photo.createdAt, DateTime.fromMillisecondsSinceEpoch(4000));
    });

    test('the foreign key rejects an invalid Catch ID', () async {
      expect(
        () => database
            .into(database.catchPhotos)
            .insert(
              CatchPhotosCompanion.insert(
                id: 'photo-1',
                catchId: 'catch-does-not-exist',
                relativePath: 'catch_photos/none/photo-1.jpg',
                sortOrder: 0,
                createdAt: 4000,
              ),
            ),
        throwsA(anything),
      );
    });

    test('deleting the Catch cascades its CatchPhoto rows', () async {
      await database
          .into(database.catchPhotos)
          .insert(
            CatchPhotosCompanion.insert(
              id: 'photo-1',
              catchId: catchId,
              relativePath: 'catch_photos/catch-1/photo-1.jpg',
              sortOrder: 0,
              createdAt: 4000,
            ),
          );

      await (database.delete(
        database.catches,
      )..where((t) => t.id.equals(catchId))).go();

      final remaining = await database.select(database.catchPhotos).get();
      expect(remaining, isEmpty);
    });

    test('returns photos for a Catch in sort order', () async {
      await database
          .into(database.catchPhotos)
          .insert(
            CatchPhotosCompanion.insert(
              id: 'photo-2',
              catchId: catchId,
              relativePath: 'catch_photos/catch-1/photo-2.jpg',
              sortOrder: 1,
              createdAt: 4001,
            ),
          );
      await database
          .into(database.catchPhotos)
          .insert(
            CatchPhotosCompanion.insert(
              id: 'photo-1',
              catchId: catchId,
              relativePath: 'catch_photos/catch-1/photo-1.jpg',
              sortOrder: 0,
              createdAt: 4000,
            ),
          );

      final query = database.select(database.catchPhotos)
        ..where((t) => t.catchId.equals(catchId))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
      final rows = await query.get();

      expect(rows.map((r) => r.id).toList(), ['photo-1', 'photo-2']);
    });

    test('returns an empty result for a Catch with no photos', () async {
      final rows = await (database.select(
        database.catchPhotos,
      )..where((t) => t.catchId.equals(catchId))).get();

      expect(rows, isEmpty);
    });
  });
}
