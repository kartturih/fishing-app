import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/statistics/presentation/widgets/statistics_summary_card.dart';

void main() {
  testWidgets('renders the given title and value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatisticsSummaryCard(
            title: 'Menestynein viehe',
            value: 'Rapala X-Rap 10, Firetiger (3 saalista)',
          ),
        ),
      ),
    );

    expect(find.text('Menestynein viehe'), findsOneWidget);
    expect(
      find.text('Rapala X-Rap 10, Firetiger (3 saalista)'),
      findsOneWidget,
    );
  });

  testWidgets('renders an optional secondary value below the primary value', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatisticsSummaryCard(
            title: 'Yleisin laji',
            value: 'Hauki',
            secondaryValue: '5 saalista',
          ),
        ),
      ),
    );

    expect(find.text('Yleisin laji'), findsOneWidget);
    expect(find.text('Hauki'), findsOneWidget);
    expect(find.text('5 saalista'), findsOneWidget);
  });

  testWidgets('renders nothing extra when no secondary value is given', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatisticsSummaryCard(title: 'Saaliita yhteensä', value: '5'),
        ),
      ),
    );

    expect(find.text('Saaliita yhteensä'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });
}
