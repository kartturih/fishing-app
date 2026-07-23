import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';
import 'package:fishing_app/features/statistics/domain/water_body_catch_entry.dart';

/// The complete, read-only result of computing one water body's statistics
/// at a single point in time. Nothing here is ever persisted.
final class WaterBodyStatisticsSummary {
  const WaterBodyStatisticsSummary({
    required this.catches,
    required this.speciesCatchCounts,
    required this.lastCatchDate,
  });

  /// Every catch at any fishing spot belonging to the water body, sorted by
  /// weight descending (a missing weight sorts last), then catch date
  /// descending, then catch id ascending. Never capped.
  final List<WaterBodyCatchEntry> catches;

  /// Every species caught at the water body, with its catch count, sorted
  /// by catch count descending, ties broken deterministically. Reuses
  /// `SpeciesCatchStatistic` unmodified.
  final List<SpeciesCatchStatistic> speciesCatchCounts;

  /// The most recent `caughtAt` among [catches]; `null` when [catches] is
  /// empty. A stored field, not a getter over [catches], since [catches] is
  /// sorted by weight, not by date.
  final DateTime? lastCatchDate;

  /// Every catch at the water body, per [catches]'s own length — never a
  /// separately stored/computed value, since [catches] is never capped.
  int get totalCatches => catches.length;

  /// The top-ranked entry of [catches].
  WaterBodyCatchEntry? get recordCatch => catches.isEmpty ? null : catches.first;
}
