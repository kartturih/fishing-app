import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';

/// The joined, read-only projection returned by every
/// `LureCatalogRepository` browse/search/filter/details query: a
/// [LureVariant] combined with its parent `LureModel`'s shared fields.
///
/// Combining these in one type is what lets every catalog query resolve in
/// a single SQL join, rather than the presentation layer loading a variant
/// and then separately querying for its model. See MFS-015 / TD-015.
final class LureCatalogEntry {
  const LureCatalogEntry({
    required this.variant,
    required this.manufacturer,
    required this.modelName,
    required this.lureType,
    required this.modelDefaultImageReference,
    this.productFamily,
  });

  final LureVariant variant;
  final String manufacturer;
  final String modelName;
  final String lureType;
  final String? productFamily;
  final String? modelDefaultImageReference;

  String get id => variant.id;

  /// The variant's own image if present, otherwise the parent model's
  /// default image. Resolved once here so presentation code never needs to
  /// know the fallback rule.
  String? get effectiveImageReference =>
      variant.imageReference ?? modelDefaultImageReference;
}
