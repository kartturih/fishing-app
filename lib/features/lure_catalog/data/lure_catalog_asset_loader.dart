import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:fishing_app/features/lure_catalog/domain/lure_model.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';

/// A single, fixed timestamp used for every freshly-parsed catalog
/// model/variant's [LureModel.createdAt]/[LureVariant.createdAt] and
/// `updatedAt`. Matches the original hand-authored Dart seed's own
/// `_seedAuthoredAt` convention exactly, so a fresh install's first import
/// produces identical `createdAt`/`updatedAt` values whether the catalog
/// came from the legacy Dart literals or this JSON-driven loader — the
/// generated catalog asset does not itself carry per-record timestamps
/// (TD-028 Section 3): they are bookkeeping about *when a device first
/// learned about a row*, not authored content, and are otherwise preserved
/// or bumped by `LureCatalogRepository`'s own reconciliation logic, never
/// read back out of this fixed value except on a genuinely first insert.
final DateTime placeholderCatalogContentTimestamp = DateTime.utc(2026, 1, 1);

/// Loads and parses the bundled, generated Lure Catalog asset
/// (`assets/lure_catalog/catalog_v1.json`), produced by
/// `tools/lure_catalog/build_catalog.py` from the manufacturer authoring
/// files under `assets/lure_catalog/source/`. Never reads those authoring
/// files directly — only the single, already-normalized, already-validated
/// generated asset. See TD-028 Section 7.
class LureCatalogAssetLoader {
  const LureCatalogAssetLoader();

  static const String defaultAssetFileName =
      'assets/lure_catalog/catalog_v1.json';

  Future<ParsedLureCatalog> load({
    String assetFileName = defaultAssetFileName,
  }) async {
    final raw = await rootBundle.loadString(assetFileName);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ParsedLureCatalog.fromJson(json);
  }
}

/// The parsed contents of the bundled catalog asset: a [catalogVersion]
/// integer (the sole driver of reconciliation — see
/// `LureCatalogRepository.ensureSeeded`) plus the flat model/variant lists,
/// already mapped into the existing domain types. See TD-028 Section 3.
class ParsedLureCatalog {
  const ParsedLureCatalog({
    required this.catalogVersion,
    required this.models,
    required this.variants,
  });

  final int catalogVersion;
  final List<LureModel> models;
  final List<LureVariant> variants;

  factory ParsedLureCatalog.fromJson(Map<String, dynamic> json) {
    final modelsJson = json['models'] as List<dynamic>;
    final variantsJson = json['variants'] as List<dynamic>;

    return ParsedLureCatalog(
      catalogVersion: json['catalogVersion'] as int,
      models: [
        for (final entry in modelsJson)
          _modelFromJson(entry as Map<String, dynamic>),
      ],
      variants: [
        for (final entry in variantsJson)
          _variantFromJson(entry as Map<String, dynamic>),
      ],
    );
  }
}

LureModel _modelFromJson(Map<String, dynamic> json) {
  return LureModel(
    id: json['id'] as String,
    manufacturer: json['manufacturer'] as String,
    productFamily: json['productFamily'] as String?,
    modelName: json['modelName'] as String,
    lureType: json['lureType'] as String,
    defaultImageReference: json['defaultImageReference'] as String?,
    createdAt: placeholderCatalogContentTimestamp,
    updatedAt: placeholderCatalogContentTimestamp,
  );
}

LureVariant _variantFromJson(Map<String, dynamic> json) {
  return LureVariant(
    id: json['id'] as String,
    lureModelId: json['lureModelId'] as String,
    variantName: json['variantName'] as String?,
    colorName: json['colorName'] as String?,
    manufacturerColorCode: json['manufacturerColorCode'] as String?,
    lengthMillimeters: json['lengthMillimeters'] as int?,
    weightGrams: json['weightGrams'] as int?,
    minRunningDepthMillimeters: json['minRunningDepthMillimeters'] as int?,
    maxRunningDepthMillimeters: json['maxRunningDepthMillimeters'] as int?,
    buoyancy: json['buoyancy'] as String?,
    imageReference: json['imageReference'] as String?,
    createdAt: placeholderCatalogContentTimestamp,
    updatedAt: placeholderCatalogContentTimestamp,
  );
}
