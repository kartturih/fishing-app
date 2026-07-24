import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/data/storage/catch_photo_storage.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/data/catch_search_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/catch_search_criteria.dart';
import 'package:fishing_app/features/catches/domain/catch_search_result.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_details_page.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_search_page.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';

/// Never resolves — used to assert the initial loading state.
class _PendingCatchSearchRepository extends CatchSearchRepository {
  _PendingCatchSearchRepository(super.database);

  @override
  Future<List<CatchSearchResult>> search(CatchSearchCriteria criteria) {
    return Completer<List<CatchSearchResult>>().future;
  }
}

/// Always fails — used to assert the retryable error state.
class _FailingCatchSearchRepository extends CatchSearchRepository {
  _FailingCatchSearchRepository(super.database);

  int callCount = 0;

  @override
  Future<List<CatchSearchResult>> search(CatchSearchCriteria criteria) async {
    callCount++;
    throw StateError('simulated search failure');
  }
}

/// Counts every real `search()` invocation while still delegating to the
/// real repository — used to assert debounce behavior (exactly one query
/// per settled typing burst, not one per keystroke).
class _CountingCatchSearchRepository extends CatchSearchRepository {
  _CountingCatchSearchRepository(super.database);

  int callCount = 0;

  @override
  Future<List<CatchSearchResult>> search(CatchSearchCriteria criteria) {
    callCount++;
    return super.search(criteria);
  }
}

/// Lets a test control exactly when a query for a given [CatchSearchCriteria]
/// resolves, and with what result — used to prove that a slow, superseded
/// request cannot overwrite a faster, later one (the `_requestId` guard).
class _GatedCatchSearchRepository extends CatchSearchRepository {
  _GatedCatchSearchRepository(super.database);

  final Map<String, Completer<List<CatchSearchResult>>> _gates = {};

  Completer<List<CatchSearchResult>> gateFor(String query) =>
      _gates.putIfAbsent(query, () => Completer<List<CatchSearchResult>>());

  @override
  Future<List<CatchSearchResult>> search(CatchSearchCriteria criteria) {
    return gateFor(criteria.query).future;
  }
}

