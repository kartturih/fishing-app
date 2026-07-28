import 'dart:convert';

import 'package:fishing_app/core/map/base_map.dart';
import 'package:fishing_app/core/map/maptiler_config.dart';
import 'package:fishing_app/core/map/maptiler_style_factory.dart';

/// Builds the complete, locally-authored MapLibre style document for the
/// currently selected [BaseMap] (TD-027 §3/§3F). Maastokartta and Ilmakuva
/// are composed differently — this is a direct, explicit `switch`, not a
/// generic "combine a MapTiler fragment with a per-`BaseMap` MML fragment"
/// function, since the two selections are no longer symmetric (MFS-027 /
/// ADR-0009: Ilmakuva does not use MML at all in this milestone):
///
/// * `BaseMap.maastokartta`: MapTiler Outdoor (worldwide underlay, if
///   configured) plus MML's real v21 vector cartography (if its
///   already-fetched-and-rewritten fragment is supplied — TD-027 §3F), with
///   MapTiler's layer listed first so MML's own cartography renders above
///   it.
/// * `BaseMap.ilmakuva`: MapTiler Satellite Hybrid only, if configured.
///   MML is never consulted for this selection.
///
/// The SYKE bathymetry overlay (TD-027 §20–§22) is added for **both**
/// selections, above the composed base map and appended last (application-
/// owned fishing-spot layers, added at runtime with no `belowLayerId`, land
/// above everything already in this document by construction — Key Design
/// Decision 4).
///
/// [mmlStyleFragmentJson] is already-fetched, already-rewritten JSON —
/// produced by `MmlVectorProxyService.fetchMmlStyleFragment()` — containing
/// MML's real `sources`/`layers`/`glyphs`, with its API key stripped and its
/// tile/glyph URLs pointed at that service's own loopback address. This
/// class never fetches anything itself and never sees the MML API key; it
/// only merges JSON it is given, exactly as before.
class WorldwideStyleFactory {
  const WorldwideStyleFactory({
    required MapTilerStyleFactory mapTilerStyleFactory,
  }) : _mapTiler = mapTilerStyleFactory;

  final MapTilerStyleFactory _mapTiler;

  // Used whenever no MML fragment is part of the composed style (Ilmakuva,
  // or Maastokartta with MML unavailable) — the fishing-spot symbol layer's
  // own `textFont` must match whichever glyph host is actually active
  // (`MapScreen._symbolTextFont`), so this default must stay in sync with
  // that font's own host.
  static const defaultGlyphsUrl =
      'https://fonts.openmaptiles.org/{fontstack}/{range}.pbf';

  static const sykeBathymetrySourceId = 'syke-bathymetry-source';
  static const sykeDepthAreasLayerId = 'syke-depth-areas-layer';
  static const sykeContoursLayerId = 'syke-contours-layer';
  static const sykeContourLabelsLayerId = 'syke-contour-labels-layer';
  static const sykeDepthAreasSourceLayer = 'depth_areas';
  static const sykeContoursSourceLayer = 'contours';

  /// The single-font `text-font` the SYKE depth-label layer uses when MML's
  /// own real v21 glyph host is the style's active `glyphs` root — verified
  /// live (`MapScreen._mmlVectorGlyphFont`, TD-027 §3F) as the one font name
  /// that actually exists there. Never combined with any other font name:
  /// MapLibre joins a multi-entry `text-font` into one combined fontstack
  /// request, and a combined request fails as a whole if any single font in
  /// it does not exist on the active glyph host — confirmed root cause of
  /// the depth labels not rendering (TD-027 depth-label font investigation).
  static const String sykeContourLabelMmlFont = 'Liberation Sans NLSFI';

  /// The single-font `text-font` the SYKE depth-label layer uses whenever
  /// [defaultGlyphsUrl] (not MML's own host) is the style's active `glyphs`
  /// root — verified live (`MapScreen._defaultGlyphFont`) as the one font
  /// name that actually exists on that host. See [sykeContourLabelMmlFont]
  /// for why this must never be combined with any other font name either.
  static const String sykeContourLabelDefaultFont = 'Open Sans Regular';

