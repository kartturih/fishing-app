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
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/statistics/data/fishing_spot_statistics_repository.dart';
import 'package:fishing_app/features/statistics/domain/fishing_spot_statistics_summary.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/catch_count_row.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/fishing_spot_record_catch_card.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/fishing_spot_statistics_page.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/statistics_summary_card.dart';

/// Pumps and lets a multi-step real dart:io/database chain (photo file
/// deletion, the catch row delete) advance to completion; the fake-async
/// test clock does not advance real I/O on its own. Mirrors the identical
/// helper in catch_details_page_test.dart / edit_catch_bottom_sheet_test.dart.
Future<void> _pumpUntilSettledWithRealIO(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Never completes `getFishingSpotStatistics`, so the loading state can be
/// observed deterministically. Mirrors `_PendingRepository` in
/// species_statistics_page_test.dart.
class _PendingRepository extends FishingSpotStatisticsRepository {
  _PendingRepository(super.database);

  final Completer<FishingSpotStatisticsSummary> pending =
      Completer<FishingSpotStatisticsSummary>();

  @override
  Future<FishingSpotStatisticsSummary> getFishingSpotStatistics(
    String fishingSpotId,
  ) => pending.future;
}

class _FailingRepository extends FishingSpotStatisticsRepository {
  _FailingRepository(super.database);

  @override
  Future<FishingSpotStatisticsSummary> getFishingSpotStatistics(
    String fishingSpotId,
  ) async {
    throw StateError('simulated load failure');
  }
}

/// Fails on its first call, then succeeds — used to verify the retry
/// action re-runs the load.
class _FailOnceRepository extends FishingSpotStatisticsRepository {
  _FailOnceRepository(super.database, this._summary);

  final FishingSpotStatisticsSummary _summary;
  int callCount = 0;

  @override
  Future<FishingSpotStatisticsSummary> getFishingSpotStatistics(
    String fishingSpotId,
  ) async {
    callCount++;
    if (callCount == 1) {
      throw StateError('simulated load failure');
    }
    return _summary;
  }
}

class _StaticRepository extends FishingSpotStatisticsRepository {
  _StaticRepository(super.database, this._summary);

  final FishingSpotStatisticsSummary _summary;

  @override
  Future<FishingSpotStatisticsSummary> getFishingSpotStatistics(
    String fishingSpotId,
  ) async => _summary;
}

/// Resolves normally on its first call, then returns a controllable,
/// never-auto-completing `Future` on every call after that — used to hold
/// the post-Catch-Details-return reload open long enough to dispose the
/// page mid-flight, proving `_openCatchDetails`'s `mounted` guard prevents
/// a `setState` call after disposal. Mirrors TD-021's own precedent
/// (`_FirstThenPendingRepository` in species_statistics_page_test.dart).
class _FirstThenPendingRepository extends FishingSpotStatisticsRepository {
  _FirstThenPendingRepository(super.database, this._firstSummary);

  final FishingSpotStatisticsSummary _firstSummary;
  final Completer<FishingSpotStatisticsSummary> secondCallCompleter =
      Completer<FishingSpotStatisticsSummary>();
  int callCount = 0;

  @override
  Future<FishingSpotStatisticsSummary> getFishingSpotStatistics(
    String fishingSpotId,
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
  late FishingSpot fishingSpot;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync(
      'fishing_spot_statistics_page',
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
    fishingSpot = FishingSpot(
      id: 'spot-1',
      name: 'Merrasjärvi',
      latitude: 61.0,
      longitude: 25.0,
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
    FishingSpotStatisticsRepository repository,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: FishingSpotStatisticsPage(
          fishingSpot: fishingSpot,
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

  testWidgets(
    'shows a loading indicator while getFishingSpotStatistics is in flight',
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
    final summary = FishingSpotStatisticsSummary(
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

  testWidgets('shows the fishing spot name in the AppBar title', (
    tester,
  ) async {
    final summary = FishingSpotStatisticsSummary(
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
    'an empty fishing spot shows the total as 0, "no data yet" for Last '
    'Catch Date, and empty section messages',
    (tester) async {
      final summary = FishingSpotStatisticsSummary(
        catches: const [],
        speciesCatchCounts: const [],
        lastCatchDate: null,
      );
      final repository = _StaticRepository(database, summary);

      await pumpPage(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
      expect(find.text('Ei vielä tietoja'), findsOneWidget);
      expect(find.text('Ei vielä ennätyssaalista.'), findsOneWidget);
      // "Ei vielä saaliita." appears twice: once for the empty Species
      // Breakdown, once for the empty Catch List.
      expect(find.text('Ei vielä saaliita.'), findsNWidgets(2));
    },
  );

  testWidgets('the header shows Last Catch Date when catches exist', (
    tester,
  ) async {
    final summary = FishingSpotStatisticsSummary(
      catches: [buildCatch('catch-1', caughtAt: DateTime.utc(2026, 7, 20))],
      speciesCatchCounts: const [
        SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 1),
      ],
      lastCatchDate: DateTime.utc(2026, 7, 20),
    );
    final repository = _StaticRepository(database, summary);

    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    // The Record Catch card shows the same date when its one catch is also
    // the most recent, so the check is scoped to the Last Catch Date card
    // specifically (the second of the two header `StatisticsSummaryCard`s).
    expect(
      find.descendant(
        of: find.byType(StatisticsSummaryCard).at(1),
        matching: find.text('20.7.2026'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a populated summary shows the total, the Record Catch card, the '
      'Species Breakdown, and the full Catch List in the given order', (
    tester,
  ) async {
    final entries = [
      buildCatch('catch-1', weightGrams: 5000),
      buildCatch('catch-2', weightGrams: 3000),
    ];
    final summary = FishingSpotStatisticsSummary(
      catches: entries,
      speciesCatchCounts: const [
        SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 2),
      ],
      lastCatchDate: DateTime.utc(2026, 7, 17),
    );
    final repository = _StaticRepository(database, summary);

    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    // The Species Breakdown's pike row also shows a catch count of 2, so
    // the total-catches check is scoped to the header's total card (the
    // first of the two `StatisticsSummaryCard`s).
    expect(
      find.descendant(
        of: find.byType(StatisticsSummaryCard).first,
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.byType(FishingSpotRecordCatchCard), findsOneWidget);

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
    final summary = FishingSpotStatisticsSummary(
      catches: [buildCatch('catch-1', weightGrams: 2000)],
      speciesCatchCounts: const [
        SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 1),
      ],
      lastCatchDate: DateTime.utc(2026, 7, 17),
    );
    final repository = _StaticRepository(database, summary);

    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    // "Hauki" also appears on the Record Catch card and the Catch List
    // entry, so the check and tap are scoped to the Species Breakdown's
    // own CatchCountRow specifically.
    final speciesBreakdownLabel = find.descendant(
      of: find.byType(CatchCountRow),
      matching: find.text('Hauki'),
    );
    expect(speciesBreakdownLabel, findsOneWidget);
    await tester.tap(speciesBreakdownLabel);
    await tester.pumpAndSettle();

    // Still on the same page — no navigation occurred.
    expect(find.byType(FishingSpotStatisticsPage), findsOneWidget);
  });

  testWidgets(
    'a catch with no photo, weight, or length renders without a broken '
    'layout',
    (tester) async {
      final summary = FishingSpotStatisticsSummary(
        catches: [buildCatch('catch-1')],
        speciesCatchCounts: const [
          SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 1),
        ],
        lastCatchDate: DateTime.utc(2026, 7, 17),
      );
      final repository = _StaticRepository(database, summary);

      await pumpPage(tester, repository);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FishingSpotRecordCatchCard), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Record Catch card opens Catch Details for that catch',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final realFishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
      );
      final createdCatch = await catchRepository.create(
        fishingSpotId: realFishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2500,
      );

      final summary = FishingSpotStatisticsSummary(
        catches: [createdCatch],
        speciesCatchCounts: const [
          SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 1),
        ],
        lastCatchDate: createdCatch.caughtAt,
      );
      final repository = _StaticRepository(database, summary);

      await tester.pumpWidget(
        MaterialApp(
          home: FishingSpotStatisticsPage(
            fishingSpot: realFishingSpot,
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

      await tester.tap(find.byType(FishingSpotRecordCatchCard));
      await tester.pumpAndSettle();

      expect(find.byType(CatchDetailsPage), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a Catch List entry opens Catch Details for that specific catch',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final realFishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
      );
      final first = await catchRepository.create(
        fishingSpotId: realFishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 5000,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      final second = await catchRepository.create(
        fishingSpotId: realFishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 1000,
      );

      final summary = FishingSpotStatisticsSummary(
        catches: [first, second],
        speciesCatchCounts: const [
          SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 2),
        ],
        lastCatchDate: first.caughtAt,
      );
      final repository = _StaticRepository(database, summary);

      await tester.pumpWidget(
        MaterialApp(
          home: FishingSpotStatisticsPage(
            fishingSpot: realFishingSpot,
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

      // The Record Catch card also renders the first (heaviest) catch, so
      // tap the second Catch List entry specifically to prove navigation
      // is wired per-entry, not just to the record catch.
      final catchListItems = find.byType(CatchListItem);
      expect(catchListItems, findsNWidgets(2));
      // The Species Breakdown section pushes the second Catch List entry
      // below the default test viewport, so it must be scrolled into view
      // before it can be hit-tested.
      await tester.ensureVisible(catchListItems.at(1));
      await tester.pump();
      await tester.tap(catchListItems.at(1));
      await tester.pumpAndSettle();

      expect(find.byType(CatchDetailsPage), findsOneWidget);
    },
  );

  // Lifecycle refresh — mirrors TD-021's own four-test shape exactly,
  // applied here from the start rather than as a later fix (TD-022 Key
  // Design Decision 9).

  testWidgets(
    "editing a catch's weight while Catch Details is open is reflected in "
    'Fishing Spot Statistics after returning (via the Record Catch card '
    'path)',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final realFishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
      );
      final original = await catchRepository.create(
        fishingSpotId: realFishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final repository = FishingSpotStatisticsRepository(database);

      await tester.pumpWidget(
        MaterialApp(
          home: FishingSpotStatisticsPage(
            fishingSpot: realFishingSpot,
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
      expect(find.text('2 kg'), findsNWidgets(2));

      await tester.tap(find.byType(FishingSpotRecordCatchCard));
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

      expect(find.byType(FishingSpotStatisticsPage), findsOneWidget);
      expect(find.text('9 kg'), findsNWidgets(2));
      expect(find.text('2 kg'), findsNothing);
    },
  );

  testWidgets(
    'deleting a catch while Catch Details is open is reflected in Fishing '
    'Spot Statistics after returning',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final realFishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
      );
      final toDelete = await catchRepository.create(
        fishingSpotId: realFishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final repository = FishingSpotStatisticsRepository(database);

      await tester.pumpWidget(
        MaterialApp(
          home: FishingSpotStatisticsPage(
            fishingSpot: realFishingSpot,
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
      // The Species Breakdown's pike row also shows a catch count of 1, so
      // the total-catches check is scoped to the header's total card.
      expect(
        find.descendant(
          of: find.byType(StatisticsSummaryCard).first,
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(FishingSpotRecordCatchCard));
      await tester.pumpAndSettle();
      expect(find.byType(CatchDetailsPage), findsOneWidget);

      await catchRepository.delete(toDelete.id);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(FishingSpotStatisticsPage), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Ei vielä ennätyssaalista.'), findsOneWidget);
      expect(find.text('Ei vielä saaliita.'), findsNWidgets(2));
    },
  );

  testWidgets(
    'deleting a catch through the real Catch Details delete action (menu, '
    'confirm dialog) is immediately reflected in Fishing Spot Statistics '
    'after returning, with no extra reload needed',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final realFishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
      );
      // The heaviest and most recent catch — deleting it must change the
      // total, the Record Catch, the Species Breakdown, and the Last Catch
      // Date all at once.
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

      final repository = FishingSpotStatisticsRepository(database);

      await tester.pumpWidget(
        MaterialApp(
          home: FishingSpotStatisticsPage(
            fishingSpot: realFishingSpot,
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
      // deleteFilesForCatch/CatchRepository.delete perform real dart:io /
      // database work that the fake-async test clock does not advance on
      // its own — same real-IO pumping convention already established in
      // catch_details_page_test.dart's own delete tests.
      await _pumpUntilSettledWithRealIO(tester);

      // Back on Fishing Spot Statistics — assert immediately, with no
      // manual reload or extra pump beyond what the delete flow itself
      // triggers.
      expect(find.byType(FishingSpotStatisticsPage), findsOneWidget);
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
      // Record Catch: now the surviving (perch) catch, not the deleted
      // (pike) one.
      expect(
        find.descendant(
          of: find.byType(FishingSpotRecordCatchCard),
          matching: find.text('Ahven'),
        ),
        findsOneWidget,
      );
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
    'a refresh after returning from Catch Details can change the Record '
    'Catch, Catch List order, and Last Catch Date (via the Catch List '
    'path)',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final realFishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
      );
      final heavier = await catchRepository.create(
        fishingSpotId: realFishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 10),
        weightGrams: 5000,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      final lighter = await catchRepository.create(
        fishingSpotId: realFishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 1000,
      );

      final repository = FishingSpotStatisticsRepository(database);

      await tester.pumpWidget(
        MaterialApp(
          home: FishingSpotStatisticsPage(
            fishingSpot: realFishingSpot,
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

      var items = tester
          .widgetList<CatchListItem>(find.byType(CatchListItem))
          .toList();
      expect(items.first.catchModel.id, heavier.id);
      expect(items.last.catchModel.id, lighter.id);
      expect(find.text('17.7.2026'), findsOneWidget); // Last Catch Date

      final catchListItems = find.byType(CatchListItem);
      // The Species Breakdown section pushes the second Catch List entry
      // below the default test viewport, so it must be scrolled into view
      // before it can be hit-tested.
      await tester.ensureVisible(catchListItems.at(1));
      await tester.pump();
      await tester.tap(catchListItems.at(1));
      await tester.pumpAndSettle();
      expect(find.byType(CatchDetailsPage), findsOneWidget);

      // While Catch Details is open, the lighter catch is edited to
      // become both the heavier and the most recent of the two.
      await catchRepository.update(
        catchModel: lighter,
        species: lighter.species,
        caughtAt: DateTime(2026, 7, 25),
        weightGrams: 9000,
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      items = tester
          .widgetList<CatchListItem>(find.byType(CatchListItem))
          .toList();
      expect(items.first.catchModel.id, lighter.id);
      expect(items.last.catchModel.id, heavier.id);
      expect(find.text('25.7.2026'), findsOneWidget);
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
      );
      final createdCatch = await catchRepository.create(
        fishingSpotId: realFishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2500,
      );

      final firstSummary = FishingSpotStatisticsSummary(
        catches: [createdCatch],
        speciesCatchCounts: const [
          SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 1),
        ],
        lastCatchDate: createdCatch.caughtAt,
      );
      final repository = _FirstThenPendingRepository(database, firstSummary);

      await tester.pumpWidget(
        MaterialApp(
          home: FishingSpotStatisticsPage(
            fishingSpot: realFishingSpot,
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

      await tester.tap(find.byType(FishingSpotRecordCatchCard));
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
