/// A record of a [LureVariant] the user actually owns, framework-independent
/// and independent of Drift.
///
/// Ownership is a boolean fact represented by the existence of this record —
/// there is no quantity, price, condition, or notes field. [personalPhotoRelativePath]
/// is the user's own photo of the physical item they own, never a catalog
/// image; it is optional, since skipping a photo is a fully valid outcome.
/// See MFS-016 / TD-016.
final class TackleBoxEntry {
  const TackleBoxEntry({
    required this.id,
    required this.lureVariantId,
    required this.addedAt,
    required this.createdAt,
    required this.updatedAt,
    this.personalPhotoRelativePath,
  }) : assert(id != '', 'id must not be empty'),
       assert(lureVariantId != '', 'lureVariantId must not be empty');

  final String id;

  /// References `LureVariant.id` (lure_catalog feature) by identifier only —
  /// this feature never duplicates catalog data.
  final String lureVariantId;

  /// An application-managed relative path, never an absolute device path and
  /// never image bytes. `null` means no personal photo has been added.
  final String? personalPhotoRelativePath;

  /// When the user added this lure to their tackle box. Set once at creation
  /// and never changes, independent of [updatedAt].
  final DateTime addedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
