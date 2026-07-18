/// A shared, read-only catalog product line (e.g. "Rapala X-Rap Shad
/// XRS08"), framework-independent and independent of Drift.
///
/// A `LureModel` groups one or more [LureVariant]s (its concrete
/// purchasable color/size combinations). See MFS-015 / TD-015.
final class LureModel {
  const LureModel({
    required this.id,
    required this.manufacturer,
    required this.modelName,
    required this.lureType,
    required this.createdAt,
    required this.updatedAt,
    this.productFamily,
    this.defaultImageReference,
  }) : assert(id != '', 'id must not be empty'),
       assert(manufacturer != '', 'manufacturer must not be empty'),
       assert(modelName != '', 'modelName must not be empty'),
       assert(lureType != '', 'lureType must not be empty');

  final String id;
  final String manufacturer;
  final String modelName;

  /// An open, stable string code (not a closed enum) — see
  /// `lure_type_labels.dart`.
  final String lureType;
  final String? productFamily;
  final String? defaultImageReference;
  final DateTime createdAt;
  final DateTime updatedAt;
}
