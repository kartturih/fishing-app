import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_catalog_list_page.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_model_details_page.dart';

/// Never completes `ensureSeeded`, so the loading state can be observed
/// deterministically. Mirrors `_PendingCatchRepository` in
/// fishing_spot_details_bottom_sheet_test.dart.
class _PendingLureCatalogRepository extends LureCatalogRepository {
  _PendingLureCatalogRepository(super.database);

  final Completer<void> pendingSeed = Completer<void>();

  @override
  Future<void> ensureSeeded() => pendingSeed.future;
}

class _FailingLureCatalogRepository extends LureCatalogRepository {
  _FailingLureCatalogRepository(super.database);

  @override
  Future<void> ensureSeeded() async {
    throw StateError('simulated seeding failure');
  }
}

/// Lets a test control exactly when each `browse()` call completes and with
/// what result, so an older request can be made to resolve after a newer
/// one — proving the page discards stale, out-of-order results.
class _ControllableBrowseLureCatalogRepository extends LureCatalogRepository {
  _ControllableBrowseLureCatalogRepository(super.database);

  final List<Completer<List<LureCatalogEntry>>> _pendingBrowseCalls = [];

  @override
  Future<List<LureCatalogEntry>> browse({
    String? searchText,
    String? manufacturer,
    String? lureType,
  }) {
    final completer = Completer<List<LureCatalogEntry>>();
    _pendingBrowseCalls.add(completer);
    return completer.future;
  }

  /// Completes the [index]-th `browse()` call (in call order) with [entries].
  void completeBrowseCall(int index, List<LureCatalogEntry> entries) {
    _pendingBrowseCalls[index].complete(entries);
  }
}

Future<void> pumpListPage(
  WidgetTester tester,
  LureCatalogRepository repository, {
  Future<Set<String>> Function()? loadOwnedLureVariantIds,
}) async {
  // Tall enough that every seed item renders without scrolling — the seed
  // catalog has more entries than fit in the default test viewport, and
  // ListView.builder only builds visible children.
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: LureCatalogListPage(
        repository: repository,
        loadOwnedLureVariantIds: loadOwnedLureVariantIds,
      ),
    ),
  );
}

/// The "Abu Garcia Toby" seed model's three variant ids, used to exercise
/// ownership badge/filter behavior against real seed data. The model is
/// only "fully owned" (MFS-018 FR-8) when all three are in the owned set.
const _abuGarciaTobySilverId = '2de7edb3-b772-40c9-a51c-75c5f20c233f';
const _abuGarciaTobyCopperId = '20aa5fab-19d8-4163-85fd-e0fef63ea3c6';
const _abuGarciaTobyFiretigerId = '09fedc45-c024-4008-bcb1-ff1d4a398c66';
const _abuGarciaTobyAllVariantIds = {
  _abuGarciaTobySilverId,
  _abuGarciaTobyCopperId,
  _abuGarciaTobyFiretigerId,
};

