import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Thrown when a selected source image cannot be decoded (unsupported or
/// corrupt). The caller treats this as a photo-attach failure.
class TackleBoxPhotoDecodeException implements Exception {
  const TackleBoxPhotoDecodeException(this.message);

  final String message;

  @override
  String toString() => 'TackleBoxPhotoDecodeException: $message';
}

/// Thrown when processing succeeded but the file could not be written to
/// application-owned storage.
class TackleBoxPhotoStorageException implements Exception {
  const TackleBoxPhotoStorageException(this.message);

  final String message;

  @override
  String toString() => 'TackleBoxPhotoStorageException: $message';
}

/// Owns the file-system and image-processing side of Personal Tackle Box
/// photos.
///
/// Reuses `CatchPhotoStorage`'s exact processing parameters and atomic
/// temp-file-then-rename write pattern (MFS-013/TD-013), duplicated here
/// rather than shared, consistent with this project's preference for small,
/// feature-owned storage components over a shared `lib/core/` abstraction
/// serving only two call sites.
///
/// Unlike `CatchPhotoStorage`, a `TackleBoxEntry` holds at most one photo —
/// never up to five — so storage uses one flat file per entry
/// (`tackle_box_photos/<tackle-box-entry-id>.jpg`), with no per-entry
/// subdirectory and no photo-id filename. See MFS-016 / TD-016.
class TackleBoxPhotoStorage {
  TackleBoxPhotoStorage({
    required Future<Directory> Function() rootDirectoryProvider,
    int maxLongestSide = defaultMaxLongestSide,
    int jpegQuality = defaultJpegQuality,
  }) : _rootDirectoryProvider = rootDirectoryProvider,
       _maxLongestSide = maxLongestSide,
       _jpegQuality = jpegQuality;

  /// Longest-side cap in pixels; larger images are downscaled preserving
  /// aspect ratio. Smaller images are never upscaled.
  static const int defaultMaxLongestSide = 2048;

  /// JPEG encode quality (0-100).
  static const int defaultJpegQuality = 85;

  static const String photosDirectoryName = 'tackle_box_photos';

  final Future<Directory> Function() _rootDirectoryProvider;
  final int _maxLongestSide;
  final int _jpegQuality;

  /// Processes the image at [sourcePath] and writes it into application-owned
  /// storage, returning the relative path to persist.
  ///
  /// The final file is created atomically: the processed bytes are written to
  /// a temporary file and only renamed into place after a successful write.
  /// On any failure no final file is left behind.
  ///
  /// Throws [TackleBoxPhotoDecodeException] if the source cannot be decoded,
  /// or rethrows underlying I/O errors (e.g. a missing source file).
  Future<String> store({
    required String tackleBoxEntryId,
    required String sourcePath,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final processed = _processImage(bytes);

    final root = await _rootDirectoryProvider();
    final photosDirectory = Directory(p.join(root.path, photosDirectoryName));
    await photosDirectory.create(recursive: true);

    final fileName = '$tackleBoxEntryId.jpg';
    final finalFile = File(p.join(photosDirectory.path, fileName));
    final tempFile = File('${finalFile.path}.tmp');

    try {
      await tempFile.writeAsBytes(processed, flush: true);
      if (!await tempFile.exists()) {
        throw const TackleBoxPhotoStorageException(
          'Processed photo file was not written.',
        );
      }
      await tempFile.rename(finalFile.path);
    } catch (_) {
      await _deleteQuietly(tempFile);
      await _deleteQuietly(finalFile);
      rethrow;
    }

    return p.posix.join(photosDirectoryName, fileName);
  }

  /// Resolves a stored relative path to an absolute [File] under the root.
  Future<File> resolve(String relativePath) async {
    final root = await _rootDirectoryProvider();
    final segments = p.posix.split(relativePath);
    return File(p.joinAll([root.path, ...segments]));
  }

  /// Deletes the file at [relativePath].
  ///
  /// A missing file is treated as already deleted (no error). Genuine
  /// file-system failures propagate so the caller can preserve the database
  /// row and allow retry.
  Future<void> delete(String relativePath) async {
    final file = await resolve(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Uint8List _processImage(Uint8List bytes) {
    final decoded = _decode(bytes);

    final oriented = img.bakeOrientation(decoded);
    final longestSide = math.max(oriented.width, oriented.height);

    final img.Image output;
    if (longestSide > _maxLongestSide) {
      output = oriented.width >= oriented.height
          ? img.copyResize(
              oriented,
              width: _maxLongestSide,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              oriented,
              height: _maxLongestSide,
              interpolation: img.Interpolation.average,
            );
    } else {
      output = oriented;
    }

    return img.encodeJpg(output, quality: _jpegQuality);
  }

  /// Decodes [bytes], converting every failure mode of the underlying `image`
  /// package — a `null` result or any exception it throws internally while
  /// sniffing/parsing an unsupported or corrupt file — into
  /// [TackleBoxPhotoDecodeException]. Callers must never depend on
  /// third-party exception types from the decode step.
  img.Image _decode(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      throw const TackleBoxPhotoDecodeException(
        'Selected image could not be decoded.',
      );
    }

    if (decoded == null) {
      throw const TackleBoxPhotoDecodeException(
        'Selected image could not be decoded.',
      );
    }
    return decoded;
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup; ignore secondary failures.
    }
  }
}
