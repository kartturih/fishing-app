import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/statistics/data/lure_statistics_repository.dart';
import 'package:fishing_app/features/statistics/domain/lure_catch_statistic.dart';
import 'package:fishing_app/features/statistics/domain/lure_statistics_summary.dart';
import 'package:fishing_app/features/statistics/domain/lure_type_catch_statistic.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/lure_statistics_tab.dart';

/// Never completes `getLureStatistics`, so the loading state can be
/// observed deterministically. Mirrors `_PendingRepository` in
/// personal_tackle_box_page_test.dart.
class _PendingRepository extends LureStatisticsRepository {
  _PendingRepository(super.database);

  final Completer<LureStatisticsSummary> pending =
      Completer<LureStatisticsSummary>();

  @override
  Future<LureStatisticsSummary> getLureStatistics() => pending.future;
}

class _FailingRepository extends LureStatisticsRepository {
  _FailingRepository(super.database);

  @override
  Future<LureStatisticsSummary> getLureStatistics() async {
    throw StateError('simulated load failure');
  }
}

/// Fails on its first call, then succeeds — used to verify the retry
/// action re-runs the load.
class _FailOnceRepository extends LureStatisticsRepository {
  _FailOnceRepository(super.database, this._summary);

  final LureStatisticsSummary _summary;
  int callCount = 0;

  @override
  Future<LureStatisticsSummary> getLureStatistics() async {
    callCount++;
    if (callCount == 1) {
      throw StateError('simulated load failure');
    }
    return _summary;
  }
}

class _StaticRepository extends LureStatisticsRepository {
  _StaticRepository(super.database, this._summary);

  final LureStatisticsSummary _summary;

  @override
  Future<LureStatisticsSummary> getLureStatistics() async => _summary;
}

LureCatalogEntry _buildEntry({
  required String id,
  required String manufacturer,
  required String modelName,
  required String lureType,
  String colorName = 'Firetiger',
}) {
  return LureCatalogEntry(
    variant: LureVariant(
      id: id,
      lureModelId: '$id-model',
      colorName: colorName,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
    manufacturer: manufacturer,
    modelName: modelName,
    lureType: lureType,
    modelDefaultImageReference: null,
  );
}

Future<void> pumpTab(WidgetTester tester, LureStatisticsRepository repository) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: LureStatisticsTab(repository: repository)),
    ),
  );
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets(
    'shows a loading indicator while getLureStatistics is in flight',
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
    const summary = LureStatisticsSummary(
      totalCatchesLinkedToLure: 0,
      lures: [],
      lureTypeBreakdown: [],
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

  testWidgets('fully-empty summary shows "no data yet" ranking cards and empty '
      'section messages', (tester) async {
    const summary = LureStatisticsSummary(
      totalCatchesLinkedToLure: 0,
      lures: [],
      lureTypeBreakdown: [],
    );
    final repository = _StaticRepository(database, summary);

    await pumpTab(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Ei vielä tietoja'), findsNWidgets(2));
    expect(
      find.text('Yksikään viehe ei ole vielä tuottanut saalista.'),
      findsOneWidget,
    );
    expect(find.text('Ei viehetyyppikohtaista dataa vielä.'), findsOneWidget);
  });

  testWidgets(
    'a populated summary renders both summary cards and both lists in the '
    'given (already-sorted) order',
    (tester) async {
      final popular = LureCatchStatistic(
        lure: _buildEntry(
          id: 'variant-popular',
          manufacturer: 'Rapala',
          modelName: 'X-Rap 10',
          lureType: 'jerkbait',
        ),
        catchCount: 3,
      );
      final rare = LureCatchStatistic(
        lure: _buildEntry(
          id: 'variant-rare',
          manufacturer: 'Abu Garcia',
          modelName: 'Toby',
          lureType: 'jig',
          colorName: 'Silver',
        ),
        catchCount: 1,
      );
      final summary = LureStatisticsSummary(
        totalCatchesLinkedToLure: 4,
        lures: [popular, rare],
        lureTypeBreakdown: const [
          LureTypeCatchStatistic(lureType: 'jerkbait', catchCount: 3),
          LureTypeCatchStatistic(lureType: 'jig', catchCount: 1),
        ],
      );
      final repository = _StaticRepository(database, summary);

      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      expect(
        find.text('Rapala X-Rap 10, Firetiger (3 saalista)'),
        findsOneWidget,
      );
      expect(find.text('Jerkki (3 saalista)'), findsOneWidget);

      final lureRowOrder = tester
          .widgetList<Text>(find.textContaining('Rapala X-Rap 10'))
          .toList();
      expect(lureRowOrder, isNotEmpty);

      final popularOffset = tester.getTopLeft(
        find.textContaining('Rapala X-Rap 10').last,
      );
      final rareOffset = tester.getTopLeft(
        find.textContaining('Abu Garcia Toby').last,
      );
      expect(popularOffset.dy, lessThan(rareOffset.dy));
    },
  );
}
