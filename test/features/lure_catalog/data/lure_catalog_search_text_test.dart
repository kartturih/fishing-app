import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/data/lure_catalog_search_text.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_model.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';

void main() {
  group('buildLureModelSearchText', () {
    test('lowercases and joins manufacturer, productFamily, and modelName', () {
      final model = LureModel(
        id: 'model-1',
        manufacturer: 'Rapala',
        productFamily: 'X-Rap',
        modelName: 'X-Rap Shad XRS08',
        lureType: 'crankbait',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      expect(buildLureModelSearchText(model), 'rapala x-rap x-rap shad xrs08');
    });

    test('omits a null productFamily without leaving extra whitespace', () {
      final model = LureModel(
        id: 'model-1',
        manufacturer: 'Rapala',
        modelName: 'Original Floater',
        lureType: 'crankbait',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      expect(buildLureModelSearchText(model), 'rapala original floater');
    });

    test('correctly lowercases Finnish ä/ö characters', () {
      final model = LureModel(
        id: 'model-1',
        manufacturer: 'Äijänpää',
        modelName: 'Örvelö',
        lureType: 'crankbait',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      expect(buildLureModelSearchText(model), 'äijänpää örvelö');
    });
  });

  group('buildLureVariantSearchText', () {
    test(
      'lowercases and joins variantName, colorName, and manufacturerColorCode',
      () {
        final variant = LureVariant(
          id: 'variant-1',
          lureModelId: 'model-1',
          variantName: 'Deep Runner',
          colorName: 'Hot Craw',
          manufacturerColorCode: 'HCC',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );

        expect(buildLureVariantSearchText(variant), 'deep runner hot craw hcc');
      },
    );

    test('correctly lowercases a Finnish color name (Sinivihreä)', () {
      final variant = LureVariant(
        id: 'variant-1',
        lureModelId: 'model-1',
        colorName: 'Sinivihreä',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      expect(buildLureVariantSearchText(variant), 'sinivihreä');
    });
  });
}
