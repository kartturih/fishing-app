import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';

void main() {
  late Directory tempDir;
  late TackleBoxPhotoStorage storage;

  Uint8List buildJpegBytes({required int width, required int height}) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(10, 120, 200));
    return img.encodeJpg(image);
  }

  File writeSourceFile(String name, List<int> bytes) {
    final file = File(p.join(tempDir.path, 'source', name));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return file;
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'tackle_box_photo_storage_test',
    );
    storage = TackleBoxPhotoStorage(
      rootDirectoryProvider: () async => tempDir,
      maxLongestSide: 100,
      jpegQuality: 85,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('store', () {
    test(
      'creates the photos directory and returns a flat relative path',
      () async {
        final source = writeSourceFile(
          'a.jpg',
          buildJpegBytes(width: 40, height: 30),
        );

        final relativePath = await storage.store(
          tackleBoxEntryId: 'entry-1',
          sourcePath: source.path,
        );

        expect(relativePath, 'tackle_box_photos/entry-1.jpg');
        final photosDirectory = Directory(
          p.join(tempDir.path, 'tackle_box_photos'),
        );
        expect(photosDirectory.existsSync(), isTrue);
      },
    );

    test('creates the final file on disk', () async {
      final source = writeSourceFile(
        'a.jpg',
        buildJpegBytes(width: 40, height: 30),
      );

      final relativePath = await storage.store(
        tackleBoxEntryId: 'entry-1',
        sourcePath: source.path,
      );

      final finalFile = File(p.join(tempDir.path, relativePath));
      expect(finalFile.existsSync(), isTrue);
      expect(finalFile.lengthSync(), greaterThan(0));
    });

    test('leaves no temporary file behind after a successful store', () async {
      final source = writeSourceFile(
        'a.jpg',
        buildJpegBytes(width: 40, height: 30),
      );

      await storage.store(tackleBoxEntryId: 'entry-1', sourcePath: source.path);

      final tempFile = File(
        p.join(tempDir.path, 'tackle_box_photos', 'entry-1.jpg.tmp'),
      );
      expect(tempFile.existsSync(), isFalse);
    });

    test('encodes the output as a decodable JPEG', () async {
      final source = writeSourceFile(
        'a.jpg',
        buildJpegBytes(width: 40, height: 30),
      );

      final relativePath = await storage.store(
        tackleBoxEntryId: 'entry-1',
        sourcePath: source.path,
      );

      final bytes = await File(
        p.join(tempDir.path, relativePath),
      ).readAsBytes();
      final decoded = img.decodeJpg(bytes);
      expect(decoded, isNotNull);
    });

    test('does not upscale an image smaller than the maximum', () async {
      final source = writeSourceFile(
        'small.jpg',
        buildJpegBytes(width: 40, height: 30),
      );

      final relativePath = await storage.store(
        tackleBoxEntryId: 'entry-1',
        sourcePath: source.path,
      );

      final bytes = await File(
        p.join(tempDir.path, relativePath),
      ).readAsBytes();
      final decoded = img.decodeJpg(bytes)!;
      expect(decoded.width, 40);
      expect(decoded.height, 30);
    });

    test('downscales an image larger than the maximum longest side', () async {
      final source = writeSourceFile(
        'large.jpg',
        buildJpegBytes(width: 200, height: 100),
      );

      final relativePath = await storage.store(
        tackleBoxEntryId: 'entry-1',
        sourcePath: source.path,
      );

      final bytes = await File(
        p.join(tempDir.path, relativePath),
      ).readAsBytes();
      final decoded = img.decodeJpg(bytes)!;
      expect(decoded.width, 100);
      expect(decoded.height, 50);
    });

    test(
      'throws TackleBoxPhotoDecodeException for a corrupt source image',
      () async {
        final source = writeSourceFile('corrupt.jpg', List<int>.filled(200, 0));

        expect(
          () => storage.store(
            tackleBoxEntryId: 'entry-1',
            sourcePath: source.path,
          ),
          throwsA(isA<TackleBoxPhotoDecodeException>()),
        );
      },
    );

    test('propagates an error for a missing source image', () async {
      final missingPath = p.join(tempDir.path, 'source', 'missing.jpg');

      expect(
        () =>
            storage.store(tackleBoxEntryId: 'entry-1', sourcePath: missingPath),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('cleans up the temp file when the final rename fails', () async {
      final source = writeSourceFile(
        'a.jpg',
        buildJpegBytes(width: 40, height: 30),
      );
      // Pre-create the final file's path as a directory so the rename in
      // store() fails, forcing the cleanup branch to run.
      final finalFileAsDirectory = Directory(
        p.join(tempDir.path, 'tackle_box_photos', 'entry-1.jpg'),
      );
      finalFileAsDirectory.createSync(recursive: true);

      await expectLater(
        storage.store(tackleBoxEntryId: 'entry-1', sourcePath: source.path),
        throwsA(anything),
      );

      final tempFile = File(
        p.join(tempDir.path, 'tackle_box_photos', 'entry-1.jpg.tmp'),
      );
      expect(tempFile.existsSync(), isFalse);
    });

    test('overwrites an existing file for a re-stored entry id', () async {
      final firstSource = writeSourceFile(
        'first.jpg',
        buildJpegBytes(width: 40, height: 30),
      );
      final secondSource = writeSourceFile(
        'second.jpg',
        buildJpegBytes(width: 60, height: 20),
      );

      await storage.store(
        tackleBoxEntryId: 'entry-1',
        sourcePath: firstSource.path,
      );
      final relativePath = await storage.store(
        tackleBoxEntryId: 'entry-1',
        sourcePath: secondSource.path,
      );

      final bytes = await File(
        p.join(tempDir.path, relativePath),
      ).readAsBytes();
      final decoded = img.decodeJpg(bytes)!;
      expect(decoded.width, 60);
      expect(decoded.height, 20);
    });
  });

  group('resolve', () {
    test(
      'resolves a relative path to an absolute file under the root',
      () async {
        final file = await storage.resolve('tackle_box_photos/entry-1.jpg');

        expect(
          file.path,
          p.join(tempDir.path, 'tackle_box_photos', 'entry-1.jpg'),
        );
      },
    );
  });

  group('delete', () {
    test('deletes an existing file', () async {
      final source = writeSourceFile(
        'a.jpg',
        buildJpegBytes(width: 40, height: 30),
      );
      final relativePath = await storage.store(
        tackleBoxEntryId: 'entry-1',
        sourcePath: source.path,
      );

      await storage.delete(relativePath);

      final file = await storage.resolve(relativePath);
      expect(file.existsSync(), isFalse);
    });

    test('completes successfully for an already-missing file', () async {
      await expectLater(
        storage.delete('tackle_box_photos/does-not-exist.jpg'),
        completes,
      );
    });
  });
}
