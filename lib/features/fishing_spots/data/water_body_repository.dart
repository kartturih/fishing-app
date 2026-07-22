import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/fishing_spots/data/haversine.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_mapper.dart';
import 'package:fishing_app/features/fishing_spots/domain/nearby_water_bodies.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body_with_spot_count.dart';

/// Below this threshold, a nearby candidate is close enough to preselect
/// outright (roughly "you are adding another spot right next to one you
/// already have"). **This is a UX tuning parameter, not an architectural
/// decision** — the value below is an illustrative starting point only,
/// not a reviewed or final number. Real-world GPS accuracy near water and
/// under tree cover is often tens of meters, so this should be adjusted
/// based on physical Android testing before release, not treated as
/// settled by this document. Not derived from any external data — see
/// MFS-024's own "locally stored coordinates only" requirement.
const double _preselectionThresholdMeters = 500;

/// The nearest candidate must be at least this much closer than the
/// second-nearest before it is preselected — avoids guessing between two
/// similarly-close, genuinely different water bodies. Also a tuning
/// parameter, not an architectural decision — see the note above.
const double _preselectionMinMarginMeters = 200;

/// Concrete repository for [WaterBody] persistence — parallel to
/// [FishingSpotRepository], no repository interface, no service layer.
/// Queries `FishingSpots` directly for counting and nearby-ranking, never
/// through `FishingSpotRepository`'s instance methods, mirroring
/// `GeneralCatchStatisticsRepository`'s own "read whichever tables you
/// need directly" precedent. See MFS-024 / ADR-0007 / TD-024.
class WaterBodyRepository {
  WaterBodyRepository(this._database);

  final AppDatabase _database;

  Future<WaterBody> create({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    final waterBody = WaterBody(
      id: _generateId(),
      name: trimmed,
      createdAt: DateTime.now(),
    );
    await _database.into(_database.waterBodies).insert(waterBody.toCompanion());
    return waterBody;
  }

  Future<List<WaterBody>> loadAll() async {
    final rows = await (_database.select(
      _database.waterBodies,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
    return [for (final row in rows) row.toDomain()];
  }

  Future<WaterBody?> getById(String id) async {
    final row = await (_database.select(
      _database.waterBodies,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  Future<WaterBody> rename({required String id, required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    final existing = await (_database.select(
      _database.waterBodies,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Water body "$id" was not found.');
    }
    await (_database.update(_database.waterBodies)
          ..where((t) => t.id.equals(id)))
        .write(WaterBodiesCompanion(name: Value(trimmed)));
    return WaterBody(
      id: existing.id,
      name: trimmed,
      createdAt: DateTime.fromMillisecondsSinceEpoch(existing.createdAt),
    );
  }

  /// Deletes an empty water body. Proactively counts referencing fishing
  /// spots first and throws a clear, typed error before ever attempting
  /// the `DELETE`, so the angler sees a clean message rather than a raw
  /// database exception — the database's own `KeyAction.restrict` foreign
  /// key remains as defense-in-depth only. See MFS-024 FR-12 / TD-024 Key
  /// Design Decision 2.
  Future<void> delete(String id) async {
    final count = await _fishingSpotCount(id);
    if (count > 0) {
      throw StateError(
        'Water body "$id" still has $count fishing spot(s) and cannot be deleted.',
      );
    }
    await (_database.delete(
      _database.waterBodies,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<List<WaterBodyWithSpotCount>> loadAllWithSpotCounts() async {
    final query = _database.select(_database.waterBodies).join([
      leftOuterJoin(
        _database.fishingSpots,
        _database.fishingSpots.waterBodyId.equalsExp(_database.waterBodies.id),
      ),
    ]);
    final rows = await query.get();

    final counts = <String, _MutableWaterBodyCount>{};
    for (final row in rows) {
      final waterBody = row.readTable(_database.waterBodies).toDomain();
      final counted = counts.putIfAbsent(
        waterBody.id,
        () => _MutableWaterBodyCount(waterBody),
      );
      if (row.readTableOrNull(_database.fishingSpots) != null) {
        counted.count++;
      }
    }

    final result =
        [
          for (final counted in counts.values)
            WaterBodyWithSpotCount(
              waterBody: counted.waterBody,
              fishingSpotCount: counted.count,
            ),
        ]..sort(
          (a, b) => a.waterBody.name.toLowerCase().compareTo(
            b.waterBody.name.toLowerCase(),
          ),
        );
    return result;
  }

  /// Ranks existing water bodies by distance from ([latitude], [longitude])
  /// to their nearest already-recorded fishing spot, using only locally
  /// stored coordinates (no network, no external dataset). See MFS-024
  /// FR-5 / TD-024 Key Design Decision 7.
  Future<NearbyWaterBodies> getNearby({
    required double latitude,
    required double longitude,
    int limit = 5,
  }) async {
    final query = _database.select(_database.waterBodies).join([
      innerJoin(
        _database.fishingSpots,
        _database.fishingSpots.waterBodyId.equalsExp(_database.waterBodies.id),
      ),
    ]);
    final rows = await query.get();

    final nearestByWaterBody = <String, _NearbyCandidate>{};
    for (final row in rows) {
      final waterBody = row.readTable(_database.waterBodies).toDomain();
      final spot = row.readTable(_database.fishingSpots);
      final distanceMeters = haversineDistanceMeters(
        latitude,
        longitude,
        spot.latitude,
        spot.longitude,
      );
      final existing = nearestByWaterBody[waterBody.id];
      if (existing == null || distanceMeters < existing.distanceMeters) {
        nearestByWaterBody[waterBody.id] = _NearbyCandidate(
          waterBody,
          distanceMeters,
        );
      }
    }

    final sorted = nearestByWaterBody.values.toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    final candidates = [for (final c in sorted.take(limit)) c.waterBody];

    return NearbyWaterBodies(
      candidates: candidates,
      preselected: _preselectionCandidate(sorted),
    );
  }

  WaterBody? _preselectionCandidate(List<_NearbyCandidate> sorted) {
    if (sorted.isEmpty) {
      return null;
    }
    final nearest = sorted.first;
    if (nearest.distanceMeters > _preselectionThresholdMeters) {
      return null;
    }
    if (sorted.length > 1) {
      final second = sorted[1];
      if (second.distanceMeters - nearest.distanceMeters <
          _preselectionMinMarginMeters) {
        return null; // Ambiguous between two similarly-close water bodies — don't guess.
      }
    }
    return nearest.waterBody;
  }

  Future<int> _fishingSpotCount(String waterBodyId) async {
    final query = _database.selectOnly(_database.fishingSpots)
      ..addColumns([_database.fishingSpots.id.count()])
      ..where(_database.fishingSpots.waterBodyId.equals(waterBodyId));
    final row = await query.getSingle();
    return row.read(_database.fishingSpots.id.count()) ?? 0;
  }

  String _generateId() => 'waterbody-${DateTime.now().microsecondsSinceEpoch}';
}

class _NearbyCandidate {
  _NearbyCandidate(this.waterBody, this.distanceMeters);
  final WaterBody waterBody;
  final double distanceMeters;
}

class _MutableWaterBodyCount {
  _MutableWaterBodyCount(this.waterBody);
  final WaterBody waterBody;
  int count = 0;
}