  /// Matches the production zoom range `tools/syke_bathymetry/build_mbtiles.py`
  /// actually tiles — **a contiguous run, z10 through z14, with no gaps**
  /// (revised after physical Android testing found a real bug in the
  /// original, non-contiguous [8, 10, 12, 14] range: MapLibre requests a
  /// vector tile at *every* integer zoom within a source's declared
  /// [minzoom, maxzoom], not merely at whichever zooms happen to have data
  /// — there is no "sparse pyramid" concept in the vector-tile source spec.
  /// The skipped levels (z9, z11, z13) genuinely had no row in the MBTiles
  /// (confirmed directly: `SELECT DISTINCT zoom_level FROM tiles` against
  /// the previously-shipped asset returned only 8/10/12/14), so the local
  /// route correctly, but unhelpfully, answered "no data" at exactly those
  /// zooms — contours flickered in and out while zooming continuously.
  /// `sykeSourceMinZoom` moved from `8` to `10` in the same fix: nothing
  /// below [sykeBathymetryPresentationMinZoom] is ever rendered regardless
  /// of source declaration, so tiling z8/z9 would only cost build time and
  /// file size for content that can never be shown.
  ///
  /// **`sykeSourceMaxZoom` (`14`) is deliberately not raised to `18`.**
  /// SYKE's underlying contour precision does not have meaningfully more
  /// real detail to reveal at finer zooms (z14 tiles were already the most
  /// heavily simplified in the original investigation build — TD-027 §20A);
  /// tiling all the way to z18 would mostly re-slice the same z14-level
  /// geometry into far more, smaller physical tiles for no informational
  /// gain. Zoom levels 15–18 are instead served by MapLibre's own standard
  /// vector-source overzoom, which the MapLibre/Mapbox style specification
  /// documents explicitly for exactly this `maxzoom` property: "Data from
  /// tiles loaded at the maxzoom are used when displaying the map at higher
  /// zoom levels" — a client-side, spec-guaranteed mechanism requiring no
  /// additional tile request or server-side data once the source honestly
  /// declares its true (now genuinely contiguous) maximum tiled zoom. This
  /// is the same reasoning already relied on for MML's own vector `maxzoom`
  /// (TD-027 §3F), now applied here for the first time with a *deliberately
  /// lower* source ceiling than the presentation range it must cover —
  /// physical Android confirmation that z15–z18 render correctly through
  /// this specific overzoom path remains a pending device-test item, not
  /// yet claimed as verified.
  static const int sykeSourceMinZoom = 10;
  static const int sykeSourceMaxZoom = 14;

  /// Presentational `minzoom` for the SYKE overlay's own layer (TD-027
  /// §22) — a static, declarative MapLibre **layer** `minzoom`, mirroring
  /// `MmlStyleFactory.presentationMinZoom`'s already-established pattern for
  /// exactly this kind of number.
  ///
  /// **Second revision after physical Android testing.** The first
  /// revision (`11`) was itself found too high once the depth-area fill's
  /// own visual-clutter problem (the original reason bathymetry was pushed
  /// to a higher zoom) was already resolved by disabling that fill layer
  /// entirely — physical testing found contours would already be useful
  /// around z10. Lowered to `10`, matching [sykeSourceMinZoom] exactly (no
  /// source data exists below it to hide anyway). Still not treated as
  /// final — subject to further physical calibration.
  static const int sykeBathymetryPresentationMinZoom = 10;

  /// Presentational `minzoom` for the depth-label symbol layer (TD-027
  /// depth-label investigation) — deliberately **higher** than
  /// [sykeBathymetryPresentationMinZoom]: at z10–z11 a whole multi-lake
  /// area is typically in view, where every visible contour competing for
  /// label text would be unreadable clutter before symbol-spacing/collision
  /// can help. Labels only start once individual lake basins are already
  /// spatially separated on screen. **First-pass value, not yet physically
  /// calibrated** — every other zoom constant in this file needed at least
  /// one on-device revision; this one should be expected to as well.
  static const int sykeContourLabelsPresentationMinZoom = 12;

  /// Returns a JSON-encoded MapLibre GL style document for [baseMap],
  /// consulting the real `MapTilerConfig` for provider availability.
  /// [mmlStyleFragmentJson] and [sykeBathymetryLocalBaseUrl] are passed
  /// straight through — see [buildStyle].
  String styleFor(
    BaseMap baseMap, {
    String? mmlStyleFragmentJson,
    String? sykeBathymetryLocalBaseUrl,
  }) {
    return buildStyle(
      baseMap,
      mapTilerAvailable: !MapTilerConfig.isMissing,
      mmlStyleFragmentJson: mmlStyleFragmentJson,
      sykeBathymetryLocalBaseUrl: sykeBathymetryLocalBaseUrl,
    );
  }

