import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/data/catch_search_repository.dart';
import 'package:fishing_app/features/catches/domain/catch_filter_options.dart';
import 'package:fishing_app/features/catches/domain/catch_search_criteria.dart';
import 'package:fishing_app/features/catches/domain/catch_search_result.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_details_page.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_filter_bottom_sheet.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_list_item.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_repository.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';

/// Sentinel used by [_CatchSearchState.copyWith] to distinguish "leave
/// errorMessage unchanged" from "explicitly clear it to null".
const Object _unset = Object();

/// The global catch-browsing/search page (MFS-025): an always-visible,
/// debounced text search across species/water body/fishing spot/lure, plus
/// a single-select-per-category filter bottom sheet (water body, species,
/// lure, date range). Reached from a new `MapScreen` AppBar entry, the same
/// established "temporary entry point, pushes a full-screen page" pattern
/// already used for Lure Tools and Statistics. See TD-025.
///
/// A plain [StatefulWidget] receiving every repository via a required
/// constructor parameter — constructed and pushed the same way every other
/// feature screen in this app is (manual dependency construction, no
/// Riverpod, no generic search framework).
class CatchSearchPage extends StatefulWidget {
  const CatchSearchPage({
    super.key,
    required this.catchSearchRepository,
    required this.catchRepository,
    required this.catchPhotoRepository,
    required this.lureCatalogRepository,
    required this.personalTackleBoxRepository,
    required this.personalTackleBoxPhotoStorage,
    required this.waterBodyRepository,
  });

  final CatchSearchRepository catchSearchRepository;
  final CatchRepository catchRepository;
  final CatchPhotoRepository catchPhotoRepository;
  final LureCatalogRepository lureCatalogRepository;
  final PersonalTackleBoxRepository personalTackleBoxRepository;
  final TackleBoxPhotoStorage personalTackleBoxPhotoStorage;
  final WaterBodyRepository waterBodyRepository;

  @override
  State<CatchSearchPage> createState() => _CatchSearchPageState();
}

/// One immutable snapshot of this page's own state — raw text, the last
/// criteria actually queried, loaded filter options, loading/error state,
/// and the current result set. A single, page-specific, non-generic class
/// (not a sealed hierarchy, not a reusable search-state framework), held as
/// one field on [_CatchSearchPageState] and replaced wholesale via
/// [copyWith]/`setState`. See TD-025 Key Design Decision 8.
@immutable
class _CatchSearchState {
  const _CatchSearchState({
    required this.rawQuery,
    required this.effectiveCriteria,
    required this.filterOptions,
    required this.isLoading,
    required this.errorMessage,
    required this.results,
  });

  const _CatchSearchState.initial()
    : rawQuery = '',
      effectiveCriteria = CatchSearchCriteria.empty,
      filterOptions = null,
      isLoading = true,
      errorMessage = null,
      results = null;

  final String rawQuery;
  final CatchSearchCriteria effectiveCriteria;
  final CatchFilterOptions? filterOptions;
  final bool isLoading;
  final String? errorMessage;
  final List<CatchSearchResult>? results;

  bool get hasActiveFilters => effectiveCriteria.hasActiveFilters;

  _CatchSearchState copyWith({
    String? rawQuery,
    CatchSearchCriteria? effectiveCriteria,
    CatchFilterOptions? filterOptions,
    bool? isLoading,
    Object? errorMessage = _unset,
    List<CatchSearchResult>? results,
  }) {
    return _CatchSearchState(
      rawQuery: rawQuery ?? this.rawQuery,
      effectiveCriteria: effectiveCriteria ?? this.effectiveCriteria,
      filterOptions: filterOptions ?? this.filterOptions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      results: results ?? this.results,
    );
  }
}

class _CatchSearchPageState extends State<CatchSearchPage> {
  static const _debounceDuration = Duration(milliseconds: 280);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  /// Incremented at the start of every [_executeSearch] call — mirrors
  /// `LureCatalogListPage`'s established stale-response guard, so a slow
  /// query for an earlier keystroke cannot overwrite a faster query for a
  /// later one.
  int _requestId = 0;

