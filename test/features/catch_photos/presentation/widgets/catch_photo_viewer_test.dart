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

  testWidgets('navigates between multiple photos', (tester) async {
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
}
