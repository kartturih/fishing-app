import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/statistics/domain/fishing_spot_catch_statistic.dart';

void main() {
  FishingSpot buildFishingSpot() {
    return FishingSpot(
      id: 'spot-1',
      name: 'Test Spot',
      latitude: 61.0,
      longitude: 25.0,
      waterBodyId: 'water-body-1',
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  test('constructs successfully with a positive catchCount', () {
    final statistic = FishingSpotCatchStatistic(
      fishingSpot: buildFishingSpot(),
      catchCount: 4,
    );
    expect(statistic.catchCount, 4);
    expect(statistic.fishingSpot.name, 'Test Spot');
  });

  test('rejects catchCount <= 0', () {
    expect(
      () => FishingSpotCatchStatistic(
        fishingSpot: buildFishingSpot(),
        catchCount: 0,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
