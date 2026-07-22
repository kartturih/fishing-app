import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_mapper.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_mapper.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'WaterBody round-trips through toDomain()/toCompanion() unchanged',
    () async {
      final waterBody = WaterBody(
        id: 'water-body-1',
        name: 'Merrasjärvi',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );
      await database.into(database.waterBodies).insert(waterBody.toCompanion());

      final row = await (database.select(
        database.waterBodies,
      )..where((t) => t.id.equals('water-body-1'))).getSingle();
      final roundTripped = row.toDomain();

      expect(roundTripped.id, waterBody.id);
      expect(roundTripped.name, waterBody.name);
      expect(roundTripped.createdAt, waterBody.createdAt);
    },
  );

  test('FishingSpot round-trips including waterBodyId', () async {
    await database
        .into(database.waterBodies)
        .insert(
          WaterBodiesCompanion.insert(
            id: 'water-body-1',
            name: 'Merrasjärvi',
            createdAt: 500,
          ),
        );
    final spot = FishingSpot(
      id: 'spot-1',
      name: 'Koiraranta',
      latitude: 61.0,
      longitude: 25.0,
      waterBodyId: 'water-body-1',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    await database.into(database.fishingSpots).insert(spot.toCompanion());

    final row = await (database.select(
      database.fishingSpots,
    )..where((t) => t.id.equals('spot-1'))).getSingle();
    final roundTripped = row.toDomain();

    expect(roundTripped.id, spot.id);
    expect(roundTripped.name, spot.name);
    expect(roundTripped.latitude, spot.latitude);
    expect(roundTripped.longitude, spot.longitude);
    expect(roundTripped.waterBodyId, spot.waterBodyId);
    expect(roundTripped.createdAt, spot.createdAt);
  });

  test('FishingSpotEntityMapper.toDomain() throws StateError when waterBodyId '
      'is null (migration invariant violated)', () async {
    // Seeded directly at the SQL layer with foreign key enforcement
    // temporarily disabled, mirroring the existing dangling-reference
    // testing technique already established for Lure-Based Catch
    // Statistics (TD-019).
    await database.customStatement('PRAGMA foreign_keys = OFF');
    await database.customStatement('''
        INSERT INTO fishing_spots (id, name, latitude, longitude, water_body_id, created_at)
        VALUES ('spot-orphan', 'Orphan', 61.0, 25.0, NULL, 1000)
      ''');

    final row = await (database.select(
      database.fishingSpots,
    )..where((t) => t.id.equals('spot-orphan'))).getSingle();

    expect(() => row.toDomain(), throwsStateError);
  });
}
