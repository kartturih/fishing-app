import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_image.dart';

/// A single row in the Lure Catalog browse list: a thumbnail (or
/// placeholder) plus manufacturer/model and the variant's distinguishing
/// detail. Tapping the row opens the read-only Lure Details page.
///
/// [isOwned] draws a small badge over the thumbnail when the variant is
/// already in the user's Personal Tackle Box. This widget takes a plain
/// `bool` rather than reaching into `personal_tackle_box` itself — the
/// caller (see `LureCatalogListPage.loadOwnedLureVariantIds`) decides
/// ownership, keeping `lure_catalog` free of any dependency on that
/// feature. See MFS-015 / TD-015.
class LureCatalogListItem extends StatelessWidget {
  const LureCatalogListItem({
    super.key,
    required this.entry,
    required this.onTap,
    this.isOwned = false,
  });

  final LureCatalogEntry entry;
  final VoidCallback onTap;
  final bool isOwned;

  String get _distinguishingDetail {
    final variant = entry.variant;
    return variant.variantName ??
        variant.colorName ??
        variant.manufacturerColorCode ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    final distinguishingDetail = _distinguishingDetail;
    final baseLabel = distinguishingDetail.isEmpty
        ? '${entry.manufacturer} ${entry.modelName}'
        : '${entry.manufacturer} ${entry.modelName} $distinguishingDetail';
    final semanticLabel = isOwned ? '$baseLabel, omistuksessa' : baseLabel;

    return InkWell(
      onTap: onTap,
      child: Semantics(
        label: semanticLabel,
        button: true,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  LureImage(
                    imageReference: entry.effectiveImageReference,
                    semanticLabel: baseLabel,
                    size: 56,
                  ),
                  if (isOwned)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: _OwnedBadge(key: const Key('ownedBadge')),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.manufacturer} ${entry.modelName}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (distinguishingDetail.isNotEmpty)
                      Text(distinguishingDetail),
                    Text(
                      lureTypeDisplayLabel(entry.lureType),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small, subtle badge marking a catalog thumbnail as already owned. Purely
/// decorative — the accessible "omistuksessa" wording lives on the row's own
/// [Semantics] label, so this badge excludes itself from the semantics tree.
class _OwnedBadge extends StatelessWidget {
  const _OwnedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary,
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.check,
          size: 14,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
