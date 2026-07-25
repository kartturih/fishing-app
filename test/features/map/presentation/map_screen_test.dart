import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fishing_app/core/map/base_map.dart';
import 'package:fishing_app/core/map/base_map_preference_store.dart';
import 'package:fishing_app/features/catches/data/catch_search_repository.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_search_page.dart';
import 'package:fishing_app/features/map/presentation/map_screen.dart';
import 'package:fishing_app/features/map/presentation/widgets/base_map_layers_control.dart';
import 'package:fishing_app/features/map/presentation/widgets/base_map_selector_panel.dart';
import 'package:fishing_app/features/map/presentation/widgets/lure_tools_page.dart';
import 'package:fishing_app/features/map/presentation/widgets/map_attribution.dart';
import 'package:fishing_app/features/map/presentation/widgets/map_controls.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/statistics_page.dart';

/// Covers `MapScreen`'s AppBar entry points (MFS-025 / TD-025 §7) and the
/// selectable MML base-map feature (MFS-026 / TD-026): the new upper-right
/// layers control and its selector, default/persisted base-map loading,
/// switching, and regression coverage confirming every pre-existing entry
/// point/control is unaffected.
///
/// `MapScreen` embeds a `MapLibreMap` platform view, which keeps
/// perpetually scheduling frames in this headless test environment (no
/// real native map surface backs it) — `tester.pumpAndSettle()` therefore
/// never settles and times out. Every pump in this file uses a bounded,
/// explicit number of frames/duration instead, exactly as this project's
/// existing convention already does for other never-settling widgets.
///
/// `MapScreen.initState` now performs genuine `dart:io` file I/O (writing
/// the MML style document to a temporary directory) before revealing the
/// map — real asynchronous I/O resolves on the actual event loop, not on
/// `tester.pump()`'s microtask flush alone, so `pumpMapScreen` interleaves
/// bounded `tester.runAsync` real-time windows with pumps, stopping the
/// moment the loading gate (`CircularProgressIndicator`) clears, following
/// the same established real-I/O pattern already used elsewhere in this
/// project (e.g. `edit_catch_bottom_sheet_test.dart`). `path_provider`'s
/// real platform channel is never touched: `MapScreen`'s
/// `temporaryDirectoryProvider` is overridden to a plain `Directory.systemTemp`
/// getter, mirroring the existing `rootDirectoryProvider` injection pattern
/// already used by `CatchPhotoStorage`/`TackleBoxPhotoStorage`.
///
/// Once the map has mounted, no further `tester.runAsync` call is made:
/// `MapScreen` also constructs a real (uninjected) `AppDatabase()`, whose
/// underlying `drift_flutter` connection lazily reaches for the real
/// `path_provider` platform channel in the background: opening a
/// `tester.runAsync` real-time window while that pending, uninjected
/// database connection is outstanding lets it fire during the test and
/// crash it with an unrelated `MissingPluginException` — a pre-existing
/// `MapScreen`/`AppDatabase` testability gap, not something this milestone
/// introduces or is scoped to fix. Base-map switching (which happens after
/// the map has already mounted) is therefore only ever exercised with plain
/// `tester.pump()` calls, and only asserts on effects that do not require
/// waiting for the real style-file write to settle (the selector closing;
/// the persisted preference, itself backed by a pure in-memory
/// `SharedPreferences` mock with no real I/O) — the style-file-write
/// mechanism itself is already covered by the initial-load tests below and
/// by `mml_style_factory_test.dart`.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<Directory> fakeTemporaryDirectory() async => Directory.systemTemp;

  Future<void> pumpMapScreen(
    WidgetTester tester, {
    BaseMapPreferenceStore baseMapPreferenceStore =
        const BaseMapPreferenceStore(),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          temporaryDirectoryProvider: fakeTemporaryDirectory,
          baseMapPreferenceStore: baseMapPreferenceStore,
        ),
      ),
    );
    await tester.pump();
    // Let the real event loop actually complete the preference read and
    // style-file write `_initializeBaseMap` performs. Stops as soon as the
    // loading gate clears — no `runAsync` call is made once `MapLibreMap`
    // has mounted (see file-level doc comment).
    for (var i = 0; i < 10; i++) {
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    // The embedded MapLibreMap schedules a short-lived platform-view-
    // initialization timer in this headless test environment; letting one
    // more bounded frame elapse gives it a chance to fire and clear itself
    // before the test's teardown asserts no pending timers remain.
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Taps and advances just enough frames for a pushed `MaterialPageRoute`
  /// to complete its transition and become findable, without ever calling
  /// `pumpAndSettle()`.
  Future<void> tapAndAwaitPush(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'the AppBar exposes the Lure Tools, Statistics, and Catch Search actions',
    (tester) async {
      await pumpMapScreen(tester);

      expect(find.byKey(const Key('openLureToolsButton')), findsOneWidget);
      expect(find.byKey(const Key('openStatisticsButton')), findsOneWidget);
      expect(find.byKey(const Key('openCatchSearchButton')), findsOneWidget);
    },
  );

  testWidgets('the Catch Search action uses Icons.search with the tooltip '
      '"Etsi saaliita"', (tester) async {
    await pumpMapScreen(tester);

    final button = tester.widget<IconButton>(
      find.byKey(const Key('openCatchSearchButton')),
    );

    expect((button.icon as Icon).icon, Icons.search);
    expect(button.tooltip, 'Etsi saaliita');
  });

  testWidgets('tapping the Catch Search action opens CatchSearchPage', (
    tester,
  ) async {
    await pumpMapScreen(tester);

    await tapAndAwaitPush(
      tester,
      find.byKey(const Key('openCatchSearchButton')),
    );

    expect(find.byType(CatchSearchPage), findsOneWidget);
  });

  testWidgets('CatchSearchPage receives a CatchSearchRepository through the '
      'documented MapScreen wiring', (tester) async {
    await pumpMapScreen(tester);

    await tapAndAwaitPush(
      tester,
      find.byKey(const Key('openCatchSearchButton')),
    );

    final page = tester.widget<CatchSearchPage>(find.byType(CatchSearchPage));

    expect(page.catchSearchRepository, isA<CatchSearchRepository>());
  });

  testWidgets(
    'the pre-existing Lure Tools action remains present and still opens '
    'LureToolsPage',
    (tester) async {
      await pumpMapScreen(tester);

      await tapAndAwaitPush(
        tester,
        find.byKey(const Key('openLureToolsButton')),
      );

      expect(find.byType(LureToolsPage), findsOneWidget);
    },
  );

  testWidgets(
    'the pre-existing Statistics action remains present and still opens '
    'StatisticsPage',
    (tester) async {
      await pumpMapScreen(tester);

      await tapAndAwaitPush(
        tester,
        find.byKey(const Key('openStatisticsButton')),
      );

      expect(find.byType(StatisticsPage), findsOneWidget);
    },
  );

  group('selectable MML base maps (MFS-026 / TD-026)', () {
    testWidgets(
      'Maastokartta is selected by default when no preference is stored',
      (tester) async {
        await pumpMapScreen(tester);

        // Asserting via `MapAttribution.baseMap` rather than the style
        // file's content: this test suite supplies no `MML_API_KEY`
        // `--dart-define` (the correct, intentional default per TD-026 §8),
        // so `MmlConfig.isMissing` is true and every base map falls back to
        // the same blank style file (by design — see FR-16/§9) — the style
        // file therefore cannot distinguish which `BaseMap` is selected in
        // this environment, but `MapAttribution` reflects the real
        // selection regardless of whether real MML imagery loads.
        final attribution = tester.widget<MapAttribution>(
          find.byType(MapAttribution),
        );
        expect(attribution.baseMap, BaseMap.maastokartta);
      },
    );

    testWidgets('a persisted Ilmakuva preference is restored on load', (
      tester,
    ) async {
      await const BaseMapPreferenceStore().save(BaseMap.ilmakuva);

      await pumpMapScreen(tester);

      final attribution = tester.widget<MapAttribution>(
        find.byType(MapAttribution),
      );
      expect(attribution.baseMap, BaseMap.ilmakuva);
    });

    testWidgets(
      'a directory-provider failure does not hang the app on its loading '
      'gate (architecture review: disk-write fallback)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MapScreen(
              temporaryDirectoryProvider: () async =>
                  throw const FileSystemException('simulated disk failure'),
            ),
          ),
        );
        await tester.pump();
        for (var i = 0; i < 10; i++) {
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
            break;
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 500));

        // The loading gate must clear and the real screen must render even
        // though every attempt to write a style file fails.
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byKey(const Key('openLureToolsButton')), findsOneWidget);
      },
    );

    testWidgets(
      'the layers control is reachable from the map and opens the selector',
      (tester) async {
        await pumpMapScreen(tester);

        expect(find.byType(BaseMapLayersControl), findsOneWidget);
        expect(find.byType(BaseMapSelectorPanel), findsNothing);

        await tester.tap(find.byKey(const Key('baseMapLayersButton')));
        await tester.pump();

        expect(find.byType(BaseMapSelectorPanel), findsOneWidget);
        // Options are image-only (MFS-026 polish pass) — no visible text
        // labels — so presence is checked via their keys, not find.text.
        expect(
          find.byKey(const Key('baseMapOption-maastokartta')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('baseMapOption-ilmakuva')), findsOneWidget);
      },
    );

    testWidgets('selecting Ilmakuva from the selector closes the selector '
        'immediately and persists the choice (no separate save/apply step)', (
      tester,
    ) async {
      await pumpMapScreen(tester);

      await tester.tap(find.byKey(const Key('baseMapLayersButton')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('baseMapOption-ilmakuva')));
      // Plain pumps only (see file-level doc comment) — sufficient here
      // since neither assertion below depends on the real style-file
      // write settling: the selector's closing is a synchronous setState,
      // and the preference store is a pure in-memory mock with no real
      // I/O. The style-file mechanism itself is covered separately by
      // the initial-load tests above and by `mml_style_factory_test.dart`.
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(find.byType(BaseMapSelectorPanel), findsNothing);
      expect(await const BaseMapPreferenceStore().load(), BaseMap.ilmakuva);
    });

    testWidgets('tapping outside the open selector dismisses it', (
      tester,
    ) async {
      await pumpMapScreen(tester);

      await tester.tap(find.byKey(const Key('baseMapLayersButton')));
      await tester.pump();
      expect(find.byType(BaseMapSelectorPanel), findsOneWidget);

      // Tap a point far from the control/panel, still inside the map area.
      await tester.tapAt(const Offset(20, 500));
      await tester.pump();

      expect(find.byType(BaseMapSelectorPanel), findsNothing);
    });

    testWidgets(
      'the existing bottom-right MapControls remain present and unchanged',
      (tester) async {
        await pumpMapScreen(tester);

        expect(find.byType(MapControls), findsOneWidget);
      },
    );

    testWidgets(
      'rapid switching persists only the latest selection, even when an '
      'older save completes after a newer one (architecture review: '
      'base-map preference persistence race)',
      (tester) async {
        final store = _ReorderingBaseMapPreferenceStore();
        await pumpMapScreen(tester, baseMapPreferenceStore: store);

        // First rapid selection: Maastokartta -> Ilmakuva. Its save() is
        // intercepted and deliberately not allowed to complete yet.
        await tester.tap(find.byKey(const Key('baseMapLayersButton')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('baseMapOption-ilmakuva')));
        await tester.pump();

        // Second, immediately-following selection back to Maastokartta —
        // the only possible "second distinct selection" with just two base
        // maps, made before the first selection's save() has completed.
        await tester.tap(find.byKey(const Key('baseMapLayersButton')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('baseMapOption-maastokartta')));
        await tester.pump();

        expect(store.pendingCount, 2);

        // Complete out of order: the *newer* request's save finishes
        // first, then the *older* one finishes after it — exactly the race
        // the fix must handle.
        store.resolve(1);
        await tester.pump();
        store.resolve(0);
        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }

        // Regardless of completion order, the persisted value must match
        // the latest accepted selection (Maastokartta), not whichever save
        // happened to finish writing last.
        expect(
          await const BaseMapPreferenceStore().load(),
          BaseMap.maastokartta,
        );
      },
    );
  });
}

/// A `BaseMapPreferenceStore` test double that lets a test control exactly
/// when the first two `save()` calls complete, to deterministically
/// reproduce out-of-order completion of concurrent persistence writes. Any
/// call beyond the first two — i.e. any self-correcting write
/// `_persistBaseMapSelection` itself issues — resolves immediately, exactly
/// like the real store, so the fix's own corrective writes are never
/// blocked by this double.
class _ReorderingBaseMapPreferenceStore extends BaseMapPreferenceStore {
  static const _interceptedCallCount = 2;

  final List<Completer<void>> _pending = [];

  int get pendingCount => _pending.length;

  @override
  Future<void> save(BaseMap baseMap) async {
    if (_pending.length < _interceptedCallCount) {
      final completer = Completer<void>();
      _pending.add(completer);
      await completer.future;
    }
    await super.save(baseMap);
  }

  /// Lets the [index]-th intercepted `save()` call (in call order) proceed.
  void resolve(int index) => _pending[index].complete();
}
