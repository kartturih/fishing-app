import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';

/// Renders one [SpeciesCatchStatistic]: its Finnish display name and catch
/// count, with a trailing static chevron signaling that this row is
/// designed for future navigation to species-specific statistics (MFS-021
/// Candidate, not this milestone). No tap handling of any kind is attached
/// — selecting a row has no effect, and the row is not exposed to
/// assistive technology as a button. See MFS-020 FR-8 / TD-020 Key Design
/// Decision 9.
class SpeciesCatchStatisticRow extends StatelessWidget {
  const SpeciesCatchStatisticRow({super.key, required this.statistic});

  final SpeciesCatchStatistic statistic;

  @override
  Widget build(BuildContext context) {
    final label = statistic.species.finnishName;
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
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
