import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catches/presentation/widgets/add_catch_bottom_sheet.dart';

void main() {
  group('parseCatchMeasurementInput', () {
    test('parses a period decimal separator', () {
      expect(parseCatchMeasurementInput('2.45'), 2.45);
    });

    test('parses a comma decimal separator', () {
      expect(parseCatchMeasurementInput('2,45'), 2.45);
    });

    test('parses a whole number', () {
      expect(parseCatchMeasurementInput('68'), 68.0);
    });

    test('trims surrounding whitespace', () {
      expect(parseCatchMeasurementInput('  68.5  '), 68.5);
    });

    test('returns null for empty input', () {
      expect(parseCatchMeasurementInput(''), isNull);
    });

    test('returns null for invalid text', () {
      expect(parseCatchMeasurementInput('abc'), isNull);
    });

    test('parses Infinity as a non-finite double', () {
      expect(parseCatchMeasurementInput('Infinity'), double.infinity);
    });

    test('parses NaN as a non-finite double', () {
      expect(parseCatchMeasurementInput('NaN')!.isNaN, isTrue);
    });
  });

  group('kilogramsToGrams', () {
    test('converts 2.45 kg to 2450 g', () {
      expect(kilogramsToGrams(2.45), 2450);
    });

    test('converts 0.85 kg to 850 g', () {
      expect(kilogramsToGrams(0.85), 850);
    });

    test('converts 10 kg to 10000 g', () {
      expect(kilogramsToGrams(10), 10000);
    });

    test('rounds extra precision', () {
      expect(kilogramsToGrams(1.2345), 1235);
    });
  });

  group('centimetersToMillimeters', () {
    test('converts 24 cm to 240 mm', () {
      expect(centimetersToMillimeters(24), 240);
    });

    test('converts 68.5 cm to 685 mm', () {
      expect(centimetersToMillimeters(68.5), 685);
    });

    test('converts 102 cm to 1020 mm', () {
      expect(centimetersToMillimeters(102), 1020);
    });

    test('rounds extra precision', () {
      expect(centimetersToMillimeters(68.56), 686);
    });
  });

  group('validateCatchWeightInput', () {
    test('empty value is valid (becomes null)', () {
      expect(validateCatchWeightInput(''), isNull);
      expect(validateCatchWeightInput(null), isNull);
    });

    test('accepts a valid period-separated value', () {
      expect(validateCatchWeightInput('2.45'), isNull);
    });

    test('accepts a valid comma-separated value', () {
      expect(validateCatchWeightInput('2,45'), isNull);
    });

    test('rejects invalid text', () {
      expect(validateCatchWeightInput('abc'), 'Syötä kelvollinen paino');
    });

    test('rejects zero', () {
      expect(
        validateCatchWeightInput('0'),
        'Painon täytyy olla suurempi kuin 0',
      );
    });

    test('rejects negative values', () {
      expect(
        validateCatchWeightInput('-1'),
        'Painon täytyy olla suurempi kuin 0',
      );
    });

    test('rejects Infinity', () {
      expect(validateCatchWeightInput('Infinity'), 'Syötä kelvollinen paino');
    });

    test('rejects -Infinity', () {
      expect(validateCatchWeightInput('-Infinity'), 'Syötä kelvollinen paino');
    });

    test('rejects NaN', () {
      expect(validateCatchWeightInput('NaN'), 'Syötä kelvollinen paino');
    });
  });

  group('validateCatchLengthInput', () {
    test('empty value is valid (becomes null)', () {
      expect(validateCatchLengthInput(''), isNull);
      expect(validateCatchLengthInput(null), isNull);
    });

    test('accepts a valid period-separated value', () {
      expect(validateCatchLengthInput('68.5'), isNull);
    });

    test('accepts a valid comma-separated value', () {
      expect(validateCatchLengthInput('68,5'), isNull);
    });

    test('rejects invalid text', () {
      expect(validateCatchLengthInput('abc'), 'Syötä kelvollinen pituus');
    });

    test('rejects zero', () {
      expect(
        validateCatchLengthInput('0'),
        'Pituuden täytyy olla suurempi kuin 0',
      );
    });

    test('rejects negative values', () {
      expect(
        validateCatchLengthInput('-1'),
        'Pituuden täytyy olla suurempi kuin 0',
      );
    });

    test('rejects non-finite values', () {
      expect(validateCatchLengthInput('Infinity'), 'Syötä kelvollinen pituus');
      expect(validateCatchLengthInput('NaN'), 'Syötä kelvollinen pituus');
    });
  });
}
