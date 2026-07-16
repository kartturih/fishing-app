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

  String _generateId() => 'spot-${DateTime.now().microsecondsSinceEpoch}';
}
