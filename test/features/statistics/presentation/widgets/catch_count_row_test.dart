import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/statistics/presentation/widgets/catch_count_row.dart';

void main() {
  testWidgets('renders the given label and catch count', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CatchCountRow(label: 'Hauki', catchCount: 4)),
      ),
    );

    expect(find.text('Hauki'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  group('when onTap is non-null', () {
    testWidgets('shows a trailing chevron', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatchCountRow(label: 'Hauki', catchCount: 4, onTap: () {}),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('tapping the row invokes onTap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatchCountRow(
              label: 'Hauki',
              catchCount: 4,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CatchCountRow));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('exposes button semantics with the combined label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatchCountRow(label: 'Ahven', catchCount: 2, onTap: () {}),
          ),
        ),
      );

      final semantics = tester.getSemantics(
        find.bySemanticsLabel('Ahven, 2 saalista'),
      );
      expect(semantics.flagsCollection.isButton, isTrue);
      handle.dispose();
    });
  });

  group('when onTap is null', () {
    testWidgets('renders the same label and count but is not tappable into '
        'anything', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CatchCountRow(label: 'Hauki', catchCount: 4)),
        ),
      );

      expect(find.text('Hauki'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);

      // Tapping where the row is must not throw and must not be treated
      // as a registered gesture (no InkWell present to absorb it).
      await tester.tap(find.byType(CatchCountRow));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not show a trailing chevron', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CatchCountRow(label: 'Hauki', catchCount: 4)),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('exposes no button semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CatchCountRow(label: 'Ahven', catchCount: 2)),
        ),
      );

      final semantics = tester.getSemantics(
        find.bySemanticsLabel('Ahven, 2 saalista'),
      );
      expect(semantics.flagsCollection.isButton, isFalse);
      handle.dispose();
    });
  });
}
