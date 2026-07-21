import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_entry.dart';

/// The complete, read-only result of computing one species' statistics at a
/// single point in time. Nothing here is ever persisted — see MFS-021
/// FR-10.
final class SpeciesStatisticsSummary {
  const SpeciesStatisticsSummary({
    required this.species,
    required this.catches,
  });

  /// The species this summary was computed for.
  final FishSpecies species;

  /// Every catch of [species] in the angler's entire catch history, sorted
  /// by weight descending (a missing weight sorts last), then catch date
  /// descending, then catch id ascending — see TD-021 Key Design Decision 7.
  /// Never capped; unlike `GeneralCatchStatisticsSummary.largestCatches`,
  /// this list always contains every matching catch.
  final List<SpeciesCatchEntry> catches;

  /// Every catch of [species], per [catches]'s own length — see TD-021 Key
  /// Design Decision 6.
  int get totalCatches => catches.length;

  /// The top-ranked entry of [catches] — see MFS-021's Conceptual Model
  /// ("Record Catch is the top-ranked entry of the Catch List") and TD-021
  /// Key Design Decision 5.
  SpeciesCatchEntry? get recordCatch => catches.isEmpty ? null : catches.first;
}
