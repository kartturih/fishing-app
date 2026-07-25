import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/map/mml_config.dart';

void main() {
  test(
    'isMissing is true when no MML_API_KEY is supplied at build time '
    '(the default for a plain `flutter test` invocation)',
    () {
      expect(MmlConfig.isMissing, isTrue);
      expect(MmlConfig.apiKey, isEmpty);
    },
  );
}
