/// A specific, independently purchasable catalog product variant (one
/// concrete color/size/spec combination of a [LureModel]),
/// framework-independent and independent of Drift.
///
/// Every field other than [id], [lureModelId], [createdAt], and [updatedAt]
/// is optional: not every lure type has a meaningful running depth, and not
/// every product publishes an exact weight. At least one of [variantName],
/// [colorName], or [manufacturerColorCode] must be present so the variant
/// remains distinguishable from its siblings under the same model. See
/// MFS-015 / TD-015.
final class LureVariant {
  const LureVariant({
    required this.id,
    required this.lureModelId,
    required this.createdAt,
    required this.updatedAt,
    this.variantName,
    this.colorName,
    this.manufacturerColorCode,
    this.lengthMillimeters,
    this.weightGrams,
    this.minRunningDepthMillimeters,
    this.maxRunningDepthMillimeters,
    this.buoyancy,
    this.imageReference,
  }) : assert(id != '', 'id must not be empty'),
       assert(lureModelId != '', 'lureModelId must not be empty'),
       assert(
         variantName != null ||
             colorName != null ||
             manufacturerColorCode != null,
         'a LureVariant must have at least one of variantName, colorName, '
         'or manufacturerColorCode to be distinguishable from its siblings',
       ),
       assert(
         lengthMillimeters == null || lengthMillimeters > 0,
         'lengthMillimeters must be greater than zero when provided',
       ),
       assert(
         weightGrams == null || weightGrams > 0,
         'weightGrams must be greater than zero when provided',
       ),
       assert(
         minRunningDepthMillimeters == null || minRunningDepthMillimeters > 0,
         'minRunningDepthMillimeters must be greater than zero when provided',
       ),
       assert(
         maxRunningDepthMillimeters == null || maxRunningDepthMillimeters > 0,
         'maxRunningDepthMillimeters must be greater than zero when provided',
       ),
       assert(
         minRunningDepthMillimeters == null ||
             maxRunningDepthMillimeters == null ||
             minRunningDepthMillimeters <= maxRunningDepthMillimeters,
         'minRunningDepthMillimeters must not exceed maxRunningDepthMillimeters',
       );

  final String id;
  final String lureModelId;
  final String? variantName;
  final String? colorName;
  final String? manufacturerColorCode;
  final int? lengthMillimeters;
  final int? weightGrams;
  final int? minRunningDepthMillimeters;
  final int? maxRunningDepthMillimeters;

  /// An open, stable string code (not a closed enum) — see
  /// `lure_type_labels.dart`.
  final String? buoyancy;
  final String? imageReference;
  final DateTime createdAt;
  final DateTime updatedAt;
}
