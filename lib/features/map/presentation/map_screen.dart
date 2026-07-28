import 'dart:async';
import 'dart:io';
import 'dart:math' show Point;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:path_provider/path_provider.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/core/location/location_service.dart';
import 'package:fishing_app/core/map/base_map.dart';
import 'package:fishing_app/core/map/base_map_preference_store.dart';
import 'package:fishing_app/core/map/maptiler_config.dart';
import 'package:fishing_app/core/map/maptiler_style_factory.dart';
import 'package:fishing_app/core/map/mml_config.dart';
import 'package:fishing_app/core/map/mml_vector_proxy_service.dart';
import 'package:fishing_app/core/map/style_restoration_tracker.dart';
import 'package:fishing_app/core/map/syke_bathymetry_tile_source.dart';
import 'package:fishing_app/core/map/worldwide_style_factory.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/data/storage/catch_photo_storage.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/data/catch_search_repository.dart';
import 'package:fishing_app/features/catches/presentation/widgets/add_catch_bottom_sheet.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_search_page.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/fishing_spots/presentation/widgets/add_fishing_spot_bottom_sheet.dart';
import 'package:fishing_app/features/fishing_spots/presentation/widgets/fishing_spot_details_bottom_sheet.dart';
import 'package:fishing_app/features/fishing_spots/presentation/widgets/fishing_spot_name_bottom_sheet.dart';
import 'package:fishing_app/features/fishing_spots/presentation/widgets/water_body_selection_bottom_sheet.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/map/presentation/widgets/base_map_layers_control.dart';
import 'package:fishing_app/features/map/presentation/widgets/base_map_selector_panel.dart';
import 'package:fishing_app/features/map/presentation/widgets/lure_tools_page.dart';
import 'package:fishing_app/features/map/presentation/widgets/map_attribution.dart';
import 'package:fishing_app/features/map/presentation/widgets/map_controls.dart';
import 'package:fishing_app/features/map/presentation/widgets/maptiler_attribution.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/personal_tackle_box/presentation/widgets/add_to_tackle_box_action.dart';
import 'package:fishing_app/features/statistics/data/general_catch_statistics_repository.dart';
import 'package:fishing_app/features/statistics/data/lure_statistics_repository.dart';
import 'package:fishing_app/features/statistics/data/species_statistics_repository.dart';
import 'package:fishing_app/features/statistics/data/water_body_statistics_repository.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/statistics_page.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.temporaryDirectoryProvider = getTemporaryDirectory,
    this.baseMapPreferenceStore = const BaseMapPreferenceStore(),
    this.mmlVectorProxyService,
    this.sykeBathymetryTileSource,
  });

  /// Supplies the directory MML base-map style documents are written to
  /// (see `_writeStyleFile`). Defaults to the real `path_provider` temporary
  /// directory; overridable so widget tests never need a real
  /// `path_provider` platform channel — mirroring the existing
  /// `rootDirectoryProvider` pattern already used by `CatchPhotoStorage`/
  /// `TackleBoxPhotoStorage` in this same screen.
  final Future<Directory> Function() temporaryDirectoryProvider;

  /// Persists the selected base map. Defaults to the real, `shared_preferences`-
  /// backed store; overridable (by subclassing and overriding `save`, the
  /// same "subclass the real repository and override one method" pattern
  /// already used elsewhere in this project's tests) so a test can control
  /// exactly when an in-flight persistence write completes — needed to
  /// exercise the out-of-order-completion race this class's `_persistBaseMapSelection`
  /// guards against.
  final BaseMapPreferenceStore baseMapPreferenceStore;

  /// The local, on-device loopback proxy for MML's real v21 vector base map
  /// and the bundled SYKE bathymetry overlay (TD-027 §3F/§20). Overridable
  /// only so tests can inject one built with a fake `httpGetBytes`/
  /// `httpGetString` (no real network call, no real key) instead of the
  /// real one `_MapScreenState` otherwise builds from `MmlConfig.apiKey`.
  final MmlVectorProxyService? mmlVectorProxyService;

  /// Reads tile blobs from the bundled SYKE bathymetry MBTiles asset
  /// (TD-027 §20/§22). Overridable so tests can inject one backed by a
  /// small synthetic MBTiles fixture (or a fake `loadAsset`) instead of the
  /// real, ~49 MB bundled national asset.
  final SykeBathymetryTileSource? sykeBathymetryTileSource;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(61.9241, 25.7482),
    zoom: 5,
  );

  static const String _fishingSpotsSourceId = 'fishing-spots-source';
  static const String _fishingSpotsCircleLayerId = 'fishing-spots-circle-layer';
  static const String _fishingSpotsSymbolLayerId = 'fishing-spots-symbol-layer';

  final LocationService _locationService = const LocationService();
  final AppDatabase _database = AppDatabase();
  late final FishingSpotRepository _fishingSpotRepository =
      FishingSpotRepository(_database);
  late final WaterBodyRepository _waterBodyRepository = WaterBodyRepository(
    _database,
  );
  late final CatchRepository _catchRepository = CatchRepository(_database);
  late final CatchPhotoStorage _catchPhotoStorage = CatchPhotoStorage(
    rootDirectoryProvider: getApplicationDocumentsDirectory,
  );
  late final CatchPhotoRepository _catchPhotoRepository = CatchPhotoRepository(
    _database,
    _catchPhotoStorage,
  );
  late final LureCatalogRepository _lureCatalogRepository =
      LureCatalogRepository(_database);
  late final TackleBoxPhotoStorage _tackleBoxPhotoStorage =
      TackleBoxPhotoStorage(
        rootDirectoryProvider: getApplicationDocumentsDirectory,
      );
  late final PersonalTackleBoxRepository _personalTackleBoxRepository =
      PersonalTackleBoxRepository(_database, _tackleBoxPhotoStorage);
  late final LureStatisticsRepository _lureStatisticsRepository =
      LureStatisticsRepository(_database);
  late final GeneralCatchStatisticsRepository
  _generalCatchStatisticsRepository = GeneralCatchStatisticsRepository(
    _database,
  );
  late final SpeciesStatisticsRepository _speciesStatisticsRepository =
      SpeciesStatisticsRepository(_database);
  late final WaterBodyStatisticsRepository _waterBodyStatisticsRepository =
      WaterBodyStatisticsRepository(_database);
  late final CatchSearchRepository _catchSearchRepository =
      CatchSearchRepository(_database);
  late final MapTilerStyleFactory _mapTilerStyleFactory = MapTilerStyleFactory(
    apiKey: MapTilerConfig.apiKey,
  );

  /// Builds the correct locally-authored style document per selected
  /// `BaseMap` (TD-027 §3/§3F): Maastokartta composes MapTiler Outdoor
  /// beneath MML's real v21 vector cartography; Ilmakuva is MapTiler
  /// Satellite Hybrid only. The SYKE bathymetry overlay (TD-027 §20–§22) is
  /// added for both selections.
  late final WorldwideStyleFactory _worldwideStyleFactory =
      WorldwideStyleFactory(mapTilerStyleFactory: _mapTilerStyleFactory);

  /// The local, on-device loopback proxy for MML's real v21 vector base map
  /// and the bundled SYKE bathymetry overlay (TD-027 §3F/§20) — "one
  /// loopback HTTP listener, multiple route prefixes." Constructed
  /// unconditionally (cheap — the constructor does no networking); started
  /// in [_initializeBaseMap] regardless of `MmlConfig`'s state, since the
  /// SYKE bathymetry route has no dependency on the MML credential at all —
  /// only [MmlVectorProxyService.fetchMmlStyleFragment] itself is gated on
  /// `MmlConfig` being configured.
  late final MmlVectorProxyService _mmlVectorProxyService =
      widget.mmlVectorProxyService ??
      MmlVectorProxyService(
        apiKey: MmlConfig.apiKey,
        sykeBathymetryTileSource: _sykeBathymetryTileSource,
      );

  /// Reads tile blobs from the bundled SYKE bathymetry MBTiles asset
  /// (TD-027 §20/§22) — fully offline, no network, no credential. Extracted
  /// once (best-effort; a failure simply omits the overlay, never a crash)
  /// in [_initializeBaseMap].
  late final SykeBathymetryTileSource _sykeBathymetryTileSource =
      widget.sykeBathymetryTileSource ?? SykeBathymetryTileSource();

  /// Whether the *currently applied* style actually includes MML's real
  /// v21 vector fragment — distinct from `_selectedBaseMap ==
  /// BaseMap.maastokartta`, since MML may be unconfigured or its fragment
  /// fetch may have failed (TD-027 §3F Failure behavior), in which case
  /// Maastokartta still renders (MapTiler Outdoor alone) but without MML's
  /// own glyph host. Drives the fishing-spot symbol layer's `textFont`
  /// choice below — MML's v21 style uses its own glyph host with its own
  /// font names (verified live: "Liberation Sans NLSFI"), not this
  /// project's usual `fonts.openmaptiles.org` "Open Sans Regular"
  /// (`WorldwideStyleFactory.defaultGlyphsUrl`); a style document only ever
  /// declares one `glyphs` URL, so the label must request a font that
  /// actually exists on whichever host the *current* style points at.
  bool _mmlFragmentIncludedInCurrentStyle = false;

  /// Whether the bundled SYKE bathymetry asset was successfully extracted
  /// and is being served for the *currently applied* style — drives the
  /// SYKE line in the shared attribution panel (TD-027 §24) and whether
  /// `WorldwideStyleFactory` is given a non-null
  /// `sykeBathymetryLocalBaseUrl`.
  bool _sykeBathymetryAvailable = false;

  static const _mmlVectorGlyphFont = 'Liberation Sans NLSFI';
  static const _defaultGlyphFont = 'Open Sans Regular';

  final Map<String, FishingSpot> _fishingSpotsById = {};

  MapLibreMapController? _mapController;
  bool _myLocationEnabled = false;
  bool _isSelectionMode = false;
  bool _isCreatingFishingSpot = false;

  /// Selected base map, and the local style file currently backing the map.
  /// Both are `null` until the persisted preference finishes loading
  /// (MFS-026 FR-8; see `_initializeBaseMap`) — `build()` shows a loading
  /// gate rather than constructing `MapLibreMap` with a not-yet-correct
  /// style, so the angler never sees the wrong base map flash before
  /// switching to the right one.
  BaseMap? _selectedBaseMap;
  String? _currentStylePath;
  bool _layersPanelOpen = false;

  /// The base map most recently *requested* by the user (updated
  /// synchronously the moment a selection is made), independent of
  /// `_selectedBaseMap` (which only updates once that selection's style has
  /// actually finished loading) and independent of the completion order of
  /// any in-flight persistence writes. This is the single source of truth
  /// for "what should ultimately end up persisted" — see
  /// `_persistBaseMapSelection`.
  BaseMap? _latestRequestedBaseMap;

  /// Bumped every time a new base-map switch is *requested* (not when it is
  /// actually applied — see `_styleRestoration` for that). Used only to
  /// discard stale in-flight work (an outdated style-file write, an
  /// outdated style-load timeout) that a newer request has since
  /// superseded.
  int _styleGeneration = 0;

  /// Tracks which style-application generation fishing-spot markers/layers
  /// have been restored for — deliberately a separate counter from
  /// `_styleGeneration` above (which tracks *requests*, not applications).
  /// Replaces the previous one-shot `_fishingSpotMarkersAdded` guard, which
  /// assumed a style loads exactly once for the widget's lifetime —
  /// application-owned fishing-spot layers must instead survive *every*
  /// base-style reload (ADR-0008; MFS-026), and `onStyleLoadedCallback` may
  /// only mark restoration complete for the generation actually applied to
  /// MapLibreMap, never for whichever generation merely happened to be the
  /// latest *requested* at the time it fired (see
  /// `StyleRestorationTracker`'s own doc comment).
  final StyleRestorationTracker _styleRestoration = StyleRestorationTracker();

  Timer? _styleLoadTimeoutTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeBaseMap());
  }

  @override
  void dispose() {
    _styleLoadTimeoutTimer?.cancel();
    _mapController?.onFeatureTapped.remove(_onFishingSpotFeatureTapped);
    unawaited(_mmlVectorProxyService.stop());
    _sykeBathymetryTileSource.close();
    unawaited(_database.close());
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    controller.onFeatureTapped.add(_onFishingSpotFeatureTapped);
  }

  /// Loads the persisted base-map preference (defaulting to Maastokartta —
  /// MFS-026 FR-2/FR-3) and prepares its style file before revealing the
  /// map for the first time.
  ///
  /// Starts [_mmlVectorProxyService] and extracts the bundled SYKE
  /// bathymetry asset ([SykeBathymetryTileSource.ensureExtracted]) before
  /// building the very first style — extending this same existing loading
  /// gate rather than introducing a second one (TD-027 §3C precedent,
  /// carried forward for §3F/§20). The proxy service is started
  /// unconditionally (not gated on `MmlConfig`): the bundled SYKE route it
  /// also serves has no dependency on the MML credential at all. Both steps
  /// are best-effort — a failure in either simply omits the corresponding
  /// content from the generated style exactly as if it were unconfigured
  /// (TD-027 §3F/§20 Failure behavior) — no separate error state is needed,
  /// and neither failure blocks the other.
  Future<void> _initializeBaseMap() async {
    try {
      await _mmlVectorProxyService.start();
    } catch (error) {
      debugPrint('Failed to start the MML vector proxy service: $error');
    }

    try {
      await _sykeBathymetryTileSource.ensureExtracted();
    } catch (error) {
      debugPrint('Failed to extract the SYKE bathymetry asset: $error');
    }

    final loaded = await widget.baseMapPreferenceStore.load();
    final prepared = await _prepareStyleFor(loaded);
    if (!mounted) {
      return;
    }

    _latestRequestedBaseMap = loaded;
    setState(() {
      _selectedBaseMap = loaded;
      _currentStylePath = prepared.path;
      _mmlFragmentIncludedInCurrentStyle = prepared.mmlFragmentIncluded;
      _sykeBathymetryAvailable = prepared.sykeBathymetryAvailable;
      // Deliberately not calling `_styleRestoration.recordStyleApplied()`
      // here: the tracker already starts at generation 0, which *is* the
      // initial style — calling it here would skip straight to generation
      // 1 for the very first load, for no benefit.
    });

    if (_isConfigurationMissing(loaded)) {
      _showMapImageryUnavailableBanner('Karttapohjan asetukset puuttuvat.');
    } else {
      _startStyleLoadTimeout(_styleGeneration);
    }
  }

  /// Whether [baseMap] has no usable provider configured at all, per
  /// TD-027 §9's per-selection banner condition:
  ///
  /// * Maastokartta has two independent providers (MML, MapTiler Outdoor);
  ///   either one alone still leaves a usable base map, so the banner is
  ///   reserved for the case where neither is configured.
  /// * Ilmakuva has only MapTiler Satellite Hybrid — a missing MapTiler key
  ///   alone already means there is nothing to show for this selection.
  bool _isConfigurationMissing(BaseMap baseMap) {
    return switch (baseMap) {
      BaseMap.maastokartta => MmlConfig.isMissing && MapTilerConfig.isMissing,
      BaseMap.ilmakuva => MapTilerConfig.isMissing,
    };
  }

  /// Switches the active base map immediately (MFS-026: no separate
  /// save/apply step) and persists the choice right away, independent of
  /// whether this particular style load later succeeds — the angler's
  /// choice is what must be remembered, not a report card on one load
  /// attempt's outcome.
  Future<void> _onBaseMapSelected(BaseMap newBaseMap) async {
    setState(() => _layersPanelOpen = false);

    // Compared against the most recently *requested* selection, not
    // `_selectedBaseMap` (which only updates once a switch's style has
    // actually finished loading) — otherwise a rapid switch back to a
    // choice whose own style hasn't applied yet would be silently dropped
    // as a no-op.
    if (newBaseMap == (_latestRequestedBaseMap ?? _selectedBaseMap)) {
      return;
    }

    final generation = ++_styleGeneration;
    _latestRequestedBaseMap = newBaseMap;
    unawaited(_persistBaseMapSelection(newBaseMap));

    if (_isConfigurationMissing(newBaseMap)) {
      _showMapImageryUnavailableBanner('Karttapohjan asetukset puuttuvat.');
    } else {
      _hideImageryBanner();
      _startStyleLoadTimeout(generation);
    }

    final prepared = await _prepareStyleFor(newBaseMap);
    if (!mounted || _styleGeneration != generation) {
      return; // a newer switch has since occurred; discard this stale result
    }

    setState(() {
      _selectedBaseMap = newBaseMap;
      _currentStylePath = prepared.path;
      _mmlFragmentIncludedInCurrentStyle = prepared.mmlFragmentIncluded;
      _sykeBathymetryAvailable = prepared.sykeBathymetryAvailable;
      // The style is only actually being applied to MapLibreMap now — see
      // `StyleRestorationTracker`'s doc comment for why this must be
      // tracked separately from `_styleGeneration` above.
      _styleRestoration.recordStyleApplied();
    });
  }

  /// Persists [baseMap] as the selected base map.
  ///
  /// Rapid switching can have several of these in flight at once, and
  /// their underlying writes are not guaranteed to complete in request
  /// order — without this guard, an older, slower write finishing after a
  /// newer one could silently leave the persisted preference behind the
  /// angler's actual latest selection. After its own write completes, this
  /// re-checks whether [baseMap] is still the most recently requested
  /// selection (`_latestRequestedBaseMap`, updated synchronously per
  /// request in `_onBaseMapSelected`, independent of style-load
  /// completion); if a newer request has since superseded it, it recurses
  /// to persist the actual latest selection instead of leaving a
  /// possibly-clobbered, stale value behind. Recursing (rather than a
  /// single unguarded follow-up write) matters: it re-applies this exact
  /// same guard to the correction itself, so even a correction that is
  /// itself overtaken by a still-newer request converges correctly. Since
  /// each recursive step only ever follows a real, distinct user
  /// selection, this always terminates — no separate queue or
  /// serialization mechanism is needed.
  Future<void> _persistBaseMapSelection(BaseMap baseMap) async {
    await widget.baseMapPreferenceStore.save(baseMap);

    final latest = _latestRequestedBaseMap;
    if (latest != null && latest != baseMap) {
      await _persistBaseMapSelection(latest);
    }
  }

  /// Prepares the MapLibre style document for [baseMap] — fetching MML's
  /// real v21 vector fragment first when applicable (TD-027 §3F), then
  /// writing the composed style to the application's temporary directory —
  /// and reports, alongside the resulting file path, whether MML's
  /// fragment and the SYKE bathymetry overlay actually ended up part of it
  /// (`_PreparedStyle`), since `build()`/the fishing-spot symbol layer need
  /// to know that to choose the correct glyph font and attribution content.
  ///
  /// `maplibre_gl`'s native Android implementation supports passing a raw
  /// JSON style string directly, but the package's own documentation states
  /// this is only supported on Android — a local absolute file path is
  /// supported on both platforms via the same generic mechanism. This
  /// factory always writes to a file rather than ever passing inline JSON,
  /// so the map works correctly if this application is ever built for iOS
  /// (TD-026 §3's documented fallback).
  ///
  /// MML's fragment is only fetched for `BaseMap.maastokartta` when
  /// `MmlConfig` is configured — `fetchMmlStyleFragment()` itself returns
  /// `null` (never throws) if the proxy service has not started or the
  /// real fetch fails, which `WorldwideStyleFactory` already treats
  /// identically to "MML unavailable" (TD-027 §3F Failure behavior). The
  /// SYKE bathymetry overlay is included whenever the bundled asset was
  /// successfully extracted, for **either** selection, independent of MML.
  ///
  /// If writing the style file itself fails (e.g. no free disk space), one
  /// more attempt writes the minimal blank style to the same location — a
  /// transient failure (e.g. a momentarily locked directory) is often
  /// enough to make the first attempt fail without also dooming a retry,
  /// and this keeps using the same cross-platform file-path mechanism
  /// rather than abandoning it.
  ///
  /// Only if that retry *also* fails does this return the blank style JSON
  /// directly as an inline string. That inline fallback is not a
  /// cross-platform solution — it relies on exactly the Android-only raw-
  /// JSON `styleString` support this method otherwise avoids (see above) —
  /// it exists solely so the app does not hang on its loading gate forever
  /// if the filesystem itself is unusable. On a platform where inline JSON
  /// is not supported, `MapLibreMap` simply will not render a base style in
  /// this specific, doubly-failed scenario; the rest of the screen (app
  /// bar, fishing-spot layer once its own add succeeds, other entry
  /// points) remains reachable regardless.
  Future<_PreparedStyle> _prepareStyleFor(BaseMap baseMap) async {
    String? mmlFragment;
    if (baseMap == BaseMap.maastokartta && !MmlConfig.isMissing) {
      mmlFragment = await _mmlVectorProxyService.fetchMmlStyleFragment();
    }

    final sykeAvailable =
        _sykeBathymetryTileSource.extractedPath != null &&
        _mmlVectorProxyService.baseUrl != null;

    try {
      final style = _worldwideStyleFactory.buildStyle(
        baseMap,
        mapTilerAvailable: !MapTilerConfig.isMissing,
        mmlStyleFragmentJson: mmlFragment,
        sykeBathymetryLocalBaseUrl: sykeAvailable
            ? _mmlVectorProxyService.baseUrl
            : null,
      );
      final path = await _writeStyleFile(baseMap.name, style);
      return _PreparedStyle(
        path: path,
        mmlFragmentIncluded: mmlFragment != null,
        sykeBathymetryAvailable: sykeAvailable,
      );
    } catch (error) {
      debugPrint('Failed to prepare base-map style file: $error');
      try {
        final path = await _writeStyleFile('blank', _blankStyle);
        return _PreparedStyle(
          path: path,
          mmlFragmentIncluded: false,
          sykeBathymetryAvailable: false,
        );
      } catch (fallbackError) {
        debugPrint(
          'Failed to write the blank-style fallback file too: '
          '$fallbackError',
        );
        // Last resort; Android-only (see doc comment above), not a
        // cross-platform guarantee.
        return const _PreparedStyle(
          path: _blankStyle,
          mmlFragmentIncluded: false,
          sykeBathymetryAvailable: false,
        );
      }
    }
  }

  // Includes the same default `glyphs` URL as
  // `WorldwideStyleFactory.defaultGlyphsUrl` — the blank fallback style
  // (missing API key, or a disk-write failure) still needs to host the
  // fishing-spot symbol layer's text labels, which require a `glyphs`
  // source to rasterize regardless of which base style is active.
  static const _blankStyle =
      '{"version":8,"glyphs":"https://fonts.openmaptiles.org/{fontstack}/{range}.pbf",'
      '"sources":{},"layers":[]}';

  Future<String> _writeStyleFile(String name, String styleJson) async {
    final directory = await widget.temporaryDirectoryProvider();
    final file = File('${directory.path}/mml_style_$name.json');
    await file.writeAsString(styleJson);
    return file.path;
  }

  void _startStyleLoadTimeout(int generation) {
    _styleLoadTimeoutTimer?.cancel();
    _styleLoadTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || _styleGeneration != generation) {
        return;
      }
      _showMapImageryUnavailableBanner(
        'Karttakuvia ei voitu ladata juuri nyt.',
      );
    });
  }

  void _showMapImageryUnavailableBanner(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('Sulje'),
          ),
        ],
      ),
    );
  }

  void _hideImageryBanner() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).clearMaterialBanners();
  }

  Map<String, dynamic> _fishingSpotToFeature(FishingSpot spot) {
    return {
      'type': 'Feature',
      'id': spot.id,
      'properties': {'id': spot.id, 'name': spot.name},
      'geometry': {
        'type': 'Point',
        'coordinates': [spot.longitude, spot.latitude],
      },
    };
  }

  Map<String, dynamic> _buildFeatureCollection(Iterable<FishingSpot> spots) {
    return {
      'type': 'FeatureCollection',
      'features': [for (final spot in spots) _fishingSpotToFeature(spot)],
    };
  }

  /// Sets up a single shared GeoJSON source backing two style layers (a
  /// circle for the marker dot, a symbol for the name label). Managed
  /// MapLibre annotations (`addCircle`/`addSymbol`/`updateSymbol`) always
  /// replace their *entire* backing GeoJSON source on every single call —
  /// even to add or relabel one marker — which on Android briefly stalls the
  /// embedded map surface and shows as a black flash. Using one feature-owned
  /// source for both layers means one full-collection update per fishing
  /// spot change instead of two (previously one for the circle annotation,
  /// one for the symbol annotation), halving how often that native refresh
  /// happens.
  ///
  /// Runs from `onStyleLoadedCallback`, which fires again every time the
  /// active style is replaced — including a base-map switch (MFS-026) —
  /// since MapLibre destroys every style-owned source/layer on a style
  /// change. `_styleRestoration` distinguishes "already restored for the
  /// style generation actually applied" (skip, avoiding a duplicate-add
  /// crash if this callback ever fires twice for the same style) from "a
  /// genuinely new style just loaded" (restore) — and, critically, can only
  /// ever be satisfied for whichever generation is *actually applied* at
  /// the moment this runs, never for a generation that was merely
  /// *requested* (see `StyleRestorationTracker`'s own doc comment for the
  /// race this closes). This replaces the previous one-shot
  /// `_fishingSpotMarkersAdded` boolean, which incorrectly assumed a style
  /// loads exactly once for the widget's lifetime.
  Future<void> _addFishingSpotMarkers() async {
    final selectedBaseMap = _selectedBaseMap;
    if (selectedBaseMap != null && !_isConfigurationMissing(selectedBaseMap)) {
      // A style just finished loading, so any pending "imagery unavailable"
      // signal for it no longer applies. Left untouched when the current
      // selection's configuration is missing, since that banner reflects a
      // persistent configuration problem, not a transient load — the blank
      // fallback style "loading successfully" must not dismiss it.
      _cancelStyleLoadTimeout();
      _hideImageryBanner();
    }

    final controller = _mapController;
    if (controller == null) {
      return;
    }

    if (_styleRestoration.isRestoredForCurrentGeneration) {
      return; // already restored for the style actually applied right now
    }
    final generation = _styleRestoration.applied;

    List<FishingSpot> spots;
    try {
      // Fishing spots don't change just because the base map did, so only
      // the very first load (cache empty) needs to hit the repository;
      // every later style reload reuses the already-loaded cache.
      spots = _fishingSpotsById.isNotEmpty
          ? _fishingSpotsById.values.toList()
          : await _fishingSpotRepository.loadAll();
    } catch (error) {
      debugPrint('Failed to load fishing spots: $error');
      return;
    }

    if (!mounted || _styleRestoration.isStale(generation)) {
      return; // a newer style has since been applied; discard this stale result
    }

    for (final spot in spots) {
      _fishingSpotsById[spot.id] = spot;
    }

    final restored = await _ensureFishingSpotLayersExist(
      controller,
      generation,
    );
    if (restored && !_styleRestoration.isStale(generation)) {
      _styleRestoration.markRestored(generation);
      debugPrint(
        'Fishing-spot layers confirmed present for style generation $generation.',
      );
    }
  }

  /// Ensures the fishing-spot GeoJSON source and both its layers actually
  /// exist in the currently active style — verified by querying
  /// `getSourceIds()`/`getLayerIds()` after each attempt, never assumed
  /// from an add call merely not throwing.
  ///
  /// Waiting for the native style to report "fully loaded" before
  /// *starting* the add sequence (this project's previous approach) does
  /// not prove the sequence's own calls succeeded: the native Android
  /// implementation's `addSource`/`addLayer` methods silently log a
  /// warning and add nothing — no exception — if the style stops being
  /// "fully loaded" at any point during the sequence, which a base-map
  /// switch can trigger by destroying the whole style out from under an
  /// in-flight attempt. This method instead re-queries what is actually
  /// present on every iteration and only (re-)attempts whichever specific
  /// object ([FishingSpotLayerPresence]) is confirmed missing — never
  /// blindly re-adding something already there, since unlike
  /// `addGeoJsonSource` (which already guards itself against this),
  /// `addLayer` throws if given an already-existing layer id.
  ///
  /// Bounded to 60 attempts (~30 seconds at 500ms apart). This bound applies
  /// identically to the very first (initial) style load and to every
  /// subsequent base-map switch — there is no special-casing by generation,
  /// since both go through this exact same verified, idempotent convergence
  /// loop.
  ///
  /// The bound was widened from an earlier ~5 seconds after a physical
  /// device showed the initial load alone failing to converge in that
  /// window while every later switch converged quickly. Root-caused (native
  /// Android source: `getSourceIds`/`getLayerIds` both gate on
  /// `style.isFullyLoaded()`, throwing `STYLE_NOT_READY` until it is) to
  /// genuine cold-start cost that a warm switch does not pay: the very
  /// first native map surface/GL initialization on the device, and — more
  /// specifically — the very first network connection (DNS + TLS + TCP
  /// handshake) to MML's tile host. A later switch between Maastokartta and
  /// Ilmakuva targets that exact same host, so it can reuse an
  /// already-warm connection and converges far faster. Widening the bound
  /// is not "an arbitrary extra delay": nothing is ever slept blindly for
  /// its own sake — every attempt still actively re-verifies real
  /// source/layer presence and returns the instant that is confirmed, so a
  /// fast style still restores in one or two attempts; only a genuinely
  /// slow cold start now gets the time it legitimately needs. A style stuck
  /// well beyond this is still bounded and gives up, and the separate,
  /// unchanged 10-second `_startStyleLoadTimeout` continues to surface its
  /// own "imagery unavailable" signal independently of this loop.
  Future<bool> _ensureFishingSpotLayersExist(
    MapLibreMapController controller,
    int generation,
  ) async {
    const maxAttempts = 60;
    const retryDelay = Duration(milliseconds: 500);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!mounted || _styleRestoration.isStale(generation)) {
        return false;
      }

      FishingSpotLayerPresence presence;
      try {
        final sourceIds = await controller.getSourceIds();
        final layerIds = (await controller.getLayerIds()).cast<String>();
        presence = FishingSpotLayerPresence.from(
          sourceIds: sourceIds,
          layerIds: layerIds,
          sourceId: _fishingSpotsSourceId,
          circleLayerId: _fishingSpotsCircleLayerId,
          symbolLayerId: _fishingSpotsSymbolLayerId,
        );
      } catch (error) {
        // Style not (yet) fully loaded, or another transient native
        // failure querying it — wait and retry, bounded by maxAttempts.
        // Logged sparsely (first attempt, then every 10th) so a physical
        // retest's logcat shows convergence progress without a line every
        // 500ms for up to 30 seconds. Never logs the error object itself
        // beyond its message, and never logs MML_API_KEY or tile URLs.
        if (attempt == 1 || attempt % 10 == 0) {
          debugPrint(
            'Fishing-spot layers not yet queryable on attempt $attempt '
            '(generation $generation): $error',
          );
        }
        await Future<void>.delayed(retryDelay);
        continue;
      }

      if (presence.isComplete) {
        if (attempt > 1) {
          debugPrint(
            'Fishing-spot layers confirmed present after $attempt attempts '
            '(generation $generation).',
          );
        }
        return true;
      }

      if (!mounted || _styleRestoration.isStale(generation)) {
        return false;
      }

      try {
        if (presence.shouldAddSource) {
          await controller.addGeoJsonSource(
            _fishingSpotsSourceId,
            _buildFeatureCollection(_fishingSpotsById.values),
            promoteId: 'id',
          );
        }

        // Re-check the source specifically before attempting either layer:
        // a layer referencing a non-existent source is itself invalid, and
        // the add just above may itself have silently no-op'd.
        final sourceReady =
            presence.hasSource ||
            (await controller.getSourceIds()).contains(_fishingSpotsSourceId);

        if (sourceReady) {
          if (presence.shouldAddCircleLayer) {
            // No `belowLayerId` is given, so the layer is appended above
            // every existing style layer (including the base-map raster
            // layer) — this is MapLibre's own documented default when
            // `belowLayerId` is omitted, verified directly against the
            // native Android implementation; layer ordering was not the
            // defect that caused missing markers.
            await controller.addLayer(
              _fishingSpotsSourceId,
              _fishingSpotsCircleLayerId,
              const CircleLayerProperties(
                circleRadius: 8,
                circleColor: '#009688',
                circleStrokeColor: '#ffffff',
                circleStrokeWidth: 2,
              ),
            );
          }

          if (!mounted || _styleRestoration.isStale(generation)) {
            return false;
          }

          if (presence.shouldAddSymbolLayer) {
            await controller.addLayer(
              _fishingSpotsSourceId,
              _fishingSpotsSymbolLayerId,
              SymbolLayerProperties(
                textField: [Expressions.get, 'name'],
                textOffset: [0, 1.2],
                // 'Open Sans Regular' alone — verified live against the
                // default glyph host (fonts.openmaptiles.org) by
                // requesting its actual PBF ranges directly: it returns
                // real glyph data (HTTP 200, application/octet-stream)
                // across ranges including Latin-1 Supplement (needed for
                // Finnish ä/ö). 'Arial Unicode MS Regular' — previously
                // included as a fallback — does NOT exist on this host
                // (HTTP 200 but an HTML error page, not glyph data), and
                // MapLibre requests a *combined* fontstack for a
                // multi-font textFont list, so that combined request
                // failed as a whole and no glyphs were ever returned for
                // any font — this is why labels silently failed to
                // render even after glyphs/circles worked. Do not add
                // another font here without first verifying it actually
                // exists on this glyph host; an unverifiable font name
                // silently breaks every font in the same textFont list.
                //
                // MML's own real v21 style declares a different `glyphs`
                // host entirely (its own, with its own font names) —
                // 'Open Sans Regular' does not exist there, so whenever
                // MML's fragment is actually part of the current style
                // (`_mmlFragmentIncludedInCurrentStyle`), the one font this
                // project has verified does exist there is used instead
                // ('Liberation Sans NLSFI', read directly off MML's own
                // real style layers — TD-027 §3F).
                textFont: kIsWeb
                    ? null
                    : [
                        _mmlFragmentIncludedInCurrentStyle
                            ? _mmlVectorGlyphFont
                            : _defaultGlyphFont,
                      ],
              ),
            );
          }
        }
      } catch (error) {
        debugPrint(
          'Fishing-spot layer setup attempt $attempt failed, retrying: $error',
        );
      }

      await Future<void>.delayed(retryDelay);
    }

    debugPrint(
      'Fishing-spot layers still missing after $maxAttempts attempts; '
      'giving up for style generation $generation.',
    );
    return false;
  }

  void _cancelStyleLoadTimeout() {
    _styleLoadTimeoutTimer?.cancel();
    _styleLoadTimeoutTimer = null;
  }

  Future<bool> _addFishingSpotFeature(FishingSpot spot) async {
    final controller = _mapController;
    if (controller == null) {
      return false;
    }

    _fishingSpotsById[spot.id] = spot;

    try {
      await controller.setGeoJsonSource(
        _fishingSpotsSourceId,
        _buildFeatureCollection(_fishingSpotsById.values),
      );
      return true;
    } catch (error) {
      debugPrint('Failed to add fishing spot marker: $error');
      return false;
    }
  }

  void _onFishingSpotFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (_isSelectionMode) {
      return;
    }

    if (layerId != _fishingSpotsCircleLayerId &&
        layerId != _fishingSpotsSymbolLayerId) {
      return;
    }

    final spot = _fishingSpotsById[id];
    if (spot == null) {
      return;
    }

    unawaited(_openFishingSpotDetails(spot));
  }

  Future<void> _openFishingSpotDetails(FishingSpot spot) async {
    final result = await FishingSpotDetailsBottomSheet.show(
      context,
      spot,
      _catchRepository,
      _catchPhotoRepository,
      _lureCatalogRepository,
      _personalTackleBoxRepository,
      _tackleBoxPhotoStorage,
      _waterBodyRepository,
      _fishingSpotRepository,
    );
    if (!mounted || result == null) {
      return;
    }

    switch (result) {
      case FishingSpotRenamed(:final name):
        await _renameFishingSpot(spot, name);
      case FishingSpotDeleted():
        await _deleteFishingSpot(spot);
      case FishingSpotAddCatchRequested():
        await _openAddCatchBottomSheet(spot);
    }
  }

  Future<void> _openAddCatchBottomSheet(FishingSpot spot) async {
    final result = await AddCatchBottomSheet.show(
      context,
      spot,
      _catchRepository,
      _catchPhotoRepository,
      _personalTackleBoxRepository,
      _tackleBoxPhotoStorage,
    );

    if (result == null || !mounted) {
      return;
    }

    switch (result) {
      case CatchCreated(:final hasPhotoFailures):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasPhotoFailures
                  ? 'Saalis tallennettu, mutta osaa kuvista ei voitu '
                        'lisätä. Voit lisätä puuttuvat kuvat myöhemmin '
                        'muokkaamalla saalista.'
                  : 'Saalis tallennettu',
            ),
          ),
        );
    }
  }

  Future<void> _renameFishingSpot(FishingSpot spot, String newName) async {
    FishingSpot updated;
    try {
      updated = await _fishingSpotRepository.updateName(
        id: spot.id,
        name: newName,
      );
    } catch (error) {
      debugPrint('Failed to update fishing spot: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kalastuspaikan päivittäminen epäonnistui. Yritä uudelleen.',
            ),
          ),
        );
      }
      return;
    }

    _fishingSpotsById[updated.id] = updated;

    final controller = _mapController;
    if (controller == null) {
      return;
    }

    try {
      await controller.setGeoJsonFeature(
        _fishingSpotsSourceId,
        _fishingSpotToFeature(updated),
      );
    } catch (error) {
      debugPrint('Failed to update fishing spot marker: $error');
    }
  }

  Future<void> _deleteFishingSpot(FishingSpot spot) async {
    try {
      await _fishingSpotRepository.delete(spot.id);
    } catch (error) {
      debugPrint('Failed to delete fishing spot: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kalastuspaikan poistaminen epäonnistui. Yritä uudelleen.',
            ),
          ),
        );
      }
      return;
    }

    _fishingSpotsById.remove(spot.id);

    final controller = _mapController;
    if (controller == null) {
      return;
    }

    try {
      await controller.setGeoJsonSource(
        _fishingSpotsSourceId,
        _buildFeatureCollection(_fishingSpotsById.values),
      );
    } catch (error) {
      debugPrint('Failed to refresh fishing spot markers: $error');
    }
  }

  Future<void> _onLocationPressed() async {
    final result = await _locationService.getCurrentPosition();

    if (!mounted) return;

    switch (result) {
      case LocationSuccess(:final position):
        setState(() => _myLocationEnabled = true);
        await _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      case LocationFailure(:final reason):
        _showLocationFailureMessage(reason);
    }
  }

  Future<void> _onAddFishingSpotPressed() async {
    final method = await AddFishingSpotBottomSheet.show(context);
    if (!mounted || method == null) {
      return;
    }

    switch (method) {
      case FishingSpotCreationMethod.currentLocation:
        await _createFishingSpotFromCurrentLocation();
      case FishingSpotCreationMethod.selectFromMap:
        setState(() => _isSelectionMode = true);
    }
  }

  Future<void> _createFishingSpotFromCurrentLocation() async {
    if (_isCreatingFishingSpot) {
      return;
    }
    _isCreatingFishingSpot = true;

    try {
      final result = await _locationService.getCurrentPosition();
      if (!mounted) return;

      switch (result) {
        case LocationSuccess(:final position):
          await _promptAndCreateFishingSpot(
            LatLng(position.latitude, position.longitude),
          );
        case LocationFailure(:final reason):
          _showLocationFailureMessage(reason);
      }
    } finally {
      _isCreatingFishingSpot = false;
    }
  }

  void _onCancelSelectionPressed() {
    setState(() => _isSelectionMode = false);
  }

  Future<void> _onAddHerePressed() async {
    if (_isCreatingFishingSpot) {
      return;
    }

    final target = _mapController?.cameraPosition?.target;
    if (target == null) {
      return;
    }

    _isCreatingFishingSpot = true;
    try {
      await _promptAndCreateFishingSpot(target);
    } finally {
      _isCreatingFishingSpot = false;
      if (mounted) {
        setState(() => _isSelectionMode = false);
      }
    }
  }

  Future<void> _promptAndCreateFishingSpot(LatLng position) async {
    final waterBody = await WaterBodySelectionBottomSheet.show(
      context,
      waterBodyRepository: _waterBodyRepository,
      fishingSpotRepository: _fishingSpotRepository,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (!mounted || waterBody == null) {
      return;
    }

    final name = await FishingSpotNameBottomSheet.show(context);
    if (!mounted || name == null) {
      return;
    }

    try {
      final spot = await _fishingSpotRepository.create(
        name: name,
        latitude: position.latitude,
        longitude: position.longitude,
        waterBodyId: waterBody.id,
      );
      await _addFishingSpotFeature(spot);
    } catch (error) {
      debugPrint('Failed to save fishing spot: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kalastuspaikan tallentaminen epäonnistui. Yritä uudelleen.',
            ),
          ),
        );
      }
    }
  }

  // Temporary navigation entry point: the application currently has no
  // dedicated navigation shell (no drawer, bottom navigation, or home
  // menu), so this is the only existing screen with an AppBar to attach a
  // link to. This does not make Lure Catalog / Personal Tackle Box a Map
  // sub-feature — the dependency is one-way, for navigation only, and is
  // expected to move once real app-wide navigation exists. See TD-015's
  // Navigation Entry Point (Temporary) section.
  //
  // A single route hosts both screens as tabs (`LureToolsPage`) so
  // switching between them never requires returning to the map first —
  // see TD-015/TD-016's Navigation sections for the two screens this
  // replaces individually opening.
  void _openLureTools() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LureToolsPage(
          lureCatalogRepository: _lureCatalogRepository,
          lureCatalogDetailsActionsBuilder: _buildLureDetailsActions,
          loadOwnedLureVariantIds: _loadOwnedLureVariantIds,
          personalTackleBoxRepository: _personalTackleBoxRepository,
          personalTackleBoxPhotoStorage: _tackleBoxPhotoStorage,
        ),
      ),
    );
  }

  // Temporary navigation entry point, following the same pattern as
  // _openLureTools above (see TD-015's Navigation Entry Point (Temporary)
  // section and TD-019 §6): the application still has no dedicated
  // navigation shell, so this is the only existing screen with an AppBar to
  // attach a link to.
  void _openStatistics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StatisticsPage(
          generalCatchStatisticsRepository: _generalCatchStatisticsRepository,
          lureStatisticsRepository: _lureStatisticsRepository,
          speciesStatisticsRepository: _speciesStatisticsRepository,
          waterBodyStatisticsRepository: _waterBodyStatisticsRepository,
          catchRepository: _catchRepository,
          catchPhotoRepository: _catchPhotoRepository,
          lureCatalogRepository: _lureCatalogRepository,
          personalTackleBoxRepository: _personalTackleBoxRepository,
          personalTackleBoxPhotoStorage: _tackleBoxPhotoStorage,
          waterBodyRepository: _waterBodyRepository,
        ),
      ),
    );
  }

  // Temporary navigation entry point, following the same pattern as
  // _openLureTools/_openStatistics above (see TD-015's Navigation Entry
  // Point (Temporary) section): the application still has no dedicated
  // navigation shell, so this is the only existing screen with an AppBar to
  // attach a link to. See MFS-025 / TD-025.
  void _openCatchSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CatchSearchPage(
          catchSearchRepository: _catchSearchRepository,
          catchRepository: _catchRepository,
          catchPhotoRepository: _catchPhotoRepository,
          lureCatalogRepository: _lureCatalogRepository,
          personalTackleBoxRepository: _personalTackleBoxRepository,
          personalTackleBoxPhotoStorage: _tackleBoxPhotoStorage,
          waterBodyRepository: _waterBodyRepository,
        ),
      ),
    );
  }

  /// Backs `LureCatalogListPage`'s owned-badge/hide-owned-filter option.
  /// `lure_catalog` only ever sees the resulting `Set<String>` of variant
  /// ids — never a `personal_tackle_box` type.
  Future<Set<String>> _loadOwnedLureVariantIds() async {
    final items = await _personalTackleBoxRepository.getAll();
    return {for (final item in items) item.catalogEntry.id};
  }

  /// Builds the "Add to Tackle Box" action for one Color Variant row inside
  /// Lure Model Details. `lure_catalog` never imports `personal_tackle_box`
  /// itself — this closure is the one place the two features meet, built
  /// entirely by `MapScreen` and threaded in through
  /// `LureModelDetailsPage.variantActionBuilder`. See TD-016's Key Design
  /// Decision 1 and TD-018's Key Design Decision 8.
  ///
  /// [initialIsOwned] is already known by the caller (from the one
  /// already-loaded owned-ids set), so it is passed straight through — this
  /// avoids one `isOwned()` query per row (TD-018 Key Design Decisions 4
  /// and 5).
  Widget _buildLureDetailsActions(
    BuildContext context,
    LureCatalogEntry entry, {
    required bool initialIsOwned,
  }) {
    return AddToTackleBoxAction(
      key: ValueKey('addToTackleBox-${entry.id}'),
      catalogEntry: entry,
      repository: _personalTackleBoxRepository,
      initialIsOwned: initialIsOwned,
    );
  }

  void _showLocationFailureMessage(LocationFailureReason reason) {
    final message = switch (reason) {
      LocationFailureReason.serviceDisabled =>
        'Sijaintipalvelut on poistettu käytöstä.',
      LocationFailureReason.permissionDenied => 'Sijaintilupa evättiin.',
      LocationFailureReason.permissionDeniedForever =>
        'Sijaintilupa on evätty pysyvästi. Ota se käyttöön järjestelmäasetuksista.',
      LocationFailureReason.positionUnavailable =>
        'Nykyinen sijainti ei ole käytettävissä.',
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedBaseMap = _selectedBaseMap;
    final stylePath = _currentStylePath;

    // The persisted base-map preference (and its style file) is loaded
    // asynchronously (see `_initializeBaseMap`); showing this brief loading
    // gate instead of constructing `MapLibreMap` with a not-yet-correct
    // style avoids the map ever visibly loading the wrong base map first
    // and then switching (MFS-026).
    if (selectedBaseMap == null || stylePath == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Kalastussovellus'),
        actions: [
          IconButton(
            key: const Key('openLureToolsButton'),
            icon: const Icon(Icons.menu_book),
            tooltip: 'Viehekatalogi ja oma vieherasia',
            onPressed: _openLureTools,
          ),
          IconButton(
            key: const Key('openStatisticsButton'),
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Tilastot',
            onPressed: _openStatistics,
          ),
          IconButton(
            key: const Key('openCatchSearchButton'),
            icon: const Icon(Icons.search),
            tooltip: 'Etsi saaliita',
            onPressed: _openCatchSearch,
          ),
        ],
      ),
      body: Stack(
        children: [
          MapLibreMap(
            initialCameraPosition: _initialCameraPosition,
            myLocationEnabled: _myLocationEnabled,
            trackCameraPosition: true,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _addFishingSpotMarkers,
            styleString: stylePath,
          ),
          if (_isSelectionMode)
            const IgnorePointer(
              child: Center(child: Icon(Icons.add, size: 32)),
            ),
          // MML attribution is shown whenever Maastokartta is selected and
          // MML is actually configured (TD-027 §3F/§11) — with no viewport
          // or zoom condition: MML's real v21 vector cartography is
          // unconditionally part of the composition whenever configured,
          // regardless of where the current viewport happens to be.
          // Ilmakuva never uses MML data in this milestone (ADR-0009,
          // MFS-027).
          if (selectedBaseMap == BaseMap.maastokartta && !MmlConfig.isMissing)
            MapAttribution(baseMap: selectedBaseMap),
          // Shown for both selections whenever MapTiler is configured, and
          // includes SYKE's own required CC BY 4.0 notice whenever the
          // bathymetry overlay is actually being served (TD-027 §24) — the
          // widget itself decides MapTiler's own visibility
          // (MapTilerConfig.isMissing); `sykeAttributionRequired` only adds
          // or omits the extra SYKE line inside the same shared panel.
          MapTilerAttribution(sykeAttributionRequired: _sykeBathymetryAvailable),
          MapControls(
            isSelectionMode: _isSelectionMode,
            onLocationPressed: _onLocationPressed,
            onAddFishingSpotPressed: _onAddFishingSpotPressed,
            onCancelSelectionPressed: _onCancelSelectionPressed,
            onAddHerePressed: _onAddHerePressed,
          ),
          BaseMapLayersControl(
            onPressed: () =>
                setState(() => _layersPanelOpen = !_layersPanelOpen),
          ),
          if (_layersPanelOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _layersPanelOpen = false),
              ),
            ),
            Positioned(
              // Anchored just under BaseMapLayersControl's own smaller
              // button (MFS-026 polish pass): AppSpacing.md padding (12) +
              // FloatingActionButton.small's 48-logical-pixel tap-target
              // footprint + a small gap (8), mirroring the same
              // padding+button+gap arithmetic the previous, larger control
              // used for its own anchor offset.
              top: 68,
              right: 12,
              child: BaseMapSelectorPanel(
                selected: selectedBaseMap,
                onSelected: _onBaseMapSelected,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The result of preparing a base map's style document (`_prepareStyleFor`):
/// the local file path `MapLibreMap.styleString` should be pointed at,
/// alongside whether MML's real v21 vector fragment and the SYKE bathymetry
/// overlay actually ended up part of it — both routinely `false` even for
/// `BaseMap.maastokartta` (missing/invalid configuration, a failed fetch, or
/// the bundled SYKE asset failing to extract are all non-crashing, silently
/// degraded outcomes, never an exception this class needs to catch).
class _PreparedStyle {
  const _PreparedStyle({
    required this.path,
    required this.mmlFragmentIncluded,
    required this.sykeBathymetryAvailable,
  });

  final String path;
  final bool mmlFragmentIncluded;
  final bool sykeBathymetryAvailable;
}
