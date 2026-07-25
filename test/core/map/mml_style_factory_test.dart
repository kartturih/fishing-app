import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/map/base_map.dart';
import 'package:fishing_app/core/map/mml_style_factory.dart';

void main() {
  // Never a real MML API key — a synthetic placeholder used only to
  // exercise URL construction.
  const factory = MmlStyleFactory(apiKey: 'test-key');

  Map<String, dynamic> decodedStyle(BaseMap baseMap) {
    return jsonDecode(factory.styleFor(baseMap)) as Map<String, dynamic>;
  }

  String tileUrl(Map<String, dynamic> style) {
    final sources = style['sources'] as Map<String, dynamic>;
    final source = sources.values.first as Map<String, dynamic>;
    return (source['tiles'] as List<dynamic>).first as String;
  }

  test('the generated tile URL places tokens in {z}/{y}/{x} order, not '
      '{z}/{x}/{y} — verified from live MML GetCapabilities (TD-026 §0)', () {
    final url = tileUrl(decodedStyle(BaseMap.maastokartta));
    expect(url, contains('/{z}/{y}/{x}'));
    expect(url, isNot(contains('/{z}/{x}/{y}')));
  });

  test('Maastokartta URL ends with .png', () {
    final url = tileUrl(decodedStyle(BaseMap.maastokartta));
    expect(url, contains('{x}.png'));
  });

  test('Ortokuva URL ends with .jpg, not .png', () {
    final url = tileUrl(decodedStyle(BaseMap.ilmakuva));
    expect(url, contains('{x}.jpg'));
    expect(url, isNot(contains('.png')));
  });

  test('the verified WGS84_Pseudo-Mercator matrix set is used verbatim', () {
    final url = tileUrl(decodedStyle(BaseMap.maastokartta));
    expect(url, contains('WGS84_Pseudo-Mercator'));
  });

  test('the api-key query parameter carries the supplied key', () {
    final url = tileUrl(decodedStyle(BaseMap.maastokartta));
    expect(url, contains('?api-key=test-key'));
  });

  test('the verified 0-18 zoom bounds appear in the generated style', () {
    final source =
        (decodedStyle(BaseMap.maastokartta)['sources'] as Map<String, dynamic>)
                .values
                .first
            as Map<String, dynamic>;
    expect(source['minzoom'], 0);
    expect(source['maxzoom'], 18);
    expect(source['tileSize'], 256);
  });

  test('the style is a single-source, single-layer raster style', () {
    final style = decodedStyle(BaseMap.maastokartta);
    expect(style['version'], 8);
    expect((style['sources'] as Map).length, 1);
    expect((style['layers'] as List).length, 1);
    final source = (style['sources'] as Map).values.first as Map;
    expect(source['type'], 'raster');
  });

  test('no real API key ever appears in generated output', () {
    final url = tileUrl(decodedStyle(BaseMap.maastokartta));
    expect(url, contains('test-key'));
    expect(url, isNot(contains('1f600b01')));
  });

  test('the style declares a glyphs URL, required for the fishing-spot '
      'symbol layer to render its name-label text at all (physical-device '
      'regression: labels silently failed to render without one)', () {
    final style = decodedStyle(BaseMap.maastokartta);
    expect(style['glyphs'], isNotNull);
    expect(style['glyphs'], contains('{fontstack}'));
    expect(style['glyphs'], contains('{range}'));
  });
}
