import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_mapper.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_search_text.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_model.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';

void main() {
  const mapper = LureCatalogMapper();

  LureModel buildModel({
    String? productFamily = 'X-Rap',
    String? defaultImageReference,
  }) {
    return LureModel(
      id: 'model-1',
      manufacturer: 'Rapala',
      modelName: 'X-Rap Shad XRS08',
      lureType: 'crankbait',
      productFamily: productFamily,
      defaultImageReference: defaultImageReference,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
  }

  LureVariant buildVariant({String? imageReference}) {
    return LureVariant(
      id: 'variant-1',
      lureModelId: 'model-1',
      colorName: 'Hot Craw',
      manufacturerColorCode: 'HCC',
      lengthMillimeters: 80,
      weightGrams: 12,
      imageReference: imageReference,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
  }

  group('entryFromRows', () {
    test('maps a joined row pair to the correct LureCatalogEntry', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database
          .into(database.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: 'model-1',
              manufacturer: 'Rapala',
              productFamily: const Value('X-Rap'),
              modelName: 'X-Rap Shad XRS08',
              lureType: 'crankbait',
              defaultImageReference: const Value(
                'assets/lure_catalog/model.png',
              ),
              searchText: 'rapala x-rap x-rap shad xrs08',
              createdAt: 1000,
              updatedAt: 2000,
            ),
          );
      await database
          .into(database.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'variant-1',
              lureModelId: 'model-1',
              colorName: const Value('Hot Craw'),
              manufacturerColorCode: const Value('HCC'),
              lengthMillimeters: const Value(80),
              weightGrams: const Value(12),
              searchText: 'hot craw hcc',
              createdAt: 1000,
              updatedAt: 2000,
            ),
          );

      final variantRow = await database
          .select(database.lureVariants)
          .getSingle();
      final modelRow = await database.select(database.lureModels).getSingle();

      final entry = mapper.entryFromRows(
        variantRow: variantRow,
        modelRow: modelRow,
      );

      expect(entry.id, 'variant-1');
      expect(entry.manufacturer, 'Rapala');
      expect(entry.productFamily, 'X-Rap');
      expect(entry.modelName, 'X-Rap Shad XRS08');
      expect(entry.lureType, 'crankbait');
      expect(entry.variant.colorName, 'Hot Craw');
      expect(entry.variant.lengthMillimeters, 80);
    });
  });

  group('effectiveImageReference (via entryFromRows)', () {
    Future<AppDatabase> openWithModel({String? defaultImageReference}) async {
      final database = AppDatabase(NativeDatabase.memory());
      await database
          .into(database.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: 'model-1',
              manufacturer: 'Rapala',
              modelName: 'X-Rap Shad XRS08',
              lureType: 'crankbait',
              defaultImageReference: Value(defaultImageReference),
              searchText: 'rapala x-rap shad xrs08',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      return database;
    }

    test('uses the variant image when present', () async {
      final database = await openWithModel(
        defaultImageReference: 'assets/lure_catalog/model.png',
      );
      addTearDown(database.close);
      await database
          .into(database.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'variant-1',
              lureModelId: 'model-1',
              colorName: const Value('Hot Craw'),
              imageReference: const Value('assets/lure_catalog/variant.png'),
              searchText: 'hot craw',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );

      final variantRow = await database
          .select(database.lureVariants)
          .getSingle();
      final modelRow = await database.select(database.lureModels).getSingle();
      final entry = mapper.entryFromRows(
        variantRow: variantRow,
        modelRow: modelRow,
      );

      expect(entry.effectiveImageReference, 'assets/lure_catalog/variant.png');
    });

    test(
      'falls back to the model default image when the variant has none',
      () async {
        final database = await openWithModel(
          defaultImageReference: 'assets/lure_catalog/model.png',
        );
        addTearDown(database.close);
        await database
            .into(database.lureVariants)
            .insert(
              LureVariantsCompanion.insert(
                id: 'variant-1',
                lureModelId: 'model-1',
                colorName: const Value('Hot Craw'),
                searchText: 'hot craw',
                createdAt: 1000,
                updatedAt: 1000,
              ),
            );

        final variantRow = await database
            .select(database.lureVariants)
            .getSingle();
        final modelRow = await database.select(database.lureModels).getSingle();
        final entry = mapper.entryFromRows(
          variantRow: variantRow,
          modelRow: modelRow,
        );

        expect(entry.effectiveImageReference, 'assets/lure_catalog/model.png');
      },
    );

    test('is null when neither variant nor model has an image', () async {
      final database = await openWithModel();
      addTearDown(database.close);
      await database
          .into(database.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'variant-1',
              lureModelId: 'model-1',
              colorName: const Value('Hot Craw'),
              searchText: 'hot craw',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );

      final variantRow = await database
          .select(database.lureVariants)
          .getSingle();
      final modelRow = await database.select(database.lureModels).getSingle();
      final entry = mapper.entryFromRows(
        variantRow: variantRow,
        modelRow: modelRow,
      );

      expect(entry.effectiveImageReference, isNull);
    });
  });

  group('modelToCompanion / variantToCompanion', () {
    test('round-trips a fully-populated LureModel', () {
      final model = buildModel(
        defaultImageReference: 'assets/lure_catalog/x.png',
      );
      final companion = mapper.modelToCompanion(
        model,
        seedVersion: 3,
        searchText: buildLureModelSearchText(model),
      );

      expect(companion.id.value, 'model-1');
      expect(companion.manufacturer.value, 'Rapala');
      expect(companion.productFamily.value, 'X-Rap');
      expect(
        companion.defaultImageReference.value,
        'assets/lure_catalog/x.png',
      );
      expect(companion.seedVersion.value, 3);
      expect(companion.searchText.value, 'rapala x-rap x-rap shad xrs08');
      expect(
        companion.createdAt.value,
        DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
      );
      expect(
        companion.updatedAt.value,
        DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
      );
    });

    test('round-trips a LureModel with all-null optional fields', () {
      final model = buildModel(
        productFamily: null,
        defaultImageReference: null,
      );
      final companion = mapper.modelToCompanion(
        model,
        seedVersion: 1,
        searchText: buildLureModelSearchText(model),
      );

      expect(companion.productFamily.value, isNull);
      expect(companion.defaultImageReference.value, isNull);
    });

    test('variantToCompanion always clears retiredAt', () {
      final variant = buildVariant();
      final companion = mapper.variantToCompanion(
        variant,
        seedVersion: 2,
        searchText: buildLureVariantSearchText(variant),
      );

      expect(companion.retiredAt.value, isNull);
      expect(companion.seedVersion.value, 2);
      expect(companion.colorName.value, 'Hot Craw');
      expect(companion.manufacturerColorCode.value, 'HCC');
      expect(companion.searchText.value, 'hot craw hcc');
    });

    test('round-trips a LureVariant with all-null optional fields', () {
      final variant = LureVariant(
        id: 'variant-1',
        lureModelId: 'model-1',
        colorName: 'Only Field',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final companion = mapper.variantToCompanion(
        variant,
        seedVersion: 1,
        searchText: buildLureVariantSearchText(variant),
      );

      expect(companion.variantName.value, isNull);
      expect(companion.manufacturerColorCode.value, isNull);
      expect(companion.lengthMillimeters.value, isNull);
      expect(companion.weightGrams.value, isNull);
      expect(companion.minRunningDepthMillimeters.value, isNull);
      expect(companion.maxRunningDepthMillimeters.value, isNull);
      expect(companion.buoyancy.value, isNull);
      expect(companion.imageReference.value, isNull);
    });
  });
}
