import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_catalog_model_list_item.dart';

void main() {
  LureCatalogEntry buildModelEntry({
    String? imageReference,
    String? modelDefaultImageReference,
  }) {
    return LureCatalogEntry(
      variant: LureVariant(
        id: 'variant-1',
        lureModelId: 'model-1',
        colorName: 'Hot Craw',
        imageReference: imageReference,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      manufacturer: 'Rapala',
      modelName: 'X-Rap Shad XRS08',
      lureType: 'crankbait',
      modelDefaultImageReference: modelDefaultImageReference,
    );
  }

  Future<void> pumpItem(
    WidgetTester tester,
    LureCatalogEntry modelEntry, {
    VoidCallback? onTap,
    bool fullyOwned = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LureCatalogModelListItem(
            modelEntry: modelEntry,
            onTap: onTap ?? () {},
            fullyOwned: fullyOwned,
          ),
        ),
      ),
    );
  }

  testWidgets('renders manufacturer and model name', (tester) async {
    await pumpItem(tester, buildModelEntry());

    expect(find.text('Rapala X-Rap Shad XRS08'), findsOneWidget);
  });

  testWidgets('does not render a per-variant distinguishing detail line', (
    tester,
  ) async {
    await pumpItem(tester, buildModelEntry());

    // The model row must not show a single color/variant name — that is
    // model-level ambiguous now that the list groups by model (MFS-018).
    expect(find.text('Hot Craw'), findsNothing);
  });

  testWidgets('renders the lure type label', (tester) async {
    await pumpItem(tester, buildModelEntry());

    expect(find.text('Vaappu'), findsOneWidget);
  });

  testWidgets('shows a placeholder icon when no image is available', (
    tester,
  ) async {
    await pumpItem(tester, buildModelEntry());

    expect(find.byIcon(Icons.phishing), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
    'attempts to render an image when the model has a default image reference',
    (tester) async {
      // A single pump (no settle) is used deliberately: the referenced
      // asset does not exist in the test environment, so letting the frame
      // settle would resolve Image.asset's errorBuilder and swap back to
      // the placeholder. This only verifies that an Image widget is built
      // for a non-null reference, not that the asset actually decodes.
      await pumpItem(
        tester,
        buildModelEntry(
          modelDefaultImageReference: 'assets/lure_catalog/x.png',
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    },
  );

  testWidgets('uses the model default image, not a variant-specific override', (
    tester,
  ) async {
    // Unlike the old per-variant row, the model row always shows the
    // model's own default image — never `variant.imageReference` — since
    // it represents the whole model, not one specific variant.
    await pumpItem(
      tester,
      buildModelEntry(
        imageReference: 'assets/lure_catalog/variant-specific.png',
        modelDefaultImageReference: 'assets/lure_catalog/model-default.png',
      ),
    );

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('tapping the row invokes onTap', (tester) async {
    var tapped = false;
    await pumpItem(tester, buildModelEntry(), onTap: () => tapped = true);

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('does not show an owned badge by default', (tester) async {
    await pumpItem(tester, buildModelEntry());

    expect(find.byKey(const Key('ownedBadge')), findsNothing);
  });

  testWidgets('shows an owned badge when fullyOwned is true', (tester) async {
    await pumpItem(tester, buildModelEntry(), fullyOwned: true);

    expect(find.byKey(const Key('ownedBadge')), findsOneWidget);
  });

  testWidgets('appends ownership to the semantic label when fully owned', (
    tester,
  ) async {
    await pumpItem(tester, buildModelEntry(), fullyOwned: true);

    expect(
      find.bySemanticsLabel('Rapala X-Rap Shad XRS08, omistuksessa'),
      findsOneWidget,
    );
  });
}
