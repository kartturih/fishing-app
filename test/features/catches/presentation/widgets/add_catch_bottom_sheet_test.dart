import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/data/storage/catch_photo_storage.dart';
import 'package:fishing_app/features/catch_photos/domain/catch_photo_limits.dart';
import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_viewer.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/widgets/add_catch_bottom_sheet.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

import '../../../../support/fake_image_picker_platform.dart';
import '../../../../support/test_image_files.dart';

class _FailingCreateCatchRepository extends CatchRepository {
  _FailingCreateCatchRepository(super.database);

  int createCallCount = 0;

  @override
  Future<Catch> create({
    required String fishingSpotId,
    required FishSpecies species,
    required DateTime caughtAt,
    int? weightGrams,
    int? lengthMillimeters,
  }) async {
    createCallCount++;
    throw StateError('simulated create failure');
  }
}

class _AddCatchHarness {
  AddCatchResult? result;

  Future<void> open(
    WidgetTester tester,
    FishingSpot fishingSpot,
    CatchRepository catchRepository,
    CatchPhotoRepository catchPhotoRepository,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await AddCatchBottomSheet.show(
                  context,
                  fishingSpot,
                  catchRepository,
                  catchPhotoRepository,
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

Future<void> _addCameraPhoto(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('catchPhotoAddButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('catchPhotoSourceCamera')));
  await tester.pumpAndSettle();
}

void main() {
  group('parseCatchMeasurementInput', () {
    test('parses a period decimal separator', () {
      expect(parseCatchMeasurementInput('2.45'), 2.45);
    });

    test('parses a comma decimal separator', () {
      expect(parseCatchMeasurementInput('2,45'), 2.45);
    });

    test('parses a whole number', () {
      expect(parseCatchMeasurementInput('68'), 68.0);
    });

    test('trims surrounding whitespace', () {
      expect(parseCatchMeasurementInput('  68.5  '), 68.5);
    });

    test('returns null for empty input', () {
      expect(parseCatchMeasurementInput(''), isNull);
    });

    test('returns null for invalid text', () {
      expect(parseCatchMeasurementInput('abc'), isNull);
    });

    test('parses Infinity as a non-finite double', () {
      expect(parseCatchMeasurementInput('Infinity'), double.infinity);
    });

    test('parses NaN as a non-finite double', () {
      expect(parseCatchMeasurementInput('NaN')!.isNaN, isTrue);
    });
  });

  group('kilogramsToGrams', () {
    test('converts 2.45 kg to 2450 g', () {
      expect(kilogramsToGrams(2.45), 2450);
    });

    test('converts 0.85 kg to 850 g', () {
      expect(kilogramsToGrams(0.85), 850);
    });

    test('converts 10 kg to 10000 g', () {
      expect(kilogramsToGrams(10), 10000);
    });

    test('rounds extra precision', () {
      expect(kilogramsToGrams(1.2345), 1235);
    });
  });

  group('centimetersToMillimeters', () {
    test('converts 24 cm to 240 mm', () {
      expect(centimetersToMillimeters(24), 240);
    });

    test('converts 68.5 cm to 685 mm', () {
      expect(centimetersToMillimeters(68.5), 685);
    });

    test('converts 102 cm to 1020 mm', () {
      expect(centimetersToMillimeters(102), 1020);
    });

    test('rounds extra precision', () {
      expect(centimetersToMillimeters(68.56), 686);
    });
  });

  group('validateCatchWeightInput', () {
    test('empty value is valid (becomes null)', () {
      expect(validateCatchWeightInput(''), isNull);
      expect(validateCatchWeightInput(null), isNull);
    });

    test('accepts a valid period-separated value', () {
      expect(validateCatchWeightInput('2.45'), isNull);
    });

    test('accepts a valid comma-separated value', () {
      expect(validateCatchWeightInput('2,45'), isNull);
    });

    test('rejects invalid text', () {
      expect(validateCatchWeightInput('abc'), 'Syötä kelvollinen paino');
    });

    test('rejects zero', () {
      expect(
        validateCatchWeightInput('0'),
        'Painon täytyy olla suurempi kuin 0',
      );
    });

    test('rejects negative values', () {
      expect(
        validateCatchWeightInput('-1'),
        'Painon täytyy olla suurempi kuin 0',
      );
    });

    test('rejects Infinity', () {
      expect(validateCatchWeightInput('Infinity'), 'Syötä kelvollinen paino');
    });

    test('rejects -Infinity', () {
      expect(validateCatchWeightInput('-Infinity'), 'Syötä kelvollinen paino');
    });

    test('rejects NaN', () {
      expect(validateCatchWeightInput('NaN'), 'Syötä kelvollinen paino');
    });
  });

  group('validateCatchLengthInput', () {
    test('empty value is valid (becomes null)', () {
      expect(validateCatchLengthInput(''), isNull);
      expect(validateCatchLengthInput(null), isNull);
    });

    test('accepts a valid period-separated value', () {
      expect(validateCatchLengthInput('68.5'), isNull);
    });

    test('accepts a valid comma-separated value', () {
      expect(validateCatchLengthInput('68,5'), isNull);
    });

    test('rejects invalid text', () {
      expect(validateCatchLengthInput('abc'), 'Syötä kelvollinen pituus');
    });

    test('rejects zero', () {
      expect(
        validateCatchLengthInput('0'),
        'Pituuden täytyy olla suurempi kuin 0',
      );
    });

    test('rejects negative values', () {
      expect(
        validateCatchLengthInput('-1'),
        'Pituuden täytyy olla suurempi kuin 0',
      );
    });

    test('rejects non-finite values', () {
      expect(validateCatchLengthInput('Infinity'), 'Syötä kelvollinen pituus');
      expect(validateCatchLengthInput('NaN'), 'Syötä kelvollinen pituus');
    });
  });

  group('formatCatchDate', () {
    test('formats day.month.year without leading zeros', () {
      expect(formatCatchDate(DateTime(2026, 7, 14)), '14.7.2026');
    });
  });

  group('formatCatchTime', () {
    test('formats hour.minute with leading zeros', () {
      expect(formatCatchTime(DateTime(2026, 7, 14, 8, 5)), '08.05');
    });

    test('formats a two-digit hour and minute unchanged', () {
      expect(formatCatchTime(DateTime(2026, 7, 14, 18, 34)), '18.34');
    });
  });

  group('photos', () {
    late AppDatabase database;
    late CatchRepository catchRepository;
    late CatchPhotoRepository catchPhotoRepository;
    late FishingSpotRepository fishingSpotRepository;
    late FishingSpot fishingSpot;
    late Directory storageDir;
    late Directory sourceDir;
    late FakeImagePickerPlatform fakePicker;
    late ImagePickerPlatform originalPicker;

    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      catchRepository = CatchRepository(database);
      storageDir = Directory.systemTemp.createTempSync(
        'add_catch_photos_storage',
      );
      sourceDir = Directory.systemTemp.createTempSync(
        'add_catch_photos_source',
      );
      catchPhotoRepository = CatchPhotoRepository(
        database,
        CatchPhotoStorage(rootDirectoryProvider: () async => storageDir),
      );
      fishingSpotRepository = FishingSpotRepository(database);
      fishingSpot = await fishingSpotRepository.create(
        name: 'Merrasjärvi',
        latitude: 61.0,
        longitude: 25.0,
      );

      originalPicker = ImagePickerPlatform.instance;
      fakePicker = FakeImagePickerPlatform();
      ImagePickerPlatform.instance = fakePicker;
    });

    tearDown(() async {
      ImagePickerPlatform.instance = originalPicker;
      await database.close();
      if (storageDir.existsSync()) {
        storageDir.deleteSync(recursive: true);
      }
      if (sourceDir.existsSync()) {
        sourceDir.deleteSync(recursive: true);
      }
    });

    testWidgets('shows no photos initially', (tester) async {
      final harness = _AddCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchRepository,
        catchPhotoRepository,
      );

      expect(find.byKey(const Key('catchPhotoAddButton')), findsOneWidget);
      expect(find.textContaining('enimmäismäärä'), findsNothing);
    });

    testWidgets('opens the photo source selection dialog', (tester) async {
      final harness = _AddCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchRepository,
        catchPhotoRepository,
      );

      await tester.tap(find.byKey(const Key('catchPhotoAddButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('catchPhotoSourceCamera')), findsOneWidget);
      expect(find.byKey(const Key('catchPhotoSourceGallery')), findsOneWidget);
      expect(find.byKey(const Key('catchPhotoSourceCancel')), findsOneWidget);
    });

    testWidgets('adds a photo selected from the camera', (tester) async {
      fakePicker.nextCameraImage = writeTestXFile(sourceDir, 'camera.jpg');

      final harness = _AddCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchRepository,
        catchPhotoRepository,
      );

      await _addCameraPhoto(tester);

      expect(fakePicker.cameraCallCount, 1);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('adds multiple photos selected from the gallery', (
      tester,
    ) async {
      fakePicker.nextGalleryImages = [
        writeTestXFile(sourceDir, 'a.jpg'),
        writeTestXFile(sourceDir, 'b.jpg'),
      ];

      final harness = _AddCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchRepository,
        catchPhotoRepository,
      );

      await tester.tap(find.byKey(const Key('catchPhotoAddButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catchPhotoSourceGallery')));
      await tester.pumpAndSettle();

      expect(fakePicker.galleryCallCount, 1);
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('picker cancellation makes no changes', (tester) async {
      fakePicker.nextCameraImage = null;

      final harness = _AddCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchRepository,
        catchPhotoRepository,
      );

      await _addCameraPhoto(tester);

      expect(find.byType(Image), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('permission denial shows a message and preserves the form', (
      tester,
    ) async {
      fakePicker.cameraError = PlatformException(code: 'camera_access_denied');

      final harness = _AddCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchRepository,
        catchPhotoRepository,
      );

      await _addCameraPhoto(tester);

      expect(
        find.text('Kameran tai kuvien käyttöoikeus puuttuu.'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('removes a pending photo without confirmation', (tester) async {
      fakePicker.nextCameraImage = writeTestXFile(sourceDir, 'camera.jpg');

      final harness = _AddCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchRepository,
        catchPhotoRepository,
      );

      await _addCameraPhoto(tester);
      expect(find.byType(Image), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('opens the full-screen viewer for a pending photo', (
      tester,
    ) async {
      fakePicker.nextCameraImage = writeTestXFile(sourceDir, 'camera.jpg');

      final harness = _AddCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchRepository,
        catchPhotoRepository,
      );

      await _addCameraPhoto(tester);
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      expect(find.byType(CatchPhotoViewer), findsOneWidget);

      await tester.tap(find.byKey(const Key('catchPhotoViewerCloseButton')));
      await tester.pumpAndSettle();

      expect(find.byType(CatchPhotoViewer), findsNothing);
    });

    testWidgets('hides the add tile once the maximum is reached', (
      tester,
    ) async {
      fakePicker.nextGalleryImages = [
        for (var i = 0; i < maxCatchPhotos; i++)
          writeTestXFile(sourceDir, '$i.jpg'),
      ];

      final harness = _AddCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchRepository,
        catchPhotoRepository,
      );

      await tester.tap(find.byKey(const Key('catchPhotoAddButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catchPhotoSourceGallery')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('catchPhotoAddButton')), findsNothing);
      expect(find.textContaining('enimmäismäärä (5)'), findsOneWidget);
    });

    testWidgets('prevents a duplicate picker invocation', (tester) async {
      fakePicker.gate = Completer<void>();
      fakePicker.nextCameraImage = writeTestXFile(sourceDir, 'camera.jpg');

      final harness = _AddCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchRepository,
        catchPhotoRepository,
      );

      await tester.tap(find.byKey(const Key('catchPhotoAddButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catchPhotoSourceCamera')));
      await tester.pump();

      // The add tile is disabled while a pick is already in flight, so a
      // second tap must not start a second picker invocation.
      await tester.tap(
        find.byKey(const Key('catchPhotoAddButton')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(fakePicker.cameraCallCount, 1);

      fakePicker.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('validation failure preserves the pending photo', (
      tester,
    ) async {
      fakePicker.nextCameraImage = writeTestXFile(sourceDir, 'camera.jpg');

      final harness = _AddCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchRepository,
        catchPhotoRepository,
      );

      await _addCameraPhoto(tester);
      // No species selected, so validation fails and the save is rejected
      // before Catch or photo repositories are ever called.
      await tester.tap(find.text('Tallenna'));
      await tester.pumpAndSettle();

      expect(harness.result, isNull);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('Catch save failure preserves the pending photo', (
      tester,
    ) async {
      final failingRepository = _FailingCreateCatchRepository(database);
      fakePicker.nextCameraImage = writeTestXFile(sourceDir, 'camera.jpg');

      final harness = _AddCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        failingRepository,
        catchPhotoRepository,
      );

      await _addCameraPhoto(tester);
      await _selectSpecies(tester, FishSpecies.pike);
      await tester.tap(find.text('Tallenna'));
      await tester.pumpAndSettle();

      expect(harness.result, isNull);
      expect(
        find.text('Saaliin tallentaminen epäonnistui. Yritä uudelleen.'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsOneWidget);
      expect(failingRepository.createCallCount, 1);
    });

    testWidgets(
      'Catch save success with no photos returns zero photo failures',
      (tester) async {
        final harness = _AddCatchHarness();
        await harness.open(
          tester,
          fishingSpot,
          catchRepository,
          catchPhotoRepository,
        );

        await _selectSpecies(tester, FishSpecies.pike);
        await tester.tap(find.text('Tallenna'));
        await tester.pumpAndSettle();

        final result = harness.result;
        expect(result, isA<CatchCreated>());
        expect((result! as CatchCreated).photoFailureCount, 0);
      },
    );

    testWidgets('Catch save success reports a partial photo failure count', (
      tester,
    ) async {
      fakePicker.nextGalleryImages = [
        writeTestXFile(sourceDir, 'good.jpg'),
        writeCorruptXFile(sourceDir, 'corrupt.jpg'),
      ];

      final harness = _AddCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchRepository,
        catchPhotoRepository,
      );

      await tester.tap(find.byKey(const Key('catchPhotoAddButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catchPhotoSourceGallery')));
      await tester.pumpAndSettle();
      await _selectSpecies(tester, FishSpecies.pike);

      await tester.tap(find.text('Tallenna'));
      await tester.pump();
      // Each pending photo's real dart:io read/process/write chain only
      // advances one step per real-time window; loop a few short windows
      // so the whole addMany() sequence gets to completion.
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      final result = harness.result;
      expect(result, isA<CatchCreated>());
      final catchCreated = result! as CatchCreated;
      expect(catchCreated.photoFailureCount, 1);
      expect(catchCreated.hasPhotoFailures, isTrue);

      final storedPhotos = await catchPhotoRepository.getByCatchId(
        catchCreated.catchModel.id,
      );
      expect(storedPhotos, hasLength(1));
    });
  });
}
