import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';

/// The complete, read-only result of computing one fishing spot's
/// statistics at a single point in time. Nothing here is ever persisted —
/// see MFS-022 FR-12.
final class FishingSpotStatisticsSummary {
  const FishingSpotStatisticsSummary({
    required this.catches,
    required this.speciesCatchCounts,
    required this.lastCatchDate,
  });

  /// Every catch at the fishing spot, sorted by weight descending (a
  /// missing weight sorts last), then catch date descending, then catch id
  /// ascending — see TD-022 Key Design Decision 2/§4. Never capped; unlike
  /// `GeneralCatchStatisticsSummary.largestCatches`, this list always
  /// contains every matching catch. No wrapper entry type is needed here
  /// (unlike `SpeciesStatisticsSummary.catches`) since every catch already
  /// belongs to the one fishing spot this summary was computed for — see
  /// TD-022 Key Design Decision 3.
  final List<Catch> catches;

  /// Every species caught at the fishing spot, with its catch count,
  /// sorted by catch count descending, ties broken deterministically.
  /// Reuses `SpeciesCatchStatistic` (MFS-020/TD-020) unmodified — see
  /// TD-022 Key Design Decision 4.
  final List<SpeciesCatchStatistic> speciesCatchCounts;

  /// The most recent `caughtAt` among [catches]; `null` when [catches] is
  /// empty. A stored field, not a getter over [catches], because [catches]
  /// is sorted by weight, not by date — see TD-022 Key Design Decision 5.
  final DateTime? lastCatchDate;

  /// Every catch at the fishing spot, per [catches]'s own length — never a
  /// separately stored/computed value, since [catches] is never capped.
  int get totalCatches => catches.length;

  /// The top-ranked entry of [catches] — see MFS-022's Conceptual Model
  /// ("Record Catch is the top-ranked entry of the Catch List") and
  /// TD-022 Key Design Decision 3.
  Catch? get recordCatch => catches.isEmpty ? null : catches.first;
}
