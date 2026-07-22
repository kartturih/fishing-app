import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_mapper.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

class FishingSpotRepository {
  FishingSpotRepository(this._database);

  final AppDatabase _database;

  Future<List<FishingSpot>> loadAll() async {
    final rows = await _database.select(_database.fishingSpots).get();
    return [for (final row in rows) row.toDomain()];
  }

  Stream<List<FishingSpot>> watchAll() {
    return _database
        .select(_database.fishingSpots)
        .watch()
        .map((rows) => [for (final row in rows) row.toDomain()]);
  }

  Future<FishingSpot> create({
    required String name,
    required double latitude,
    required double longitude,
    required String waterBodyId,
  }) async {
    if (waterBodyId.isEmpty) {
      throw ArgumentError.value(
        waterBodyId,
        'waterBodyId',
        'must not be empty',
      );
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

  Future<FishingSpot> updateName({
    required String id,
    required String name,
  }) async {
    final table = _database.fishingSpots;
    final existing = await (_database.select(
      table,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existing == null) {
      throw StateError('Fishing spot "$id" was not found.');
    }

    await (_database.update(table)..where((t) => t.id.equals(id))).write(
      FishingSpotsCompanion(name: Value(name)),
    );

    final existingSpot = existing.toDomain();
    return FishingSpot(
      id: existingSpot.id,
      name: name,
      latitude: existingSpot.latitude,
      longitude: existingSpot.longitude,
      waterBodyId: existingSpot.waterBodyId,
      createdAt: existingSpot.createdAt,
    );
  }

  /// Changes only which water body this fishing spot belongs to — a new,
  /// narrow, single-purpose method mirroring [updateName]'s existing shape,
  /// not a general-purpose "update" covering every field. Coordinates,
  /// name, and identifier are left untouched. See MFS-024 FR-7 / TD-024.
  Future<FishingSpot> updateWaterBody({
    required String id,
    required String waterBodyId,
  }) async {
    if (waterBodyId.isEmpty) {
      throw ArgumentError.value(
        waterBodyId,
        'waterBodyId',
        'must not be empty',
      );
    }
    final table = _database.fishingSpots;
    final existing = await (_database.select(
      table,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existing == null) {
      throw StateError('Fishing spot "$id" was not found.');
    }

    await (_database.update(table)..where((t) => t.id.equals(id))).write(
      FishingSpotsCompanion(waterBodyId: Value(waterBodyId)),
    );

    final existingSpot = existing.toDomain();
    return FishingSpot(
      id: existingSpot.id,
      name: existingSpot.name,
      latitude: existingSpot.latitude,
      longitude: existingSpot.longitude,
      waterBodyId: waterBodyId,
      createdAt: existingSpot.createdAt,
    );
  }

  /// Every fishing spot belonging to [waterBodyId], ordered by name — used
  /// by the water-body management surface to show a water body's member
  /// fishing spots. Mirrors `CatchRepository.getByFishingSpotId`'s existing
  /// shape exactly. See TD-024.
  Future<List<FishingSpot>> getByWaterBodyId(String waterBodyId) async {
    final rows =
        await (_database.select(_database.fishingSpots)
              ..where((t) => t.waterBodyId.equals(waterBodyId))
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    return [for (final row in rows) row.toDomain()];
  }

  Future<void> delete(String id) async {
    final table = _database.fishingSpots;
    final existing = await (_database.select(
      table,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existing == null) {
      throw StateError('Fishing spot "$id" was not found.');
    }

    await (_database.delete(table)..where((t) => t.id.equals(id))).go();
  }

  String _generateId() => 'spot-${DateTime.now().microsecondsSinceEpoch}';
}