  /// The composition logic behind [styleFor], with MapTiler availability
  /// passed in explicitly rather than read from `MapTilerConfig` directly —
  /// the same testability seam this class has always exposed, now also
  /// covering the MML fragment and the SYKE overlay:
  ///
  /// * [mmlStyleFragmentJson]: `null` omits MML's cartography entirely
  ///   (Ilmakuva always; Maastokartta when MML is unconfigured or its
  ///   fragment could not be fetched — TD-027 §3F Failure behavior).
  /// * [sykeBathymetryLocalBaseUrl]: `null` omits the bathymetry overlay
  ///   entirely (e.g. the bundled asset failed to extract). Non-null adds
  ///   it for **either** selection — the overlay is base-map-agnostic
  ///   (MFS-027 Revision 7 Design Notes).
  String buildStyle(
    BaseMap baseMap, {
    required bool mapTilerAvailable,
    String? mmlStyleFragmentJson,
    String? sykeBathymetryLocalBaseUrl,
  }) {
    final sources = <String, dynamic>{};
    final layers = <dynamic>[];
    var glyphs = defaultGlyphsUrl;
    // Tracks whether [glyphs] ends up being MML's own real host (rewritten
    // to this app's local proxy) rather than [defaultGlyphsUrl] — the same
    // condition `MapScreen._mmlFragmentIncludedInCurrentStyle` already
    // tracks for the fishing-spot symbol layer's own `textFont` choice, now
    // also driving the SYKE depth-label layer's font (TD-027 depth-label
    // font investigation): a style only ever declares one `glyphs` root, so
    // every symbol layer in it must request a font that actually exists on
    // that specific host.
    var mmlGlyphsActive = false;

    switch (baseMap) {
      case BaseMap.maastokartta:
        if (mapTilerAvailable) {
          _mapTiler.addOutdoorFragment(sources, layers);
        }
        if (mmlStyleFragmentJson != null) {
          final fragment =
              jsonDecode(mmlStyleFragmentJson) as Map<String, dynamic>;
          sources.addAll(fragment['sources'] as Map<String, dynamic>);
          layers.addAll(fragment['layers'] as List<dynamic>);
          glyphs = fragment['glyphs'] as String;
          mmlGlyphsActive = true;
        }
      case BaseMap.ilmakuva:
        if (mapTilerAvailable) {
          _mapTiler.addSatelliteHybridFragment(sources, layers);
        }
      // MML is deliberately never referenced in this branch, regardless of
      // [mmlStyleFragmentJson] — MML is not part of the Ilmakuva
      // composition (ADR-0009, MFS-027).
    }

    if (sykeBathymetryLocalBaseUrl != null) {
      _addSykeBathymetryFragment(
        sources,
        layers,
        sykeBathymetryLocalBaseUrl,
        contourLabelFont: mmlGlyphsActive
            ? sykeContourLabelMmlFont
            : sykeContourLabelDefaultFont,
      );
    }

    return jsonEncode({
      'version': 8,
      'glyphs': glyphs,
      'sources': sources,
      'layers': layers,
    });
  }

  /// Adds the SYKE bathymetry overlay's source to [sources], and its
  /// contour-line layer to [layers] (TD-027 §22), appended after whichever
  /// base-map layers already exist, so it renders above the base map and
  /// below whatever application-owned layers `MapScreen` adds afterward, by
  /// the same append-order construction this document already relies on
  /// throughout.
  ///
  /// **Depth-area fill — disabled from the normal presentation after
  /// physical Android testing, not removed from the data.** The source
  /// declared here still exposes both the `depth_areas` and `contours`
  /// source-layers (the bundled MBTiles asset and
  /// `tools/syke_bathymetry/build_mbtiles.py` are unchanged — the fill data
  /// remains fully present for a possible future depth-shading revision),
  /// but a real-device test found the depth-area fill's large, flat-colored
  /// polygons looked visually wrong laid directly over MML's own normal
  /// lake surface, especially at lower zoom: a lake that already reads
  /// correctly as "a lake" gained a second, competing blue shape on top of
  /// it. The product decision this milestone implements instead: the normal
  /// Maastokartta presentation shows **depth contour lines only**, in the
  /// same spirit as bathymetry on a traditional Finnish topographic map,
  /// with MML's own lake rendering fully visible underneath. `[sykeDepthAreasLayerId]`/
  /// `[sykeDepthAreasSourceLayer]` are kept, unused, as the documented
  /// identifiers for that future re-enablement — deleting them would not
  /// remove any real complexity, only lose the record of what they were
  /// (mirroring `BaseMap.ilmakuva`'s own unused-but-retained MML-specific
  /// getters, TD-027 §2).
  void _addSykeBathymetryFragment(
    Map<String, dynamic> sources,
    List<dynamic> layers,
    String localBaseUrl, {
    required String contourLabelFont,
  }) {
    sources[sykeBathymetrySourceId] = {
      'type': 'vector',
      'tiles': ['$localBaseUrl/syke/bathymetry/{z}/{x}/{y}.pbf'],
      'minzoom': sykeSourceMinZoom,
      'maxzoom': sykeSourceMaxZoom,
    };

    layers.add({
      'id': sykeContoursLayerId,
      'type': 'line',
      'source': sykeBathymetrySourceId,
      'source-layer': sykeContoursSourceLayer,
      'minzoom': sykeBathymetryPresentationMinZoom,
      'paint': {
        // Restrained bathymetric blue, deliberately deeper/more saturated
        // than water-fill blues so it reads as depth information rather
        // than blending into the lake surface or MML's own (brown/grey)
        // terrain contours — but thin and modestly opaque, since physical
        // testing specifically flagged the previous presentation
        // (depth-area fill plus this line) as too visually dominant.
        'line-color': '#0f5c8c',
        'line-width': 0.6,
        'line-opacity': 0.75,
      },
    });

    layers.add(_sykeContourLabelsLayer(contourLabelFont));
  }

