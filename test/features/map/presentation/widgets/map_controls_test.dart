import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/map/presentation/widgets/base_map_layers_control.dart';
import 'package:fishing_app/features/map/presentation/widgets/map_controls.dart';

void main() {
  Future<void> pumpControls(
    WidgetTester tester, {
    bool isSelectionMode = false,
    VoidCallback? onLocationPressed,
    VoidCallback? onAddFishingSpotPressed,
    VoidCallback? onCancelSelectionPressed,
    VoidCallback? onAddHerePressed,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapControls(
            isSelectionMode: isSelectionMode,
            onLocationPressed: onLocationPressed ?? () {},
            onAddFishingSpotPressed: onAddFishingSpotPressed ?? () {},
            onCancelSelectionPressed: onCancelSelectionPressed ?? () {},
            onAddHerePressed: onAddHerePressed ?? () {},
          ),
        ),
      ),
    );
  }

  group('default mode (MFS-026 polish-pass regression check)', () {
    testWidgets(
      'shows the settings, add-fishing-spot, and location buttons, and no '
      'selection-mode buttons',
      (tester) async {
        await pumpControls(tester);

        expect(find.byIcon(Icons.settings), findsOneWidget);
        expect(find.byIcon(Icons.add_location_alt), findsOneWidget);
        expect(find.byIcon(Icons.my_location), findsOneWidget);
        expect(find.byIcon(Icons.close), findsNothing);
        expect(find.byIcon(Icons.check), findsNothing);
      },
    );

    testWidgets('tapping the settings placeholder button does not throw '
        'and does not fire any of the other callbacks', (tester) async {
      var locationPressed = false;
      var addFishingSpotPressed = false;
      await pumpControls(
        tester,
        onLocationPressed: () => locationPressed = true,
        onAddFishingSpotPressed: () => addFishingSpotPressed = true,
      );

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();

      expect(locationPressed, isFalse);
      expect(addFishingSpotPressed, isFalse);
    });

    testWidgets('tapping the add-fishing-spot button fires '
        'onAddFishingSpotPressed only', (tester) async {
      var addFishingSpotPressed = false;
      var locationPressed = false;
      await pumpControls(
        tester,
        onAddFishingSpotPressed: () => addFishingSpotPressed = true,
        onLocationPressed: () => locationPressed = true,
      );

      await tester.tap(find.byIcon(Icons.add_location_alt));
      await tester.pump();

      expect(addFishingSpotPressed, isTrue);
      expect(locationPressed, isFalse);
    });

    testWidgets('tapping the location button fires onLocationPressed only', (
      tester,
    ) async {
      var locationPressed = false;
      var addFishingSpotPressed = false;
      await pumpControls(
        tester,
        onLocationPressed: () => locationPressed = true,
        onAddFishingSpotPressed: () => addFishingSpotPressed = true,
      );

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump();

      expect(locationPressed, isTrue);
      expect(addFishingSpotPressed, isFalse);
    });
  });

  group('selection mode (MFS-026 polish-pass regression check)', () {
    testWidgets('shows only the cancel-selection and add-here buttons', (
      tester,
    ) async {
      await pumpControls(tester, isSelectionMode: true);

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsNothing);
      expect(find.byIcon(Icons.add_location_alt), findsNothing);
      expect(find.byIcon(Icons.my_location), findsNothing);
    });

    testWidgets('tapping cancel fires onCancelSelectionPressed only', (
      tester,
    ) async {
      var cancelPressed = false;
      var addHerePressed = false;
      await pumpControls(
        tester,
        isSelectionMode: true,
        onCancelSelectionPressed: () => cancelPressed = true,
        onAddHerePressed: () => addHerePressed = true,
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(cancelPressed, isTrue);
      expect(addHerePressed, isFalse);
    });

    testWidgets('tapping add-here fires onAddHerePressed only', (tester) async {
      var cancelPressed = false;
      var addHerePressed = false;
      await pumpControls(
        tester,
        isSelectionMode: true,
        onCancelSelectionPressed: () => cancelPressed = true,
        onAddHerePressed: () => addHerePressed = true,
      );

      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      expect(addHerePressed, isTrue);
      expect(cancelPressed, isFalse);
    });
  });

  testWidgets(
    "MapControls' buttons are the same size as BaseMapLayersControl's "
    'button, so they form one visually consistent control system '
    '(MFS-026 polish pass) — not asserting a specific pixel value, only '
    'that the two independently-built widgets agree',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                MapControls(
                  isSelectionMode: false,
                  onLocationPressed: () {},
                  onAddFishingSpotPressed: () {},
                  onCancelSelectionPressed: () {},
                  onAddHerePressed: () {},
                ),
                BaseMapLayersControl(onPressed: () {}),
              ],
            ),
          ),
        ),
      );

      final mapControlsButtonSize = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.my_location),
          matching: find.byType(FloatingActionButton),
        ),
      );
      final layersButtonSize = tester.getSize(
        find.byKey(const Key('baseMapLayersButton')),
      );

      expect(mapControlsButtonSize, layersButtonSize);
    },
  );
}
