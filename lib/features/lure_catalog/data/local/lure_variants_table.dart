import 'package:drift/drift.dart';

import 'package:fishing_app/features/lure_catalog/data/local/lure_models_table.dart';

/// Drift table for shared, read-only Lure Catalog purchasable variants.
///
/// `id` is an opaque, authored UUID. `retiredAt` is set (not deleted) when a
/// seed-owned variant is removed from a later seed revision, so a future
/// reference to it (Personal Tackle Box, Assign Lure to Catch) can still
/// resolve it; `browse()` excludes retired variants, `getEntryById()` does
/// not. See MFS-015 / TD-015.
@DataClassName('LureVariantEntity')
@TableIndex(name: 'lure_variants_lure_model_id', columns: {#lureModelId})
class LureVariants extends Table {
  TextColumn get id => text()();

  TextColumn get lureModelId =>
      text().references(LureModels, #id, onDelete: KeyAction.cascade)();

  TextColumn get variantName => text().nullable()();
  TextColumn get colorName => text().nullable()();
  TextColumn get manufacturerColorCode => text().nullable()();

  IntColumn get lengthMillimeters => integer().nullable().check(
    // ignore: recursive_getters
    lengthMillimeters.isNull() | lengthMillimeters.isBiggerThanValue(0),
  )();

  IntColumn get weightGrams => integer().nullable().check(
    // ignore: recursive_getters
    weightGrams.isNull() | weightGrams.isBiggerThanValue(0),
  )();

  IntColumn get minRunningDepthMillimeters => integer().nullable().check(
    // ignore: recursive_getters
    minRunningDepthMillimeters.isNull() |
        // ignore: recursive_getters
        minRunningDepthMillimeters.isBiggerThanValue(0),
  )();

  IntColumn get maxRunningDepthMillimeters => integer().nullable().check(
    // ignore: recursive_getters
    maxRunningDepthMillimeters.isNull() |
        // ignore: recursive_getters
        maxRunningDepthMillimeters.isBiggerThanValue(0),
  )();

  TextColumn get buoyancy => text().nullable()();
  TextColumn get imageReference => text().nullable()();
  TextColumn get searchText => text()();
  IntColumn get seedVersion => integer().nullable()();
  IntColumn get retiredAt => integer().nullable()();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (variant_name IS NOT NULL OR color_name IS NOT NULL '
        'OR manufacturer_color_code IS NOT NULL)',
    'CHECK (min_running_depth_millimeters IS NULL '
        'OR max_running_depth_millimeters IS NULL '
        'OR min_running_depth_millimeters <= max_running_depth_millimeters)',
  ];
}
