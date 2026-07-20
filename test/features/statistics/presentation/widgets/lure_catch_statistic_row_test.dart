import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/statistics/domain/lure_catch_statistic.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/lure_catch_statistic_row.dart';

void main() {
  LureCatalogEntry buildEntry({String? imageReference}) {
    return LureCatalogEntry(
      variant: LureVariant(
        id: 'variant-1',
        lureModelId: 'model-1',
        colorName: 'Firetiger',
        imageReference: imageReference,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      manufacturer: 'Rapala',
      modelName: 'X-Rap 10',
      lureType: 'jerkbait',
      modelDefaultImageReference: null,
    );
  }

  testWidgets('renders manufacturer, model, color, type, and count', (
    tester,
  ) async {
    final statistic = LureCatchStatistic(lure: buildEntry(), catchCount: 5);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LureCatchStatisticRow(statistic: statistic)),
      ),
    );

    expect(find.textContaining('Rapala X-Rap 10'), findsOneWidget);
    expect(find.textContaining('Firetiger'), findsOneWidget);
    expect(find.text('Jerkki'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('falls back to a placeholder when no image is available', (
    tester,
  ) async {
    final statistic = LureCatchStatistic(lure: buildEntry(), catchCount: 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LureCatchStatisticRow(statistic: statistic)),
      ),
    );

    expect(find.byIcon(Icons.phishing), findsOneWidget);
  });
}
