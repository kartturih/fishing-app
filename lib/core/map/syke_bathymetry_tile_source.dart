import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Reads SYKE bathymetry vector-tile bytes directly from the bundled,
/// preprocessed national MBTiles asset (TD-027 §20/§21/§25). Deliberately
/// narrow and SYKE-specific — not a generalized "local tile source"
/// abstraction (MFS-027 FR-33; this milestone's own explicit instruction
/// against a pluggable bathymetry/provider framework).
///
/// The asset itself (`assets/syke_bathymetry/<assetFileName>`) is a plain
/// SQLite database (the standard MBTiles schema: `metadata`, `tiles`), built
/// entirely offline by `tools/syke_bathymetry/build_mbtiles.py` from the
/// authoritative `EL.ContourLine`/`EL.Syvyysalue` datasets — this class never
/// makes a network request of any kind, and there is no live SYKE WFS call
/// anywhere in the running application.
///
/// `sqlite3` cannot open a database bundled inside the Flutter asset bundle
/// directly (it needs a real file-system path, not an asset-bundle handle),
/// so the asset is copied out to a real file the first time it is needed —
/// see [ensureExtracted]. This is ordinary, one-time app-install/first-run
/// cost, not a network download and not a user-facing "offline map" feature:
/// the data is already inside the app's own installed bundle before
/// extraction ever runs.
///
/// **Content-aware extraction invalidation (bug fix).** A confirmed
/// physical-device investigation found that an earlier version of
/// [ensureExtracted] reused *any* existing, non-empty file already at the
/// target path, with no check that it actually matched the currently
/// bundled asset. `getApplicationSupportDirectory()` survives an ordinary
/// `flutter run`/reinstall-over-existing-app workflow on Android, so a
/// device that had ever extracted an older bundled MBTiles (e.g. before the
/// contiguous-z10–z14 tiling fix) kept silently serving that stale copy —
/// including its stale, non-contiguous zoom gaps — even after the app's own
/// bundled asset was updated. [ensureExtracted] now compares a small,
/// build-time-computed version sidecar (`<assetFileName>.version`, plain
/// text, the MBTiles file's own SHA-256 — written by
/// `tools/syke_bathymetry/build_mbtiles.py`) against the sidecar recorded
/// alongside the previously-extracted copy, and only reuses the existing
/// file when they match — never hashing the full, tens-of-MB MBTiles file
/// itself on-device; only two short strings are ever compared at runtime.
class SykeBathymetryTileSource {
  SykeBathymetryTileSource({
    this.assetFileName = defaultAssetFileName,
    Future<Directory> Function() supportDirectoryProvider =
        getApplicationSupportDirectory,
    Future<ByteData> Function(String assetPath)? loadAsset,
  }) : _supportDirectoryProvider = supportDirectoryProvider,
       _loadAsset = loadAsset ?? rootBundle.load;

  /// The bundled asset's file name. Versioned for *schema* changes (an
  /// attribute/layer-shape change to what `build_mbtiles.py` produces) —
  /// bump this (`_v1` → `_v2`) only when the shape of the data itself
  /// changes, not for an ordinary content refresh (e.g. an updated SYKE
  /// snapshot, or a simplification-tolerance fix), which the version
  /// sidecar below already handles correctly and automatically.
  static const String defaultAssetFileName = 'syke_bathymetry_v1.mbtiles';

  static const String assetDirectory = 'assets/syke_bathymetry';

  final String assetFileName;
  final Future<Directory> Function() _supportDirectoryProvider;
  final Future<ByteData> Function(String assetPath) _loadAsset;

  String get _versionAssetFileName => '$assetFileName.version';

  Database? _db;
  String? _extractedPath;
  int? _extractedByteSize;
  String? _bundledVersion;
  bool? _lastExtractionWasReplace;

  /// The real, on-disk path of the extracted MBTiles file, once
  /// [ensureExtracted] has completed. `null` before that.
  String? get extractedPath => _extractedPath;

  /// The extracted MBTiles file's byte size, once [ensureExtracted] has
  /// completed. `null` before that.
  int? get extractedByteSize => _extractedByteSize;

  /// The bundled asset's own version identifier (its SHA-256, per the
  /// `.version` sidecar `build_mbtiles.py` writes), once [ensureExtracted]
  /// has completed and the sidecar was readable. `null` before that, or if
  /// the sidecar could not be read.
  String? get bundledVersion => _bundledVersion;

  /// Whether the most recent [ensureExtracted] call actually replaced the
  /// on-disk copy (`true`), reused an already-current one (`false`), or
  /// has not run yet (`null`) — exposed so the content-aware extraction
  /// invalidation fix (this class's own doc comment) has a directly
  /// observable outcome for tests to assert on, since the real effect
  /// (replace vs. reuse) is otherwise only visible as an internal file
  /// write.
  bool? get lastExtractionWasReplace => _lastExtractionWasReplace;

