import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/map/presentation/widgets/lure_tools_page.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';

void main() {
  late AppDatabase database;
  late Directory tempDir;
  late LureCatalogRepository lureCatalogRepository;
  late TackleBoxPhotoStorage storage;
  late PersonalTackleBoxRepository personalTackleBoxRepository;

  Future<void> pumpPage(WidgetTester tester) async {
    // Tall enough that the Lure Catalog seed list renders without
    // scrolling, mirroring lure_catalog_list_page_test.dart's pumpListPage.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: LureToolsPage(
          lureCatalogRepository: lureCatalogRepository,
          personalTackleBoxRepository: personalTackleBoxRepository,
          personalTackleBoxPhotoStorage: storage,
        ),
      ),
    );
  }

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    lureCatalogRepository = LureCatalogRepository(database);
    tempDir = Directory.systemTemp.createTempSync('lure_tools_page_test');
    storage = TackleBoxPhotoStorage(rootDirectoryProvider: () async => tempDir);
    personalTackleBoxRepository = PersonalTackleBoxRepository(
      database,
      storage,
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('shows both tab labels and exactly one AppBar', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Viehekatalogi'), findsOneWidget);
    expect(find.text('Oma vieherasia'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('opens on the Lure Catalog tab by default', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lureCatalogList')), findsOneWidget);
    expect(find.byKey(const Key('personalTackleBoxSearchField')), findsNothing);
  });

  testWidgets('switching to the Personal Tackle Box tab shows its content', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Oma vieherasia'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Et ole vielä lisännyt viehteitä'),
      findsOneWidget,
    );
  });

  testWidgets(
    'switching tabs and back preserves the Lure Catalog search text',
    (tester) async {
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('lureCatalogSearchField')),
        'Toby',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oma vieherasia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viehekatalogi'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Toby'), findsOneWidget);
    },
  );

  testWidgets(
    'switching tabs and back preserves the Lure Catalog manufacturer filter',
    (tester) async {
      // Deliberately the default (smaller) test viewport, not pumpPage's
      // oversized one: with every seed entry visible at once, "Abu Garcia"
      // also matches list rows, so find.text('Abu Garcia').last no longer
      // reliably resolves to the dropdown menu item. Mirrors the working
      // pattern in lure_catalog_list_page_test.dart's own filter test.
      await tester.pumpWidget(
        MaterialApp(
          home: LureToolsPage(
            lureCatalogRepository: lureCatalogRepository,
            personalTackleBoxRepository: personalTackleBoxRepository,
            personalTackleBoxPhotoStorage: storage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lureCatalogManufacturerFilter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abu Garcia').last);
      await tester.pumpAndSettle();
      expect(find.text('Rapala X-Rap Shad XRS08'), findsNothing);

      await tester.tap(find.text('Oma vieherasia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viehekatalogi'));
      await tester.pumpAndSettle();

      // The filter selection is still applied: Rapala stays hidden and Abu
      // Garcia entries remain visible.
      expect(find.text('Rapala X-Rap Shad XRS08'), findsNothing);
      expect(find.text('Abu Garcia Toby'), findsWidgets);
    },
  );

  testWidgets(
    'switching tabs and back preserves the Lure Catalog scroll position',
    (tester) async {
      // Deliberately the default (smaller) test viewport, unlike pumpPage's
      // oversized one — the seed catalog must actually overflow for there
      // to be a scroll position to preserve.
      await tester.pumpWidget(
        MaterialApp(
          home: LureToolsPage(
            lureCatalogRepository: lureCatalogRepository,
            personalTackleBoxRepository: personalTackleBoxRepository,
            personalTackleBoxPhotoStorage: storage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listFinder = find.byKey(const Key('lureCatalogList'));
      await tester.drag(listFinder, const Offset(0, -400));
      await tester.pump();

      final scrollableFinder = find.descendant(
        of: listFinder,
        matching: find.byType(Scrollable),
      );
      final offsetBeforeSwitch = tester
          .state<ScrollableState>(scrollableFinder)
          .position
          .pixels;
      expect(offsetBeforeSwitch, greaterThan(0));

      await tester.tap(find.text('Oma vieherasia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viehekatalogi'));
      await tester.pumpAndSettle();

      final offsetAfterSwitch = tester
          .state<ScrollableState>(scrollableFinder)
          .position
          .pixels;
      expect(offsetAfterSwitch, offsetBeforeSwitch);
    },
  );

  testWidgets('the back button pops the whole tabbed shell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LureToolsPage(
                    lureCatalogRepository: lureCatalogRepository,
                    personalTackleBoxRepository: personalTackleBoxRepository,
                    personalTackleBoxPhotoStorage: storage,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(LureToolsPage), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(LureToolsPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
