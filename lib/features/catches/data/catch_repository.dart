import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_mapper.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';

class CatchRepository {
  CatchRepository(this._database, [this._mapper = const CatchMapper()]);

  final AppDatabase _database;
  final CatchMapper _mapper;

  Future<List<Catch>> getByFishingSpotId(String fishingSpotId) async {
    final query = _database.select(_database.catches)
      ..where((t) => t.fishingSpotId.equals(fishingSpotId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.caughtAt),
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.asc(t.id),
      ]);

    final rows = await query.get();
    return [for (final row in rows) _mapper.toDomain(row)];
  }

  Future<Catch?> getById(String id) async {
    final row = await (_database.select(
      _database.catches,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    return row == null ? null : _mapper.toDomain(row);
  }
}
