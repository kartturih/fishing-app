import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_entry.dart';

void main() {
  Catch buildCatch({int? weightGrams}) {
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
      waterBodyId: 'water-body-1',
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  WaterBody buildWaterBody() {
    return WaterBody(
      id: 'water-body-1',
      name: 'Test Water Body',
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  test('constructs successfully when catchModel has a recorded weight', () {
    final entry = SpeciesCatchEntry(
      catchModel: buildCatch(weightGrams: 2000),
      fishingSpot: buildFishingSpot(),
      waterBody: buildWaterBody(),
    );
    expect(entry.catchModel.weightGrams, 2000);
  });

  test('constructs successfully when catchModel has no recorded weight — '
      'unlike LargestCatch, this is not rejected', () {
    final entry = SpeciesCatchEntry(
      catchModel: buildCatch(),
      fishingSpot: buildFishingSpot(),
      waterBody: buildWaterBody(),
    );
    expect(entry.catchModel.weightGrams, isNull);
  });
}
