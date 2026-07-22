import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/data/storage/catch_photo_storage.dart';
import 'package:fishing_app/features/catch_photos/domain/catch_photo_limits.dart';
import 'package:fishing_app/features/catch_photos/domain/pending_catch_photo.dart';
import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_viewer.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/catch_notes_limits.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/widgets/edit_catch_bottom_sheet.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';

import '../../../../support/fake_image_picker_platform.dart';
import '../../../../support/test_image_files.dart';

class _FailingDeleteCatchPhotoRepository extends CatchPhotoRepository {
  _FailingDeleteCatchPhotoRepository(super.database, super.storage);

  int deleteCallCount = 0;

  @override
  Future<void> delete(String photoId) async {
    deleteCallCount++;
    throw StateError('simulated photo delete failure');
  }
}

/// A storage whose [delete] never touches the real file.
///
/// `Image.file` can leave a native (Skia) read handle open on the backing
/// file well after the widget stops needing it — on Windows specifically,
/// this can make a real, immediately-following file deletion fail with a
/// transient sharing-violation error that has nothing to do with the
/// application's own logic. Real file removal is already covered by the
/// CatchPhotoStorage/CatchPhotoRepository tests; widget tests that only need
/// to verify the UI/repository contract use this to sidestep that platform
/// quirk entirely.
class _NonLockingDeleteCatchPhotoStorage extends CatchPhotoStorage {
  _NonLockingDeleteCatchPhotoStorage({required super.rootDirectoryProvider});

  @override
  Future<void> delete(String relativePath) async {}

  @override
  Future<void> deleteCatchDirectory(String catchId) async {}
}

class _SlowDeleteCatchPhotoRepository extends CatchPhotoRepository {
  _SlowDeleteCatchPhotoRepository(super.database, super.storage);

  int deleteCallCount = 0;
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> delete(String photoId) async {
    deleteCallCount++;
    await gate.future;
    return super.delete(photoId);
  }
}