  /// Copies the bundled asset out to a real file — but only when the
  /// existing extracted copy (if any) does not match the currently bundled
  /// asset's own version — and opens it read-only. Idempotent and safe to
  /// call multiple times — a second call with nothing changed is a cheap
  /// no-op (two short string reads/comparisons, no multi-MB I/O).
  ///
  /// **Version comparison, precisely:** the bundled `.version` sidecar
  /// (this asset's own SHA-256, written at build time) is compared against
  /// a sidecar of the same name previously written alongside the extracted
  /// copy. Re-extraction happens whenever they differ, including when the
  /// extracted sidecar is missing entirely (e.g. a device upgrading from
  /// an app version that predates this mechanism — the exact real-world
  /// case this fix targets: an existing, undated stale copy must not be
  /// trusted just because a file happens to be present). If the *bundled*
  /// sidecar itself cannot be read, freshness cannot be verified either
  /// way; an already-present target file is conservatively kept rather
  /// than unconditionally forcing a large, likely-pointless re-copy every
  /// launch — only a genuinely missing/empty target still forces
  /// extraction in that specific, degraded case.
  ///
  /// **Atomicity (Android robustness — unchanged from before, now applied
  /// consistently to both files):** both the MBTiles file and its version
  /// sidecar are written to a `.tmp` sibling first and renamed into place
  /// only once their write completes fully — the MBTiles file is renamed
  /// into place *before* the sidecar is, so a process death between the
  /// two leaves, at worst, a correctly-updated MBTiles file paired with a
  /// stale-or-missing sidecar, which is self-correcting (simply causes one
  /// extra, harmless re-extraction next launch) rather than ever leaving a
  /// truncated/corrupt MBTiles file mistaken for a complete one, or ever
  /// deleting a previously-valid copy before its replacement is fully
  /// ready.
  ///
  /// If extraction fails, [ensureExtracted] rethrows — the caller
  /// (`MapScreen`, mirroring its own already-established pattern for
  /// `MmlVectorProxyService`) treats this exactly like "the local service
  /// failed to start": the SYKE overlay is simply omitted, never a crash.
  /// A failed replacement attempt never touches the previously-valid
  /// target file at all (per the atomicity guarantee above), so a
  /// previously-working extracted copy remains exactly as usable as it was
  /// before the failed attempt.
  Future<void> ensureExtracted() async {
    if (_db != null) {
      return;
    }

    final supportDir = await _supportDirectoryProvider();
    final targetDir = Directory('${supportDir.path}/$assetDirectory');
    await targetDir.create(recursive: true);
    final targetFile = File('${targetDir.path}/$assetFileName');
    final targetVersionFile = File(
      '${targetDir.path}/$_versionAssetFileName',
    );

    final targetExists =
        await targetFile.exists() && await targetFile.length() > 0;

    String? bundledVersion;
    try {
      bundledVersion = await _readAssetString(
        '$assetDirectory/$_versionAssetFileName',
      );
    } catch (_) {
      bundledVersion = null;
    }
    _bundledVersion = bundledVersion;

    String? extractedVersion;
    if (targetExists && await targetVersionFile.exists()) {
      try {
        extractedVersion = await targetVersionFile.readAsString();
      } catch (_) {
        extractedVersion = null;
      }
    }

    // A genuinely missing/empty target always needs extraction. A present
    // target is only invalidated when the bundled version is actually
    // known and differs from what was last extracted — see this method's
    // own doc comment for why an unreadable bundled sidecar does not, on
    // its own, force a large re-copy of an already-present file.
    final needsExtraction =
        !targetExists ||
        (bundledVersion != null && extractedVersion != bundledVersion);

    if (needsExtraction) {
      final data = await _loadAsset('$assetDirectory/$assetFileName');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final tempFile = File('${targetFile.path}.tmp');
      await tempFile.writeAsBytes(bytes, flush: true);
      await tempFile.rename(targetFile.path);

      if (bundledVersion != null) {
        final tempVersionFile = File('${targetVersionFile.path}.tmp');
        await tempVersionFile.writeAsString(bundledVersion, flush: true);
        await tempVersionFile.rename(targetVersionFile.path);
      }
      _lastExtractionWasReplace = true;
    } else {
      _lastExtractionWasReplace = false;
    }

    _extractedPath = targetFile.path;
    _extractedByteSize = await targetFile.length();
    _db = sqlite3.open(targetFile.path, mode: OpenMode.readOnly);
  }

  Future<String> _readAssetString(String assetPath) async {
    final data = await _loadAsset(assetPath);
    return _utf8DecodeTrim(data);
  }

  /// Returns the raw MVT tile bytes for `z/x/y` (standard `{z}/{x}/{y}`
  /// order, matching MapLibre's own default and this project's MapTiler
  /// convention — MBTiles' own on-disk `tile_row` uses the TMS
  /// (Y-flipped) convention internally, translated here so no caller needs
  /// to know about that), or `null` if the tile genuinely has no data at
  /// that coordinate.
  ///
  /// A `null` result is the correct, expected "no bathymetry here" case
  /// (MFS-027 FR-29) for the large majority of Finland's water bodies SYKE
  /// does not cover — never an error, never logged, never distinguished
  /// from "this area was never expected to have data."
  Uint8List? tileFor(int z, int x, int y) {
    final db = _db;
    if (db == null) {
      throw StateError('SykeBathymetryTileSource.ensureExtracted() was not '
          'awaited before tileFor() was called');
    }
    final tmsY = (1 << z) - 1 - y;
    final result = db.select(
      'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? '
      'AND tile_row = ? LIMIT 1',
      [z, x, tmsY],
    );
    if (result.isEmpty) {
      return null;
    }
    final blob = result.first['tile_data'];
    return blob is Uint8List ? blob : Uint8List.fromList(blob as List<int>);
  }

  /// Closes the underlying database connection. Safe to call even if
  /// [ensureExtracted] was never called or already closed.
  void close() {
    _db?.close();
    _db = null;
  }
}

/// Decodes a small text asset's `ByteData` as UTF-8 and trims surrounding
/// whitespace (a build-time-written sidecar file may or may not carry a
/// trailing newline depending on the tool that wrote it — trimming keeps
/// the comparison exact either way).
String _utf8DecodeTrim(ByteData data) {
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  return String.fromCharCodes(bytes).trim();
}
