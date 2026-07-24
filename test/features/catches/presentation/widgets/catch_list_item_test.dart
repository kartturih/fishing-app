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
import 'package:fishing_app/features/catches/presentation/widgets/catch_list_item.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

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

Future<void> _pumpItem(
  WidgetTester tester,
  Catch catchModel,
  CatchPhotoRepository catchPhotoRepository, {
  VoidCallback? onTap,
  String? waterBodyName,
  String? fishingSpotName,
  String? lureLabel,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CatchListItem(
          catchModel: catchModel,
          catchPhotoRepository: catchPhotoRepository,
          onTap: onTap ?? () {},
          waterBodyName: waterBodyName,
          fishingSpotName: fishingSpotName,
          lureLabel: lureLabel,
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
  late FishingSpot fishingSpot;
  late Catch existingCatch;

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
    storageDir = Directory.systemTemp.createTempSync('catch_list_item_storage');
    sourceDir = Directory.systemTemp.createTempSync('catch_list_item_source');
    catchPhotoRepository = CatchPhotoRepository(
      database,
      CatchPhotoStorage(rootDirectoryProvider: () async => storageDir),
    );
    final fishingSpotRepository = FishingSpotRepository(database);
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
    await _pumpItem(tester, existingCatch, catchPhotoRepository);
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

    await _pumpItem(tester, existingCatch, catchPhotoRepository);
    await _pumpUntilSettledWithRealIO(tester);

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.set_meal), findsNothing);
  });

  testWidgets('tapping the row invokes onTap', (tester) async {
    var tapped = false;
    await _pumpItem(
      tester,
      existingCatch,
      catchPhotoRepository,
      onTap: () => tapped = true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  // MFS-025 / TD-025: additive water body / fishing spot / lure lines, used
  // only by the global catch-browsing/search surface.

  testWidgets('renders no location or lure line when none of the three new '
      'parameters are supplied (every pre-existing call site)', (tester) async {
    await _pumpItem(tester, existingCatch, catchPhotoRepository);
    await tester.pumpAndSettle();

    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets(
    'renders a combined "water body / fishing spot" line when both are '
    'supplied',
    (tester) async {
      await _pumpItem(
        tester,
        existingCatch,
        catchPhotoRepository,
        waterBodyName: 'Merrasjärvi',
        fishingSpotName: 'Koiraranta',
      );
      await tester.pumpAndSettle();

      expect(find.text('Merrasjärvi / Koiraranta'), findsOneWidget);
    },
  );

  testWidgets(
    'renders only the water body name when the fishing spot name is absent',
    (tester) async {
      await _pumpItem(
        tester,
        existingCatch,
        catchPhotoRepository,
        waterBodyName: 'Merrasjärvi',
      );
      await tester.pumpAndSettle();

      expect(find.text('Merrasjärvi'), findsOneWidget);
    },
  );

  testWidgets(
    'renders only the fishing spot name when the water body name is absent',
    (tester) async {
      await _pumpItem(
        tester,
        existingCatch,
        catchPhotoRepository,
        fishingSpotName: 'Koiraranta',
      );
      await tester.pumpAndSettle();

      expect(find.text('Koiraranta'), findsOneWidget);
    },
  );

  testWidgets('renders the lure label when supplied', (tester) async {
    await _pumpItem(
      tester,
      existingCatch,
      catchPhotoRepository,
      lureLabel: 'Rapala X-Rap Shad',
    );
    await tester.pumpAndSettle();

    expect(find.text('Rapala X-Rap Shad'), findsOneWidget);
  });

  testWidgets('renders no lure line when lureLabel is not supplied', (
    tester,
  ) async {
    await _pumpItem(tester, existingCatch, catchPhotoRepository);
    await tester.pumpAndSettle();

    expect(find.textContaining('Rapala'), findsNothing);
  });
}
