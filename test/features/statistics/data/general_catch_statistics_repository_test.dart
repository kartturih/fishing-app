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
    catchRepository = CatchRepository(database);
    fishingSpotRepository = FishingSpotRepository(database);
    statisticsRepository = GeneralCatchStatisticsRepository(database);
    fishingSpot = await fishingSpotRepository.create(
      name: 'Test Spot',
      latitude: 61.0,
      longitude: 25.0,
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

  test('no catches at all produces an empty summary', () async {
    final summary = await statisticsRepository.getGeneralCatchStatistics();

    expect(summary.totalCatches, 0);
    expect(summary.largestCatches, isEmpty);
    expect(summary.speciesCatchCounts, isEmpty);
    expect(summary.fishingSpotCatchCounts, isEmpty);
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
    final otherSpot = await fishingSpotRepository.create(
      name: 'Other Spot',
      latitude: 62.0,
      longitude: 26.0,
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

  // Fishing Spot List (MFS-022/TD-022) — computed from the same rows as
  // the assertions above, not a separate query.

  test('multiple catches at the same fishing spot are aggregated into one '
      'fishingSpotCatchCounts entry', () async {
    for (var i = 0; i < 3; i++) {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );
      await delay();
    }

    final summary = await statisticsRepository.getGeneralCatchStatistics();

    expect(summary.fishingSpotCatchCounts, hasLength(1));
    expect(
      summary.fishingSpotCatchCounts.single.fishingSpot.id,
      fishingSpot.id,
    );
    expect(summary.fishingSpotCatchCounts.single.catchCount, 3);
  });

  test(
    'a fishing spot with no catches never appears in fishingSpotCatchCounts',
    () async {
      await fishingSpotRepository.create(
        name: 'Empty Spot',
        latitude: 63.0,
        longitude: 27.0,
      );

      final summary = await statisticsRepository.getGeneralCatchStatistics();

      expect(summary.fishingSpotCatchCounts, isEmpty);
    },
  );

  test('fishingSpotCatchCounts is sorted by catch count descending', () async {
    final otherSpot = await fishingSpotRepository.create(
      name: 'Other Spot',
      latitude: 62.0,
      longitude: 26.0,
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

    expect(summary.fishingSpotCatchCounts, hasLength(2));
    expect(summary.fishingSpotCatchCounts.first.fishingSpot.id, fishingSpot.id);
    expect(summary.fishingSpotCatchCounts.first.catchCount, 2);
    expect(summary.fishingSpotCatchCounts.last.fishingSpot.id, otherSpot.id);
    expect(summary.fishingSpotCatchCounts.last.catchCount, 1);
  });

  test(
    'two fishing spots sharing the same display name resolve deterministically '
    'by id, and remain separate entries',
    () async {
      // Fishing spot names have no uniqueness constraint (ADR-0004) — two
      // spots can share a display name and must still be counted and
      // ordered as distinct entries.
      final firstSpot = await fishingSpotRepository.create(
        name: 'Kotijärvi',
        latitude: 61.0,
        longitude: 25.0,
      );
      await delay();
      final secondSpot = await fishingSpotRepository.create(
        name: 'Kotijärvi',
        latitude: 61.5,
        longitude: 25.5,
      );
      expect(firstSpot.id, isNot(secondSpot.id));

      await catchRepository.create(
        fishingSpotId: firstSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );
      await delay();
      await catchRepository.create(
        fishingSpotId: secondSpot.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 17),
      );

      final summary = await statisticsRepository.getGeneralCatchStatistics();

      final matchingEntries = summary.fishingSpotCatchCounts
          .where((entry) => entry.fishingSpot.name == 'Kotijärvi')
          .toList();
      expect(matchingEntries, hasLength(2));
      // Both are a tie on catch count (1) and on name ("Kotijärvi"), so the
      // final, guaranteed-unique tiebreak (fishing spot id ascending)
      // determines the order.
      final expectedFirstId = firstSpot.id.compareTo(secondSpot.id) < 0
          ? firstSpot.id
          : secondSpot.id;
      expect(matchingEntries.first.fishingSpot.id, expectedFirstId);
    },
  );

  test('a tie in catch count between two differently-named fishing spots '
      'resolves deterministically by name ascending', () async {
    final otherSpot = await fishingSpotRepository.create(
      name: 'Ahvenlampi',
      latitude: 62.0,
      longitude: 26.0,
    );
    // fishingSpot is named 'Test Spot' (setUp); 'Ahvenlampi' sorts first.

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

    expect(summary.fishingSpotCatchCounts, hasLength(2));
    expect(summary.fishingSpotCatchCounts.first.fishingSpot.name, 'Ahvenlampi');
    expect(summary.fishingSpotCatchCounts.last.fishingSpot.name, 'Test Spot');
  });

  test('existing totalCatches/largestCatches/speciesCatchCounts computation is '
      'unaffected by the added fishingSpotCatchCounts aggregation', () async {
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
    expect(summary.fishingSpotCatchCounts, hasLength(1));
  });
}
