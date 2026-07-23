import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_details_page.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_list_item.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_repository.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/statistics/data/species_statistics_repository.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_entry.dart';
import 'package:fishing_app/features/statistics/domain/species_statistics_summary.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/record_catch_card.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/statistics_summary_card.dart';

/// A single species' statistics: total catches, a Record Catch section, and
/// a full Catch List — reached by tapping a row in MFS-020's Species List.
/// Pushed as a normal full-screen page (`MaterialPageRoute`), mirroring
/// `CatchDetailsPage.open()`'s exact precedent, not a third Statistics tab.
/// See MFS-021 / TD-021 Key Design Decision 10.
class SpeciesStatisticsPage extends StatefulWidget {
  const SpeciesStatisticsPage({
    super.key,
    required this.species,
    required this.repository,
    required this.catchRepository,
    required this.catchPhotoRepository,
    required this.lureCatalogRepository,
    required this.personalTackleBoxRepository,
    required this.personalTackleBoxPhotoStorage,
    required this.waterBodyRepository,
  });

  final FishSpecies species;
  final SpeciesStatisticsRepository repository;

  /// Forwarded to `CatchDetailsPage.open()` when the Record Catch card or a
  /// Catch List entry is tapped — this page has no other use for them.
  final CatchRepository catchRepository;
  final CatchPhotoRepository catchPhotoRepository;
  final LureCatalogRepository lureCatalogRepository;
  final PersonalTackleBoxRepository personalTackleBoxRepository;
  final TackleBoxPhotoStorage personalTackleBoxPhotoStorage;
  final WaterBodyRepository waterBodyRepository;

  /// Pushes Species Statistics as a normal [MaterialPageRoute].
  static Future<void> open(
    BuildContext context, {
    required FishSpecies species,
    required SpeciesStatisticsRepository repository,
    required CatchRepository catchRepository,
    required CatchPhotoRepository catchPhotoRepository,
    required LureCatalogRepository lureCatalogRepository,
    required PersonalTackleBoxRepository personalTackleBoxRepository,
    required TackleBoxPhotoStorage personalTackleBoxPhotoStorage,
    required WaterBodyRepository waterBodyRepository,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SpeciesStatisticsPage(
          species: species,
          repository: repository,
          catchRepository: catchRepository,
          catchPhotoRepository: catchPhotoRepository,
          lureCatalogRepository: lureCatalogRepository,
          personalTackleBoxRepository: personalTackleBoxRepository,
          personalTackleBoxPhotoStorage: personalTackleBoxPhotoStorage,
          waterBodyRepository: waterBodyRepository,
        ),
      ),
    );
  }

  @override
  State<SpeciesStatisticsPage> createState() => _SpeciesStatisticsPageState();
}

class _SpeciesStatisticsPageState extends State<SpeciesStatisticsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  SpeciesStatisticsSummary? _summary;

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
      final summary = await widget.repository.getSpeciesStatistics(
        widget.species,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Failed to load species statistics: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Tilastojen lataaminen epäonnistui.';
        _isLoading = false;
      });
    }
  }

  /// `CatchDetailsPage.open()` has no typed changed-result convention (it
  /// returns a bare `Future<void>` from `Navigator.push`) — Catch Details
  /// may have edited or deleted the catch, or done nothing, and this page
  /// cannot tell which from the return value alone. The established
  /// pattern for exactly this situation, already shipped in
  /// `FishingSpotDetailsBottomSheet._openCatchDetails`, is to
  /// unconditionally reload after the awaited call returns rather than
  /// trying to distinguish cases. Reusing `_load()` here (the same method
  /// `initState` already calls) means Species Statistics is never left
  /// showing a stale total, Record Catch, or Catch List — covering both
  /// the Record Catch card and every Catch List entry, since both call
  /// this same method. See MFS-021 FR-10 / TD-021 Key Design Decision 10.
  Future<void> _openCatchDetails(SpeciesCatchEntry entry) async {
    await CatchDetailsPage.open(
      context,
      fishingSpot: entry.fishingSpot,
      catchModel: entry.catchModel,
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.species.finnishName)),
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
      key: const Key('speciesStatisticsList'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        StatisticsSummaryCard(
          title: 'Saaliita yhteensä',
          value: '${summary.totalCatches}',
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Ennätyssaalis', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        if (recordCatch == null)
          const Text('Ei vielä ennätyssaalista.')
        else
          RecordCatchCard(
            entry: recordCatch,
            catchPhotoRepository: widget.catchPhotoRepository,
            onTap: () => unawaited(_openCatchDetails(recordCatch)),
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
}
