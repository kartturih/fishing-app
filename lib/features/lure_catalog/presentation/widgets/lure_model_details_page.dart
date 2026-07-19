import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/color_variant_row.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_details_page.dart';

/// Lure Model Details: one lure model's common information plus its full
/// list of color variants. Replaces `LureDetailsPage` as the browsing list's
/// push destination now that the list groups by model. See MFS-018 / TD-018.
///
/// A [StatelessWidget]: all mutable state (the loaded catalog rows, the
/// owned-ids set) is owned by the parent browsing flow (`LureCatalogListPage`
/// today). This page only renders already-resolved data passed in via its
/// constructor — it performs no repository loading and needs no page-local
/// state of its own (TD-018 Key Design Decision 10).
class LureModelDetailsPage extends StatelessWidget {
  const LureModelDetailsPage({
    super.key,
    required this.modelEntry,
    required this.variants,
    required this.ownedVariantIds,
    this.variantActionBuilder,
  });

  final LureCatalogEntry modelEntry;
  final List<LureVariant> variants;
  final Set<String> ownedVariantIds;

  /// Generic, optional per-variant extension point — the same shape of
  /// touch as `LureDetailsPage.actionsBuilder`, one level up the new
  /// navigation stack. `lure_catalog` still never imports
  /// `personal_tackle_box`.
  final Widget Function(
    BuildContext context,
    LureCatalogEntry variantEntry, {
    required bool initialIsOwned,
  })?
  variantActionBuilder;

  static Future<void> open(
    BuildContext context, {
    required LureCatalogEntry modelEntry,
    required List<LureVariant> variants,
    required Set<String> ownedVariantIds,
    Widget Function(
      BuildContext context,
      LureCatalogEntry variantEntry, {
      required bool initialIsOwned,
    })?
    variantActionBuilder,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LureModelDetailsPage(
          modelEntry: modelEntry,
          variants: variants,
          ownedVariantIds: ownedVariantIds,
          variantActionBuilder: variantActionBuilder,
        ),
      ),
    );
  }

  /// A presentation convenience only, not a new source of truth. Assembled
  /// entirely from data already held in memory (the row's own [LureVariant]
  /// plus [modelEntry]'s already-loaded model-level fields) purely so that
  /// `LureDetailsPage` — which expects one `LureCatalogEntry` per its
  /// existing, unchanged contract — can render it. Never persisted, never
  /// written back to `LureCatalogRepository` or any other repository, and
  /// never treated as an independent record beyond the `variant.id` it
  /// wraps: the single authoritative source for every field it carries
  /// remains the row `browse()` originally returned.
  LureCatalogEntry _entryFor(LureVariant variant) => LureCatalogEntry(
    variant: variant,
    manufacturer: modelEntry.manufacturer,
    modelName: modelEntry.modelName,
    lureType: modelEntry.lureType,
    productFamily: modelEntry.productFamily,
    modelDefaultImageReference: modelEntry.modelDefaultImageReference,
  );

  @override
  Widget build(BuildContext context) {
    final baseLabel = '${modelEntry.manufacturer} ${modelEntry.modelName}';

    return Scaffold(
      appBar: AppBar(title: Text(baseLabel)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(context, 'Valmistaja', modelEntry.manufacturer),
                  if (modelEntry.productFamily != null)
                    _buildInfoRow(
                      context,
                      'Mallisto',
                      modelEntry.productFamily!,
                    ),
                  _buildInfoRow(context, 'Malli', modelEntry.modelName),
                  _buildInfoRow(
                    context,
                    'Vieheen tyyppi',
                    lureTypeDisplayLabel(modelEntry.lureType),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Väriversiot',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: variants.length,
                itemBuilder: (context, index) {
                  final variant = variants[index];
                  final variantEntry = _entryFor(variant);
                  final initialIsOwned = ownedVariantIds.contains(variant.id);

                  return ColorVariantRow(
                    entry: variantEntry,
                    onTap: () => LureDetailsPage.open(context, variantEntry),
                    action: variantActionBuilder?.call(
                      context,
                      variantEntry,
                      initialIsOwned: initialIsOwned,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
