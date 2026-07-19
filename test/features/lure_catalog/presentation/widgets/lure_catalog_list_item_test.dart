import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_catalog_list_item.dart';

void main() {
  LureCatalogEntry buildEntry({
    String? colorName = 'Hot Craw',
    String? variantName,
    String? imageReference,
    String? modelDefaultImageReference,
  }) {
    return LureCatalogEntry(
      variant: LureVariant(
        id: 'variant-1',
        lureModelId: 'model-1',
        colorName: colorName,
        variantName: variantName,
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
    LureCatalogEntry entry, {
    VoidCallback? onTap,
    bool isOwned = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LureCatalogListItem(
            entry: entry,
            onTap: onTap ?? () {},
            isOwned: isOwned,
          ),
        ),
      ),
    );
  }

  testWidgets('renders manufacturer, model, and distinguishing text', (
    tester,
  ) async {
    await pumpItem(tester, buildEntry());

    expect(find.text('Rapala X-Rap Shad XRS08'), findsOneWidget);
    expect(find.text('Hot Craw'), findsOneWidget);
  });

  testWidgets('renders the lure type label', (tester) async {
    await pumpItem(tester, buildEntry());

    expect(find.text('Vaappu'), findsOneWidget);
  });

  testWidgets('shows a placeholder icon when no image is available', (
    tester,
  ) async {
    await pumpItem(tester, buildEntry());

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
        buildEntry(modelDefaultImageReference: 'assets/lure_catalog/x.png'),
      );

      expect(find.byType(Image), findsOneWidget);
    },
  );

  testWidgets('tapping the row invokes onTap', (tester) async {
    var tapped = false;
    await pumpItem(tester, buildEntry(), onTap: () => tapped = true);

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('does not show an owned badge by default', (tester) async {
    await pumpItem(tester, buildEntry());

    expect(find.byKey(const Key('ownedBadge')), findsNothing);
  });

  testWidgets('shows an owned badge when isOwned is true', (tester) async {
    await pumpItem(tester, buildEntry(), isOwned: true);

    expect(find.byKey(const Key('ownedBadge')), findsOneWidget);
  });

  testWidgets('appends ownership to the semantic label when owned', (
    tester,
  ) async {
    await pumpItem(tester, buildEntry(), isOwned: true);

    expect(
      find.bySemanticsLabel('Rapala X-Rap Shad XRS08 Hot Craw, omistuksessa'),
      findsOneWidget,
    );
  });
}
