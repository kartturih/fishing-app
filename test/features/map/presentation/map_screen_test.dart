import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fishing_app/core/map/base_map.dart';
import 'package:fishing_app/core/map/base_map_preference_store.dart';
import 'package:fishing_app/core/map/mml_vector_proxy_service.dart';
import 'package:fishing_app/core/map/syke_bathymetry_tile_source.dart';
import 'package:fishing_app/features/catches/data/catch_search_repository.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_search_page.dart';
import 'package:fishing_app/features/map/presentation/map_screen.dart';
import 'package:fishing_app/features/map/presentation/widgets/base_map_layers_control.dart';
import 'package:fishing_app/features/map/presentation/widgets/base_map_selector_panel.dart';
import 'package:fishing_app/features/map/presentation/widgets/lure_tools_page.dart';
import 'package:fishing_app/features/map/presentation/widgets/map_attribution.dart';
import 'package:fishing_app/features/map/presentation/widgets/map_controls.dart';
import 'package:fishing_app/features/map/presentation/widgets/maptiler_attribution.dart';
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
/// by `worldwide_style_factory_test.dart`.
///
/// **TD-027 §3F/§25 (Revision 7):** `MmlConfig.isMissing` is a compile-time
/// constant (`String.fromEnvironment('MML_API_KEY')`) that is always true
/// under plain `flutter test` (no `--dart-define` is supplied here), so
/// `_prepareStyleFor` never calls `fetchMmlStyleFragment()` by default in
/// this file — `MmlVectorProxyService.start()` itself still runs
/// unconditionally (it has no dependency on `MmlConfig`, since it also
/// serves the SYKE bathymetry route), binding a real, ordinary loopback
/// socket, which is safe and supported in this VM-based test environment.
/// The proxy service's own request-handling/caching/coalescing logic is
/// instead covered directly, independent of any real key or real network,
/// by `mml_vector_proxy_service_test.dart`. `SykeBathymetryTileSource`'s
/// own extraction/read logic is covered by
/// `syke_bathymetry_tile_source_test.dart`; by default in this file (no
/// injected fake), its real `getApplicationSupportDirectory` call throws
/// `MissingPluginException`, which `_initializeBaseMap` already catches —
/// the SYKE overlay is simply absent, never a crash, exactly like a missing
/// MML key.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<Directory> fakeTemporaryDirectory() async => Directory.systemTemp;

  Future<void> pumpMapScreen(
    WidgetTester tester, {
    BaseMapPreferenceStore baseMapPreferenceStore =
        const BaseMapPreferenceStore(),
    MmlVectorProxyService? mmlVectorProxyService,
    SykeBathymetryTileSource? sykeBathymetryTileSource,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          temporaryDirectoryProvider: fakeTemporaryDirectory,
          baseMapPreferenceStore: baseMapPreferenceStore,
          mmlVectorProxyService: mmlVectorProxyService,
          sykeBathymetryTileSource: sykeBathymetryTileSource,
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

        // Asserted via the selector panel's own `selected` value rather
        // than `MapAttribution`: this test suite supplies no `MML_API_KEY`
        // `--dart-define` (the correct, intentional default per TD-026 §8),
        // so `MmlConfig.isMissing` is true — and as of TD-027 §3A/§11,
        // `MapAttribution` requires MML to be *configured* in addition to
        // Maastokartta being selected and region-active, so it is never
        // present at all in this environment (see the "worldwide base-map
        // coverage" group below for that behavior's own dedicated tests) —
        // `MapAttribution.baseMap` is therefore no longer a usable proxy
        // for "which BaseMap is currently selected."
        await tester.tap(find.byKey(const Key('baseMapLayersButton')));
        await tester.pump();
        final panel = tester.widget<BaseMapSelectorPanel>(
          find.byType(BaseMapSelectorPanel),
        );
        expect(panel.selected, BaseMap.maastokartta);
      },
    );

    testWidgets('a persisted Ilmakuva preference is restored on load', (
      tester,
    ) async {
      await const BaseMapPreferenceStore().save(BaseMap.ilmakuva);

      await pumpMapScreen(tester);

      // Asserted via the selector panel's own `selected` value (opened
      // here purely to read it) rather than `MapAttribution`, which is no
      // longer in the tree at all for Ilmakuva as of TD-027 (MML is not
      // part of the Ilmakuva composition in this milestone — see the
      // "worldwide base-map coverage" group below for that behavior's own
      // dedicated tests) — `MapAttribution.baseMap` is therefore no longer
      // a usable proxy for "which BaseMap is currently selected."
      await tester.tap(find.byKey(const Key('baseMapLayersButton')));
      await tester.pump();
      final panel = tester.widget<BaseMapSelectorPanel>(
        find.byType(BaseMapSelectorPanel),
      );
      expect(panel.selected, BaseMap.ilmakuva);
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
      // the initial-load tests above and by `worldwide_style_factory_test.dart`.
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

  group('worldwide base-map coverage (MFS-027 / TD-027)', () {
    testWidgets('MML attribution (MapAttribution) is absent for the default '
        'Maastokartta selection when MML is not configured (TD-027 §3C/§11: '
        'attribution is now unconditional whenever MML is configured, with '
        'no viewport or zoom condition — this only exercises the "not '
        'configured" half, since this test suite supplies no '
        '`MML_API_KEY` `--dart-define` and `MmlConfig.isMissing` is a '
        'compile-time constant that is always true here; the "configured" '
        'half is exercised at the pure-logic level instead, in '
        '`worldwide_style_factory_test.dart`)', (tester) async {
      await pumpMapScreen(tester);

      expect(find.byType(MapAttribution), findsNothing);
    });

    testWidgets('MML attribution (MapAttribution) is absent when a persisted '
        'Ilmakuva selection loads, since MML Ortokuva is not part of the '
        'Ilmakuva composition in this milestone (ADR-0009, MFS-027, TD-027 '
        '§11) — showing it would misattribute content that is not actually '
        'present', (tester) async {
      await const BaseMapPreferenceStore().save(BaseMap.ilmakuva);

      await pumpMapScreen(tester);

      expect(find.byType(MapAttribution), findsNothing);
    });

    testWidgets(
      'MapTilerAttribution is present in the widget tree regardless of '
      'the active selection — its own visibility is independently gated '
      'on MapTilerConfig, not on which BaseMap is active (TD-027 §11)',
      (tester) async {
        await pumpMapScreen(tester);

        expect(find.byType(MapTilerAttribution), findsOneWidget);
      },
    );

    testWidgets('MapTilerAttribution remains present in the widget tree for a '
        'persisted Ilmakuva selection too', (tester) async {
      await const BaseMapPreferenceStore().save(BaseMap.ilmakuva);

      await pumpMapScreen(tester);

      expect(find.byType(MapTilerAttribution), findsOneWidget);
    });

    testWidgets(
      'no viewport- or zoom-driven STYLE REGENERATION trigger exists '
      '(TD-027 §3C Revision 4): MML coverage correctness is enforced per '
      'pixel/tile, not by reloading the style when the camera crosses a '
      'region boundary — `onCameraIdle` is simply never wired up, so it '
      'is unconditionally null, in every build mode',
      (tester) async {
        await pumpMapScreen(tester);

        final map = tester.widget<MapLibreMap>(find.byType(MapLibreMap));
        expect(map.onCameraIdle, isNull);
      },
    );

    testWidgets('the temporary debug camera-zoom overlay (added during the '
        'Revision 3 zoom-threshold investigation, superseded before it was '
        'ever used) is gone — Revision 4 removes it entirely', (tester) async {
      await pumpMapScreen(tester);

      expect(find.byKey(const Key('debugCameraZoomLabel')), findsNothing);
    });
  });

  group('MML v21 vector productionization (TD-027 §3F, Revision 7)', () {
    testWidgets(
      'the temporary vector PoC debug toggle is gone entirely — vector is '
      'now the real Maastokartta path, not a debug-only alternative to it',
      (tester) async {
        await pumpMapScreen(tester);

        expect(find.byKey(const Key('vectorPocToggleButton')), findsNothing);
        expect(find.byIcon(Icons.science), findsNothing);
      },
    );

    testWidgets(
      'MmlVectorProxyService is started unconditionally (even with no '
      '`MML_API_KEY`, since it also serves the SYKE bathymetry route) — '
      'the injected instance\'s baseUrl becomes non-null once the map has '
      'mounted',
      (tester) async {
        final service = MmlVectorProxyService(apiKey: 'unused-in-this-test');
        addTearDown(service.stop);

        await pumpMapScreen(tester, mmlVectorProxyService: service);

        expect(service.baseUrl, isNotNull);
      },
    );

    testWidgets(
      'when MmlConfig is unconfigured (the default under plain `flutter '
      'test`), fetchMmlStyleFragment is never called, so the injected '
      'httpGetString is never invoked — Maastokartta still renders '
      '(MapTiler Outdoor alone)',
      (tester) async {
        var fetchCount = 0;
        final service = MmlVectorProxyService(
          apiKey: 'unused',
          httpGetString: (_) async {
            fetchCount++;
            return '{"sources":{},"layers":[],"glyphs":""}';
          },
        );
        addTearDown(service.stop);

        await pumpMapScreen(tester, mmlVectorProxyService: service);

        expect(fetchCount, 0);
        expect(find.byType(MapLibreMap), findsOneWidget);
      },
    );
  });

  group('SYKE bathymetry overlay (TD-027 §20–§22, Revision 7)', () {
    testWidgets(
      'the SYKE attribution line is not requested from MapTilerAttribution '
      'when the bundled asset was not extracted (the default in this test '
      'file — no fake SykeBathymetryTileSource is injected)',
      (tester) async {
        await pumpMapScreen(tester);

        final attribution = tester.widget<MapTilerAttribution>(
          find.byType(MapTilerAttribution),
        );
        expect(attribution.sykeAttributionRequired, isFalse);
      },
    );

    testWidgets(
      'once a fake SykeBathymetryTileSource successfully "extracts", the '
      'SYKE attribution line is requested from MapTilerAttribution, for '
      'the default Maastokartta selection',
      (tester) async {
        final source = _FakeSykeBathymetryTileSource();
        await pumpMapScreen(tester, sykeBathymetryTileSource: source);

        final attribution = tester.widget<MapTilerAttribution>(
          find.byType(MapTilerAttribution),
        );
        expect(attribution.sykeAttributionRequired, isTrue);
      },
    );

    testWidgets(
      'the SYKE attribution line is also requested for a persisted '
      'Ilmakuva selection — the overlay is base-map-agnostic',
      (tester) async {
        await const BaseMapPreferenceStore().save(BaseMap.ilmakuva);
        final source = _FakeSykeBathymetryTileSource();

        await pumpMapScreen(tester, sykeBathymetryTileSource: source);

        final attribution = tester.widget<MapTilerAttribution>(
          find.byType(MapTilerAttribution),
        );
        expect(attribution.sykeAttributionRequired, isTrue);
      },
    );
  });
}

/// A `SykeBathymetryTileSource` test double whose `ensureExtracted()`
/// always "succeeds" without touching `path_provider` or the real asset
/// bundle, so `MapScreen`-level tests can exercise the "bathymetry
/// available" branch without a real, ~49 MB bundled asset.
class _FakeSykeBathymetryTileSource implements SykeBathymetryTileSource {
  @override
  Future<void> ensureExtracted() async {}

  @override
  String? get extractedPath => '/fake/syke_bathymetry_v1.mbtiles';

  @override
  int? get extractedByteSize => 2048;

  @override
  String? get bundledVersion => 'fake-version';

  @override
  bool? get lastExtractionWasReplace => false;

  @override
  Uint8List? tileFor(int z, int x, int y) => null;

  @override
  void close() {}

  @override
  String get assetFileName => SykeBathymetryTileSource.defaultAssetFileName;
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
