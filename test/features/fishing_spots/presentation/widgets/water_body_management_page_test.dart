import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_repository.dart';
import 'package:fishing_app/features/fishing_spots/presentation/widgets/water_body_management_page.dart';

Future<void> _pumpPage(
  WidgetTester tester,
  WaterBodyRepository waterBodyRepository,
  FishingSpotRepository fishingSpotRepository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WaterBodyManagementPage(
        waterBodyRepository: waterBodyRepository,
        fishingSpotRepository: fishingSpotRepository,
      ),
    ),
  );
  await tester.pumpAndSettle();
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
    await _pumpPage(tester, waterBodyRepository, fishingSpotRepository);
    expect(find.text('Ei vielä vesistöjä.'), findsOneWidget);
  });

  testWidgets('lists every water body with its correct fishing-spot count', (
    tester,
  ) async {
    final waterBody = await waterBodyRepository.create(name: 'Merrasjärvi');
    await fishingSpotRepository.create(
      name: 'Koiraranta',
      latitude: 61.0,
      longitude: 25.0,
      waterBodyId: waterBody.id,
    );
    await waterBodyRepository.create(name: 'Tyhjäjärvi');

    await _pumpPage(tester, waterBodyRepository, fishingSpotRepository);

    expect(find.text('Merrasjärvi'), findsOneWidget);
    expect(find.text('1 kalastuspaikkaa'), findsOneWidget);
    expect(find.text('Tyhjäjärvi'), findsOneWidget);
    expect(find.text('0 kalastuspaikkaa'), findsOneWidget);
  });

  testWidgets('renaming a water body persists and reloads the list', (
    tester,
  ) async {
    final waterBody = await waterBodyRepository.create(name: 'Old Name');
    await _pumpPage(tester, waterBodyRepository, fishingSpotRepository);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'New Name');
    await tester.tap(find.text('Tallenna'));
    await tester.pumpAndSettle();

    expect(find.text('New Name'), findsOneWidget);
    expect(find.text('Old Name'), findsNothing);
    final reloaded = await waterBodyRepository.getById(waterBody.id);
    expect(reloaded?.name, 'New Name');
  });

  testWidgets(
    'attempting to delete a non-empty water body shows the explanatory '
    'dialog and performs no deletion',
    (tester) async {
      final waterBody = await waterBodyRepository.create(name: 'Merrasjärvi');
      await fishingSpotRepository.create(
        name: 'Koiraranta',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: waterBody.id,
      );

      await _pumpPage(tester, waterBodyRepository, fishingSpotRepository);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Vesistöä ei voi poistaa'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(await waterBodyRepository.getById(waterBody.id), isNotNull);
    },
  );

  testWidgets(
    'deleting an empty water body requires confirmation and then succeeds',
    (tester) async {
      final waterBody = await waterBodyRepository.create(name: 'Tyhjäjärvi');

      await _pumpPage(tester, waterBodyRepository, fishingSpotRepository);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Poistetaanko vesistö?'), findsOneWidget);

      await tester.tap(find.text('Poista'));
      await tester.pumpAndSettle();

      expect(await waterBodyRepository.getById(waterBody.id), isNull);
      expect(find.text('Ei vielä vesistöjä.'), findsOneWidget);
    },
  );

  testWidgets('expanding a water body row shows its member fishing spots', (
    tester,
  ) async {
    final waterBody = await waterBodyRepository.create(name: 'Merrasjärvi');
    await fishingSpotRepository.create(
      name: 'Koiraranta',
      latitude: 61.0,
      longitude: 25.0,
      waterBodyId: waterBody.id,
    );

    await _pumpPage(tester, waterBodyRepository, fishingSpotRepository);

    await tester.tap(find.text('Merrasjärvi'));
    await tester.pumpAndSettle();

    expect(find.text('Koiraranta'), findsOneWidget);
  });
}
