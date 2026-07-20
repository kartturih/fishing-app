import 'package:fishing_app/features/statistics/domain/largest_catch.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';

/// The complete, read-only result of computing general catch statistics at
/// a single point in time. Nothing here is ever persisted — see MFS-020
/// FR-10 / TD-020 §4.
///
/// Not `const`-constructible: the assertion below calls `.length` on
/// [largestCatches], which Dart does not accept as a constant expression.
final class GeneralCatchStatisticsSummary {
  GeneralCatchStatisticsSummary({
    required this.totalCatches,
    required this.largestCatches,
    required this.speciesCatchCounts,
  }) : assert(totalCatches >= 0, 'totalCatches must not be negative'),
       assert(
         largestCatches.length <= 3,
         'largestCatches must contain at most three entries',
       );

  /// Every catch the angler has ever logged, across every fishing spot.
  final int totalCatches;

  /// The catches with the greatest recorded weight, descending, ties
  /// broken deterministically. At most three entries; a catch with no
  /// recorded weight is never included.
  final List<LargestCatch> largestCatches;

  /// Every species with at least one logged catch, with its catch count,
  /// sorted by catch count descending, ties broken deterministically.
  final List<SpeciesCatchStatistic> speciesCatchCounts;

  SpeciesCatchStatistic? get mostCaughtSpecies =>
      speciesCatchCounts.isEmpty ? null : speciesCatchCounts.first;
}
