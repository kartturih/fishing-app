import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/data/storage/catch_photo_storage.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/statistics/data/general_catch_statistics_repository.dart';
import 'package:fishing_app/features/statistics/data/lure_statistics_repository.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/statistics_page.dart';

void main() {
  late AppDatabase database;
  late Directory tempDir;
  late GeneralCatchStatisticsRepository generalCatchStatisticsRepository;
  late LureStatisticsRepository lureStatisticsRepository;
  late CatchRepository catchRepository;
  late CatchPhotoRepository catchPhotoRepository;
  late LureCatalogRepository lureCatalogRepository;
  late PersonalTackleBoxRepository personalTackleBoxRepository;
  late TackleBoxPhotoStorage tackleBoxPhotoStorage;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync('statistics_page');
    generalCatchStatisticsRepository = GeneralCatchStatisticsRepository(
      database,
    );
    lureStatisticsRepository = LureStatisticsRepository(database);
    catchRepository = CatchRepository(database);
    catchPhotoRepository = CatchPhotoRepository(
      database,
      CatchPhotoStorage(rootDirectoryProvider: () async => tempDir),
    );
    lureCatalogRepository = LureCatalogRepository(database);
    tackleBoxPhotoStorage = TackleBoxPhotoStorage(
      rootDirectoryProvider: () async => tempDir,
    );
    personalTackleBoxRepository = PersonalTackleBoxRepository(
      database,
      tackleBoxPhotoStorage,
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpPage(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: StatisticsPage(
          generalCatchStatisticsRepository: generalCatchStatisticsRepository,
          lureStatisticsRepository: lureStatisticsRepository,
          catchRepository: catchRepository,
          catchPhotoRepository: catchPhotoRepository,
          lureCatalogRepository: lureCatalogRepository,
          personalTackleBoxRepository: personalTackleBoxRepository,
          personalTackleBoxPhotoStorage: tackleBoxPhotoStorage,
        ),
      ),
    );
  }

  testWidgets('shows the app bar title and both tabs, in order', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Tilastot'), findsOneWidget);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    final tabTexts = [for (final tab in tabBar.tabs) (tab as Tab).text];
    expect(tabTexts, ['Saalistilastot', 'Viehetilastot']);
  });

  testWidgets('opens to the Catches tab by default', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    // The Catches tab's own empty state, not Lure Statistics'.
    expect(find.text('Yksikään saalis ei ole vielä punnittu.'), findsOneWidget);
    expect(
      find.text('Yksikään viehe ei ole vielä tuottanut saalista.'),
      findsNothing,
    );
  });

  testWidgets('switching to the Lure Statistics tab shows its content', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Viehetilastot'));
    await tester.pumpAndSettle();

    expect(
      find.text('Yksikään viehe ei ole vielä tuottanut saalista.'),
      findsOneWidget,
    );
  });
}
