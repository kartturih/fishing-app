import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/statistics/data/water_body_statistics_repository.dart';

void main() {
  late AppDatabase database;
  late CatchRepository catchRepository;
  late FishingSpotRepository fishingSpotRepository;
  late WaterBodyStatisticsRepository repository;
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
    repository = WaterBodyStatisticsRepository(database);
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

  // CatchRepository/FishingSpotRepository derive ids from
  // DateTime.now().microsecondsSinceEpoch; a tiny delay avoids two rapid
  // calls landing on the same clock tick in this test environment,
  // matching every other repository test's convention in this project.
  Future<void> delay() => Future<void>.delayed(const Duration(milliseconds: 2));

  Future<void> createWaterBody(String id, String name) {
    return database
        .into(database.waterBodies)
        .insert(
          WaterBodiesCompanion.insert(id: id, name: name, createdAt: 0),
        );
  }

  test('no catches at the water body produces an empty summary', () async {
    final summary = await repository.getWaterBodyStatistics('water-body-1');

    expect(summary.catches, isEmpty);
    expect(summary.totalCatches, 0);
    expect(summary.recordCatch, isNull);
    expect(summary.speciesCatchCounts, isEmpty);
    expect(summary.lastCatchDate, isNull);
  });

  test('catches at fishing spots belonging to a different water body are '
      'excluded from the result', () async {
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
      species: FishSpecies.perch,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 1000,
    );

    final summary = await repository.getWaterBodyStatistics('water-body-1');

    expect(summary.catches, isEmpty);
  });

  test(
    'catches at multiple fishing spots belonging to the same water body are '
    'all combined into the Catch List',
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
        weightGrams: 2000,
      );
      await delay();
      await catchRepository.create(
        fishingSpotId: otherSpot.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 1000,
      );

      final summary = await repository.getWaterBodyStatistics('water-body-1');

      expect(summary.catches, hasLength(2));
      expect(summary.totalCatches, 2);
      final fishingSpotIds = summary.catches
          .map((entry) => entry.fishingSpot.id)
          .toSet();
      expect(fishingSpotIds, {fishingSpot.id, otherSpot.id});
    },
  );

  test(
    'one catch at the water body with a recorded weight appears',
    () async {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2500,
      );

      final summary = await repository.getWaterBodyStatistics('water-body-1');

      expect(summary.catches, hasLength(1));
      expect(summary.catches.single.catchModel.weightGrams, 2500);
      expect(summary.catches.single.fishingSpot.id, fishingSpot.id);
      expect(summary.totalCatches, 1);
    },
  );

  test('catches at the water body are sorted by weight descending', () async {
    final weights = [1000, 4000, 2000];
    for (final weight in weights) {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: weight,
      );
      await delay();
    }

    final summary = await repository.getWaterBodyStatistics('water-body-1');

    expect(
      summary.catches
          .map((entry) => entry.catchModel.weightGrams)
          .toList(),
      [4000, 2000, 1000],
    );
  });

  test('a catch with no recorded weight sorts after every catch that has one, '
      'regardless of catch date', () async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 20),
    );
    await delay();
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 1),
      weightGrams: 500,
    );

    final summary = await repository.getWaterBodyStatistics('water-body-1');

    expect(summary.catches, hasLength(2));
    expect(summary.catches.first.catchModel.weightGrams, 500);
    expect(summary.catches.last.catchModel.weightGrams, isNull);
  });

  test('a tie in weight between two catches resolves deterministically by '
      'catch date descending', () async {
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

    final summary = await repository.getWaterBodyStatistics('water-body-1');

    expect(summary.catches, hasLength(2));
    expect(summary.catches.first.catchModel.caughtAt, DateTime(2026, 7, 17));
    expect(summary.catches.last.catchModel.caughtAt, DateTime(2026, 7, 10));
  });

  test(
    'recordCatch equals the first entry of the already-sorted catches list',
    () async {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 1000,
      );
      await delay();
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 5000,
      );

      final summary = await repository.getWaterBodyStatistics('water-body-1');

      expect(summary.recordCatch, same(summary.catches.first));
      expect(summary.recordCatch?.catchModel.weightGrams, 5000);
    },
  );

  test('speciesCatchCounts aggregates catches by species across every '
      'fishing spot under the water body', () async {
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
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
    );
    await delay();
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.perch,
      caughtAt: DateTime(2026, 7, 17),
    );

    final summary = await repository.getWaterBodyStatistics('water-body-1');

    expect(summary.speciesCatchCounts, hasLength(2));
    final pikeCount = summary.speciesCatchCounts.firstWhere(
      (s) => s.species == FishSpecies.pike,
    );
    expect(pikeCount.catchCount, 2);
  });

  test('lastCatchDate equals the true maximum caughtAt across every fishing '
      'spot under the water body', () async {
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
      caughtAt: DateTime(2026, 7, 1),
    );
    await delay();
    await catchRepository.create(
      fishingSpotId: otherSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 20),
    );
    await delay();
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 10),
    );

    final summary = await repository.getWaterBodyStatistics('water-body-1');

    expect(summary.lastCatchDate, DateTime(2026, 7, 20));
  });

  test(
    'deleting a catch at the water body changes catches/speciesCatchCounts/'
    'lastCatchDate on the next call, with no stale data',
    () async {
      final created = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final before = await repository.getWaterBodyStatistics('water-body-1');
      expect(before.totalCatches, 1);
      expect(before.lastCatchDate, isNotNull);

      await catchRepository.delete(created.id);

      final after = await repository.getWaterBodyStatistics('water-body-1');
      expect(after.totalCatches, 0);
      expect(after.catches, isEmpty);
      expect(after.speciesCatchCounts, isEmpty);
      expect(after.lastCatchDate, isNull);
    },
  );
}