void main() {
  late AppDatabase database;
  late LureCatalogRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LureCatalogRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('shows a loading indicator while seeding/loading is pending', (
    tester,
  ) async {
    final pendingRepository = _PendingLureCatalogRepository(database);

    await pumpListPage(tester, pendingRepository);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pendingRepository.pendingSeed.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('renders the full seed catalog after loading', (tester) async {
    await pumpListPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lureCatalogList')), findsOneWidget);
    expect(find.text('Rapala X-Rap Shad XRS08'), findsWidgets);
    expect(find.text('Abu Garcia Toby'), findsWidgets);
  });

  testWidgets(
    'groups every variant of a model into a single row, not one per variant',
    (tester) async {
      await pumpListPage(tester, repository);
      await tester.pumpAndSettle();

      // The seed "Abu Garcia Toby" model has 3 variants (Silver, Copper,
      // Firetiger); the browsing list must show exactly one row for the
      // model, not three (MFS-018's primary grouping requirement).
      expect(find.text('Abu Garcia Toby'), findsOneWidget);
    },
  );

  testWidgets('typing a search term narrows the list', (tester) async {
    await pumpListPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('lureCatalogSearchField')),
      'Toby',
    );
    await tester.pumpAndSettle();

    expect(find.text('Abu Garcia Toby'), findsWidgets);
    expect(find.text('Rapala X-Rap Shad XRS08'), findsNothing);
  });

  testWidgets('search matches a Finnish ä/ö term regardless of case', (
    tester,
  ) async {
    await database
        .into(database.lureModels)
        .insert(
          LureModelsCompanion.insert(
            id: 'fi-model',
            manufacturer: 'Äijänpää',
            modelName: 'Örvelö',
            lureType: 'spoon',
            searchText: 'äijänpää örvelö',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await database
        .into(database.lureVariants)
        .insert(
          LureVariantsCompanion.insert(
            id: 'fi-variant',
            lureModelId: 'fi-model',
            colorName: const Value('Sinivihreä'),
            searchText: 'sinivihreä',
            createdAt: 1,
            updatedAt: 1,
          ),
        );

    await pumpListPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('lureCatalogSearchField')),
      'SINIVIHREÄ',
    );
    await tester.pumpAndSettle();

    expect(find.text('Äijänpää Örvelö'), findsOneWidget);
  });

  testWidgets('selecting a manufacturer filter narrows the list', (
    tester,
  ) async {
    await pumpListPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('lureCatalogManufacturerFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abu Garcia').last);
    await tester.pumpAndSettle();

    expect(find.text('Abu Garcia Toby'), findsWidgets);
    expect(find.text('Rapala X-Rap Shad XRS08'), findsNothing);
  });

  testWidgets('selecting a lure-type filter narrows the list', (tester) async {
    await pumpListPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('lureCatalogLureTypeFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jigi').last);
    await tester.pumpAndSettle();

    expect(find.text('Rapala Jigging Rap W5'), findsWidgets);
    expect(find.text('Abu Garcia Toby'), findsNothing);
  });

  testWidgets('clearing a filter restores the wider list', (tester) async {
    await pumpListPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('lureCatalogManufacturerFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abu Garcia').last);
    await tester.pumpAndSettle();
    expect(find.text('Rapala X-Rap Shad XRS08'), findsNothing);

    await tester.tap(find.byKey(const Key('lureCatalogManufacturerFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaikki valmistajat').last);
    await tester.pumpAndSettle();

    expect(find.text('Rapala X-Rap Shad XRS08'), findsWidgets);
  });

  testWidgets('shows an empty-result message for no matches', (tester) async {
    await pumpListPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('lureCatalogSearchField')),
      'no such lure exists anywhere',
    );
    await tester.pumpAndSettle();

    expect(find.text('Ei tuloksia hakuehdoilla.'), findsOneWidget);
  });

  testWidgets('shows an error message when the repository throws', (
    tester,
  ) async {
    final failingRepository = _FailingLureCatalogRepository(database);

    await pumpListPage(tester, failingRepository);
    await tester.pumpAndSettle();

    expect(find.text('Viehekatalogin lataaminen epäonnistui.'), findsOneWidget);
  });

  testWidgets('tapping a model row opens LureModelDetailsPage for that model', (
    tester,
  ) async {
    await pumpListPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abu Garcia Toby').first);
    await tester.pumpAndSettle();

    expect(find.byType(LureModelDetailsPage), findsOneWidget);
    final page = tester.widget<LureModelDetailsPage>(
      find.byType(LureModelDetailsPage),
    );
    expect(page.modelEntry.manufacturer, 'Abu Garcia');
    // All 3 seed variants of this model, not just the one that was
    // visible/tapped in the browsing list (MFS-018 FR-6).
    expect(page.variants, hasLength(3));
  });

  testWidgets(
    'a search matching only one variant still surfaces the whole model, '
    'and opening it shows every variant',
    (tester) async {
      await pumpListPage(tester, repository);
      await tester.pumpAndSettle();

      // "Firetiger" matches only one of the Toby model's 3 variants.
      await tester.enterText(
        find.byKey(const Key('lureCatalogSearchField')),
        'Firetiger',
      );
      await tester.pumpAndSettle();

      expect(find.text('Abu Garcia Toby'), findsOneWidget);

      await tester.tap(find.text('Abu Garcia Toby').first);
      await tester.pumpAndSettle();

      final page = tester.widget<LureModelDetailsPage>(
        find.byType(LureModelDetailsPage),
      );
      expect(page.variants, hasLength(3));
    },
  );

  testWidgets(
    "an older search request cannot overwrite a newer request's result",
    (tester) async {
      final controllableRepository = _ControllableBrowseLureCatalogRepository(
        database,
      );

      await pumpListPage(tester, controllableRepository);
      await tester.pump();
      await tester.pump();

      // Complete the initial load's browse() call (request #0) so the page
      // finishes loading.
      controllableRepository.completeBrowseCall(0, const []);
      await tester.pump();
      await tester.pump();

      // Two searches in quick succession: request #1 (older) then request
      // #2 (newer). Neither browse() call completes on its own.
      await tester.enterText(
        find.byKey(const Key('lureCatalogSearchField')),
        'first',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('lureCatalogSearchField')),
        'second',
      );
      await tester.pump();

      LureCatalogEntry buildEntry(String id, String modelName) {
        return LureCatalogEntry(
          variant: LureVariant(
            id: id,
            lureModelId: id,
            colorName: 'Color',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
          manufacturer: 'Test Manufacturer',
          modelName: modelName,
          lureType: 'crankbait',
          modelDefaultImageReference: null,
        );
      }

      // The newer request (#2) completes first; the older request (#1)
      // resolves afterwards, simulating out-of-order completion. Model
      // rows only show manufacturer/model text now, so the two results are
      // distinguished by model name rather than variant color.
      controllableRepository.completeBrowseCall(2, [
        buildEntry('newer-model', 'Newer Model'),
      ]);
      await tester.pump();
      await tester.pump();

      controllableRepository.completeBrowseCall(1, [
        buildEntry('older-model', 'Older Model'),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Manufacturer Newer Model'), findsOneWidget);
      expect(find.text('Test Manufacturer Older Model'), findsNothing);
    },
  );

  testWidgets(
    'does not show an owned badge or hide-owned filter without an ownership callback',
    (tester) async {
      await pumpListPage(tester, repository);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ownedBadge')), findsNothing);
      expect(find.byKey(const Key('lureCatalogHideOwnedFilter')), findsNothing);
    },
  );

  testWidgets(
    'shows no owned badge when only some of a model\'s variants are owned',
    (tester) async {
      await pumpListPage(
        tester,
        repository,
        loadOwnedLureVariantIds: () async => {_abuGarciaTobySilverId},
      );
      await tester.pumpAndSettle();

      // MFS-018 FR-8 / TD-018 §2: a model-level badge only appears when
      // *every* non-retired variant of the model is owned.
      expect(find.byKey(const Key('ownedBadge')), findsNothing);
    },
  );

  testWidgets('shows an owned badge when every variant of a model is owned', (
    tester,
  ) async {
    await pumpListPage(
      tester,
      repository,
      loadOwnedLureVariantIds: () async => _abuGarciaTobyAllVariantIds,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ownedBadge')), findsOneWidget);
  });

  testWidgets(
    '"hide owned" hides a fully-owned model but keeps a partially-owned one',
    (tester) async {
      await pumpListPage(
        tester,
        repository,
        loadOwnedLureVariantIds: () async => {_abuGarciaTobySilverId},
      );
      await tester.pumpAndSettle();
      expect(find.text('Abu Garcia Toby'), findsOneWidget);

      await tester.tap(find.byKey(const Key('lureCatalogHideOwnedFilter')));
      await tester.pumpAndSettle();

      // Only one of three variants is owned: the model still has an
      // addable variant, so it must not be hidden.
      expect(find.text('Abu Garcia Toby'), findsOneWidget);
    },
  );

  testWidgets('"hide owned" hides a model once every variant is owned', (
    tester,
  ) async {
    await pumpListPage(
      tester,
      repository,
      loadOwnedLureVariantIds: () async => _abuGarciaTobyAllVariantIds,
    );
    await tester.pumpAndSettle();
    expect(find.text('Abu Garcia Toby'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lureCatalogHideOwnedFilter')));
    await tester.pumpAndSettle();

    expect(find.text('Abu Garcia Toby'), findsNothing);
  });

  testWidgets('opening details and returning refreshes the owned badge', (
    tester,
  ) async {
    var owned = <String>{};
    await pumpListPage(
      tester,
      repository,
      loadOwnedLureVariantIds: () async => owned,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ownedBadge')), findsNothing);

    // Simulate every variant of the model having been added while its
    // details were open.
    owned = _abuGarciaTobyAllVariantIds;

    await tester.tap(find.text('Abu Garcia Toby').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ownedBadge')), findsOneWidget);
  });
}
