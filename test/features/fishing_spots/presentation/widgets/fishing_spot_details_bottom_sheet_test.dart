import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/fishing_spots/presentation/widgets/fishing_spot_details_bottom_sheet.dart';

// Uses a manually-controlled Completer (instead of a real Timer/Future.delayed)
// so the test can deterministically observe the loading state and then
// resolve it, without depending on real wall-clock time inside pumpAndSettle.
class _PendingCatchRepository extends CatchRepository {
  _PendingCatchRepository(super.database);

  final Completer<List<Catch>> pendingResult = Completer<List<Catch>>();

  @override
  Future<List<Catch>> getByFishingSpotId(String fishingSpotId) {
    return pendingResult.future;
  }
}

Future<void> _openSheet(
  WidgetTester tester,
  FishingSpot fishingSpot,
  CatchRepository catchRepository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              FishingSpotDetailsBottomSheet.show(
                context,
                fishingSpot,
                catchRepository,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
}

void main() {
  late AppDatabase database;
  late CatchRepository catchRepository;
  late FishingSpotRepository fishingSpotRepository;
  late FishingSpot fishingSpot;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    catchRepository = CatchRepository(database);
    fishingSpotRepository = FishingSpotRepository(database);
    fishingSpot = await fishingSpotRepository.create(
      name: 'Merrasjärvi',
      latitude: 61.0,
      longitude: 25.0,
    );
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('shows a loading indicator while catches are loading', (
    tester,
  ) async {
    final pendingRepository = _PendingCatchRepository(database);

    await _openSheet(tester, fishingSpot, pendingRepository);

    expect(find.text('Ladataan...'), findsOneWidget);

    pendingRepository.pendingResult.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('Ei vielä saaliita.'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no catches', (
    tester,
  ) async {
    await _openSheet(tester, fishingSpot, catchRepository);
    await tester.pumpAndSettle();

    expect(find.text('Ei vielä saaliita.'), findsOneWidget);
  });

  testWidgets('shows an error message when loading fails', (tester) async {
    await database.close();

    await _openSheet(tester, fishingSpot, catchRepository);
    await tester.pumpAndSettle();

    expect(find.text('Saaliiden lataaminen epäonnistui.'), findsOneWidget);
    expect(find.text('Merrasjärvi'), findsOneWidget);
    expect(find.text('Muokkaa nimeä'), findsOneWidget);
    expect(find.text('Poista'), findsOneWidget);
  });

  testWidgets('shows one catch with species, measurements, and date', (
    tester,
  ) async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 14, 18, 34),
      weightGrams: 3200,
      lengthMillimeters: 780,
    );

    await _openSheet(tester, fishingSpot, catchRepository);
    await tester.pumpAndSettle();

    expect(find.text('Hauki'), findsOneWidget);
    expect(find.text('3.2 kg • 78 cm'), findsOneWidget);
    expect(find.text('14.7.2026 18.34'), findsOneWidget);
  });

  testWidgets('shows multiple catches in the order the repository returns', (
    tester,
  ) async {
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 14, 18, 34),
    );
    // A real (not fake-clock) delay so the two generated identifiers
    // (derived from DateTime.now()) don't land on the same clock tick.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.perch,
      caughtAt: DateTime(2026, 7, 10, 21, 10),
    );

    final expectedOrder = await catchRepository.getByFishingSpotId(
      fishingSpot.id,
    );

    await _openSheet(tester, fishingSpot, catchRepository);
    await tester.pumpAndSettle();

    final renderedText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .toList();

    final firstIndex = renderedText.indexOf(
      expectedOrder[0].species.finnishName,
    );
    final secondIndex = renderedText.indexOf(
      expectedOrder[1].species.finnishName,
    );

    expect(firstIndex, greaterThanOrEqualTo(0));
    expect(secondIndex, greaterThan(firstIndex));
  });

  group('measurement formatting', () {
    Future<void> createAndShow(
      WidgetTester tester, {
      int? weightGrams,
      int? lengthMillimeters,
    }) async {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 10, 21, 10),
        weightGrams: weightGrams,
        lengthMillimeters: lengthMillimeters,
      );

      await _openSheet(tester, fishingSpot, catchRepository);
      await tester.pumpAndSettle();
    }

    testWidgets('formats weight below 1000 g in grams', (tester) async {
      await createAndShow(tester, weightGrams: 320);
      expect(find.text('320 g'), findsOneWidget);
    });

    testWidgets('formats 1000 g as 1 kg with no trailing zeros', (
      tester,
    ) async {
      await createAndShow(tester, weightGrams: 1000);
      expect(find.text('1 kg'), findsOneWidget);
    });

    testWidgets('formats 1200 g as 1.2 kg', (tester) async {
      await createAndShow(tester, weightGrams: 1200);
      expect(find.text('1.2 kg'), findsOneWidget);
    });

    testWidgets('formats 2450 g as 2.45 kg', (tester) async {
      await createAndShow(tester, weightGrams: 2450);
      expect(find.text('2.45 kg'), findsOneWidget);
    });

    testWidgets('formats 8000 g as 8 kg', (tester) async {
      await createAndShow(tester, weightGrams: 8000);
      expect(find.text('8 kg'), findsOneWidget);
    });

    testWidgets('formats 680 mm as 68 cm', (tester) async {
      await createAndShow(tester, lengthMillimeters: 680);
      expect(find.text('68 cm'), findsOneWidget);
    });

    testWidgets('formats 685 mm as 68.5 cm', (tester) async {
      await createAndShow(tester, lengthMillimeters: 685);
      expect(find.text('68.5 cm'), findsOneWidget);
    });

    testWidgets('formats 700 mm as 70 cm', (tester) async {
      await createAndShow(tester, lengthMillimeters: 700);
      expect(find.text('70 cm'), findsOneWidget);
    });
  });

  group('missing measurements', () {
    testWidgets('shows weight and length joined by a bullet', (tester) async {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 14, 18, 34),
        weightGrams: 3200,
        lengthMillimeters: 780,
      );

      await _openSheet(tester, fishingSpot, catchRepository);
      await tester.pumpAndSettle();

      expect(find.text('3.2 kg • 78 cm'), findsOneWidget);
      expect(find.textContaining('•'), findsOneWidget);
    });

    testWidgets('shows only weight when length is missing', (tester) async {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 14, 18, 34),
        weightGrams: 3200,
      );

      await _openSheet(tester, fishingSpot, catchRepository);
      await tester.pumpAndSettle();

      expect(find.text('3.2 kg'), findsOneWidget);
      expect(find.textContaining('•'), findsNothing);
    });

    testWidgets('shows only length when weight is missing', (tester) async {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 7, 8, 7, 55),
        lengthMillimeters: 680,
      );

      await _openSheet(tester, fishingSpot, catchRepository);
      await tester.pumpAndSettle();

      expect(find.text('68 cm'), findsOneWidget);
      expect(find.textContaining('•'), findsNothing);
    });

    testWidgets('omits the measurement line entirely when both are missing', (
      tester,
    ) async {
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 7, 8, 7, 55),
      );

      await _openSheet(tester, fishingSpot, catchRepository);
      await tester.pumpAndSettle();

      expect(find.text('Kuha'), findsOneWidget);
      expect(find.textContaining('•'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
    });
  });

  testWidgets('tapping a catch requests editing that catch', (tester) async {
    final createdCatch = await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.zander,
      caughtAt: DateTime(2026, 7, 8, 7, 55),
      lengthMillimeters: 680,
    );

    FishingSpotDetailsResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await FishingSpotDetailsBottomSheet.show(
                  context,
                  fishingSpot,
                  catchRepository,
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

    await tester.tap(find.text('Kuha'));
    await tester.pumpAndSettle();

    expect(result, isA<FishingSpotEditCatchRequested>());
    expect(
      (result! as FishingSpotEditCatchRequested).catchModel.id,
      createdCatch.id,
    );
  });
}
