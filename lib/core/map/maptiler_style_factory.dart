/// Builds MapLibre GL raster source/layer fragments for MapTiler's Outdoor
/// and Satellite Hybrid products, using the WMTS-analogous mechanics
/// confirmed directly against MapTiler's own official documentation and,
/// for zoom range, MapTiler's authenticated TileJSON (TD-027 §0). Each
/// method mutates the caller-supplied `sources`/`layers` collections rather
/// than returning a complete style document — the two products are
/// composed differently per `BaseMap` selection by `WorldwideStyleFactory`,
/// which this class knows nothing about (TD-027 §3).
///
/// Deliberately not a general-purpose "any MapTiler map id" builder: only
/// the two products this milestone actually uses (Outdoor, Satellite
/// Hybrid) are exposed, as two named methods, so a call site can never
/// accidentally mix up `outdoor-v4` and `hybrid-v4`.
class MapTilerStyleFactory {
  const MapTilerStyleFactory({required this.apiKey});

  final String apiKey;

  /// Maps API raster tile base path. Verified against official MapTiler
  /// documentation (TD-027 §0): `.../maps/{mapId}/{tileSize}/{z}/{x}/{y}.{format}?key=<key>`.
  static const _mapsBase = 'https://api.maptiler.com/maps';

  static const _outdoorMapId = 'outdoor-v4';
  static const _satelliteHybridMapId = 'hybrid-v4';

  /// The only allowed `tileSize` for this endpoint (TD-027 §0).
  static const _tileSize = 256;

  /// Confirmed directly from both styles' own authenticated TileJSON
  /// (TD-027 §0): `minzoom: 0`, `maxzoom: 22` — identical for Outdoor and
  /// Satellite Hybrid. Deliberately not shared with MML's own 0–18 range
  /// (`MmlStyleFactory`): the two providers have genuinely different native
  /// ranges, and forcing one artificial common maximum would either cap
  /// MapTiler's real available detail or falsely claim resolution MML does
  /// not have.
  static const _minZoom = 0;
  static const _maxZoom = 22;

  static const outdoorSourceId = 'maptiler-outdoor-source';
  static const outdoorLayerId = 'maptiler-outdoor-layer';
  static const satelliteHybridSourceId = 'maptiler-hybrid-source';
  static const satelliteHybridLayerId = 'maptiler-hybrid-layer';

  /// Adds MapTiler Outdoor's raster source/layer to [sources]/[layers].
  ///
  /// The tile URL token order is `{z}/{x}/{y}` — the standard order MapTiler
  /// documents, and the *opposite* of MML's reversed `{z}/{y}/{x}`
  /// `ResourceURL` convention (`MmlStyleFactory`). Do not apply MML's
  /// row-before-column reversal here.
  void addOutdoorFragment(Map<String, dynamic> sources, List<dynamic> layers) {
    sources[outdoorSourceId] = _rasterSource(_outdoorMapId);
    layers.add(_rasterLayer(outdoorSourceId, outdoorLayerId));
  }

  /// Adds MapTiler Satellite Hybrid's raster source/layer to
  /// [sources]/[layers]. Hybrid bakes in labels/roads/place names over its
  /// own imagery (confirmed from MapTiler's official product page, TD-027
  /// §0), so no separate label layer is composed by this project.
  void addSatelliteHybridFragment(
    Map<String, dynamic> sources,
    List<dynamic> layers,
  ) {
    sources[satelliteHybridSourceId] = _rasterSource(_satelliteHybridMapId);
    layers.add(_rasterLayer(satelliteHybridSourceId, satelliteHybridLayerId));
  }

  Map<String, dynamic> _rasterSource(String mapId) {
    return {
      'type': 'raster',
      'tiles': ['$_mapsBase/$mapId/$_tileSize/{z}/{x}/{y}.png?key=$apiKey'],
      'tileSize': _tileSize,
      'minzoom': _minZoom,
      'maxzoom': _maxZoom,
    };
  }

  Map<String, dynamic> _rasterLayer(String sourceId, String layerId) {
    return {'id': layerId, 'type': 'raster', 'source': sourceId};
  }
}
