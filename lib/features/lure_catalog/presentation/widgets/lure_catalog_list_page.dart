import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_catalog_filter_bar.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_catalog_list_item.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_details_page.dart';

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

  /// Forwarded verbatim to every `LureDetailsPage` this screen opens. See
  /// `LureDetailsPage.actionsBuilder` — this file still never imports
  /// anything from `personal_tackle_box`.
  final List<Widget> Function(BuildContext context, LureCatalogEntry entry)?
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

class _LureCatalogListPageState extends State<LureCatalogListPage> {
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

  Future<void> _openDetails(LureCatalogEntry entry) async {
    await LureDetailsPage.open(
      context,
      entry,
      actionsBuilder: widget.detailsActionsBuilder,
    );
    // The user may have added this (or another) variant to their tackle box
    // while viewing details; refresh so the badge/filter reflect it.
    if (widget.loadOwnedLureVariantIds != null) {
      unawaited(_refreshOwnedVariantIds());
    }
  }

  @override
  Widget build(BuildContext context) {
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

    final visibleEntries = _hideOwned
        ? _entries
              .where((entry) => !_ownedVariantIds.contains(entry.id))
              .toList()
        : _entries;

    if (visibleEntries.isEmpty) {
      return const Center(child: Text('Ei tuloksia hakuehdoilla.'));
    }

    return ListView.builder(
      key: const Key('lureCatalogList'),
      itemCount: visibleEntries.length,
      itemBuilder: (context, index) {
        final entry = visibleEntries[index];
        return LureCatalogListItem(
          key: ValueKey(entry.id),
          entry: entry,
          isOwned: _ownedVariantIds.contains(entry.id),
          onTap: () => _openDetails(entry),
        );
      },
    );
  }
}
