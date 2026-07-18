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
  const LureCatalogListPage({super.key, required this.repository});

  final LureCatalogRepository repository;

  @override
  State<LureCatalogListPage> createState() => _LureCatalogListPageState();
}

class _LureCatalogListPageState extends State<LureCatalogListPage> {
  final TextEditingController _searchController = TextEditingController();

  String? _manufacturerFilter;
  String? _lureTypeFilter;
  List<String> _manufacturers = [];
  List<String> _lureTypes = [];
  bool _isLoading = true;
  String? _loadError;
  List<LureCatalogEntry> _entries = [];

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

      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _manufacturers = manufacturers;
        _lureTypes = lureTypes;
        _entries = entries;
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

  Future<void> _openDetails(LureCatalogEntry entry) {
    return LureDetailsPage.open(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viehekatalogi')),
      body: SafeArea(
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
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
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

    if (_entries.isEmpty) {
      return const Center(child: Text('Ei tuloksia hakuehdoilla.'));
    }

    return ListView.builder(
      key: const Key('lureCatalogList'),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return LureCatalogListItem(
          key: ValueKey(entry.id),
          entry: entry,
          onTap: () => _openDetails(entry),
        );
      },
    );
  }
}
