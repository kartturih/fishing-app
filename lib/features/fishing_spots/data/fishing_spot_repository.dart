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
  }) async {
    final spot = FishingSpot(
      id: _generateId(),
      name: name,
      latitude: latitude,
      longitude: longitude,
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

    await (_database.update(
      table,
    )..where((t) => t.id.equals(id))).write(
      FishingSpotsCompanion(name: Value(name)),
    );

    return FishingSpot(
      id: existing.id,
      name: name,
      latitude: existing.latitude,
      longitude: existing.longitude,
      createdAt: DateTime.fromMillisecondsSinceEpoch(existing.createdAt),
    );
  }

  String _generateId() => 'spot-${DateTime.now().microsecondsSinceEpoch}';
}
