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
import 'package:fishing_app/features/statistics/data/species_statistics_repository.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_entry.dart';
import 'package:fishing_app/features/statistics/domain/species_statistics_summary.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/record_catch_card.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/species_statistics_page.dart';

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

/// Never completes `getSpeciesStatistics`, so the loading state can be
/// observed deterministically. Mirrors `_PendingRepository` in
/// general_catch_statistics_tab_test.dart.
class _PendingRepository extends SpeciesStatisticsRepository {
  _PendingRepository(super.database);

  final Completer<SpeciesStatisticsSummary> pending =
      Completer<SpeciesStatisticsSummary>();

  @override
  Future<SpeciesStatisticsSummary> getSpeciesStatistics(FishSpecies species) =>
      pending.future;
}

class _FailingRepository extends SpeciesStatisticsRepository {
  _FailingRepository(super.database);

  @override
  Future<SpeciesStatisticsSummary> getSpeciesStatistics(
    FishSpecies species,
  ) async {
    throw StateError('simulated load failure');
  }
}

/// Fails on its first call, then succeeds — used to verify the retry
/// action re-runs the load.
class _FailOnceRepository extends SpeciesStatisticsRepository {
  _FailOnceRepository(super.database, this._summary);

  final SpeciesStatisticsSummary _summary;
  int callCount = 0;

  @override
  Future<SpeciesStatisticsSummary> getSpeciesStatistics(
    FishSpecies species,
  ) async {
    callCount++;
    if (callCount == 1) {
      throw StateError('simulated load failure');
    }
    return _summary;
  }
}

class _StaticRepository extends SpeciesStatisticsRepository {
  _StaticRepository(super.database, this._summary);

  final SpeciesStatisticsSummary _summary;

  @override
  Future<SpeciesStatisticsSummary> getSpeciesStatistics(
    FishSpecies species,
  ) async => _summary;
}

/// Resolves normally on its first call, then returns a controllable,
/// never-auto-completing `Future` on every call after that — used to hold
/// the post-Catch-Details-return reload open long enough to dispose the
/// page mid-flight, proving `_openCatchDetails`'s `mounted` guard prevents
/// a `setState` call after disposal.
class _FirstThenPendingRepository extends SpeciesStatisticsRepository {
  _FirstThenPendingRepository(super.database, this._firstSummary);

  final SpeciesStatisticsSummary _firstSummary;
  final Completer<SpeciesStatisticsSummary> secondCallCompleter =
      Completer<SpeciesStatisticsSummary>();
  int callCount = 0;

