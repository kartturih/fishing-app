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
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/statistics/data/fishing_spot_statistics_repository.dart';
import 'package:fishing_app/features/statistics/data/general_catch_statistics_repository.dart';
import 'package:fishing_app/features/statistics/data/species_statistics_repository.dart';
import 'package:fishing_app/features/statistics/domain/fishing_spot_catch_statistic.dart';
import 'package:fishing_app/features/statistics/domain/general_catch_statistics_summary.dart';
import 'package:fishing_app/features/statistics/domain/largest_catch.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/catch_count_row.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/fishing_spot_record_catch_card.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/fishing_spot_statistics_page.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/general_catch_statistics_tab.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/ranked_largest_catch_row.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/record_catch_card.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/species_statistics_page.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/statistics_summary_card.dart';

/// Pumps and lets a multi-step real dart:io/database chain (photo file
/// deletion, the catch row delete) advance to completion; the fake-async
/// test clock does not advance real I/O on its own. Mirrors the identical
/// helper in catch_details_page_test.dart / fishing_spot_statistics_page_test.dart.
Future<void> _pumpUntilSettledWithRealIO(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Never completes `getGeneralCatchStatistics`, so the loading state can be
/// observed deterministically. Mirrors `_PendingRepository` in
/// lure_statistics_tab_test.dart.
class _PendingRepository extends GeneralCatchStatisticsRepository {
  _PendingRepository(super.database);

  final Completer<GeneralCatchStatisticsSummary> pending =
      Completer<GeneralCatchStatisticsSummary>();

  @override
  Future<GeneralCatchStatisticsSummary> getGeneralCatchStatistics() =>
      pending.future;
}

class _FailingRepository extends GeneralCatchStatisticsRepository {
  _FailingRepository(super.database);

  @override
  Future<GeneralCatchStatisticsSummary> getGeneralCatchStatistics() async {
    throw StateError('simulated load failure');
  }
}

/// Fails on its first call, then succeeds — used to verify the retry
/// action re-runs the load.
class _FailOnceRepository extends GeneralCatchStatisticsRepository {
  _FailOnceRepository(super.database, this._summary);

  final GeneralCatchStatisticsSummary _summary;
  int callCount = 0;

  @override
  Future<GeneralCatchStatisticsSummary> getGeneralCatchStatistics() async {
    callCount++;
    if (callCount == 1) {
      throw StateError('simulated load failure');
    }
    return _summary;
  }
}

class _StaticRepository extends GeneralCatchStatisticsRepository {
  _StaticRepository(super.database, this._summary);

  final GeneralCatchStatisticsSummary _summary;

  @override
  Future<GeneralCatchStatisticsSummary> getGeneralCatchStatistics() async =>
      _summary;
}

/// Resolves normally on its first call, then returns a controllable,
/// never-auto-completing `Future` on every call after that — used to hold
/// the post-return reload open long enough to dispose the tab mid-flight,
/// proving `_openFishingSpotStatistics`/`_openSpeciesStatistics`'s
/// `mounted` guard prevents a `setState` call after disposal. Mirrors the
/// identical precedent in fishing_spot_statistics_page_test.dart /
/// species_statistics_page_test.dart.
class _FirstThenPendingRepository extends GeneralCatchStatisticsRepository {
  _FirstThenPendingRepository(super.database, this._firstSummary);

  final GeneralCatchStatisticsSummary _firstSummary;
  final Completer<GeneralCatchStatisticsSummary> secondCallCompleter =
      Completer<GeneralCatchStatisticsSummary>();
  int callCount = 0;

  @override
  Future<GeneralCatchStatisticsSummary> getGeneralCatchStatistics() {
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
  late CatchPhotoStorage catchPhotoStorage;
  late CatchPhotoRepository catchPhotoRepository;
  late CatchRepository catchRepository;
  late LureCatalogRepository lureCatalogRepository;
  late TackleBoxPhotoStorage tackleBoxPhotoStorage;
  late PersonalTackleBoxRepository personalTackleBoxRepository;
  late SpeciesStatisticsRepository speciesStatisticsRepository;
  late FishingSpotStatisticsRepository fishingSpotStatisticsRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync(
      'general_catch_statistics_tab',
    );
    catchPhotoStorage = CatchPhotoStorage(
      rootDirectoryProvider: () async => tempDir,
    );
    catchPhotoRepository = CatchPhotoRepository(database, catchPhotoStorage);
    catchRepository = CatchRepository(database);
    lureCatalogRepository = LureCatalogRepository(database);
    tackleBoxPhotoStorage = TackleBoxPhotoStorage(
      rootDirectoryProvider: () async => tempDir,
    );
    personalTackleBoxRepository = PersonalTackleBoxRepository(
      database,
      tackleBoxPhotoStorage,
    );
    speciesStatisticsRepository = SpeciesStatisticsRepository(database);
    fishingSpotStatisticsRepository = FishingSpotStatisticsRepository(database);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // FishingSpotRepository/CatchRepository derive ids from
  // DateTime.now().microsecondsSinceEpoch; a tiny delay avoids two rapid
  // calls landing on the same clock tick. A bare Future.delayed would
  // deadlock under this file's fake-async testWidgets binding, so the
  // real delay runs via tester.runAsync — matching
  // fishing_spot_statistics_page_test.dart's own convention.
  Future<void> delay(WidgetTester tester) => tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 2)),
  );

  Future<void> pumpTab(
    WidgetTester tester,
    GeneralCatchStatisticsRepository repository,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GeneralCatchStatisticsTab(
            repository: repository,
            speciesStatisticsRepository: speciesStatisticsRepository,
            fishingSpotStatisticsRepository: fishingSpotStatisticsRepository,
            catchRepository: catchRepository,
            catchPhotoRepository: catchPhotoRepository,
            lureCatalogRepository: lureCatalogRepository,
            personalTackleBoxRepository: personalTackleBoxRepository,
            personalTackleBoxPhotoStorage: tackleBoxPhotoStorage,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'shows a loading indicator while getGeneralCatchStatistics is in flight',
    (tester) async {
      final pending = _PendingRepository(database);

      await pumpTab(tester, pending);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('shows an error message and a retry action on failure', (
    tester,
  ) async {
    final failing = _FailingRepository(database);

    await pumpTab(tester, failing);
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
    final summary = GeneralCatchStatisticsSummary(
      totalCatches: 0,
      largestCatches: const [],
      speciesCatchCounts: const [],
      fishingSpotCatchCounts: const [],
    );
    final repository = _FailOnceRepository(database, summary);

    await pumpTab(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Tilastojen lataaminen epäonnistui.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Yritä uudelleen'));
    await tester.pumpAndSettle();

    expect(find.text('Tilastojen lataaminen epäonnistui.'), findsNothing);
    expect(repository.callCount, 2);
  });

  testWidgets(
    'fully-empty summary shows "no data yet" and empty section messages',
    (tester) async {
      final summary = GeneralCatchStatisticsSummary(
        totalCatches: 0,
        largestCatches: const [],
        speciesCatchCounts: const [],
        fishingSpotCatchCounts: const [],
      );
      final repository = _StaticRepository(database, summary);

      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
      expect(find.text('Ei vielä tietoja'), findsOneWidget);
      expect(
        find.text('Yksikään saalis ei ole vielä punnittu.'),
        findsOneWidget,
      );
      // "Ei vielä saaliita." now appears twice: once for the empty Species
      // List, once for the empty Fishing Spot List (MFS-022).
      expect(find.text('Ei vielä saaliita.'), findsNWidgets(2));
    },
  );

  testWidgets(
    'a populated summary renders both cards, ranked largest catches in '
    'order, and the species list in order',
    (tester) async {
      final fishingSpot = FishingSpot(
        id: 'spot-1',
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      Catch buildCatch(String id, int weightGrams) => Catch(
        id: id,
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime.utc(2026, 7, 17),
        weightGrams: weightGrams,
        createdAt: DateTime.utc(2026, 7, 17),
        updatedAt: DateTime.utc(2026, 7, 17),
      );

      final summary = GeneralCatchStatisticsSummary(
        totalCatches: 4,
        largestCatches: [
          LargestCatch(
            catchModel: buildCatch('catch-1', 5000),
            fishingSpot: fishingSpot,
          ),
          LargestCatch(
            catchModel: buildCatch('catch-2', 3000),
            fishingSpot: fishingSpot,
          ),
        ],
        speciesCatchCounts: const [
          SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 3),
          SpeciesCatchStatistic(species: FishSpecies.perch, catchCount: 1),
        ],
        fishingSpotCatchCounts: [
          FishingSpotCatchStatistic(fishingSpot: fishingSpot, catchCount: 4),
        ],
      );
      final repository = _StaticRepository(database, summary);

      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('4'), findsOneWidget);
      expect(find.textContaining('Hauki'), findsWidgets);

      final rows = tester
          .widgetList<RankedLargestCatchRow>(find.byType(RankedLargestCatchRow))
          .toList();
      expect(rows.map((row) => row.rank).toList(), [1, 2]);
      expect(rows.map((row) => row.catchModel.id).toList(), [
        'catch-1',
        'catch-2',
      ]);
    },
  );

  testWidgets(
    'tapping a Top 3 Largest Catches entry opens Catch Details for the '
    'correct catch',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final fishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
      );
      final createdCatch = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2500,
      );

      final summary = GeneralCatchStatisticsSummary(
        totalCatches: 1,
        largestCatches: [
          LargestCatch(catchModel: createdCatch, fishingSpot: fishingSpot),
        ],
        speciesCatchCounts: const [
          SpeciesCatchStatistic(species: FishSpecies.zander, catchCount: 1),
        ],
        fishingSpotCatchCounts: const [],
      );
      final repository = _StaticRepository(database, summary);

      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      // Scoped to RankedLargestCatchRow: an unscoped exact "Kuha" finder
      // would also match the Species List row's own bare species label.
      await tester.tap(
        find.descendant(
          of: find.byType(RankedLargestCatchRow),
          matching: find.text('Kuha'),
        ),
      );
      await tester.pumpAndSettle();

      // Catch Details' AppBar title is the catch species (MFS-014 FR-3).
      expect(find.text('Kuha'), findsWidgets);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a Species List row opens Species Statistics for the correct '
    'species (MFS-021)',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final fishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
      );
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final summary = GeneralCatchStatisticsSummary(
        totalCatches: 1,
        largestCatches: const [],
        speciesCatchCounts: const [
          SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 1),
        ],
        fishingSpotCatchCounts: const [],
      );
      final repository = _StaticRepository(database, summary);

      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      // Scoped to the Species List section: an unscoped "Hauki" finder
      // would also match the most-caught-species summary card's own
      // primary value text (species name and catch count now render as
      // separate texts).
      await tester.tap(
        find.descendant(
          of: find.byType(CatchCountRow).first,
          matching: find.text('Hauki'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SpeciesStatisticsPage), findsOneWidget);
      // The Species Statistics AppBar title is the species' Finnish name.
      expect(find.widgetWithText(AppBar, 'Hauki'), findsOneWidget);
    },
  );

  testWidgets(
    'the Fishing Spot List renders every entry in the given (already-sorted) '
    'order',
    (tester) async {
      final firstSpot = FishingSpot(
        id: 'spot-1',
        name: 'Kotijärvi',
        latitude: 61.0,
        longitude: 25.0,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final secondSpot = FishingSpot(
        id: 'spot-2',
        name: 'Muualla',
        latitude: 62.0,
        longitude: 26.0,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final summary = GeneralCatchStatisticsSummary(
        totalCatches: 3,
        largestCatches: const [],
        speciesCatchCounts: const [],
        fishingSpotCatchCounts: [
          FishingSpotCatchStatistic(fishingSpot: firstSpot, catchCount: 2),
          FishingSpotCatchStatistic(fishingSpot: secondSpot, catchCount: 1),
        ],
      );
      final repository = _StaticRepository(database, summary);

      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('Kotijärvi'), findsOneWidget);
      expect(find.text('Muualla'), findsOneWidget);
      expect(find.text('Kalastuspaikat'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a Fishing Spot List row opens Fishing Spot Statistics for the '
    'correct fishing spot (MFS-022)',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final fishingSpot = await fishingSpotRepository.create(
        name: 'Merrasjärvi',
        latitude: 61.0,
        longitude: 25.0,
      );
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final summary = GeneralCatchStatisticsSummary(
        totalCatches: 1,
        largestCatches: const [],
        speciesCatchCounts: const [],
        fishingSpotCatchCounts: [
          FishingSpotCatchStatistic(fishingSpot: fishingSpot, catchCount: 1),
        ],
      );
      final repository = _StaticRepository(database, summary);

      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Merrasjärvi'));
      await tester.pumpAndSettle();

      expect(find.byType(FishingSpotStatisticsPage), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Merrasjärvi'), findsOneWidget);
    },
  );

  testWidgets('the two summary cards are displayed side by side with equal '
      'width', (tester) async {
    final summary = GeneralCatchStatisticsSummary(
      totalCatches: 5,
      largestCatches: const [],
      speciesCatchCounts: const [],
      fishingSpotCatchCounts: const [],
    );
    final repository = _StaticRepository(database, summary);

    await pumpTab(tester, repository);
    await tester.pumpAndSettle();

    final cardFinder = find.byType(StatisticsSummaryCard);
    expect(cardFinder, findsNWidgets(2));

    final firstCard = tester.getTopLeft(cardFinder.at(0));
    final secondCard = tester.getTopLeft(cardFinder.at(1));
    expect(firstCard.dy, secondCard.dy);
    expect(firstCard.dx, lessThan(secondCard.dx));
    expect(
      tester.getSize(cardFinder.at(0)).width,
      tester.getSize(cardFinder.at(1)).width,
    );
  });

  testWidgets(
    'the most caught species card shows the species name as its primary '
    'value and the catch count as secondary text',
    (tester) async {
      final summary = GeneralCatchStatisticsSummary(
        totalCatches: 5,
        largestCatches: const [],
        speciesCatchCounts: const [
          SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 5),
        ],
        fishingSpotCatchCounts: const [],
      );
      final repository = _StaticRepository(database, summary);

      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      final speciesCard = find.byType(StatisticsSummaryCard).at(1);
      expect(
        find.descendant(of: speciesCard, matching: find.text('Hauki')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: speciesCard, matching: find.text('5 saalista')),
        findsOneWidget,
      );
    },
  );

  testWidgets('a narrow screen layout renders without overflowing', (
    tester,
  ) async {
    final originalSize = tester.view.physicalSize;
    final originalDpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalDpr;
    });

    final fishingSpot = FishingSpot(
      id: 'spot-1',
      name: 'Test Spot',
      latitude: 61.0,
      longitude: 25.0,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    Catch buildCatch(String id, int weightGrams) => Catch(
      id: id,
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.eel,
      caughtAt: DateTime.utc(2026, 7, 17),
      weightGrams: weightGrams,
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );

    final summary = GeneralCatchStatisticsSummary(
      totalCatches: 3,
      largestCatches: [
        LargestCatch(
          catchModel: buildCatch('catch-1', 5000),
          fishingSpot: fishingSpot,
        ),
        LargestCatch(
          catchModel: buildCatch('catch-2', 3000),
          fishingSpot: fishingSpot,
        ),
        LargestCatch(
          catchModel: buildCatch('catch-3', 1000),
          fishingSpot: fishingSpot,
        ),
      ],
      speciesCatchCounts: const [
        SpeciesCatchStatistic(species: FishSpecies.eel, catchCount: 3),
      ],
      fishingSpotCatchCounts: [
        FishingSpotCatchStatistic(fishingSpot: fishingSpot, catchCount: 3),
      ],
    );
    final repository = _StaticRepository(database, summary);

    await pumpTab(tester, repository);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'returning from Fishing Spot Statistics after a real delete refreshes '
    'General Catch Statistics: total, Fishing Spot List (including removal '
    'of an emptied spot), Species List, and Top 3',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final spotA = await fishingSpotRepository.create(
        name: 'Spot A',
        latitude: 61.0,
        longitude: 25.0,
      );
      await delay(tester);
      final spotB = await fishingSpotRepository.create(
        name: 'Spot B',
        latitude: 62.0,
        longitude: 26.0,
      );
      await catchRepository.create(
        fishingSpotId: spotA.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 3000,
      );
      await delay(tester);
      await catchRepository.create(
        fishingSpotId: spotB.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 10),
        weightGrams: 1000,
      );

      final repository = GeneralCatchStatisticsRepository(database);

      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(StatisticsSummaryCard).first,
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      // The Fishing Spot List sits below the Top 3 and Species List
      // sections, past the default test viewport's lazy-build range —
      // scroll it into view before asserting on or tapping its rows.
      await tester.scrollUntilVisible(
        find.text('Spot A'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Spot A'), findsOneWidget);
      expect(find.text('Spot B'), findsOneWidget);

      await tester.tap(find.text('Spot A'));
      await tester.pumpAndSettle();
      expect(find.byType(FishingSpotStatisticsPage), findsOneWidget);

      await tester.tap(find.byType(FishingSpotRecordCatchCard));
      await tester.pumpAndSettle();
      expect(find.byType(CatchDetailsPage), findsOneWidget);

      // The real delete action: overflow menu -> "Poista" -> confirm
      // dialog -> "Poista". Not a direct repository call from the test.
      await tester.tap(find.byKey(const Key('catchDetailsMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Poista'));
      await _pumpUntilSettledWithRealIO(tester);

      expect(find.byType(FishingSpotStatisticsPage), findsOneWidget);
      expect(find.byType(CatchDetailsPage), findsNothing);

      // Return from Fishing Spot Statistics to General Catch Statistics.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(GeneralCatchStatisticsTab), findsOneWidget);
      expect(find.byType(FishingSpotStatisticsPage), findsNothing);

      // Total catches: 2 -> 1 — assert immediately, no extra reload.
      expect(
        find.descendant(
          of: find.byType(StatisticsSummaryCard).first,
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      // Spot A had its only catch deleted — it must disappear entirely
      // from the Fishing Spot List, not merely show a count of 0. The
      // list is shorter now (one fewer fishing spot, species, and largest
      // catch), so it may already fit the viewport; scrollUntilVisible is
      // a no-op in that case.
      await tester.scrollUntilVisible(
        find.text('Spot B'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Spot A'), findsNothing);
      expect(find.text('Spot B'), findsOneWidget);
      // Species List: pike (only ever caught at Spot A) is gone; perch
      // remains.
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
      // Top 3 Largest Catches: the deleted pike catch must be gone.
      final rankedRows = tester
          .widgetList<RankedLargestCatchRow>(find.byType(RankedLargestCatchRow))
          .toList();
      expect(rankedRows, hasLength(1));
      expect(rankedRows.single.catchModel.species, FishSpecies.perch);
    },
  );

  testWidgets('returning from Species Statistics after a real delete refreshes '
      'General Catch Statistics', (tester) async {
    final fishingSpotRepository = FishingSpotRepository(database);
    final fishingSpot = await fishingSpotRepository.create(
      name: 'Test Spot',
      latitude: 61.0,
      longitude: 25.0,
    );
    await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
      weightGrams: 2000,
    );

    final repository = GeneralCatchStatisticsRepository(database);

    await pumpTab(tester, repository);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(StatisticsSummaryCard).first,
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(CatchCountRow).first,
        matching: find.text('Hauki'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SpeciesStatisticsPage), findsOneWidget);

    await tester.tap(find.byType(RecordCatchCard));
    await tester.pumpAndSettle();
    expect(find.byType(CatchDetailsPage), findsOneWidget);

    // The real delete action, not a direct repository call.
    await tester.tap(find.byKey(const Key('catchDetailsMenuButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poista'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Poista'));
    await _pumpUntilSettledWithRealIO(tester);

    expect(find.byType(SpeciesStatisticsPage), findsOneWidget);
    expect(find.byType(CatchDetailsPage), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(GeneralCatchStatisticsTab), findsOneWidget);
    expect(find.byType(SpeciesStatisticsPage), findsNothing);

    expect(
      find.descendant(
        of: find.byType(StatisticsSummaryCard).first,
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(find.text('Yksikään saalis ei ole vielä punnittu.'), findsOneWidget);
    // "Ei vielä saaliita." for both the now-empty Species List and the
    // now-empty Fishing Spot List.
    expect(find.text('Ei vielä saaliita.'), findsNWidgets(2));
  });

  testWidgets(
    'an ordinary open-and-back through Fishing Spot Statistics with no '
    'changes reloads safely and shows the same data',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final fishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
      );
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final repository = GeneralCatchStatisticsRepository(database);

      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Spot'));
      await tester.pumpAndSettle();
      expect(find.byType(FishingSpotStatisticsPage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(GeneralCatchStatisticsTab), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(StatisticsSummaryCard).first,
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(find.text('Test Spot'), findsOneWidget);
      // No lingering/overlapping loading or error state.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Tilastojen lataaminen epäonnistui.'), findsNothing);
    },
  );

  testWidgets(
    'does not call setState after the tab is disposed while a post-return '
    'reload (after Fishing Spot Statistics) is still pending',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final fishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
      );
      await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final firstSummary = GeneralCatchStatisticsSummary(
        totalCatches: 1,
        largestCatches: const [],
        speciesCatchCounts: const [
          SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 1),
        ],
        fishingSpotCatchCounts: [
          FishingSpotCatchStatistic(fishingSpot: fishingSpot, catchCount: 1),
        ],
      );
      final repository = _FirstThenPendingRepository(database, firstSummary);

      await pumpTab(tester, repository);
      await tester.pumpAndSettle();
      expect(repository.callCount, 1);

      await tester.tap(find.text('Test Spot'));
      await tester.pumpAndSettle();
      expect(find.byType(FishingSpotStatisticsPage), findsOneWidget);

      // Returning triggers the post-navigation reload — now the pending,
      // never-completing second call, so the tab is left showing its
      // loading state indefinitely. `pumpAndSettle()` would time out here
      // (a `CircularProgressIndicator` animates forever), so a bounded
      // pump is used instead.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      expect(repository.callCount, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Dispose the whole tree while that reload is still in flight.
      await tester.pumpWidget(const SizedBox.shrink());

      // Resolving the pending call now must not crash with "setState()
      // called after dispose()".
      repository.secondCallCompleter.complete(firstSummary);
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
