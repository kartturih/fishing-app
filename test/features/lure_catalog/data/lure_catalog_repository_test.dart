import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/lure_catalog/data/local/lure_catalog_seed_data.dart';

void main() {
  late AppDatabase database;
  late LureCatalogRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LureCatalogRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('ensureSeeded', () {
    test('inserts all seed models and variants on first call', () async {
      await repository.ensureSeeded();

      final models = await database.select(database.lureModels).get();
      final variants = await database.select(database.lureVariants).get();

      expect(models, hasLength(lureCatalogSeedModels.length));
      expect(variants, hasLength(lureCatalogSeedVariants.length));
      for (final model in models) {
        expect(model.seedVersion, currentLureCatalogSeedVersion);
      }
      for (final variant in variants) {
        expect(variant.seedVersion, currentLureCatalogSeedVersion);
        expect(variant.retiredAt, isNull);
      }
    });

    test('a second call performs no writes (idempotent)', () async {
      await repository.ensureSeeded();
      final before = await database.select(database.lureVariants).get();

      await repository.ensureSeeded();
      final after = await database.select(database.lureVariants).get();

      expect(after.length, before.length);
      for (var i = 0; i < before.length; i++) {
        expect(after[i].updatedAt, before[i].updatedAt);
      }
    });

    test(
      'corrects a row whose stored seedVersion is behind current, preserving createdAt',
      () async {
        final seedVariant = lureCatalogSeedVariants.first;
        // Simulate a row shipped by an earlier seed version, with stale content.
        await database
            .into(database.lureModels)
            .insert(
              LureModelsCompanion.insert(
                id: lureCatalogSeedModels.first.id,
                manufacturer: 'Old Manufacturer Name',
                modelName: lureCatalogSeedModels.first.modelName,
                lureType: lureCatalogSeedModels.first.lureType,
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

        await repository.ensureSeeded();

        final model =
            await (database.select(database.lureModels)
                  ..where((t) => t.id.equals(lureCatalogSeedModels.first.id)))
                .getSingle();
        final variant = await (database.select(
          database.lureVariants,
        )..where((t) => t.id.equals(seedVariant.id))).getSingle();

        expect(model.manufacturer, lureCatalogSeedModels.first.manufacturer);
        expect(model.createdAt, 500); // preserved
        expect(model.updatedAt, isNot(500)); // corrected
        expect(model.seedVersion, currentLureCatalogSeedVersion);

        expect(variant.colorName, seedVariant.colorName);
        expect(variant.createdAt, 500); // preserved
        expect(variant.updatedAt, isNot(500)); // corrected
        expect(variant.seedVersion, currentLureCatalogSeedVersion);
      },
    );

    test('never modifies a row whose stored seedVersion is null', () async {
      final seedModel = lureCatalogSeedModels.first;
      final seedVariant = lureCatalogSeedVariants.first;

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

      await repository.ensureSeeded();

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
      'retires a seed-owned variant removed from the current seed source',
      () async {
        const removedId = 'removed-variant-id';
        await database
            .into(database.lureModels)
            .insert(
              LureModelsCompanion.insert(
                id: lureCatalogSeedModels.first.id,
                manufacturer: lureCatalogSeedModels.first.manufacturer,
                modelName: lureCatalogSeedModels.first.modelName,
                lureType: lureCatalogSeedModels.first.lureType,
                searchText: 'x',
                seedVersion: Value(currentLureCatalogSeedVersion),
                createdAt: 500,
                updatedAt: 500,
              ),
            );
        await database
            .into(database.lureVariants)
            .insert(
              LureVariantsCompanion.insert(
                id: removedId,
                lureModelId: lureCatalogSeedModels.first.id,
                colorName: const Value('No Longer Sold'),
                searchText: 'no longer sold',
                seedVersion: Value(currentLureCatalogSeedVersion),
                createdAt: 500,
                updatedAt: 500,
              ),
            );

        await repository.ensureSeeded();

        final row = await (database.select(
          database.lureVariants,
        )..where((t) => t.id.equals(removedId))).getSingle();

        expect(row.retiredAt, isNotNull);
      },
    );

    test(
      'clears retiredAt for a variant that reappears in the seed source',
      () async {
        final seedModel = lureCatalogSeedModels.first;
        final seedVariant = lureCatalogSeedVariants.first;

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

        await repository.ensureSeeded();

        final row = await (database.select(
          database.lureVariants,
        )..where((t) => t.id.equals(seedVariant.id))).getSingle();

        expect(row.retiredAt, isNull);
      },
    );
  });

  group('browse', () {
    setUp(() async {
      await repository.ensureSeeded();
    });

    test('with no arguments returns all non-retired entries', () async {
      final entries = await repository.browse();
      expect(entries, hasLength(lureCatalogSeedVariants.length));
    });

    test('excludes retired variants', () async {
      await (database.update(
        database.lureVariants,
      )..where((t) => t.id.equals(lureCatalogSeedVariants.first.id))).write(
        LureVariantsCompanion(
          retiredAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

      final entries = await repository.browse();
      expect(entries, hasLength(lureCatalogSeedVariants.length - 1));
      expect(
        entries.any((e) => e.id == lureCatalogSeedVariants.first.id),
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
      // standard seed data, to test the search mechanism directly.
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
      expect(entries, hasLength(lureCatalogSeedVariants.length));
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
      await repository.ensureSeeded();
    });

    test('returns the correct entry', () async {
      final expected = lureCatalogSeedVariants.first;
      final entry = await repository.getEntryById(expected.id);
      expect(entry, isNotNull);
      expect(entry!.id, expected.id);
    });

    test('returns null for an unknown id', () async {
      final entry = await repository.getEntryById('does-not-exist');
      expect(entry, isNull);
    });

    test('still returns a retired variant', () async {
      final target = lureCatalogSeedVariants.first;
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
      await repository.ensureSeeded();
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
        // Abu Garcia's Toby is the only "spoon" model in the seed data, and
        // all of its variants are retired here — both the manufacturer and
        // the lure type should disappear from their respective filters.
        final now = DateTime.now().millisecondsSinceEpoch;
        final tobyVariantIds = lureCatalogSeedVariants
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
        final tobyVariantIds = lureCatalogSeedVariants
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
