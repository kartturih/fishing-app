import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/map/presentation/widgets/maptiler_attribution.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    // SvgPicture decodes its bundled asset asynchronously; let it settle.
    await tester.pump();
  }

  testWidgets(
    'renders nothing when MapTiler is not configured (the default under '
    'plain `flutter test`, with no configured override)',
    (tester) async {
      await pump(tester, const MapTilerAttribution());

      expect(find.byKey(const Key('mapTilerAttributionButton')), findsNothing);
      expect(find.byType(SvgPicture), findsNothing);
    },
  );

  testWidgets(
    'renders the official MapTiler logo (bundled SVG) as the attribution '
    'trigger when configured — not a generic icon (architecture review: '
    'Free-plan attribution compliance)',
    (tester) async {
      await pump(tester, const MapTilerAttribution(configured: true));

      expect(
        find.byKey(const Key('mapTilerAttributionButton')),
        findsOneWidget,
      );
      expect(find.byType(SvgPicture), findsOneWidget);
      // The previous generic info-icon trigger must no longer be used.
      expect(find.byIcon(Icons.info_outline), findsNothing);
      expect(find.byType(Icon), findsNothing);
    },
  );

  testWidgets(
    'tapping the logo reveals the exact required attribution text with '
    'both links (MapTiler, OpenStreetMap contributors)',
    (tester) async {
      await pump(tester, const MapTilerAttribution(configured: true));

      await tester.tap(find.byKey(const Key('mapTilerAttributionButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('mapTilerCopyrightLink')), findsOneWidget);
      expect(find.byKey(const Key('osmCopyrightLink')), findsOneWidget);
      expect(find.text('© MapTiler'), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    },
  );

  group('SYKE bathymetry attribution (TD-027 §24, Revision 7)', () {
    testWidgets(
      'the SYKE line is absent from the panel when sykeAttributionRequired '
      'is false (the default)',
      (tester) async {
        await pump(tester, const MapTilerAttribution(configured: true));

        await tester.tap(find.byKey(const Key('mapTilerAttributionButton')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('sykeCopyrightLink')), findsNothing);
      },
    );

    testWidgets(
      'the SYKE line is present in the same shared panel — extended, not '
      'triplicated — when sykeAttributionRequired is true',
      (tester) async {
        await pump(
          tester,
          const MapTilerAttribution(
            configured: true,
            sykeAttributionRequired: true,
          ),
        );

        await tester.tap(find.byKey(const Key('mapTilerAttributionButton')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(const Key('sykeCopyrightLink')), findsOneWidget);
        // Still the same three MapTiler/OSM elements — nothing removed.
        expect(find.byKey(const Key('mapTilerCopyrightLink')), findsOneWidget);
        expect(find.byKey(const Key('osmCopyrightLink')), findsOneWidget);
      },
    );

    testWidgets(
      'the trigger itself (the always-visible logo) is unaffected by '
      'sykeAttributionRequired when MapTiler is unconfigured — no '
      'standalone SYKE-only attribution surface is introduced',
      (tester) async {
        await pump(
          tester,
          const MapTilerAttribution(sykeAttributionRequired: true),
        );

        expect(
          find.byKey(const Key('mapTilerAttributionButton')),
          findsNothing,
        );
      },
    );
  });
}
