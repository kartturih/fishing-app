import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/statistics/data/species_statistics_repository.dart';

void main() {
  late AppDatabase database;
  late CatchRepository catchRepository;
  late FishingSpotRepository fishingSpotRepository;
  late SpeciesStatisticsRepository repository;
  late FishingSpot fishingSpot;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    catchRepository = CatchRepository(database);
    fishingSpotRepository = FishingSpotRepository(database);
    repository = SpeciesStatisticsRepository(database);
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
  // this test environment, matching general_catch_statistics_repository_test.dart's
  // convention.
  Future<void> delay() => Future<void>.delayed(const Duration(milliseconds: 2));

  test(
    'no catches of the requested species produces an empty summary',
    () async {
      final summary = await repository.getSpeciesStatistics(FishSpecies.pike);

      expect(summary.species, FishSpecies.pike);
      expect(summary.catches, isEmpty);
      expect(summary.totalCatches, 0);
      expect(summary.recordCatch, isNull);
    },
  );

  test('catches of other species are excluded from the result', () async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.perch,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 1000,
    );

    final summary = await repository.getSpeciesStatistics(FishSpecies.pike);

    expect(summary.catches, isEmpty);
  });

  test('one catch of the species with a recorded weight appears with its '
      'fishing spot correctly resolved', () async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 2500,
    );

    final summary = await repository.getSpeciesStatistics(FishSpecies.pike);

    expect(summary.catches, hasLength(1));
    expect(summary.catches.single.catchModel.weightGrams, 2500);
    expect(summary.catches.single.fishingSpot.id, fishingSpot.id);
    expect(summary.catches.single.fishingSpot.name, 'Test Spot');
  });

  test('catches of the species are sorted by weight descending', () async {
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

    final summary = await repository.getSpeciesStatistics(FishSpecies.pike);

    expect(
      summary.catches.map((entry) => entry.catchModel.weightGrams).toList(),
      [4000, 2000, 1000],
    );
  });

  test('a catch with no recorded weight sorts after every catch that has one, '
      'regardless of catch date', () async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      // Caught much later than the weighted catch below, but weight
      // still outranks catch date per the documented ordering.
      caughtAt: DateTime(2026, 7, 20),
    );
    await delay();
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 1),
      weightGrams: 500,
    );

    final summary = await repository.getSpeciesStatistics(FishSpecies.pike);

    expect(summary.catches, hasLength(2));
    expect(summary.catches.first.catchModel.weightGrams, 500);
    expect(summary.catches.last.catchModel.weightGrams, isNull);
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

    final summary = await repository.getSpeciesStatistics(FishSpecies.pike);

    expect(summary.catches, hasLength(2));
    expect(summary.catches.first.catchModel.caughtAt, DateTime(2026, 7, 20));
    expect(summary.catches.last.catchModel.caughtAt, DateTime(2026, 7, 1));
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

    final summary = await repository.getSpeciesStatistics(FishSpecies.pike);

    expect(summary.catches, hasLength(2));
    expect(summary.catches.first.catchModel.caughtAt, DateTime(2026, 7, 17));
    expect(summary.catches.last.catchModel.caughtAt, DateTime(2026, 7, 10));
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

    final summary = await repository.getSpeciesStatistics(FishSpecies.pike);

    expect(summary.catches, hasLength(2));
    expect(summary.catches.first.catchModel.id, first.id);
    expect(summary.catches.last.catchModel.id, second.id);
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

      final summary = await repository.getSpeciesStatistics(FishSpecies.pike);

      expect(summary.recordCatch, same(summary.catches.first));
      expect(summary.recordCatch?.catchModel.weightGrams, 5000);
    },
  );

  test('catches of the species at two different fishing spots each resolve to '
      'their own correct FishingSpot', () async {
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
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 1000,
    );

    final summary = await repository.getSpeciesStatistics(FishSpecies.pike);

    final atTestSpot = summary.catches.firstWhere(
      (entry) => entry.catchModel.weightGrams == 3000,
    );
    final atOtherSpot = summary.catches.firstWhere(
      (entry) => entry.catchModel.weightGrams == 1000,
    );
    expect(atTestSpot.fishingSpot.id, fishingSpot.id);
    expect(atOtherSpot.fishingSpot.id, otherSpot.id);
  });

  test(
    'deleting a catch of the species changes catches/totalCatches/recordCatch '
    'on the next call, with no stale data',
    () async {
      final created = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final before = await repository.getSpeciesStatistics(FishSpecies.pike);
      expect(before.totalCatches, 1);
      expect(before.recordCatch, isNotNull);

      await catchRepository.delete(created.id);

      final after = await repository.getSpeciesStatistics(FishSpecies.pike);
      expect(after.totalCatches, 0);
      expect(after.catches, isEmpty);
      expect(after.recordCatch, isNull);
    },
  );

  test("editing a catch's species away from the requested value removes it "
      'from the next call', () async {
    final created = await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 2000,
    );

    final before = await repository.getSpeciesStatistics(FishSpecies.pike);
    expect(before.totalCatches, 1);

    await catchRepository.update(
      catchModel: created,
      species: FishSpecies.perch,
      caughtAt: created.caughtAt,
      weightGrams: created.weightGrams,
    );

    final after = await repository.getSpeciesStatistics(FishSpecies.pike);
    expect(after.totalCatches, 0);
    final perchSummary = await repository.getSpeciesStatistics(
      FishSpecies.perch,
    );
    expect(perchSummary.totalCatches, 1);
  });

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

    final before = await repository.getSpeciesStatistics(FishSpecies.pike);
    expect(before.recordCatch?.catchModel.weightGrams, 5000);

    await catchRepository.update(
      catchModel: second,
      species: second.species,
      caughtAt: second.caughtAt,
      weightGrams: 9000,
    );

    final after = await repository.getSpeciesStatistics(FishSpecies.pike);
    expect(after.recordCatch?.catchModel.id, second.id);
    expect(after.recordCatch?.catchModel.weightGrams, 9000);
  });
}
