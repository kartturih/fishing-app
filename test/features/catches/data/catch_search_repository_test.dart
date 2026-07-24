import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/data/catch_search_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/catch_search_criteria.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

void main() {
  late AppDatabase database;
  late CatchRepository catchRepository;
  late FishingSpotRepository fishingSpotRepository;
  late CatchSearchRepository searchRepository;

  late FishingSpot koiraranta; // water-body-1 (Merrasjärvi)
  late FishingSpot pohjoislahti; // water-body-1 (Merrasjärvi)
  late FishingSpot keskusranta; // water-body-2 (Näsijärvi)

  // CatchRepository/FishingSpotRepository derive ids from
  // DateTime.now().microsecondsSinceEpoch; a tiny delay avoids two rapid
  // calls landing on the same clock tick in this test environment,
  // matching every other repository test's convention in this project
  // (e.g. general_catch_statistics_repository_test.dart).
  Future<void> delay() => Future<void>.delayed(const Duration(milliseconds: 2));

  Future<FishingSpot> createSpot({
    required String name,
    required double latitude,
    required double longitude,
    required String waterBodyId,
  }) async {
    await delay();
    return fishingSpotRepository.create(
      name: name,
      latitude: latitude,
      longitude: longitude,
      waterBodyId: waterBodyId,
    );
  }

  Future<Catch> createCatch({
    required String fishingSpotId,
    required FishSpecies species,
    required DateTime caughtAt,
    int? weightGrams,
    int? lengthMillimeters,
    String? lureVariantId,
  }) async {
    await delay();
    return catchRepository.create(
      fishingSpotId: fishingSpotId,
      species: species,
      caughtAt: caughtAt,
      weightGrams: weightGrams,
      lengthMillimeters: lengthMillimeters,
      lureVariantId: lureVariantId,
    );
  }

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database
        .into(database.waterBodies)
        .insert(
          const WaterBodiesCompanion(
            id: Value('water-body-1'),
            name: Value('Merrasjärvi'),
            createdAt: Value(0),
          ),
        );
    await database
        .into(database.waterBodies)
        .insert(
          const WaterBodiesCompanion(
            id: Value('water-body-2'),
            name: Value('Näsijärvi'),
            createdAt: Value(0),
          ),
        );
    // A water body with a fishing spot but no catches at all — must never
    // appear in getFilterOptions(), and must never surface in a search
    // result either.
    await database
        .into(database.waterBodies)
        .insert(
          const WaterBodiesCompanion(
            id: Value('water-body-3'),
            name: Value('Tyhjäjärvi'),
            createdAt: Value(0),
          ),
        );

    catchRepository = CatchRepository(database);
    fishingSpotRepository = FishingSpotRepository(database);
    searchRepository = CatchSearchRepository(database);

    koiraranta = await createSpot(
      name: 'Koiraranta',
      latitude: 61.0,
      longitude: 25.0,
      waterBodyId: 'water-body-1',
    );
    pohjoislahti = await createSpot(
      name: 'Pohjoislahti',
      latitude: 61.1,
      longitude: 25.1,
      waterBodyId: 'water-body-1',
    );
    keskusranta = await createSpot(
      name: 'Keskusranta',
      latitude: 61.2,
      longitude: 25.2,
      waterBodyId: 'water-body-2',
    );
    await createSpot(
      name: 'Autio',
      latitude: 61.3,
      longitude: 25.3,
      waterBodyId: 'water-body-3',
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> insertModel(
    AppDatabase database, {
    required String id,
    required String manufacturer,
    required String modelName,
    String lureType = 'jerkbait',
  }) async {
    await database
        .into(database.lureModels)
        .insertOnConflictUpdate(
          LureModelsCompanion.insert(
            id: id,
            manufacturer: manufacturer,
            modelName: modelName,
            lureType: lureType,
            searchText: '$manufacturer $modelName'.toLowerCase(),
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
  }

  Future<void> insertVariant(
    AppDatabase database, {
    required String id,
    required String modelId,
    String colorName = 'Firetiger',
    int? retiredAt,
  }) async {
    await database
        .into(database.lureVariants)
        .insert(
          LureVariantsCompanion.insert(
            id: id,
            lureModelId: modelId,
            colorName: Value(colorName),
            searchText: colorName.toLowerCase(),
            retiredAt: Value(retiredAt),
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
  }

  /// Combines [insertModel]/[insertVariant] for the common case of one
  /// straightforward, resolvable lure.
  Future<String> insertLure(
    AppDatabase database, {
    required String modelId,
    required String variantId,
    required String manufacturer,
    required String modelName,
    int? retiredAt,
  }) async {
    await insertModel(
      database,
      id: modelId,
      manufacturer: manufacturer,
      modelName: modelName,
    );
    await insertVariant(
      database,
      id: variantId,
      modelId: modelId,
      retiredAt: retiredAt,
    );
    return variantId;
  }

  /// Seeds a catch whose `lureVariantId` references a row that does not
  /// exist at all — a genuinely dangling reference, not merely a retired
  /// one — by temporarily disabling foreign-key enforcement, mirroring the
  /// established technique already used for
  /// `lure_statistics_repository_test.dart`/`fishing_spot_mapper_test.dart`.
  Future<void> insertDanglingCatch(
    AppDatabase database, {
    required String id,
    required String fishingSpotId,
    required String species,
    required int caughtAt,
    required String danglingLureVariantId,
  }) async {
    await database.customStatement('PRAGMA foreign_keys = OFF');
    await database
        .into(database.catches)
        .insert(
          CatchesCompanion.insert(
            id: id,
            fishingSpotId: fishingSpotId,
            species: species,
            caughtAt: caughtAt,
            lureVariantId: Value(danglingLureVariantId),
            createdAt: caughtAt,
            updatedAt: caughtAt,
          ),
        );
    await database.customStatement('PRAGMA foreign_keys = ON');
  }

  group('unfiltered search', () {
    test('an empty query returns every catch, fully enriched', () async {
      final pike = await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
        weightGrams: 2450,
      );

      final results = await searchRepository.search(CatchSearchCriteria.empty);

      expect(results, hasLength(1));
      expect(results.single.catchModel.id, pike.id);
      expect(results.single.fishingSpot.id, koiraranta.id);
      expect(results.single.waterBody.id, 'water-body-1');
      expect(results.single.lure, isNull);
    });

    test('no catches at all returns an empty list, not an error', () async {
      final results = await searchRepository.search(CatchSearchCriteria.empty);

      expect(results, isEmpty);
    });
  });

  group('free-text search — species', () {
    test(
      'full Finnish species name matches every catch of that species',
      () async {
        await createCatch(
          fishingSpotId: koiraranta.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 1, 10),
        );
        await createCatch(
          fishingSpotId: pohjoislahti.id,
          species: FishSpecies.zander,
          caughtAt: DateTime(2026, 1, 11),
        );

        final results = await searchRepository.search(
          const CatchSearchCriteria(query: 'hauki'),
        );

        expect(results, hasLength(1));
        expect(results.single.catchModel.species, FishSpecies.pike);
      },
    );

    test('a partial species name matches', () async {
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );

      final results = await searchRepository.search(
        const CatchSearchCriteria(query: 'hau'),
      );

      expect(results, hasLength(1));
    });

    test('the stored English enum value itself is not matched — only the '
        'localized Finnish name is', () async {
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );

      final results = await searchRepository.search(
        const CatchSearchCriteria(query: 'pike'),
      );

      expect(results, isEmpty);
    });
  });

  group('free-text search — water body', () {
    test('full water body name matches every catch under it', () async {
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );
      await createCatch(
        fishingSpotId: pohjoislahti.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 1, 11),
      );
      await createCatch(
        fishingSpotId: keskusranta.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 1, 12),
      );

      final results = await searchRepository.search(
        const CatchSearchCriteria(query: 'Merrasjärvi'),
      );

      expect(results, hasLength(2));
      expect(results.map((r) => r.waterBody.name), everyElement('Merrasjärvi'));
    });

    test('a partial, case-different water body name matches', () async {
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );

      final results = await searchRepository.search(
        const CatchSearchCriteria(query: 'MERRAS'),
      );

      expect(results, hasLength(1));
    });
  });

  group('free-text search — fishing spot', () {
    test('fishing spot name matches only catches at that exact spot', () async {
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );
      await createCatch(
        fishingSpotId: pohjoislahti.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 1, 11),
      );

      final results = await searchRepository.search(
        const CatchSearchCriteria(query: 'koiraranta'),
      );

      expect(results, hasLength(1));
      expect(results.single.fishingSpot.id, koiraranta.id);
    });
  });

  group('free-text search — lure brand and model', () {
    test('lure brand (manufacturer) matches', () async {
      final variantId = await insertLure(
        database,
        modelId: 'model-rapala',
        variantId: 'variant-rapala',
        manufacturer: 'Rapala',
        modelName: 'X-Rap Shad',
      );
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 2, 15),
        lureVariantId: variantId,
      );

      final results = await searchRepository.search(
        const CatchSearchCriteria(query: 'rapala'),
      );

      expect(results, hasLength(1));
      expect(results.single.lure?.manufacturer, 'Rapala');
    });

    test('lure model/name matches', () async {
      final variantId = await insertLure(
        database,
        modelId: 'model-rapala',
        variantId: 'variant-rapala',
        manufacturer: 'Rapala',
        modelName: 'X-Rap Shad',
      );
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 2, 15),
        lureVariantId: variantId,
      );

      final results = await searchRepository.search(
        const CatchSearchCriteria(query: 'x-rap'),
      );

      expect(results, hasLength(1));
    });

    test(
      'a catch whose lure has since been retired is still found by name',
      () async {
        final variantId = await insertLure(
          database,
          modelId: 'model-abu',
          variantId: 'variant-abu',
          manufacturer: 'Abu Garcia',
          modelName: 'Zebco',
          retiredAt: 5000,
        );
        await createCatch(
          fishingSpotId: keskusranta.id,
          species: FishSpecies.perch,
          caughtAt: DateTime(2026, 3, 1),
          lureVariantId: variantId,
        );

        final results = await searchRepository.search(
          const CatchSearchCriteria(query: 'abu garcia'),
        );

        expect(results, hasLength(1));
        expect(results.single.lure?.manufacturer, 'Abu Garcia');
      },
    );

    test(
      'a catch with no assigned lure is unaffected by a lure-name search',
      () async {
        await createCatch(
          fishingSpotId: koiraranta.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 1, 10),
        );

        final results = await searchRepository.search(
          const CatchSearchCriteria(query: 'rapala'),
        );

        expect(results, isEmpty);
      },
    );
  });

  group('search behavior', () {
    test('matching is case-insensitive for every searchable field', () async {
      final variantId = await insertLure(
        database,
        modelId: 'model-rapala',
        variantId: 'variant-rapala',
        manufacturer: 'Rapala',
        modelName: 'X-Rap Shad',
      );
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
        lureVariantId: variantId,
      );

      expect(
        await searchRepository.search(
          const CatchSearchCriteria(query: 'HAUKI'),
        ),
        hasLength(1),
      );
      expect(
        await searchRepository.search(
          const CatchSearchCriteria(query: 'KOIRARANTA'),
        ),
        hasLength(1),
      );
      expect(
        await searchRepository.search(
          const CatchSearchCriteria(query: 'RAPALA'),
        ),
        hasLength(1),
      );
    });

    test('leading and trailing whitespace is ignored', () async {
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );

      final results = await searchRepository.search(
        const CatchSearchCriteria(query: '   hauki   '),
      );

      expect(results, hasLength(1));
    });

    test(
      'an empty query returns the full list, subject to active filters',
      () async {
        await createCatch(
          fishingSpotId: koiraranta.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 1, 10),
        );
        await createCatch(
          fishingSpotId: pohjoislahti.id,
          species: FishSpecies.zander,
          caughtAt: DateTime(2026, 1, 11),
        );

        final results = await searchRepository.search(
          const CatchSearchCriteria(query: '', species: FishSpecies.pike),
        );

        expect(results, hasLength(1));
        expect(results.single.catchModel.species, FishSpecies.pike);
      },
    );
  });

  group('filters — individually', () {
    test('water body filter', () async {
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );
      await createCatch(
        fishingSpotId: keskusranta.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 1, 11),
      );

      final results = await searchRepository.search(
        const CatchSearchCriteria(waterBodyId: 'water-body-1'),
      );

      expect(results, hasLength(1));
      expect(results.single.waterBody.id, 'water-body-1');
    });

    test('species filter', () async {
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 1, 11),
      );

      final results = await searchRepository.search(
        const CatchSearchCriteria(species: FishSpecies.zander),
      );

      expect(results, hasLength(1));
      expect(results.single.catchModel.species, FishSpecies.zander);
    });

    test('lure filter', () async {
      final variantId = await insertLure(
        database,
        modelId: 'model-rapala',
        variantId: 'variant-rapala',
        manufacturer: 'Rapala',
        modelName: 'X-Rap Shad',
      );
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 2, 15),
        lureVariantId: variantId,
      );
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );

      final results = await searchRepository.search(
        CatchSearchCriteria(lureVariantId: variantId),
      );

      expect(results, hasLength(1));
      expect(results.single.lure?.variant.id, variantId);
    });

    test('lure filter matches even a retired variant, by exact id', () async {
      final variantId = await insertLure(
        database,
        modelId: 'model-abu',
        variantId: 'variant-abu',
        manufacturer: 'Abu Garcia',
        modelName: 'Zebco',
        retiredAt: 5000,
      );
      await createCatch(
        fishingSpotId: keskusranta.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 3, 1),
        lureVariantId: variantId,
      );

      final results = await searchRepository.search(
        CatchSearchCriteria(lureVariantId: variantId),
      );

      expect(results, hasLength(1));
    });

    test('date range filter is inclusive at both boundaries', () async {
      final from = DateTime(2026, 2, 1);
      final to = DateTime(2026, 2, 28);
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: from, // exactly on the lower boundary
      );
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.zander,
        caughtAt: to, // exactly on the upper boundary
      );
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 1, 31), // one day before the range
      );
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.burbot,
        caughtAt: DateTime(2026, 3, 1), // one day after the range
      );

      final results = await searchRepository.search(
        CatchSearchCriteria(dateFrom: from, dateTo: to),
      );

      expect(results, hasLength(2));
      expect(
        results.map((r) => r.catchModel.species),
        containsAll([FishSpecies.pike, FishSpecies.zander]),
      );
    });
  });

  group('filters — combined (AND semantics)', () {
    test('two active filters narrow correctly', () async {
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );
      await createCatch(
        fishingSpotId: pohjoislahti.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 11),
      );
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 1, 12),
      );

      final results = await searchRepository.search(
        const CatchSearchCriteria(
          waterBodyId: 'water-body-1',
          species: FishSpecies.pike,
        ),
      );

      expect(results, hasLength(2));
      expect(
        results.map((r) => r.catchModel.species),
        everyElement(FishSpecies.pike),
      );
    });

    test('a combination matching nothing returns an empty list', () async {
      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );

      final results = await searchRepository.search(
        const CatchSearchCriteria(
          waterBodyId: 'water-body-2',
          species: FishSpecies.pike,
        ),
      );

      expect(results, isEmpty);
    });

    test('text search combined with an active filter', () async {
      final variantId = await insertLure(
        database,
        modelId: 'model-rapala',
        variantId: 'variant-rapala',
        manufacturer: 'Rapala',
        modelName: 'X-Rap Shad',
      );
      await createCatch(
        fishingSpotId: koiraranta.id, // water-body-1
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 2, 15),
        lureVariantId: variantId,
      );

      final matching = await searchRepository.search(
        const CatchSearchCriteria(query: 'rapala', waterBodyId: 'water-body-1'),
      );
      final nonMatching = await searchRepository.search(
        const CatchSearchCriteria(query: 'rapala', waterBodyId: 'water-body-2'),
      );

      expect(matching, hasLength(1));
      expect(nonMatching, isEmpty);
    });
  });

  group('legacy/dangling data handling', () {
    test(
      'a dangling lureVariantId resolves to a null lure, no crash',
      () async {
        await insertDanglingCatch(
          database,
          id: 'catch-dangling',
          fishingSpotId: koiraranta.id,
          species: 'pike',
          caughtAt: 1000,
          danglingLureVariantId: 'variant-does-not-exist',
        );

        final results = await searchRepository.search(
          CatchSearchCriteria.empty,
        );

        expect(results, hasLength(1));
        expect(results.single.lure, isNull);
      },
    );

    test(
      'a dangling lureVariantId is never offered as a filter option',
      () async {
        await insertDanglingCatch(
          database,
          id: 'catch-dangling',
          fishingSpotId: koiraranta.id,
          species: 'pike',
          caughtAt: 1000,
          danglingLureVariantId: 'variant-does-not-exist',
        );

        final options = await searchRepository.getFilterOptions();

        expect(options.lures, isEmpty);
      },
    );
  });

  group('deterministic ordering', () {
    test('orders by caughtAt desc, then createdAt desc, then id asc', () async {
      // Two catches share the same caughtAt; createdAt breaks the tie.
      await database
          .into(database.catches)
          .insert(
            CatchesCompanion.insert(
              id: 'catch-b',
              fishingSpotId: koiraranta.id,
              species: 'pike',
              caughtAt: 2000,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      await database
          .into(database.catches)
          .insert(
            CatchesCompanion.insert(
              id: 'catch-a',
              fishingSpotId: koiraranta.id,
              species: 'zander',
              caughtAt: 2000,
              createdAt: 2000,
              updatedAt: 2000,
            ),
          );
      // A third, older catch sorts last.
      await database
          .into(database.catches)
          .insert(
            CatchesCompanion.insert(
              id: 'catch-c',
              fishingSpotId: koiraranta.id,
              species: 'perch',
              caughtAt: 1000,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );

      final results = await searchRepository.search(CatchSearchCriteria.empty);

      expect(results.map((r) => r.catchModel.id).toList(), [
        'catch-a',
        'catch-b',
        'catch-c',
      ]);
    });
  });

  group('getFilterOptions', () {
    test(
      'returns only water bodies/species/lures with at least one catch',
      () async {
        final variantId = await insertLure(
          database,
          modelId: 'model-rapala',
          variantId: 'variant-rapala',
          manufacturer: 'Rapala',
          modelName: 'X-Rap Shad',
        );
        await createCatch(
          fishingSpotId: koiraranta.id, // water-body-1
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 1, 10),
          lureVariantId: variantId,
        );
        await createCatch(
          fishingSpotId: keskusranta.id, // water-body-2
          species: FishSpecies.perch,
          caughtAt: DateTime(2026, 1, 11),
        );
        // water-body-3 has a fishing spot but no catch — must be excluded.

        final options = await searchRepository.getFilterOptions();

        expect(
          options.waterBodies.map((w) => w.id),
          unorderedEquals(['water-body-1', 'water-body-2']),
        );
        expect(
          options.species,
          unorderedEquals([FishSpecies.pike, FishSpecies.perch]),
        );
        expect(options.lures.map((l) => l.variant.id), [variantId]);
      },
    );

    test(
      'a retired lure with a catch is still offered as a filter option',
      () async {
        final variantId = await insertLure(
          database,
          modelId: 'model-abu',
          variantId: 'variant-abu',
          manufacturer: 'Abu Garcia',
          modelName: 'Zebco',
          retiredAt: 5000,
        );
        await createCatch(
          fishingSpotId: keskusranta.id,
          species: FishSpecies.perch,
          caughtAt: DateTime(2026, 3, 1),
          lureVariantId: variantId,
        );

        final options = await searchRepository.getFilterOptions();

        expect(options.lures, hasLength(1));
        expect(options.lures.single.variant.id, variantId);
      },
    );

    test('water bodies are sorted alphabetically', () async {
      await createCatch(
        fishingSpotId: keskusranta.id, // Näsijärvi
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 1, 11),
      );
      await createCatch(
        fishingSpotId: koiraranta.id, // Merrasjärvi
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );

      final options = await searchRepository.getFilterOptions();

      expect(options.waterBodies.map((w) => w.name).toList(), [
        'Merrasjärvi',
        'Näsijärvi',
      ]);
    });

    test('no catches at all produces empty filter options', () async {
      final options = await searchRepository.getFilterOptions();

      expect(options.waterBodies, isEmpty);
      expect(options.species, isEmpty);
      expect(options.lures, isEmpty);
    });
  });

  group('live updates', () {
    test('a newly created catch is reflected by a subsequent search', () async {
      expect(await searchRepository.search(CatchSearchCriteria.empty), isEmpty);

      await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );

      expect(
        await searchRepository.search(CatchSearchCriteria.empty),
        hasLength(1),
      );
    });

    test(
      'editing a catch so it no longer matches a species filter removes it',
      () async {
        final created = await createCatch(
          fishingSpotId: koiraranta.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 1, 10),
        );

        final beforeEdit = await searchRepository.search(
          const CatchSearchCriteria(species: FishSpecies.pike),
        );
        expect(beforeEdit, hasLength(1));

        await catchRepository.update(
          catchModel: created,
          species: FishSpecies.zander,
          caughtAt: created.caughtAt,
        );

        final afterEdit = await searchRepository.search(
          const CatchSearchCriteria(species: FishSpecies.pike),
        );
        expect(afterEdit, isEmpty);
      },
    );

    test('deleting a catch removes it from subsequent results', () async {
      final created = await createCatch(
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );

      expect(
        await searchRepository.search(CatchSearchCriteria.empty),
        hasLength(1),
      );

      await catchRepository.delete(created.id);

      expect(await searchRepository.search(CatchSearchCriteria.empty), isEmpty);
    });
  });
}
