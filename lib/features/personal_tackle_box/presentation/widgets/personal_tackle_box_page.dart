import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_image.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/tackle_box_item.dart';
import 'package:fishing_app/features/personal_tackle_box/presentation/widgets/owned_entry_detail_page.dart';
import 'package:fishing_app/features/personal_tackle_box/presentation/widgets/personal_tackle_box_filter_bar.dart';

/// Personal Tackle Box browsing screen: owned entries grouped by
/// manufacturer, then model — never a flat one-row-per-variant list.
///
/// A plain [StatefulWidget] receiving its [PersonalTackleBoxRepository]/
/// [TackleBoxPhotoStorage] via required constructor parameters — constructed
/// and pushed the same way every other feature screen in this app is
/// (manual dependency construction, no Riverpod). See MFS-016 / TD-016.
///
/// Search and manufacturer/model filtering operate entirely on the already-
/// loaded [_items] list, in memory — no repository query changes. A user's
/// tackle box is expected to remain small (MFS-016), so this is sufficient
/// and avoids adding search/filter methods to `PersonalTackleBoxRepository`.
class PersonalTackleBoxPage extends StatefulWidget {
  const PersonalTackleBoxPage({
    super.key,
    required this.repository,
    required this.photoStorage,
    this.embedded = false,
  });

  final PersonalTackleBoxRepository repository;
  final TackleBoxPhotoStorage photoStorage;

  /// When `true`, this widget renders only its content — no `Scaffold`, no
  /// `AppBar` — so a host (e.g. a tabbed shell) can supply its own chrome
  /// around it. Defaults to `false`, preserving this page's standalone,
  /// directly-pushable behavior unchanged.
  final bool embedded;

  @override
  State<PersonalTackleBoxPage> createState() => _PersonalTackleBoxPageState();
}

