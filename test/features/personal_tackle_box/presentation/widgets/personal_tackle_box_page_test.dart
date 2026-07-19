import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/tackle_box_item.dart';
import 'package:fishing_app/features/personal_tackle_box/presentation/widgets/owned_entry_detail_page.dart';
import 'package:fishing_app/features/personal_tackle_box/presentation/widgets/personal_tackle_box_page.dart';

/// Never completes `getAll`, so the loading state can be observed
/// deterministically. Mirrors `_PendingLureCatalogRepository` in
/// lure_catalog_list_page_test.dart.
class _PendingRepository extends PersonalTackleBoxRepository {
  _PendingRepository(super.database, super.storage);

  final Completer<List<TackleBoxItem>> pendingGetAll =
      Completer<List<TackleBoxItem>>();

  @override
  Future<List<TackleBoxItem>> getAll() => pendingGetAll.future;
}

class _FailingRepository extends PersonalTackleBoxRepository {
  _FailingRepository(super.database, super.storage);

  @override
  Future<List<TackleBoxItem>> getAll() async {
    throw StateError('simulated load failure');
  }
}

Future<void> pumpPage(
  WidgetTester tester,
  PersonalTackleBoxRepository repository,
  TackleBoxPhotoStorage storage,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: PersonalTackleBoxPage(
        repository: repository,
        photoStorage: storage,
      ),
    ),
  );
}

