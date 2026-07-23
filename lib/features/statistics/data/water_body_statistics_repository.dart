import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_mapper.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_mapper.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';
import 'package:fishing_app/features/statistics/domain/water_body_catch_entry.dart';
import 'package:fishing_app/features/statistics/domain/water_body_statistics_summary.dart';

/// Concrete, read-only repository computing one water body's catch
/// statistics live from existing `Catches`/`FishingSpots` data.
///
/// Unlike `FishingSpotStatisticsRepository` (which reads `Catches` alone,
/// since every catch it returns already belongs to one known fishing spot),
/// a water body's Catch List spans every fishing spot under it, so each
/// catch's own fishing spot must be resolved — the same reason
/// `SpeciesStatisticsRepository` joins `FishingSpots` for a species-scoped
/// Catch List. Never reads `CatchPhotos`: photo resolution is a
/// presentation-layer concern, exactly as it already is for the existing
/// Catch List (`CatchListItem`).
class WaterBodyStatisticsRepository {
  WaterBodyStatisticsRepository(
    this._database, [
    this._catchMapper = const CatchMapper(),
  ]);

  final AppDatabase _database;
  final CatchMapper _catchMapper;

  /// Computes the full summary for [waterBodyId] fresh — nothing is cached
  /// or stored.
  Future<WaterBodyStatisticsSummary> getWaterBodyStatistics(
    String waterBodyId,
  ) async {
    final rows = await _catchesForWaterBody(waterBodyId);

    final entries = [
      for (final row in rows)
        WaterBodyCatchEntry(
          catchModel: _catchMapper.toDomain(row.readTable(_database.catches)),
          fishingSpot: row.readTable(_database.fishingSpots).toDomain(),
        ),
    ]..sort(_compareWaterBodyCatchEntries);

    final speciesCounts = <FishSpecies, int>{};
    DateTime? lastCatchDate;
    for (final entry in entries) {
      final catchModel = entry.catchModel;
      speciesCounts.update(
        catchModel.species,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      if (lastCatchDate == null || catchModel.caughtAt.isAfter(lastCatchDate)) {
        lastCatchDate = catchModel.caughtAt;
      }
    }

    final speciesCatchCounts = [
      for (final entry in speciesCounts.entries)
        SpeciesCatchStatistic(species: entry.key, catchCount: entry.value),
    ]..sort(_compareSpeciesStatistics);

    return WaterBodyStatisticsSummary(
      catches: entries,
      speciesCatchCounts: speciesCatchCounts,
      lastCatchDate: lastCatchDate,
    );
  }

  /// Every catch at any fishing spot belonging to [waterBodyId], joined
  /// with that fishing spot. `Catches.fishingSpotId` and
  /// `FishingSpots.waterBodyId` are both required foreign keys, so the
  /// `innerJoin` never excludes a row that truly belongs to this water
  /// body.
  Future<List<TypedResult>> _catchesForWaterBody(String waterBodyId) {
    final query = _database.select(_database.catches).join([
      innerJoin(
        _database.fishingSpots,
        _database.fishingSpots.id.equalsExp(_database.catches.fishingSpotId),
      ),
    ])..where(_database.fishingSpots.waterBodyId.equals(waterBodyId));
    return query.get();
  }
}

/// Sorts by weight descending (a missing weight sorts after every catch
/// that has one), then catch date descending, then the catch id ascending
/// as a guaranteed-unique final tiebreak — the same rule
/// `FishingSpotStatisticsRepository`/`SpeciesStatisticsRepository` already
/// use.
int _compareWaterBodyCatchEntries(WaterBodyCatchEntry a, WaterBodyCatchEntry b) {
  final aWeight = a.catchModel.weightGrams;
  final bWeight = b.catchModel.weightGrams;
  if (aWeight == null && bWeight != null) return 1;
  if (aWeight != null && bWeight == null) return -1;
  if (aWeight != null && bWeight != null) {
    final byWeight = bWeight.compareTo(aWeight);
    if (byWeight != 0) return byWeight;
  }
  final byCaughtAt = b.catchModel.caughtAt.compareTo(a.catchModel.caughtAt);
  if (byCaughtAt != 0) return byCaughtAt;
  return a.catchModel.id.compareTo(b.catchModel.id);
}

/// Sorts by catch count descending; ties broken by the species' stable
/// stored identifier ascending — the same rule used elsewhere in this
/// feature.
int _compareSpeciesStatistics(
  SpeciesCatchStatistic a,
  SpeciesCatchStatistic b,
) {
  final byCount = b.catchCount.compareTo(a.catchCount);
  if (byCount != 0) return byCount;
  return a.species.name.compareTo(b.species.name);
}
