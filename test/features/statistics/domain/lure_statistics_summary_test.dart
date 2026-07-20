import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/statistics/domain/lure_catch_statistic.dart';
import 'package:fishing_app/features/statistics/domain/lure_statistics_summary.dart';
import 'package:fishing_app/features/statistics/domain/lure_type_catch_statistic.dart';

void main() {
  LureCatalogEntry buildEntry(String id) {
    return LureCatalogEntry(
      variant: LureVariant(
        id: id,
        lureModelId: 'model-1',
        colorName: 'Firetiger',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      manufacturer: 'Rapala',
      modelName: 'X-Rap 10',
      lureType: 'jerkbait',
      modelDefaultImageReference: null,
    );
  }

  test('mostSuccessfulLure returns the first list element when non-empty', () {
    final first = LureCatchStatistic(
      lure: buildEntry('variant-1'),
      catchCount: 3,
    );
    final second = LureCatchStatistic(
      lure: buildEntry('variant-2'),
      catchCount: 1,
    );
    final summary = LureStatisticsSummary(
      totalCatchesLinkedToLure: 4,
      lures: [first, second],
      lureTypeBreakdown: const [],
    );
    expect(summary.mostSuccessfulLure, same(first));
  });

  test('mostSuccessfulLure returns null when lures is empty', () {
    const summary = LureStatisticsSummary(
      totalCatchesLinkedToLure: 0,
      lures: [],
      lureTypeBreakdown: [],
    );
    expect(summary.mostSuccessfulLure, isNull);
  });

  test(
    'mostSuccessfulLureType returns the first list element when non-empty',
    () {
      const first = LureTypeCatchStatistic(lureType: 'jerkbait', catchCount: 3);
      const second = LureTypeCatchStatistic(lureType: 'jig', catchCount: 1);
      final summary = LureStatisticsSummary(
        totalCatchesLinkedToLure: 4,
        lures: const [],
        lureTypeBreakdown: [first, second],
      );
      expect(summary.mostSuccessfulLureType, same(first));
    },
  );

  test(
    'mostSuccessfulLureType returns null when lureTypeBreakdown is empty',
    () {
      const summary = LureStatisticsSummary(
        totalCatchesLinkedToLure: 0,
        lures: [],
        lureTypeBreakdown: [],
      );
      expect(summary.mostSuccessfulLureType, isNull);
    },
  );

  test('rejects a negative totalCatchesLinkedToLure', () {
    expect(
      () => LureStatisticsSummary(
        totalCatchesLinkedToLure: -1,
        lures: const [],
        lureTypeBreakdown: const [],
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
