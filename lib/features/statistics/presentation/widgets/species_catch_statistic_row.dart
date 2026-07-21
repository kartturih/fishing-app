import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';

/// Renders one [SpeciesCatchStatistic]: its Finnish display name and catch
/// count, with a trailing chevron. Tapping the row opens Species Statistics
/// for [SpeciesCatchStatistic.species] (MFS-021), so the row is exposed to
/// assistive technology as a real button — the change MFS-020's own
/// Accessibility Expectations already anticipated ("expected to change once
/// a future milestone adds real navigation"). See MFS-021 / TD-021 Key
/// Design Decision 1.
class SpeciesCatchStatisticRow extends StatelessWidget {
  const SpeciesCatchStatisticRow({
    super.key,
    required this.statistic,
    required this.onTap,
  });

  final SpeciesCatchStatistic statistic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = statistic.species.finnishName;
    final semanticLabel = '$label, ${statistic.catchCount} saalista';

    return InkWell(
      onTap: onTap,
      child: Semantics(
        label: semanticLabel,
        button: true,
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
      ),
    );
  }
}
