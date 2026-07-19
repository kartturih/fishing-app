import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/color_variant_row.dart';

void main() {
  LureCatalogEntry buildEntry({
    String? variantName,
    String? colorName,
    String? manufacturerColorCode,
    int? lengthMillimeters,
    int? weightGrams,
    String? imageReference,
  }) {
    return LureCatalogEntry(
      variant: LureVariant(
        id: 'variant-1',
        lureModelId: 'model-1',
        variantName: variantName,
        colorName: colorName,
        manufacturerColorCode: manufacturerColorCode,
        lengthMillimeters: lengthMillimeters,
        weightGrams: weightGrams,
        imageReference: imageReference,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      manufacturer: 'Rapala',
      modelName: 'X-Rap Shad XRS08',
      lureType: 'crankbait',
      modelDefaultImageReference: null,
    );
  }

  Future<void> pumpRow(
    WidgetTester tester,
    LureCatalogEntry entry, {
    VoidCallback? onTap,
    Widget? action,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColorVariantRow(
            entry: entry,
            onTap: onTap ?? () {},
            action: action,
          ),
        ),
      ),
    );
  }

  testWidgets('renders the distinguishing color/variant name', (tester) async {
    await pumpRow(tester, buildEntry(colorName: 'Hot Craw'));

    expect(find.text('Hot Craw'), findsOneWidget);
  });

  testWidgets('prefers variantName over colorName and manufacturerColorCode', (
    tester,
  ) async {
    await pumpRow(
      tester,
      buildEntry(
        variantName: 'Special Edition',
        colorName: 'Hot Craw',
        manufacturerColorCode: 'RAP-01',
      ),
    );

    expect(find.text('Special Edition'), findsOneWidget);
    expect(find.text('Hot Craw'), findsNothing);
  });

  testWidgets('renders combined length and weight when both are present', (
    tester,
  ) async {
    await pumpRow(
      tester,
      buildEntry(colorName: 'Hot Craw', lengthMillimeters: 80, weightGrams: 12),
    );

    expect(find.text('8 cm • 12 g'), findsOneWidget);
  });

  testWidgets('renders only length when weight is absent', (tester) async {
    await pumpRow(
      tester,
      buildEntry(colorName: 'Hot Craw', lengthMillimeters: 85),
    );

    expect(find.text('8.5 cm'), findsOneWidget);
  });

  testWidgets('renders only weight when length is absent', (tester) async {
    await pumpRow(tester, buildEntry(colorName: 'Hot Craw', weightGrams: 12));

    expect(find.text('12 g'), findsOneWidget);
  });

  testWidgets('renders no measurements line when both are absent', (
    tester,
  ) async {
    await pumpRow(tester, buildEntry(colorName: 'Hot Craw'));

    expect(find.textContaining('cm'), findsNothing);
    expect(find.textContaining(' g'), findsNothing);
  });

  testWidgets('tapping the row body invokes onTap', (tester) async {
    var tapped = false;
    await pumpRow(
      tester,
      buildEntry(colorName: 'Hot Craw'),
      onTap: () => tapped = true,
    );

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('renders the caller-supplied action widget', (tester) async {
    await pumpRow(
      tester,
      buildEntry(colorName: 'Hot Craw'),
      action: const Text('ACTION'),
    );

    expect(find.text('ACTION'), findsOneWidget);
  });

  testWidgets('tapping the action widget does not invoke row onTap', (
    tester,
  ) async {
    var rowTapped = false;
    var actionTapped = false;
    await pumpRow(
      tester,
      buildEntry(colorName: 'Hot Craw'),
      onTap: () => rowTapped = true,
      action: GestureDetector(
        onTap: () => actionTapped = true,
        child: const Text('ACTION'),
      ),
    );

    await tester.tap(find.text('ACTION'));
    await tester.pumpAndSettle();

    expect(actionTapped, isTrue);
    expect(rowTapped, isFalse);
  });

  testWidgets('shows a placeholder icon when no image is available', (
    tester,
  ) async {
    await pumpRow(tester, buildEntry(colorName: 'Hot Craw'));

    expect(find.byIcon(Icons.phishing), findsOneWidget);
  });
}
