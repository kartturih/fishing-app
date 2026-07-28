import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/map/maptiler_style_factory.dart';

void main() {
  // Never a real MapTiler API key — a synthetic placeholder used only to
  // exercise URL construction.
  const factory = MapTilerStyleFactory(apiKey: 'test-key');

  ({Map<String, dynamic> sources, List<dynamic> layers}) buildOutdoor() {
    final sources = <String, dynamic>{};
    final layers = <dynamic>[];
    factory.addOutdoorFragment(sources, layers);
    return (sources: sources, layers: layers);
  }

  ({Map<String, dynamic> sources, List<dynamic> layers})
  buildSatelliteHybrid() {
    final sources = <String, dynamic>{};
    final layers = <dynamic>[];
    factory.addSatelliteHybridFragment(sources, layers);
    return (sources: sources, layers: layers);
  }

  String tileUrl(Map<String, dynamic> sources) {
    final source = sources.values.first as Map<String, dynamic>;
    return (source['tiles'] as List<dynamic>).first as String;
  }

  group('Outdoor fragment', () {
    test('the generated tile URL uses the standard {z}/{x}/{y} order, not '
        'MML\'s reversed {z}/{y}/{x} — verified from MapTiler\'s Maps API docs '
        '(TD-027 §0)', () {
      final url = tileUrl(buildOutdoor().sources);
      expect(url, contains('/{z}/{x}/{y}'));
      expect(url, isNot(contains('/{z}/{y}/{x}')));
    });

    test('targets the outdoor-v4 style id', () {
      final url = tileUrl(buildOutdoor().sources);
      expect(url, contains('/maps/outdoor-v4/'));
    });

    test('uses the key query parameter, not MML\'s api-key', () {
      final url = tileUrl(buildOutdoor().sources);
      expect(url, contains('?key=test-key'));
      expect(url, isNot(contains('api-key=')));
    });

    test('declares tileSize 256 and the confirmed 0-22 zoom range (TD-027 §0, '
        'verified from outdoor-v4\'s own authenticated TileJSON)', () {
      final source = buildOutdoor().sources.values.first as Map;
      expect(source['tileSize'], 256);
      expect(source['minzoom'], 0);
      expect(source['maxzoom'], 22);
    });

    test('produces exactly one raster source and one raster layer', () {
      final built = buildOutdoor();
      expect(built.sources.length, 1);
      expect(built.layers.length, 1);
      final source = built.sources.values.first as Map;
      expect(source['type'], 'raster');
      final layer = built.layers.first as Map;
      expect(layer['type'], 'raster');
      expect(layer['source'], built.sources.keys.first);
    });
  });

  group('Satellite Hybrid fragment', () {
    test('the generated tile URL uses the standard {z}/{x}/{y} order, not '
        'MML\'s reversed {z}/{y}/{x}', () {
      final url = tileUrl(buildSatelliteHybrid().sources);
      expect(url, contains('/{z}/{x}/{y}'));
      expect(url, isNot(contains('/{z}/{y}/{x}')));
    });

    test('targets the hybrid-v4 style id', () {
      final url = tileUrl(buildSatelliteHybrid().sources);
      expect(url, contains('/maps/hybrid-v4/'));
    });

    test('uses the key query parameter, not MML\'s api-key', () {
      final url = tileUrl(buildSatelliteHybrid().sources);
      expect(url, contains('?key=test-key'));
      expect(url, isNot(contains('api-key=')));
    });

    test('declares tileSize 256 and the confirmed 0-22 zoom range, identical '
        'to Outdoor\'s', () {
      final source = buildSatelliteHybrid().sources.values.first as Map;
      expect(source['tileSize'], 256);
      expect(source['minzoom'], 0);
      expect(source['maxzoom'], 22);
    });

    test('produces exactly one raster source and one raster layer', () {
      final built = buildSatelliteHybrid();
      expect(built.sources.length, 1);
      expect(built.layers.length, 1);
      final source = built.sources.values.first as Map;
      expect(source['type'], 'raster');
    });
  });

  test('Outdoor and Satellite Hybrid use different source/layer ids', () {
    final outdoor = buildOutdoor();
    final hybrid = buildSatelliteHybrid();
    expect(outdoor.sources.keys.first, isNot(hybrid.sources.keys.first));
    expect(
      (outdoor.layers.first as Map)['id'],
      isNot((hybrid.layers.first as Map)['id']),
    );
  });

  test('no real API key ever appears in generated output', () {
    final url = tileUrl(buildOutdoor().sources);
    expect(url, contains('test-key'));
    expect(url, isNot(contains('1f600b01')));
  });
}