void main() {
  late AppDatabase database;
  late Directory tempDir;
  late TackleBoxPhotoStorage storage;
  late PersonalTackleBoxRepository repository;

  Future<LureCatalogEntry> seedCatalogVariant({
    required String modelId,
    required String variantId,
    required String manufacturer,
    required String modelName,
    required String colorName,
    String lureType = 'crankbait',
  }) async {
    await database
        .into(database.lureModels)
        .insert(
          LureModelsCompanion.insert(
            id: modelId,
            manufacturer: manufacturer,
            modelName: modelName,
            lureType: lureType,
            searchText: '$manufacturer $modelName'.toLowerCase(),
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    await database
        .into(database.lureVariants)
        .insert(
          LureVariantsCompanion.insert(
            id: variantId,
            lureModelId: modelId,
            colorName: Value(colorName),
            searchText: colorName.toLowerCase(),
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    return LureCatalogEntry(
      variant: LureVariant(
        id: variantId,
        lureModelId: modelId,
        colorName: colorName,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      ),
      manufacturer: manufacturer,
      modelName: modelName,
      lureType: lureType,
      modelDefaultImageReference: null,
    );
  }

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync('personal_tackle_box_page');
    storage = TackleBoxPhotoStorage(rootDirectoryProvider: () async => tempDir);
    repository = PersonalTackleBoxRepository(database, storage);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('shows a loading indicator while getAll is in flight', (
    tester,
  ) async {
    final pending = _PendingRepository(database, storage);

    await pumpPage(tester, pending, storage);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an empty-state message when nothing is owned', (
    tester,
  ) async {
    await pumpPage(tester, repository, storage);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Et ole vielä lisännyt viehteitä'),
      findsOneWidget,
    );
  });

  testWidgets('shows an error message when getAll fails', (tester) async {
    final failing = _FailingRepository(database, storage);

    await pumpPage(tester, failing, storage);
    await tester.pumpAndSettle();

    expect(find.text('Vieherasian lataaminen epäonnistui.'), findsOneWidget);
  });

  testWidgets('groups owned entries by manufacturer and model', (tester) async {
    final rapala = await seedCatalogVariant(
      modelId: 'model-rapala',
      variantId: 'variant-rapala',
      manufacturer: 'Rapala',
      modelName: 'X-Rap 10',
      colorName: 'Firetiger',
    );
    final westin = await seedCatalogVariant(
      modelId: 'model-westin',
      variantId: 'variant-westin',
      manufacturer: 'Westin',
      modelName: 'Swim',
      colorName: 'Official Roach',
    );
    await repository.add(catalogEntry: rapala);
    await repository.add(catalogEntry: westin);

    await pumpPage(tester, repository, storage);
    await tester.pumpAndSettle();

    expect(find.text('Rapala'), findsOneWidget);
    expect(find.text('X-Rap 10'), findsOneWidget);
    expect(find.text('Firetiger'), findsOneWidget);
    expect(find.text('Westin'), findsOneWidget);
    expect(find.text('Swim'), findsOneWidget);
    expect(find.text('Official Roach'), findsOneWidget);
  });

  testWidgets('tapping an owned entry opens OwnedEntryDetailPage', (
    tester,
  ) async {
    final rapala = await seedCatalogVariant(
      modelId: 'model-rapala',
      variantId: 'variant-rapala',
      manufacturer: 'Rapala',
      modelName: 'X-Rap 10',
      colorName: 'Firetiger',
    );
    await repository.add(catalogEntry: rapala);

    await pumpPage(tester, repository, storage);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Firetiger'));
    await tester.pumpAndSettle();

    expect(find.byType(OwnedEntryDetailPage), findsOneWidget);
  });

  testWidgets('does not show search/filter controls when nothing is owned', (
    tester,
  ) async {
    await pumpPage(tester, repository, storage);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('personalTackleBoxSearchField')), findsNothing);
  });

  group('search and filters', () {
    Future<void> seedTwoManufacturers(WidgetTester tester) async {
      final rapala = await seedCatalogVariant(
        modelId: 'model-rapala',
        variantId: 'variant-rapala',
        manufacturer: 'Rapala',
        modelName: 'X-Rap 10',
        colorName: 'Firetiger',
        lureType: 'crankbait',
      );
      final westin = await seedCatalogVariant(
        modelId: 'model-westin',
        variantId: 'variant-westin',
        manufacturer: 'Westin',
        modelName: 'Swim',
        colorName: 'Official Roach',
        lureType: 'swimbait',
      );
      await repository.add(catalogEntry: rapala);
      await repository.add(catalogEntry: westin);

      await pumpPage(tester, repository, storage);
      await tester.pumpAndSettle();
    }

    testWidgets('typing a search term narrows the list', (tester) async {
      await seedTwoManufacturers(tester);

      await tester.enterText(
        find.byKey(const Key('personalTackleBoxSearchField')),
        'Firetiger',
      );
      await tester.pumpAndSettle();

      // findsWidgets, not findsOneWidget: the search field's own current
      // text also matches "Firetiger", in addition to the list row.
      expect(find.text('Firetiger'), findsWidgets);
      expect(find.text('Official Roach'), findsNothing);
    });

    testWidgets('search matches manufacturer text too', (tester) async {
      await seedTwoManufacturers(tester);

      await tester.enterText(
        find.byKey(const Key('personalTackleBoxSearchField')),
        'westin',
      );
      await tester.pumpAndSettle();

      expect(find.text('Official Roach'), findsOneWidget);
      expect(find.text('Firetiger'), findsNothing);
    });

    testWidgets('selecting a manufacturer filter narrows the list', (
      tester,
    ) async {
      await seedTwoManufacturers(tester);

      await tester.tap(
        find.byKey(const Key('personalTackleBoxManufacturerFilter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Westin').last);
      await tester.pumpAndSettle();

      expect(find.text('Official Roach'), findsOneWidget);
      expect(find.text('Firetiger'), findsNothing);
    });

    testWidgets('selecting a lure type filter narrows the list', (
      tester,
    ) async {
      await seedTwoManufacturers(tester);

      await tester.tap(
        find.byKey(const Key('personalTackleBoxLureTypeFilter')),
      );
      await tester.pumpAndSettle();
      // 'swimbait' -> 'Uimavetouistin' (lure_type_labels.dart).
      await tester.tap(find.text('Uimavetouistin').last);
      await tester.pumpAndSettle();

      expect(find.text('Official Roach'), findsOneWidget);
      expect(find.text('Firetiger'), findsNothing);
    });

    testWidgets('clearing the lure type filter restores the wider list', (
      tester,
    ) async {
      await seedTwoManufacturers(tester);

      await tester.tap(
        find.byKey(const Key('personalTackleBoxLureTypeFilter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uimavetouistin').last);
      await tester.pumpAndSettle();
      expect(find.text('Firetiger'), findsNothing);

      await tester.tap(
        find.byKey(const Key('personalTackleBoxLureTypeFilter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaikki tyypit').last);
      await tester.pumpAndSettle();

      expect(find.text('Firetiger'), findsOneWidget);
    });

    testWidgets('clearing the manufacturer filter restores the wider list', (
      tester,
    ) async {
      await seedTwoManufacturers(tester);

      await tester.tap(
        find.byKey(const Key('personalTackleBoxManufacturerFilter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Westin').last);
      await tester.pumpAndSettle();
      expect(find.text('Firetiger'), findsNothing);

      await tester.tap(
        find.byKey(const Key('personalTackleBoxManufacturerFilter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaikki valmistajat').last);
      await tester.pumpAndSettle();

      expect(find.text('Firetiger'), findsOneWidget);
    });

    testWidgets('shows a distinct message when a filter matches nothing', (
      tester,
    ) async {
      await seedTwoManufacturers(tester);

      await tester.enterText(
        find.byKey(const Key('personalTackleBoxSearchField')),
        'no such lure exists anywhere',
      );
      await tester.pumpAndSettle();

      expect(find.text('Ei tuloksia hakuehdoilla.'), findsOneWidget);
      expect(
        find.textContaining('Et ole vielä lisännyt viehteitä'),
        findsNothing,
      );
    });
  });

  group('onSelect (MFS-017/TD-017 picker mode)', () {
    testWidgets('invokes onSelect instead of opening OwnedEntryDetailPage', (
      tester,
    ) async {
      final rapala = await seedCatalogVariant(
        modelId: 'model-rapala',
        variantId: 'variant-rapala',
        manufacturer: 'Rapala',
        modelName: 'X-Rap 10',
        colorName: 'Firetiger',
      );
      await repository.add(catalogEntry: rapala);

      TackleBoxItem? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalTackleBoxPage(
            repository: repository,
            photoStorage: storage,
            onSelect: (item) => selected = item,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Firetiger'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.catalogEntry.id, 'variant-rapala');
      expect(find.byType(OwnedEntryDetailPage), findsNothing);
    });

    testWidgets(
      'omitting onSelect preserves the existing browse-to-detail behavior',
      (tester) async {
        final rapala = await seedCatalogVariant(
          modelId: 'model-rapala',
          variantId: 'variant-rapala',
          manufacturer: 'Rapala',
          modelName: 'X-Rap 10',
          colorName: 'Firetiger',
        );
        await repository.add(catalogEntry: rapala);

        await pumpPage(tester, repository, storage);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Firetiger'));
        await tester.pumpAndSettle();

        expect(find.byType(OwnedEntryDetailPage), findsOneWidget);
      },
    );
  });
}
