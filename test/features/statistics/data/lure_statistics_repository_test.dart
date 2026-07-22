import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/statistics/data/lure_statistics_repository.dart';

void main() {
  late AppDatabase database;
  late CatchRepository catchRepository;
  late LureStatisticsRepository statisticsRepository;
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
    statisticsRepository = LureStatisticsRepository(database);
    final fishingSpotRepository = FishingSpotRepository(database);
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

  Future<void> insertModel(
    AppDatabase database, {
    String id = 'model-1',
    String manufacturer = 'Rapala',
    String modelName = 'X-Rap 10',
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
    String id = 'variant-1',
    String modelId = 'model-1',
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

  /// Convenience combining [insertModel]/[insertVariant] for tests that
  /// only need one straightforward, resolvable lure.
  Future<String> insertLure(
    AppDatabase database, {
    String modelId = 'model-1',
    String variantId = 'variant-1',
    String manufacturer = 'Rapala',
    String modelName = 'X-Rap 10',
    String lureType = 'jerkbait',
    String colorName = 'Firetiger',
    int? retiredAt,
  }) async {
    await insertModel(
      database,
      id: modelId,
      manufacturer: manufacturer,
      modelName: modelName,
      lureType: lureType,
    );
    await insertVariant(
      database,
      id: variantId,
      modelId: modelId,
      colorName: colorName,
      retiredAt: retiredAt,
    );
    return variantId;
  }

  Future<void> insertDanglingCatch(
    AppDatabase database, {
    required String id,
    required String lureVariantId,
  }) async {
    await database.customStatement('PRAGMA foreign_keys = OFF');
    await database
        .into(database.catches)
        .insert(
          CatchesCompanion.insert(
            id: id,
            fishingSpotId: fishingSpot.id,
            species: 'pike',
            caughtAt: 1000,
            lureVariantId: Value(lureVariantId),
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    await database.customStatement('PRAGMA foreign_keys = ON');
  }

  test('no catches at all produces an empty summary', () async {
    final summary = await statisticsRepository.getLureStatistics();

    expect(summary.totalCatchesLinkedToLure, 0);
    expect(summary.lures, isEmpty);
    expect(summary.lureTypeBreakdown, isEmpty);
  });

  test('a catch with no assigned lure never contributes', () async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
    );

    final summary = await statisticsRepository.getLureStatistics();

    expect(summary.totalCatchesLinkedToLure, 0);
    expect(summary.lures, isEmpty);
    expect(summary.lureTypeBreakdown, isEmpty);
  });

  test(
    'one catch with a resolvable assigned lure counts everywhere once',
    () async {
      final lureVariantId = await insertLure(database);
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        lureVariantId: lureVariantId,
      );

      final summary = await statisticsRepository.getLureStatistics();

      expect(summary.totalCatchesLinkedToLure, 1);
      expect(summary.lures, hasLength(1));
      expect(summary.lures.single.catchCount, 1);
      expect(summary.lures.single.lure.id, lureVariantId);
      expect(summary.lureTypeBreakdown, hasLength(1));
      expect(summary.lureTypeBreakdown.single.catchCount, 1);
      expect(summary.lureTypeBreakdown.single.lureType, 'jerkbait');
    },
  );

  test(
    'multiple catches assigned to the same LureVariant accumulate',
    () async {
      final lureVariantId = await insertLure(database);
      for (var i = 0; i < 3; i++) {
        await catchRepository.create(
          fishingSpotId: fishingSpot.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 7, 17),
          lureVariantId: lureVariantId,
        );
        // CatchRepository derives ids from
        // DateTime.now().microsecondsSinceEpoch; a tiny delay avoids two
        // rapid calls landing on the same clock tick in this test
        // environment, matching catch_repository_test.dart's convention.
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }

      final summary = await statisticsRepository.getLureStatistics();

      expect(summary.totalCatchesLinkedToLure, 3);
      expect(summary.lures, hasLength(1));
      expect(summary.lures.single.catchCount, 3);
    },
  );

  test('multiple lures of the same lureType sum in the breakdown', () async {
    final firstVariantId = await insertLure(
      database,
      modelId: 'model-1',
      variantId: 'variant-1',
      lureType: 'jerkbait',
      colorName: 'Firetiger',
    );
    final secondVariantId = await insertLure(
      database,
      modelId: 'model-2',
      variantId: 'variant-2',
      lureType: 'jerkbait',
      colorName: 'Silver',
    );
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      lureVariantId: firstVariantId,
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      lureVariantId: secondVariantId,
    );

    final summary = await statisticsRepository.getLureStatistics();

    expect(summary.lureTypeBreakdown, hasLength(1));
    expect(summary.lureTypeBreakdown.single.lureType, 'jerkbait');
    expect(summary.lureTypeBreakdown.single.catchCount, 2);
  });

  test(
    'lures and lureTypeBreakdown are sorted by catch count descending',
    () async {
      final popularVariantId = await insertLure(
        database,
        modelId: 'model-1',
        variantId: 'variant-popular',
        lureType: 'jerkbait',
        colorName: 'Firetiger',
      );
      final rareVariantId = await insertLure(
        database,
        modelId: 'model-2',
        variantId: 'variant-rare',
        lureType: 'jig',
        colorName: 'Silver',
      );
      for (var i = 0; i < 3; i++) {
        await catchRepository.create(
          fishingSpotId: fishingSpot.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 7, 17),
          lureVariantId: popularVariantId,
        );
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        lureVariantId: rareVariantId,
      );

      final summary = await statisticsRepository.getLureStatistics();

      expect(summary.lures.first.lure.id, 'variant-popular');
      expect(summary.lures.last.lure.id, 'variant-rare');
      expect(summary.lureTypeBreakdown.first.lureType, 'jerkbait');
      expect(summary.lureTypeBreakdown.last.lureType, 'jig');
    },
  );

  test(
    'a tie in catch count between two lures resolves deterministically '
    '(manufacturer, then model, then distinguishing detail, then id)',
    () async {
      final variantB = await insertLure(
        database,
        modelId: 'model-b',
        variantId: 'variant-b',
        manufacturer: 'Rapala',
        modelName: 'X-Rap 10',
        colorName: 'Silver',
      );
      final variantA = await insertLure(
        database,
        modelId: 'model-a',
        variantId: 'variant-a',
        manufacturer: 'Abu Garcia',
        modelName: 'Toby',
        colorName: 'Gold',
      );
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        lureVariantId: variantB,
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        lureVariantId: variantA,
      );

      final summary = await statisticsRepository.getLureStatistics();

      expect(summary.lures[0].catchCount, 1);
      expect(summary.lures[1].catchCount, 1);
      // 'Abu Garcia' sorts before 'Rapala', so variant-a must come first
      // even though variant-b was inserted/caught first.
      expect(summary.lures.first.lure.id, 'variant-a');
      expect(summary.lures.last.lure.id, 'variant-b');
    },
  );

  test('a tie in catch count between two lure types resolves deterministically '
      'by lure type code', () async {
    final jigVariant = await insertLure(
      database,
      modelId: 'model-1',
      variantId: 'variant-1',
      lureType: 'jig',
    );
    final crankbaitVariant = await insertLure(
      database,
      modelId: 'model-2',
      variantId: 'variant-2',
      lureType: 'crankbait',
    );
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      lureVariantId: jigVariant,
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      lureVariantId: crankbaitVariant,
    );

    final summary = await statisticsRepository.getLureStatistics();

    // 'crankbait' sorts before 'jig'.
    expect(summary.lureTypeBreakdown.first.lureType, 'crankbait');
    expect(summary.lureTypeBreakdown.last.lureType, 'jig');
  });

  test(
    'a catch assigned to a retired LureVariant is still counted normally',
    () async {
      final lureVariantId = await insertLure(database, retiredAt: 5000);
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        lureVariantId: lureVariantId,
      );

      final summary = await statisticsRepository.getLureStatistics();

      expect(summary.totalCatchesLinkedToLure, 1);
      expect(summary.lures, hasLength(1));
      expect(summary.lures.single.catchCount, 1);
      expect(summary.lureTypeBreakdown.single.catchCount, 1);
    },
  );

  test('removing a TackleBoxEntry for a counted lure does not change its '
      'catch count', () async {
    final lureVariantId = await insertLure(database);
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      lureVariantId: lureVariantId,
    );
    await database
        .into(database.tackleBoxEntries)
        .insert(
          TackleBoxEntriesCompanion.insert(
            id: 'entry-1',
            lureVariantId: lureVariantId,
            addedAt: 1000,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );

    final before = await statisticsRepository.getLureStatistics();
    expect(before.lures.single.catchCount, 1);

    await (database.delete(
      database.tackleBoxEntries,
    )..where((t) => t.id.equals('entry-1'))).go();

    final after = await statisticsRepository.getLureStatistics();
    expect(after.lures.single.catchCount, 1);
    expect(after.totalCatchesLinkedToLure, before.totalCatchesLinkedToLure);
  });

  test('a catch with a dangling lureVariantId counts toward the total but is '
      'excluded from the lure list and lure-type breakdown', () async {
    final resolvableLureVariantId = await insertLure(database);
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      lureVariantId: resolvableLureVariantId,
    );
    await insertDanglingCatch(
      database,
      id: 'catch-dangling',
      lureVariantId: 'variant-does-not-exist',
    );

    final summary = await statisticsRepository.getLureStatistics();

    expect(summary.totalCatchesLinkedToLure, 2);
    expect(summary.lures, hasLength(1));
    expect(summary.lures.single.lure.id, resolvableLureVariantId);
    expect(summary.lureTypeBreakdown, hasLength(1));
  });
}