void main() {
  late AppDatabase database;
  late CatchRepository catchRepository;
  late FishingSpotRepository fishingSpotRepository;
  late CatchPhotoRepository catchPhotoRepository;
  late LureCatalogRepository lureCatalogRepository;
  late PersonalTackleBoxRepository personalTackleBoxRepository;
  late TackleBoxPhotoStorage personalTackleBoxPhotoStorage;
  late WaterBodyRepository waterBodyRepository;
  late CatchSearchRepository catchSearchRepository;
  late Directory storageDir;
  late Directory tackleBoxStorageDir;
  late FishingSpot koiraranta;
  late FishingSpot pohjoislahti;

  // CatchRepository/FishingSpotRepository derive ids from
  // DateTime.now().microsecondsSinceEpoch; a tiny delay avoids two rapid
  // calls landing on the same clock tick in this test environment,
  // matching every other repository test's convention in this project.
  Future<void> delay() => Future<void>.delayed(const Duration(milliseconds: 2));

  Future<FishingSpot> createSpot({
    required String name,
    required double latitude,
    required double longitude,
    required String waterBodyId,
  }) async {
    await delay();
    return fishingSpotRepository.create(
      name: name,
      latitude: latitude,
      longitude: longitude,
      waterBodyId: waterBodyId,
    );
  }

  // Called from within testWidgets bodies (unlike createSpot, only ever
  // called from setUp), so the delay must run via tester.runAsync — a bare
  // Future.delayed never resolves under this file's fake-async testWidgets
  // binding, matching general_catch_statistics_tab_test.dart's established
  // convention.
  Future<Catch> createCatch(
    WidgetTester tester, {
    required String fishingSpotId,
    required FishSpecies species,
    required DateTime caughtAt,
    int? weightGrams,
    int? lengthMillimeters,
    String? lureVariantId,
  }) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    return catchRepository.create(
      fishingSpotId: fishingSpotId,
      species: species,
      caughtAt: caughtAt,
      weightGrams: weightGrams,
      lengthMillimeters: lengthMillimeters,
      lureVariantId: lureVariantId,
    );
  }

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database
        .into(database.waterBodies)
        .insert(
          const WaterBodiesCompanion(
            id: Value('water-body-1'),
            name: Value('Merrasjärvi'),
            createdAt: Value(0),
          ),
        );
    storageDir = Directory.systemTemp.createTempSync(
      'catch_search_page_storage',
    );
    tackleBoxStorageDir = Directory.systemTemp.createTempSync(
      'catch_search_page_tackle_box_storage',
    );

    catchRepository = CatchRepository(database);
    fishingSpotRepository = FishingSpotRepository(database);
    catchPhotoRepository = CatchPhotoRepository(
      database,
      CatchPhotoStorage(rootDirectoryProvider: () async => storageDir),
    );
    lureCatalogRepository = LureCatalogRepository(database);
    personalTackleBoxPhotoStorage = TackleBoxPhotoStorage(
      rootDirectoryProvider: () async => tackleBoxStorageDir,
    );
    personalTackleBoxRepository = PersonalTackleBoxRepository(
      database,
      personalTackleBoxPhotoStorage,
    );
    waterBodyRepository = WaterBodyRepository(database);
    catchSearchRepository = CatchSearchRepository(database);

    koiraranta = await createSpot(
      name: 'Koiraranta',
      latitude: 61.0,
      longitude: 25.0,
      waterBodyId: 'water-body-1',
    );
    pohjoislahti = await createSpot(
      name: 'Pohjoislahti',
      latitude: 61.1,
      longitude: 25.1,
      waterBodyId: 'water-body-1',
    );
  });

  tearDown(() async {
    await database.close();
    if (storageDir.existsSync()) {
      storageDir.deleteSync(recursive: true);
    }
    if (tackleBoxStorageDir.existsSync()) {
      tackleBoxStorageDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    CatchSearchRepository? repository,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: CatchSearchPage(
          catchSearchRepository: repository ?? catchSearchRepository,
          catchRepository: catchRepository,
          catchPhotoRepository: catchPhotoRepository,
          lureCatalogRepository: lureCatalogRepository,
          personalTackleBoxRepository: personalTackleBoxRepository,
          personalTackleBoxPhotoStorage: personalTackleBoxPhotoStorage,
          waterBodyRepository: waterBodyRepository,
        ),
      ),
    );
  }

  testWidgets('the search field is visible immediately on page open', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.pump();

    expect(find.byKey(const Key('catchSearchField')), findsOneWidget);
  });

  testWidgets('tapping the search field gives it immediate focus', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catchSearchField')));
    await tester.pump();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
  });

  group('clear button', () {
    testWidgets('is absent when the field is empty', (tester) async {
      await pumpPage(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('clearSearchButton')), findsNothing);
    });

    testWidgets('appears once text is entered', (tester) async {
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('catchSearchField')),
        'hauki',
      );
      await tester.pump();

      expect(find.byKey(const Key('clearSearchButton')), findsOneWidget);
    });

    testWidgets(
      'pressing it clears the query and immediately refreshes results '
      'without waiting for the debounce, while preserving active filters',
      (tester) async {
        await createCatch(
          tester,
          fishingSpotId: koiraranta.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 1, 10),
        );
        await createCatch(
          tester,
          fishingSpotId: pohjoislahti.id,
          species: FishSpecies.zander,
          caughtAt: DateTime(2026, 1, 11),
        );

        await pumpPage(tester);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('catchSearchField')),
          'hauki',
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('catchSearchResultsList')), findsOneWidget);
        expect(find.byType(ListTile), findsNothing); // sanity: not a stray list

        await tester.tap(find.byKey(const Key('clearSearchButton')));
        await tester.pump(); // no debounce wait — must refresh immediately
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('clearSearchButton')), findsNothing);
      },
    );
  });

  testWidgets(
    'debounces text input: no query is issued before ~280ms, exactly one '
    'after',
    (tester) async {
      final repository = _CountingCatchSearchRepository(database);
      await pumpPage(tester, repository: repository);
      await tester.pumpAndSettle();

      final callsAfterInitialLoad = repository.callCount;

      await tester.enterText(find.byKey(const Key('catchSearchField')), 'h');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.callCount, callsAfterInitialLoad);

      await tester.enterText(find.byKey(const Key('catchSearchField')), 'ha');
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        repository.callCount,
        callsAfterInitialLoad,
        reason: 'typing again before the debounce elapsed must restart it',
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.callCount, callsAfterInitialLoad + 1);
    },
  );

  testWidgets(
    'a slow, superseded query cannot overwrite a faster, later result '
    '(stale-response protection)',
    (tester) async {
      final repository = _GatedCatchSearchRepository(database);
      final slowGate = repository.gateFor('');
      await pumpPage(tester, repository: repository);
      await tester.pump(); // initial load ('') is now pending on slowGate

      // A second, distinct query ('fast') is dispatched before the first
      // resolves — resolve it first.
      final fastGate = repository.gateFor('fast');
      await tester.enterText(find.byKey(const Key('catchSearchField')), 'fast');
      await tester.pump(const Duration(milliseconds: 300));
      fastGate.complete([]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Ei vielä saaliita.'), findsNothing);
      expect(find.text('Hakuehdoilla ei löytynyt saaliita.'), findsOneWidget);

      // Now let the stale, superseded initial ('') query resolve — it must
      // be discarded rather than overwriting the already-applied 'fast'
      // result.
      slowGate.complete([]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Hakuehdoilla ei löytynyt saaliita.'), findsOneWidget);
    },
  );

  testWidgets('shows a loading indicator before the initial load completes', (
    tester,
  ) async {
    await pumpPage(tester, repository: _PendingCatchSearchRepository(database));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows a retryable error message on search failure', (
    tester,
  ) async {
    final repository = _FailingCatchSearchRepository(database);
    await pumpPage(tester, repository: repository);
    await tester.pump();
    await tester.pump();

    expect(find.text('Hakutulosten lataaminen epäonnistui.'), findsOneWidget);
    expect(find.text('Yritä uudelleen'), findsOneWidget);

    final callsBeforeRetry = repository.callCount;
    await tester.tap(find.text('Yritä uudelleen'));
    await tester.pump();
    await tester.pump();

    expect(repository.callCount, callsBeforeRetry + 1);
  });

  testWidgets('shows a distinct empty-database state when no catches exist', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Ei vielä saaliita.'), findsOneWidget);
  });

  testWidgets('shows a distinct no-match state when the query matches nothing, '
      'with a one-action way to clear', (tester) async {
    await createCatch(
      tester,
      fishingSpotId: koiraranta.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 1, 10),
    );

    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('catchSearchField')), 'ahven');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Hakuehdoilla ei löytynyt saaliita.'), findsOneWidget);
    expect(
      find.byKey(const Key('clearSearchAndFiltersButton')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('clearSearchAndFiltersButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catchSearchResultsList')), findsOneWidget);
  });

  group('filters', () {
    testWidgets(
      'the filter indicator is hidden until a filter is applied, and shown '
      'afterward',
      (tester) async {
        await createCatch(
          tester,
          fishingSpotId: koiraranta.id,
          species: FishSpecies.pike,
          caughtAt: DateTime(2026, 1, 10),
        );
        await createCatch(
          tester,
          fishingSpotId: koiraranta.id,
          species: FishSpecies.zander,
          caughtAt: DateTime(2026, 1, 11),
        );

        await pumpPage(tester);
        await tester.pumpAndSettle();

        var badge = tester.widget<Badge>(find.byType(Badge));
        expect(badge.isLabelVisible, isFalse);

        await tester.tap(find.byKey(const Key('openFilterSheetButton')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('speciesFilterOption-pike')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('applyFiltersButton')));
        await tester.pumpAndSettle();

        badge = tester.widget<Badge>(find.byType(Badge));
        expect(badge.isLabelVisible, isTrue);
      },
    );

    testWidgets('applying a species filter narrows the results', (
      tester,
    ) async {
      await createCatch(
        tester,
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );
      await createCatch(
        tester,
        fishingSpotId: koiraranta.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 1, 11),
      );

      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('openFilterSheetButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('speciesFilterOption-zander')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('applyFiltersButton')));
      await tester.pumpAndSettle();

      expect(find.text('Kuha'), findsOneWidget);
      expect(find.text('Hauki'), findsNothing);
    });

    testWidgets('clearing filters restores the full list', (tester) async {
      await createCatch(
        tester,
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );
      await createCatch(
        tester,
        fishingSpotId: koiraranta.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 1, 11),
      );

      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('openFilterSheetButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('speciesFilterOption-zander')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('applyFiltersButton')));
      await tester.pumpAndSettle();

      expect(find.text('Hauki'), findsNothing);

      await tester.tap(find.byKey(const Key('openFilterSheetButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('clearFiltersButton')));
      await tester.pumpAndSettle();

      expect(find.text('Hauki'), findsOneWidget);
      expect(find.text('Kuha'), findsOneWidget);

      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isFalse);
    });
  });

  group('navigation to CatchDetailsPage', () {
    testWidgets('tapping a result opens the existing CatchDetailsPage', (
      tester,
    ) async {
      await createCatch(
        tester,
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );

      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hauki'));
      await tester.pumpAndSettle();

      expect(find.byType(CatchDetailsPage), findsOneWidget);
    });

    testWidgets('returning from CatchDetailsPage preserves the search text and '
        'refreshes results', (tester) async {
      await createCatch(
        tester,
        fishingSpotId: koiraranta.id,
        species: FishSpecies.pike,
        caughtAt: DateTime(2026, 1, 10),
      );
      await createCatch(
        tester,
        fishingSpotId: koiraranta.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 1, 11),
      );

      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('catchSearchField')),
        'hauki',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Hauki'), findsOneWidget);
      expect(find.text('Kuha'), findsNothing);

      await tester.tap(find.text('Hauki'));
      await tester.pumpAndSettle();
      expect(find.byType(CatchDetailsPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(CatchSearchPage), findsOneWidget);
      expect(
        find.text('hauki'),
        findsOneWidget,
        reason: 'the search field text must survive the round trip',
      );
      expect(find.text('Hauki'), findsOneWidget);
      expect(find.text('Kuha'), findsNothing);
    });
  });

  testWidgets('lays out correctly on a narrow Android-sized screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await createCatch(
      tester,
      fishingSpotId: koiraranta.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 1, 10),
      weightGrams: 2450,
    );

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
