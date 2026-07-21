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
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/statistics/data/general_catch_statistics_repository.dart';
import 'package:fishing_app/features/statistics/data/species_statistics_repository.dart';
import 'package:fishing_app/features/statistics/domain/general_catch_statistics_summary.dart';
import 'package:fishing_app/features/statistics/domain/largest_catch.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/general_catch_statistics_tab.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/ranked_largest_catch_row.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/species_catch_statistic_row.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/species_statistics_page.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/statistics_summary_card.dart';

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
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

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
      expect(find.text('Ei vielä saaliita.'), findsOneWidget);
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
      );
      final repository = _StaticRepository(database, summary);

      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      // Scoped to SpeciesCatchStatisticRow: an unscoped "Hauki" finder would
      // also match the most-caught-species summary card's own primary value
      // text (species name and catch count now render as separate texts).
      await tester.tap(
        find.descendant(
          of: find.byType(SpeciesCatchStatisticRow),
          matching: find.text('Hauki'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SpeciesStatisticsPage), findsOneWidget);
      // The Species Statistics AppBar title is the species' Finnish name.
      expect(find.widgetWithText(AppBar, 'Hauki'), findsOneWidget);
    },
  );

  testWidgets('the two summary cards are displayed side by side with equal '
      'width', (tester) async {
    final summary = GeneralCatchStatisticsSummary(
      totalCatches: 5,
      largestCatches: const [],
      speciesCatchCounts: const [],
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
    );
    final repository = _StaticRepository(database, summary);

    await pumpTab(tester, repository);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
