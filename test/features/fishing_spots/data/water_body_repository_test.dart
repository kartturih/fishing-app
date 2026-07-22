import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_repository.dart';

void main() {
  late AppDatabase database;
  late WaterBodyRepository repository;
  late FishingSpotRepository fishingSpotRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = WaterBodyRepository(database);
    fishingSpotRepository = FishingSpotRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('create', () {
    test('trims leading/trailing whitespace before storing', () async {
      final waterBody = await repository.create(name: '  Merrasjärvi  ');
      expect(waterBody.name, 'Merrasjärvi');
    });

    test('rejects an empty name', () async {
      expect(() => repository.create(name: ''), throwsArgumentError);
    });

    test('rejects a whitespace-only name', () async {
      expect(() => repository.create(name: '   '), throwsArgumentError);
    });

    test(
      'permits creating a second water body with a duplicate name',
      () async {
        await repository.create(name: 'Merrasjärvi');
        // A real (not fake-clock) delay so the two generated identifiers
        // (derived from DateTime.now()) don't land on the same clock tick.
        await Future<void>.delayed(const Duration(milliseconds: 2));
        final second = await repository.create(name: 'Merrasjärvi');
        final all = await repository.loadAll();
        expect(all, hasLength(2));
        expect(second.name, 'Merrasjärvi');
      },
    );
  });

  group('loadAll', () {
    test('returns every water body in alphabetical order', () async {
      await repository.create(name: 'Pohjoisjärvi');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repository.create(name: 'Ahvenlampi');
      final all = await repository.loadAll();
      expect(all.map((w) => w.name).toList(), ['Ahvenlampi', 'Pohjoisjärvi']);
    });

    test('returns an empty list when no water bodies exist', () async {
      expect(await repository.loadAll(), isEmpty);
    });
  });

  group('getById', () {
    test('returns the matching water body', () async {
      final created = await repository.create(name: 'Merrasjärvi');
      final found = await repository.getById(created.id);
      expect(found?.name, 'Merrasjärvi');
    });

    test('returns null for an unknown id', () async {
      expect(await repository.getById('unknown'), isNull);
    });
  });

  group('rename', () {
    test('trims and persists the new name', () async {
      final created = await repository.create(name: 'Old Name');
      final renamed = await repository.rename(
        id: created.id,
        name: '  New Name  ',
      );
      expect(renamed.name, 'New Name');
      final reloaded = await repository.getById(created.id);
      expect(reloaded?.name, 'New Name');
    });

    test('rejects an empty name', () async {
      final created = await repository.create(name: 'Old Name');
      expect(
        () => repository.rename(id: created.id, name: ''),
        throwsArgumentError,
      );
    });

    test('throws for an unknown id', () async {
      expect(
        () => repository.rename(id: 'unknown', name: 'New Name'),
        throwsStateError,
      );
    });
  });

  group('delete', () {
    test('succeeds for an empty water body', () async {
      final created = await repository.create(name: 'Empty');
      await repository.delete(created.id);
      expect(await repository.getById(created.id), isNull);
    });

    test(
      'throws for a non-empty water body and performs no database write',
      () async {
        final created = await repository.create(name: 'Merrasjärvi');
        await fishingSpotRepository.create(
          name: 'Koiraranta',
          latitude: 61.0,
          longitude: 25.0,
          waterBodyId: created.id,
        );

        expect(() => repository.delete(created.id), throwsStateError);
        // Still present — the delete was never attempted.
        expect(await repository.getById(created.id), isNotNull);
      },
    );
  });

  group('loadAllWithSpotCounts', () {
    test('includes a water body with zero fishing spots', () async {
      final created = await repository.create(name: 'Merrasjärvi');
      final all = await repository.loadAllWithSpotCounts();
      expect(all, hasLength(1));
      expect(all.single.waterBody.id, created.id);
      expect(all.single.fishingSpotCount, 0);
    });

    test('counts every fishing spot referencing a water body', () async {
      final waterBody = await repository.create(name: 'Merrasjärvi');
      await fishingSpotRepository.create(
        name: 'Koiraranta',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: waterBody.id,
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await fishingSpotRepository.create(
        name: 'Pohjoislahti',
        latitude: 61.1,
        longitude: 25.1,
        waterBodyId: waterBody.id,
      );

      final all = await repository.loadAllWithSpotCounts();
      expect(all.single.fishingSpotCount, 2);
    });
  });

  group('getNearby', () {
    test('returns candidates ordered by ascending distance', () async {
      final near = await repository.create(name: 'Near');
      await fishingSpotRepository.create(
        name: 'Near Spot',
        latitude: 61.001,
        longitude: 25.001,
        waterBodyId: near.id,
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final far = await repository.create(name: 'Far');
      await fishingSpotRepository.create(
        name: 'Far Spot',
        latitude: 65.0,
        longitude: 30.0,
        waterBodyId: far.id,
      );

      final result = await repository.getNearby(
        latitude: 61.0,
        longitude: 25.0,
      );
      expect(result.candidates.map((w) => w.id).toList(), [near.id, far.id]);
    });

    test(
      'preselects a single candidate within the threshold and margin',
      () async {
        final near = await repository.create(name: 'Near');
        await fishingSpotRepository.create(
          name: 'Near Spot',
          latitude: 61.0001,
          longitude: 25.0001,
          waterBodyId: near.id,
        );

        final result = await repository.getNearby(
          latitude: 61.0,
          longitude: 25.0,
        );
        expect(result.preselected?.id, near.id);
      },
    );

    test('preselects nothing when the nearest exceeds the threshold', () async {
      final far = await repository.create(name: 'Far');
      await fishingSpotRepository.create(
        name: 'Far Spot',
        latitude: 65.0,
        longitude: 30.0,
        waterBodyId: far.id,
      );

      final result = await repository.getNearby(
        latitude: 61.0,
        longitude: 25.0,
      );
      expect(result.preselected, isNull);
    });

    test('preselects nothing when two candidates are within the margin of '
        'each other', () async {
      final first = await repository.create(name: 'First');
      await fishingSpotRepository.create(
        name: 'First Spot',
        latitude: 61.0005,
        longitude: 25.0,
        waterBodyId: first.id,
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = await repository.create(name: 'Second');
      await fishingSpotRepository.create(
        name: 'Second Spot',
        latitude: 61.0006,
        longitude: 25.0,
        waterBodyId: second.id,
      );

      final result = await repository.getNearby(
        latitude: 61.0,
        longitude: 25.0,
      );
      expect(result.preselected, isNull);
    });

    test(
      'returns an empty result when no water body has any fishing spot',
      () async {
        await repository.create(name: 'Lonely');
        final result = await repository.getNearby(
          latitude: 61.0,
          longitude: 25.0,
        );
        expect(result.candidates, isEmpty);
        expect(result.preselected, isNull);
      },
    );
  });
}
