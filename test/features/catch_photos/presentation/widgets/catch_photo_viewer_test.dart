import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_viewer.dart';

import '../../../../support/test_image_files.dart';

/// A failed image decode/read is delivered through a genuine dart:io error
/// callback, which — like other real asynchronous I/O — only resolves when
/// interleaved with real time via tester.runAsync, not through fake-clock
/// pumps alone.
Future<void> _pumpUntilSettledWithRealIO(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Simulates a two-finger pinch-out (zoom in) centered on the current
/// [InteractiveViewer] page.
Future<void> _pinchZoomIn(WidgetTester tester) async {
  final center = tester.getCenter(find.byType(InteractiveViewer));
  final pointer1 = await tester.startGesture(center + const Offset(-20, 0));
  final pointer2 = await tester.startGesture(center + const Offset(20, 0));
  await tester.pump(const Duration(milliseconds: 16));
  for (var i = 0; i < 10; i++) {
    await pointer1.moveBy(const Offset(-6, 0));
    await pointer2.moveBy(const Offset(6, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await pointer1.up();
  await pointer2.up();
  await tester.pumpAndSettle();
}

/// A one-finger drag broken into many small steps (rather than a single
/// jump), so the viewer's per-update boundary/overdrag detection has enough
/// samples to work with — matching how a real drag is delivered.
Future<void> _dragInSteps(
  WidgetTester tester,
  Offset totalOffset, {
  int steps = 40,
}) async {
  final start = tester.getCenter(find.byType(InteractiveViewer));
  final gesture = await tester.startGesture(start);
  final stepOffset = Offset(totalOffset.dx / steps, totalOffset.dy / steps);
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(stepOffset);
    await tester.pump(const Duration(milliseconds: 8));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

double _currentScale(WidgetTester tester) {
  final viewer = tester.widget<InteractiveViewer>(
    find.byType(InteractiveViewer),
  );
  return viewer.transformationController!.value.getMaxScaleOnAxis();
}

double _currentTranslationX(WidgetTester tester) {
  final viewer = tester.widget<InteractiveViewer>(
    find.byType(InteractiveViewer),
  );
  return viewer.transformationController!.value.getTranslation().x;
}

void main() {
  late Directory sourceDir;

  setUp(() {
    sourceDir = Directory.systemTemp.createTempSync('catch_photo_viewer_test');
  });

  tearDown(() {
    if (sourceDir.existsSync()) {
      sourceDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpViewer(
    WidgetTester tester,
    List<File> files, {
    int initialIndex = 0,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CatchPhotoViewer.open(
                context,
                files: files,
                initialIndex: initialIndex,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('opens at the selected index', (tester) async {
    final files = [
      File(writeTestJpeg(sourceDir, 'a.jpg')),
      File(writeTestJpeg(sourceDir, 'b.jpg')),
      File(writeTestJpeg(sourceDir, 'c.jpg')),
    ];
    await pumpViewer(tester, files, initialIndex: 2);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('displays a single photo', (tester) async {
    final files = [File(writeTestJpeg(sourceDir, 'a.jpg'))];
    await pumpViewer(tester, files);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('unzoomed one-finger swipe changes page normally', (
    tester,
  ) async {
    final files = [
      File(writeTestJpeg(sourceDir, 'a.jpg')),
      File(writeTestJpeg(sourceDir, 'b.jpg')),
    ];
    await pumpViewer(tester, files);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('catchPhotoViewerPageView')),
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('closes correctly', (tester) async {
    final files = [File(writeTestJpeg(sourceDir, 'a.jpg'))];
    await pumpViewer(tester, files);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(CatchPhotoViewer), findsOneWidget);

    await tester.tap(find.byKey(const Key('catchPhotoViewerCloseButton')));
    await tester.pumpAndSettle();

    expect(find.byType(CatchPhotoViewer), findsNothing);
  });

  testWidgets('shows a placeholder for a missing file', (tester) async {
    final files = [File('${sourceDir.path}/does-not-exist.jpg')];
    await pumpViewer(tester, files);

    await tester.tap(find.text('open'));
    await _pumpUntilSettledWithRealIO(tester);

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.text('Kuvaa ei voi näyttää'), findsOneWidget);
  });

  testWidgets('shows a placeholder for a corrupt file', (tester) async {
    final corruptPath = '${sourceDir.path}/corrupt.jpg';
    File(corruptPath).writeAsBytesSync(List<int>.filled(200, 0));
    final files = [File(corruptPath)];
    await pumpViewer(tester, files);

    await tester.tap(find.text('open'));
    await _pumpUntilSettledWithRealIO(tester);

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('provides a zoom-capable widget', (tester) async {
    final files = [File(writeTestJpeg(sourceDir, 'a.jpg'))];
    await pumpViewer(tester, files);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  group('zoomed gesture handling', () {
    testWidgets('pinch zoom still works', (tester) async {
      final files = [File(writeTestJpeg(sourceDir, 'a.jpg'))];
      await pumpViewer(tester, files);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await _pinchZoomIn(tester);

      expect(_currentScale(tester), greaterThan(1.0));
    });

    testWidgets('zoomed one-finger drag pans the image without changing page', (
      tester,
    ) async {
      final files = [
        File(writeTestJpeg(sourceDir, 'a.jpg')),
        File(writeTestJpeg(sourceDir, 'b.jpg')),
      ];
      await pumpViewer(tester, files);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await _pinchZoomIn(tester);
      expect(_currentScale(tester), greaterThan(1.0));

      final translationBefore = _currentTranslationX(tester);

      await _dragInSteps(tester, const Offset(-30, 0), steps: 10);

      expect(find.text('1 / 2'), findsOneWidget);
      expect(_currentTranslationX(tester), isNot(equals(translationBefore)));
    });

    testWidgets(
      'dragging outward at the right boundary moves to the next photo',
      (tester) async {
        final files = [
          File(writeTestJpeg(sourceDir, 'a.jpg')),
          File(writeTestJpeg(sourceDir, 'b.jpg')),
        ];
        await pumpViewer(tester, files);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await _pinchZoomIn(tester);
        expect(_currentScale(tester), greaterThan(1.0));

        // Drag far enough left to reach the right pan boundary and keep
        // going: this should hand off to the next photo.
        await _dragInSteps(tester, const Offset(-4000, 0));

        expect(find.text('2 / 2'), findsOneWidget);
      },
    );

    testWidgets(
      'dragging outward at the left boundary moves to the previous photo',
      (tester) async {
        final files = [
          File(writeTestJpeg(sourceDir, 'a.jpg')),
          File(writeTestJpeg(sourceDir, 'b.jpg')),
        ];
        await pumpViewer(tester, files, initialIndex: 1);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('2 / 2'), findsOneWidget);

        await _pinchZoomIn(tester);
        expect(_currentScale(tester), greaterThan(1.0));

        // Drag far enough right to reach the left pan boundary and keep
        // going: this should hand off to the previous photo.
        await _dragInSteps(tester, const Offset(4000, 0));

        expect(find.text('1 / 2'), findsOneWidget);
      },
    );
  });
}
