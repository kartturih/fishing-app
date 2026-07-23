import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_mapper.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_mapper.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_mapper.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/statistics/domain/general_catch_statistics_summary.dart';
import 'package:fishing_app/features/statistics/domain/largest_catch.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';
import 'package:fishing_app/features/statistics/domain/water_body_catch_statistic.dart';

/// Concrete, read-only repository computing general catch statistics live
/// from existing `Catches`/`FishingSpots`/`WaterBodies` data.
///
/// Performs its own join directly against those tables (reusing the
/// already-public `CatchMapper`, `FishingSpotEntityMapper`, and
/// `WaterBodyEntityMapper`), exactly like `LureStatisticsRepository`'s
/// established precedent — never through `CatchRepository`,
/// `FishingSpotRepository`, or `WaterBodyRepository`'s instance methods.
/// Never reads `CatchPhotos`: photo resolution for a largest-catch row is a
/// presentation-layer concern, exactly as it already is for the existing
/// catch list (`CatchListItem`). See MFS-020 / TD-020.
class GeneralCatchStatisticsRepository {
  GeneralCatchStatisticsRepository(
    this._database, [
    this._catchMapper = const CatchMapper(),
  ]);

  final AppDatabase _database;
  final CatchMapper _catchMapper;

  /// Computes the full summary fresh — nothing is cached or stored. See
  /// MFS-020 FR-10.
  ///
  /// Also produces [GeneralCatchStatisticsSummary.waterBodyCatchCounts],
  /// entirely from the same rows this method already fetches — see this
  /// class's own doc comment. No additional query is issued for it.
  Future<GeneralCatchStatisticsSummary> getGeneralCatchStatistics() async {
    final rows = await _catchesWithFishingSpotAndWaterBody();

    final speciesCounts = <FishSpecies, int>{};
    final waterBodyCounts = <String, _MutableWaterBodyCount>{};
    final weightedCatches = <LargestCatch>[];

    for (final row in rows) {
      final catchModel = _catchMapper.toDomain(
        row.readTable(_database.catches),
      );
      speciesCounts.update(
        catchModel.species,
        (count) => count + 1,
        ifAbsent: () => 1,
      );

      final fishingSpot = row.readTable(_database.fishingSpots).toDomain();

      // Resolved unconditionally (not only for weighted catches, as
      // GeneralCatchStatisticsSummary.largestCatches alone required) so the
      // Water Body List can be built from this same pass.
      final waterBody = row.readTable(_database.waterBodies).toDomain();
      waterBodyCounts
          .putIfAbsent(waterBody.id, () => _MutableWaterBodyCount(waterBody))
          .increment();

      if (catchModel.weightGrams != null) {
        weightedCatches.add(
          LargestCatch(catchModel: catchModel, fishingSpot: fishingSpot),
        );
      }
    }

    weightedCatches.sort(_compareLargestCatches);

    final speciesCatchCounts = [
      for (final entry in speciesCounts.entries)
        SpeciesCatchStatistic(species: entry.key, catchCount: entry.value),
    ]..sort(_compareSpeciesStatistics);

    final waterBodyCatchCounts = [
      for (final counted in waterBodyCounts.values)
        WaterBodyCatchStatistic(
          waterBody: counted.waterBody,
          catchCount: counted.count,
        ),
    ]..sort(_compareWaterBodyStatistics);

    return GeneralCatchStatisticsSummary(
      totalCatches: rows.length,
      largestCatches: weightedCatches.take(3).toList(),
      speciesCatchCounts: speciesCatchCounts,
      waterBodyCatchCounts: waterBodyCatchCounts,
    );
  }

  /// Every catch, joined with its fishing spot and that fishing spot's
  /// water body. `Catches.fishingSpotId` and `FishingSpots.waterBodyId` are
  /// both required foreign keys, so neither `innerJoin` ever excludes a
  /// row — see TD-020 Key Design Decision 2 / TD-024.
  Future<List<TypedResult>> _catchesWithFishingSpotAndWaterBody() {
    final query = _database.select(_database.catches).join([
      innerJoin(
        _database.fishingSpots,
        _database.fishingSpots.id.equalsExp(_database.catches.fishingSpotId),
      ),
      innerJoin(
        _database.waterBodies,
        _database.waterBodies.id.equalsExp(_database.fishingSpots.waterBodyId),
      ),
    ]);
    return query.get();
  }
}

/// Sorts by weight descending; ties broken by caught-at date/time
/// descending, then created-at descending, then the catch id ascending as
/// a guaranteed-unique final tiebreak — see TD-020 Key Design Decision 4.
int _compareLargestCatches(LargestCatch a, LargestCatch b) {
  final byWeight = b.catchModel.weightGrams!.compareTo(
    a.catchModel.weightGrams!,
  );
  if (byWeight != 0) return byWeight;
  final byCaughtAt = b.catchModel.caughtAt.compareTo(a.catchModel.caughtAt);
  if (byCaughtAt != 0) return byCaughtAt;
  final byCreatedAt = b.catchModel.createdAt.compareTo(a.catchModel.createdAt);
  if (byCreatedAt != 0) return byCreatedAt;
  return a.catchModel.id.compareTo(b.catchModel.id);
}

/// Sorts by catch count descending; ties broken by the species' stable
/// stored identifier ascending — see TD-020 Key Design Decision 4.
int _compareSpeciesStatistics(
  SpeciesCatchStatistic a,
  SpeciesCatchStatistic b,
) {
  final byCount = b.catchCount.compareTo(a.catchCount);
  if (byCount != 0) return byCount;
  return a.species.name.compareTo(b.species.name);
}

class _MutableWaterBodyCount {
  _MutableWaterBodyCount(this.waterBody);

  final WaterBody waterBody;
  int count = 0;

  void increment() => count++;
}

/// Sorts by catch count descending; ties broken by water body name
/// (case-insensitive ascending), then by water body id ascending as a
/// guaranteed-unique final tiebreak. Water body names are angler-authored
/// free text and are not guaranteed unique, so a name-only tiebreak is not
/// sufficient on its own — mirrors `FishingSpotCatchStatistic`'s own
/// precedent (MFS-022 / TD-022 Key Design Decision 1).
int _compareWaterBodyStatistics(
  WaterBodyCatchStatistic a,
  WaterBodyCatchStatistic b,
) {
  final byCount = b.catchCount.compareTo(a.catchCount);
  if (byCount != 0) return byCount;
  final byName = a.waterBody.name.toLowerCase().compareTo(
    b.waterBody.name.toLowerCase(),
  );
  if (byName != 0) return byName;
  return a.waterBody.id.compareTo(b.waterBody.id);
}
