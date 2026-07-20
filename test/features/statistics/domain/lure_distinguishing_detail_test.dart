import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/statistics/domain/lure_distinguishing_detail.dart';

void main() {
  LureCatalogEntry buildEntry({
    String? variantName,
    String? colorName,
    String? manufacturerColorCode,
  }) {
    return LureCatalogEntry(
      variant: LureVariant(
        id: 'variant-1',
        lureModelId: 'model-1',
        variantName: variantName,
        colorName: colorName,
        manufacturerColorCode: manufacturerColorCode,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      manufacturer: 'Rapala',
      modelName: 'X-Rap 10',
      lureType: 'jerkbait',
      modelDefaultImageReference: null,
    );
  }

  test('returns colorName when present', () {
    final entry = buildEntry(
      colorName: 'Firetiger',
      manufacturerColorCode: 'FT',
      variantName: 'Glow',
    );
    expect(lureDistinguishingDetail(entry), 'Firetiger');
  });

  test('falls back to manufacturerColorCode when colorName is absent', () {
    final entry = buildEntry(manufacturerColorCode: 'FT', variantName: 'Glow');
    expect(lureDistinguishingDetail(entry), 'FT');
  });

  test(
    'falls back to variantName when colorName and manufacturerColorCode are absent',
    () {
      final entry = buildEntry(variantName: 'Glow');
      expect(lureDistinguishingDetail(entry), 'Glow');
    },
  );

  test('lureDisplayName includes the distinguishing detail when present', () {
    final entry = buildEntry(colorName: 'Firetiger');
    expect(lureDisplayName(entry), 'Rapala X-Rap 10, Firetiger');
  });
}
