import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/statistics/data/lure_statistics_repository.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/statistics_page.dart';

void main() {
  late AppDatabase database;
  late LureStatisticsRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LureStatisticsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('shows the app bar title, the single tab, and its content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: StatisticsPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tilastot'), findsOneWidget);
    expect(find.text('Viehetilastot'), findsOneWidget);
    expect(
      find.text('Yksikään viehe ei ole vielä tuottanut saalista.'),
      findsOneWidget,
    );
  });
}
