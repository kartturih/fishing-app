import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/statistics/presentation/widgets/lure_statistics_summary_card.dart';

void main() {
  testWidgets('renders the given title and value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LureStatisticsSummaryCard(
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
}
