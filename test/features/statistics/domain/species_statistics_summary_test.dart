import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_entry.dart';
import 'package:fishing_app/features/statistics/domain/species_statistics_summary.dart';

void main() {
  SpeciesCatchEntry buildEntry(String id, {int? weightGrams}) {
    return SpeciesCatchEntry(
      catchModel: Catch(
        id: id,
        fishingSpotId: 'spot-1',
        species: FishSpecies.pike,
        caughtAt: DateTime.utc(2026, 7, 17),
        weightGrams: weightGrams,
        createdAt: DateTime.utc(2026, 7, 17),
        updatedAt: DateTime.utc(2026, 7, 17),
      ),
      fishingSpot: FishingSpot(
        id: 'spot-1',
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: 'water-body-1',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      waterBody: WaterBody(
        id: 'water-body-1',
        name: 'Test Water Body',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
  }

  test('totalCatches equals the length of catches', () {
    final summary = SpeciesStatisticsSummary(
      species: FishSpecies.pike,
      catches: [
        buildEntry('catch-1', weightGrams: 3000),
        buildEntry('catch-2', weightGrams: 1000),
      ],
    );
    expect(summary.totalCatches, 2);
  });

  test('totalCatches is 0 for an empty list', () {
    final summary = SpeciesStatisticsSummary(
      species: FishSpecies.pike,
      catches: const [],
    );
    expect(summary.totalCatches, 0);
  });

  test('recordCatch returns the first entry when catches is non-empty', () {
    final first = buildEntry('catch-1', weightGrams: 3000);
    final second = buildEntry('catch-2', weightGrams: 1000);
    final summary = SpeciesStatisticsSummary(
      species: FishSpecies.pike,
      catches: [first, second],
    );
    expect(summary.recordCatch, same(first));
  });

  test('recordCatch returns null when catches is empty', () {
    final summary = SpeciesStatisticsSummary(
      species: FishSpecies.pike,
      catches: const [],
    );
    expect(summary.recordCatch, isNull);
  });
}
