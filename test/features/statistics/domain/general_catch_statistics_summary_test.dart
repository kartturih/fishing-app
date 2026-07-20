import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/statistics/domain/general_catch_statistics_summary.dart';
import 'package:fishing_app/features/statistics/domain/largest_catch.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';

void main() {
  LargestCatch buildLargestCatch(String id) {
    return LargestCatch(
      catchModel: Catch(
        id: id,
        fishingSpotId: 'spot-1',
        species: FishSpecies.pike,
        caughtAt: DateTime.utc(2026, 7, 17),
        weightGrams: 2000,
        createdAt: DateTime.utc(2026, 7, 17),
        updatedAt: DateTime.utc(2026, 7, 17),
      ),
      fishingSpot: FishingSpot(
        id: 'spot-1',
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
  }

  test('mostCaughtSpecies returns the first list element when non-empty', () {
    const first = SpeciesCatchStatistic(
      species: FishSpecies.pike,
      catchCount: 3,
    );
    const second = SpeciesCatchStatistic(
      species: FishSpecies.perch,
      catchCount: 1,
    );
    final summary = GeneralCatchStatisticsSummary(
      totalCatches: 4,
      largestCatches: const [],
      speciesCatchCounts: [first, second],
    );
    expect(summary.mostCaughtSpecies, same(first));
  });

  test('mostCaughtSpecies returns null when speciesCatchCounts is empty', () {
    final summary = GeneralCatchStatisticsSummary(
      totalCatches: 0,
      largestCatches: const [],
      speciesCatchCounts: const [],
    );
    expect(summary.mostCaughtSpecies, isNull);
  });

  test('rejects a negative totalCatches', () {
    expect(
      () => GeneralCatchStatisticsSummary(
        totalCatches: -1,
        largestCatches: const [],
        speciesCatchCounts: const [],
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects more than three largestCatches entries', () {
    expect(
      () => GeneralCatchStatisticsSummary(
        totalCatches: 4,
        largestCatches: [
          buildLargestCatch('catch-1'),
          buildLargestCatch('catch-2'),
          buildLargestCatch('catch-3'),
          buildLargestCatch('catch-4'),
        ],
        speciesCatchCounts: const [],
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('accepts exactly three largestCatches entries', () {
    final summary = GeneralCatchStatisticsSummary(
      totalCatches: 3,
      largestCatches: [
        buildLargestCatch('catch-1'),
        buildLargestCatch('catch-2'),
        buildLargestCatch('catch-3'),
      ],
      speciesCatchCounts: const [],
    );
    expect(summary.largestCatches, hasLength(3));
  });
}
