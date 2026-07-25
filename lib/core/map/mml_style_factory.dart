import 'dart:convert';

import 'package:fishing_app/core/map/base_map.dart';

/// Builds a minimal MapLibre GL style document for a single MML raster WMTS
/// base map. One source, one layer — this is not a general-purpose style
/// builder, and it is not meant to grow beyond what these two base maps need
/// (ADR-0008: raster, not vector; no custom Fishing App styling).
class MmlStyleFactory {
  const MmlStyleFactory({required this.apiKey});

  final String apiKey;

  /// WMTS REST base path. Verified against live GetCapabilities (TD-026
  /// §0); the exact `ResourceURL` templates for both layers are:
  /// `.../maastokartta/default/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.png`
  /// and
  /// `.../ortokuva/default/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.jpg`.
  static const _wmtsBase =
      'https://avoin-karttakuva.maanmittauslaitos.fi/avoin/wmts/1.0.0';

  /// Verified exact identifier from live GetCapabilities (TD-026 §0).
  /// Substituted directly for MML's generic `{TileMatrixSet}` template
  /// token, since this factory only ever targets this one matrix set.
  static const _matrixSet = 'WGS84_Pseudo-Mercator';

  /// Verified from live GetCapabilities (TD-026 §0): both `maastokartta`
  /// and `ortokuva` support TileMatrix identifiers `0` through `18` under
  /// `WGS84_Pseudo-Mercator`, with no per-layer restriction.
  static const _minZoom = 0;
  static const _maxZoom = 18;

  static const _sourceId = 'mml-base-source';
  static const _layerId = 'mml-base-layer';

  /// A MapLibre-style-spec `glyphs` URL template, required for *any*
  /// symbol layer that renders text via `text-field` (MapLibre GL style
  /// spec: `glyphs` — "A URL template for loading signed-distance-field
  /// glyph sets in PBF format"). Without one, the map has no font glyphs to
  /// rasterize text with: the fishing-spot circle layer (no text)
  /// rendered correctly on a physical device, but its symbol layer's name
  /// label silently rendered nothing — the previous placeholder demo style
  /// (`https://demotiles.maplibre.org/style.json`) happened to already
  /// include a working `glyphs` URL, which this project's own minimal,
  /// locally-generated style did not carry over.
  ///
  /// Points at OpenMapTiles' public glyph CDN — a genuinely different,
  /// widely-used, general-purpose font-glyph host (not the old MapLibre
  /// demo server), consistent with `textFont`'s existing "Open Sans
  /// Regular" fontstack already used by `MapScreen`'s symbol layer. Fonts
  /// are generic Unicode glyph shapes, not MML map data, so depending on
  /// this separate, dedicated glyph host does not compromise ADR-0008's
  /// choice of MML as the authoritative *map data* source. This is a new,
  /// real network dependency for label rendering specifically — a fully
  /// offline-first alternative (bundling glyph PBFs as local assets) is a
  /// reasonable future improvement, not attempted here as the smallest fix
  /// for the reported defect.
  static const _glyphsUrl =
      'https://fonts.openmaptiles.org/{fontstack}/{range}.pbf';

  /// Returns a JSON-encoded MapLibre GL style document for [baseMap].
  ///
  /// The tile URL template's token order is `{z}/{y}/{x}` — not
  /// `{z}/{x}/{y}`. This is verified directly from live GetCapabilities
  /// (TD-026 §0): MML's own `ResourceURL` templates order
  /// `{TileMatrix}/{TileRow}/{TileCol}` (row before column, the opposite of
  /// the generic OGC-default order), and the verified standard-XYZ scheme
  /// means `{TileRow}` is MapLibre's `{y}` and `{TileCol}` is MapLibre's
  /// `{x}`, with no further inversion. Getting this order wrong silently
  /// produces a mirrored/transposed map with no error thrown.
  ///
  /// The file extension is not the same for both base maps — Maastokartta
  /// is `.png`, Ortokuva is `.jpg` — hence branching on
  /// `baseMap.tileFileExtension` below rather than a single hardcoded
  /// extension.
  String styleFor(BaseMap baseMap) {
    final tileUrl =
        '$_wmtsBase/${baseMap.mmlLayerId}/default/$_matrixSet/{z}/{y}/{x}'
        '${baseMap.tileFileExtension}'
        // Verified from MML's own API-key instructions page, not from
        // GetCapabilities (TD-026 §0) — GetCapabilities only states that a
        // credential is required, not how to supply one.
        '?api-key=$apiKey';

    final style = {
      'version': 8,
      'glyphs': _glyphsUrl,
      'sources': {
        _sourceId: {
          'type': 'raster',
          'tiles': [tileUrl],
          'tileSize': 256,
          'minzoom': _minZoom,
          'maxzoom': _maxZoom,
          'attribution': baseMap.attributionText,
        },
      },
      'layers': [
        {'id': _layerId, 'type': 'raster', 'source': _sourceId},
      ],
    };

    return jsonEncode(style);
  }
}
