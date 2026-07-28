import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for facts about MML's real v21 vector product that
/// `MmlVectorProxyService`/`WorldwideStyleFactory` (TD-027 §3F, the
/// production Maastokartta path) rely on.
/// `mml_v21_backgroundmap_style_fixture.json` is a trimmed-but-faithful
/// excerpt of MML's own live v21 "backgroundmap" style response (fetched
/// 2026-07 with a real, never-committed API key, which was redacted before
/// this fixture was written) — real layer ids and `source-layer` names,
/// real structure, just far fewer of the ~100 total layers (most of the
/// omitted ones are duplicate road-grade variants for tunnels/bridges, not
/// a different information category).
///
/// This asserts facts about MML's real product, not about this project's
/// own code — it exists so a future MML v21 style change that removes
/// something this project's design relies on (e.g. contour lines, the
/// `korkeus` source-layer, or the single unconditional `background` layer
/// `MmlVectorProxyService` strips) is caught, rather than silently assumed
/// to still hold.
void main() {
  late Map<String, dynamic> style;

  setUpAll(() {
    final raw = File(
      'test/fixtures/mml_v21_backgroundmap_style_fixture.json',
    ).readAsStringSync();
    style = jsonDecode(raw) as Map<String, dynamic>;
  });

  test('is a version 8 MapLibre/Mapbox GL style', () {
    expect(style['version'], 8);
  });

  test(
    'declares a single vector source over Web Mercator, referencing v21',
    () {
      final sources = style['sources'] as Map<String, dynamic>;
      expect(sources, hasLength(1));
      final source = sources.values.first as Map<String, dynamic>;
      expect(source['type'], 'vector');
      final url = source['url'] as String;
      expect(url, contains('/v21/'));
      expect(url, contains('WGS84_Pseudo-Mercator'));
    },
  );

  test('never contains a hardcoded, non-redacted API key', () {
    final raw = jsonEncode(style);
    expect(raw, isNot(contains(RegExp(r'api-key=[0-9a-fA-F-]{20,}'))));
  });

  test('declares a glyphs URL (required for any text-field label layer)', () {
    expect(style['glyphs'], isA<String>());
    expect(style['glyphs'], contains('{fontstack}'));
    expect(style['glyphs'], contains('{range}'));
  });

  Set<String> sourceLayersUsedBy(String layerId) {
    final layers = style['layers'] as List<dynamic>;
    return {
      for (final layer in layers.cast<Map<String, dynamic>>())
        if (layer['id'] == layerId) layer['source-layer'] as String,
    };
  }

  test('contains a terrain contour-line layer sourced from "korkeus" — '
      'MML\'s elevation contour source-layer, not a lake-depth/bathymetric '
      'one', () {
    expect(sourceLayersUsedBy('korkeus_viiva'), {'korkeus'});
  });

  test('contains water-body fill/line and stream/river line layers', () {
    expect(sourceLayersUsedBy('vesisto_alue'), {'vesisto_alue'});
    expect(sourceLayersUsedBy('vesisto_viiva'), {'vesisto_viiva'});
  });

  test('contains a roads/paths layer sourced from "liikenne"', () {
    final layers = style['layers'] as List<dynamic>;
    final liikenneLayerIds = [
      for (final layer in layers.cast<Map<String, dynamic>>())
        if (layer['source-layer'] == 'liikenne') layer['id'] as String,
    ];
    expect(liikenneLayerIds, isNotEmpty);
    expect(liikenneLayerIds, contains('ajotie, pinnalla'));
    expect(
      liikenneLayerIds,
      contains('kavely- ja pyoratie, paallystamaton, pinnalla'),
    );
  });

  test('contains a building fill layer sourced from "rakennus"', () {
    expect(sourceLayersUsedBy('rakennus'), {'rakennus'});
  });

  test('contains land-use/terrain-class fill layers', () {
    expect(sourceLayersUsedBy('maankaytto'), {'maankaytto'});
    expect(sourceLayersUsedBy('maasto_alue'), {'maasto_alue'});
  });

  test('contains place-name label layers sourced from "nimisto"', () {
    expect(sourceLayersUsedBy('nimisto'), {'nimisto'});
  });

  test('contains an administrative-boundary line layer', () {
    expect(sourceLayersUsedBy('hallintorajat'), {'hallintoalue'});
  });

  test('contains exactly one layer with no "source" at all (the '
      'unconditional "background" layer `MmlVectorProxyService` strips, '
      'TD-027 §3F) — every other layer is scoped to a real source-layer '
      'and therefore only paints where that layer genuinely has features', () {
    final layers = (style['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
    final noSourceLayers = layers.where((l) => l['source'] == null).toList();
    expect(noSourceLayers, hasLength(1));
    expect(noSourceLayers.single['id'], 'background');
    expect(noSourceLayers.single['type'], 'background');
  });

  test('contains no bathymetric/lake-depth-contour source-layer anywhere — '
      'only terrain elevation ("korkeus"/"korkeusalue") and water-extent '
      '("vesisto_*") source-layers are referenced', () {
    final layers = style['layers'] as List<dynamic>;
    final sourceLayers = {
      for (final layer in layers.cast<Map<String, dynamic>>())
        if (layer['source-layer'] != null) layer['source-layer'] as String,
    };
    expect(
      sourceLayers.where(
        (name) =>
            name.toLowerCase().contains('syvyys') || // Finnish: depth
            name.toLowerCase().contains('bathy'),
      ),
      isEmpty,
    );
  });
}
