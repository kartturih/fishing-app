import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/data/storage/catch_photo_storage.dart';
import 'package:fishing_app/features/catch_photos/domain/pending_catch_photo.dart';
import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_viewer.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_details_page.dart';
import 'package:fishing_app/features/catches/presentation/widgets/edit_catch_bottom_sheet.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';

import '../../../../support/test_image_files.dart';

/// A storage whose [delete] never touches the real file, avoiding a
/// Windows-only Skia file-handle artifact unrelated to the behavior under
/// test. See the identical helper in edit_catch_bottom_sheet_test.dart.
class _NonLockingDeleteCatchPhotoStorage extends CatchPhotoStorage {
  _NonLockingDeleteCatchPhotoStorage({required super.rootDirectoryProvider});

  @override
  Future<void> delete(String relativePath) async {}

  @override
  Future<void> deleteCatchDirectory(String catchId) async {}
}

/// A `LureCatalogRepository` whose `getEntryById` always returns `null`,
/// simulating an unresolvable reference. See the identical helper in
/// edit_catch_bottom_sheet_test.dart.
class _NullResolvingLureCatalogRepository extends LureCatalogRepository {
  _NullResolvingLureCatalogRepository(super.database);

  @override
  Future<LureCatalogEntry?> getEntryById(String variantId) async => null;
}

/// A `WaterBodyRepository` whose `getById` always returns `null`, simulating
/// an unresolvable reference — mirrors
/// `_NullResolvingLureCatalogRepository`'s own precedent.
class _NullResolvingWaterBodyRepository extends WaterBodyRepository {
  _NullResolvingWaterBodyRepository(super.database);

  @override
  Future<WaterBody?> getById(String id) async => null;
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

/// Holds `delete` open on [deleteGate] until the test completes it —
/// simulates the real, measurable device-I/O delay `_confirmDelete`'s own
/// awaited deletion can take, so a test can attempt to navigate away
/// *while* the deletion is still in flight.
class _SlowDeleteCatchRepository extends CatchRepository {
  _SlowDeleteCatchRepository(super.database);

  final Completer<void> deleteGate = Completer<void>();
  int deleteCallCount = 0;

  @override
  Future<void> delete(String catchId) async {
    deleteCallCount++;
    await deleteGate.future;
    await super.delete(catchId);
  }
}

/// Pumps and lets a multi-step real dart:io chain (image loading, file
/// deletion) advance to completion; see the identical helper in
/// edit_catch_bottom_sheet_test.dart / catch_photo_viewer_test.dart.
Future<void> _pumpUntilSettledWithRealIO(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _openDetails(
  WidgetTester tester,
  FishingSpot fishingSpot,
  Catch catchModel,
  CatchRepository catchRepository,
  CatchPhotoRepository catchPhotoRepository,
  LureCatalogRepository lureCatalogRepository,
  PersonalTackleBoxRepository personalTackleBoxRepository,
  TackleBoxPhotoStorage personalTackleBoxPhotoStorage,
  WaterBodyRepository waterBodyRepository,
) async {
  // Taller than the default test viewport: Edit Catch's form (now including
  // the MFS-017 lure-assignment row) no longer fits at the default 800x600
  // in every test, which left "Tallenna" below the fold and unhittable.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CatchDetailsPage.open(
              context,
              fishingSpot: fishingSpot,
              catchModel: catchModel,
              catchRepository: catchRepository,
              catchPhotoRepository: catchPhotoRepository,
              lureCatalogRepository: lureCatalogRepository,
              personalTackleBoxRepository: personalTackleBoxRepository,
              personalTackleBoxPhotoStorage: personalTackleBoxPhotoStorage,
              waterBodyRepository: waterBodyRepository,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase database;
  late CatchRepository catchRepository;
  late CatchPhotoRepository catchPhotoRepository;
  late Directory storageDir;
  late Directory sourceDir;
  late Directory tackleBoxStorageDir;
  late FishingSpotRepository fishingSpotRepository;
  late FishingSpot fishingSpot;
  late Catch existingCatch;
  late LureCatalogRepository lureCatalogRepository;
  late PersonalTackleBoxRepository personalTackleBoxRepository;
  late TackleBoxPhotoStorage personalTackleBoxPhotoStorage;
  late WaterBodyRepository waterBodyRepository;

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
    storageDir = Directory.systemTemp.createTempSync(
      'catch_details_page_storage',
    );
    sourceDir = Directory.systemTemp.createTempSync(
      'catch_details_page_source',
    );
    tackleBoxStorageDir = Directory.systemTemp.createTempSync(
      'catch_details_page_tackle_box_storage',
    );
    catchPhotoRepository = CatchPhotoRepository(
      database,
      CatchPhotoStorage(rootDirectoryProvider: () async => storageDir),
    );
    lureCatalogRepository = LureCatalogRepository(database);
    personalTackleBoxPhotoStorage = TackleBoxPhotoStorage(
      rootDirectoryProvider: () async => tackleBoxStorageDir,
    );
    personalTackleBoxRepository = PersonalTackleBoxRepository(
      database,
      personalTackleBoxPhotoStorage,
    );
    fishingSpotRepository = FishingSpotRepository(database);
    waterBodyRepository = WaterBodyRepository(database);
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
    if (storageDir.existsSync()) {
      storageDir.deleteSync(recursive: true);
    }
    if (sourceDir.existsSync()) {
      sourceDir.deleteSync(recursive: true);
    }
    if (tackleBoxStorageDir.existsSync()) {
      tackleBoxStorageDir.deleteSync(recursive: true);
    }
  });

