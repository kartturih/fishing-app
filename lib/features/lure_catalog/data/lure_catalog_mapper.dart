import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_model.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';

/// Converts between Drift rows/companions and the Lure Catalog domain/read
/// model types. Search-text derivation lives outside this class — see
/// `lure_catalog_search_text.dart`. See MFS-015 / TD-015.
class LureCatalogMapper {
  const LureCatalogMapper();

  LureCatalogEntry entryFromRows({
    required LureVariantEntity variantRow,
    required LureModelEntity modelRow,
  }) {
    return LureCatalogEntry(
      variant: variantFromRow(variantRow),
      manufacturer: modelRow.manufacturer,
      productFamily: modelRow.productFamily,
      modelName: modelRow.modelName,
      lureType: modelRow.lureType,
      modelDefaultImageReference: modelRow.defaultImageReference,
    );
  }

  /// Converts a single `LureVariants` row with no model join, e.g. for
  /// `LureCatalogRepository.getVariantsForModel()`, whose caller already
  /// knows the model-level fields. See TD-018's Implementation Notes.
  LureVariant variantFromRow(LureVariantEntity row) {
    return LureVariant(
      id: row.id,
      lureModelId: row.lureModelId,
      variantName: row.variantName,
      colorName: row.colorName,
      manufacturerColorCode: row.manufacturerColorCode,
      lengthMillimeters: row.lengthMillimeters,
      weightGrams: row.weightGrams,
      minRunningDepthMillimeters: row.minRunningDepthMillimeters,
      maxRunningDepthMillimeters: row.maxRunningDepthMillimeters,
      buoyancy: row.buoyancy,
      imageReference: row.imageReference,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  /// Builds the companion used to insert/correct a seed [LureModel] row.
  /// [searchText] is computed by the caller (see
  /// `lure_catalog_search_text.dart`), not by this mapper.
  LureModelsCompanion modelToCompanion(
    LureModel model, {
    required int seedVersion,
    required String searchText,
  }) {
    return LureModelsCompanion.insert(
      id: model.id,
      manufacturer: model.manufacturer,
      productFamily: Value(model.productFamily),
      modelName: model.modelName,
      lureType: model.lureType,
      defaultImageReference: Value(model.defaultImageReference),
      searchText: searchText,
      seedVersion: Value(seedVersion),
      createdAt: model.createdAt.millisecondsSinceEpoch,
      updatedAt: model.updatedAt.millisecondsSinceEpoch,
    );
  }

  /// Builds the companion used to insert/correct a seed [LureVariant] row.
  /// [searchText] is computed by the caller. Reconciling from seed data
  /// always clears `retiredAt`: a variant present in the current seed
  /// source is, by definition, not retired.
  LureVariantsCompanion variantToCompanion(
    LureVariant variant, {
    required int seedVersion,
    required String searchText,
  }) {
    return LureVariantsCompanion.insert(
      id: variant.id,
      lureModelId: variant.lureModelId,
      variantName: Value(variant.variantName),
      colorName: Value(variant.colorName),
      manufacturerColorCode: Value(variant.manufacturerColorCode),
      lengthMillimeters: Value(variant.lengthMillimeters),
      weightGrams: Value(variant.weightGrams),
      minRunningDepthMillimeters: Value(variant.minRunningDepthMillimeters),
      maxRunningDepthMillimeters: Value(variant.maxRunningDepthMillimeters),
      buoyancy: Value(variant.buoyancy),
      imageReference: Value(variant.imageReference),
      searchText: searchText,
      seedVersion: Value(seedVersion),
      retiredAt: const Value(null),
      createdAt: variant.createdAt.millisecondsSinceEpoch,
      updatedAt: variant.updatedAt.millisecondsSinceEpoch,
    );
  }
}
