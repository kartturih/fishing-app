import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch_notes_limits.dart';
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

  Future<String> insertLureVariant(
    AppDatabase database, {
    String id = 'variant-1',
  }) async {
    const modelId = 'model-1';
    await database
        .into(database.lureModels)
        .insertOnConflictUpdate(
          LureModelsCompanion.insert(
            id: modelId,
            manufacturer: 'Rapala',
            modelName: 'X-Rap Shad XRS08',
            lureType: 'crankbait',
            searchText: 'rapala x-rap shad xrs08',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    await database
        .into(database.lureVariants)
        .insert(
          LureVariantsCompanion.insert(
            id: id,
            lureModelId: modelId,
            colorName: const Value('Hot Craw'),
            searchText: 'hot craw',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    return id;
  }

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

  group('CatchRepository.update', () {
    test('updates the species', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );

      final updated = await catchRepository.update(
        catchModel: original,
        species: FishSpecies.zander,
        caughtAt: original.caughtAt,
      );

      expect(updated.species, FishSpecies.zander);
      final stored = await catchRepository.getById(original.id);
      expect(stored!.species, FishSpecies.zander);
    });

    test('updates the caught-at date and time', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17, 10, 0),
      );

      final newCaughtAt = DateTime(2026, 7, 18, 12, 30);
      final updated = await catchRepository.update(
        catchModel: original,
        species: original.species,
        caughtAt: newCaughtAt,
      );

      expect(updated.caughtAt, newCaughtAt);
    });

    test('updates the weight', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 1000,
      );

      final updated = await catchRepository.update(
        catchModel: original,
        species: original.species,
        caughtAt: original.caughtAt,
        weightGrams: 2500,
      );

      expect(updated.weightGrams, 2500);
    });

    test('updates the length', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        lengthMillimeters: 500,
      );

      final updated = await catchRepository.update(
        catchModel: original,
        species: original.species,
        caughtAt: original.caughtAt,
        lengthMillimeters: 720,
      );

      expect(updated.lengthMillimeters, 720);
    });

    test('clears an existing weight when omitted', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 1000,
      );

      final updated = await catchRepository.update(
        catchModel: original,
        species: original.species,
        caughtAt: original.caughtAt,
      );

      expect(updated.weightGrams, isNull);
      final stored = await catchRepository.getById(original.id);
      expect(stored!.weightGrams, isNull);
    });

    test('clears an existing length when omitted', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        lengthMillimeters: 500,
      );

      final updated = await catchRepository.update(
        catchModel: original,
        species: original.species,
        caughtAt: original.caughtAt,
      );

      expect(updated.lengthMillimeters, isNull);
      final stored = await catchRepository.getById(original.id);
      expect(stored!.lengthMillimeters, isNull);
    });

    test('preserves id, fishingSpotId, and createdAt', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );

      final updated = await catchRepository.update(
        catchModel: original,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 7, 18),
      );

      expect(updated.id, original.id);
      expect(updated.fishingSpotId, original.fishingSpotId);
      expect(updated.createdAt, original.createdAt);
    });

    test('refreshes updatedAt', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );

      await Future<void>.delayed(const Duration(milliseconds: 2));

      final updated = await catchRepository.update(
        catchModel: original,
        species: original.species,
        caughtAt: original.caughtAt,
      );

      expect(updated.updatedAt.isAfter(original.updatedAt), isTrue);
    });

    test('rejects a non-positive weight', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );

      expect(
        () => catchRepository.update(
          catchModel: original,
          species: original.species,
          caughtAt: original.caughtAt,
          weightGrams: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive length', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );

      expect(
        () => catchRepository.update(
          catchModel: original,
          species: original.species,
          caughtAt: original.caughtAt,
          lengthMillimeters: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('CatchRepository.delete', () {
    test('deletes an existing catch', () async {
      final created = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );

      await catchRepository.delete(created.id);

      expect(await catchRepository.getById(created.id), isNull);
    });

    test('completes successfully when the catch does not exist', () async {
      await expectLater(
        catchRepository.delete('catch-does-not-exist'),
        completes,
      );
    });

    test('only affects the selected catch', () async {
      final first = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 16),
      );

      await catchRepository.delete(first.id);

      expect(await catchRepository.getById(first.id), isNull);
      expect(await catchRepository.getById(second.id), isNotNull);
    });

    test('rejects an empty id', () async {
      expect(() => catchRepository.delete(''), throwsArgumentError);
    });
  });

  group('CatchRepository lureVariantId', () {
    test('create persists a provided lureVariantId', () async {
      final lureVariantId = await insertLureVariant(database);

      final created = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        lureVariantId: lureVariantId,
      );

      expect(created.lureVariantId, lureVariantId);
      final stored = await catchRepository.getById(created.id);
      expect(stored!.lureVariantId, lureVariantId);
    });

    test('create stores null when lureVariantId is omitted', () async {
      final created = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );

      expect(created.lureVariantId, isNull);
    });

    test('create rejects an empty lureVariantId', () async {
      expect(
        () => catchRepository.create(
          fishingSpotId: fishingSpot.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 7, 17),
          lureVariantId: '',
        ),
        throwsArgumentError,
      );
    });

    test('update assigns a lureVariantId to a catch that had none', () async {
      final lureVariantId = await insertLureVariant(database);
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );

      final updated = await catchRepository.update(
        catchModel: original,
        species: original.species,
        caughtAt: original.caughtAt,
        lureVariantId: lureVariantId,
      );

      expect(updated.lureVariantId, lureVariantId);
    });

    test('update can change an existing lureVariantId', () async {
      final firstVariantId = await insertLureVariant(database, id: 'variant-1');
      final secondVariantId = await insertLureVariant(
        database,
        id: 'variant-2',
      );
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        lureVariantId: firstVariantId,
      );

      final updated = await catchRepository.update(
        catchModel: original,
        species: original.species,
        caughtAt: original.caughtAt,
        lureVariantId: secondVariantId,
      );

      expect(updated.lureVariantId, secondVariantId);
    });

    test('update clears an existing lureVariantId when omitted', () async {
      final lureVariantId = await insertLureVariant(database);
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        lureVariantId: lureVariantId,
      );

      final updated = await catchRepository.update(
        catchModel: original,
        species: original.species,
        caughtAt: original.caughtAt,
      );

      expect(updated.lureVariantId, isNull);
      final stored = await catchRepository.getById(original.id);
      expect(stored!.lureVariantId, isNull);
    });

    test('update rejects an empty lureVariantId', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );

      expect(
        () => catchRepository.update(
          catchModel: original,
          species: original.species,
          caughtAt: original.caughtAt,
          lureVariantId: '',
        ),
        throwsArgumentError,
      );
    });
  });

  group('CatchRepository notes', () {
    test('create stores null when notes is omitted', () async {
      final created = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );

      expect(created.notes, isNull);
    });

    test('create persists a normal notes value', () async {
      final created = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        notes: 'Tuulinen ilta, hauki iski laineeseen.',
      );

      expect(created.notes, 'Tuulinen ilta, hauki iski laineeseen.');
      final stored = await catchRepository.getById(created.id);
      expect(stored!.notes, 'Tuulinen ilta, hauki iski laineeseen.');
    });

    test('create persists notes at exactly the limit', () async {
      final notes = 'a' * maxCatchNotesLength;

      final created = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        notes: notes,
      );

      expect(created.notes, hasLength(maxCatchNotesLength));
    });

    test('create rejects notes longer than the limit', () async {
      final notes = 'a' * (maxCatchNotesLength + 1);

      expect(
        () => catchRepository.create(
          fishingSpotId: fishingSpot.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 7, 17),
          notes: notes,
        ),
        throwsArgumentError,
      );
    });

    test('create trims leading and trailing whitespace from notes', () async {
      final created = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        notes: '  Iso hauki illalla.  ',
      );

      expect(created.notes, 'Iso hauki illalla.');
    });

    test('create preserves internal spaces and line breaks in notes', () async {
      final created = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        notes: 'Ensimmäinen rivi.\nToinen  rivi.',
      );

      expect(created.notes, 'Ensimmäinen rivi.\nToinen  rivi.');
    });

    test('create stores null when notes is whitespace-only', () async {
      final created = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        notes: '   \n  ',
      );

      expect(created.notes, isNull);
    });

    test('update can add notes to a catch that had none', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );

      final updated = await catchRepository.update(
        catchModel: original,
        species: original.species,
        caughtAt: original.caughtAt,
        notes: 'Uusi muistiinpano.',
      );

      expect(updated.notes, 'Uusi muistiinpano.');
      final stored = await catchRepository.getById(original.id);
      expect(stored!.notes, 'Uusi muistiinpano.');
    });

    test('update can change an existing notes value', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        notes: 'Vanha muistiinpano.',
      );

      final updated = await catchRepository.update(
        catchModel: original,
        species: original.species,
        caughtAt: original.caughtAt,
        notes: 'Päivitetty muistiinpano.',
      );

      expect(updated.notes, 'Päivitetty muistiinpano.');
    });

    test('update clears an existing notes value when omitted', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        notes: 'Poistettava muistiinpano.',
      );

      final updated = await catchRepository.update(
        catchModel: original,
        species: original.species,
        caughtAt: original.caughtAt,
      );

      expect(updated.notes, isNull);
      final stored = await catchRepository.getById(original.id);
      expect(stored!.notes, isNull);
    });

    test(
      'update clears an existing notes value when whitespace-only',
      () async {
        final original = await catchRepository.create(
          fishingSpotId: fishingSpot.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 7, 17),
          notes: 'Poistettava muistiinpano.',
        );

        final updated = await catchRepository.update(
          catchModel: original,
          species: original.species,
          caughtAt: original.caughtAt,
          notes: '   ',
        );

        expect(updated.notes, isNull);
      },
    );

    test('update rejects notes longer than the limit', () async {
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
      );
      final notes = 'a' * (maxCatchNotesLength + 1);

      expect(
        () => catchRepository.update(
          catchModel: original,
          species: original.species,
          caughtAt: original.caughtAt,
          notes: notes,
        ),
        throwsArgumentError,
      );
    });

    test('getByFishingSpotId returns the correct notes value', () async {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        notes: 'Muistiinpano listauksessa.',
      );

      final catches = await catchRepository.getByFishingSpotId(fishingSpot.id);

      expect(catches.single.notes, 'Muistiinpano listauksessa.');
    });
  });
}
