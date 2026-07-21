import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/statistics/domain/fishing_spot_statistics_summary.dart';

void main() {
  Catch buildCatch(String id, {int? weightGrams}) {
    return Catch(
      id: id,
      fishingSpotId: 'spot-1',
      species: FishSpecies.pike,
      caughtAt: DateTime.utc(2026, 7, 17),
      weightGrams: weightGrams,
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );
  }

  test('totalCatches equals the length of catches', () {
    final summary = FishingSpotStatisticsSummary(
      catches: [buildCatch('catch-1'), buildCatch('catch-2')],
      speciesCatchCounts: const [],
      lastCatchDate: DateTime.utc(2026, 7, 17),
    );
    expect(summary.totalCatches, 2);
  });

  test('totalCatches is 0 for an empty list', () {
    final summary = FishingSpotStatisticsSummary(
      catches: const [],
      speciesCatchCounts: const [],
      lastCatchDate: null,
    );
    expect(summary.totalCatches, 0);
  });

  test('recordCatch returns the first entry when catches is non-empty', () {
    final first = buildCatch('catch-1', weightGrams: 3000);
    final second = buildCatch('catch-2', weightGrams: 1000);
    final summary = FishingSpotStatisticsSummary(
      catches: [first, second],
      speciesCatchCounts: const [],
      lastCatchDate: DateTime.utc(2026, 7, 17),
    );
    expect(summary.recordCatch, same(first));
  });

  test('recordCatch returns null when catches is empty', () {
    final summary = FishingSpotStatisticsSummary(
      catches: const [],
      speciesCatchCounts: const [],
      lastCatchDate: null,
    );
    expect(summary.recordCatch, isNull);
  });

  test('lastCatchDate is stored as given, independent of catches order', () {
    // catches is sorted by weight, not by date — lastCatchDate must not
    // be derived from catches.first.caughtAt.
    final heaviestButEarlier = buildCatch('catch-1', weightGrams: 9000);
    final lighterButLater = buildCatch('catch-2', weightGrams: 100);
    final summary = FishingSpotStatisticsSummary(
      catches: [heaviestButEarlier, lighterButLater],
      speciesCatchCounts: const [],
      lastCatchDate: DateTime.utc(2026, 8, 1),
    );
    expect(summary.lastCatchDate, DateTime.utc(2026, 8, 1));
    expect(summary.recordCatch, same(heaviestButEarlier));
  });
}