  testWidgets('renders read-only catch information with no editable fields', (
    tester,
  ) async {
    await _openDetails(
      tester,
      fishingSpot,
      existingCatch,
      catchRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
      waterBodyRepository,
    );

    // The species now appears only in the AppBar title — the redundant
    // "Kalalaji" metadata field has been removed.
    expect(find.text('Hauki'), findsOneWidget);
    expect(find.text('Kalalaji'), findsNothing);
    expect(find.text('3.2 kg'), findsOneWidget);
    expect(find.text('78 cm'), findsOneWidget);
    expect(find.text('14.7.2026'), findsOneWidget);
    expect(find.text('18.34'), findsOneWidget);
    expect(find.text('Vesistö'), findsOneWidget);
    expect(find.text('Test Water Body'), findsOneWidget);
    expect(find.text('Kalastuspaikka'), findsOneWidget);
    expect(find.text('Merrasjärvi'), findsOneWidget);

    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(DropdownButtonFormField<FishSpecies>), findsNothing);
  });

  testWidgets('omits weight and length rows when not set', (tester) async {
    final bareCatch = await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.perch,
      caughtAt: DateTime(2026, 7, 10, 21, 10),
    );

    await _openDetails(
      tester,
      fishingSpot,
      bareCatch,
      catchRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
      waterBodyRepository,
    );

    expect(find.text('Paino'), findsNothing);
    expect(find.text('Pituus'), findsNothing);
  });

  testWidgets('shows no photo container when the catch has no photos', (
    tester,
  ) async {
    await _openDetails(
      tester,
      fishingSpot,
      existingCatch,
      catchRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
      waterBodyRepository,
    );

    expect(find.byType(Image), findsNothing);
  });

  group('photo gallery', () {
    Finder dot(int index) =>
        find.byKey(ValueKey('catchDetailsPhotoDot-$index'));

    BoxDecoration decorationOf(WidgetTester tester, Finder finder) =>
        tester.widget<Container>(finder).decoration! as BoxDecoration;

    testWidgets('shows a single photo with no page indicator', (tester) async {
      await tester.runAsync(
        () => catchPhotoRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(sourceDir, 'a.jpg'),
          ),
        ),
      );

      await _openDetails(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );
      await _pumpUntilSettledWithRealIO(tester);

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(dot(0), findsNothing);
    });

    testWidgets('shows the first of multiple photos with a page indicator', (
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
      await tester.runAsync(
        () => catchPhotoRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(sourceDir, 'b.jpg'),
          ),
        ),
      );
      await tester.runAsync(
        () => catchPhotoRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(sourceDir, 'c.jpg'),
          ),
        ),
      );

      await _openDetails(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );
      await _pumpUntilSettledWithRealIO(tester);

      // PageView.builder only builds the current page, so exactly one
      // Image is present even though there are three photos.
      expect(find.byType(Image), findsOneWidget);
      expect(dot(0), findsOneWidget);
      expect(dot(1), findsOneWidget);
      expect(dot(2), findsOneWidget);
    });

    testWidgets('the active page indicator dot is visually distinct', (
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
      await tester.runAsync(
        () => catchPhotoRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(sourceDir, 'b.jpg'),
          ),
        ),
      );

      await _openDetails(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );
      await _pumpUntilSettledWithRealIO(tester);

      final activeSize = tester.getSize(dot(0));
      final inactiveSize = tester.getSize(dot(1));
      final activeColor = decorationOf(tester, dot(0)).color;
      final inactiveColor = decorationOf(tester, dot(1)).color;

      expect(activeSize.width, greaterThan(inactiveSize.width));
      expect(activeColor, isNot(equals(inactiveColor)));
    });

    testWidgets('swiping changes the active page indicator', (tester) async {
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

      await _openDetails(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );
      await _pumpUntilSettledWithRealIO(tester);

      expect(
        decorationOf(tester, dot(0)).color,
        isNot(equals(decorationOf(tester, dot(1)).color)),
      );
      final initialFirstDotColor = decorationOf(tester, dot(0)).color;

      await tester.drag(
        find.byKey(const Key('catchDetailsPhotoGallery')),
        const Offset(-500, 0),
      );
      await _pumpUntilSettledWithRealIO(tester);

      expect(decorationOf(tester, dot(1)).color, initialFirstDotColor);
      expect(
        decorationOf(tester, dot(0)).color,
        isNot(equals(initialFirstDotColor)),
      );
    });

    testWidgets('uses centered BoxFit.cover for a portrait photo', (
      tester,
    ) async {
      await tester.runAsync(
        () => catchPhotoRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(
              sourceDir,
              'portrait.jpg',
              width: 15,
              height: 20,
            ),
          ),
        ),
      );

      await _openDetails(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );
      await _pumpUntilSettledWithRealIO(tester);

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(image.alignment, Alignment.center);
    });

    testWidgets('uses centered BoxFit.cover for a landscape photo', (
      tester,
    ) async {
      await tester.runAsync(
        () => catchPhotoRepository.add(
          catchId: existingCatch.id,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: writeTestJpeg(
              sourceDir,
              'landscape.jpg',
              width: 20,
              height: 15,
            ),
          ),
        ),
      );

      await _openDetails(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );
      await _pumpUntilSettledWithRealIO(tester);

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(image.alignment, Alignment.center);
    });

    testWidgets('tapping the photo opens the full-screen viewer', (
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

      await _openDetails(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );
      await _pumpUntilSettledWithRealIO(tester);

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.byType(CatchPhotoViewer), findsOneWidget);
    });
  });

  testWidgets('the app bar back button returns to the previous screen', (
    tester,
  ) async {
    await _openDetails(
      tester,
      fishingSpot,
      existingCatch,
      catchRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
      waterBodyRepository,
    );
    expect(find.byType(CatchDetailsPage), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(CatchDetailsPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the overflow menu offers Edit and Delete', (tester) async {
    await _openDetails(
      tester,
      fishingSpot,
      existingCatch,
      catchRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
      waterBodyRepository,
    );

    await tester.tap(find.byKey(const Key('catchDetailsMenuButton')));
    await tester.pumpAndSettle();

    expect(find.text('Muokkaa'), findsOneWidget);
    expect(find.text('Poista'), findsOneWidget);
  });

  testWidgets('Edit opens the existing Edit Catch editor', (tester) async {
    await _openDetails(
      tester,
      fishingSpot,
      existingCatch,
      catchRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
      waterBodyRepository,
    );

    await tester.tap(find.byKey(const Key('catchDetailsMenuButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Muokkaa'));
    await tester.pumpAndSettle();

    expect(find.byType(EditCatchBottomSheet), findsOneWidget);
  });

  testWidgets('saving in the editor updates the details shown', (tester) async {
    await _openDetails(
      tester,
      fishingSpot,
      existingCatch,
      catchRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
      waterBodyRepository,
    );

    await tester.tap(find.byKey(const Key('catchDetailsMenuButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Muokkaa'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<FishSpecies>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(FishSpecies.zander.finnishName).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    expect(find.byType(EditCatchBottomSheet), findsNothing);
    expect(find.byType(CatchDetailsPage), findsOneWidget);
    expect(find.text('Kuha'), findsWidgets);
    expect(find.text('Hauki'), findsNothing);
  });

  testWidgets('cancelling the editor returns to unchanged details', (
    tester,
  ) async {
    await _openDetails(
      tester,
      fishingSpot,
      existingCatch,
      catchRepository,
      catchPhotoRepository,
      lureCatalogRepository,
      personalTackleBoxRepository,
      personalTackleBoxPhotoStorage,
      waterBodyRepository,
    );

    await tester.tap(find.byKey(const Key('catchDetailsMenuButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Muokkaa'));
    await tester.pumpAndSettle();

    // Dismiss the modal Bottom Sheet without saving, e.g. by tapping the
    // scrim above it.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(EditCatchBottomSheet), findsNothing);
    expect(find.byType(CatchDetailsPage), findsOneWidget);
    expect(find.text('Hauki'), findsWidgets);
  });

  group('delete', () {
    testWidgets('requires a confirmation dialog', (tester) async {
      await _openDetails(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );

      await tester.tap(find.byKey(const Key('catchDetailsMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista'));
      await tester.pumpAndSettle();

      expect(find.text('Poistetaanko saalis?'), findsOneWidget);
      expect(find.text('Toimintoa ei voi perua.'), findsOneWidget);
      expect(await catchRepository.getById(existingCatch.id), isNotNull);
    });

    testWidgets('cancelling keeps Catch Details open and does not delete', (
      tester,
    ) async {
      await _openDetails(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );

      await tester.tap(find.byKey(const Key('catchDetailsMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Peruuta'));
      await tester.pumpAndSettle();

      expect(find.byType(CatchDetailsPage), findsOneWidget);
      expect(await catchRepository.getById(existingCatch.id), isNotNull);
    });

    testWidgets(
      'confirming deletes the catch, cleans up photos, and closes the screen',
      (tester) async {
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

        await _openDetails(
          tester,
          fishingSpot,
          existingCatch,
          catchRepository,
          nonLockingRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
          waterBodyRepository,
        );
        await _pumpUntilSettledWithRealIO(tester);

        await tester.tap(find.byKey(const Key('catchDetailsMenuButton')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Poista'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Poista').last);
        await _pumpUntilSettledWithRealIO(tester);

        expect(find.byType(CatchDetailsPage), findsNothing);
        expect(find.text('Saalis poistettu'), findsOneWidget);
        expect(await catchRepository.getById(existingCatch.id), isNull);
        expect(
          await nonLockingRepository.getByCatchId(existingCatch.id),
          isEmpty,
        );
      },
    );

    testWidgets(
      'an impatient back-tap while the delete is still in flight does not '
      'pop the page before the deletion completes — regression for the '
      'physical-device bug where a caller reloaded before the delete had '
      'taken effect',
      (tester) async {
        final slowRepository = _SlowDeleteCatchRepository(database);

        await _openDetails(
          tester,
          fishingSpot,
          existingCatch,
          slowRepository,
          catchPhotoRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
          waterBodyRepository,
        );

        await tester.tap(find.byKey(const Key('catchDetailsMenuButton')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Poista'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Poista').last);
        // Let deleteFilesForCatch's real (but here trivially fast, no
        // photos) I/O run first, advancing execution to the gated
        // catchRepository.delete call.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();

        // The deletion is now suspended on deleteGate, mid-flight.
        expect(slowRepository.deleteCallCount, 1);
        expect(await catchRepository.getById(existingCatch.id), isNotNull);

        // An impatient back-tap while the deletion is still pending must
        // not pop the page — the only way out during this window is
        // _confirmDelete's own pop, once the deletion has actually
        // completed. pumpAndSettle (rather than a single pump) lets any
        // pop transition that *did* start run fully to completion, so
        // this check cannot be fooled by an in-progress route animation.
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.byType(CatchDetailsPage), findsOneWidget);
        expect(await catchRepository.getById(existingCatch.id), isNotNull);

        // Once the deletion completes, the page closes on its own.
        slowRepository.deleteGate.complete();
        await _pumpUntilSettledWithRealIO(tester);

        expect(find.byType(CatchDetailsPage), findsNothing);
        expect(await catchRepository.getById(existingCatch.id), isNull);
      },
    );

    testWidgets('shows an error and keeps the screen open when delete fails', (
      tester,
    ) async {
      final failingRepository = _FailingDeleteCatchRepository(database);

      await _openDetails(
        tester,
        fishingSpot,
        existingCatch,
        failingRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );

      await tester.tap(find.byKey(const Key('catchDetailsMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista').last);
      await _pumpUntilSettledWithRealIO(tester);

      expect(find.byType(CatchDetailsPage), findsOneWidget);
      expect(
        find.text('Saaliin poistaminen epäonnistui. Yritä uudelleen.'),
        findsOneWidget,
      );
      expect(failingRepository.deleteCallCount, 1);
    });
  });

  group('lure display', () {
    Future<String> seedOwnedLure(
      AppDatabase database, {
      String variantId = 'variant-1',
      bool retired = false,
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
              id: variantId,
              lureModelId: modelId,
              colorName: const Value('Hot Craw'),
              searchText: 'hot craw',
              retiredAt: retired ? const Value(1000) : const Value.absent(),
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      return variantId;
    }

    testWidgets('omits the lure row when no lure is assigned', (tester) async {
      await _openDetails(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );

      expect(find.text('Viehe'), findsNothing);
    });

    testWidgets('displays the assigned lure details when present', (
      tester,
    ) async {
      final variantId = await seedOwnedLure(database);
      final catchWithLure = await catchRepository.update(
        catchModel: existingCatch,
        species: existingCatch.species,
        caughtAt: existingCatch.caughtAt,
        weightGrams: existingCatch.weightGrams,
        lengthMillimeters: existingCatch.lengthMillimeters,
        lureVariantId: variantId,
      );

      await _openDetails(
        tester,
        fishingSpot,
        catchWithLure,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );

      expect(find.text('Viehe'), findsOneWidget);
      expect(find.text('Rapala X-Rap Shad XRS08'), findsOneWidget);
    });

    testWidgets('a retired assigned variant still displays normally', (
      tester,
    ) async {
      final variantId = await seedOwnedLure(database, retired: true);
      final catchWithLure = await catchRepository.update(
        catchModel: existingCatch,
        species: existingCatch.species,
        caughtAt: existingCatch.caughtAt,
        weightGrams: existingCatch.weightGrams,
        lengthMillimeters: existingCatch.lengthMillimeters,
        lureVariantId: variantId,
      );

      await _openDetails(
        tester,
        fishingSpot,
        catchWithLure,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );

      expect(find.text('Rapala X-Rap Shad XRS08'), findsOneWidget);
    });

    testWidgets(
      'an unresolvable assigned lureVariantId shows a fallback without crashing',
      (tester) async {
        final variantId = await seedOwnedLure(database);
        final catchWithLure = await catchRepository.update(
          catchModel: existingCatch,
          species: existingCatch.species,
          caughtAt: existingCatch.caughtAt,
          weightGrams: existingCatch.weightGrams,
          lengthMillimeters: existingCatch.lengthMillimeters,
          lureVariantId: variantId,
        );

        await _openDetails(
          tester,
          fishingSpot,
          catchWithLure,
          catchRepository,
          catchPhotoRepository,
          _NullResolvingLureCatalogRepository(database),
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
          waterBodyRepository,
        );

        expect(find.text('Viehetiedot eivät ole saatavilla'), findsOneWidget);
        expect(find.byType(CatchDetailsPage), findsOneWidget);
      },
    );
  });

  group('notes', () {
    testWidgets('omits the notes section when the catch has no note', (
      tester,
    ) async {
      await _openDetails(
        tester,
        fishingSpot,
        existingCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );

      expect(find.text('Muistiinpanot'), findsNothing);
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('displays the note in full when present', (tester) async {
      final catchWithNotes = await catchRepository.update(
        catchModel: existingCatch,
        species: existingCatch.species,
        caughtAt: existingCatch.caughtAt,
        weightGrams: existingCatch.weightGrams,
        lengthMillimeters: existingCatch.lengthMillimeters,
        notes: 'Tuulinen ilta, hauki iski laineeseen.',
      );

      await _openDetails(
        tester,
        fishingSpot,
        catchWithNotes,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );

      expect(find.text('Muistiinpanot'), findsOneWidget);
      expect(
        find.text('Tuulinen ilta, hauki iski laineeseen.'),
        findsOneWidget,
      );
    });

    testWidgets('preserves line breaks in a multi-line note', (tester) async {
      final catchWithNotes = await catchRepository.update(
        catchModel: existingCatch,
        species: existingCatch.species,
        caughtAt: existingCatch.caughtAt,
        weightGrams: existingCatch.weightGrams,
        lengthMillimeters: existingCatch.lengthMillimeters,
        notes: 'Ensimmäinen rivi.\nToinen rivi.',
      );

      await _openDetails(
        tester,
        fishingSpot,
        catchWithNotes,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );

      final notesWidget = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(notesWidget.data, 'Ensimmäinen rivi.\nToinen rivi.');
    });

    testWidgets('a long note wraps without truncation', (tester) async {
      final longNote = 'a' * 500;
      final catchWithNotes = await catchRepository.update(
        catchModel: existingCatch,
        species: existingCatch.species,
        caughtAt: existingCatch.caughtAt,
        weightGrams: existingCatch.weightGrams,
        lengthMillimeters: existingCatch.lengthMillimeters,
        notes: longNote,
      );

      await _openDetails(
        tester,
        fishingSpot,
        catchWithNotes,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );

      final notesWidget = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(notesWidget.data, longNote);
      expect(notesWidget.maxLines, isNull);
    });

    testWidgets('the note text is selectable', (tester) async {
      final catchWithNotes = await catchRepository.update(
        catchModel: existingCatch,
        species: existingCatch.species,
        caughtAt: existingCatch.caughtAt,
        weightGrams: existingCatch.weightGrams,
        lengthMillimeters: existingCatch.lengthMillimeters,
        notes: 'Valittava muistiinpano.',
      );

      await _openDetails(
        tester,
        fishingSpot,
        catchWithNotes,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );

      expect(find.byType(SelectableText), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        'Valittava muistiinpano.',
      );
    });

    testWidgets('the notes section appears after the lure row', (tester) async {
      const modelId = 'model-1';
      const variantId = 'variant-1';
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
      final catchWithLureAndNotes = await catchRepository.update(
        catchModel: existingCatch,
        species: existingCatch.species,
        caughtAt: existingCatch.caughtAt,
        weightGrams: existingCatch.weightGrams,
        lengthMillimeters: existingCatch.lengthMillimeters,
        lureVariantId: variantId,
        notes: 'Muistiinpano vieheen jälkeen.',
      );

      await _openDetails(
        tester,
        fishingSpot,
        catchWithLureAndNotes,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );

      final lureLabelY = tester.getCenter(find.text('Viehe')).dy;
      final notesLabelY = tester.getCenter(find.text('Muistiinpanot')).dy;

      expect(lureLabelY, lessThan(notesLabelY));
    });

    testWidgets('existing rows remain unaffected when a note is present', (
      tester,
    ) async {
      final catchWithNotes = await catchRepository.update(
        catchModel: existingCatch,
        species: existingCatch.species,
        caughtAt: existingCatch.caughtAt,
        weightGrams: existingCatch.weightGrams,
        lengthMillimeters: existingCatch.lengthMillimeters,
        notes: 'Sivuvaikutuksia ei pitäisi olla.',
      );

      await _openDetails(
        tester,
        fishingSpot,
        catchWithNotes,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );

      expect(find.text('Hauki'), findsWidgets);
      expect(find.text('3.2 kg'), findsOneWidget);
      expect(find.text('78 cm'), findsOneWidget);
      expect(find.text('14.7.2026'), findsOneWidget);
      expect(find.text('18.34'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets(
      'Paino and Pituus render side by side in the same row',
      (tester) async {
        await _openDetails(
          tester,
          fishingSpot,
          existingCatch,
          catchRepository,
          catchPhotoRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
          waterBodyRepository,
        );

        final weightCenter = tester.getCenter(find.text('Paino'));
        final lengthCenter = tester.getCenter(find.text('Pituus'));

        expect(lengthCenter.dy, weightCenter.dy);
        expect(weightCenter.dx, lessThan(lengthCenter.dx));
      },
    );

    testWidgets(
      'Päivämäärä and Kellonaika render side by side in the same row, '
      'below Paino/Pituus',
      (tester) async {
        await _openDetails(
          tester,
          fishingSpot,
          existingCatch,
          catchRepository,
          catchPhotoRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
          waterBodyRepository,
        );

        final weightCenter = tester.getCenter(find.text('Paino'));
        final dateCenter = tester.getCenter(find.text('Päivämäärä'));
        final timeCenter = tester.getCenter(find.text('Kellonaika'));

        expect(timeCenter.dy, dateCenter.dy);
        expect(dateCenter.dx, lessThan(timeCenter.dx));
        expect(dateCenter.dy, greaterThan(weightCenter.dy));
      },
    );

    testWidgets('omits the Paino/Pituus row entirely when neither is set', (
      tester,
    ) async {
      final bareCatch = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 10, 21, 10),
      );

      await _openDetails(
        tester,
        fishingSpot,
        bareCatch,
        catchRepository,
        catchPhotoRepository,
        lureCatalogRepository,
        personalTackleBoxRepository,
        personalTackleBoxPhotoStorage,
        waterBodyRepository,
      );

      expect(find.text('Paino'), findsNothing);
      expect(find.text('Pituus'), findsNothing);
    });

    testWidgets(
      'a single set field (e.g. only Paino) still renders correctly when '
      'its row partner is absent',
      (tester) async {
        final weightOnlyCatch = await catchRepository.create(
          fishingSpotId: fishingSpot.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 7, 17),
          weightGrams: 1500,
        );

        await _openDetails(
          tester,
          fishingSpot,
          weightOnlyCatch,
          catchRepository,
          catchPhotoRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
          waterBodyRepository,
        );

        expect(find.text('Paino'), findsOneWidget);
        expect(find.text('1.5 kg'), findsOneWidget);
        expect(find.text('Pituus'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a narrow screen with long water body/fishing spot names renders '
      'without overflowing',
      (tester) async {
        await (database.update(
          database.waterBodies,
        )..where((t) => t.id.equals('water-body-1'))).write(
          const WaterBodiesCompanion(
            name: Value(
              'Erittäin pitkä vesistön nimi joka ei todellakaan mahdu',
            ),
          ),
        );
        final longNameSpotRepository = FishingSpotRepository(database);
        final longNameSpot = await longNameSpotRepository.create(
          name: 'Todella pitkä kalastuspaikan nimi joka ei mahdu riviin',
          latitude: 61.0,
          longitude: 25.0,
          waterBodyId: 'water-body-1',
        );
        final longNameCatch = await catchRepository.create(
          fishingSpotId: longNameSpot.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 7, 17),
          weightGrams: 3200,
          lengthMillimeters: 780,
        );

        // _openDetails itself sets a tall 800x1400 viewport (needed for
        // Edit Catch's own tests), so the narrow width is applied only
        // after Catch Details is already open and pumped.
        await _openDetails(
          tester,
          longNameSpot,
          longNameCatch,
          catchRepository,
          catchPhotoRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
          waterBodyRepository,
        );

        final originalSize = tester.view.physicalSize;
        final originalDpr = tester.view.devicePixelRatio;
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.physicalSize = originalSize;
          tester.view.devicePixelRatio = originalDpr;
        });
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('location', () {
    testWidgets(
      'shows the Vesistö and Kalastuspaikka fields side by side, positioned '
      'near the date/time fields',
      (tester) async {
        await _openDetails(
          tester,
          fishingSpot,
          existingCatch,
          catchRepository,
          catchPhotoRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
          waterBodyRepository,
        );

        final timeLabelY = tester.getCenter(find.text('Kellonaika')).dy;
        final waterBodyCenter = tester.getCenter(find.text('Vesistö'));
        final fishingSpotCenter = tester.getCenter(find.text('Kalastuspaikka'));

        expect(waterBodyCenter.dy, greaterThan(timeLabelY));
        // Same row: equal vertical center, Vesistö in the left column and
        // Kalastuspaikka in the right.
        expect(fishingSpotCenter.dy, waterBodyCenter.dy);
        expect(waterBodyCenter.dx, lessThan(fishingSpotCenter.dx));
      },
    );

    testWidgets(
      'shows a fallback without crashing when the water body cannot be '
      'resolved',
      (tester) async {
        await _openDetails(
          tester,
          fishingSpot,
          existingCatch,
          catchRepository,
          catchPhotoRepository,
          lureCatalogRepository,
          personalTackleBoxRepository,
          personalTackleBoxPhotoStorage,
          _NullResolvingWaterBodyRepository(database),
        );

        expect(find.text('Vesistöä ei löytynyt'), findsOneWidget);
        // The fishing spot name is always known synchronously from the
        // page's own input — it is never affected by the water body
        // resolution failing.
        expect(find.text('Merrasjärvi'), findsOneWidget);
        expect(find.byType(CatchDetailsPage), findsOneWidget);
      },
    );
  });
}
