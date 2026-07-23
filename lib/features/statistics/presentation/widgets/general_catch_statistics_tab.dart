import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_details_page.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_repository.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/statistics/data/general_catch_statistics_repository.dart';
import 'package:fishing_app/features/statistics/data/species_statistics_repository.dart';
import 'package:fishing_app/features/statistics/data/water_body_statistics_repository.dart';
import 'package:fishing_app/features/statistics/domain/general_catch_statistics_summary.dart';
import 'package:fishing_app/features/statistics/domain/largest_catch.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';
import 'package:fishing_app/features/statistics/domain/water_body_catch_statistic.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/catch_count_row.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/ranked_largest_catch_row.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/species_statistics_page.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/statistics_summary_card.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/water_body_statistics_page.dart';

const String _noDataYetText = 'Ei vielä tietoja';

/// The Statistics feature's first tab: two full-width summary cards (total
/// catches, most caught species), a ranked Top 3 Largest Catches list, and
/// a per-species catch-count list, all computed live every time this tab
/// loads.
///
/// A plain [StatefulWidget] receiving its [GeneralCatchStatisticsRepository]
/// via a required constructor parameter, following the same `initState`
/// -> async load -> `setState` pattern already used by `LureStatisticsTab`
/// (TD-019).
///
/// Deliberately does **not** use `AutomaticKeepAliveClientMixin`: statistics
/// must be recomputed whenever this tab becomes visible (MFS-020), not
/// preserved across a tab switch — see TD-019's Key Design Decision 8,
/// reused here for the same reason (TD-020).
class GeneralCatchStatisticsTab extends StatefulWidget {
  const GeneralCatchStatisticsTab({
    super.key,
    required this.repository,
    required this.speciesStatisticsRepository,
    required this.waterBodyStatisticsRepository,
    required this.catchRepository,
    required this.catchPhotoRepository,
    required this.lureCatalogRepository,
    required this.personalTackleBoxRepository,
    required this.personalTackleBoxPhotoStorage,
    required this.waterBodyRepository,
  });

  final GeneralCatchStatisticsRepository repository;

  /// Used to open Species Statistics from a Species List row (MFS-021).
  final SpeciesStatisticsRepository speciesStatisticsRepository;

  /// Used to open Water Body Statistics from a Water Body List row.
  final WaterBodyStatisticsRepository waterBodyStatisticsRepository;

  /// Needed only to open Catch Details from a largest-catch entry (FR-5),
  /// a Species/Water Body Statistics Record Catch, or a Species/Water Body
  /// Statistics Catch List entry, and to resolve each entry's photo
  /// thumbnail via the reused `CatchListItem` — this tab performs no
  /// writes through any of them.
  final CatchRepository catchRepository;
  final CatchPhotoRepository catchPhotoRepository;
  final LureCatalogRepository lureCatalogRepository;
  final PersonalTackleBoxRepository personalTackleBoxRepository;
  final TackleBoxPhotoStorage personalTackleBoxPhotoStorage;

  /// Forwarded to `CatchDetailsPage.open()` for it to resolve each catch's
  /// own water body — see that page's own doc comment.
  final WaterBodyRepository waterBodyRepository;

  @override
  State<GeneralCatchStatisticsTab> createState() =>
      _GeneralCatchStatisticsTabState();
}

class _GeneralCatchStatisticsTabState extends State<GeneralCatchStatisticsTab> {
  bool _isLoading = true;
  String? _errorMessage;
  GeneralCatchStatisticsSummary? _summary;

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
      final summary = await widget.repository.getGeneralCatchStatistics();
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Failed to load general catch statistics: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Tilastojen lataaminen epäonnistui.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openCatchDetails(LargestCatch largestCatch) {
    return CatchDetailsPage.open(
      context,
      fishingSpot: largestCatch.fishingSpot,
      catchModel: largestCatch.catchModel,
      catchRepository: widget.catchRepository,
      catchPhotoRepository: widget.catchPhotoRepository,
      lureCatalogRepository: widget.lureCatalogRepository,
      personalTackleBoxRepository: widget.personalTackleBoxRepository,
      personalTackleBoxPhotoStorage: widget.personalTackleBoxPhotoStorage,
      waterBodyRepository: widget.waterBodyRepository,
    );
  }

