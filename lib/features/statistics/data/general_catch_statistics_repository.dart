import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_mapper.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_mapper.dart';
import 'package:fishing_app/features/statistics/domain/general_catch_statistics_summary.dart';
import 'package:fishing_app/features/statistics/domain/largest_catch.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';

/// Concrete, read-only repository computing general catch statistics live
/// from existing `Catches`/`FishingSpots` data.
///
/// Performs its own join directly against those tables (reusing the
/// already-public `CatchMapper` and `FishingSpotEntityMapper`), exactly
/// like `LureStatisticsRepository`'s established precedent — never through
/// `CatchRepository` or `FishingSpotRepository`'s instance methods. Never
/// reads `CatchPhotos`: photo resolution for a largest-catch row is a
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
  Future<GeneralCatchStatisticsSummary> getGeneralCatchStatistics() async {
    final rows = await _catchesWithFishingSpot();

    final speciesCounts = <FishSpecies, int>{};
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

      if (catchModel.weightGrams != null) {
        weightedCatches.add(
          LargestCatch(
            catchModel: catchModel,
            fishingSpot: row.readTable(_database.fishingSpots).toDomain(),
          ),
        );
      }
    }

    weightedCatches.sort(_compareLargestCatches);

    final speciesCatchCounts = [
      for (final entry in speciesCounts.entries)
        SpeciesCatchStatistic(species: entry.key, catchCount: entry.value),
    ]..sort(_compareSpeciesStatistics);

    return GeneralCatchStatisticsSummary(
      totalCatches: rows.length,
      largestCatches: weightedCatches.take(3).toList(),
      speciesCatchCounts: speciesCatchCounts,
    );
  }

  /// Every catch, joined with its fishing spot. `Catches.fishingSpotId` is
  /// a required foreign key, so this `innerJoin` never excludes a row —
  /// see TD-020 Key Design Decision 2.
  Future<List<TypedResult>> _catchesWithFishingSpot() {
    final query = _database.select(_database.catches).join([
      innerJoin(
        _database.fishingSpots,
        _database.fishingSpots.id.equalsExp(_database.catches.fishingSpotId),
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