  /// Builds the depth-label symbol layer (TD-027 depth-label investigation) —
  /// presentation-only, reading the existing `depth_m` MVT attribute
  /// straight from the same `contours` source-layer the line layer above
  /// already uses. No MBTiles/pipeline change of any kind was needed:
  /// `tools/syke_bathymetry/build_mbtiles.py`'s `normalize_contours()`
  /// already guarantees every tiled contour carries a usable `depth_m`
  /// (features with no parseable depth are dropped before tiling, not
  /// tiled with a missing attribute).
  ///
  /// Always appended immediately after [sykeContoursLayerId] in [layers] —
  /// same source, same source-layer, rendered directly above its own line
  /// — and, because it is added after (not before) every MML/MapTiler
  /// layer already in the document, MapLibre's collision system already
  /// gives MML's own place/lake-name symbol layers placement priority over
  /// these depth labels for free: labels in earlier-listed layers block
  /// labels in later ones, and neither layer sets `text-allow-overlap`/
  /// `text-ignore-placement`, so no explicit reordering or overlap
  /// override is needed to satisfy "must not overwhelm existing map
  /// labels."
  ///
  /// `depth_m == 0` (the shoreline contour) is filtered out: it is ~35% of
  /// all contour features (confirmed directly against the bundled MBTiles
  /// asset) and labeling it would trace "0 m" along every lake's already-
  /// visible shoreline — clutter, not information, for a fishing map.
  ///
  /// Every layout constant below (`minzoom` 12, `symbol-spacing` 350,
  /// `text-size` 11) is this feature's **first physical-test build** —
  /// not yet confirmed on a real device, unlike the other SYKE constants
  /// in this file which were already revised after Android testing.
  ///
  /// [textFont] is always exactly one font name — [sykeContourLabelMmlFont]
  /// or [sykeContourLabelDefaultFont], chosen by [buildStyle] to match
  /// whichever `glyphs` host this specific generated style actually
  /// declares. Never MapLibre's own multi-font `text-font` default: that
  /// combined fontstack request is confirmed to fail entirely against both
  /// glyph hosts this app ever configures, which was the root cause of the
  /// depth labels not rendering on a physical device (TD-027 depth-label
  /// font investigation) — the same failure mode already known and worked
  /// around for the fishing-spot symbol layer (`MapScreen`).
  Map<String, dynamic> _sykeContourLabelsLayer(String textFont) => {
    'id': sykeContourLabelsLayerId,
    'type': 'symbol',
    'source': sykeBathymetrySourceId,
    'source-layer': sykeContoursSourceLayer,
    'minzoom': sykeContourLabelsPresentationMinZoom,
    'filter': ['!=', ['get', 'depth_m'], 0],
    'layout': {
      'symbol-placement': 'line',
      'symbol-spacing': 350,
      'text-field': [
        'concat',
        ['to-string', ['get', 'depth_m']],
        ' m',
      ],
      'text-font': [textFont],
      'text-size': 11,
      'text-rotation-alignment': 'map',
      'text-pitch-alignment': 'viewport',
      'text-keep-upright': true,
      'text-max-angle': 45,
      'text-padding': 2,
      'text-allow-overlap': false,
      'text-ignore-placement': false,
    },
    'paint': {
      'text-color': '#0f5c8c',
      'text-halo-color': '#ffffff',
      'text-halo-width': 1.2,
    },
  };
}
