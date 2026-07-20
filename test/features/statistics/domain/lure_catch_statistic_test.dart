import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/statistics/domain/lure_catch_statistic.dart';

void main() {
  LureCatalogEntry buildEntry() {
    return LureCatalogEntry(
      variant: LureVariant(
        id: 'variant-1',
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

  test('constructs successfully with a positive catchCount', () {
    final statistic = LureCatchStatistic(lure: buildEntry(), catchCount: 3);
    expect(statistic.catchCount, 3);
  });

  test('rejects a zero catchCount', () {
    expect(
      () => LureCatchStatistic(lure: buildEntry(), catchCount: 0),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a negative catchCount', () {
    expect(
      () => LureCatchStatistic(lure: buildEntry(), catchCount: -1),
      throwsA(isA<AssertionError>()),
    );
  });
}
