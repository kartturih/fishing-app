import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_asset_loader.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_model.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';

import '../../../support/lure_catalog_test_doubles.dart';

final DateTime _testAuthoredAt = DateTime.utc(2026, 1, 1);

/// Mirrors the content that used to live in the now-deleted
/// `lure_catalog_seed_data.dart` (MFS-015/TD-015) -- same manufacturers,
/// models, variants, and ids, now expressed as test fixture data for the
/// asset-driven `ensureSeeded()` (MFS-028/TD-028) instead of as a
/// production Dart seed source.
final List<LureModel> testCatalogModels = [
  LureModel(
    id: '3149d765-a567-49ec-994b-74179d3171c1',
    manufacturer: 'Rapala',
    productFamily: 'X-Rap',
    modelName: 'X-Rap Shad XRS08',
    lureType: 'crankbait',
    defaultImageReference: 'assets/lure_catalog/placeholder_crankbait.png',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureModel(
    id: '7eb042d9-8826-4e12-bcb4-bc0079f03aee',
    manufacturer: 'Abu Garcia',
    modelName: 'Toby',
    lureType: 'spoon',
    defaultImageReference: 'assets/lure_catalog/placeholder_spoon.png',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureModel(
    id: '5d824c1b-1611-47f5-9724-982a846d5126',
    manufacturer: 'Storm',
    productFamily: 'WildEye',
    modelName: 'Swim Shad',
    lureType: 'swimbait',
    defaultImageReference: 'assets/lure_catalog/placeholder_swimbait.png',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureModel(
    id: 'c5a8db14-e9a0-4d85-ada3-79de1e09d3ad',
    manufacturer: 'Rapala',
    modelName: 'Jigging Rap W5',
    lureType: 'jig',
    defaultImageReference: 'assets/lure_catalog/placeholder_jig.png',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
];

final List<LureVariant> testCatalogVariants = [
  LureVariant(
    id: '442e3a0c-a3f2-49cf-9e8f-751adff94b02',
    lureModelId: '3149d765-a567-49ec-994b-74179d3171c1',
    colorName: 'Hot Craw',
    manufacturerColorCode: 'HCC',
    lengthMillimeters: 80,
    weightGrams: 12,
    minRunningDepthMillimeters: 1500,
    maxRunningDepthMillimeters: 2400,
    buoyancy: 'suspending',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureVariant(
    id: 'a12963ad-e94d-4585-835a-c2673cc0704c',
    lureModelId: '3149d765-a567-49ec-994b-74179d3171c1',
    colorName: 'Silver Shad',
    manufacturerColorCode: 'SSD',
    lengthMillimeters: 80,
    weightGrams: 12,
    minRunningDepthMillimeters: 1500,
    maxRunningDepthMillimeters: 2400,
    buoyancy: 'suspending',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureVariant(
    id: '8befcbdf-0930-490e-840d-dd60af63f819',
    lureModelId: '3149d765-a567-49ec-994b-74179d3171c1',
    colorName: 'Perch',
    manufacturerColorCode: 'PER',
    lengthMillimeters: 80,
    weightGrams: 12,
    minRunningDepthMillimeters: 1500,
    maxRunningDepthMillimeters: 2400,
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureVariant(
    id: 'e4be0987-2e2e-402d-85d9-955fc54f9c15',
    lureModelId: '3149d765-a567-49ec-994b-74179d3171c1',
    variantName: 'Glow',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureVariant(
    id: '2de7edb3-b772-40c9-a51c-75c5f20c233f',
    lureModelId: '7eb042d9-8826-4e12-bcb4-bc0079f03aee',
    colorName: 'Silver',
    manufacturerColorCode: 'S',
    lengthMillimeters: 60,
    weightGrams: 18,
    buoyancy: 'sinking',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureVariant(
    id: '20aa5fab-19d8-4163-85fd-e0fef63ea3c6',
    lureModelId: '7eb042d9-8826-4e12-bcb4-bc0079f03aee',
    colorName: 'Copper',
    lengthMillimeters: 65,
    weightGrams: 24,
    buoyancy: 'sinking',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureVariant(
    id: '09fedc45-c024-4008-bcb1-ff1d4a398c66',
    lureModelId: '7eb042d9-8826-4e12-bcb4-bc0079f03aee',
    colorName: 'Firetiger',
    lengthMillimeters: 50,
    weightGrams: 12,
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureVariant(
    id: 'e3c58f5b-f165-4399-b9f4-b6edcff4809d',
    lureModelId: '5d824c1b-1611-47f5-9724-982a846d5126',
    colorName: 'Emerald Shiner',
    lengthMillimeters: 130,
    weightGrams: 20,
    buoyancy: 'sinking',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureVariant(
    id: '0f5052f8-4a46-4fdc-af9c-a1eed353a98a',
    lureModelId: '5d824c1b-1611-47f5-9724-982a846d5126',
    colorName: 'Bluegill',
    lengthMillimeters: 130,
    weightGrams: 20,
    buoyancy: 'sinking',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureVariant(
    id: '3369ff41-4786-4c07-9eed-c37193a8f2e0',
    lureModelId: '5d824c1b-1611-47f5-9724-982a846d5126',
    colorName: 'Golden Shiner',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureVariant(
    id: 'db8cbcfd-a5ac-41ab-ba1c-3c7429440d7e',
    lureModelId: 'c5a8db14-e9a0-4d85-ada3-79de1e09d3ad',
    colorName: 'Glow Red',
    manufacturerColorCode: 'GR',
    lengthMillimeters: 50,
    weightGrams: 7,
    buoyancy: 'sinking',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureVariant(
    id: '319180d6-5773-461d-9e91-32c0b9f2cb9a',
    lureModelId: 'c5a8db14-e9a0-4d85-ada3-79de1e09d3ad',
    colorName: 'Blue Silver',
    lengthMillimeters: 50,
    weightGrams: 7,
    buoyancy: 'sinking',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureVariant(
    id: 'd121d97c-d147-4996-8646-2a89384268df',
    lureModelId: 'c5a8db14-e9a0-4d85-ada3-79de1e09d3ad',
    colorName: 'Perch',
    lengthMillimeters: 50,
    weightGrams: 7,
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
  LureVariant(
    id: '67a1b1ab-ce08-4e30-9847-dd7dc6e34e60',
    lureModelId: 'c5a8db14-e9a0-4d85-ada3-79de1e09d3ad',
    colorName: 'Gold',
    createdAt: _testAuthoredAt,
    updatedAt: _testAuthoredAt,
  ),
];

const testCatalogVersion = 1;

ParsedLureCatalog buildTestCatalog({
  List<LureModel>? models,
  List<LureVariant>? variants,
  int catalogVersion = testCatalogVersion,
}) {
  return ParsedLureCatalog(
    catalogVersion: catalogVersion,
    models: models ?? testCatalogModels,
    variants: variants ?? testCatalogVariants,
  );
}

/// Every `LureVariants` row's `updatedAt`, keyed by id -- used to prove a
/// reconciliation pass touched (or didn't touch) any row, independent of
/// row count.
Future<Map<String, int>> _variantUpdatedAtById(AppDatabase database) async {
  final rows = await database.select(database.lureVariants).get();
  return {for (final row in rows) row.id: row.updatedAt};
}

void main() {
  late AppDatabase database;
  late LureCatalogRepository repository;
  late FakeLureCatalogAssetLoader loader;
  late InMemoryLureCatalogVersionStore versionStore;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LureCatalogRepository(database);
    loader = FakeLureCatalogAssetLoader(buildTestCatalog());
    versionStore = InMemoryLureCatalogVersionStore();
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seed() =>
      repository.ensureSeeded(assetLoader: loader, versionStore: versionStore);

  group('ensureSeeded', () {
    test('inserts all catalog models and variants on first call', () async {
      await seed();

      final models = await database.select(database.lureModels).get();
      final variants = await database.select(database.lureVariants).get();

      expect(models, hasLength(testCatalogModels.length));
      expect(variants, hasLength(testCatalogVariants.length));
      for (final model in models) {
        expect(model.seedVersion, testCatalogVersion);
      }
      for (final variant in variants) {
        expect(variant.seedVersion, testCatalogVersion);
        expect(variant.retiredAt, isNull);
      }
    });

    test(
      'a second full-reconciliation pass performs no writes (idempotent)',
      () async {
        await seed();
        final before = await database.select(database.lureVariants).get();

        // A fresh version store forces a genuine full reconciliation pass
        // (not the fast path below), directly exercising the per-row
        // seedVersion comparison's own idempotency.
        await repository.ensureSeeded(
          assetLoader: loader,
          versionStore: InMemoryLureCatalogVersionStore(),
        );
        final after = await database.select(database.lureVariants).get();

        expect(after.length, before.length);
        for (var i = 0; i < before.length; i++) {
          expect(after[i].updatedAt, before[i].updatedAt);
        }
      },
    );

    test(
      'a second call with the same version store never touches the '
      'database at all (fast path)',
      () async {
        await seed();

        // Directly corrupt a row's content in a way that WOULD be corrected
        // if full reconciliation ran again -- proves the second call
        // skipped reconciliation entirely, not merely that its result
        // happened to match.
        final targetId = testCatalogModels.first.id;
        await (database.update(
          database.lureModels,
        )..where((t) => t.id.equals(targetId))).write(
          const LureModelsCompanion(manufacturer: Value('Corrupted By Test')),
        );

        await seed(); // same loader, same versionStore as the first call

        final row = await (database.select(
          database.lureModels,
        )..where((t) => t.id.equals(targetId))).getSingle();
        expect(row.manufacturer, 'Corrupted By Test');
      },
    );

    test(
      'corrects a row whose stored seedVersion is behind current, preserving createdAt',
      () async {
        final seedVariant = testCatalogVariants.first;
        // Simulate a row shipped by an earlier catalog version, with stale content.
        await database
            .into(database.lureModels)
            .insert(
              LureModelsCompanion.insert(
                id: testCatalogModels.first.id,
                manufacturer: 'Old Manufacturer Name',
                modelName: testCatalogModels.first.modelName,
                lureType: testCatalogModels.first.lureType,
                searchText: 'old manufacturer name',
                seedVersion: const Value(0),
                createdAt: 500,
                updatedAt: 500,
              ),
            );
        await database
            .into(database.lureVariants)
            .insert(
              LureVariantsCompanion.insert(
                id: seedVariant.id,
                lureModelId: seedVariant.lureModelId,
                colorName: const Value('Old Color Name'),
                searchText: 'old color name',
                seedVersion: const Value(0),
                createdAt: 500,
                updatedAt: 500,
              ),
            );

        await seed();

        final model =
            await (database.select(database.lureModels)
                  ..where((t) => t.id.equals(testCatalogModels.first.id)))
                .getSingle();
        final variant = await (database.select(
          database.lureVariants,
        )..where((t) => t.id.equals(seedVariant.id))).getSingle();

        expect(model.manufacturer, testCatalogModels.first.manufacturer);
        expect(model.createdAt, 500); // preserved
        expect(model.updatedAt, isNot(500)); // corrected
        expect(model.seedVersion, testCatalogVersion);

        expect(variant.colorName, seedVariant.colorName);
        expect(variant.createdAt, 500); // preserved
        expect(variant.updatedAt, isNot(500)); // corrected
        expect(variant.seedVersion, testCatalogVersion);
      },
    );

    test('never modifies a row whose stored seedVersion is null', () async {
      final seedModel = testCatalogModels.first;
      final seedVariant = testCatalogVariants.first;

      await database
          .into(database.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: seedModel.id,
              manufacturer: 'Server Managed Manufacturer',
              modelName: seedModel.modelName,
              lureType: seedModel.lureType,
              searchText: 'server managed manufacturer',
              createdAt: 500,
              updatedAt: 500,
            ),
          );
      await database
          .into(database.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: seedVariant.id,
              lureModelId: seedVariant.lureModelId,
              colorName: const Value('Server Managed Color'),
              searchText: 'server managed color',
              createdAt: 500,
              updatedAt: 500,
            ),
          );

      await seed();

      final model = await (database.select(
        database.lureModels,
      )..where((t) => t.id.equals(seedModel.id))).getSingle();
      final variant = await (database.select(
        database.lureVariants,
      )..where((t) => t.id.equals(seedVariant.id))).getSingle();

      expect(model.manufacturer, 'Server Managed Manufacturer');
      expect(model.seedVersion, isNull);
      expect(model.updatedAt, 500);

      expect(variant.colorName, 'Server Managed Color');
      expect(variant.seedVersion, isNull);
      expect(variant.updatedAt, 500);
    });

    test(
      'retires a catalog-owned variant removed from the current catalog content',
      () async {
        const removedId = 'removed-variant-id';
        await database
            .into(database.lureModels)
            .insert(
              LureModelsCompanion.insert(
                id: testCatalogModels.first.id,
                manufacturer: testCatalogModels.first.manufacturer,
                modelName: testCatalogModels.first.modelName,
                lureType: testCatalogModels.first.lureType,
                searchText: 'x',
                seedVersion: const Value(testCatalogVersion),
                createdAt: 500,
                updatedAt: 500,
              ),
            );
        await database
            .into(database.lureVariants)
            .insert(
              LureVariantsCompanion.insert(
                id: removedId,
                lureModelId: testCatalogModels.first.id,
                colorName: const Value('No Longer Sold'),
                searchText: 'no longer sold',
                seedVersion: const Value(testCatalogVersion),
                createdAt: 500,
                updatedAt: 500,
              ),
            );

        await seed();

        final row = await (database.select(
          database.lureVariants,
        )..where((t) => t.id.equals(removedId))).getSingle();

        expect(row.retiredAt, isNotNull);
      },
    );

    test(
      'clears retiredAt for a variant that reappears in the catalog content',
      () async {
        final seedModel = testCatalogModels.first;
        final seedVariant = testCatalogVariants.first;

        await database
            .into(database.lureModels)
            .insert(
              LureModelsCompanion.insert(
                id: seedModel.id,
                manufacturer: seedModel.manufacturer,
                modelName: seedModel.modelName,
                lureType: seedModel.lureType,
                searchText: 'x',
                seedVersion: const Value(0),
                createdAt: 500,
                updatedAt: 500,
              ),
            );
        await database
            .into(database.lureVariants)
            .insert(
              LureVariantsCompanion.insert(
                id: seedVariant.id,
                lureModelId: seedVariant.lureModelId,
                colorName: Value(seedVariant.colorName),
                searchText: 'x',
                seedVersion: const Value(0),
                retiredAt: const Value(999),
                createdAt: 500,
                updatedAt: 500,
              ),
            );

        await seed();

        final row = await (database.select(
          database.lureVariants,
        )..where((t) => t.id.equals(seedVariant.id))).getSingle();

        expect(row.retiredAt, isNull);
      },
    );

    test(
      'retiring every variant of a model makes that model invisible to '
      'browse/getDistinctManufacturers/getDistinctLureTypes, while its '
      'variants remain individually resolvable and the model row itself '
      'is never deleted',
      () async {
        await seed();

        const tobyModelId = '7eb042d9-8826-4e12-bcb4-bc0079f03aee';
        final tobyVariantIds = testCatalogVariants
            .where((v) => v.lureModelId == tobyModelId)
            .map((v) => v.id)
            .toList();
        final remainingVariants = testCatalogVariants
            .where((v) => v.lureModelId != tobyModelId)
            .toList();

        loader.catalog = buildTestCatalog(
          variants: remainingVariants,
          catalogVersion: testCatalogVersion + 1,
        );
        await seed();

        final manufacturers = await repository.getDistinctManufacturers();
        final lureTypes = await repository.getDistinctLureTypes();
        expect(manufacturers, isNot(contains('Abu Garcia')));
        expect(lureTypes, isNot(contains('spoon')));

        for (final id in tobyVariantIds) {
          final entry = await repository.getEntryById(id);
          expect(entry, isNotNull, reason: 'retired variant $id must remain resolvable');
        }
        final browseResults = await repository.browse();
        expect(
          browseResults.any((e) => tobyVariantIds.contains(e.id)),
          isFalse,
        );

        // The model row itself is never deleted -- only its variants are
        // retired (TD-028 Section 8, scenario 6).
        final modelRow = await (database.select(
          database.lureModels,
        )..where((t) => t.id.equals(tobyModelId))).getSingleOrNull();
        expect(modelRow, isNotNull);
      },
    );

    test(
      'a failed import leaves the database in its pre-import state (no partial writes)',
      () async {
        await seed();
        final before = await database.select(database.lureModels).get();
        final beforeVariants = await database.select(database.lureVariants).get();

        // A variant referencing a non-existent model violates the
        // lureModelId foreign key at write time, forcing the whole batch
        // (and therefore the whole outer transaction) to fail.
        final orphanVariant = LureVariant(
          id: 'orphan-variant',
          lureModelId: 'this-model-does-not-exist',
          colorName: 'Orphan',
          createdAt: _testAuthoredAt,
          updatedAt: _testAuthoredAt,
        );
        final brokenLoader = FakeLureCatalogAssetLoader(
          buildTestCatalog(
            variants: [...testCatalogVariants, orphanVariant],
            catalogVersion: testCatalogVersion + 1,
          ),
        );

        await expectLater(
          () => repository.ensureSeeded(
            assetLoader: brokenLoader,
            versionStore: InMemoryLureCatalogVersionStore(),
          ),
          throwsA(anything),
        );

        final after = await database.select(database.lureModels).get();
        final afterVariants = await database.select(database.lureVariants).get();
        expect(after.length, before.length);
        expect(afterVariants.length, beforeVariants.length);
        expect(afterVariants.any((v) => v.id == 'orphan-variant'), isFalse);
        // None of the *unrelated* rows that would otherwise have been
        // corrected by the version bump were touched either.
        for (var i = 0; i < beforeVariants.length; i++) {
          expect(afterVariants[i].updatedAt, beforeVariants[i].updatedAt);
        }
      },
    );

    test(
      'a large synthetic catalog (1,000 models / 10,000 variants) imports '
      'successfully within a generous time budget',
      () async {
        final largeModels = <LureModel>[];
        final largeVariants = <LureVariant>[];
        for (var m = 0; m < 1000; m++) {
          final modelId = 'perf-model-$m';
          largeModels.add(
            LureModel(
              id: modelId,
              manufacturer: 'Manufacturer ${m % 50}',
              modelName: 'Model $m',
              lureType: 'jig',
              createdAt: _testAuthoredAt,
              updatedAt: _testAuthoredAt,
            ),
          );
          for (var v = 0; v < 10; v++) {
            largeVariants.add(
              LureVariant(
                id: 'perf-variant-$m-$v',
                lureModelId: modelId,
                colorName: 'Color $v',
                createdAt: _testAuthoredAt,
                updatedAt: _testAuthoredAt,
              ),
            );
          }
        }
        expect(largeModels, hasLength(1000));
        expect(largeVariants, hasLength(10000));

        final largeLoader = FakeLureCatalogAssetLoader(
          ParsedLureCatalog(
            catalogVersion: 1,
            models: largeModels,
            variants: largeVariants,
          ),
        );

        final stopwatch = Stopwatch()..start();
        await repository.ensureSeeded(
          assetLoader: largeLoader,
          versionStore: InMemoryLureCatalogVersionStore(),
        );
        stopwatch.stop();

        final modelCount = await database.lureModels.count().getSingle();
        final variantCount = await database.lureVariants.count().getSingle();
        expect(modelCount, 1000);
        expect(variantCount, 10000);

        // Measured on development hardware: a first import of this exact
        // fixture (1,000 models / 10,000 variants) takes ~0.3-0.4s with the
        // batched-read/batched-write design (TD-028 Section 7/Section 10).
        // 5s leaves generous headroom for slower/loaded CI hardware while
        // still catching the specific regression this design replaced: a
        // reintroduced per-row SELECT/INSERT pattern would issue on the
        // order of 20,000 individual statements instead of a handful of
        // batched ones, which is slow enough (seconds, not milliseconds) to
        // blow well past this bound even generously interpreted.
        expect(
          stopwatch.elapsed,
          lessThan(const Duration(seconds: 5)),
          reason: 'first import of a 10,000-variant catalog took '
              '${stopwatch.elapsed} -- investigate a possible '
              'per-row-query regression',
        );

        // A second pass over the *same* content must be idempotent: no row
        // is touched, proven by comparing every row's updatedAt (not just a
        // row count, which would miss a spurious re-write of existing
        // content) before and after.
        final updatedAtBefore = await _variantUpdatedAtById(database);

        final secondStopwatch = Stopwatch()..start();
        await repository.ensureSeeded(
          assetLoader: largeLoader,
          versionStore: InMemoryLureCatalogVersionStore(),
        );
        secondStopwatch.stop();

        final variantCountAfter = await database.lureVariants.count().getSingle();
        expect(variantCountAfter, 10000);
        final updatedAtAfter = await _variantUpdatedAtById(database);
        expect(updatedAtAfter, equals(updatedAtBefore));

        // A second, idempotent pass (a full reconciliation with nothing to
        // write) is expected to be at least as fast as the first; 2s keeps
        // proportionate headroom over the ~0.1s observed on development
        // hardware.
        expect(
          secondStopwatch.elapsed,
          lessThan(const Duration(seconds: 2)),
          reason: 'second (idempotent) pass over a 10,000-variant catalog '
              'took ${secondStopwatch.elapsed} -- investigate a possible '
              'regression that causes unnecessary writes',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('historical reference stability across a catalog update', () {
    test(
      'a TackleBoxEntry referencing a variant remains resolvable, and '
      'reflects a correction, after the catalog is updated',
      () async {
        await seed();
        final targetVariantId = testCatalogVariants.first.id; // Hot Craw

        await database
            .into(database.tackleBoxEntries)
            .insert(
              TackleBoxEntriesCompanion.insert(
                id: 'tackle-box-entry-1',
                lureVariantId: targetVariantId,
                addedAt: 1000,
                createdAt: 1000,
                updatedAt: 1000,
              ),
            );

        // Correct the referenced variant's color in a new catalog version.
        final correctedVariants = [
          for (final variant in testCatalogVariants)
            if (variant.id == targetVariantId)
              LureVariant(
                id: variant.id,
                lureModelId: variant.lureModelId,
                colorName: 'Hot Craw (Corrected)',
                manufacturerColorCode: variant.manufacturerColorCode,
                lengthMillimeters: variant.lengthMillimeters,
                weightGrams: variant.weightGrams,
                minRunningDepthMillimeters: variant.minRunningDepthMillimeters,
                maxRunningDepthMillimeters: variant.maxRunningDepthMillimeters,
                buoyancy: variant.buoyancy,
                createdAt: variant.createdAt,
                updatedAt: variant.updatedAt,
              )
            else
              variant,
        ];
        loader.catalog = buildTestCatalog(
          variants: correctedVariants,
          catalogVersion: testCatalogVersion + 1,
        );
        await seed();

        final entry = await (database.select(
          database.tackleBoxEntries,
        )..where((t) => t.id.equals('tackle-box-entry-1'))).getSingle();
        expect(entry.lureVariantId, targetVariantId);

        final resolved = await repository.getEntryById(entry.lureVariantId);
        expect(resolved, isNotNull);
        expect(resolved!.variant.colorName, 'Hot Craw (Corrected)');
      },
    );

    test(
      'a Catch referencing a variant remains resolvable after the catalog '
      'is updated, including after that variant is retired',
      () async {
        await seed();
        final targetVariantId = testCatalogVariants.first.id; // Hot Craw

        await database
            .into(database.waterBodies)
            .insert(
              WaterBodiesCompanion.insert(
                id: 'water-body-1',
                name: 'Test Lake',
                createdAt: 1000,
              ),
            );
        await database
            .into(database.fishingSpots)
            .insert(
              FishingSpotsCompanion.insert(
                id: 'fishing-spot-1',
                name: 'Test Spot',
                latitude: 61.0,
                longitude: 25.0,
                waterBodyId: const Value('water-body-1'),
                createdAt: 1000,
              ),
            );
        await database
            .into(database.catches)
            .insert(
              CatchesCompanion.insert(
                id: 'catch-1',
                fishingSpotId: 'fishing-spot-1',
                species: 'pike',
                caughtAt: 1000,
                lureVariantId: Value(targetVariantId),
                createdAt: 1000,
                updatedAt: 1000,
              ),
            );

        // Remove the referenced variant from the catalog entirely (retire).
        final remainingVariants = testCatalogVariants
            .where((v) => v.id != targetVariantId)
            .toList();
        loader.catalog = buildTestCatalog(
          variants: remainingVariants,
          catalogVersion: testCatalogVersion + 1,
        );
        await seed();

        final catchRow = await (database.select(
          database.catches,
        )..where((t) => t.id.equals('catch-1'))).getSingle();
        expect(catchRow.lureVariantId, targetVariantId);

        final resolved = await repository.getEntryById(catchRow.lureVariantId!);
        expect(resolved, isNotNull);
        expect(resolved!.id, targetVariantId);
      },
    );
  });

  group('browse', () {
    setUp(() async {
      await seed();
    });

    test('with no arguments returns all non-retired entries', () async {
      final entries = await repository.browse();
      expect(entries, hasLength(testCatalogVariants.length));
    });

    test('excludes retired variants', () async {
      await (database.update(
        database.lureVariants,
      )..where((t) => t.id.equals(testCatalogVariants.first.id))).write(
        LureVariantsCompanion(
          retiredAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

      final entries = await repository.browse();
      expect(entries, hasLength(testCatalogVariants.length - 1));
      expect(
        entries.any((e) => e.id == testCatalogVariants.first.id),
        isFalse,
      );
    });

    test('matches manufacturer text', () async {
      final entries = await repository.browse(searchText: 'Rapala');
      expect(entries, isNotEmpty);
      expect(entries.every((e) => e.manufacturer == 'Rapala'), isTrue);
    });

    test('matches model name text', () async {
      final entries = await repository.browse(searchText: 'Toby');
      expect(entries, isNotEmpty);
      expect(entries.every((e) => e.modelName == 'Toby'), isTrue);
    });

    test('matches color name text', () async {
      final entries = await repository.browse(searchText: 'Hot Craw');
      expect(entries, hasLength(1));
      expect(entries.single.variant.colorName, 'Hot Craw');
    });

    test('matches variantName text', () async {
      final entries = await repository.browse(searchText: 'Glow');
      expect(entries.any((e) => e.variant.variantName == 'Glow'), isTrue);
    });

    test('matches manufacturerColorCode text', () async {
      final entries = await repository.browse(searchText: 'HCC');
      expect(entries, hasLength(1));
      expect(entries.single.variant.manufacturerColorCode, 'HCC');
    });

    test('search is case-insensitive for ASCII text', () async {
      final entries = await repository.browse(searchText: 'RAPALA');
      expect(entries, isNotEmpty);
    });

    test('search matches a Finnish ä/ö term regardless of case', () async {
      // Insert a one-off model/variant with Finnish text not present in the
      // standard fixture, to test the search mechanism directly.
      await database
          .into(database.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: 'fi-model',
              manufacturer: 'Äijänpää',
              modelName: 'Örvelö',
              lureType: 'spoon',
              searchText: 'äijänpää örvelö',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await database
          .into(database.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'fi-variant',
              lureModelId: 'fi-model',
              colorName: const Value('Sinivihreä'),
              searchText: 'sinivihreä',
              createdAt: 1,
              updatedAt: 1,
            ),
          );

      final lower = await repository.browse(searchText: 'sinivihreä');
      final upper = await repository.browse(searchText: 'SINIVIHREÄ');
      final mixedManufacturer = await repository.browse(searchText: 'ÄIJÄNPÄÄ');

      expect(lower.map((e) => e.id), contains('fi-variant'));
      expect(upper.map((e) => e.id), contains('fi-variant'));
      expect(mixedManufacturer.map((e) => e.id), contains('fi-variant'));
    });

    test('an empty/whitespace search term returns the full catalog', () async {
      final entries = await repository.browse(searchText: '   ');
      expect(entries, hasLength(testCatalogVariants.length));
    });

    test('treats a literal "%" in the search term as literal text', () async {
      // A decoy row that contains "50" but not the literal substring "50%".
      // If "%" were left unescaped, searching "50%" would behave like the
      // wildcard pattern "%50%%" (any text containing "50"), incorrectly
      // matching this decoy too.
      await database
          .into(database.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: 'percent-decoy-model',
              manufacturer: 'PercentCo',
              modelName: 'Fifty 50X Sale',
              lureType: 'spoon',
              searchText: 'percentco fifty 50x sale',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await database
          .into(database.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'percent-decoy-variant',
              lureModelId: 'percent-decoy-model',
              colorName: const Value('Decoy'),
              searchText: 'decoy',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      // The genuine match, containing the literal substring "50%".
      await database
          .into(database.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: 'percent-match-model',
              manufacturer: 'PercentCo',
              modelName: 'Fifty 50% Sale',
              lureType: 'spoon',
              searchText: 'percentco fifty 50% sale',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await database
          .into(database.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'percent-match-variant',
              lureModelId: 'percent-match-model',
              colorName: const Value('Match'),
              searchText: 'match',
              createdAt: 1,
              updatedAt: 1,
            ),
          );

      final entries = await repository.browse(searchText: '50%');

      expect(entries.map((e) => e.id), contains('percent-match-variant'));
      expect(
        entries.map((e) => e.id),
        isNot(contains('percent-decoy-variant')),
      );
    });

    test('treats a literal "_" in the search term as literal text', () async {
      // A decoy row where a single arbitrary character stands in for the
      // underscore position. If "_" were left unescaped, it would act as
      // the SQL LIKE "any single character" wildcard and incorrectly match
      // this decoy too.
      await database
          .into(database.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: 'underscore-decoy-model',
              manufacturer: 'UnderscoreCo',
              modelName: 'WideXBody Bait',
              lureType: 'crankbait',
              searchText: 'underscoreco widexbody bait',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await database
          .into(database.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'underscore-decoy-variant',
              lureModelId: 'underscore-decoy-model',
              colorName: const Value('Decoy'),
              searchText: 'decoy',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      // The genuine match, containing the literal substring "wide_body".
      await database
          .into(database.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: 'underscore-match-model',
              manufacturer: 'UnderscoreCo',
              modelName: 'Wide_Body Bait',
              lureType: 'crankbait',
              searchText: 'underscoreco wide_body bait',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await database
          .into(database.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'underscore-match-variant',
              lureModelId: 'underscore-match-model',
              colorName: const Value('Match'),
              searchText: 'match',
              createdAt: 1,
              updatedAt: 1,
            ),
          );

      final entries = await repository.browse(searchText: 'wide_body');

      expect(entries.map((e) => e.id), contains('underscore-match-variant'));
      expect(
        entries.map((e) => e.id),
        isNot(contains('underscore-decoy-variant')),
      );
    });

    test('filters by manufacturer', () async {
      final entries = await repository.browse(manufacturer: 'Abu Garcia');
      expect(entries, isNotEmpty);
      expect(entries.every((e) => e.manufacturer == 'Abu Garcia'), isTrue);
    });

    test('filters by lureType', () async {
      final entries = await repository.browse(lureType: 'jig');
      expect(entries, isNotEmpty);
      expect(entries.every((e) => e.lureType == 'jig'), isTrue);
    });

    test('combines search and both filters', () async {
      final entries = await repository.browse(
        searchText: 'Perch',
        manufacturer: 'Rapala',
        lureType: 'crankbait',
      );
      expect(entries, hasLength(1));
      expect(entries.single.variant.colorName, 'Perch');
    });

    test(
      'returns matching rows for an unrecognized lureType present in the data',
      () async {
        await database
            .into(database.lureModels)
            .insert(
              LureModelsCompanion.insert(
                id: 'future-model',
                manufacturer: 'FutureCo',
                modelName: 'Unknown Type Lure',
                lureType: 'some_future_type',
                searchText: 'futureco unknown type lure',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await database
            .into(database.lureVariants)
            .insert(
              LureVariantsCompanion.insert(
                id: 'future-variant',
                lureModelId: 'future-model',
                colorName: const Value('Mystery'),
                searchText: 'mystery',
                createdAt: 1,
                updatedAt: 1,
              ),
            );

        final entries = await repository.browse(lureType: 'some_future_type');
        expect(entries, hasLength(1));
        expect(entries.single.lureType, 'some_future_type');
      },
    );

    test('applies a stable, deterministic sort order', () async {
      final first = await repository.browse();
      final second = await repository.browse();
      expect(first.map((e) => e.id).toList(), second.map((e) => e.id).toList());
    });
  });

  group('getEntryById', () {
    setUp(() async {
      await seed();
    });

    test('returns the correct entry', () async {
      final expected = testCatalogVariants.first;
      final entry = await repository.getEntryById(expected.id);
      expect(entry, isNotNull);
      expect(entry!.id, expected.id);
    });

    test('returns null for an unknown id', () async {
      final entry = await repository.getEntryById('does-not-exist');
      expect(entry, isNull);
    });

    test('still returns a retired variant', () async {
      final target = testCatalogVariants.first;
      await (database.update(
        database.lureVariants,
      )..where((t) => t.id.equals(target.id))).write(
        LureVariantsCompanion(
          retiredAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

      final entry = await repository.getEntryById(target.id);
      expect(entry, isNotNull);
      expect(entry!.id, target.id);
    });
  });

  group('getDistinctManufacturers / getDistinctLureTypes', () {
    setUp(() async {
      await seed();
    });

    test(
      'getDistinctManufacturers returns sorted, deduplicated values',
      () async {
        final manufacturers = await repository.getDistinctManufacturers();

        expect(manufacturers.toSet().length, manufacturers.length);
        expect(manufacturers, contains('Rapala'));
        expect(manufacturers, contains('Abu Garcia'));
        expect(manufacturers, contains('Storm'));
        final sorted = [...manufacturers]
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        expect(manufacturers, sorted);
      },
    );

    test('getDistinctLureTypes returns sorted, deduplicated values', () async {
      final lureTypes = await repository.getDistinctLureTypes();

      expect(lureTypes.toSet().length, lureTypes.length);
      expect(lureTypes, containsAll(['crankbait', 'spoon', 'swimbait', 'jig']));
    });

    test(
      'excludes a manufacturer whose every variant has been retired',
      () async {
        // Abu Garcia's Toby is the only "spoon" model in the fixture, and
        // all of its variants are retired here -- both the manufacturer
        // and the lure type should disappear from their respective filters.
        final now = DateTime.now().millisecondsSinceEpoch;
        final tobyVariantIds = testCatalogVariants
            .where(
              (v) => v.lureModelId == '7eb042d9-8826-4e12-bcb4-bc0079f03aee',
            )
            .map((v) => v.id);
        for (final id in tobyVariantIds) {
          await (database.update(database.lureVariants)
                ..where((t) => t.id.equals(id)))
              .write(LureVariantsCompanion(retiredAt: Value(now)));
        }

        final manufacturers = await repository.getDistinctManufacturers();
        final lureTypes = await repository.getDistinctLureTypes();

        expect(manufacturers, isNot(contains('Abu Garcia')));
        expect(lureTypes, isNot(contains('spoon')));
        // Manufacturers/types with at least one active variant remain.
        expect(manufacturers, contains('Rapala'));
        expect(lureTypes, contains('crankbait'));
      },
    );

    test(
      'reincludes a manufacturer once at least one of its variants is active '
      'again',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final tobyVariantIds = testCatalogVariants
            .where(
              (v) => v.lureModelId == '7eb042d9-8826-4e12-bcb4-bc0079f03aee',
            )
            .map((v) => v.id)
            .toList();
        for (final id in tobyVariantIds) {
          await (database.update(database.lureVariants)
                ..where((t) => t.id.equals(id)))
              .write(LureVariantsCompanion(retiredAt: Value(now)));
        }
        await (database.update(database.lureVariants)
              ..where((t) => t.id.equals(tobyVariantIds.first)))
            .write(const LureVariantsCompanion(retiredAt: Value(null)));

        final manufacturers = await repository.getDistinctManufacturers();
        final lureTypes = await repository.getDistinctLureTypes();

        expect(manufacturers, contains('Abu Garcia'));
        expect(lureTypes, contains('spoon'));
      },
    );
  });
}
