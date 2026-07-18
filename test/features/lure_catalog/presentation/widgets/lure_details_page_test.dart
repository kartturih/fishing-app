import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_details_page.dart';

void main() {
  LureCatalogEntry buildFullEntry() {
    return LureCatalogEntry(
      variant: LureVariant(
        id: 'variant-1',
        lureModelId: 'model-1',
        colorName: 'Hot Craw',
        manufacturerColorCode: 'HCC',
        lengthMillimeters: 80,
        weightGrams: 12,
        minRunningDepthMillimeters: 1500,
        maxRunningDepthMillimeters: 2400,
        buoyancy: 'suspending',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      manufacturer: 'Rapala',
      productFamily: 'X-Rap',
      modelName: 'X-Rap Shad XRS08',
      lureType: 'crankbait',
      modelDefaultImageReference: null,
    );
  }

  LureCatalogEntry buildBareEntry() {
    return LureCatalogEntry(
      variant: LureVariant(
        id: 'variant-2',
        lureModelId: 'model-2',
        colorName: 'Gold',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      manufacturer: 'Abu Garcia',
      modelName: 'Toby',
      lureType: 'spoon',
      modelDefaultImageReference: null,
    );
  }

  Future<void> pumpDetails(WidgetTester tester, LureCatalogEntry entry) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => LureDetailsPage.open(context, entry),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders all present fields', (tester) async {
    await pumpDetails(tester, buildFullEntry());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Rapala X-Rap Shad XRS08'), findsOneWidget);
    expect(find.text('Rapala'), findsOneWidget);
    expect(find.text('X-Rap'), findsOneWidget);
    expect(find.text('Vaappu'), findsOneWidget);
    expect(find.text('Hot Craw'), findsOneWidget);
    expect(find.text('HCC'), findsOneWidget);
    expect(find.text('8 cm'), findsOneWidget);
    expect(find.text('12 g'), findsOneWidget);
    expect(find.text('1.5–2.4 m'), findsOneWidget);
    expect(find.text('Neutraali'), findsOneWidget);
  });

  testWidgets('omits rows for absent optional fields', (tester) async {
    await pumpDetails(tester, buildBareEntry());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Mallisto'), findsNothing);
    expect(find.text('Pituus'), findsNothing);
    expect(find.text('Paino'), findsNothing);
    expect(find.text('Uintisyvyys'), findsNothing);
    expect(find.text('Kellunta'), findsNothing);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('shows a placeholder image when none is available', (
    tester,
  ) async {
    await pumpDetails(tester, buildBareEntry());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.phishing), findsOneWidget);
  });

  testWidgets('Back returns to the previous screen', (tester) async {
    await pumpDetails(tester, buildFullEntry());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(LureDetailsPage), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(LureDetailsPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
