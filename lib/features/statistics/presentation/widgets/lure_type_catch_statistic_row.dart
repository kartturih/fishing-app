import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';
import 'package:fishing_app/features/statistics/domain/lure_type_catch_statistic.dart';

/// Renders one [LureTypeCatchStatistic]: its Finnish display label and
/// catch count. A pure, stateless row. See MFS-019 / TD-019 §5.
class LureTypeCatchStatisticRow extends StatelessWidget {
  const LureTypeCatchStatisticRow({super.key, required this.statistic});

  final LureTypeCatchStatistic statistic;

  @override
  Widget build(BuildContext context) {
    final label = lureTypeDisplayLabel(statistic.lureType);
    final semanticLabel = '$label, ${statistic.catchCount} saalista';

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
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
