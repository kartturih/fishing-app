import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/statistics/data/general_catch_statistics_repository.dart';

void main() {
  late AppDatabase database;
  late CatchRepository catchRepository;
  late FishingSpotRepository fishingSpotRepository;
  late GeneralCatchStatisticsRepository statisticsRepository;
  late FishingSpot fishingSpot;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database
        .into(database.waterBodies)
        .insert(
          WaterBodiesCompanion.insert(
            id: 'water-body-1',
            name: 'Test Water Body',
            createdAt: 0,
          ),
        );
    catchRepository = CatchRepository(database);
    fishingSpotRepository = FishingSpotRepository(database);
    statisticsRepository = GeneralCatchStatisticsRepository(database);
    fishingSpot = await fishingSpotRepository.create(
      name: 'Test Spot',
      latitude: 61.0,
      longitude: 25.0,
      waterBodyId: 'water-body-1',
    );
  });

  tearDown(() async {
    await database.close();
  });

  // CatchRepository derives ids from DateTime.now().microsecondsSinceEpoch;
  // a tiny delay avoids two rapid calls landing on the same clock tick in
  // this test environment, matching catch_repository_test.dart's and
  // lure_statistics_repository_test.dart's convention.
  Future<void> delay() => Future<void>.delayed(const Duration(milliseconds: 2));

  Future<void> createWaterBody(String id, String name) {
    return database
        .into(database.waterBodies)
        .insert(
          WaterBodiesCompanion.insert(id: id, name: name, createdAt: 0),
        );
  }

  test('no catches at all produces an empty summary', () async {
    final summary = await statisticsRepository.getGeneralCatchStatistics();

    expect(summary.totalCatches, 0);
    expect(summary.largestCatches, isEmpty);
    expect(summary.speciesCatchCounts, isEmpty);
    expect(summary.waterBodyCatchCounts, isEmpty);
  });

  test('one catch with a recorded weight appears in largestCatches with its '
      'fishing spot correctly resolved', () async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 2500,
    );

    final summary = await statisticsRepository.getGeneralCatchStatistics();

    expect(summary.totalCatches, 1);
    expect(summary.largestCatches, hasLength(1));
    expect(summary.largestCatches.single.catchModel.weightGrams, 2500);
    expect(summary.largestCatches.single.fishingSpot.id, fishingSpot.id);
    expect(summary.largestCatches.single.fishingSpot.name, 'Test Spot');
  });

  test('a catch with no recorded weight never appears in largestCatches, but '
      'still contributes to totalCatches and speciesCatchCounts', () async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.perch,
      caughtAt: DateTime(2026, 7, 17),
    );

    final summary = await statisticsRepository.getGeneralCatchStatistics();

    expect(summary.totalCatches, 1);
    expect(summary.largestCatches, isEmpty);
    expect(summary.speciesCatchCounts, hasLength(1));
    expect(summary.speciesCatchCounts.single.species, FishSpecies.perch);
    expect(summary.speciesCatchCounts.single.catchCount, 1);
  });

  test('more than three weighted catches only shows the top three, in '
      'weight-descending order', () async {
    final weights = [1000, 4000, 2000, 5000, 3000];
    for (final weight in weights) {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: weight,
      );
      await delay();
    }

    final summary = await statisticsRepository.getGeneralCatchStatistics();

    expect(summary.totalCatches, 5);
    expect(summary.largestCatches, hasLength(3));
    expect(
      summary.largestCatches.map((c) => c.catchModel.weightGrams).toList(),
      [5000, 4000, 3000],
    );
  });

  test('a tie in weight between two catches resolves deterministically by '
      'caughtAt descending', () async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 10),
      weightGrams: 2000,
    );
    await delay();
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 2000,
    );

    final summary = await statisticsRepository.getGeneralCatchStatistics();

    expect(summary.largestCatches, hasLength(2));
    // The more recently-caught fish (7/17) ranks first despite an equal
    // weight, per the documented weight -> caughtAt tie-break.
    expect(
      summary.largestCatches.first.catchModel.caughtAt,
      DateTime(2026, 7, 17),
    );
    expect(
      summary.largestCatches.last.catchModel.caughtAt,
      DateTime(2026, 7, 10),
    );
  });

  test('multiple catches of the same species sum correctly', () async {
    for (var i = 0; i < 3; i++) {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );
      await delay();
    }

    final summary = await statisticsRepository.getGeneralCatchStatistics();

    expect(summary.speciesCatchCounts, hasLength(1));
    expect(summary.speciesCatchCounts.single.species, FishSpecies.pike);
    expect(summary.speciesCatchCounts.single.catchCount, 3);
  });

  test('a tie in catch count between two species resolves deterministically '
      'by species identifier ascending', () async {
    // 'perch' sorts before 'pike' alphabetically.
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
    );
    await delay();
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.perch,
      caughtAt: DateTime(2026, 7, 17),
    );

    final summary = await statisticsRepository.getGeneralCatchStatistics();

    expect(summary.speciesCatchCounts, hasLength(2));
    expect(summary.speciesCatchCounts.first.species, FishSpecies.perch);
    expect(summary.speciesCatchCounts.last.species, FishSpecies.pike);
  });

  test('mostCaughtSpecies matches the top of speciesCatchCounts', () async {
    for (var i = 0; i < 2; i++) {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );
      await delay();
    }
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.perch,
      caughtAt: DateTime(2026, 7, 17),
    );

    final summary = await statisticsRepository.getGeneralCatchStatistics();

    expect(summary.mostCaughtSpecies?.species, FishSpecies.pike);
    expect(summary.mostCaughtSpecies, same(summary.speciesCatchCounts.first));
  });

  test('catches at two different fishing spots each resolve to their own '
      'correct FishingSpot in largestCatches', () async {
    // A real (not fake-clock) delay so the two generated identifiers
    // (derived from DateTime.now()) don't land on the same clock tick —
    // the same pre-existing mitigation already used elsewhere in this
    // project's test suite.
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final otherSpot = await fishingSpotRepository.create(
      name: 'Other Spot',
      latitude: 62.0,
      longitude: 26.0,
      waterBodyId: 'water-body-1',
    );

    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 3000,
    );
    await delay();
    await catchRepository.create(
      fishingSpotId: otherSpot.id,
      species: FishSpecies.perch,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 1000,
    );

    final summary = await statisticsRepository.getGeneralCatchStatistics();

    final atTestSpot = summary.largestCatches.firstWhere(
      (c) => c.catchModel.weightGrams == 3000,
    );
    final atOtherSpot = summary.largestCatches.firstWhere(
      (c) => c.catchModel.weightGrams == 1000,
    );
    expect(atTestSpot.fishingSpot.id, fishingSpot.id);
    expect(atOtherSpot.fishingSpot.id, otherSpot.id);
  });

  test(
    'deleting a catch changes totalCatches/speciesCatchCounts/largestCatches '
    'on the next call, with no stale data',
    () async {
      final created = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final before = await statisticsRepository.getGeneralCatchStatistics();
      expect(before.totalCatches, 1);
      expect(before.largestCatches, hasLength(1));
      expect(before.speciesCatchCounts, hasLength(1));

      await catchRepository.delete(created.id);

      final after = await statisticsRepository.getGeneralCatchStatistics();
      expect(after.totalCatches, 0);
      expect(after.largestCatches, isEmpty);
      expect(after.speciesCatchCounts, isEmpty);
    },
  );

  // Water Body List — computed from the same rows as the assertions above,
  // not a separate query. Grouped by WaterBody (via each catch's fishing
  // spot), not by FishingSpot.

  test('multiple catches at the same fishing spot are aggregated into one '
      'waterBodyCatchCounts entry', () async {
    for (var i = 0; i < 3; i++) {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );
      await delay();
    }

    final summary = await statisticsRepository.getGeneralCatchStatistics();

    expect(summary.waterBodyCatchCounts, hasLength(1));
    expect(summary.waterBodyCatchCounts.single.waterBody.id, 'water-body-1');
    expect(summary.waterBodyCatchCounts.single.catchCount, 3);
  });

  test(
    'catches at multiple fishing spots belonging to the same water body are '
    'combined into one waterBodyCatchCounts entry',
    () async {
      await delay();
      final otherSpot = await fishingSpotRepository.create(
        name: 'Other Spot',
        latitude: 62.0,
        longitude: 26.0,
        waterBodyId: 'water-body-1',
      );

      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );
      await delay();
      await catchRepository.create(
        fishingSpotId: otherSpot.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 17),
      );
      await delay();
      await catchRepository.create(
        fishingSpotId: otherSpot.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 17),
      );

      final summary = await statisticsRepository.getGeneralCatchStatistics();

      expect(summary.waterBodyCatchCounts, hasLength(1));
      expect(summary.waterBodyCatchCounts.single.waterBody.id, 'water-body-1');
      expect(summary.waterBodyCatchCounts.single.catchCount, 3);
    },
  );

  test(
    'catches at fishing spots belonging to different water bodies remain '
    'separate waterBodyCatchCounts entries',
    () async {
      await createWaterBody('water-body-2', 'Other Water Body');
      await delay();
      final otherWaterBodySpot = await fishingSpotRepository.create(
        name: 'Spot In Other Water Body',
        latitude: 62.0,
        longitude: 26.0,
        waterBodyId: 'water-body-2',
      );

      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );
      await delay();
      await catchRepository.create(
        fishingSpotId: otherWaterBodySpot.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 17),
      );

      final summary = await statisticsRepository.getGeneralCatchStatistics();

      expect(summary.waterBodyCatchCounts, hasLength(2));
      final ids = summary.waterBodyCatchCounts
          .map((entry) => entry.waterBody.id)
          .toSet();
      expect(ids, {'water-body-1', 'water-body-2'});
      for (final entry in summary.waterBodyCatchCounts) {
        expect(entry.catchCount, 1);
      }
    },
  );

  test(
    'a water body with no catches never appears in waterBodyCatchCounts',
    () async {
      await createWaterBody('water-body-2', 'Empty Water Body');
      await delay();
      await fishingSpotRepository.create(
        name: 'Empty Spot',
        latitude: 63.0,
        longitude: 27.0,
        waterBodyId: 'water-body-2',
      );

      final summary = await statisticsRepository.getGeneralCatchStatistics();

      expect(summary.waterBodyCatchCounts, isEmpty);
    },
  );

  test('waterBodyCatchCounts is sorted by catch count descending', () async {
    await createWaterBody('water-body-2', 'Other Water Body');
    await delay();
    final otherSpot = await fishingSpotRepository.create(
      name: 'Other Spot',
      latitude: 62.0,
      longitude: 26.0,
      waterBodyId: 'water-body-2',
    );

    await catchRepository.create(
      fishingSpotId: otherSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
    );
    await delay();
    for (var i = 0; i < 2; i++) {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 17),
      );
      await delay();
    }

    final summary = await statisticsRepository.getGeneralCatchStatistics();

    expect(summary.waterBodyCatchCounts, hasLength(2));
    expect(summary.waterBodyCatchCounts.first.waterBody.id, 'water-body-1');
    expect(summary.waterBodyCatchCounts.first.catchCount, 2);
    expect(summary.waterBodyCatchCounts.last.waterBody.id, 'water-body-2');
    expect(summary.waterBodyCatchCounts.last.catchCount, 1);
  });

  test(
    'two water bodies sharing the same display name resolve deterministically '
    'by id, and remain separate entries',
    () async {
      // Water body names have no uniqueness constraint (mirrors fishing
      // spot names, ADR-0004) — two water bodies can share a display name
      // and must still be counted and ordered as distinct entries.
      await createWaterBody('water-body-a', 'Kotijärvi');
      await createWaterBody('water-body-b', 'Kotijärvi');
      await delay();
      final spotA = await fishingSpotRepository.create(
        name: 'Spot A',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: 'water-body-a',
      );
      await delay();
      final spotB = await fishingSpotRepository.create(
        name: 'Spot B',
        latitude: 61.5,
        longitude: 25.5,
        waterBodyId: 'water-body-b',
      );

      await catchRepository.create(
        fishingSpotId: spotA.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );
      await delay();
      await catchRepository.create(
        fishingSpotId: spotB.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 17),
      );

      final summary = await statisticsRepository.getGeneralCatchStatistics();

      final matchingEntries = summary.waterBodyCatchCounts
          .where((entry) => entry.waterBody.name == 'Kotijärvi')
          .toList();
      expect(matchingEntries, hasLength(2));
      // Both are a tie on catch count (1) and on name ("Kotijärvi"), so the
      // final, guaranteed-unique tiebreak (water body id ascending)
      // determines the order.
      final expectedFirstId = 'water-body-a'.compareTo('water-body-b') < 0
          ? 'water-body-a'
          : 'water-body-b';
      expect(matchingEntries.first.waterBody.id, expectedFirstId);
    },
  );

  test('a tie in catch count between two differently-named water bodies '
      'resolves deterministically by name ascending', () async {
    await createWaterBody('water-body-2', 'Ahvenlampi');
    await delay();
    final otherSpot = await fishingSpotRepository.create(
      name: 'Other Spot',
      latitude: 62.0,
      longitude: 26.0,
      waterBodyId: 'water-body-2',
    );
    // fishingSpot's water body is named 'Test Water Body' (setUp);
    // 'Ahvenlampi' sorts first.

    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
    );
    await delay();
    await catchRepository.create(
      fishingSpotId: otherSpot.id,
      species: FishSpecies.perch,
      caughtAt: DateTime(2026, 7, 17),
    );

    final summary = await statisticsRepository.getGeneralCatchStatistics();

    expect(summary.waterBodyCatchCounts, hasLength(2));
    expect(summary.waterBodyCatchCounts.first.waterBody.name, 'Ahvenlampi');
    expect(summary.waterBodyCatchCounts.last.waterBody.name, 'Test Water Body');
  });

  test('existing totalCatches/largestCatches/speciesCatchCounts computation is '
      'unaffected by the added waterBodyCatchCounts aggregation', () async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 2500,
    );

    final summary = await statisticsRepository.getGeneralCatchStatistics();

    expect(summary.totalCatches, 1);
    expect(summary.largestCatches, hasLength(1));
    expect(summary.largestCatches.single.catchModel.weightGrams, 2500);
    expect(summary.speciesCatchCounts, hasLength(1));
    expect(summary.speciesCatchCounts.single.species, FishSpecies.pike);
    expect(summary.waterBodyCatchCounts, hasLength(1));
  });
}
