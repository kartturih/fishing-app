import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_mapper.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_mapper.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_mapper.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_entry.dart';
import 'package:fishing_app/features/statistics/domain/species_statistics_summary.dart';

/// Concrete, read-only repository computing one species' catch statistics
/// live from existing `Catches`/`FishingSpots` data.
///
/// Performs its own species-filtered join directly against those tables
/// (reusing the already-public `CatchMapper` and `FishingSpotEntityMapper`),
/// exactly like `GeneralCatchStatisticsRepository`'s established precedent
/// (TD-020) — never through `CatchRepository` or `FishingSpotRepository`'s
/// instance methods. Never reads `CatchPhotos`: photo resolution is a
/// presentation-layer concern, exactly as it already is for the existing
/// catch list (`CatchListItem`) and the Record Catch section
/// (`RecordCatchCard`). See MFS-021 / TD-021.
class SpeciesStatisticsRepository {
  SpeciesStatisticsRepository(
    this._database, [
    this._catchMapper = const CatchMapper(),
  ]);

  final AppDatabase _database;
  final CatchMapper _catchMapper;

  /// Computes the full summary for [species] fresh — nothing is cached or
  /// stored. See MFS-021 FR-10.
  Future<SpeciesStatisticsSummary> getSpeciesStatistics(
    FishSpecies species,
  ) async {
    final rows = await _catchesForSpecies(species);

    final entries = [
      for (final row in rows)
        SpeciesCatchEntry(
          catchModel: _catchMapper.toDomain(row.readTable(_database.catches)),
          fishingSpot: row.readTable(_database.fishingSpots).toDomain(),
          waterBody: row.readTable(_database.waterBodies).toDomain(),
        ),
    ]..sort(_compareSpeciesCatchEntries);

    return SpeciesStatisticsSummary(species: species, catches: entries);
  }

  /// Every catch of [species], joined with its fishing spot and, since
  /// MFS-024/TD-024, that fishing spot's water body. `Catches.fishingSpotId`
  /// and (after the 7->8 migration) `FishingSpots.waterBodyId` are both
  /// required foreign keys, so neither `innerJoin` ever excludes a row —
  /// the same guarantee `GeneralCatchStatisticsRepository` already relies on
  /// (TD-020 Key Design Decision 2).
  Future<List<TypedResult>> _catchesForSpecies(FishSpecies species) {
    final query = _database.select(_database.catches).join([
      innerJoin(
        _database.fishingSpots,
        _database.fishingSpots.id.equalsExp(_database.catches.fishingSpotId),
      ),
      innerJoin(
        _database.waterBodies,
        _database.waterBodies.id.equalsExp(_database.fishingSpots.waterBodyId),
      ),
    ])..where(_database.catches.species.equals(species.name));
    return query.get();
  }
}

/// Sorts by weight descending (a missing weight sorts after every catch
/// that has one), then catch date descending, then the catch id ascending
/// as a guaranteed-unique final tiebreak — see MFS-021's ordering
/// requirement and TD-021 Key Design Decision 7.
int _compareSpeciesCatchEntries(SpeciesCatchEntry a, SpeciesCatchEntry b) {
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
