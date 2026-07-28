import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/map/maptiler_config.dart';

void main() {
  test('isMissing is true when no MAPTILER_API_KEY is supplied at build time '
      '(the default for a plain `flutter test` invocation)', () {
    expect(MapTilerConfig.isMissing, isTrue);
    expect(MapTilerConfig.apiKey, isEmpty);
  });
}
