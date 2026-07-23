import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/statistics/domain/water_body_catch_entry.dart';
import 'package:fishing_app/features/statistics/domain/water_body_statistics_summary.dart';

void main() {
  FishingSpot buildFishingSpot(String id) {
    return FishingSpot(
      id: id,
      name: 'Spot $id',
      latitude: 61.0,
      longitude: 25.0,
      waterBodyId: 'water-body-1',
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  WaterBodyCatchEntry buildEntry(
    String catchId, {
    int? weightGrams,
    String fishingSpotId = 'spot-1',
  }) {
    return WaterBodyCatchEntry(
      catchModel: Catch(
        id: catchId,
        fishingSpotId: fishingSpotId,
        species: FishSpecies.pike,
        caughtAt: DateTime.utc(2026, 7, 17),
        weightGrams: weightGrams,
        createdAt: DateTime.utc(2026, 7, 17),
        updatedAt: DateTime.utc(2026, 7, 17),
      ),
      fishingSpot: buildFishingSpot(fishingSpotId),
    );
  }

  test('totalCatches equals the length of catches', () {
    final summary = WaterBodyStatisticsSummary(
      catches: [buildEntry('catch-1'), buildEntry('catch-2')],
      speciesCatchCounts: const [],
      lastCatchDate: DateTime.utc(2026, 7, 17),
    );
    expect(summary.totalCatches, 2);
  });

  test('totalCatches is 0 for an empty list', () {
    final summary = WaterBodyStatisticsSummary(
      catches: const [],
      speciesCatchCounts: const [],
      lastCatchDate: null,
    );
    expect(summary.totalCatches, 0);
  });

  test('recordCatch returns the first entry when catches is non-empty', () {
    final first = buildEntry('catch-1', weightGrams: 3000);
    final second = buildEntry('catch-2', weightGrams: 1000);
    final summary = WaterBodyStatisticsSummary(
      catches: [first, second],
      speciesCatchCounts: const [],
      lastCatchDate: DateTime.utc(2026, 7, 17),
    );
    expect(summary.recordCatch, same(first));
  });

  test('recordCatch returns null when catches is empty', () {
    final summary = WaterBodyStatisticsSummary(
      catches: const [],
      speciesCatchCounts: const [],
      lastCatchDate: null,
    );
    expect(summary.recordCatch, isNull);
  });

  test('lastCatchDate is stored as given, independent of catches order', () {
    // catches is sorted by weight, not by date — lastCatchDate must not be
    // derived from catches.first.catchModel.caughtAt.
    final heaviestButEarlier = buildEntry('catch-1', weightGrams: 9000);
    final lighterButLater = buildEntry('catch-2', weightGrams: 100);
    final summary = WaterBodyStatisticsSummary(
      catches: [heaviestButEarlier, lighterButLater],
      speciesCatchCounts: const [],
      lastCatchDate: DateTime.utc(2026, 8, 1),
    );
    expect(summary.lastCatchDate, DateTime.utc(2026, 8, 1));
    expect(summary.recordCatch, same(heaviestButEarlier));
  });

  test('catches can span multiple fishing spots under the same water body', () {
    final atSpotA = buildEntry('catch-1', fishingSpotId: 'spot-a');
    final atSpotB = buildEntry('catch-2', fishingSpotId: 'spot-b');
    final summary = WaterBodyStatisticsSummary(
      catches: [atSpotA, atSpotB],
      speciesCatchCounts: const [],
      lastCatchDate: DateTime.utc(2026, 7, 17),
    );
    expect(summary.catches.map((e) => e.fishingSpot.id), ['spot-a', 'spot-b']);
  });
}
