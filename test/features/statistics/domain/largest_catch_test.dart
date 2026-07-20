import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/statistics/domain/largest_catch.dart';

void main() {
  Catch buildCatch({int? weightGrams = 2000}) {
    return Catch(
      id: 'catch-1',
      fishingSpotId: 'spot-1',
      species: FishSpecies.pike,
      caughtAt: DateTime.utc(2026, 7, 17),
      weightGrams: weightGrams,
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );
  }

  FishingSpot buildFishingSpot() {
    return FishingSpot(
      id: 'spot-1',
      name: 'Test Spot',
      latitude: 61.0,
      longitude: 25.0,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  test('constructs successfully when catchModel has a recorded weight', () {
    final largestCatch = LargestCatch(
      catchModel: buildCatch(),
      fishingSpot: buildFishingSpot(),
    );
    expect(largestCatch.catchModel.weightGrams, 2000);
  });

  test('rejects a catchModel with no recorded weight', () {
    expect(
      () => LargestCatch(
        catchModel: buildCatch(weightGrams: null),
        fishingSpot: buildFishingSpot(),
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
