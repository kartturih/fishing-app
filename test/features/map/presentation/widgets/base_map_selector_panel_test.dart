import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/map/base_map.dart';
import 'package:fishing_app/features/map/presentation/widgets/base_map_selector_panel.dart';

void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    required BaseMap selected,
    required ValueChanged<BaseMap> onSelected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BaseMapSelectorPanel(
            selected: selected,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'shows both base-map choices as previews, with no visible text label '
    '(MFS-026 polish pass: image-only options)',
    (tester) async {
      await pumpPanel(
        tester,
        selected: BaseMap.maastokartta,
        onSelected: (_) {},
      );

      expect(find.byType(Image), findsNWidgets(2));
      expect(
        find.byKey(const Key('baseMapOption-maastokartta')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('baseMapOption-ilmakuva')), findsOneWidget);

      // No visible text anywhere in the panel — the names are conveyed only
      // through Semantics (checked separately below), not on-screen text.
      expect(find.text('Maastokartta'), findsNothing);
      expect(find.text('Ilmakuva'), findsNothing);
      expect(find.byType(Text), findsNothing);
    },
  );

  testWidgets('both options have identical dimensions (MFS-026 polish pass)', (
    tester,
  ) async {
    await pumpPanel(tester, selected: BaseMap.maastokartta, onSelected: (_) {});

    final maastokarttaSize = tester.getSize(
      find.byKey(const Key('baseMapOption-maastokartta')),
    );
    final ilmakuvaSize = tester.getSize(
      find.byKey(const Key('baseMapOption-ilmakuva')),
    );

    expect(maastokarttaSize, ilmakuvaSize);
  });

  testWidgets('the active choice is identifiable via its semantics', (
    tester,
  ) async {
    await pumpPanel(tester, selected: BaseMap.maastokartta, onSelected: (_) {});

    expect(
      tester.getSemantics(find.byKey(const Key('baseMapOption-maastokartta'))),
      matchesSemantics(
        label: 'Maastokartta, valittu',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('baseMapOption-ilmakuva'))),
      matchesSemantics(
        label: 'Ilmakuva, ei valittu',
        isButton: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('tapping the inactive choice fires onSelected with it', (
    tester,
  ) async {
    BaseMap? selectedFromCallback;
    await pumpPanel(
      tester,
      selected: BaseMap.maastokartta,
      onSelected: (baseMap) => selectedFromCallback = baseMap,
    );

    await tester.tap(find.byKey(const Key('baseMapOption-ilmakuva')));
    await tester.pump();

    expect(selectedFromCallback, BaseMap.ilmakuva);
  });

  testWidgets(
    'tapping the already-active choice still fires onSelected with it',
    (tester) async {
      BaseMap? selectedFromCallback;
      await pumpPanel(
        tester,
        selected: BaseMap.maastokartta,
        onSelected: (baseMap) => selectedFromCallback = baseMap,
      );

      await tester.tap(find.byKey(const Key('baseMapOption-maastokartta')));
      await tester.pump();

      expect(selectedFromCallback, BaseMap.maastokartta);
    },
  );

  testWidgets(
    'the two options are arranged vertically (stacked), not side by side '
    '(MFS-026 polish pass)',
    (tester) async {
      await pumpPanel(
        tester,
        selected: BaseMap.maastokartta,
        onSelected: (_) {},
      );

      final maastokarttaTopLeft = tester.getTopLeft(
        find.byKey(const Key('baseMapOption-maastokartta')),
      );
      final ilmakuvaTopLeft = tester.getTopLeft(
        find.byKey(const Key('baseMapOption-ilmakuva')),
      );

      // Stacked: the second option starts lower than the first and shares
      // its left edge, rather than sitting to its right on the same row.
      // Not asserting exact offsets — just the vertical relationship.
      expect(ilmakuvaTopLeft.dy, greaterThan(maastokarttaTopLeft.dy));
      expect(ilmakuvaTopLeft.dx, maastokarttaTopLeft.dx);
    },
  );

  testWidgets(
    'no large checkmark icon is rendered for the active choice — active '
    'state must come from subtle styling only (MFS-026 polish pass)',
    (tester) async {
      await pumpPanel(
        tester,
        selected: BaseMap.maastokartta,
        onSelected: (_) {},
      );

      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
    },
  );

  testWidgets(
    'the active option is styled distinctly from the inactive one via a '
    'border/tint, not merely via semantics (MFS-026 polish pass)',
    (tester) async {
      await pumpPanel(
        tester,
        selected: BaseMap.maastokartta,
        onSelected: (_) {},
      );

      final activeDecoration =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byKey(const Key('baseMapOption-maastokartta')),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      final inactiveDecoration =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byKey(const Key('baseMapOption-ilmakuva')),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration
              as BoxDecoration;

      // Subtle, not a strong opinion about exact colors/widths: the active
      // tile has *some* border and background tint; the inactive tile has
      // neither.
      expect(activeDecoration.border, isNotNull);
      expect(activeDecoration.color, isNotNull);
      expect(inactiveDecoration.border, isNull);
      expect(inactiveDecoration.color, isNull);
    },
  );
}
