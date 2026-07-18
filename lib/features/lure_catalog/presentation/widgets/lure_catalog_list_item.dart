import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_image.dart';

/// A single row in the Lure Catalog browse list: a thumbnail (or
/// placeholder) plus manufacturer/model and the variant's distinguishing
/// detail. Tapping the row opens the read-only Lure Details page. See
/// MFS-015 / TD-015.
class LureCatalogListItem extends StatelessWidget {
  const LureCatalogListItem({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final LureCatalogEntry entry;
  final VoidCallback onTap;

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
    final semanticLabel = distinguishingDetail.isEmpty
        ? '${entry.manufacturer} ${entry.modelName}'
        : '${entry.manufacturer} ${entry.modelName} $distinguishingDetail';

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
              LureImage(
                imageReference: entry.effectiveImageReference,
                semanticLabel: semanticLabel,
                size: 56,
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
