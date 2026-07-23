import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/statistics/domain/water_body_catch_statistic.dart';

void main() {
  WaterBody buildWaterBody() {
    return WaterBody(
      id: 'water-body-1',
      name: 'Test Water Body',
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  test('constructs successfully with a positive catchCount', () {
    final statistic = WaterBodyCatchStatistic(
      waterBody: buildWaterBody(),
      catchCount: 4,
    );
    expect(statistic.catchCount, 4);
    expect(statistic.waterBody.name, 'Test Water Body');
  });

  test('rejects catchCount <= 0', () {
    expect(
      () => WaterBodyCatchStatistic(
        waterBody: buildWaterBody(),
        catchCount: 0,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
