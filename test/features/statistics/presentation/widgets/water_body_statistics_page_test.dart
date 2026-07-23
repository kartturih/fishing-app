import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/data/storage/catch_photo_storage.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_details_page.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_list_item.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/statistics/data/water_body_statistics_repository.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';
import 'package:fishing_app/features/statistics/domain/water_body_catch_entry.dart';
import 'package:fishing_app/features/statistics/domain/water_body_statistics_summary.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/catch_count_row.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/statistics_summary_card.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/water_body_statistics_page.dart';

/// Pumps and lets a multi-step real dart:io/database chain (photo file
/// deletion, the catch row delete) advance to completion; the fake-async
/// test clock does not advance real I/O on its own. Mirrors the identical
/// helper in catch_details_page_test.dart / general_catch_statistics_tab_test.dart.
Future<void> _pumpUntilSettledWithRealIO(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Never completes `getWaterBodyStatistics`, so the loading state can be
/// observed deterministically.
class _PendingRepository extends WaterBodyStatisticsRepository {
  _PendingRepository(super.database);

  final Completer<WaterBodyStatisticsSummary> pending =
      Completer<WaterBodyStatisticsSummary>();

  @override
  Future<WaterBodyStatisticsSummary> getWaterBodyStatistics(
    String waterBodyId,
  ) => pending.future;
}

class _FailingRepository extends WaterBodyStatisticsRepository {
  _FailingRepository(super.database);

  @override
  Future<WaterBodyStatisticsSummary> getWaterBodyStatistics(
    String waterBodyId,
  ) async {
    throw StateError('simulated load failure');
  }
}

/// Fails on its first call, then succeeds — used to verify the retry
/// action re-runs the load.
class _FailOnceRepository extends WaterBodyStatisticsRepository {
  _FailOnceRepository(super.database, this._summary);

  final WaterBodyStatisticsSummary _summary;
  int callCount = 0;

  @override
  Future<WaterBodyStatisticsSummary> getWaterBodyStatistics(
    String waterBodyId,
  ) async {
    callCount++;
    if (callCount == 1) {
      throw StateError('simulated load failure');
    }
    return _summary;
  }
}

class _StaticRepository extends WaterBodyStatisticsRepository {
  _StaticRepository(super.database, this._summary);

  final WaterBodyStatisticsSummary _summary;

  @override
  Future<WaterBodyStatisticsSummary> getWaterBodyStatistics(
    String waterBodyId,
  ) async => _summary;
}

/// Resolves normally on its first call, then returns a controllable,
/// never-auto-completing `Future` on every call after that — used to hold
/// the post-Catch-Details-return reload open long enough to dispose the
/// page mid-flight, proving `_openCatchDetails`'s `mounted` guard prevents
/// a `setState` call after disposal.
class _FirstThenPendingRepository extends WaterBodyStatisticsRepository {
  _FirstThenPendingRepository(super.database, this._firstSummary);

  final WaterBodyStatisticsSummary _firstSummary;
  final Completer<WaterBodyStatisticsSummary> secondCallCompleter =
      Completer<WaterBodyStatisticsSummary>();
  int callCount = 0;

  @override
  Future<WaterBodyStatisticsSummary> getWaterBodyStatistics(
    String waterBodyId,
  ) {
    callCount++;
    if (callCount == 1) {
      return Future.value(_firstSummary);
    }
    return secondCallCompleter.future;
  }
}

void main() {
  late AppDatabase database;
  late Directory tempDir;
  late CatchPhotoRepository catchPhotoRepository;
  late CatchRepository catchRepository;
  late LureCatalogRepository lureCatalogRepository;
  late TackleBoxPhotoStorage tackleBoxPhotoStorage;
  late PersonalTackleBoxRepository personalTackleBoxRepository;
  late WaterBody waterBody;
  late FishingSpot fishingSpot;

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
    tempDir = Directory.systemTemp.createTempSync(
      'water_body_statistics_page',
    );
    catchPhotoRepository = CatchPhotoRepository(
      database,
      CatchPhotoStorage(rootDirectoryProvider: () async => tempDir),
    );
    catchRepository = CatchRepository(database);
    lureCatalogRepository = LureCatalogRepository(database);
    tackleBoxPhotoStorage = TackleBoxPhotoStorage(
      rootDirectoryProvider: () async => tempDir,
    );
    personalTackleBoxRepository = PersonalTackleBoxRepository(
      database,
      tackleBoxPhotoStorage,
    );
    waterBody = WaterBody(
      id: 'water-body-1',
      name: 'Merrasjärvi',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    fishingSpot = FishingSpot(
      id: 'spot-1',
      name: 'Test Spot',
      latitude: 61.0,
      longitude: 25.0,
      waterBodyId: 'water-body-1',
      createdAt: DateTime.utc(2026, 1, 1),
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpPage(
    WidgetTester tester,
    WaterBodyStatisticsRepository repository,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: WaterBodyStatisticsPage(
          waterBody: waterBody,
          repository: repository,
          catchRepository: catchRepository,
          catchPhotoRepository: catchPhotoRepository,
          lureCatalogRepository: lureCatalogRepository,
          personalTackleBoxRepository: personalTackleBoxRepository,
          personalTackleBoxPhotoStorage: tackleBoxPhotoStorage,
        ),
      ),
    );
  }

  Catch buildCatch(String id, {int? weightGrams, DateTime? caughtAt}) => Catch(
    id: id,
    fishingSpotId: fishingSpot.id,
    species: FishSpecies.pike,
    caughtAt: caughtAt ?? DateTime.utc(2026, 7, 17),
    weightGrams: weightGrams,
    createdAt: DateTime.utc(2026, 7, 17),
    updatedAt: DateTime.utc(2026, 7, 17),
  );

  WaterBodyCatchEntry buildEntry(
    String id, {
    int? weightGrams,
    DateTime? caughtAt,
    FishingSpot? atFishingSpot,
  }) => WaterBodyCatchEntry(
    catchModel: buildCatch(id, weightGrams: weightGrams, caughtAt: caughtAt),
    fishingSpot: atFishingSpot ?? fishingSpot,
  );

  testWidgets(
    'shows a loading indicator while getWaterBodyStatistics is in flight',
    (tester) async {
      final pending = _PendingRepository(database);

      await pumpPage(tester, pending);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('shows an error message and a retry action on failure', (
    tester,
  ) async {
    final failing = _FailingRepository(database);

    await pumpPage(tester, failing);
    await tester.pumpAndSettle();

    expect(find.text('Tilastojen lataaminen epäonnistui.'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Yritä uudelleen'),
      findsOneWidget,
    );
  });

  testWidgets('retry re-runs the load and shows content on success', (
    tester,
  ) async {
    final summary = WaterBodyStatisticsSummary(
      catches: const [],
      speciesCatchCounts: const [],
      lastCatchDate: null,
    );
    final repository = _FailOnceRepository(database, summary);

    await pumpPage(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Tilastojen lataaminen epäonnistui.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Yritä uudelleen'));
    await tester.pumpAndSettle();

    expect(find.text('Tilastojen lataaminen epäonnistui.'), findsNothing);
    expect(repository.callCount, 2);
  });

  testWidgets('shows the water body name in the AppBar title', (
    tester,
  ) async {
    final summary = WaterBodyStatisticsSummary(
      catches: const [],
      speciesCatchCounts: const [],
      lastCatchDate: null,
    );
    final repository = _StaticRepository(database, summary);

    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Merrasjärvi'), findsOneWidget);
  });

  testWidgets(
    'an empty water body shows the total as 0, "no data yet" for Last '
    'Catch Date, and empty section messages',
    (tester) async {
      final summary = WaterBodyStatisticsSummary(
        catches: const [],
        speciesCatchCounts: const [],
        lastCatchDate: null,
      );
      final repository = _StaticRepository(database, summary);

      await pumpPage(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
      expect(find.text('Ei vielä tietoja'), findsOneWidget);
      // "Ei vielä saaliita." appears twice: once for the empty Species
      // Breakdown, once for the empty Catch List.
      expect(find.text('Ei vielä saaliita.'), findsNWidgets(2));
    },
  );

  testWidgets('the header shows Last Catch Date when catches exist', (
    tester,
  ) async {
    final summary = WaterBodyStatisticsSummary(
      catches: [buildEntry('catch-1', caughtAt: DateTime.utc(2026, 7, 20))],
      speciesCatchCounts: const [
        SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 1),
      ],
      lastCatchDate: DateTime.utc(2026, 7, 20),
    );
    final repository = _StaticRepository(database, summary);

    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(StatisticsSummaryCard).at(1),
        matching: find.text('20.7.2026'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a populated summary shows the total, the Species Breakdown, '
      'and the full Catch List in the given order', (tester) async {
    final entries = [
      buildEntry('catch-1', weightGrams: 5000),
      buildEntry('catch-2', weightGrams: 3000),
    ];
    final summary = WaterBodyStatisticsSummary(
      catches: entries,
      speciesCatchCounts: const [
        SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 2),
      ],
      lastCatchDate: DateTime.utc(2026, 7, 17),
    );
    final repository = _StaticRepository(database, summary);

    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(StatisticsSummaryCard).first,
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    final items = tester
        .widgetList<CatchListItem>(find.byType(CatchListItem))
        .toList();
    expect(items.map((item) => item.catchModel.id).toList(), [
      'catch-1',
      'catch-2',
    ]);
  });

  testWidgets('the Species Breakdown row performs no action when tapped', (
    tester,
  ) async {
    final summary = WaterBodyStatisticsSummary(
      catches: [buildEntry('catch-1', weightGrams: 2000)],
      speciesCatchCounts: const [
        SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 1),
      ],
      lastCatchDate: DateTime.utc(2026, 7, 17),
    );
    final repository = _StaticRepository(database, summary);

    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    // "Hauki" also appears on the Catch List entry, so the check and tap
    // are scoped to the Species Breakdown's own CatchCountRow specifically.
    final speciesBreakdownLabel = find.descendant(
      of: find.byType(CatchCountRow),
      matching: find.text('Hauki'),
    );
    expect(speciesBreakdownLabel, findsOneWidget);
    await tester.tap(speciesBreakdownLabel);
    await tester.pumpAndSettle();

    // Still on the same page — no navigation occurred.
    expect(find.byType(WaterBodyStatisticsPage), findsOneWidget);
  });

  testWidgets(
    'a catch with no photo, weight, or length renders without a broken '
    'layout',
    (tester) async {
      final summary = WaterBodyStatisticsSummary(
        catches: [buildEntry('catch-1')],
        speciesCatchCounts: const [
          SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 1),
        ],
        lastCatchDate: DateTime.utc(2026, 7, 17),
      );
      final repository = _StaticRepository(database, summary);

      await pumpPage(tester, repository);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tapping a Catch List entry opens Catch Details using that entry\'s own '
    'fishing spot, even when catches span multiple fishing spots under the '
    'water body',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final spotA = await fishingSpotRepository.create(
        name: 'Spot A',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: 'water-body-1',
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      final spotB = await fishingSpotRepository.create(
        name: 'Spot B',
        latitude: 61.5,
        longitude: 25.5,
        waterBodyId: 'water-body-1',
      );
      final atSpotA = await catchRepository.create(
        fishingSpotId: spotA.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 5000,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      final atSpotB = await catchRepository.create(
        fishingSpotId: spotB.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 1000,
      );

      final summary = WaterBodyStatisticsSummary(
        catches: [
          WaterBodyCatchEntry(catchModel: atSpotA, fishingSpot: spotA),
          WaterBodyCatchEntry(catchModel: atSpotB, fishingSpot: spotB),
        ],
        speciesCatchCounts: const [
          SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 2),
        ],
        lastCatchDate: atSpotA.caughtAt,
      );
      final repository = _StaticRepository(database, summary);

      await pumpPage(tester, repository);
      await tester.pumpAndSettle();

      final catchListItems = find.byType(CatchListItem);
      expect(catchListItems, findsNWidgets(2));
      await tester.tap(catchListItems.at(1));
      await tester.pumpAndSettle();

      expect(find.byType(CatchDetailsPage), findsOneWidget);
    },
  );

  // Lifecycle refresh — mirrors the established four-test shape already
  // used by Species Statistics / Fishing Spot Statistics.

  testWidgets(
    "editing a catch's weight while Catch Details is open is reflected in "
    'Water Body Statistics after returning',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final realFishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: 'water-body-1',
      );
      final original = await catchRepository.create(
        fishingSpotId: realFishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final repository = WaterBodyStatisticsRepository(database);

      await tester.pumpWidget(
        MaterialApp(
          home: WaterBodyStatisticsPage(
            waterBody: waterBody,
            repository: repository,
            catchRepository: catchRepository,
            catchPhotoRepository: catchPhotoRepository,
            lureCatalogRepository: lureCatalogRepository,
            personalTackleBoxRepository: personalTackleBoxRepository,
            personalTackleBoxPhotoStorage: tackleBoxPhotoStorage,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 kg'), findsOneWidget);

      await tester.tap(find.byType(CatchListItem));
      await tester.pumpAndSettle();
      expect(find.byType(CatchDetailsPage), findsOneWidget);

      await catchRepository.update(
        catchModel: original,
        species: original.species,
        caughtAt: original.caughtAt,
        weightGrams: 9000,
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(WaterBodyStatisticsPage), findsOneWidget);
      expect(find.text('9 kg'), findsOneWidget);
      expect(find.text('2 kg'), findsNothing);
    },
  );

  testWidgets(
    'deleting a catch while Catch Details is open is reflected in Water '
    'Body Statistics after returning',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final realFishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: 'water-body-1',
      );
      final toDelete = await catchRepository.create(
        fishingSpotId: realFishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final repository = WaterBodyStatisticsRepository(database);

      await tester.pumpWidget(
        MaterialApp(
          home: WaterBodyStatisticsPage(
            waterBody: waterBody,
            repository: repository,
            catchRepository: catchRepository,
            catchPhotoRepository: catchPhotoRepository,
            lureCatalogRepository: lureCatalogRepository,
            personalTackleBoxRepository: personalTackleBoxRepository,
            personalTackleBoxPhotoStorage: tackleBoxPhotoStorage,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(StatisticsSummaryCard).first,
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(CatchListItem));
      await tester.pumpAndSettle();
      expect(find.byType(CatchDetailsPage), findsOneWidget);

      await catchRepository.delete(toDelete.id);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(WaterBodyStatisticsPage), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Ei vielä saaliita.'), findsNWidgets(2));
    },
  );

  testWidgets(
    'deleting a catch through the real Catch Details delete action (menu, '
    'confirm dialog) is immediately reflected in Water Body Statistics '
    'after returning, with no extra reload needed',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final realFishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: 'water-body-1',
      );
      // The heaviest and most recent catch — deleting it must change the
      // total, the Species Breakdown, and the Last Catch Date all at once.
      final toDelete = await catchRepository.create(
        fishingSpotId: realFishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 20),
        weightGrams: 5000,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      final remaining = await catchRepository.create(
        fishingSpotId: realFishingSpot.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 10),
        weightGrams: 1000,
      );

      final repository = WaterBodyStatisticsRepository(database);

      await tester.pumpWidget(
        MaterialApp(
          home: WaterBodyStatisticsPage(
            waterBody: waterBody,
            repository: repository,
            catchRepository: catchRepository,
            catchPhotoRepository: catchPhotoRepository,
            lureCatalogRepository: lureCatalogRepository,
            personalTackleBoxRepository: personalTackleBoxRepository,
            personalTackleBoxPhotoStorage: tackleBoxPhotoStorage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Repository-sorted by weight descending, so toDelete (5000g) is the
      // first Catch List entry.
      final catchListItems = tester
          .widgetList<CatchListItem>(find.byType(CatchListItem))
          .toList();
      expect(catchListItems.first.catchModel.id, toDelete.id);
      await tester.tap(find.byType(CatchListItem).first);
      await tester.pumpAndSettle();
      expect(find.byType(CatchDetailsPage), findsOneWidget);

      // The real delete action: overflow menu -> "Poista" -> confirm dialog
      // -> "Poista". Not a direct repository call from the test.
      await tester.tap(find.byKey(const Key('catchDetailsMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Poista'));
      await _pumpUntilSettledWithRealIO(tester);

      // Back on Water Body Statistics — assert immediately, with no
      // manual reload or extra pump beyond what the delete flow itself
      // triggers.
      expect(find.byType(WaterBodyStatisticsPage), findsOneWidget);
      expect(find.byType(CatchDetailsPage), findsNothing);

      final remainingItems = tester
          .widgetList<CatchListItem>(find.byType(CatchListItem))
          .toList();
      expect(remainingItems.map((item) => item.catchModel.id).toList(), [
        remaining.id,
      ]);

      // Total catches: 2 -> 1.
      expect(
        find.descendant(
          of: find.byType(StatisticsSummaryCard).first,
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      // Last Catch Date: the deleted catch's date must no longer be shown;
      // the surviving catch's date takes its place.
      expect(
        find.descendant(
          of: find.byType(StatisticsSummaryCard).at(1),
          matching: find.text('10.7.2026'),
        ),
        findsOneWidget,
      );
      expect(find.text('20.7.2026'), findsNothing);
      // Species Breakdown: pike entry gone, perch entry remains.
      expect(
        find.descendant(
          of: find.byType(CatchCountRow),
          matching: find.text('Hauki'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(CatchCountRow),
          matching: find.text('Ahven'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'does not call setState after the page is disposed while a post-return '
    'reload is still pending',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final realFishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: 'water-body-1',
      );
      final createdCatch = await catchRepository.create(
        fishingSpotId: realFishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2500,
      );

      final firstSummary = WaterBodyStatisticsSummary(
        catches: [
          WaterBodyCatchEntry(
            catchModel: createdCatch,
            fishingSpot: realFishingSpot,
          ),
        ],
        speciesCatchCounts: const [
          SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 1),
        ],
        lastCatchDate: createdCatch.caughtAt,
      );
      final repository = _FirstThenPendingRepository(database, firstSummary);

      await tester.pumpWidget(
        MaterialApp(
          home: WaterBodyStatisticsPage(
            waterBody: waterBody,
            repository: repository,
            catchRepository: catchRepository,
            catchPhotoRepository: catchPhotoRepository,
            lureCatalogRepository: lureCatalogRepository,
            personalTackleBoxRepository: personalTackleBoxRepository,
            personalTackleBoxPhotoStorage: tackleBoxPhotoStorage,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.callCount, 1);

      await tester.tap(find.byType(CatchListItem));
      await tester.pumpAndSettle();
      expect(find.byType(CatchDetailsPage), findsOneWidget);

      // Returning triggers the post-navigation reload — now the pending,
      // never-completing second call, so the page is left showing its
      // loading state indefinitely. `pumpAndSettle()` would time out here
      // (a `CircularProgressIndicator` animates forever), so a bounded
      // pump sequence is used instead.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(repository.callCount, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Dispose the whole page tree while that reload is still in flight.
      await tester.pumpWidget(const SizedBox.shrink());

      // Resolving the pending call now must not crash with "setState()
      // called after dispose()".
      repository.secondCallCompleter.complete(firstSummary);
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
