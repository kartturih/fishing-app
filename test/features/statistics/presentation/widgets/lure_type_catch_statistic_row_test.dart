import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/statistics/domain/lure_type_catch_statistic.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/lure_type_catch_statistic_row.dart';

void main() {
  testWidgets('renders the display label and catch count', (tester) async {
    const statistic = LureTypeCatchStatistic(lureType: 'jig', catchCount: 4);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LureTypeCatchStatisticRow(statistic: statistic)),
      ),
    );

    expect(find.text('Jigi'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('falls back to a humanized label for an unrecognized code', (
    tester,
  ) async {
    const statistic = LureTypeCatchStatistic(
      lureType: 'deep_diving_glider',
      catchCount: 2,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LureTypeCatchStatisticRow(statistic: statistic)),
      ),
    );

    expect(find.text('Deep diving glider'), findsOneWidget);
  });
}
