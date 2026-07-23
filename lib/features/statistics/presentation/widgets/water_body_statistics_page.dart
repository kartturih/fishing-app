import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/widgets/add_catch_bottom_sheet.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_details_page.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_list_item.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/statistics/data/water_body_statistics_repository.dart';
import 'package:fishing_app/features/statistics/domain/water_body_catch_entry.dart';
import 'package:fishing_app/features/statistics/domain/water_body_statistics_summary.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/catch_count_row.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/statistics_summary_card.dart';

const String _noDataYetText = 'Ei vielä tietoja';

/// One water body's statistics: total catches, Last Catch Date, a static
/// Species Breakdown, and a full Catch List spanning every fishing spot
/// belonging to that water body — reached by tapping a row in the Catches
/// tab's Water Body List. Pushed as a normal full-screen page
/// (`MaterialPageRoute`), mirroring `FishingSpotStatisticsPage.open()`'s
/// precedent.
class WaterBodyStatisticsPage extends StatefulWidget {
  const WaterBodyStatisticsPage({
    super.key,
    required this.waterBody,
    required this.repository,
    required this.catchRepository,
    required this.catchPhotoRepository,
    required this.lureCatalogRepository,
    required this.personalTackleBoxRepository,
    required this.personalTackleBoxPhotoStorage,
  });

  final WaterBody waterBody;
  final WaterBodyStatisticsRepository repository;

  /// Forwarded to `CatchDetailsPage.open()` when a Catch List entry is
  /// tapped — this page has no other use for them.
  final CatchRepository catchRepository;
  final CatchPhotoRepository catchPhotoRepository;
  final LureCatalogRepository lureCatalogRepository;
  final PersonalTackleBoxRepository personalTackleBoxRepository;
  final TackleBoxPhotoStorage personalTackleBoxPhotoStorage;

  /// Pushes Water Body Statistics as a normal [MaterialPageRoute].
  static Future<void> open(
    BuildContext context, {
    required WaterBody waterBody,
    required WaterBodyStatisticsRepository repository,
    required CatchRepository catchRepository,
    required CatchPhotoRepository catchPhotoRepository,
    required LureCatalogRepository lureCatalogRepository,
    required PersonalTackleBoxRepository personalTackleBoxRepository,
    required TackleBoxPhotoStorage personalTackleBoxPhotoStorage,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WaterBodyStatisticsPage(
          waterBody: waterBody,
          repository: repository,
          catchRepository: catchRepository,
          catchPhotoRepository: catchPhotoRepository,
          lureCatalogRepository: lureCatalogRepository,
          personalTackleBoxRepository: personalTackleBoxRepository,
          personalTackleBoxPhotoStorage: personalTackleBoxPhotoStorage,
        ),
      ),
    );
  }

  @override
  State<WaterBodyStatisticsPage> createState() =>
      _WaterBodyStatisticsPageState();
}

class _WaterBodyStatisticsPageState extends State<WaterBodyStatisticsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  WaterBodyStatisticsSummary? _summary;

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
      final summary = await widget.repository.getWaterBodyStatistics(
        widget.waterBody.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Failed to load water body statistics: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Tilastojen lataaminen epäonnistui.';
        _isLoading = false;
      });
    }
  }

  /// Unconditionally reloads after returning from Catch Details, since it
  /// has no typed changed-result — the same established convention
  /// `FishingSpotStatisticsPage`/`SpeciesStatisticsPage` already apply.
  Future<void> _openCatchDetails(WaterBodyCatchEntry entry) async {
    await CatchDetailsPage.open(
      context,
      fishingSpot: entry.fishingSpot,
      catchModel: entry.catchModel,
      catchRepository: widget.catchRepository,
      catchPhotoRepository: widget.catchPhotoRepository,
      lureCatalogRepository: widget.lureCatalogRepository,
      personalTackleBoxRepository: widget.personalTackleBoxRepository,
      personalTackleBoxPhotoStorage: widget.personalTackleBoxPhotoStorage,
    );

    if (!mounted) {
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.waterBody.name)),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
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
      key: const Key('waterBodyStatisticsList'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
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
                  title: 'Viimeisin saalis',
                  value: _lastCatchDateText(summary.lastCatchDate),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
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
            ),
        const SizedBox(height: AppSpacing.xxl),
        Text('Kaikki saaliit', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (summary.catches.isEmpty)
          const Text('Ei vielä saaliita.')
        else
          for (final entry in summary.catches)
            CatchListItem(
              key: ValueKey(entry.catchModel.id),
              catchModel: entry.catchModel,
              catchPhotoRepository: widget.catchPhotoRepository,
              onTap: () => unawaited(_openCatchDetails(entry)),
            ),
      ],
    );
  }

  String _lastCatchDateText(DateTime? lastCatchDate) {
    if (lastCatchDate == null) {
      return _noDataYetText;
    }
    return formatCatchDate(lastCatchDate);
  }
}