/// Pumps and lets a multi-step real dart:io chain (image processing, file
/// deletion) advance to completion. A single tester.pump() only drains
/// microtasks already queued at that instant; real asynchronous file I/O
/// resolves on the actual event loop, so this interleaves short real-time
/// windows (via tester.runAsync) with pumps until the widget settles.
Future<void> _pumpUntilSettledWithRealIO(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

class _FailingUpdateCatchRepository extends CatchRepository {
  _FailingUpdateCatchRepository(super.database);

  int updateCallCount = 0;

  @override
  Future<Catch> update({
    required Catch catchModel,
    required FishSpecies species,
    required DateTime caughtAt,
    int? weightGrams,
    int? lengthMillimeters,
    String? lureVariantId,
    String? notes,
  }) async {
    updateCallCount++;
    throw StateError('simulated update failure');
  }
}

/// A `LureCatalogRepository` whose `getEntryById` always returns `null`,
/// simulating an unresolvable reference for [_EditCatchHarness]'s fallback
/// test — see the "unresolvable assignment" test below.
class _NullResolvingLureCatalogRepository extends LureCatalogRepository {
  _NullResolvingLureCatalogRepository(super.database);

  @override
  Future<LureCatalogEntry?> getEntryById(String variantId) async => null;
}

class _FailingDeleteCatchRepository extends CatchRepository {
  _FailingDeleteCatchRepository(super.database);

  int deleteCallCount = 0;

  @override
  Future<void> delete(String catchId) async {
    deleteCallCount++;
    throw StateError('simulated delete failure');
  }
}

class _SlowUpdateCatchRepository extends CatchRepository {
  _SlowUpdateCatchRepository(super.database);

  int updateCallCount = 0;
  final Completer<void> gate = Completer<void>();

  @override
  Future<Catch> update({
    required Catch catchModel,
    required FishSpecies species,
    required DateTime caughtAt,
    int? weightGrams,
    int? lengthMillimeters,
    String? lureVariantId,
    String? notes,
  }) async {
    updateCallCount++;
    await gate.future;
    return super.update(
      catchModel: catchModel,
      species: species,
      caughtAt: caughtAt,
      weightGrams: weightGrams,
      lengthMillimeters: lengthMillimeters,
      lureVariantId: lureVariantId,
      notes: notes,
    );
  }
}

class _SlowDeleteCatchRepository extends CatchRepository {
  _SlowDeleteCatchRepository(super.database);

  int deleteCallCount = 0;
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> delete(String catchId) async {
    deleteCallCount++;
    await gate.future;
    return super.delete(catchId);
  }
}

class _EditCatchHarness {
  EditCatchResult? result;

  Future<void> open(
    WidgetTester tester,
    FishingSpot fishingSpot,
    Catch catchModel,
    CatchRepository catchRepository,
    CatchPhotoRepository catchPhotoRepository,
    LureCatalogRepository lureCatalogRepository,
    PersonalTackleBoxRepository personalTackleBoxRepository,
    TackleBoxPhotoStorage personalTackleBoxPhotoStorage,
  ) async {
    // Taller than the default test viewport: the form (now including the
    // MFS-017 lure-assignment row) no longer fits at the default 800x600 in
    // every test, which left action buttons below the fold and unhittable.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await EditCatchBottomSheet.show(
                  context,
                  fishingSpot,
                  catchModel,
                  catchRepository,
                  catchPhotoRepository,
                  lureCatalogRepository,
                  personalTackleBoxRepository,
                  personalTackleBoxPhotoStorage,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

Future<void> _selectSpecies(WidgetTester tester, FishSpecies species) async {
  await tester.tap(find.byType(DropdownButtonFormField<FishSpecies>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(species.finnishName).last);
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase database;
  late CatchRepository catchRepository;
  late CatchPhotoRepository catchPhotoRepository;
  late Directory tempDir;
  late Directory tackleBoxTempDir;
  late FishingSpotRepository fishingSpotRepository;
  late FishingSpot fishingSpot;
  late Catch existingCatch;
  late LureCatalogRepository lureCatalogRepository;
  late PersonalTackleBoxRepository personalTackleBoxRepository;
  late TackleBoxPhotoStorage personalTackleBoxPhotoStorage;

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
    tempDir = Directory.systemTemp.createTempSync('edit_catch_bottom_sheet');
    catchPhotoRepository = CatchPhotoRepository(
      database,
      CatchPhotoStorage(rootDirectoryProvider: () async => tempDir),
    );
    tackleBoxTempDir = Directory.systemTemp.createTempSync(
      'edit_catch_tackle_box_storage',
    );
    lureCatalogRepository = LureCatalogRepository(database);
    personalTackleBoxPhotoStorage = TackleBoxPhotoStorage(
      rootDirectoryProvider: () async => tackleBoxTempDir,
    );
    personalTackleBoxRepository = PersonalTackleBoxRepository(
      database,
      personalTackleBoxPhotoStorage,
    );
    fishingSpotRepository = FishingSpotRepository(database);
    fishingSpot = await fishingSpotRepository.create(
      name: 'Merrasjärvi',
      latitude: 61.0,
      longitude: 25.0,
      waterBodyId: 'water-body-1',
    );
    existingCatch = await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 14, 18, 34),
      weightGrams: 3200,
      lengthMillimeters: 780,
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    if (tackleBoxTempDir.existsSync()) {
      tackleBoxTempDir.deleteSync(recursive: true);
    }
  });

  group('initial values', () {
    testWidgets('prefills species, weight, and length from the catch', (
      tester,
    ) async {
      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      expect(find.text('Merrasjärvi'), findsOneWidget);
      expect(find.text('Hauki'), findsOneWidget);
      expect(find.text('3.2'), findsOneWidget);
      expect(find.text('78'), findsOneWidget);
    });

    testWidgets('shows empty weight and length when not set', (tester) async {
      final catchWithoutMeasurements = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 10, 21, 10),
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchWithoutMeasurements,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      final weightField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(0),
      );
      final lengthField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(1),
      );

      expect(weightField.controller!.text, isEmpty);
      expect(lengthField.controller!.text, isEmpty);
    });
  });

  testWidgets('allows changing the species and saves it', (tester) async {
    final harness = _EditCatchHarness();
    await harness.open(
      tester,
      fishingSpot,
      existingCatch,
      catchRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
    );

    await _selectSpecies(tester, FishSpecies.zander);
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    expect(harness.result, isA<CatchUpdated>());
    final updated = (harness.result! as CatchUpdated).catchModel;
    expect(updated.species, FishSpecies.zander);

    final stored = await catchRepository.getById(existingCatch.id);
    expect(stored!.species, FishSpecies.zander);
  });

  testWidgets('accepts a comma decimal separator for weight', (tester) async {
    final harness = _EditCatchHarness();
    await harness.open(
      tester,
      fishingSpot,
      existingCatch,
      catchRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
    );

    await tester.enterText(find.byType(TextFormField).at(0), '2,5');
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    final updated = (harness.result! as CatchUpdated).catchModel;
    expect(updated.weightGrams, 2500);
  });

  testWidgets('accepts a period decimal separator for length', (tester) async {
    final harness = _EditCatchHarness();
    await harness.open(
      tester,
      fishingSpot,
      existingCatch,
      catchRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
    );

    await tester.enterText(find.byType(TextFormField).at(1), '68.5');
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    final updated = (harness.result! as CatchUpdated).catchModel;
    expect(updated.lengthMillimeters, 685);
  });

  testWidgets('allows clearing an existing weight', (tester) async {
    final harness = _EditCatchHarness();
    await harness.open(
      tester,
      fishingSpot,
      existingCatch,
      catchRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
    );

    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    final updated = (harness.result! as CatchUpdated).catchModel;
    expect(updated.weightGrams, isNull);
  });

  testWidgets('allows clearing an existing length', (tester) async {
    final harness = _EditCatchHarness();
    await harness.open(
      tester,
      fishingSpot,
      existingCatch,
      catchRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
    );

    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    final updated = (harness.result! as CatchUpdated).catchModel;
    expect(updated.lengthMillimeters, isNull);
  });

  testWidgets('rejects zero weight and keeps the sheet open', (tester) async {
    final harness = _EditCatchHarness();
    await harness.open(
      tester,
      fishingSpot,
      existingCatch,
      catchRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
    );

    await tester.enterText(find.byType(TextFormField).at(0), '0');
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    expect(harness.result, isNull);
    expect(find.text('Painon täytyy olla suurempi kuin 0'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('shows an error and preserves values when save fails', (
    tester,
  ) async {
    final failingRepository = _FailingUpdateCatchRepository(database);
    final harness = _EditCatchHarness();
    await harness.open(
      tester,
      fishingSpot,
      existingCatch,
      failingRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
    );

    await tester.enterText(find.byType(TextFormField).at(0), '5');
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    expect(harness.result, isNull);
    expect(
      find.text('Saaliin tallentaminen epäonnistui. Yritä uudelleen.'),
      findsOneWidget,
    );
    expect(find.text('5'), findsOneWidget);
    expect(failingRepository.updateCallCount, 1);
  });

  testWidgets('prevents duplicate save taps', (tester) async {
    final slowRepository = _SlowUpdateCatchRepository(database);
    final harness = _EditCatchHarness();
    await harness.open(
      tester,
      fishingSpot,
      existingCatch,
      slowRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
    );

    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pump();

    expect(slowRepository.updateCallCount, 1);

    slowRepository.gate.complete();
    await tester.pumpAndSettle();

    expect(harness.result, isA<CatchUpdated>());
  });

  group('delete', () {
    testWidgets('shows a confirmation dialog', (tester) async {
      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.byKey(const Key('editCatchDeleteButton')));
      await tester.pumpAndSettle();

      expect(find.text('Poistetaanko saalis?'), findsOneWidget);
      expect(find.text('Toimintoa ei voi perua.'), findsOneWidget);
    });

    testWidgets('cancelling keeps the sheet open and does not delete', (
      tester,
    ) async {
      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.byKey(const Key('editCatchDeleteButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Peruuta'));
      await tester.pumpAndSettle();

      expect(harness.result, isNull);
      expect(find.text('Merrasjärvi'), findsOneWidget);
      expect(await catchRepository.getById(existingCatch.id), isNotNull);
    });

    testWidgets('confirming deletes the catch and closes the sheet', (
      tester,
    ) async {
      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.byKey(const Key('editCatchDeleteButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista').last);
      await tester.pump();
      // The delete flow calls CatchPhotoRepository.deleteAllForCatch first,
      // which performs genuine dart:io directory operations even with no
      // photos; give the real event loop time to complete that work before
      // resuming normal (fake-clock) pumping.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      expect(harness.result, isA<CatchDeleted>());
      expect((harness.result! as CatchDeleted).catchId, existingCatch.id);
      expect(await catchRepository.getById(existingCatch.id), isNull);
    });

    testWidgets('shows an error and keeps the sheet open when delete fails', (
      tester,
    ) async {
      final failingRepository = _FailingDeleteCatchRepository(database);
      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        failingRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.byKey(const Key('editCatchDeleteButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista').last);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      expect(harness.result, isNull);
      expect(
        find.text('Saaliin poistaminen epäonnistui. Yritä uudelleen.'),
        findsOneWidget,
      );
      expect(failingRepository.deleteCallCount, 1);
    });

    testWidgets('prevents duplicate delete taps', (tester) async {
      final slowRepository = _SlowDeleteCatchRepository(database);
      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        slowRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.byKey(const Key('editCatchDeleteButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista').last);
      await tester.pump();
      // Let CatchPhotoRepository.deleteAllForCatch's real dart:io work
      // resolve before checking that the (still-gated) Catch delete call
      // has happened exactly once.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      expect(slowRepository.deleteCallCount, 1);

      // The sheet's own Delete button is now disabled while deleting; a
      // second tap attempt must not trigger a second repository call.
      await tester.tap(
        find.byKey(const Key('editCatchDeleteButton')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(slowRepository.deleteCallCount, 1);

      slowRepository.gate.complete();
      await tester.pumpAndSettle();

      expect(harness.result, isA<CatchDeleted>());
    });
  });

  group('photos', () {
    late Directory storageDir;
    late Directory sourceDir;
    late FakeImagePickerPlatform fakePicker;
    late ImagePickerPlatform originalPicker;

    setUp(() {
      storageDir = Directory.systemTemp.createTempSync(
        'edit_catch_photos_storage',
      );
      sourceDir = Directory.systemTemp.createTempSync(
        'edit_catch_photos_source',
      );
      catchPhotoRepository = CatchPhotoRepository(
        database,
        CatchPhotoStorage(rootDirectoryProvider: () async => storageDir),
      );

      originalPicker = ImagePickerPlatform.instance;
      fakePicker = FakeImagePickerPlatform();
      ImagePickerPlatform.instance = fakePicker;
    });

    tearDown(() {
      ImagePickerPlatform.instance = originalPicker;
      if (storageDir.existsSync()) {
        storageDir.deleteSync(recursive: true);
      }
      if (sourceDir.existsSync()) {
        sourceDir.deleteSync(recursive: true);
      }
    });

    testWidgets('shows an empty photo list normally', (tester) async {
      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      expect(find.byType(Image), findsNothing);
      expect(find.byKey(const Key('catchPhotoAddButton')), findsOneWidget);
    });

    testWidgets('shows existing photos in sort order', (tester) async {
      await tester.runAsync(
        () => catchPhotoRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(sourceDir, 'a.jpg'),
          ),
        ),
      );
      await tester.runAsync(
        () => catchPhotoRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(sourceDir, 'b.jpg'),
          ),
        ),
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('adds a pending photo during edit', (tester) async {
      fakePicker.nextCameraImage = writeTestXFile(sourceDir, 'camera.jpg');

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.byKey(const Key('catchPhotoAddButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catchPhotoSourceCamera')));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('enforces the combined existing + pending limit', (
      tester,
    ) async {
      for (var i = 0; i < maxCatchPhotos - 1; i++) {
        await tester.runAsync(
          () => catchPhotoRepository.add(
            catchId: existingCatch.id,
            pendingPhoto: PendingCatchPhoto(
              sourcePath: writeTestJpeg(sourceDir, '$i.jpg'),
            ),
          ),
        );
      }
      fakePicker.nextCameraImage = writeTestXFile(sourceDir, 'camera.jpg');

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      expect(find.byKey(const Key('catchPhotoAddButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('catchPhotoAddButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catchPhotoSourceCamera')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('catchPhotoAddButton')), findsNothing);
      expect(find.textContaining('enimmäismäärä (5)'), findsOneWidget);
    });

    testWidgets('removes a pending photo without confirmation', (tester) async {
      fakePicker.nextCameraImage = writeTestXFile(sourceDir, 'camera.jpg');

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.byKey(const Key('catchPhotoAddButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catchPhotoSourceCamera')));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('persistent delete shows a confirmation dialog', (
      tester,
    ) async {
      final photo = await tester.runAsync(
        () => catchPhotoRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(sourceDir, 'a.jpg'),
          ),
        ),
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Poistetaanko kuva?'), findsOneWidget);
      expect(find.text('Toimintoa ei voi perua.'), findsOneWidget);
      final stored = await catchPhotoRepository.getByCatchId(existingCatch.id);
      expect(stored.map((p) => p.id), [photo!.id]);
    });

    testWidgets('persistent delete cancelling keeps the photo', (tester) async {
      await tester.runAsync(
        () => catchPhotoRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(sourceDir, 'a.jpg'),
          ),
        ),
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Peruuta'));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(
        await catchPhotoRepository.getByCatchId(existingCatch.id),
        hasLength(1),
      );
    });

    testWidgets('persistent delete confirming removes the photo', (
      tester,
    ) async {
      // Real file removal is covered by CatchPhotoRepository/CatchPhotoStorage
      // tests; see _NonLockingDeleteCatchPhotoStorage for why this widget
      // test uses a non-file-touching delete.
      final nonLockingRepository = CatchPhotoRepository(
        database,
        _NonLockingDeleteCatchPhotoStorage(
          rootDirectoryProvider: () async => storageDir,
        ),
      );
      await tester.runAsync(
        () => nonLockingRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(sourceDir, 'a.jpg'),
          ),
        ),
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        nonLockingRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista').last);
      await _pumpUntilSettledWithRealIO(tester);

      expect(find.byType(Image), findsNothing);
      expect(
        await nonLockingRepository.getByCatchId(existingCatch.id),
        isEmpty,
      );
    });

    testWidgets(
      'persistent delete failure keeps the photo and shows an error',
      (tester) async {
        final failingRepository = _FailingDeleteCatchPhotoRepository(
          database,
          CatchPhotoStorage(rootDirectoryProvider: () async => storageDir),
        );
        await tester.runAsync(
          () => failingRepository.add(
            catchId: existingCatch.id,
            pendingPhoto: PendingCatchPhoto(
              sourcePath: writeTestJpeg(sourceDir, 'a.jpg'),
            ),
          ),
        );

        final harness = _EditCatchHarness();
        await harness.open(
          tester,
          fishingSpot,
          existingCatch,
          catchRepository,
          failingRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
        );

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Poista').last);
        await tester.pumpAndSettle();

        expect(find.byType(Image), findsOneWidget);
        expect(
          find.text('Kuvan poistaminen epäonnistui. Yritä uudelleen.'),
          findsOneWidget,
        );
        expect(failingRepository.deleteCallCount, 1);
      },
    );

    testWidgets('prevents a duplicate persistent delete request', (
      tester,
    ) async {
      final slowRepository = _SlowDeleteCatchPhotoRepository(
        database,
        _NonLockingDeleteCatchPhotoStorage(
          rootDirectoryProvider: () async => storageDir,
        ),
      );
      final photo = await tester.runAsync(
        () => slowRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(sourceDir, 'a.jpg'),
          ),
        ),
      );
      final removeButton = find.byKey(
        ValueKey('deleteExistingPhoto-${photo!.id}'),
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        slowRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(removeButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista').last);
      await tester.pump();

      expect(slowRepository.deleteCallCount, 1);

      // The remove affordance now shows a busy spinner and is disabled while
      // a photo delete is in flight, so a second tap must not remove twice.
      await tester.tap(removeButton, warnIfMissed: false);
      await tester.pump();

      expect(slowRepository.deleteCallCount, 1);

      slowRepository.gate.complete();
      await _pumpUntilSettledWithRealIO(tester);

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('shows a placeholder for a missing photo file', (tester) async {
      final photo = await tester.runAsync(
        () => catchPhotoRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(sourceDir, 'a.jpg'),
          ),
        ),
      );
      final file = await catchPhotoRepository.resolveFile(photo!);
      await tester.runAsync(() => file.delete());

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );
      await _pumpUntilSettledWithRealIO(tester);

      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('opens the full-screen viewer for an existing photo', (
      tester,
    ) async {
      await tester.runAsync(
        () => catchPhotoRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(sourceDir, 'a.jpg'),
          ),
        ),
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.byType(CatchPhotoViewer), findsOneWidget);
    });

    testWidgets(
      'Catch update success adds pending photos and reports failures',
      (tester) async {
        fakePicker.nextGalleryImages = [
          writeTestXFile(sourceDir, 'good.jpg'),
          writeCorruptXFile(sourceDir, 'corrupt.jpg'),
        ];

        final harness = _EditCatchHarness();
        await harness.open(
          tester,
          fishingSpot,
          existingCatch,
          catchRepository,
          catchPhotoRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
        );

        await tester.tap(find.byKey(const Key('catchPhotoAddButton')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('catchPhotoSourceGallery')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('editCatchSaveButton')));
        await tester.pump();
        await _pumpUntilSettledWithRealIO(tester);

        final result = harness.result;
        expect(result, isA<CatchUpdated>());
        final updated = result! as CatchUpdated;
        expect(updated.photoFailureCount, 1);
        expect(updated.hasPhotoFailures, isTrue);
        expect(
          await catchPhotoRepository.getByCatchId(existingCatch.id),
          hasLength(1),
        );
      },
    );

    testWidgets('Catch update failure preserves existing and pending photos', (
      tester,
    ) async {
      final failingRepository = _FailingUpdateCatchRepository(database);
      await tester.runAsync(
        () => catchPhotoRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(sourceDir, 'a.jpg'),
          ),
        ),
      );
      fakePicker.nextCameraImage = writeTestXFile(sourceDir, 'camera.jpg');

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        failingRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.byKey(const Key('catchPhotoAddButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catchPhotoSourceCamera')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('editCatchSaveButton')));
      await tester.pumpAndSettle();

      expect(harness.result, isNull);
      expect(find.byType(Image), findsNWidgets(2));
      expect(
        await catchPhotoRepository.getByCatchId(existingCatch.id),
        hasLength(1),
      );
    });

    testWidgets('Catch deletion failure after file cleanup preserves the Catch '
        'and its CatchPhoto rows', (tester) async {
      final failingRepository = _FailingDeleteCatchRepository(database);
      // See _NonLockingDeleteCatchPhotoStorage: avoids a Windows-only
      // Skia file-handle artifact unrelated to the behavior under test.
      final nonLockingPhotoRepository = CatchPhotoRepository(
        database,
        _NonLockingDeleteCatchPhotoStorage(
          rootDirectoryProvider: () async => storageDir,
        ),
      );
      await tester.runAsync(
        () => nonLockingPhotoRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(sourceDir, 'a.jpg'),
          ),
        ),
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        failingRepository,
        nonLockingPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.byKey(const Key('editCatchDeleteButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista').last);
      await _pumpUntilSettledWithRealIO(tester);

      expect(harness.result, isNull);
      expect(failingRepository.deleteCallCount, 1);
      // File cleanup (deleteFilesForCatch) ran and succeeded before the
      // Catch deletion failed. Because that step never touches CatchPhoto
      // rows, the Catch and its photo record both survive — the record
      // will correctly render as a missing-file placeholder rather than
      // disappearing.
      expect(await failingRepository.getById(existingCatch.id), isNotNull);
      expect(
        await nonLockingPhotoRepository.getByCatchId(existingCatch.id),
        hasLength(1),
      );
    });

    group('operation locking', () {
      testWidgets('Save is disabled while a photo pick is in flight', (
        tester,
      ) async {
        fakePicker.gate = Completer<void>();
        fakePicker.nextCameraImage = writeTestXFile(sourceDir, 'camera.jpg');

        final harness = _EditCatchHarness();
        await harness.open(
          tester,
          fishingSpot,
          existingCatch,
          catchRepository,
          catchPhotoRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
        );

        await tester.tap(find.byKey(const Key('catchPhotoAddButton')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('catchPhotoSourceCamera')));
        await tester.pump();

        final saveButton = tester.widget<FilledButton>(
          find.byKey(const Key('editCatchSaveButton')),
        );
        expect(saveButton.onPressed, isNull);

        fakePicker.gate!.complete();
        await tester.pumpAndSettle();
      });

      testWidgets('Delete is disabled while a photo pick is in flight', (
        tester,
      ) async {
        fakePicker.gate = Completer<void>();
        fakePicker.nextCameraImage = writeTestXFile(sourceDir, 'camera.jpg');

        final harness = _EditCatchHarness();
        await harness.open(
          tester,
          fishingSpot,
          existingCatch,
          catchRepository,
          catchPhotoRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
        );

        await tester.tap(find.byKey(const Key('catchPhotoAddButton')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('catchPhotoSourceCamera')));
        await tester.pump();

        final deleteButton = tester.widget<OutlinedButton>(
          find.byKey(const Key('editCatchDeleteButton')),
        );
        expect(deleteButton.onPressed, isNull);

        fakePicker.gate!.complete();
        await tester.pumpAndSettle();
      });

      testWidgets(
        'Save is disabled while a persistent photo deletion is in flight',
        (tester) async {
          final slowPhotoRepository = _SlowDeleteCatchPhotoRepository(
            database,
            _NonLockingDeleteCatchPhotoStorage(
              rootDirectoryProvider: () async => storageDir,
            ),
          );
          await tester.runAsync(
            () => slowPhotoRepository.add(
              catchId: existingCatch.id,
              pendingPhoto: PendingCatchPhoto(
                sourcePath: writeTestJpeg(sourceDir, 'a.jpg'),
              ),
            ),
          );

          final harness = _EditCatchHarness();
          await harness.open(
            tester,
            fishingSpot,
            existingCatch,
            catchRepository,
            slowPhotoRepository,
            lureCatalogRepository,
            personalTackleBoxRepository,
            personalTackleBoxPhotoStorage,
          );

          await tester.tap(find.byIcon(Icons.close));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Poista').last);
          await tester.pump();

          expect(slowPhotoRepository.deleteCallCount, 1);
          final saveButton = tester.widget<FilledButton>(
            find.byKey(const Key('editCatchSaveButton')),
          );
          expect(saveButton.onPressed, isNull);

          slowPhotoRepository.gate.complete();
          await _pumpUntilSettledWithRealIO(tester);
        },
      );

      testWidgets(
        'Delete is disabled while a persistent photo deletion is in flight',
        (tester) async {
          final slowPhotoRepository = _SlowDeleteCatchPhotoRepository(
            database,
            _NonLockingDeleteCatchPhotoStorage(
              rootDirectoryProvider: () async => storageDir,
            ),
          );
          await tester.runAsync(
            () => slowPhotoRepository.add(
              catchId: existingCatch.id,
              pendingPhoto: PendingCatchPhoto(
                sourcePath: writeTestJpeg(sourceDir, 'a.jpg'),
              ),
            ),
          );

          final harness = _EditCatchHarness();
          await harness.open(
            tester,
            fishingSpot,
            existingCatch,
            catchRepository,
            slowPhotoRepository,
            lureCatalogRepository,
            personalTackleBoxRepository,
            personalTackleBoxPhotoStorage,
          );

          await tester.tap(find.byIcon(Icons.close));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Poista').last);
          await tester.pump();

          expect(slowPhotoRepository.deleteCallCount, 1);
          final deleteButton = tester.widget<OutlinedButton>(
            find.byKey(const Key('editCatchDeleteButton')),
          );
          expect(deleteButton.onPressed, isNull);

          slowPhotoRepository.gate.complete();
          await _pumpUntilSettledWithRealIO(tester);
        },
      );

      testWidgets(
        'the add-photo action is disabled while Catch Save is in flight',
        (tester) async {
          final slowRepository = _SlowUpdateCatchRepository(database);

          final harness = _EditCatchHarness();
          await harness.open(
            tester,
            fishingSpot,
            existingCatch,
            slowRepository,
            catchPhotoRepository,
            lureCatalogRepository,
            personalTackleBoxRepository,
            personalTackleBoxPhotoStorage,
          );

          await tester.tap(find.byKey(const Key('editCatchSaveButton')));
          await tester.pump();

          expect(slowRepository.updateCallCount, 1);
          final addTile = tester.widget<InkWell>(
            find.byKey(const Key('catchPhotoAddButton')),
          );
          expect(addTile.onTap, isNull);

          slowRepository.gate.complete();
          await tester.pumpAndSettle();
        },
      );

      testWidgets(
        'the add-photo action is disabled while Catch Delete is in flight',
        (tester) async {
          final slowRepository = _SlowDeleteCatchRepository(database);

          final harness = _EditCatchHarness();
          await harness.open(
            tester,
            fishingSpot,
            existingCatch,
            slowRepository,
            catchPhotoRepository,
            lureCatalogRepository,
            personalTackleBoxRepository,
            personalTackleBoxPhotoStorage,
          );

          await tester.tap(find.byKey(const Key('editCatchDeleteButton')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Poista').last);
          await tester.pump();
          // deleteFilesForCatch runs (and completes, even with no photos —
          // it still performs a real dart:io directory check) before the
          // gated CatchRepository.delete call is reached.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)),
          );
          await tester.pump();

          expect(slowRepository.deleteCallCount, 1);
          final addTile = tester.widget<InkWell>(
            find.byKey(const Key('catchPhotoAddButton')),
          );
          expect(addTile.onTap, isNull);

          slowRepository.gate.complete();
          await _pumpUntilSettledWithRealIO(tester);
        },
      );
    });
  });

  group('lure assignment', () {
    Future<String> seedOwnedLure({String variantId = 'variant-1'}) async {
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
              id: variantId,
              lureModelId: modelId,
              colorName: const Value('Hot Craw'),
              searchText: 'hot craw',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      final catalogEntry = LureCatalogEntry(
        variant: LureVariant(
          id: variantId,
          lureModelId: modelId,
          colorName: 'Hot Craw',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        manufacturer: 'Rapala',
        modelName: 'X-Rap Shad XRS08',
        lureType: 'crankbait',
        modelDefaultImageReference: null,
      );
      await personalTackleBoxRepository.add(catalogEntry: catalogEntry);
      return variantId;
    }

    testWidgets('shows no assignment for a catch with none', (tester) async {
      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      expect(find.text('Ei valittua viehettä'), findsOneWidget);
    });

    testWidgets('loads and displays the existing assignment', (tester) async {
      final variantId = await seedOwnedLure();
      final catchWithLure = await catchRepository.update(
        catchModel: existingCatch,
        species: existingCatch.species,
        caughtAt: existingCatch.caughtAt,
        weightGrams: existingCatch.weightGrams,
        lengthMillimeters: existingCatch.lengthMillimeters,
        lureVariantId: variantId,
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchWithLure,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      expect(find.text('Rapala X-Rap Shad XRS08'), findsOneWidget);
    });

    testWidgets('changing the assignment via the picker updates the save', (
      tester,
    ) async {
      final firstVariantId = await seedOwnedLure(variantId: 'variant-1');
      final secondVariantId = await seedOwnedLure(variantId: 'variant-2');
      final catchWithLure = await catchRepository.update(
        catchModel: existingCatch,
        species: existingCatch.species,
        caughtAt: existingCatch.caughtAt,
        weightGrams: existingCatch.weightGrams,
        lengthMillimeters: existingCatch.lengthMillimeters,
        lureVariantId: firstVariantId,
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchWithLure,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.text('Vaihda').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hot Craw').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('editCatchSaveButton')));
      await tester.pumpAndSettle();

      final updated = (harness.result! as CatchUpdated).catchModel;
      expect(updated.lureVariantId, secondVariantId);
    });

    testWidgets('removing the assignment clears it on save', (tester) async {
      final variantId = await seedOwnedLure();
      final catchWithLure = await catchRepository.update(
        catchModel: existingCatch,
        species: existingCatch.species,
        caughtAt: existingCatch.caughtAt,
        weightGrams: existingCatch.weightGrams,
        lengthMillimeters: existingCatch.lengthMillimeters,
        lureVariantId: variantId,
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchWithLure,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.tap(find.text('Poista').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('editCatchSaveButton')));
      await tester.pumpAndSettle();

      final updated = (harness.result! as CatchUpdated).catchModel;
      expect(updated.lureVariantId, isNull);
    });

    testWidgets(
      'an unresolvable assignment shows a fallback without blocking save',
      (tester) async {
        // The restrict foreign keys make a genuinely orphaned reference
        // structurally impossible to persist (TD-017 §9), so the
        // resolution failure itself is simulated at the repository layer
        // instead — a `LureCatalogRepository` whose `getEntryById` always
        // returns null, mirroring this file's existing `_Failing`/`_Slow`
        // subclass convention for CatchRepository.
        final variantId = await seedOwnedLure();
        final catchWithLure = await catchRepository.update(
          catchModel: existingCatch,
          species: existingCatch.species,
          caughtAt: existingCatch.caughtAt,
          weightGrams: existingCatch.weightGrams,
          lengthMillimeters: existingCatch.lengthMillimeters,
          lureVariantId: variantId,
        );

        final harness = _EditCatchHarness();
        await harness.open(
          tester,
          fishingSpot,
          catchWithLure,
          catchRepository,
          catchPhotoRepository,
          _NullResolvingLureCatalogRepository(database),
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
        );

        expect(find.text('Viehetiedot eivät ole saatavilla'), findsOneWidget);

        await tester.tap(find.byKey(const Key('editCatchSaveButton')));
        await tester.pumpAndSettle();

        expect(harness.result, isA<CatchUpdated>());
      },
    );
  });

  group('notes', () {
    testWidgets('prefills the existing note', (tester) async {
      final catchWithNotes = await catchRepository.update(
        catchModel: existingCatch,
        species: existingCatch.species,
        caughtAt: existingCatch.caughtAt,
        weightGrams: existingCatch.weightGrams,
        lengthMillimeters: existingCatch.lengthMillimeters,
        notes: 'Aiempi muistiinpano.',
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchWithNotes,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      final notesField = tester.widget<TextFormField>(
        find.byKey(const Key('editCatchNotesField')),
      );
      expect(notesField.controller!.text, 'Aiempi muistiinpano.');
    });

    testWidgets('shows an empty field when there is no existing note', (
      tester,
    ) async {
      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      final notesField = tester.widget<TextFormField>(
        find.byKey(const Key('editCatchNotesField')),
      );
      expect(notesField.controller!.text, isEmpty);
    });

    testWidgets('a note can be added where none existed', (tester) async {
      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.enterText(
        find.byKey(const Key('editCatchNotesField')),
        'Uusi muistiinpano.',
      );
      await tester.tap(find.byKey(const Key('editCatchSaveButton')));
      await tester.pumpAndSettle();

      final updated = (harness.result! as CatchUpdated).catchModel;
      expect(updated.notes, 'Uusi muistiinpano.');
    });

    testWidgets('an existing note can be changed', (tester) async {
      final catchWithNotes = await catchRepository.update(
        catchModel: existingCatch,
        species: existingCatch.species,
        caughtAt: existingCatch.caughtAt,
        weightGrams: existingCatch.weightGrams,
        lengthMillimeters: existingCatch.lengthMillimeters,
        notes: 'Vanha muistiinpano.',
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchWithNotes,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.enterText(
        find.byKey(const Key('editCatchNotesField')),
        'Päivitetty muistiinpano.',
      );
      await tester.tap(find.byKey(const Key('editCatchSaveButton')));
      await tester.pumpAndSettle();

      final updated = (harness.result! as CatchUpdated).catchModel;
      expect(updated.notes, 'Päivitetty muistiinpano.');
    });

    testWidgets('an existing note can be cleared by deleting all its text', (
      tester,
    ) async {
      final catchWithNotes = await catchRepository.update(
        catchModel: existingCatch,
        species: existingCatch.species,
        caughtAt: existingCatch.caughtAt,
        weightGrams: existingCatch.weightGrams,
        lengthMillimeters: existingCatch.lengthMillimeters,
        notes: 'Poistettava muistiinpano.',
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchWithNotes,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      await tester.enterText(find.byKey(const Key('editCatchNotesField')), '');
      await tester.tap(find.byKey(const Key('editCatchSaveButton')));
      await tester.pumpAndSettle();

      final updated = (harness.result! as CatchUpdated).catchModel;
      expect(updated.notes, isNull);
    });

    testWidgets('a note of exactly 1000 characters saves successfully', (
      tester,
    ) async {
      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
      );

      final notes = 'a' * maxCatchNotesLength;
      await tester.enterText(
        find.byKey(const Key('editCatchNotesField')),
        notes,
      );
      await tester.tap(find.byKey(const Key('editCatchSaveButton')));
      await tester.pumpAndSettle();

      final updated = (harness.result! as CatchUpdated).catchModel;
      expect(updated.notes, hasLength(maxCatchNotesLength));
    });

    testWidgets(
      'over-limit input (1001 characters) blocks saving and preserves the text',
      (tester) async {
        final repository = _FailingUpdateCatchRepository(database);
        final harness = _EditCatchHarness();
        await harness.open(
          tester,
          fishingSpot,
          existingCatch,
          repository,
          catchPhotoRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
        );

        final overLimitNotes = 'a' * (maxCatchNotesLength + 1);
        await tester.enterText(
          find.byKey(const Key('editCatchNotesField')),
          overLimitNotes,
        );

        // Step 2: the field still contains the full over-limit text.
        final fieldWidget = tester.widget<TextFormField>(
          find.byKey(const Key('editCatchNotesField')),
        );
        expect(
          fieldWidget.controller!.text,
          hasLength(maxCatchNotesLength + 1),
        );

        // Step 3: attempt to save.
        await tester.tap(find.byKey(const Key('editCatchSaveButton')));
        await tester.pumpAndSettle();

        // Step 4: saving does not occur; validation blocked the save before
        // the repository was ever reached, and the stored catch is
        // unchanged.
        expect(harness.result, isNull);
        expect(repository.updateCallCount, 0);
        final stored = await catchRepository.getById(existingCatch.id);
        expect(stored!.notes, existingCatch.notes);

        // Step 5: the Finnish validation message is shown.
        expect(
          find.text('Muistiinpanot voivat olla enintään 1000 merkkiä.'),
          findsOneWidget,
        );

        // Step 6: the entered content remains available for correction.
        final fieldAfterFailure = tester.widget<TextFormField>(
          find.byKey(const Key('editCatchNotesField')),
        );
        expect(
          fieldAfterFailure.controller!.text,
          hasLength(maxCatchNotesLength + 1),
        );
      },
    );

    testWidgets(
      'Catch save failure preserves the newly entered multiline note',
      (tester) async {
        final catchWithNotes = await catchRepository.update(
          catchModel: existingCatch,
          species: existingCatch.species,
          caughtAt: existingCatch.caughtAt,
          weightGrams: existingCatch.weightGrams,
          lengthMillimeters: existingCatch.lengthMillimeters,
          notes: 'Vanha muistiinpano.',
        );
        final failingRepository = _FailingUpdateCatchRepository(database);
        final distinctiveNote =
            'Uusi havainto illalta.\nVesi oli erittäin kirkasta.';

        final harness = _EditCatchHarness();
        await harness.open(
          tester,
          fishingSpot,
          catchWithNotes,
          failingRepository,
          catchPhotoRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
        );

        await tester.enterText(
          find.byKey(const Key('editCatchNotesField')),
          distinctiveNote,
        );
        await tester.tap(find.byKey(const Key('editCatchSaveButton')));
        await tester.pumpAndSettle();

        // The repository was called exactly once, and its failure kept the
        // sheet open with no CatchUpdated result.
        expect(failingRepository.updateCallCount, 1);
        expect(harness.result, isNull);
        expect(find.byType(EditCatchBottomSheet), findsOneWidget);

        // The complete newly entered note, including its line break,
        // remains in the field.
        final notesField = tester.widget<TextFormField>(
          find.byKey(const Key('editCatchNotesField')),
        );
        expect(notesField.controller!.text, distinctiveNote);
      },
    );

    testWidgets(
      'saving a note change still produces the existing CatchUpdated contract',
      (tester) async {
        final harness = _EditCatchHarness();
        await harness.open(
          tester,
          fishingSpot,
          existingCatch,
          catchRepository,
          catchPhotoRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
        );

        await tester.enterText(
          find.byKey(const Key('editCatchNotesField')),
          'Muutettu muistiinpano.',
        );
        await tester.tap(find.byKey(const Key('editCatchSaveButton')));
        await tester.pumpAndSettle();

        final result = harness.result;
        expect(result, isA<CatchUpdated>());
        final updated = result! as CatchUpdated;
        expect(updated.catchModel.notes, 'Muutettu muistiinpano.');
        expect(updated.photoFailureCount, 0);
        expect(updated.hasPhotoFailures, isFalse);
      },
    );
  });
}
