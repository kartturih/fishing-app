import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_catalog_filter_bar.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_catalog_model_list_item.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_model_details_page.dart';

/// Lure Catalog browse/search/filter entry screen.
///
/// A plain [StatefulWidget] receiving its [LureCatalogRepository] via a
/// required constructor parameter — constructed and pushed the same way
/// every other feature screen in this app is (manual dependency
/// construction, no Riverpod). See MFS-015 / TD-015.
class LureCatalogListPage extends StatefulWidget {
  const LureCatalogListPage({
    super.key,
    required this.repository,
    this.detailsActionsBuilder,
    this.loadOwnedLureVariantIds,
    this.embedded = false,
  });

  final LureCatalogRepository repository;

  /// Generic, optional per-variant extension point forwarded verbatim to
  /// every `LureModelDetailsPage` this screen opens — see
  /// `LureModelDetailsPage.variantActionBuilder`. This file still never
  /// imports anything from `personal_tackle_box`.
  final Widget Function(
    BuildContext context,
    LureCatalogEntry variantEntry, {
    required bool initialIsOwned,
  })?
  detailsActionsBuilder;

  /// Optional, generic hook for showing which variants are already owned
  /// (an "owned" badge per row, and a "hide owned" filter). Returns the set
  /// of owned `LureVariant.id`s. Like [detailsActionsBuilder], this is a
  /// plain data callback — this file never imports anything from
  /// `personal_tackle_box`; the caller (currently `MapScreen`) supplies it.
  /// When omitted, no ownership badge or filter is shown, exactly like
  /// before this option existed.
  final Future<Set<String>> Function()? loadOwnedLureVariantIds;

  /// When `true`, this widget renders only its content — no `Scaffold`, no
  /// `AppBar` — so a host (e.g. a tabbed shell) can supply its own chrome
  /// around it. Defaults to `false`, preserving this page's standalone,
  /// directly-pushable behavior unchanged.
  final bool embedded;

  @override
  State<LureCatalogListPage> createState() => _LureCatalogListPageState();
}

