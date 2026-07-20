import 'package:fishing_app/features/statistics/domain/lure_catch_statistic.dart';
import 'package:fishing_app/features/statistics/domain/lure_type_catch_statistic.dart';

/// The complete, read-only result of computing lure-based catch statistics
/// at a single point in time. Nothing here is ever persisted — see MFS-019
/// FR-8 / TD-019 §4.
final class LureStatisticsSummary {
  const LureStatisticsSummary({
    required this.totalCatchesLinkedToLure,
    required this.lures,
    required this.lureTypeBreakdown,
  }) : assert(
         totalCatchesLinkedToLure >= 0,
         'totalCatchesLinkedToLure must not be negative',
       );

  /// Every catch with a non-null assigned lure, whether or not that
  /// reference currently resolves. See MFS-019 FR-3/FR-10.
  final int totalCatchesLinkedToLure;

  /// Every lure with at least one resolvable catch, sorted by [catchCount]
  /// descending, ties broken deterministically. May be shorter than
  /// [totalCatchesLinkedToLure] implies if any catches are unresolvable.
  final List<LureCatchStatistic> lures;

  /// Every lure type with at least one resolvable catch, sorted by
  /// [catchCount] descending, ties broken deterministically.
  final List<LureTypeCatchStatistic> lureTypeBreakdown;

  LureCatchStatistic? get mostSuccessfulLure =>
      lures.isEmpty ? null : lures.first;

  LureTypeCatchStatistic? get mostSuccessfulLureType =>
      lureTypeBreakdown.isEmpty ? null : lureTypeBreakdown.first;
}
