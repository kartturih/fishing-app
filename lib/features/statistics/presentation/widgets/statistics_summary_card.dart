import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';

/// A small, stateless summary card showing a [title], a [value], and an
/// optional [secondaryValue] — pure presentation, no business logic, no
/// repository access. Shared by both Statistics tabs
/// (`GeneralCatchStatisticsTab`, `LureStatisticsTab`), which are each
/// responsible for formatting their own cards' content. Renamed from
/// `LureStatisticsSummaryCard` once it became genuinely shared, not
/// lure-specific — see MFS-019/TD-019 §5, MFS-020/TD-020 Key Design
/// Decision 8. [secondaryValue] was added for the Catches tab's "most
/// caught species" card (species name as [value], catch count as
/// [secondaryValue]) without complicating the title/value contract every
/// other caller already relies on — it is `null` and renders nothing for
/// every other card.
class StatisticsSummaryCard extends StatelessWidget {
  const StatisticsSummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.secondaryValue,
  });

  final String title;
  final String value;
  final String? secondaryValue;

  @override
  Widget build(BuildContext context) {
    final secondary = secondaryValue;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (secondary != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
