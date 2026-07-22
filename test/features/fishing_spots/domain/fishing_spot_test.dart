import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

void main() {
  test('constructs successfully with a non-empty waterBodyId', () {
    final spot = FishingSpot(
      id: 'spot-1',
      name: 'Koiraranta',
      latitude: 61.0,
      longitude: 25.0,
      waterBodyId: 'water-body-1',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    expect(spot.waterBodyId, 'water-body-1');
  });

  test('rejects an empty waterBodyId', () {
    expect(
      () => FishingSpot(
        id: 'spot-1',
        name: 'Koiraranta',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: '',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
