import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catches/data/catch_search_repository.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_search_page.dart';
import 'package:fishing_app/features/map/presentation/map_screen.dart';
import 'package:fishing_app/features/map/presentation/widgets/lure_tools_page.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/statistics_page.dart';

/// Covers `MapScreen`'s AppBar entry points (MFS-025 / TD-025 §7): the new
/// Catch Search action, and regression coverage confirming the two
/// pre-existing entry points (Lure Tools, Statistics) it sits alongside are
/// unaffected. No test file for `MapScreen` existed prior to this milestone
/// — this is a new file at the conventional path mirroring
/// `lib/features/map/presentation/map_screen.dart`.
///
/// `MapScreen` embeds a `MapLibreMap` platform view, which keeps
/// perpetually scheduling frames in this headless test environment (no
/// real native map surface backs it) — `tester.pumpAndSettle()` therefore
/// never settles and times out. Every pump in this file uses a bounded,
/// explicit number of frames/duration instead, exactly as this project's
/// existing convention already does for other never-settling widgets (e.g.
/// an indefinitely animating `CircularProgressIndicator`).
void main() {
  Future<void> pumpMapScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MapScreen()));
    await tester.pump();
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
}
