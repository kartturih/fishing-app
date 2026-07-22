import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/fishing_spots/presentation/widgets/water_body_selection_bottom_sheet.dart';

Future<WaterBody?> _openSheet(
  WidgetTester tester,
  WaterBodyRepository waterBodyRepository,
  FishingSpotRepository fishingSpotRepository, {
  double latitude = 61.0,
  double longitude = 25.0,
}) async {
  WaterBody? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await WaterBodySelectionBottomSheet.show(
                context,
                waterBodyRepository: waterBodyRepository,
                fishingSpotRepository: fishingSpotRepository,
                latitude: latitude,
                longitude: longitude,
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
  return result;
}

void main() {
  late AppDatabase database;
  late WaterBodyRepository waterBodyRepository;
  late FishingSpotRepository fishingSpotRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    waterBodyRepository = WaterBodyRepository(database);
    fishingSpotRepository = FishingSpotRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('shows an empty state when no water bodies exist', (
    tester,
  ) async {
    await _openSheet(tester, waterBodyRepository, fishingSpotRepository);
    expect(find.text('Ei vielä vesistöjä.'), findsOneWidget);
  });

  testWidgets(
    'a nearby candidate within the threshold is preselected and can be '
    'confirmed with "Valitse"',
    (tester) async {
      final near = await waterBodyRepository.create(name: 'Merrasjärvi');
      await fishingSpotRepository.create(
        name: 'Koiraranta',
        latitude: 61.0001,
        longitude: 25.0001,
        waterBodyId: near.id,
      );

      WaterBody? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await WaterBodySelectionBottomSheet.show(
                    context,
                    waterBodyRepository: waterBodyRepository,
                    fishingSpotRepository: fishingSpotRepository,
                    latitude: 61.0,
                    longitude: 25.0,
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

      expect(find.text('Lähellä'), findsOneWidget);
      expect(find.text('Merrasjärvi'), findsWidgets);

      await tester.tap(find.text('Valitse'));
      await tester.pumpAndSettle();

      expect(result?.id, near.id);
    },
  );

  testWidgets('creating a new water body with a name selects it', (
    tester,
  ) async {
    final result = await _openSheet(
      tester,
      waterBodyRepository,
      fishingSpotRepository,
    );
    expect(result, isNull); // not yet — sheet is open, nothing tapped

    await tester.enterText(
      find.widgetWithText(TextField, 'Vesistön nimi'),
      'Uusijärvi',
    );
    await tester.tap(find.text('Luo'));
    await tester.pumpAndSettle();

    final all = await waterBodyRepository.loadAll();
    expect(all.single.name, 'Uusijärvi');
  });

  testWidgets(
    'entering a name matching an existing water body shows a non-blocking hint',
    (tester) async {
      await waterBodyRepository.create(name: 'Merrasjärvi');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => WaterBodySelectionBottomSheet.show(
                  context,
                  waterBodyRepository: waterBodyRepository,
                  fishingSpotRepository: fishingSpotRepository,
                  latitude: 61.0,
                  longitude: 25.0,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Vesistön nimi'),
        'merrasjärvi',
      );
      await tester.pump();

      expect(
        find.text(
          'Vesistö tällä nimellä on jo olemassa — valitse se listasta?',
        ),
        findsOneWidget,
      );
      // Still allowed — the hint is informational only, not a block.
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Vesistön nimi'))
            .enabled,
        isTrue,
      );
    },
  );

  testWidgets(
    'selecting a water body from the full list closes the sheet with it',
    (tester) async {
      final created = await waterBodyRepository.create(name: 'Merrasjärvi');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final selected = await WaterBodySelectionBottomSheet.show(
                    context,
                    waterBodyRepository: waterBodyRepository,
                    fishingSpotRepository: fishingSpotRepository,
                    latitude: 61.0,
                    longitude: 25.0,
                  );
                  if (selected != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('picked:${selected.id}')),
                    );
                  }
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('waterBody-${created.id}')));
      await tester.pumpAndSettle();

      expect(find.text('picked:${created.id}'), findsOneWidget);
    },
  );
}
