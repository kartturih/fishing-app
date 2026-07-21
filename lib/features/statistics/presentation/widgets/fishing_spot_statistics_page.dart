import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/widgets/add_catch_bottom_sheet.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_details_page.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_list_item.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/statistics/data/fishing_spot_statistics_repository.dart';
import 'package:fishing_app/features/statistics/domain/fishing_spot_statistics_summary.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/catch_count_row.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/fishing_spot_record_catch_card.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/statistics_summary_card.dart';

const String _noDataYetText = 'Ei vielä tietoja';

/// One fishing spot's statistics: total catches, Last Catch Date, a Record
/// Catch section, a static Species Breakdown, and a full Catch List —
/// reached by tapping a row in the Catches tab's Fishing Spot List.
/// Pushed as a normal full-screen page (`MaterialPageRoute`), mirroring
/// `SpeciesStatisticsPage.open()`'s exact precedent, not a third
/// Statistics tab. See MFS-022 / TD-022 Key Design Decision 2/9.
class FishingSpotStatisticsPage extends StatefulWidget {
  const FishingSpotStatisticsPage({
    super.key,
    required this.fishingSpot,
    required this.repository,
    required this.catchRepository,
    required this.catchPhotoRepository,
    required this.lureCatalogRepository,
    required this.personalTackleBoxRepository,
    required this.personalTackleBoxPhotoStorage,
  });

  final FishingSpot fishingSpot;
  final FishingSpotStatisticsRepository repository;

  /// Forwarded to `CatchDetailsPage.open()` when the Record Catch card or a
  /// Catch List entry is tapped — this page has no other use for them.
  final CatchRepository catchRepository;
  final CatchPhotoRepository catchPhotoRepository;
  final LureCatalogRepository lureCatalogRepository;
  final PersonalTackleBoxRepository personalTackleBoxRepository;
  final TackleBoxPhotoStorage personalTackleBoxPhotoStorage;

  /// Pushes Fishing Spot Statistics as a normal [MaterialPageRoute].
  static Future<void> open(
    BuildContext context, {
    required FishingSpot fishingSpot,
    required FishingSpotStatisticsRepository repository,
    required CatchRepository catchRepository,
    required CatchPhotoRepository catchPhotoRepository,
    required LureCatalogRepository lureCatalogRepository,
    required PersonalTackleBoxRepository personalTackleBoxRepository,
    required TackleBoxPhotoStorage personalTackleBoxPhotoStorage,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FishingSpotStatisticsPage(
          fishingSpot: fishingSpot,
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
  State<FishingSpotStatisticsPage> createState() =>
      _FishingSpotStatisticsPageState();
}

class _FishingSpotStatisticsPageState extends State<FishingSpotStatisticsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  FishingSpotStatisticsSummary? _summary;

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
      final summary = await widget.repository.getFishingSpotStatistics(
        widget.fishingSpot.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Failed to load fishing spot statistics: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Tilastojen lataaminen epäonnistui.';
        _isLoading = false;
      });
    }
  }

  /// Reuses `FishingSpotDetailsBottomSheet`'s established convention —
  /// `CatchDetailsPage.open()` has no typed changed-result, so this page
  /// unconditionally reloads after the awaited call returns rather than
  /// trying to distinguish an edit from a delete from nothing happening.
  /// Applied from the start here, not retrofitted — see TD-022 Key Design
  /// Decision 9 (which cites TD-021's own equivalent fix).
  Future<void> _openCatchDetails(Catch catchModel) async {
    await CatchDetailsPage.open(
      context,
      fishingSpot: widget.fishingSpot,
      catchModel: catchModel,
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
      appBar: AppBar(title: Text(widget.fishingSpot.name)),
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
    final recordCatch = summary.recordCatch;

    return ListView(
      key: const Key('fishingSpotStatisticsList'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Same equal-height, side-by-side layout already established for
        // the Catches tab's own two summary cards (TD-020 §5) — reused
        // here rather than StatisticsSummaryCard's primary/secondaryValue
        // shape, since total catches and Last Catch Date are two
        // independent facts, not a primary/elaboration pair (TD-022 Key
        // Design Decision 10).
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
        Text('Ennätyssaalis', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        if (recordCatch == null)
          const Text('Ei vielä ennätyssaalista.')
        else
          FishingSpotRecordCatchCard(
            catchModel: recordCatch,
            catchPhotoRepository: widget.catchPhotoRepository,
            onTap: () => unawaited(_openCatchDetails(recordCatch)),
          ),
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
            ),
        const SizedBox(height: AppSpacing.xxl),
        Text('Kaikki saaliit', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (summary.catches.isEmpty)
          const Text('Ei vielä saaliita.')
        else
          for (final catchModel in summary.catches)
            CatchListItem(
              key: ValueKey(catchModel.id),
              catchModel: catchModel,
              catchPhotoRepository: widget.catchPhotoRepository,
              onTap: () => unawaited(_openCatchDetails(catchModel)),
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