class _LureCatalogListPageState extends State<LureCatalogListPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();

  String? _manufacturerFilter;
  String? _lureTypeFilter;
  bool _hideOwned = false;
  List<String> _manufacturers = [];
  List<String> _lureTypes = [];
  bool _isLoading = true;
  String? _loadError;
  List<LureCatalogEntry> _entries = [];
  Set<String> _ownedVariantIds = {};

  /// Incremented at the start of every [_load]/[_refresh] call. A completing
  /// request only applies its result if it is still the most recent request,
  /// so an older request that resolves after a newer one cannot overwrite
  /// the newer result with stale data.
  int _requestId = 0;

  /// Keeps this page's search/filter/scroll state alive when it is the
  /// non-visible tab inside `LureToolsPage`'s `TabBarView` — without this,
  /// `TabBarView` may dispose and recreate this `State` on switching away
  /// and back, silently resetting every field above. See TD-018's
  /// Implementation Notes.
  @override
  bool get wantKeepAlive => true;

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
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      await widget.repository.ensureSeeded();
      final manufacturers = await widget.repository.getDistinctManufacturers();
      final lureTypes = await widget.repository.getDistinctLureTypes();
      final entries = await widget.repository.browse();
      final ownedVariantIds = await _loadOwnedVariantIds();

      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _manufacturers = manufacturers;
        _lureTypes = lureTypes;
        _entries = entries;
        _ownedVariantIds = ownedVariantIds;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Failed to load lure catalog: $error');
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _loadError = 'Viehekatalogin lataaminen epäonnistui.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final requestId = ++_requestId;
    try {
      final entries = await widget.repository.browse(
        searchText: _searchController.text,
        manufacturer: _manufacturerFilter,
        lureType: _lureTypeFilter,
      );
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _entries = entries;
        _loadError = null;
      });
    } catch (error) {
      debugPrint('Failed to search lure catalog: $error');
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() => _loadError = 'Viehekatalogin lataaminen epäonnistui.');
    }
  }

  Future<Set<String>> _loadOwnedVariantIds() async {
    final loadOwnedLureVariantIds = widget.loadOwnedLureVariantIds;
    if (loadOwnedLureVariantIds == null) {
      return const {};
    }
    try {
      return await loadOwnedLureVariantIds();
    } catch (error) {
      debugPrint('Failed to load owned lure variant ids: $error');
      return const {};
    }
  }

  Future<void> _refreshOwnedVariantIds() async {
    final ownedVariantIds = await _loadOwnedVariantIds();
    if (!mounted) {
      return;
    }
    setState(() => _ownedVariantIds = ownedVariantIds);
  }

  void _onHideOwnedChanged(bool value) {
    setState(() => _hideOwned = value);
  }

  void _onSearchChanged(String value) {
    unawaited(_refresh());
  }

  void _onManufacturerChanged(String? value) {
    setState(() => _manufacturerFilter = value);
    unawaited(_refresh());
  }

  void _onLureTypeChanged(String? value) {
    setState(() => _lureTypeFilter = value);
    unawaited(_refresh());
  }

  /// Opens `LureModelDetailsPage` for [group]'s model.
  ///
  /// Queries `getVariantsForModel` for the model's complete, unfiltered
  /// variant set rather than reusing [group.variants] — a search or filter
  /// active on this list may have narrowed [group.variants] to only the
  /// variant(s) that matched, and MFS-018 FR-6 requires every non-retired
  /// variant to be shown regardless. See TD-018's Implementation Notes.
  Future<void> _openModelDetails(_LureModelGroup group) async {
    final List<LureVariant> variants;
    try {
      variants = await widget.repository.getVariantsForModel(
        group.modelEntry.variant.lureModelId,
      );
    } catch (error) {
      debugPrint('Failed to load lure model variants: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vieheen tietojen lataaminen epäonnistui.'),
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }

    await LureModelDetailsPage.open(
      context,
      modelEntry: group.modelEntry,
      variants: variants,
      ownedVariantIds: _ownedVariantIds,
      variantActionBuilder: widget.detailsActionsBuilder,
    );
    // The user may have added a variant of this model to their tackle box
    // while viewing details; refresh so the badge/filter reflect it.
    if (widget.loadOwnedLureVariantIds != null) {
      unawaited(_refreshOwnedVariantIds());
    }
  }

  bool _isFullyOwned(_LureModelGroup group) =>
      group.variants.every((variant) => _ownedVariantIds.contains(variant.id));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LureCatalogFilterBar(
              searchController: _searchController,
              onSearchChanged: _onSearchChanged,
              manufacturers: _manufacturers,
              selectedManufacturer: _manufacturerFilter,
              onManufacturerChanged: _onManufacturerChanged,
              lureTypes: _lureTypes,
              selectedLureType: _lureTypeFilter,
              onLureTypeChanged: _onLureTypeChanged,
              hideOwned: widget.loadOwnedLureVariantIds == null
                  ? null
                  : _hideOwned,
              onHideOwnedChanged: widget.loadOwnedLureVariantIds == null
                  ? null
                  : _onHideOwnedChanged,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Viehekatalogi')),
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

    final groups = _groupByModel(_entries);
    final visibleGroups = _hideOwned
        ? groups.where((group) => !_isFullyOwned(group)).toList()
        : groups;

    if (visibleGroups.isEmpty) {
      return const Center(child: Text('Ei tuloksia hakuehdoilla.'));
    }

    return ListView.builder(
      key: const Key('lureCatalogList'),
      itemCount: visibleGroups.length,
      itemBuilder: (context, index) {
        final group = visibleGroups[index];
        return LureCatalogModelListItem(
          key: ValueKey(group.modelEntry.variant.lureModelId),
          modelEntry: group.modelEntry,
          fullyOwned: _isFullyOwned(group),
          onTap: () => _openModelDetails(group),
        );
      },
    );
  }
}

/// One lure model's browse-list summary plus all of its (already-loaded,
/// non-retired) variants. Grouping is keyed by `LureVariant.lureModelId` —
/// the actual foreign key — not by a `(manufacturer, modelName)` text tuple,
/// so it cannot be confused by two different models that happen to share
/// display text. See TD-018 Key Design Decision 1.
final class _LureModelGroup {
  _LureModelGroup(this.modelEntry) : variants = [modelEntry.variant];

  final LureCatalogEntry modelEntry;
  final List<LureVariant> variants;
}

/// A single linear pass over `browse()`'s already-sorted result (manufacturer
/// → model, case-insensitive → variant id), grouping adjacent rows into one
/// summary per model. Every model-level field (`manufacturer`, `modelName`,
/// `productFamily`, `lureType`, `modelDefaultImageReference`) is identical
/// across every entry in a group — they all resolve from the same
/// `LureModel` row — so the first entry encountered for a given model
/// supplies all of them; no merging logic is needed. Mirrors
/// `PersonalTackleBoxPage._buildRows`'s existing boundary-detection pattern
/// (TD-016 Key Design Decision 3). See TD-018 §2.
List<_LureModelGroup> _groupByModel(List<LureCatalogEntry> entries) {
  final groups = <_LureModelGroup>[];
  final groupsByModelId = <String, _LureModelGroup>{};

  for (final entry in entries) {
    final modelId = entry.variant.lureModelId;
    final existing = groupsByModelId[modelId];
    if (existing == null) {
      final group = _LureModelGroup(entry);
      groupsByModelId[modelId] = group;
      groups.add(group);
    } else {
      existing.variants.add(entry.variant);
    }
  }
  return groups;
}
