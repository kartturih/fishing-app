import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';

/// The single piece of text that distinguishes one [LureCatalogEntry] from
/// a sibling variant of the same model — the same fallback chain
/// `LureVariant`'s own constructor assertion already requires at least one
/// of to be present (MFS-015). Reused by [LureStatisticsRepository]'s
/// deterministic tie-break and by the lure list's "Color" column, so the
/// same fallback logic is never duplicated within this feature.
String lureDistinguishingDetail(LureCatalogEntry entry) =>
    entry.variant.colorName ??
    entry.variant.manufacturerColorCode ??
    entry.variant.variantName ??
    '';

/// A human-readable "manufacturer model[, detail]" name for [entry],
/// omitting the trailing detail when [lureDistinguishingDetail] is empty.
/// Shared by the lure list row and the "most successful lure" summary card
/// so the two never drift apart.
String lureDisplayName(LureCatalogEntry entry) {
  final distinguishingDetail = lureDistinguishingDetail(entry);
  return distinguishingDetail.isEmpty
      ? '${entry.manufacturer} ${entry.modelName}'
      : '${entry.manufacturer} ${entry.modelName}, $distinguishingDetail';
}
