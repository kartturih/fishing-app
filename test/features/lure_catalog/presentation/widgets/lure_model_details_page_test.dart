import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_details_page.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_model_details_page.dart';

void main() {
  final variantA = LureVariant(
    id: 'variant-a',
    lureModelId: 'model-1',
    colorName: 'Hot Craw',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
  final variantB = LureVariant(
    id: 'variant-b',
    lureModelId: 'model-1',
    colorName: 'Silver',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  final modelEntry = LureCatalogEntry(
    variant: variantA,
    manufacturer: 'Rapala',
    modelName: 'X-Rap Shad XRS08',
    lureType: 'crankbait',
    modelDefaultImageReference: null,
  );

  Widget buildPage({
    List<LureVariant>? variants,
    Set<String>? ownedVariantIds,
    Widget Function(
      BuildContext context,
      LureCatalogEntry variantEntry, {
      required bool initialIsOwned,
    })?
    variantActionBuilder,
  }) {
    return MaterialApp(
      home: LureModelDetailsPage(
        modelEntry: modelEntry,
        variants: variants ?? [variantA, variantB],
        ownedVariantIds: ownedVariantIds ?? const {},
        variantActionBuilder: variantActionBuilder,
      ),
    );
  }

  testWidgets('renders manufacturer, model name and lure type', (tester) async {
    await tester.pumpWidget(buildPage());

    expect(find.text('Rapala'), findsOneWidget);
    expect(find.text('X-Rap Shad XRS08'), findsOneWidget);
    expect(find.text('Vaappu'), findsOneWidget);
  });

  testWidgets('renders one row per variant', (tester) async {
    await tester.pumpWidget(buildPage());

    expect(find.text('Hot Craw'), findsOneWidget);
    expect(find.text('Silver'), findsOneWidget);
  });

  testWidgets('renders with no action slot when variantActionBuilder is null', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'passes each row its own owned state, independent of sibling rows',
    (tester) async {
      final observedOwnership = <String, bool>{};
      await tester.pumpWidget(
        buildPage(
          ownedVariantIds: {'variant-a'},
          variantActionBuilder:
              (context, variantEntry, {required initialIsOwned}) {
                observedOwnership[variantEntry.variant.id] = initialIsOwned;
                return Text('action-${variantEntry.variant.id}');
              },
        ),
      );

      expect(observedOwnership['variant-a'], isTrue);
      expect(observedOwnership['variant-b'], isFalse);
    },
  );

  testWidgets(
    'variantActionBuilder receives a variant-specific entry, not the model entry',
    (tester) async {
      final observedVariantIds = <String>[];
      await tester.pumpWidget(
        buildPage(
          variantActionBuilder:
              (context, variantEntry, {required initialIsOwned}) {
                observedVariantIds.add(variantEntry.variant.id);
                return Text('action-${variantEntry.variant.id}');
              },
        ),
      );

      expect(observedVariantIds, containsAll(['variant-a', 'variant-b']));
    },
  );

  testWidgets(
    'tapping a variant row body opens LureDetailsPage for that variant',
    (tester) async {
      await tester.pumpWidget(buildPage());

      await tester.tap(find.text('Hot Craw'));
      await tester.pumpAndSettle();

      expect(find.byType(LureDetailsPage), findsOneWidget);
      expect(find.text('Väri', skipOffstage: false), findsWidgets);
    },
  );
}
