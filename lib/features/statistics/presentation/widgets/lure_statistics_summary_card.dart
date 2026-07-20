import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';

/// A small, stateless summary card showing a [title] and a [value] — pure
/// presentation, no business logic, no repository access. Used three times
/// by `LureStatisticsTab`, which is responsible for formatting each card's
/// specific content. See MFS-019 / TD-019 §5.
class LureStatisticsSummaryCard extends StatelessWidget {
  const LureStatisticsSummaryCard({
    super.key,
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
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
          ],
        ),
      ),
    );
  }
}
