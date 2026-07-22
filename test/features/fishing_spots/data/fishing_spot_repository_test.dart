import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_repository.dart';

void main() {
  late AppDatabase database;
  late FishingSpotRepository repository;
  late WaterBodyRepository waterBodyRepository;
  late String waterBodyId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = FishingSpotRepository(database);
    waterBodyRepository = WaterBodyRepository(database);
    waterBodyId = (await waterBodyRepository.create(name: 'Merrasjärvi')).id;
  });

  tearDown(() async {
    await database.close();
  });

  group('create', () {
    test('requires and persists waterBodyId', () async {
      final spot = await repository.create(
        name: 'Koiraranta',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: waterBodyId,
      );
      expect(spot.waterBodyId, waterBodyId);

      final all = await repository.loadAll();
      expect(all.single.waterBodyId, waterBodyId);
    });

    test('rejects an empty waterBodyId', () async {
      expect(
        () => repository.create(
          name: 'Koiraranta',
          latitude: 61.0,
          longitude: 25.0,
          waterBodyId: '',
        ),
        throwsArgumentError,
      );
    });

    test('rejects an unknown waterBodyId (foreign key)', () async {
      expect(
        () => repository.create(
          name: 'Koiraranta',
          latitude: 61.0,
          longitude: 25.0,
          waterBodyId: 'unknown-water-body',
        ),
        throwsA(anything),
      );
    });
  });

  group('updateWaterBody', () {
    test('changes only the water-body reference, leaving name/coordinates/id '
        'untouched', () async {
      final spot = await repository.create(
        name: 'Koiraranta',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: waterBodyId,
      );
      final otherWaterBody = await waterBodyRepository.create(
        name: 'Toinenjärvi',
      );

      final updated = await repository.updateWaterBody(
        id: spot.id,
        waterBodyId: otherWaterBody.id,
      );

      expect(updated.id, spot.id);
      expect(updated.name, spot.name);
      expect(updated.latitude, spot.latitude);
      expect(updated.longitude, spot.longitude);
      expect(updated.waterBodyId, otherWaterBody.id);
    });

    test('rejects an empty waterBodyId', () async {
      final spot = await repository.create(
        name: 'Koiraranta',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: waterBodyId,
      );
      expect(
        () => repository.updateWaterBody(id: spot.id, waterBodyId: ''),
        throwsArgumentError,
      );
    });

    test('throws for an unknown fishing spot id', () async {
      expect(
        () =>
            repository.updateWaterBody(id: 'unknown', waterBodyId: waterBodyId),
        throwsStateError,
      );
    });
  });

  group('getByWaterBodyId', () {
    test(
      'returns only fishing spots referencing that water body, ordered',
      () async {
        final otherWaterBody = await waterBodyRepository.create(name: 'Toinen');
        // Real (not fake-clock) delays so the generated identifiers (derived
        // from DateTime.now()) don't land on the same clock tick — the same
        // pre-existing mitigation already used elsewhere in this project's
        // test suite.
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await repository.create(
          name: 'Ruovikkoniemi',
          latitude: 61.2,
          longitude: 25.2,
          waterBodyId: waterBodyId,
        );
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await repository.create(
          name: 'Koiraranta',
          latitude: 61.0,
          longitude: 25.0,
          waterBodyId: waterBodyId,
        );
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await repository.create(
          name: 'Muualla',
          latitude: 62.0,
          longitude: 26.0,
          waterBodyId: otherWaterBody.id,
        );

        final spots = await repository.getByWaterBodyId(waterBodyId);
        expect(spots.map((s) => s.name).toList(), [
          'Koiraranta',
          'Ruovikkoniemi',
        ]);
      },
    );

    test(
      'returns an empty list for a water body with no fishing spots',
      () async {
        expect(await repository.getByWaterBodyId(waterBodyId), isEmpty);
      },
    );
  });

  group('existing behavior is unaffected (regression)', () {
    test('updateName changes only the name', () async {
      final spot = await repository.create(
        name: 'Old Name',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: waterBodyId,
      );
      final renamed = await repository.updateName(
        id: spot.id,
        name: 'New Name',
      );
      expect(renamed.name, 'New Name');
      expect(renamed.waterBodyId, waterBodyId);
      expect(renamed.latitude, spot.latitude);
      expect(renamed.longitude, spot.longitude);
    });

    test('delete removes the fishing spot', () async {
      final spot = await repository.create(
        name: 'Koiraranta',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: waterBodyId,
      );
      await repository.delete(spot.id);
      expect(await repository.loadAll(), isEmpty);
    });

    test('loadAll returns every fishing spot', () async {
      await repository.create(
        name: 'Koiraranta',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: waterBodyId,
      );
      final all = await repository.loadAll();
      expect(all, hasLength(1));
    });

    test('watchAll emits an updated list after a create', () async {
      final stream = repository.watchAll();
      final firstEmission = await stream.first;
      expect(firstEmission, isEmpty);

      await repository.create(
        name: 'Koiraranta',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: waterBodyId,
      );

      final updated = await repository.watchAll().firstWhere(
        (spots) => spots.isNotEmpty,
      );
      expect(updated, hasLength(1));
    });
  });
}
