import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';
import 'package:fishing_app/features/statistics/data/lure_statistics_repository.dart';
import 'package:fishing_app/features/statistics/domain/lure_catch_statistic.dart';
import 'package:fishing_app/features/statistics/domain/lure_distinguishing_detail.dart';
import 'package:fishing_app/features/statistics/domain/lure_statistics_summary.dart';
import 'package:fishing_app/features/statistics/domain/lure_type_catch_statistic.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/lure_catch_statistic_row.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/lure_statistics_summary_card.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/lure_type_catch_statistic_row.dart';

const String _noDataYetText = 'Ei vielä tietoja';

/// The Statistics feature's first tab: two full-width summary cards (most
/// successful lure, most successful lure type), a per-lure catch-count
/// list, and a per-lure-type catch-count breakdown, all computed live every
/// time this tab loads.
///
/// A plain [StatefulWidget] receiving its [LureStatisticsRepository] via a
/// required constructor parameter, following the same `initState` -> async
/// load -> `setState` pattern already used by `PersonalTackleBoxPage`
/// (TD-016) and `CatchDetailsPage`'s lure resolution (TD-017).
///
/// Deliberately does **not** use `AutomaticKeepAliveClientMixin`: statistics
/// must be recomputed whenever this tab becomes visible (MFS-019), not
/// preserved across a tab switch — see TD-019's Key Design Decision 8.
class LureStatisticsTab extends StatefulWidget {
  const LureStatisticsTab({super.key, required this.repository});

  final LureStatisticsRepository repository;

  @override
  State<LureStatisticsTab> createState() => _LureStatisticsTabState();
}

class _LureStatisticsTabState extends State<LureStatisticsTab> {
  bool _isLoading = true;
  String? _errorMessage;
  LureStatisticsSummary? _summary;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary = await widget.repository.getLureStatistics();
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Failed to load lure statistics: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Tilastojen lataaminen epäonnistui.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => unawaited(_load()),
                child: const Text('Yritä uudelleen'),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _summary!;
    return ListView(
      key: const Key('lureStatisticsList'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        LureStatisticsSummaryCard(
          title: 'Menestynein viehe',
          value: _mostSuccessfulLureText(summary.mostSuccessfulLure),
        ),
        const SizedBox(height: AppSpacing.sm),
        LureStatisticsSummaryCard(
          title: 'Menestynein viehetyyppi',
          value: _mostSuccessfulLureTypeText(summary.mostSuccessfulLureType),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Vieheet', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (summary.lures.isEmpty)
          const Text('Yksikään viehe ei ole vielä tuottanut saalista.')
        else
          for (final statistic in summary.lures)
            LureCatchStatisticRow(
              key: ValueKey(statistic.lure.id),
              statistic: statistic,
            ),
        const SizedBox(height: AppSpacing.xl),
        Text('Viehetyypit', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (summary.lureTypeBreakdown.isEmpty)
          const Text('Ei viehetyyppikohtaista dataa vielä.')
        else
          for (final statistic in summary.lureTypeBreakdown)
            LureTypeCatchStatisticRow(
              key: ValueKey(statistic.lureType),
              statistic: statistic,
            ),
      ],
    );
  }

  String _mostSuccessfulLureText(LureCatchStatistic? statistic) {
    if (statistic == null) {
      return _noDataYetText;
    }
    final name = lureDisplayName(statistic.lure);
    return '$name (${statistic.catchCount} saalista)';
  }

  String _mostSuccessfulLureTypeText(LureTypeCatchStatistic? statistic) {
    if (statistic == null) {
      return _noDataYetText;
    }
    final label = lureTypeDisplayLabel(statistic.lureType);
    return '$label (${statistic.catchCount} saalista)';
  }
}