  _CatchSearchState _state = const _CatchSearchState.initial();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    unawaited(_executeSearch(CatchSearchCriteria.empty));
  }

  @override
  void dispose() {
    // Cancelled before disposing the controller/focus node: a pending timer
    // firing after dispose would otherwise call setState on an unmounted
    // State. The _requestId guard inside _executeSearch is a second,
    // independent safety net for the async gap between dispatch and
    // completion, not a substitute for cancelling the timer itself.
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    final text = _searchController.text;
    setState(() => _state = _state.copyWith(rawQuery: text));
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      unawaited(
        _executeSearch(_state.effectiveCriteria.copyWith(query: text.trim())),
      );
    });
  }

  /// FR-20: clears the raw and effective query, immediately refreshes
  /// results using whatever filters remain active, and removes focus —
  /// without clearing those filters. Temporarily detaches the controller's
  /// own listener around `.clear()` so this refresh happens immediately
  /// rather than being delayed through the debounce path a normal text
  /// change would schedule.
  void _onClearPressed() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.clear();
    _searchController.addListener(_onSearchTextChanged);
    _searchFocusNode.unfocus();

    final clearedCriteria = _state.effectiveCriteria.copyWith(query: '');
    setState(() => _state = _state.copyWith(rawQuery: ''));
    unawaited(_executeSearch(clearedCriteria));
  }

  /// Clears both the search text and every active filter, restoring the
  /// full catch list — the no-match state's own "clear everything" action.
  void _clearSearchAndFilters() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.clear();
    _searchController.addListener(_onSearchTextChanged);
    _searchFocusNode.unfocus();

    setState(() => _state = _state.copyWith(rawQuery: ''));
    unawaited(_executeSearch(CatchSearchCriteria.empty));
  }

  Future<void> _executeSearch(CatchSearchCriteria criteria) async {
    final requestId = ++_requestId;
    setState(
      () => _state = _state.copyWith(isLoading: true, errorMessage: null),
    );

    try {
      final results = await widget.catchSearchRepository.search(criteria);
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(
        () => _state = _state.copyWith(
          effectiveCriteria: criteria,
          results: results,
          isLoading: false,
        ),
      );
    } catch (error) {
      debugPrint('Failed to search catches: $error');
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(
        () => _state = _state.copyWith(
          isLoading: false,
          errorMessage: 'Hakutulosten lataaminen epäonnistui.',
        ),
      );
    }
  }

  Future<void> _openFilterSheet() async {
    var options = _state.filterOptions;
    if (options == null) {
      try {
        options = await widget.catchSearchRepository.getFilterOptions();
      } catch (error) {
        debugPrint('Failed to load filter options: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Suodattimien lataaminen epäonnistui.'),
            ),
          );
        }
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() => _state = _state.copyWith(filterOptions: options));
    }

    if (!mounted) {
      return;
    }
    final updated = await CatchFilterBottomSheet.show(
      context,
      filterOptions: options,
      initialCriteria: _state.effectiveCriteria,
    );
    if (updated == null || !mounted) {
      return;
    }
    unawaited(_executeSearch(updated));
  }

  /// Following the established "just reload, don't branch on the result"
  /// convention already used by every existing `CatchDetailsPage.open()`
  /// caller — the search field and every active filter are untouched by
  /// this round trip (`_state` is never disposed while the page underneath
  /// stays mounted), only the results are re-queried, so a create/edit/
  /// delete made from Catch Details is reflected (MFS-025 FR-15) while the
  /// angler's search/filter context is preserved exactly (FR-12).
  Future<void> _openCatchDetails(CatchSearchResult result) async {
    await CatchDetailsPage.open(
      context,
      fishingSpot: result.fishingSpot,
      catchModel: result.catchModel,
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
    unawaited(_executeSearch(_state.effectiveCriteria));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saaliit')),
      body: Column(
        children: [
          _buildSearchAndFilterRow(context),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('catchSearchField'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Hae kalalajia, vesistöä tai viehettä…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _state.rawQuery.isNotEmpty
                    ? IconButton(
                        key: const Key('clearSearchButton'),
                        tooltip: 'Tyhjennä haku',
                        icon: const Icon(Icons.clear),
                        onPressed: _onClearPressed,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            label: _state.hasActiveFilters
                ? 'Suodattimet, aktiivisia suodattimia'
                : 'Suodattimet',
            child: Badge(
              isLabelVisible: _state.hasActiveFilters,
              child: IconButton(
                key: const Key('openFilterSheetButton'),
                tooltip: 'Suodattimet',
                icon: const Icon(Icons.filter_list),
                onPressed: () => unawaited(_openFilterSheet()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_state.isLoading && _state.results == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final errorMessage = _state.errorMessage;
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              errorMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () =>
                  unawaited(_executeSearch(_state.effectiveCriteria)),
              child: const Text('Yritä uudelleen'),
            ),
          ],
        ),
      );
    }

    final results = _state.results ?? const [];

    if (results.isEmpty && _state.effectiveCriteria.isEmpty) {
      return const Center(child: Text('Ei vielä saaliita.'));
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Hakuehdoilla ei löytynyt saaliita.'),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('clearSearchAndFiltersButton'),
              onPressed: _clearSearchAndFilters,
              child: const Text('Tyhjennä haku ja suodattimet'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: const Key('catchSearchResultsList'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        final lure = result.lure;
        return CatchListItem(
          key: ValueKey('catchSearchResult-${result.catchModel.id}'),
          catchModel: result.catchModel,
          catchPhotoRepository: widget.catchPhotoRepository,
          waterBodyName: result.waterBody.name,
          fishingSpotName: result.fishingSpot.name,
          lureLabel: lure == null
              ? null
              : '${lure.manufacturer} ${lure.modelName}',
          onTap: () => unawaited(_openCatchDetails(result)),
        );
      },
    );
  }
}
