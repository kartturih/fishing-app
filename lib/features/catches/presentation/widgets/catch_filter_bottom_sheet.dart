import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catches/domain/catch_filter_options.dart';
import 'package:fishing_app/features/catches/domain/catch_search_criteria.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/widgets/add_catch_bottom_sheet.dart'
    show formatCatchDate;

/// Lets the angler narrow the global catch-browsing/search surface
/// (MFS-025) by water body, fish species, lure, and/or date range — each
/// category single-select in this MVP (MFS-025's own decision). Follows the
/// same Material 3 bottom-sheet convention already established by
/// `WaterBodySelectionBottomSheet`. See TD-025 §8/§10.
class CatchFilterBottomSheet extends StatefulWidget {
  const CatchFilterBottomSheet({
    super.key,
    required this.filterOptions,
    required this.initialCriteria,
  });

  final CatchFilterOptions filterOptions;
  final CatchSearchCriteria initialCriteria;

  /// Shows the sheet and resolves to an updated [CatchSearchCriteria] when
  /// the angler applies or clears filters, or `null` if dismissed without
  /// either (e.g. tapping outside).
  static Future<CatchSearchCriteria?> show(
    BuildContext context, {
    required CatchFilterOptions filterOptions,
    required CatchSearchCriteria initialCriteria,
  }) {
    return showModalBottomSheet<CatchSearchCriteria>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => CatchFilterBottomSheet(
        filterOptions: filterOptions,
        initialCriteria: initialCriteria,
      ),
    );
  }

  @override
  State<CatchFilterBottomSheet> createState() => _CatchFilterBottomSheetState();
}

class _CatchFilterBottomSheetState extends State<CatchFilterBottomSheet> {
  late String? _waterBodyId = widget.initialCriteria.waterBodyId;
  late FishSpecies? _species = widget.initialCriteria.species;
  late String? _lureVariantId = widget.initialCriteria.lureVariantId;
  late DateTime? _dateFrom = widget.initialCriteria.dateFrom;
  late DateTime? _dateTo = widget.initialCriteria.dateTo;

  String get _dateRangeLabel {
    final from = _dateFrom;
    final to = _dateTo;
    if (from != null && to != null) {
      return '${formatCatchDate(from)} – ${formatCatchDate(to)}';
    }
    if (from != null) {
      return 'Alkaen ${formatCatchDate(from)}';
    }
    if (to != null) {
      return 'Päättyen ${formatCatchDate(to)}';
    }
    return 'Ei aikaväliä';
  }

  Future<void> _pickDateRange() async {
    final from = _dateFrom;
    final to = _dateTo;
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: (from != null && to != null)
          ? DateTimeRange(start: from, end: to)
          : null,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _dateFrom = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      _dateTo = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
        999,
      );
    });
  }

  void _clearDateRange() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
  }

  void _applyAndClose() {
    Navigator.of(context).pop(
      widget.initialCriteria.copyWith(
        waterBodyId: _waterBodyId,
        species: _species,
        lureVariantId: _lureVariantId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      ),
    );
  }

  void _clearAllAndClose() {
    Navigator.of(context).pop(widget.initialCriteria.clearFilters());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Suodattimet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildWaterBodySection(context),
              _buildSpeciesSection(context),
              _buildLureSection(context),
              _buildDateRangeSection(context),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('clearFiltersButton'),
                      onPressed: _clearAllAndClose,
                      child: const Text('Tyhjennä suodattimet'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      key: const Key('applyFiltersButton'),
                      onPressed: _applyAndClose,
                      child: const Text('Käytä'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterBodySection(BuildContext context) {
    if (widget.filterOptions.waterBodies.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Vesistö', style: Theme.of(context).textTheme.labelLarge),
          RadioGroup<String?>(
            groupValue: _waterBodyId,
            onChanged: (value) => setState(() => _waterBodyId = value),
            child: Column(
              children: [
                const RadioListTile<String?>(
                  key: Key('waterBodyFilterOption-none'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('Ei valintaa'),
                  value: null,
                ),
                for (final waterBody in widget.filterOptions.waterBodies)
                  RadioListTile<String?>(
                    key: ValueKey('waterBodyFilterOption-${waterBody.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(waterBody.name),
                    value: waterBody.id,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesSection(BuildContext context) {
    if (widget.filterOptions.species.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Kalalaji', style: Theme.of(context).textTheme.labelLarge),
          RadioGroup<FishSpecies?>(
            groupValue: _species,
            onChanged: (value) => setState(() => _species = value),
            child: Column(
              children: [
                const RadioListTile<FishSpecies?>(
                  key: Key('speciesFilterOption-none'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('Ei valintaa'),
                  value: null,
                ),
                for (final species in widget.filterOptions.species)
                  RadioListTile<FishSpecies?>(
                    key: ValueKey('speciesFilterOption-${species.name}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(species.finnishName),
                    value: species,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLureSection(BuildContext context) {
    if (widget.filterOptions.lures.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Viehe', style: Theme.of(context).textTheme.labelLarge),
          RadioGroup<String?>(
            groupValue: _lureVariantId,
            onChanged: (value) => setState(() => _lureVariantId = value),
            child: Column(
              children: [
                const RadioListTile<String?>(
                  key: Key('lureFilterOption-none'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('Ei valintaa'),
                  value: null,
                ),
                for (final lure in widget.filterOptions.lures)
                  RadioListTile<String?>(
                    key: ValueKey('lureFilterOption-${lure.variant.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text('${lure.manufacturer} ${lure.modelName}'),
                    value: lure.variant.id,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ajanjakso', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('dateRangeFilterButton'),
                onPressed: () => unawaited(_pickDateRange()),
                child: Text(_dateRangeLabel),
              ),
            ),
            if (_dateFrom != null || _dateTo != null)
              IconButton(
                key: const Key('clearDateRangeButton'),
                tooltip: 'Tyhjennä ajanjakso',
                icon: const Icon(Icons.clear),
                onPressed: _clearDateRange,
              ),
          ],
        ),
      ],
    );
  }
}
