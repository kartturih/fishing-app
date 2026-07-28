import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/map/base_map.dart';
import 'package:fishing_app/core/map/maptiler_style_factory.dart';
import 'package:fishing_app/core/map/worldwide_style_factory.dart';

void main() {
  const factory = WorldwideStyleFactory(
    mapTilerStyleFactory: MapTilerStyleFactory(apiKey: 'test-maptiler-key'),
  );
  const sykeLocalBaseUrl = 'http://127.0.0.1:54321';

  // A synthetic, already-fetched-and-rewritten MML fragment — never a real
  // network fetch, mirroring how `MmlVectorProxyService.fetchMmlStyleFragment`
  // is only ever awaited by `MapScreen`, never by this pure factory.
  String syntheticMmlFragment() => jsonEncode({
    'sources': {
      'taustakartta': {
        'type': 'vector',
        'tiles': ['http://127.0.0.1:9999/mml/v21/tiles/{z}/{x}/{y}.pbf'],
        'minzoom': 0,
        'maxzoom': 18,
      },
    },
    'layers': [
      {
        'id': 'vesisto_alue',
        'type': 'fill',
        'source': 'taustakartta',
        'source-layer': 'vesisto_alue',
      },
    ],
    'glyphs': 'http://127.0.0.1:9999/mml/v21/glyphs/{fontstack}/{range}.pbf',
  });

  Map<String, dynamic> decoded(String json) =>
      jsonDecode(json) as Map<String, dynamic>;

  group('Maastokartta', () {
    test('both MapTiler Outdoor and the MML vector fragment are present '
        'when both are available, with Outdoor listed before MML in the '
        'generated layers array (the ordering mechanism relied on for '
        'correct stacking — TD-027 §3F)', () {
      final style = decoded(
        factory.buildStyle(
          BaseMap.maastokartta,
          mapTilerAvailable: true,
          mmlStyleFragmentJson: syntheticMmlFragment(),
        ),
      );

      final sources = style['sources'] as Map<String, dynamic>;
      expect(sources, contains(MapTilerStyleFactory.outdoorSourceId));
      expect(sources, contains('taustakartta'));
      expect((sources['taustakartta'] as Map)['type'], 'vector');

      final layers = style['layers'] as List<dynamic>;
      expect((layers[0] as Map)['id'], MapTilerStyleFactory.outdoorLayerId);
      expect((layers[1] as Map)['id'], 'vesisto_alue');

      // The MML fragment's own glyphs URL wins for Maastokartta+MML.
      expect(
        style['glyphs'],
        'http://127.0.0.1:9999/mml/v21/glyphs/{fontstack}/{range}.pbf',
      );
    });

    test('only the MapTiler Outdoor fragment is present when the MML '
        'fragment is null (unconfigured, or the fetch failed — TD-027 §3F '
        'Failure behavior)', () {
      final style = decoded(
        factory.buildStyle(
          BaseMap.maastokartta,
          mapTilerAvailable: true,
          mmlStyleFragmentJson: null,
        ),
      );

      final sources = style['sources'] as Map<String, dynamic>;
      expect(sources.length, 1);
      expect(sources, contains(MapTilerStyleFactory.outdoorSourceId));
      expect(style['glyphs'], WorldwideStyleFactory.defaultGlyphsUrl);
    });

    test('only the MML vector fragment is present when MapTiler is '
        'unavailable', () {
      final style = decoded(
        factory.buildStyle(
          BaseMap.maastokartta,
          mapTilerAvailable: false,
          mmlStyleFragmentJson: syntheticMmlFragment(),
        ),
      );

      final sources = style['sources'] as Map<String, dynamic>;
      expect(sources.length, 1);
      expect(sources, isNot(contains(MapTilerStyleFactory.outdoorSourceId)));
    });

    test('neither fragment is present when both are unavailable — an '
        'empty, still-valid (glyphs-only) style, exactly like the existing '
        'blank-style fallback shape', () {
      final style = decoded(
        factory.buildStyle(
          BaseMap.maastokartta,
          mapTilerAvailable: false,
          mmlStyleFragmentJson: null,
        ),
      );

      expect(style['sources'], isEmpty);
      expect(style['layers'], isEmpty);
      expect(style['glyphs'], WorldwideStyleFactory.defaultGlyphsUrl);
    });
  });

  group('Ilmakuva', () {
    test('only the Satellite Hybrid fragment is present when MapTiler is '
        'available, regardless of the MML fragment being supplied', () {
      for (final mmlFragment in [syntheticMmlFragment(), null]) {
        final style = decoded(
          factory.buildStyle(
            BaseMap.ilmakuva,
            mapTilerAvailable: true,
            mmlStyleFragmentJson: mmlFragment,
          ),
        );

        final sources = style['sources'] as Map<String, dynamic>;
        expect(sources.length, 1);
        expect(sources, contains(MapTilerStyleFactory.satelliteHybridSourceId));
      }
    });

    test('no MML source/layer is ever present for Ilmakuva, under any MML '
        'fragment availability — this is the direct regression guard for '
        'the product decision that MML is not used by this selection '
        '(ADR-0009, MFS-027)', () {
      for (final mmlFragment in [syntheticMmlFragment(), null]) {
        for (final mapTilerAvailable in [true, false]) {
          final style = decoded(
            factory.buildStyle(
              BaseMap.ilmakuva,
              mapTilerAvailable: mapTilerAvailable,
              mmlStyleFragmentJson: mmlFragment,
            ),
          );

          final sources = (style['sources'] as Map<String, dynamic>).keys;
          for (final sourceId in sources) {
            expect(
              sourceId,
              anyOf(
                MapTilerStyleFactory.satelliteHybridSourceId,
                WorldwideStyleFactory.sykeBathymetrySourceId,
              ),
            );
          }
        }
      }
    });

    test('no source/layer at all when MapTiler is unavailable — an empty, '
        'still-valid style, since Ilmakuva has no fallback provider', () {
      final style = decoded(
        factory.buildStyle(
          BaseMap.ilmakuva,
          mapTilerAvailable: false,
          mmlStyleFragmentJson: syntheticMmlFragment(),
        ),
      );

      expect(style['sources'], isEmpty);
      expect(style['layers'], isEmpty);
      expect(style['glyphs'], isNotNull);
    });
  });

  group('SYKE bathymetry overlay (TD-027 §20–§22, Revision 7; presentation '
      'revised after physical Android testing)', () {
    test('the source is present for Maastokartta when '
        'sykeBathymetryLocalBaseUrl is supplied, with the contour line '
        'layer above the base map', () {
      final style = decoded(
        factory.buildStyle(
          BaseMap.maastokartta,
          mapTilerAvailable: true,
          mmlStyleFragmentJson: syntheticMmlFragment(),
          sykeBathymetryLocalBaseUrl: sykeLocalBaseUrl,
        ),
      );

      final sources = style['sources'] as Map<String, dynamic>;
      expect(sources, contains(WorldwideStyleFactory.sykeBathymetrySourceId));
      final sykeSource =
          sources[WorldwideStyleFactory.sykeBathymetrySourceId] as Map;
      expect(sykeSource['type'], 'vector');
      expect(
        (sykeSource['tiles'] as List).single,
        '$sykeLocalBaseUrl/syke/bathymetry/{z}/{x}/{y}.pbf',
      );

      final layers = (style['layers'] as List<dynamic>).cast<Map>();
      final contourIndex = layers.indexWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContoursLayerId,
      );
      expect(contourIndex, greaterThanOrEqualTo(0));

      // Above the base map (MapTiler at index 0, MML at index 1), matching
      // the required base-map -> MML -> SYKE ordering.
      expect(contourIndex, greaterThan(1));
    });

    test(
      'the depth-area fill layer is NOT part of the generated style — '
      'disabled from the normal presentation after physical Android '
      'testing found it visually dominant/incorrect over MML\'s own lake '
      'rendering (this milestone\'s own product decision), even though '
      'the source (and therefore the underlying depth_areas data) remains '
      'fully present',
      () {
        final style = decoded(
          factory.buildStyle(
            BaseMap.maastokartta,
            mapTilerAvailable: true,
            sykeBathymetryLocalBaseUrl: sykeLocalBaseUrl,
          ),
        );

        final layers = (style['layers'] as List<dynamic>).cast<Map>();
        expect(
          layers.any(
            (l) => l['id'] == WorldwideStyleFactory.sykeDepthAreasLayerId,
          ),
          isFalse,
        );
        expect(
          layers.any((l) => l['type'] == 'fill' && l['source'] == WorldwideStyleFactory.sykeBathymetrySourceId),
          isFalse,
          reason: 'no fill layer of any id sourced from the SYKE source',
        );

        // The data itself is untouched — only the presentation layer is
        // disabled. The source still declares the same tileset (both
        // depth_areas and contours source-layers remain in the bundled
        // MBTiles asset and its own build pipeline, unaffected by this
        // change) and `sykeDepthAreasLayerId`/`sykeDepthAreasSourceLayer`
        // remain defined identifiers for a possible future revision.
        final sources = style['sources'] as Map<String, dynamic>;
        expect(sources, contains(WorldwideStyleFactory.sykeBathymetrySourceId));
        expect(WorldwideStyleFactory.sykeDepthAreasSourceLayer, 'depth_areas');
      },
    );

    test('is present for Ilmakuva too — the overlay is base-map-agnostic '
        '(MFS-027 Revision 7 Design Notes)', () {
      final style = decoded(
        factory.buildStyle(
          BaseMap.ilmakuva,
          mapTilerAvailable: true,
          sykeBathymetryLocalBaseUrl: sykeLocalBaseUrl,
        ),
      );

      final sources = style['sources'] as Map<String, dynamic>;
      expect(sources, contains(WorldwideStyleFactory.sykeBathymetrySourceId));
      final layers = (style['layers'] as List<dynamic>).cast<Map>();
      expect(
        layers.any((l) => l['id'] == WorldwideStyleFactory.sykeContoursLayerId),
        isTrue,
      );
    });

    test('is absent for either selection when sykeBathymetryLocalBaseUrl is '
        'null (asset failed to extract, or the proxy service is not '
        'running)', () {
      for (final baseMap in BaseMap.values) {
        final style = decoded(
          factory.buildStyle(
            baseMap,
            mapTilerAvailable: true,
            sykeBathymetryLocalBaseUrl: null,
          ),
        );

        final sources = style['sources'] as Map<String, dynamic>;
        expect(
          sources,
          isNot(contains(WorldwideStyleFactory.sykeBathymetrySourceId)),
        );
      }
    });

    test('the contour layer carries the twice-revised presentational '
        'minzoom (10, lowered from the intermediate 11 after physical '
        'Android testing found 11 too high once the depth-area fill was '
        'already disabled — TD-027 §22) — a layer property, not a source '
        'property, mirroring MmlStyleFactory.presentationMinZoom\'s own '
        'already-established distinction', () {
      final style = decoded(
        factory.buildStyle(
          BaseMap.maastokartta,
          mapTilerAvailable: true,
          sykeBathymetryLocalBaseUrl: sykeLocalBaseUrl,
        ),
      );

      expect(WorldwideStyleFactory.sykeBathymetryPresentationMinZoom, 10);

      final layers = (style['layers'] as List<dynamic>).cast<Map>();
      final contourLayer = layers.firstWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContoursLayerId,
      );
      expect(
        contourLayer['minzoom'],
        WorldwideStyleFactory.sykeBathymetryPresentationMinZoom,
      );
    });

    test('the contour layer never declares a "maxzoom" of its own — the '
        'one concrete way a layer property could reintroduce the '
        '"disappears when zooming in close" bug being fixed here. Zooms '
        'above the source\'s own maxzoom are left entirely to MapLibre\'s '
        'standard vector-source overzoom (client-side reuse of the last '
        'real tile), never a layer-level cutoff', () {
      final style = decoded(
        factory.buildStyle(
          BaseMap.maastokartta,
          mapTilerAvailable: true,
          sykeBathymetryLocalBaseUrl: sykeLocalBaseUrl,
        ),
      );

      final layers = (style['layers'] as List<dynamic>).cast<Map>();
      final contourLayer = layers.firstWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContoursLayerId,
      );
      expect(contourLayer.containsKey('maxzoom'), isFalse);
    });

    test('the source declares a contiguous, honest zoom range — minzoom '
        '10 (matching the presentation minzoom exactly; no source data '
        'exists below it) through maxzoom 14 (matching '
        'tools/syke_bathymetry/build_mbtiles.py\'s own contiguous z10–z14 '
        'tiling range, with no gaps) — the root-cause fix for the '
        'reported close-zoom flicker/disappearance: a source that '
        'honestly declares a range it actually tiles *continuously* is '
        'exactly the precondition MapLibre\'s own vector-source spec '
        'requires for correct behavior both within the declared range and '
        'via overzoom beyond it', () {
      final style = decoded(
        factory.buildStyle(
          BaseMap.maastokartta,
          mapTilerAvailable: true,
          sykeBathymetryLocalBaseUrl: sykeLocalBaseUrl,
        ),
      );

      final source =
          (style['sources']
                  as Map<String, dynamic>)[WorldwideStyleFactory.sykeBathymetrySourceId]
              as Map;
      expect(source['minzoom'], 10);
      expect(source['maxzoom'], 14);
      expect(WorldwideStyleFactory.sykeSourceMinZoom, 10);
      expect(WorldwideStyleFactory.sykeSourceMaxZoom, 14);
      // Presentation minzoom and source minzoom are now equal by design —
      // no source data exists below the zoom the layer would show it at
      // anyway, so tiling it would be pure waste.
      expect(
        WorldwideStyleFactory.sykeBathymetryPresentationMinZoom,
        WorldwideStyleFactory.sykeSourceMinZoom,
      );
    });

    test('the contour layer uses a restrained, thin, modestly-opaque line '
        'style with no accompanying fill — deliberately less visually '
        'dominant than the previous depth-area-fill presentation', () {
      final style = decoded(
        factory.buildStyle(
          BaseMap.maastokartta,
          mapTilerAvailable: true,
          sykeBathymetryLocalBaseUrl: sykeLocalBaseUrl,
        ),
      );

      final layers = (style['layers'] as List<dynamic>).cast<Map>();
      final contourLayer = layers.firstWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContoursLayerId,
      );
      expect(contourLayer['type'], 'line');
      final paint = contourLayer['paint'] as Map;
      expect(paint['line-width'], lessThan(1.0));
      expect(paint['line-opacity'], lessThan(1.0));
      expect(paint.containsKey('line-blur'), isFalse);
    });
  });

  group('SYKE contour depth labels (TD-027 depth-label investigation; '
      'first physical-test build — minzoom/spacing/text-size not yet '
      'confirmed on a real device)', () {
    List<Map<dynamic, dynamic>> layersFor({
      BaseMap baseMap = BaseMap.maastokartta,
    }) {
      final style = decoded(
        factory.buildStyle(
          baseMap,
          mapTilerAvailable: true,
          mmlStyleFragmentJson: syntheticMmlFragment(),
          sykeBathymetryLocalBaseUrl: sykeLocalBaseUrl,
        ),
      );
      return (style['layers'] as List<dynamic>).cast<Map>();
    }

    test('the label layer exists, sourced from the existing SYKE '
        'bathymetry source and its "contours" source-layer — the same '
        'source/source-layer the line layer already uses, no new source '
        'introduced', () {
      final layers = layersFor();
      final labelLayer = layers.firstWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContourLabelsLayerId,
      );

      expect(labelLayer['type'], 'symbol');
      expect(
        labelLayer['source'],
        WorldwideStyleFactory.sykeBathymetrySourceId,
      );
      expect(
        labelLayer['source-layer'],
        WorldwideStyleFactory.sykeContoursSourceLayer,
      );
      expect(WorldwideStyleFactory.sykeContoursSourceLayer, 'contours');
    });

    test('the label layer is positioned immediately after the contour '
        'line layer in the generated layers array', () {
      final layers = layersFor();
      final contourIndex = layers.indexWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContoursLayerId,
      );
      final labelIndex = layers.indexWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContourLabelsLayerId,
      );

      expect(contourIndex, greaterThanOrEqualTo(0));
      expect(labelIndex, contourIndex + 1);
    });

    test('all existing MML/MapTiler layer ordering is unchanged — the '
        'label layer is only ever appended at the very end, never '
        'inserted earlier, so MML\'s own place/lake-name labels retain '
        'collision priority (labels in earlier-listed layers block '
        'labels in later ones)', () {
      final layers = layersFor();
      expect(
        (layers[0])['id'],
        MapTilerStyleFactory.outdoorLayerId,
      );
      expect((layers[1])['id'], 'vesisto_alue');

      final labelIndex = layers.indexWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContourLabelsLayerId,
      );
      // The label layer is the very last layer in the document — strictly
      // after every MML/MapTiler layer already present.
      expect(labelIndex, layers.length - 1);
    });

    test('the label layer carries the first physical-test minzoom (12), '
        'deliberately higher than the contour line layer\'s own minzoom '
        '(10) — text only starts once individual lake basins are already '
        'spatially separated on screen', () {
      final layers = layersFor();
      final labelLayer = layers.firstWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContourLabelsLayerId,
      );

      expect(
        WorldwideStyleFactory.sykeContourLabelsPresentationMinZoom,
        12,
      );
      expect(
        labelLayer['minzoom'],
        WorldwideStyleFactory.sykeContourLabelsPresentationMinZoom,
      );
      expect(
        labelLayer['minzoom'],
        greaterThan(WorldwideStyleFactory.sykeBathymetryPresentationMinZoom),
      );
    });

    test('the label layer uses line placement with the first physical-test '
        'spacing (350px) and text size (11px)', () {
      final layers = layersFor();
      final layout =
          layers.firstWhere(
                (l) => l['id'] == WorldwideStyleFactory.sykeContourLabelsLayerId,
              )['layout']
              as Map;

      expect(layout['symbol-placement'], 'line');
      expect(layout['symbol-spacing'], 350);
      expect(layout['text-size'], 11);
    });

    test('the label layer\'s text-field expression reads the existing '
        '"depth_m" MVT attribute and formats it as "<depth> m"', () {
      final layers = layersFor();
      final layout =
          layers.firstWhere(
                (l) => l['id'] == WorldwideStyleFactory.sykeContourLabelsLayerId,
              )['layout']
              as Map;

      expect(
        layout['text-field'],
        [
          'concat',
          [
            'to-string',
            ['get', 'depth_m'],
          ],
          ' m',
        ],
      );
    });

    test('the label layer filters out depth_m == 0 (the shoreline '
        'contour) — ~35% of all contour features in the bundled MBTiles '
        'asset, which would otherwise trace "0 m" along every lake\'s '
        'already-visible shoreline', () {
      final layers = layersFor();
      final labelLayer = layers.firstWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContourLabelsLayerId,
      );

      expect(labelLayer['filter'], [
        '!=',
        ['get', 'depth_m'],
        0,
      ]);
    });

    test('the label layer relies on the default MapLibre collision system '
        '— overlap/ignore-placement are explicitly false, and keep-upright '
        '/max-angle/padding match MapLibre\'s own documented defaults, set '
        'explicitly rather than left implicit', () {
      final layers = layersFor();
      final layout =
          layers.firstWhere(
                (l) => l['id'] == WorldwideStyleFactory.sykeContourLabelsLayerId,
              )['layout']
              as Map;

      expect(layout['text-allow-overlap'], isFalse);
      expect(layout['text-ignore-placement'], isFalse);
      expect(layout['text-keep-upright'], isTrue);
      expect(layout['text-max-angle'], 45);
      expect(layout['text-padding'], 2);
      expect(layout['text-rotation-alignment'], 'map');
      expect(layout['text-pitch-alignment'], 'viewport');
    });

    test('the label layer\'s paint styling is a restrained bathymetric '
        'blue with a white halo for readability over both MML terrain and '
        'MapTiler imagery, matching the existing contour line color', () {
      final layers = layersFor();
      final labelLayer = layers.firstWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContourLabelsLayerId,
      );
      final paint = labelLayer['paint'] as Map;

      expect(paint['text-color'], '#0f5c8c');
      expect(paint['text-halo-color'], '#ffffff');
      expect(paint['text-halo-width'], 1.2);
    });

    test('the label layer is present for Ilmakuva too, appended after the '
        'contour line layer exactly as for Maastokartta — the overlay '
        'remains base-map-agnostic', () {
      final layers = layersFor(baseMap: BaseMap.ilmakuva);
      final contourIndex = layers.indexWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContoursLayerId,
      );
      final labelIndex = layers.indexWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContourLabelsLayerId,
      );

      expect(contourIndex, greaterThanOrEqualTo(0));
      expect(labelIndex, contourIndex + 1);
    });

    test('the label layer is absent, alongside the contour line layer, '
        'when sykeBathymetryLocalBaseUrl is null', () {
      final style = decoded(
        factory.buildStyle(
          BaseMap.maastokartta,
          mapTilerAvailable: true,
          sykeBathymetryLocalBaseUrl: null,
        ),
      );
      final layers = (style['layers'] as List<dynamic>).cast<Map>();

      expect(
        layers.any(
          (l) => l['id'] == WorldwideStyleFactory.sykeContourLabelsLayerId,
        ),
        isFalse,
      );
    });

    test('the existing contour line layer is completely unchanged by this '
        'addition — same id, type, source, source-layer, minzoom, no '
        'maxzoom, and identical paint, with no filter added to it', () {
      final layers = layersFor();
      final contourLayer = layers.firstWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContoursLayerId,
      );

      expect(contourLayer['type'], 'line');
      expect(
        contourLayer['source'],
        WorldwideStyleFactory.sykeBathymetrySourceId,
      );
      expect(
        contourLayer['source-layer'],
        WorldwideStyleFactory.sykeContoursSourceLayer,
      );
      expect(
        contourLayer['minzoom'],
        WorldwideStyleFactory.sykeBathymetryPresentationMinZoom,
      );
      expect(contourLayer.containsKey('maxzoom'), isFalse);
      expect(contourLayer.containsKey('filter'), isFalse);
      expect(contourLayer['paint'], {
        'line-color': '#0f5c8c',
        'line-width': 0.6,
        'line-opacity': 0.75,
      });
    });
  });

  group('SYKE contour depth-label font selection (TD-027 depth-label font '
      'investigation — confirmed root cause fix: the label layer must '
      'never fall back to MapLibre\'s own multi-font text-font default, '
      'since that combined fontstack request fails against both glyph '
      'hosts this app ever configures)', () {
    Map<dynamic, dynamic> labelLayerFor({
      required BaseMap baseMap,
      String? mmlStyleFragmentJson,
    }) {
      final style = decoded(
        factory.buildStyle(
          baseMap,
          mapTilerAvailable: true,
          mmlStyleFragmentJson: mmlStyleFragmentJson,
          sykeBathymetryLocalBaseUrl: sykeLocalBaseUrl,
        ),
      );
      final layers = (style['layers'] as List<dynamic>).cast<Map>();
      return layers.firstWhere(
        (l) => l['id'] == WorldwideStyleFactory.sykeContourLabelsLayerId,
      );
    }

    test('Maastokartta with the MML vector fragment present uses '
        '["Liberation Sans NLSFI"] — the one font verified to exist on '
        'MML\'s own real glyph host, which is the active glyphs root in '
        'this configuration', () {
      final labelLayer = labelLayerFor(
        baseMap: BaseMap.maastokartta,
        mmlStyleFragmentJson: syntheticMmlFragment(),
      );
      final layout = labelLayer['layout'] as Map;

      expect(
        WorldwideStyleFactory.sykeContourLabelMmlFont,
        'Liberation Sans NLSFI',
      );
      expect(layout['text-font'], [
        WorldwideStyleFactory.sykeContourLabelMmlFont,
      ]);
    });

    test('Ilmakuva uses ["Open Sans Regular"] — MML is never part of the '
        'Ilmakuva composition, so defaultGlyphsUrl is always the active '
        'glyphs root there, regardless of an MML fragment being supplied', () {
      for (final mmlFragment in [syntheticMmlFragment(), null]) {
        final labelLayer = labelLayerFor(
          baseMap: BaseMap.ilmakuva,
          mmlStyleFragmentJson: mmlFragment,
        );
        final layout = labelLayer['layout'] as Map;

        expect(
          WorldwideStyleFactory.sykeContourLabelDefaultFont,
          'Open Sans Regular',
        );
        expect(layout['text-font'], [
          WorldwideStyleFactory.sykeContourLabelDefaultFont,
        ]);
      }
    });

    test('Maastokartta without an MML fragment falls back to '
        '["Open Sans Regular"] — defaultGlyphsUrl is the actual glyphs '
        'root in this configuration (TD-027 §3F Failure behavior: MML '
        'unconfigured or its fragment fetch failed), so the label font '
        'must match that host, not MML\'s', () {
      final labelLayer = labelLayerFor(
        baseMap: BaseMap.maastokartta,
        mmlStyleFragmentJson: null,
      );
      final layout = labelLayer['layout'] as Map;

      expect(layout['text-font'], [
        WorldwideStyleFactory.sykeContourLabelDefaultFont,
      ]);
    });

    test('no combined default font stack is ever emitted — text-font is '
        'always exactly one font name, never MapLibre\'s own '
        '["Open Sans Regular", "Arial Unicode MS Regular"] default, under '
        'any base-map/MML-availability combination', () {
      for (final baseMap in BaseMap.values) {
        for (final mmlFragment in [syntheticMmlFragment(), null]) {
          final labelLayer = labelLayerFor(
            baseMap: baseMap,
            mmlStyleFragmentJson: mmlFragment,
          );
          final layout = labelLayer['layout'] as Map;
          final textFont = layout['text-font'] as List;

          expect(textFont.length, 1);
          expect(textFont, isNot(contains('Arial Unicode MS Regular')));
        }
      }
    });
  });

  test('the glyphs URL is present in every generated variant, for both '
      'selections, including the no-source case', () {
    for (final baseMap in BaseMap.values) {
      for (final mapTilerAvailable in [true, false]) {
        for (final mmlFragment in [syntheticMmlFragment(), null]) {
          final style = decoded(
            factory.buildStyle(
              baseMap,
              mapTilerAvailable: mapTilerAvailable,
              mmlStyleFragmentJson: mmlFragment,
            ),
          );
          expect(style['glyphs'], isNotNull);
          expect(style['glyphs'], contains('{fontstack}'));
          expect(style['glyphs'], contains('{range}'));
        }
      }
    }
  });

  test('styleFor reads the real MapTilerConfig (missing by default under '
      'plain `flutter test`), producing the same empty, glyphs-only shape '
      'as the explicit unavailable case', () {
    final style = decoded(factory.styleFor(BaseMap.maastokartta));
    expect(style['sources'], isEmpty);
    expect(style['layers'], isEmpty);
    expect(style['glyphs'], isNotNull);
  });
}
