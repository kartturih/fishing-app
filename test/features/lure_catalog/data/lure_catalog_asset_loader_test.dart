import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/data/lure_catalog_asset_loader.dart';

/// Covers `ParsedLureCatalog.fromJson` (TD-028 Section 3/Section 7) against
/// hand-built JSON maps — never a real Flutter asset bundle, consistent
/// with this codebase's existing convention of injecting fake asset
/// sources in tests rather than depending on `rootBundle`
/// (`syke_bathymetry_tile_source_test.dart`'s own precedent).
///
/// A separate test in the `Committed catalog_v1.json` group below reads the
/// real, committed generated asset directly from disk with `dart:io`
/// (never through `rootBundle`) to verify it is internally self-consistent
/// -- TD-028 Section 6's "Dart tests verify the committed asset's internal
/// self-consistency."
void main() {
  group('ParsedLureCatalog.fromJson', () {
    test('parses a minimal catalog', () {
      final catalog = ParsedLureCatalog.fromJson({
        'catalogVersion': 3,
        'generatedAt': '2026-01-01T00:00:00Z',
        'models': [
          {
            'id': 'model-1',
            'manufacturer': 'Rapala',
            'productFamily': 'X-Rap',
            'modelName': 'X-Rap Shad XRS08',
            'lureType': 'crankbait',
            'defaultImageReference': 'assets/lure_catalog/placeholder_crankbait.png',
          },
        ],
        'variants': [
          {
            'id': 'variant-1',
            'lureModelId': 'model-1',
            'variantName': null,
            'colorName': 'Hot Craw',
            'manufacturerColorCode': 'HCC',
            'lengthMillimeters': 80,
            'weightGrams': 12,
            'minRunningDepthMillimeters': 1500,
            'maxRunningDepthMillimeters': 2400,
            'buoyancy': 'suspending',
            'imageReference': null,
          },
        ],
      });

      expect(catalog.catalogVersion, 3);
      expect(catalog.models, hasLength(1));
      expect(catalog.variants, hasLength(1));

      final model = catalog.models.single;
      expect(model.id, 'model-1');
      expect(model.manufacturer, 'Rapala');
      expect(model.productFamily, 'X-Rap');
      expect(model.modelName, 'X-Rap Shad XRS08');
      expect(model.lureType, 'crankbait');
      expect(
        model.defaultImageReference,
        'assets/lure_catalog/placeholder_crankbait.png',
      );

      final variant = catalog.variants.single;
      expect(variant.id, 'variant-1');
      expect(variant.lureModelId, 'model-1');
      expect(variant.colorName, 'Hot Craw');
      expect(variant.manufacturerColorCode, 'HCC');
      expect(variant.lengthMillimeters, 80);
      expect(variant.weightGrams, 12);
      expect(variant.minRunningDepthMillimeters, 1500);
      expect(variant.maxRunningDepthMillimeters, 2400);
      expect(variant.buoyancy, 'suspending');
    });

    test('missing optional fields parse as null, not empty/placeholder', () {
      final catalog = ParsedLureCatalog.fromJson({
        'catalogVersion': 1,
        'generatedAt': '2026-01-01T00:00:00Z',
        'models': [
          {
            'id': 'model-1',
            'manufacturer': 'Storm',
            'modelName': 'Swim Shad',
            'lureType': 'swimbait',
          },
        ],
        'variants': [
          {'id': 'variant-1', 'lureModelId': 'model-1', 'colorName': 'Golden Shiner'},
        ],
      });

      final model = catalog.models.single;
      expect(model.productFamily, isNull);
      expect(model.defaultImageReference, isNull);

      final variant = catalog.variants.single;
      expect(variant.variantName, isNull);
      expect(variant.manufacturerColorCode, isNull);
      expect(variant.lengthMillimeters, isNull);
      expect(variant.weightGrams, isNull);
      expect(variant.minRunningDepthMillimeters, isNull);
      expect(variant.maxRunningDepthMillimeters, isNull);
      expect(variant.buoyancy, isNull);
      expect(variant.imageReference, isNull);
    });

    test('every freshly-parsed record shares the same placeholder timestamp', () {
      final catalog = ParsedLureCatalog.fromJson({
        'catalogVersion': 1,
        'generatedAt': '2026-01-01T00:00:00Z',
        'models': [
          {'id': 'model-1', 'manufacturer': 'Rapala', 'modelName': 'A', 'lureType': 'jig'},
        ],
        'variants': [
          {'id': 'variant-1', 'lureModelId': 'model-1', 'colorName': 'Red'},
        ],
      });

      expect(catalog.models.single.createdAt, placeholderCatalogContentTimestamp);
      expect(catalog.models.single.updatedAt, placeholderCatalogContentTimestamp);
      expect(catalog.variants.single.createdAt, placeholderCatalogContentTimestamp);
      expect(catalog.variants.single.updatedAt, placeholderCatalogContentTimestamp);
    });
  });

  group('Committed catalog_v1.json (real, on-disk asset)', () {
    test('parses and is internally self-consistent', () {
      final file = File('assets/lure_catalog/catalog_v1.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'assets/lure_catalog/catalog_v1.json must exist -- run '
            'tools/lure_catalog/build_catalog.py build',
      );

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final catalog = ParsedLureCatalog.fromJson(json);

      expect(catalog.catalogVersion, greaterThan(0));
      expect(catalog.models, isNotEmpty);
      expect(catalog.variants, isNotEmpty);

      final modelIds = catalog.models.map((m) => m.id).toSet();
      expect(
        modelIds.length,
        catalog.models.length,
        reason: 'model ids must be unique',
      );

      final variantIds = catalog.variants.map((v) => v.id).toSet();
      expect(
        variantIds.length,
        catalog.variants.length,
        reason: 'variant ids must be unique',
      );

      for (final variant in catalog.variants) {
        expect(
          modelIds.contains(variant.lureModelId),
          isTrue,
          reason:
              'variant ${variant.id} has lureModelId ${variant.lureModelId}, '
              'which does not match any model in the committed catalog',
        );
      }

      // This first-implementation migration (TD-028 Section 11) transcribes
      // the original 4-model/14-variant Dart seed content losslessly.
      expect(catalog.models, hasLength(4));
      expect(catalog.variants, hasLength(14));
    });
  });
}
