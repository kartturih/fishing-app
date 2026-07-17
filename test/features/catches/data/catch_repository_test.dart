import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

void main() {
  late AppDatabase database;
  late CatchRepository catchRepository;
  late FishingSpotRepository fishingSpotRepository;
  late FishingSpot fishingSpot;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    catchRepository = CatchRepository(database);
    fishingSpotRepository = FishingSpotRepository(database);
    fishingSpot = await fishingSpotRepository.create(
      name: 'Test Spot',
      latitude: 61.0,
      longitude: 25.0,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('CatchRepository.create', () {
    test('creates a catch linked to the correct fishing spot', () async {
      final createdCatch = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17, 14, 35),
        weightGrams: 2450,
        lengthMillimeters: 685,
      );

      expect(createdCatch.fishingSpotId, fishingSpot.id);
      expect(createdCatch.species, FishSpecies.pike);
      expect(createdCatch.weightGrams, 2450);
      expect(createdCatch.lengthMillimeters, 685);
      expect(createdCatch.createdAt, createdCatch.updatedAt);
    });

    test(
      'round-trips the species, weight, and length through the database',
      () async {
        final createdCatch = await catchRepository.create(
          fishingSpotId: fishingSpot.id,
          species: FishSpecies.zander,
          caughtAt: DateTime(2026, 7, 17, 14, 35),
          weightGrams: 1200,
          lengthMillimeters: 450,
        );

        final stored = await catchRepository.getById(createdCatch.id);

        expect(stored, isNotNull);
        expect(stored!.species, FishSpecies.zander);
        expect(stored.weightGrams, 1200);
        expect(stored.lengthMillimeters, 450);
        expect(stored.fishingSpotId, fishingSpot.id);
      },
    );

    test('stores null weight and length when omitted', () async {
      final createdCatch = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 17),
      );

      final stored = await catchRepository.getById(createdCatch.id);

      expect(stored!.weightGrams, isNull);
      expect(stored.lengthMillimeters, isNull);
    });

    test('getByFishingSpotId returns catches for that fishing spot', () async {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );
      // Identifiers are derived from DateTime.now().microsecondsSinceEpoch
      // (matching FishingSpotRepository's strategy); a tiny delay avoids two
      // calls landing on the same clock tick in this test environment.
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 16),
      );

      final catches = await catchRepository.getByFishingSpotId(fishingSpot.id);

      expect(catches, hasLength(2));
    });

    test('rejects a non-positive weight', () async {
      expect(
        () => catchRepository.create(
          fishingSpotId: fishingSpot.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 7, 17),
          weightGrams: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive length', () async {
      expect(
        () => catchRepository.create(
          fishingSpotId: fishingSpot.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 7, 17),
          lengthMillimeters: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('cascade deletion', () {
    test('deleting a fishing spot removes its catches', () async {
      final createdCatch = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );

      await fishingSpotRepository.delete(fishingSpot.id);

      final stored = await catchRepository.getById(createdCatch.id);
      expect(stored, isNull);
    });
  });
}
