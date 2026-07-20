import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/species_catch_statistic_row.dart';

void main() {
  testWidgets('renders the species name and catch count', (tester) async {
    const statistic = SpeciesCatchStatistic(
      species: FishSpecies.pike,
      catchCount: 4,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SpeciesCatchStatisticRow(statistic: statistic)),
      ),
    );

    expect(find.text('Hauki'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('exposes no button semantics', (tester) async {
    const statistic = SpeciesCatchStatistic(
      species: FishSpecies.perch,
      catchCount: 2,
    );
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SpeciesCatchStatisticRow(statistic: statistic)),
      ),
    );

    final semantics = tester.getSemantics(
      find.bySemanticsLabel('Ahven, 2 saalista'),
    );
    expect(semantics.flagsCollection.isButton, isFalse);
    handle.dispose();
  });
}
