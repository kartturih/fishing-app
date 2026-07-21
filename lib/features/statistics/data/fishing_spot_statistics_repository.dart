import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_mapper.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/statistics/domain/fishing_spot_statistics_summary.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';

/// Concrete, read-only repository computing one fishing spot's catch
/// statistics live from existing `Catches` data.
///
/// Reads no join at all: unlike `SpeciesStatisticsRepository`, which must
/// resolve each catch's own `FishingSpot` because catches of one species
/// are scattered across many spots, every catch this repository returns
/// already belongs to the one fishing spot it was asked about — and the
/// calling page already holds that `FishingSpot` object directly, passed
/// in at navigation time. This repository therefore reads `Catches` alone,
/// filtered by `fishingSpotId`. Never reads `CatchPhotos`: photo
/// resolution is a presentation-layer concern, exactly as it already is
/// for the existing Catch List (`CatchListItem`) and Record Catch section
/// (`FishingSpotRecordCatchCard`). See MFS-022 / TD-022 Key Design
/// Decision 2.
class FishingSpotStatisticsRepository {
  FishingSpotStatisticsRepository(
    this._database, [
    this._catchMapper = const CatchMapper(),
  ]);

  final AppDatabase _database;
  final CatchMapper _catchMapper;

  /// Computes the full summary for [fishingSpotId] fresh — nothing is
  /// cached or stored. See MFS-022 FR-12.
  Future<FishingSpotStatisticsSummary> getFishingSpotStatistics(
    String fishingSpotId,
  ) async {
    final rows = await _catchesForFishingSpot(fishingSpotId);

    final catches = [for (final row in rows) _catchMapper.toDomain(row)]
      ..sort(_compareCatches);

    final speciesCounts = <FishSpecies, int>{};
    DateTime? lastCatchDate;
    for (final catchModel in catches) {
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

    return FishingSpotStatisticsSummary(
      catches: catches,
      speciesCatchCounts: speciesCatchCounts,
      lastCatchDate: lastCatchDate,
    );
  }

  /// Every catch at [fishingSpotId]. No join — see this class's own doc
  /// comment and TD-022 Key Design Decision 2.
  Future<List<CatchEntity>> _catchesForFishingSpot(String fishingSpotId) {
    final query = _database.select(_database.catches)
      ..where((t) => t.fishingSpotId.equals(fishingSpotId));
    return query.get();
  }
}

/// Sorts by weight descending (a missing weight sorts after every catch
/// that has one), then catch date descending, then the catch id ascending
/// as a guaranteed-unique final tiebreak — the exact rule
/// `SpeciesStatisticsRepository` already uses (TD-021 Key Design
/// Decision 7), reused unchanged here per MFS-022's own ordering
/// requirement. Duplicated rather than shared — see TD-022 Key Design
/// Decision 7.
int _compareCatches(Catch a, Catch b) {
  final aWeight = a.weightGrams;
  final bWeight = b.weightGrams;
  if (aWeight == null && bWeight != null) return 1;
  if (aWeight != null && bWeight == null) return -1;
  if (aWeight != null && bWeight != null) {
    final byWeight = bWeight.compareTo(aWeight);
    if (byWeight != 0) return byWeight;
  }
  final byCaughtAt = b.caughtAt.compareTo(a.caughtAt);
  if (byCaughtAt != 0) return byCaughtAt;
  return a.id.compareTo(b.id);
}

/// Sorts by catch count descending; ties broken by the species' stable
/// stored identifier ascending — the same rule `GeneralCatchStatisticsRepository`
/// already uses (TD-020 Key Design Decision 4), reused unchanged since
/// `SpeciesCatchStatistic` and its ordering are reused directly (TD-022
/// Key Design Decision 4).
int _compareSpeciesStatistics(
  SpeciesCatchStatistic a,
  SpeciesCatchStatistic b,
) {
  final byCount = b.catchCount.compareTo(a.catchCount);
  if (byCount != 0) return byCount;
  return a.species.name.compareTo(b.species.name);
}
