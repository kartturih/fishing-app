import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/statistics/domain/lure_type_catch_statistic.dart';

void main() {
  test(
    'constructs successfully with a non-empty lureType and positive catchCount',
    () {
      final statistic = LureTypeCatchStatistic(lureType: 'jig', catchCount: 5);
      expect(statistic.lureType, 'jig');
      expect(statistic.catchCount, 5);
    },
  );

  test('rejects an empty lureType', () {
    expect(
      () => LureTypeCatchStatistic(lureType: '', catchCount: 1),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a zero catchCount', () {
    expect(
      () => LureTypeCatchStatistic(lureType: 'jig', catchCount: 0),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a negative catchCount', () {
    expect(
      () => LureTypeCatchStatistic(lureType: 'jig', catchCount: -1),
      throwsA(isA<AssertionError>()),
    );
  });
}
