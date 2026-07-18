import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';

void main() {
  group('lureTypeDisplayLabel', () {
    test('returns the known label for a known code', () {
      expect(lureTypeDisplayLabel('crankbait'), 'Vaappu');
      expect(lureTypeDisplayLabel('jig'), 'Jigi');
    });

    test('returns a humanized fallback for an unrecognized code', () {
      expect(lureTypeDisplayLabel('deep_diving_glider'), 'Deep diving glider');
    });

    test('does not throw for an empty code', () {
      expect(lureTypeDisplayLabel(''), '');
    });
  });

  group('buoyancyDisplayLabel', () {
    test('returns the known label for a known code', () {
      expect(buoyancyDisplayLabel('floating'), 'Uiva');
      expect(buoyancyDisplayLabel('sinking'), 'Uppoava');
    });

    test('returns a humanized fallback for an unrecognized code', () {
      expect(buoyancyDisplayLabel('rapid_sinking'), 'Rapid sinking');
    });

    test('does not throw for an empty code', () {
      expect(buoyancyDisplayLabel(''), '');
    });
  });
}
