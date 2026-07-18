import 'package:fishing_app/features/lure_catalog/domain/lure_model.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';

/// Builds the precomputed, Dart-lowercased search keys stored in
/// `LureModels.searchText`/`LureVariants.searchText`.
///
/// SQLite's own `LIKE`/`COLLATE NOCASE` only reliably folds ASCII case, so
/// it cannot correctly match Finnish `ä`/`ö` case-insensitively. Instead,
/// both the stored key and the incoming search term are lowercased once in
/// Dart (which is Unicode-aware), and compared with a plain `LIKE` that
/// never needs SQLite to fold case at all.
///
/// Kept separate from `LureCatalogMapper`: every existing mapper in this
/// codebase (`CatchMapper`, `CatchPhotoMapper`, `FishingSpotEntityMapper`)
/// performs direct field-to-field conversion only. Deriving one new value
/// from several source fields is a distinct concern from that, so it lives
/// here rather than inside the mapper. See MFS-015 / TD-015.
String buildLureModelSearchText(LureModel model) {
  final parts = [
    model.manufacturer,
    model.productFamily,
    model.modelName,
  ].whereType<String>().where((value) => value.isNotEmpty);
  return parts.join(' ').toLowerCase();
}

String buildLureVariantSearchText(LureVariant variant) {
  final parts = [
    variant.variantName,
    variant.colorName,
    variant.manufacturerColorCode,
  ].whereType<String>().where((value) => value.isNotEmpty);
  return parts.join(' ').toLowerCase();
}
