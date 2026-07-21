import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/data/storage/catch_photo_storage.dart';
import 'package:fishing_app/features/catch_photos/domain/pending_catch_photo.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/fishing_spot_record_catch_card.dart';

import '../../../../support/test_image_files.dart';

Future<void> _pumpUntilSettledWithRealIO(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _pumpCard(
  WidgetTester tester,
  Catch catchModel,
  CatchPhotoRepository catchPhotoRepository, {
  VoidCallback? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FishingSpotRecordCatchCard(
          catchModel: catchModel,
          catchPhotoRepository: catchPhotoRepository,
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  late AppDatabase database;
  late CatchRepository catchRepository;
  late CatchPhotoRepository catchPhotoRepository;
  late Directory storageDir;
  late Directory sourceDir;
  late Catch existingCatch;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    catchRepository = CatchRepository(database);
    storageDir = Directory.systemTemp.createTempSync(
      'fishing_spot_record_catch_card_storage',
    );
    sourceDir = Directory.systemTemp.createTempSync(
      'fishing_spot_record_catch_card_source',
    );
    catchPhotoRepository = CatchPhotoRepository(
      database,
      CatchPhotoStorage(rootDirectoryProvider: () async => storageDir),
    );
    final fishingSpotRepository = FishingSpotRepository(database);
    final fishingSpot = await fishingSpotRepository.create(
      name: 'Merrasjärvi',
      latitude: 61.0,
      longitude: 25.0,
    );
    existingCatch = await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 14),
      weightGrams: 3200,
      lengthMillimeters: 680,
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
  });

  testWidgets('shows a placeholder icon when the catch has no photos', (
    tester,
  ) async {
    await _pumpCard(tester, existingCatch, catchPhotoRepository);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.set_meal), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows the first photo by sortOrder as a thumbnail', (
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

    await _pumpCard(tester, existingCatch, catchPhotoRepository);
    await _pumpUntilSettledWithRealIO(tester);

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.set_meal), findsNothing);
  });

  testWidgets('renders species, the measurement line, and the date', (
    tester,
  ) async {
    await _pumpCard(tester, existingCatch, catchPhotoRepository);
    await tester.pumpAndSettle();

    expect(find.text('Hauki'), findsOneWidget);
    expect(find.textContaining('3.2 kg'), findsOneWidget);
    expect(find.textContaining('68 cm'), findsOneWidget);
    expect(find.text('14.7.2026'), findsOneWidget);
  });

  testWidgets(
    'omits the measurement line without breaking the layout when weight '
    'and length are both absent',
    (tester) async {
      final catchWithoutMeasurements = Catch(
        id: 'catch-no-measurements',
        fishingSpotId: existingCatch.fishingSpotId,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 14),
        createdAt: DateTime(2026, 7, 14),
        updatedAt: DateTime(2026, 7, 14),
      );

      await _pumpCard(tester, catchWithoutMeasurements, catchPhotoRepository);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Ahven'), findsOneWidget);
      expect(find.text('14.7.2026'), findsOneWidget);
    },
  );

  testWidgets(
    'does not render the fishing spot name — species is shown in its place',
    (tester) async {
      await _pumpCard(tester, existingCatch, catchPhotoRepository);
      await tester.pumpAndSettle();

      expect(find.text('Merrasjärvi'), findsNothing);
      expect(find.text('Hauki'), findsOneWidget);
    },
  );

  testWidgets('tapping the card invokes onTap', (tester) async {
    var tapped = false;

    await _pumpCard(
      tester,
      existingCatch,
      catchPhotoRepository,
      onTap: () => tapped = true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fishingSpotRecordCatchCard')));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('exposes a combined semantic label with no location text', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await _pumpCard(tester, existingCatch, catchPhotoRepository);
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Hauki, 3.2 kg • 68 cm, 14.7.2026'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
