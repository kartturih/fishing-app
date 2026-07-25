import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/map/presentation/widgets/base_map_layers_control.dart';

void main() {
  Future<void> pumpControl(
    WidgetTester tester, {
    required VoidCallback onPressed,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BaseMapLayersControl(onPressed: onPressed)),
      ),
    );
  }

  testWidgets('shows the layers icon with the Karttatasot tooltip', (
    tester,
  ) async {
    await pumpControl(tester, onPressed: () {});

    expect(find.byIcon(Icons.layers), findsOneWidget);
    final button = tester.widget<FloatingActionButton>(
      find.byKey(const Key('baseMapLayersButton')),
    );
    expect(button.tooltip, 'Karttatasot');
  });

  testWidgets('tapping the control fires onPressed', (tester) async {
    var pressed = false;
    await pumpControl(tester, onPressed: () => pressed = true);

    await tester.tap(find.byKey(const Key('baseMapLayersButton')));
    await tester.pump();

    expect(pressed, isTrue);
  });
}
