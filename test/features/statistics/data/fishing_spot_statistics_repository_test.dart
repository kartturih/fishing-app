import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/statistics/data/fishing_spot_statistics_repository.dart';

void main() {
  late AppDatabase database;
  late CatchRepository catchRepository;
  late FishingSpotRepository fishingSpotRepository;
  late FishingSpotStatisticsRepository repository;
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
    repository = FishingSpotStatisticsRepository(database);
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
  // this test environment, matching every other repository test's
  // convention in this project.
  Future<void> delay() => Future<void>.delayed(const Duration(milliseconds: 2));

  test('no catches at the fishing spot produces an empty summary', () async {
    final summary = await repository.getFishingSpotStatistics(fishingSpot.id);

    expect(summary.catches, isEmpty);
    expect(summary.totalCatches, 0);
    expect(summary.recordCatch, isNull);
    expect(summary.speciesCatchCounts, isEmpty);
    expect(summary.lastCatchDate, isNull);
  });

  test('catches at other fishing spots are excluded from the result', () async {
    // A real (not fake-clock) delay so the two generated identifiers
    // (derived from DateTime.now()) don't land on the same clock tick —
    // the same pre-existing mitigation already used elsewhere in this
    // project's test suite (e.g. fishing_spot_details_bottom_sheet_test.dart).
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final otherSpot = await fishingSpotRepository.create(
      name: 'Other Spot',
      latitude: 62.0,
      longitude: 26.0,
      waterBodyId: 'water-body-1',
    );
    await catchRepository.create(
      fishingSpotId: otherSpot.id,
      species: FishSpecies.perch,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 1000,
    );

    final summary = await repository.getFishingSpotStatistics(fishingSpot.id);

    expect(summary.catches, isEmpty);
  });

  test(
    'one catch at the fishing spot with a recorded weight appears',
    () async {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2500,
      );

      final summary = await repository.getFishingSpotStatistics(fishingSpot.id);

      expect(summary.catches, hasLength(1));
      expect(summary.catches.single.weightGrams, 2500);
      expect(summary.totalCatches, 1);
    },
  );

  test('catches at the fishing spot are sorted by weight descending', () async {
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

    final summary = await repository.getFishingSpotStatistics(fishingSpot.id);

    expect(
      summary.catches.map((catchModel) => catchModel.weightGrams).toList(),
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

    final summary = await repository.getFishingSpotStatistics(fishingSpot.id);

    expect(summary.catches, hasLength(2));
    expect(summary.catches.first.weightGrams, 500);
    expect(summary.catches.last.weightGrams, isNull);
  });

  test('when every catch has no recorded weight, catches are sorted by catch '
      'date descending', () async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 1),
    );
    await delay();
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 20),
    );

    final summary = await repository.getFishingSpotStatistics(fishingSpot.id);

    expect(summary.catches, hasLength(2));
    expect(summary.catches.first.caughtAt, DateTime(2026, 7, 20));
    expect(summary.catches.last.caughtAt, DateTime(2026, 7, 1));
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

    final summary = await repository.getFishingSpotStatistics(fishingSpot.id);

    expect(summary.catches, hasLength(2));
    expect(summary.catches.first.caughtAt, DateTime(2026, 7, 17));
    expect(summary.catches.last.caughtAt, DateTime(2026, 7, 10));
  });

  test('a tie in both weight and catch date resolves deterministically by '
      'catch id ascending', () async {
    final first = await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 2000,
    );
    await delay();
    final second = await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 2000,
    );
    expect(first.id.compareTo(second.id), lessThan(0));

    final summary = await repository.getFishingSpotStatistics(fishingSpot.id);

    expect(summary.catches, hasLength(2));
    expect(summary.catches.first.id, first.id);
    expect(summary.catches.last.id, second.id);
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

      final summary = await repository.getFishingSpotStatistics(fishingSpot.id);

      expect(summary.recordCatch, same(summary.catches.first));
      expect(summary.recordCatch?.weightGrams, 5000);
    },
  );

  test('recordCatch is the most recently caught entry when no catch has a '
      'recorded weight', () async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 1),
    );
    await delay();
    final mostRecent = await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 20),
    );

    final summary = await repository.getFishingSpotStatistics(fishingSpot.id);

    expect(summary.recordCatch?.id, mostRecent.id);
    expect(summary.recordCatch?.weightGrams, isNull);
  });

  test('speciesCatchCounts aggregates catches by species', () async {
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

    final summary = await repository.getFishingSpotStatistics(fishingSpot.id);

    expect(summary.speciesCatchCounts, hasLength(2));
    final pikeCount = summary.speciesCatchCounts.firstWhere(
      (s) => s.species == FishSpecies.pike,
    );
    expect(pikeCount.catchCount, 2);
  });

  test('speciesCatchCounts is sorted by catch count descending with '
      'deterministic tie-breaking', () async {
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

    final summary = await repository.getFishingSpotStatistics(fishingSpot.id);

    expect(summary.speciesCatchCounts, hasLength(2));
    expect(summary.speciesCatchCounts.first.species, FishSpecies.perch);
    expect(summary.speciesCatchCounts.last.species, FishSpecies.pike);
  });

  test('lastCatchDate equals the true maximum caughtAt', () async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 1),
    );
    await delay();
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 20),
    );
    await delay();
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 10),
    );

    final summary = await repository.getFishingSpotStatistics(fishingSpot.id);

    expect(summary.lastCatchDate, DateTime(2026, 7, 20));
  });

  test('lastCatchDate is not derived from catches.first — the chronologically '
      'most recent catch need not be the heaviest', () async {
    // The heaviest catch (and therefore catches.first / recordCatch) is
    // caught earlier than a lighter, more recent catch.
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 1),
      weightGrams: 9000,
    );
    await delay();
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.perch,
      caughtAt: DateTime(2026, 7, 20),
      weightGrams: 100,
    );

    final summary = await repository.getFishingSpotStatistics(fishingSpot.id);

    expect(summary.recordCatch?.weightGrams, 9000);
    expect(summary.recordCatch?.caughtAt, DateTime(2026, 7, 1));
    expect(summary.lastCatchDate, DateTime(2026, 7, 20));
  });

  test(
    'deleting a catch at the fishing spot changes catches/speciesCatchCounts/'
    'lastCatchDate on the next call, with no stale data',
    () async {
      final created = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final before = await repository.getFishingSpotStatistics(fishingSpot.id);
      expect(before.totalCatches, 1);
      expect(before.lastCatchDate, isNotNull);

      await catchRepository.delete(created.id);

      final after = await repository.getFishingSpotStatistics(fishingSpot.id);
      expect(after.totalCatches, 0);
      expect(after.catches, isEmpty);
      expect(after.speciesCatchCounts, isEmpty);
      expect(after.lastCatchDate, isNull);
    },
  );

  test("editing a catch's weight such that it becomes the heaviest changes "
      'recordCatch on the next call', () async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 5000,
    );
    await delay();
    final second = await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 1000,
    );

    final before = await repository.getFishingSpotStatistics(fishingSpot.id);
    expect(before.recordCatch?.weightGrams, 5000);

    await catchRepository.update(
      catchModel: second,
      species: second.species,
      caughtAt: second.caughtAt,
      weightGrams: 9000,
    );

    final after = await repository.getFishingSpotStatistics(fishingSpot.id);
    expect(after.recordCatch?.id, second.id);
    expect(after.recordCatch?.weightGrams, 9000);
  });
}
