import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';

void main() {
  group('knownLureTypeCodes / known_lure_types.json synchronization', () {
    test(
      'the Dart display-label codes and the Python authoring-tool '
      'allowlist contain exactly the same set of codes',
      () {
        // These are two independently maintained lists with no shared
        // source (TD-028 Section 4/Section 5 -- the Dart map provides
        // Finnish display labels, the JSON file gates authoring-time
        // content validation in tools/lure_catalog/build_catalog.py). This
        // test is the only thing standing between them silently drifting
        // apart, so it fails loudly, naming exactly which codes are
        // missing on which side, rather than merely asserting equality.
        final file = File('tools/lure_catalog/known_lure_types.json');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'tools/lure_catalog/known_lure_types.json must exist',
        );

        final jsonCodes = (jsonDecode(file.readAsStringSync()) as List<dynamic>)
            .cast<String>()
            .toSet();
        final dartCodes = knownLureTypeCodes;

        final missingFromJson = dartCodes.difference(jsonCodes);
        final missingFromDart = jsonCodes.difference(dartCodes);

        expect(
          missingFromJson,
          isEmpty,
          reason:
              'lure_type_labels.dart has a Finnish label for code(s) '
              '$missingFromJson that tools/lure_catalog/known_lure_types.json '
              'does not list -- add them there too, or the authoring '
              'validator will reject genuinely known content.',
        );
        expect(
          missingFromDart,
          isEmpty,
          reason:
              'tools/lure_catalog/known_lure_types.json allows code(s) '
              '$missingFromDart that lure_type_labels.dart has no Finnish '
              'label for -- add a label there too, or those codes will '
              'only ever render via the humanized fallback.',
        );
      },
    );
  });
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