  @override
  Future<SpeciesStatisticsSummary> getSpeciesStatistics(FishSpecies species) {
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
    tempDir = Directory.systemTemp.createTempSync('species_statistics_page');
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
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpPage(
    WidgetTester tester,
    SpeciesStatisticsRepository repository, {
    FishSpecies species = FishSpecies.pike,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: SpeciesStatisticsPage(
          species: species,
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

  FishingSpot buildFishingSpot() => FishingSpot(
    id: 'spot-1',
    name: 'Test Spot',
    latitude: 61.0,
    longitude: 25.0,
    waterBodyId: 'water-body-1',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  WaterBody buildWaterBody() => WaterBody(
    id: 'water-body-1',
    name: 'Test Water Body',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  Catch buildCatch(String id, {int? weightGrams}) => Catch(
    id: id,
    fishingSpotId: 'spot-1',
    species: FishSpecies.pike,
    caughtAt: DateTime.utc(2026, 7, 17),
    weightGrams: weightGrams,
    createdAt: DateTime.utc(2026, 7, 17),
    updatedAt: DateTime.utc(2026, 7, 17),
  );

  testWidgets(
    'shows a loading indicator while getSpeciesStatistics is in flight',
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
    final summary = SpeciesStatisticsSummary(
      species: FishSpecies.pike,
      catches: const [],
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

  testWidgets('shows the Finnish species name in the AppBar title', (
    tester,
  ) async {
    final summary = SpeciesStatisticsSummary(
      species: FishSpecies.pike,
      catches: const [],
    );
    final repository = _StaticRepository(database, summary);

    await pumpPage(tester, repository, species: FishSpecies.pike);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Hauki'), findsOneWidget);
  });

  testWidgets(
    'an empty species shows the total as 0 and empty section messages',
    (tester) async {
      final summary = SpeciesStatisticsSummary(
        species: FishSpecies.pike,
        catches: const [],
      );
      final repository = _StaticRepository(database, summary);

      await pumpPage(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
      expect(find.text('Ei vielä ennätyssaalista.'), findsOneWidget);
      expect(find.text('Ei vielä saaliita.'), findsOneWidget);
    },
  );

  testWidgets(
    'a populated summary shows the total, the Record Catch card, and the '
    'full Catch List in the given (already-sorted) order',
    (tester) async {
      final fishingSpot = buildFishingSpot();
      final waterBody = buildWaterBody();
      final entries = [
        SpeciesCatchEntry(
          catchModel: buildCatch('catch-1', weightGrams: 5000),
          fishingSpot: fishingSpot,
          waterBody: waterBody,
        ),
        SpeciesCatchEntry(
          catchModel: buildCatch('catch-2', weightGrams: 3000),
          fishingSpot: fishingSpot,
          waterBody: waterBody,
        ),
      ];
      final summary = SpeciesStatisticsSummary(
        species: FishSpecies.pike,
        catches: entries,
      );
      final repository = _StaticRepository(database, summary);

      await pumpPage(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.byType(RecordCatchCard), findsOneWidget);

      final items = tester
          .widgetList<CatchListItem>(find.byType(CatchListItem))
          .toList();
      expect(items.map((item) => item.catchModel.id).toList(), [
        'catch-1',
        'catch-2',
      ]);
    },
  );

  testWidgets(
    'a catch with no photo, weight, or length renders without a broken '
    'layout',
    (tester) async {
      final fishingSpot = buildFishingSpot();
      final waterBody = buildWaterBody();
      final entry = SpeciesCatchEntry(
        catchModel: buildCatch('catch-1'),
        fishingSpot: fishingSpot,
        waterBody: waterBody,
      );
      final summary = SpeciesStatisticsSummary(
        species: FishSpecies.pike,
        catches: [entry],
      );
      final repository = _StaticRepository(database, summary);

      await pumpPage(tester, repository);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(RecordCatchCard), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Record Catch card opens Catch Details for that catch',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final fishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: 'water-body-1',
      );
      final waterBody = buildWaterBody();
      final createdCatch = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2500,
      );

      final summary = SpeciesStatisticsSummary(
        species: FishSpecies.pike,
        catches: [
          SpeciesCatchEntry(
            catchModel: createdCatch,
            fishingSpot: fishingSpot,
            waterBody: waterBody,
          ),
        ],
      );
      final repository = _StaticRepository(database, summary);

      await pumpPage(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(RecordCatchCard));
      await tester.pumpAndSettle();

      expect(find.byType(CatchDetailsPage), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a Catch List entry opens Catch Details for that specific catch',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final fishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: 'water-body-1',
      );
      final waterBody = buildWaterBody();
      final first = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 5000,
      );
      // A bare `Future.delayed` never resolves under the widget test
      // binding's fake clock, and `tester.pump(duration)` fast-forwards
      // Flutter's own frame scheduling without letting any real wall-clock
      // time pass — `CatchRepository`'s id generation reads the real
      // `DateTime.now()`, so only a real delay run via `tester.runAsync()`
      // (the same real-IO escape hatch already established elsewhere in
      // this project's widget tests) guarantees the two catches below get
      // distinct ids.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      final second = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 1000,
      );

      final summary = SpeciesStatisticsSummary(
        species: FishSpecies.pike,
        catches: [
          SpeciesCatchEntry(
            catchModel: first,
            fishingSpot: fishingSpot,
            waterBody: waterBody,
          ),
          SpeciesCatchEntry(
            catchModel: second,
            fishingSpot: fishingSpot,
            waterBody: waterBody,
          ),
        ],
      );
      final repository = _StaticRepository(database, summary);

      await pumpPage(tester, repository);
      await tester.pumpAndSettle();

      // The Record Catch card also renders the first (heaviest) catch, so
      // tap the second Catch List entry specifically to prove navigation
      // is wired per-entry, not just to the record catch.
      final catchListItems = find.byType(CatchListItem);
      expect(catchListItems, findsNWidgets(2));
      await tester.tap(catchListItems.at(1));
      await tester.pumpAndSettle();

      expect(find.byType(CatchDetailsPage), findsOneWidget);
    },
  );

  testWidgets('reopening the page recomputes from the repository', (
    tester,
  ) async {
    final firstSummary = SpeciesStatisticsSummary(
      species: FishSpecies.pike,
      catches: const [],
    );
    final firstRepository = _StaticRepository(database, firstSummary);

    await pumpPage(tester, firstRepository);
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);

    final fishingSpot = buildFishingSpot();
    final waterBody = buildWaterBody();
    final secondSummary = SpeciesStatisticsSummary(
      species: FishSpecies.pike,
      catches: [
        SpeciesCatchEntry(
          catchModel: buildCatch('catch-1', weightGrams: 2000),
          fishingSpot: fishingSpot,
          waterBody: waterBody,
        ),
      ],
    );
    final secondRepository = _StaticRepository(database, secondSummary);

    // Tear the whole tree down first so the next pumpPage() genuinely
    // constructs a new State (and therefore a fresh initState()/_load()
    // call), matching what a real Navigator pop-then-push cycle already
    // does — reusing the same root widget shape across two direct
    // pumpWidget() calls would otherwise let Flutter's element diffing
    // reuse the existing State in place, which is not what this test means
    // to exercise. See TD-021 Key Design Decision 10 ("a fresh push...
    // re-queries from scratch").
    await tester.pumpWidget(const SizedBox.shrink());

    await pumpPage(tester, secondRepository);
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
  });

  // Returning from Catch Details — regardless of whether the catch was
  // edited, deleted, or left untouched — must refresh Species Statistics,
  // since `CatchDetailsPage.open()` has no typed changed-result to branch
  // on. These tests use the real `SpeciesStatisticsRepository` against a
  // real in-memory database, and simulate "an edit/delete happened while
  // Catch Details was open" via a direct repository mutation rather than
  // driving the full Edit Catch UI — the lifecycle fix under test does not
  // care how the underlying data changed, only that it reloads afterward.

  testWidgets(
    "editing a catch's weight while Catch Details is open is reflected in "
    'Species Statistics after returning (via the Record Catch card path)',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final fishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: 'water-body-1',
      );
      final original = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final repository = SpeciesStatisticsRepository(database);

      await pumpPage(tester, repository, species: FishSpecies.pike);
      await tester.pumpAndSettle();
      expect(find.text('2 kg'), findsNWidgets(2));

      await tester.tap(find.byType(RecordCatchCard));
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

      expect(find.byType(SpeciesStatisticsPage), findsOneWidget);
      expect(find.text('9 kg'), findsNWidgets(2));
      expect(find.text('2 kg'), findsNothing);
    },
  );

  testWidgets(
    'deleting a catch while Catch Details is open is reflected in Species '
    'Statistics after returning',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final fishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: 'water-body-1',
      );
      final toDelete = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final repository = SpeciesStatisticsRepository(database);

      await pumpPage(tester, repository, species: FishSpecies.pike);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byType(RecordCatchCard));
      await tester.pumpAndSettle();
      expect(find.byType(CatchDetailsPage), findsOneWidget);

      await catchRepository.delete(toDelete.id);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(SpeciesStatisticsPage), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Ei vielä ennätyssaalista.'), findsOneWidget);
      expect(find.text('Ei vielä saaliita.'), findsOneWidget);
    },
  );

  testWidgets(
    'deleting a catch through the real Catch Details delete action (menu, '
    'confirm dialog) is immediately reflected in Species Statistics after '
    'returning, with no extra reload needed',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final fishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: 'water-body-1',
      );
      final toDelete = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2000,
      );

      final repository = SpeciesStatisticsRepository(database);

      await pumpPage(tester, repository, species: FishSpecies.pike);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byType(RecordCatchCard));
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

      // Back on Species Statistics — assert immediately, with no manual
      // reload or extra pump beyond what the delete flow itself triggers.
      expect(find.byType(SpeciesStatisticsPage), findsOneWidget);
      expect(find.byType(CatchDetailsPage), findsNothing);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Ei vielä ennätyssaalista.'), findsOneWidget);
      expect(find.text('Ei vielä saaliita.'), findsOneWidget);
      expect(await catchRepository.getById(toDelete.id), isNull);
    },
  );

  testWidgets(
    'a refresh after returning from Catch Details can change the Record '
    'Catch and ordering (via the Catch List path)',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final fishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: 'water-body-1',
      );
      final heavier = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 5000,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      final lighter = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 1000,
      );

      final repository = SpeciesStatisticsRepository(database);

      await pumpPage(tester, repository, species: FishSpecies.pike);
      await tester.pumpAndSettle();

      var items = tester
          .widgetList<CatchListItem>(find.byType(CatchListItem))
          .toList();
      expect(items.first.catchModel.id, heavier.id);
      expect(items.last.catchModel.id, lighter.id);

      // Tap the second (lighter) Catch List entry specifically — proving
      // the Catch List navigation path also triggers the post-return
      // refresh, not only the Record Catch card path (covered above).
      final catchListItems = find.byType(CatchListItem);
      await tester.tap(catchListItems.at(1));
      await tester.pumpAndSettle();
      expect(find.byType(CatchDetailsPage), findsOneWidget);

      // While Catch Details is open, the lighter catch is edited to
      // become the heavier of the two.
      await catchRepository.update(
        catchModel: lighter,
        species: lighter.species,
        caughtAt: lighter.caughtAt,
        weightGrams: 9000,
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // The Record Catch and the Catch List order have swapped.
      items = tester
          .widgetList<CatchListItem>(find.byType(CatchListItem))
          .toList();
      expect(items.first.catchModel.id, lighter.id);
      expect(items.last.catchModel.id, heavier.id);
      expect(
        tester
            .widget<RecordCatchCard>(find.byType(RecordCatchCard))
            .entry
            .catchModel
            .id,
        lighter.id,
      );
    },
  );

  testWidgets(
    'does not call setState after the page is disposed while a post-return '
    'reload is still pending',
    (tester) async {
      final fishingSpotRepository = FishingSpotRepository(database);
      final fishingSpot = await fishingSpotRepository.create(
        name: 'Test Spot',
        latitude: 61.0,
        longitude: 25.0,
        waterBodyId: 'water-body-1',
      );
      final waterBody = buildWaterBody();
      final createdCatch = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 7, 17),
        weightGrams: 2500,
      );

      final firstSummary = SpeciesStatisticsSummary(
        species: FishSpecies.pike,
        catches: [
          SpeciesCatchEntry(
            catchModel: createdCatch,
            fishingSpot: fishingSpot,
            waterBody: waterBody,
          ),
        ],
      );
      final repository = _FirstThenPendingRepository(database, firstSummary);

      await pumpPage(tester, repository, species: FishSpecies.pike);
      await tester.pumpAndSettle();
      expect(repository.callCount, 1);

      await tester.tap(find.byType(RecordCatchCard));
      await tester.pumpAndSettle();
      expect(find.byType(CatchDetailsPage), findsOneWidget);

      // Returning triggers the post-navigation reload — now the pending,
      // never-completing second call, so the page is left showing its
      // loading state indefinitely. `pumpAndSettle()` would time out here
      // (a `CircularProgressIndicator` animates forever), so a bounded
      // pump sequence is used instead: one to process the pop, one to let
      // the route's pop transition finish.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(repository.callCount, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Dispose the whole page tree while that reload is still in flight.
      await tester.pumpWidget(const SizedBox.shrink());

      // Resolving the pending call now must not crash with "setState()
      // called after dispose()" — if `_openCatchDetails`'s `mounted` guard
      // were missing (or `_load()`'s own guard, on which it also relies),
      // this would throw.
      repository.secondCallCompleter.complete(firstSummary);
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