class _PersonalTackleBoxPageState extends State<PersonalTackleBoxPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _loadError;
  List<TackleBoxItem> _items = [];
  String? _manufacturerFilter;
  String? _lureTypeFilter;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final items = await widget.repository.getAll();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Failed to load personal tackle box: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = 'Vieherasian lataaminen epäonnistui.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openDetails(TackleBoxItem item) async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => OwnedEntryDetailPage(
          item: item,
          repository: widget.repository,
          photoStorage: widget.photoStorage,
        ),
      ),
    );
    if (removed == true) {
      unawaited(_load());
    }
  }

  /// Manufacturers among owned entries, for the filter dropdown.
  List<String> get _manufacturerOptions {
    final options =
        _items.map((item) => item.catalogEntry.manufacturer).toSet().toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return options;
  }

  /// Lure types among owned entries, for the filter dropdown. Independent
  /// of [_manufacturerFilter] — a type spans manufacturers, so scoping it
  /// down would only hide otherwise-valid options.
  List<String> get _lureTypeOptions {
    final options =
        _items.map((item) => item.catalogEntry.lureType).toSet().toList()
          ..sort();
    return options;
  }

  /// [_items] narrowed by the search text and manufacturer/lure-type
  /// filters. Search matches manufacturer, model, and color/variant/
  /// color-code text, case-insensitively. Model is intentionally not a
  /// filter dropdown — the search field already covers it.
  List<TackleBoxItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();

    return _items.where((item) {
      final catalogEntry = item.catalogEntry;
      if (_manufacturerFilter != null &&
          catalogEntry.manufacturer != _manufacturerFilter) {
        return false;
      }
      if (_lureTypeFilter != null && catalogEntry.lureType != _lureTypeFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final variant = catalogEntry.variant;
      final haystack = [
        catalogEntry.manufacturer,
        catalogEntry.modelName,
        variant.colorName,
        variant.variantName,
        variant.manufacturerColorCode,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {});
  }

  void _onManufacturerChanged(String? value) {
    setState(() => _manufacturerFilter = value);
  }

  void _onLureTypeChanged(String? value) {
    setState(() => _lureTypeFilter = value);
  }

  @override
  Widget build(BuildContext context) {
    final showFilters = !_isLoading && _loadError == null && _items.isNotEmpty;

    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showFilters) ...[
              PersonalTackleBoxFilterBar(
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                manufacturers: _manufacturerOptions,
                selectedManufacturer: _manufacturerFilter,
                onManufacturerChanged: _onManufacturerChanged,
                lureTypes: _lureTypeOptions,
                selectedLureType: _lureTypeFilter,
                onLureTypeChanged: _onLureTypeChanged,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Oma vieherasia')),
      body: content,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final loadError = _loadError;
    if (loadError != null) {
      return Center(
        child: Text(
          loadError,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'Et ole vielä lisännyt viehteitä vieherasiaan. '
          'Voit lisätä viehteitä viehekatalogista.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final filteredItems = _filteredItems;
    if (filteredItems.isEmpty) {
      return const Center(child: Text('Ei tuloksia hakuehdoilla.'));
    }

    final rows = _buildRows(filteredItems);
    return ListView.builder(
      key: const Key('personalTackleBoxList'),
      itemCount: rows.length,
      itemBuilder: (context, index) => _buildRow(context, rows[index]),
    );
  }

  Widget _buildRow(BuildContext context, _TackleBoxListRow row) {
    return switch (row) {
      _ManufacturerHeaderRow(:final manufacturer, :final isFirst) => Padding(
        padding: EdgeInsets.only(
          top: isFirst ? 0 : AppSpacing.lg,
          bottom: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isFirst) const Divider(height: AppSpacing.lg),
            Text(
              manufacturer,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      _ModelHeaderRow(:final modelName) => Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.xs,
        ),
        child: Text(
          modelName,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      _ItemRow(:final item) => Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: _TackleBoxItemRow(
          key: ValueKey(item.id),
          item: item,
          onTap: () => _openDetails(item),
        ),
      ),
    };
  }
}

sealed class _TackleBoxListRow {}

final class _ManufacturerHeaderRow extends _TackleBoxListRow {
  _ManufacturerHeaderRow(this.manufacturer, {required this.isFirst});
  final String manufacturer;
  final bool isFirst;
}

final class _ModelHeaderRow extends _TackleBoxListRow {
  _ModelHeaderRow(this.modelName);
  final String modelName;
}

final class _ItemRow extends _TackleBoxListRow {
  _ItemRow(this.item);
  final TackleBoxItem item;
}

/// Groups the already-sorted (manufacturer -> model -> variant) flat
/// repository result into a flat row list with manufacturer/model section
/// headers, detecting section boundaries in a single linear pass — no
/// persisted grouping entity and no extra query, per MFS-016's Conceptual
/// Data Model / TD-016's Key Design Decision 3.
List<_TackleBoxListRow> _buildRows(List<TackleBoxItem> items) {
  final rows = <_TackleBoxListRow>[];
  String? lastManufacturer;
  String? lastModelName;

  for (final item in items) {
    final manufacturer = item.catalogEntry.manufacturer;
    final modelName = item.catalogEntry.modelName;

    if (manufacturer != lastManufacturer) {
      rows.add(_ManufacturerHeaderRow(manufacturer, isFirst: rows.isEmpty));
      lastManufacturer = manufacturer;
      lastModelName = null;
    }
    if (modelName != lastModelName) {
      rows.add(_ModelHeaderRow(modelName));
      lastModelName = modelName;
    }
    rows.add(_ItemRow(item));
  }
  return rows;
}

class _TackleBoxItemRow extends StatelessWidget {
  const _TackleBoxItemRow({super.key, required this.item, required this.onTap});

  final TackleBoxItem item;
  final VoidCallback onTap;

  String get _distinguishingDetail {
    final variant = item.catalogEntry.variant;
    return variant.variantName ??
        variant.colorName ??
        variant.manufacturerColorCode ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    final distinguishingDetail = _distinguishingDetail;
    final semanticLabel = distinguishingDetail.isEmpty
        ? '${item.catalogEntry.manufacturer} ${item.catalogEntry.modelName}'
        : '${item.catalogEntry.manufacturer} ${item.catalogEntry.modelName} '
              '$distinguishingDetail';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Semantics(
          label: semanticLabel,
          button: true,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.xs,
            ),
            child: Row(
              children: [
                LureImage(
                  imageReference: item.catalogEntry.effectiveImageReference,
                  semanticLabel: semanticLabel,
                  size: 48,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        distinguishingDetail.isEmpty
                            ? '—'
                            : distinguishingDetail,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        lureTypeDisplayLabel(item.catalogEntry.lureType),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
