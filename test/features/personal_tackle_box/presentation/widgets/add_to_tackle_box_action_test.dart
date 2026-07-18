import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/personal_tackle_box/presentation/widgets/add_to_tackle_box_action.dart';

import '../../../../support/fake_image_picker_platform.dart';
import '../../../../support/test_image_files.dart';

/// Pumps and lets a multi-step real dart:io chain (image processing, file
/// writing) advance to completion. A single tester.pump() only drains
/// microtasks already queued at that instant; real asynchronous file I/O
/// resolves on the actual event loop, so this interleaves short real-time
/// windows (via tester.runAsync) with pumps until the widget settles.
/// Mirrors the identical helper in edit_catch_bottom_sheet_test.dart /
/// catch_photo_viewer_test.dart.
Future<void> _pumpUntilSettledWithRealIO(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Fails every [store] call, used to exercise the photoFailed/retry path.
class _FailingStoreStorage extends TackleBoxPhotoStorage {
  _FailingStoreStorage({required super.rootDirectoryProvider});

  @override
  Future<String> store({
    required String tackleBoxEntryId,
    required String sourcePath,
  }) {
    throw const TackleBoxPhotoStorageException('Simulated store failure.');
  }
}

Future<void> pumpAction(
  WidgetTester tester,
  LureCatalogEntry entry,
  PersonalTackleBoxRepository repository,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [
            AddToTackleBoxAction(catalogEntry: entry, repository: repository),
          ],
        ),
        body: const SizedBox(),
      ),
    ),
  );
}

void main() {
  late AppDatabase database;
  late Directory tempDir;
  late PersonalTackleBoxRepository repository;
  late LureCatalogEntry catalogEntry;
  late FakeImagePickerPlatform fakePicker;
  late ImagePickerPlatform originalPicker;

  Future<LureCatalogEntry> seedCatalogVariant() async {
    await database
        .into(database.lureModels)
        .insert(
          LureModelsCompanion.insert(
            id: 'model-1',
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
            id: 'variant-1',
            lureModelId: 'model-1',
            colorName: const Value('Hot Craw'),
            searchText: 'hot craw',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    return LureCatalogEntry(
      variant: LureVariant(
        id: 'variant-1',
        lureModelId: 'model-1',
        colorName: 'Hot Craw',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      ),
      manufacturer: 'Rapala',
      modelName: 'X-Rap Shad XRS08',
      lureType: 'crankbait',
      modelDefaultImageReference: null,
    );
  }

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync('add_to_tackle_box_test');
    repository = PersonalTackleBoxRepository(
      database,
      TackleBoxPhotoStorage(rootDirectoryProvider: () async => tempDir),
    );
    catalogEntry = await seedCatalogVariant();

    originalPicker = ImagePickerPlatform.instance;
    fakePicker = FakeImagePickerPlatform();
    ImagePickerPlatform.instance = fakePicker;
  });

  tearDown(() async {
    ImagePickerPlatform.instance = originalPicker;
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('shows the add button once loaded when not owned', (
    tester,
  ) async {
    await pumpAction(tester, catalogEntry, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('addToTackleBoxButton')), findsOneWidget);
    expect(find.byKey(const Key('tackleBoxAlreadyOwnedLabel')), findsNothing);
  });

  testWidgets('shows the already-owned label when already owned', (
    tester,
  ) async {
    await repository.add(catalogEntry: catalogEntry);

    await pumpAction(tester, catalogEntry, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tackleBoxAlreadyOwnedLabel')), findsOneWidget);
    expect(find.byKey(const Key('addToTackleBoxButton')), findsNothing);
  });

  testWidgets('choosing "Ei kuvaa" adds the lure without a photo', (
    tester,
  ) async {
    await pumpAction(tester, catalogEntry, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addToTackleBoxButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tackleBoxPhotoSourceSkip')));
    await tester.pumpAndSettle();

    expect(await repository.isOwned(catalogEntry.id), isTrue);
    expect(find.byKey(const Key('tackleBoxAlreadyOwnedLabel')), findsOneWidget);
    expect(find.text('Lisätty vieherasiaan.'), findsOneWidget);
  });

  testWidgets('choosing camera adds the lure with a photo', (tester) async {
    fakePicker.nextCameraImage = writeTestXFile(tempDir, 'camera.jpg');

    await pumpAction(tester, catalogEntry, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addToTackleBoxButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tackleBoxPhotoSourceCamera')));
    await _pumpUntilSettledWithRealIO(tester);

    final item = await repository.getById(
      (await repository.getAll()).single.id,
    );
    expect(item!.personalPhotoRelativePath, isNotNull);
  });

  testWidgets('cancelling the native picker creates no entry', (tester) async {
    fakePicker.nextCameraImage = null;

    await pumpAction(tester, catalogEntry, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addToTackleBoxButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tackleBoxPhotoSourceCamera')));
    await tester.pumpAndSettle();

    expect(await repository.isOwned(catalogEntry.id), isFalse);
    expect(find.byKey(const Key('addToTackleBoxButton')), findsOneWidget);
  });

  testWidgets(
    'a photo storage failure still adds the lure and offers a retry',
    (tester) async {
      final failingRepository = PersonalTackleBoxRepository(
        database,
        _FailingStoreStorage(rootDirectoryProvider: () async => tempDir),
      );
      fakePicker.nextCameraImage = writeTestXFile(tempDir, 'camera.jpg');

      await pumpAction(tester, catalogEntry, failingRepository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('addToTackleBoxButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tackleBoxPhotoSourceCamera')));
      await tester.pumpAndSettle();

      expect(await failingRepository.isOwned(catalogEntry.id), isTrue);
      expect(
        find.text('Lisätty vieherasiaan, mutta kuvan lisääminen epäonnistui.'),
        findsOneWidget,
      );
      expect(find.text('Yritä uudelleen'), findsOneWidget);
    },
  );
}