  /// Reuses the same proactive lifecycle-refresh convention
  /// `WaterBodyStatisticsPage`/`SpeciesStatisticsPage` already apply to
  /// their own Catch Details visits (TD-022 Key Design Decision 9): a catch
  /// edited or deleted inside Species Statistics can change this tab's
  /// total, Top 3 Largest Catches, most caught species, Species List, and
  /// Water Body List, none of which Species Statistics itself has any
  /// way to know about or update — so this tab must reload its own summary
  /// unconditionally after returning, exactly as it does after opening
  /// Catch Details directly (`_openCatchDetails`), not only on a specific
  /// outcome.
  Future<void> _openSpeciesStatistics(SpeciesCatchStatistic statistic) async {
    await SpeciesStatisticsPage.open(
      context,
      species: statistic.species,
      repository: widget.speciesStatisticsRepository,
      catchRepository: widget.catchRepository,
      catchPhotoRepository: widget.catchPhotoRepository,
      lureCatalogRepository: widget.lureCatalogRepository,
      personalTackleBoxRepository: widget.personalTackleBoxRepository,
      personalTackleBoxPhotoStorage: widget.personalTackleBoxPhotoStorage,
      waterBodyRepository: widget.waterBodyRepository,
    );

    if (!mounted) {
      return;
    }
    await _load();
  }

  /// See `_openSpeciesStatistics`'s own doc comment — the identical
  /// unconditional reload-after-return principle applies here for Water
  /// Body Statistics.
  Future<void> _openWaterBodyStatistics(
    WaterBodyCatchStatistic statistic,
  ) async {
    await WaterBodyStatisticsPage.open(
      context,
      waterBody: statistic.waterBody,
      repository: widget.waterBodyStatisticsRepository,
      catchRepository: widget.catchRepository,
      catchPhotoRepository: widget.catchPhotoRepository,
      lureCatalogRepository: widget.lureCatalogRepository,
      personalTackleBoxRepository: widget.personalTackleBoxRepository,
      personalTackleBoxPhotoStorage: widget.personalTackleBoxPhotoStorage,
      waterBodyRepository: widget.waterBodyRepository,
    );

    if (!mounted) {
      return;
    }
    await _load();
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
      key: const Key('generalCatchStatisticsList'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // IntrinsicHeight + a stretched cross axis gives both cards the
        // same height regardless of how much text either one holds, while
        // StatisticsSummaryCard itself stays untouched (TD-020 §5).
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatisticsSummaryCard(
                  title: 'Saaliita yhteensä',
                  value: '${summary.totalCatches}',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatisticsSummaryCard(
                  title: 'Yleisin laji',
                  value: _mostCaughtSpeciesValueText(summary.mostCaughtSpecies),
                  secondaryValue: _mostCaughtSpeciesCountText(
                    summary.mostCaughtSpecies,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Suurimmat saaliit',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        if (summary.largestCatches.isEmpty)
          const Text('Yksikään saalis ei ole vielä punnittu.')
        else
          for (var i = 0; i < summary.largestCatches.length; i++) ...[
            RankedLargestCatchRow(
              key: ValueKey(summary.largestCatches[i].catchModel.id),
              rank: i + 1,
              catchModel: summary.largestCatches[i].catchModel,
              catchPhotoRepository: widget.catchPhotoRepository,
              onTap: () =>
                  unawaited(_openCatchDetails(summary.largestCatches[i])),
            ),
            if (i < summary.largestCatches.length - 1)
              const SizedBox(height: AppSpacing.md),
          ],
        const SizedBox(height: AppSpacing.xxl),
        Text('Lajit', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (summary.speciesCatchCounts.isEmpty)
          const Text('Ei vielä saaliita.')
        else
          for (final statistic in summary.speciesCatchCounts)
            CatchCountRow(
              key: ValueKey(statistic.species.name),
              label: statistic.species.finnishName,
              catchCount: statistic.catchCount,
              onTap: () => unawaited(_openSpeciesStatistics(statistic)),
            ),
        const SizedBox(height: AppSpacing.xxl),
        Text('Vesistöt', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (summary.waterBodyCatchCounts.isEmpty)
          const Text('Ei vielä saaliita.')
        else
          for (final statistic in summary.waterBodyCatchCounts)
            CatchCountRow(
              key: ValueKey(statistic.waterBody.id),
              label: statistic.waterBody.name,
              catchCount: statistic.catchCount,
              onTap: () => unawaited(_openWaterBodyStatistics(statistic)),
            ),
      ],
    );
  }

  String _mostCaughtSpeciesValueText(SpeciesCatchStatistic? statistic) {
    if (statistic == null) {
      return _noDataYetText;
    }
    return statistic.species.finnishName;
  }

  String? _mostCaughtSpeciesCountText(SpeciesCatchStatistic? statistic) {
    if (statistic == null) {
      return null;
    }
    return '${statistic.catchCount} saalista';
  }
}
