import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_image.dart';
import 'package:fishing_app/features/statistics/domain/lure_catch_statistic.dart';
import 'package:fishing_app/features/statistics/domain/lure_distinguishing_detail.dart';

/// Renders one [LureCatchStatistic]: photo (with the existing catalog
/// image-fallback behavior), manufacturer + model name, color/variant
/// detail, lure type, and catch count. A pure, stateless row — no
/// repository access, no navigation. See MFS-019 / TD-019 §5.
class LureCatchStatisticRow extends StatelessWidget {
  const LureCatchStatisticRow({super.key, required this.statistic});

  final LureCatchStatistic statistic;

  @override
  Widget build(BuildContext context) {
    final lure = statistic.lure;
    final title = lureDisplayName(lure);
    final lureTypeLabel = lureTypeDisplayLabel(lure.lureType);
    final semanticLabel =
        '$title, $lureTypeLabel, ${statistic.catchCount} saalista';

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            LureImage(
              imageReference: lure.effectiveImageReference,
              semanticLabel: semanticLabel,
              size: 48,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    lureTypeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${statistic.catchCount}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
