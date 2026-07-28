import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:fishing_app/core/map/syke_bathymetry_tile_source.dart';

/// Covers `SykeBathymetryTileSource` (TD-027 §20/§22/§25) against a small,
/// synthetic MBTiles fixture built directly with `sqlite3` in a temp
/// directory — never the real, ~71 MB bundled national asset, and never a
/// real Flutter asset bundle (a fake `loadAsset` stands in for
/// `rootBundle.load`).
///
/// Also covers the stale-extracted-copy fix: a confirmed physical-device
/// bug where `ensureExtracted()` used to reuse any existing, non-empty
/// extracted file forever, so a device that had ever extracted an older
/// bundled MBTiles kept silently serving it — including its stale,
/// non-contiguous zoom gaps — even after the app's own bundled asset was
/// updated. The `'content-aware extraction invalidation'` group below
/// exercises the version-sidecar mechanism that replaced that behavior.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('syke_tile_source_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// Builds a minimal, real MBTiles SQLite file (standard schema) with one
  /// tile at 5/10/12 (TMS `tile_row`), and returns its raw bytes.
  Uint8List buildFixtureMbtilesBytes({required List<int> tileBytes}) {
    final path = '${tempDir.path}/fixture_source_${identityHashCode(tileBytes)}.mbtiles';
    final db = sqlite3.open(path);
    db.execute('CREATE TABLE metadata (name TEXT, value TEXT)');
    db.execute(
      'CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, '
      'tile_row INTEGER, tile_data BLOB)',
    );
    db.execute(
      'INSERT INTO tiles (zoom_level, tile_column, tile_row, tile_data) '
      'VALUES (?, ?, ?, ?)',
      [5, 10, 12, tileBytes],
    );
    db.close();
    final bytes = File(path).readAsBytesSync();
    File(path).deleteSync();
    return bytes;
  }

  /// A `loadAsset` fake that routes by the requested asset path, exactly
  /// like `rootBundle.load` does against a real bundle with two files
  /// (the `.mbtiles` and its `.version` sidecar) — unlike a fake that
  /// ignores its path argument (which cannot distinguish "the sidecar was
  /// read" from "the heavy asset was read"), this lets tests assert on
  /// mbtiles-load count and version-load count independently, which is the
  /// whole point of the version-sidecar mechanism: the small sidecar may be
  /// read cheaply every launch, but the heavy asset must not be.
  Future<ByteData> Function(String) routedLoadAsset({
    required Uint8List mbtilesBytes,
    String? version,
    void Function()? onMbtilesLoad,
    void Function()? onVersionLoad,
  }) {
    return (String path) async {
      if (path.endsWith('.version')) {
        onVersionLoad?.call();
        if (version == null) {
          throw Exception('no bundled version sidecar (asset not found)');
        }
        return Uint8List.fromList(utf8.encode(version)).buffer.asByteData();
      }
      onMbtilesLoad?.call();
      return mbtilesBytes.buffer.asByteData();
    };
  }

  SykeBathymetryTileSource buildSource(
    Uint8List assetBytes, {
    String? version = 'test-version-1',
    Directory? dir,
  }) {
    return SykeBathymetryTileSource(
      supportDirectoryProvider: () async => dir ?? tempDir,
      loadAsset: routedLoadAsset(mbtilesBytes: assetBytes, version: version),
    );
  }

  /// Builds a fixture mirroring the production pyramid's shape (TD-027
  /// §20/§22, revised after physical Android testing found the original
  /// [8, 10, 12, 14] range non-contiguous): one real tile at the *same*
  /// x/y position, present at every zoom in [zooms], absent everywhere
  /// else — used to prove `tileFor`'s own query behavior is correct across
  /// a genuinely continuous range and at its boundaries, independent of
  /// whether `tools/syke_bathymetry/build_mbtiles.py` itself was run
  /// correctly (that pipeline-level continuity is verified separately,
  /// directly against the real regenerated asset, not via this Flutter
  /// test suite — see TD-027 §20A's own established discipline against
  /// depending on the real, tens-of-MB national asset from unit tests).
  Uint8List buildContiguousFixtureBytes({
    required List<int> zooms,
    required int x,
    required int tmsRow,
    String suffix = '',
  }) {
    final path = '${tempDir.path}/fixture_contiguous$suffix.mbtiles';
    final db = sqlite3.open(path);
    db.execute('CREATE TABLE metadata (name TEXT, value TEXT)');
    db.execute(
      'CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, '
      'tile_row INTEGER, tile_data BLOB)',
    );
    for (final z in zooms) {
      db.execute(
        'INSERT INTO tiles (zoom_level, tile_column, tile_row, tile_data) '
        'VALUES (?, ?, ?, ?)',
        [z, x, tmsRow, <int>[z]],
      );
    }
    db.close();
    final bytes = File(path).readAsBytesSync();
    File(path).deleteSync();
    return bytes;
  }

  test(
    'ensureExtracted copies the bundled asset out to a real file, which '
    'tileFor then reads correctly-positioned tiles from (z/x/y -> TMS row)',
    () async {
      final tileBytes = [1, 2, 3, 4, 5];
      final assetBytes = buildFixtureMbtilesBytes(tileBytes: tileBytes);
      final source = buildSource(assetBytes);

      await source.ensureExtracted();

      expect(source.extractedPath, isNotNull);
      expect(File(source.extractedPath!).existsSync(), isTrue);

      // z=5 -> n=32 tiles per axis; TMS tile_row 12 corresponds to
      // standard (XYZ) y = 32 - 1 - 12 = 19.
      final result = source.tileFor(5, 10, 19);
      expect(result, isNotNull);
      expect(result, equals(tileBytes));

      source.close();
    },
  );

  test(
    'tileFor returns null for a genuinely absent tile — the correct, '
    'expected "no bathymetry here" case (MFS-027 FR-29), not an error',
    () async {
      final assetBytes = buildFixtureMbtilesBytes(tileBytes: [9, 9, 9]);
      final source = buildSource(assetBytes);

      await source.ensureExtracted();

      final result = source.tileFor(5, 0, 0);
      expect(result, isNull);

      source.close();
    },
  );

  test('ensureExtracted is idempotent — a second call does not re-copy or '
      'fail', () async {
    final assetBytes = buildFixtureMbtilesBytes(tileBytes: [1]);
    final source = buildSource(assetBytes);

    await source.ensureExtracted();
    final firstPath = source.extractedPath;
    await source.ensureExtracted();

    expect(source.extractedPath, firstPath);

    source.close();
  });

  test(
    'tileFor throws StateError if called before ensureExtracted — a '
    'programming-error guard, not a runtime user-facing condition',
    () {
      final source = SykeBathymetryTileSource(
        supportDirectoryProvider: () async => tempDir,
        loadAsset: (_) async => Uint8List(0).buffer.asByteData(),
      );

      expect(() => source.tileFor(1, 0, 0), throwsStateError);
    },
  );

  group(
    'zoom-range continuity (TD-027 §20/§22, root-cause regression coverage '
    'for the "contours disappear when zooming in" bug)',
    () {
      test(
        'a tile is found at every zoom in a genuinely contiguous z10–z14 '
        'range — the shape the production pipeline must now produce, in '
        'place of the original, buggy non-contiguous [8, 10, 12, 14] range',
        () async {
          const zooms = [10, 11, 12, 13, 14];
          final assetBytes = buildContiguousFixtureBytes(
            zooms: zooms,
            x: 1,
            tmsRow: 1,
          );
          final source = buildSource(assetBytes);
          await source.ensureExtracted();

          for (final z in zooms) {
            final y = (1 << z) - 1 - 1; // tmsRow=1 -> standard XYZ y
            final result = source.tileFor(z, 1, y);
            expect(
              result,
              equals([z]),
              reason: 'zoom $z must be present — a gap here is exactly the '
                  'bug that caused visible flicker/disappearance while '
                  'zooming',
            );
          }

          source.close();
        },
      );

      test(
        'zoom 9 (immediately below the real z10 floor) is genuinely absent '
        '— correct, since the presentation layer never shows this source '
        'below its own minzoom (10) either way, so nothing is lost by not '
        'tiling it',
        () async {
          final assetBytes = buildContiguousFixtureBytes(
            zooms: const [10, 11, 12, 13, 14],
            x: 1,
            tmsRow: 1,
          );
          final source = buildSource(assetBytes);
          await source.ensureExtracted();

          final y9 = (1 << 9) - 1 - 1;
          expect(source.tileFor(9, 1, y9), isNull);

          source.close();
        },
      );

      test(
        'zooms 15 through 18 (beyond the real z14 ceiling) are genuinely '
        'absent from this on-device data source — correct and expected: '
        'MapLibre\'s own vector-source overzoom is what is relied on to '
        'keep contours visible there (a client-side mechanism outside '
        'this class\'s own responsibility), not a further-tiled row this '
        'class could serve. A well-formed MapLibre client should never '
        'actually request these zooms from this route at all once the '
        'source honestly declares maxzoom 14, but this class must still '
        'degrade gracefully (null, not a crash) if one ever did',
        () async {
          final assetBytes = buildContiguousFixtureBytes(
            zooms: const [10, 11, 12, 13, 14],
            x: 1,
            tmsRow: 1,
          );
          final source = buildSource(assetBytes);
          await source.ensureExtracted();

          for (final z in [15, 16, 17, 18]) {
            final y = (1 << z) - 1 - 1;
            expect(
              source.tileFor(z, 1, y),
              isNull,
              reason: 'z$z must not be served locally — overzoom of the '
                  'real z14 tile is MapLibre\'s own job',
            );
          }

          source.close();
        },
      );
    },
  );

  group(
    'content-aware extraction invalidation (stale-SYKE-asset fix — a '
    'confirmed physical-device bug: getApplicationSupportDirectory() '
    'survives ordinary flutter run/reinstall workflows on Android, so an '
    'existence-only reuse check let a device keep serving an older '
    'extracted MBTiles file forever, even after the bundled asset changed)',
    () {
      test(
        'first extraction (nothing on disk yet) creates the file, loads '
        'the bundled mbtiles exactly once, and reports a replace action',
        () async {
          final assetBytes = buildFixtureMbtilesBytes(tileBytes: [1]);
          var mbtilesLoads = 0;
          final source = SykeBathymetryTileSource(
            supportDirectoryProvider: () async => tempDir,
            loadAsset: routedLoadAsset(
              mbtilesBytes: assetBytes,
              version: 'v1',
              onMbtilesLoad: () => mbtilesLoads++,
            ),
          );

          await source.ensureExtracted();

          expect(File(source.extractedPath!).existsSync(), isTrue);
          expect(mbtilesLoads, 1);
          expect(source.lastExtractionWasReplace, isTrue);
          expect(source.bundledVersion, 'v1');
          expect(source.extractedByteSize, assetBytes.length);

          source.close();
        },
      );

      test(
        'a second instance whose bundled version matches the previously '
        'extracted copy\'s sidecar reuses the file on disk without '
        'reloading the heavy mbtiles asset (only the small version '
        'sidecar is read again) — the real-world "second app launch, '
        'nothing changed" case',
        () async {
          final assetBytes = buildFixtureMbtilesBytes(tileBytes: [7, 7]);
          var mbtilesLoads = 0;

          SykeBathymetryTileSource makeSource() => SykeBathymetryTileSource(
            supportDirectoryProvider: () async => tempDir,
            loadAsset: routedLoadAsset(
              mbtilesBytes: assetBytes,
              version: 'same-version',
              onMbtilesLoad: () => mbtilesLoads++,
            ),
          );

          final first = makeSource();
          await first.ensureExtracted();
          first.close();
          expect(mbtilesLoads, 1);
          expect(first.lastExtractionWasReplace, isTrue);

          final second = makeSource();
          await second.ensureExtracted();
          expect(
            mbtilesLoads,
            1,
            reason: 'the already-extracted file is reused; only the cheap '
                'version sidecar should have been read again, never the '
                'full ~71 MB asset',
          );
          expect(second.lastExtractionWasReplace, isFalse);
          final result = second.tileFor(5, 10, 19);
          expect(result, equals([7, 7]));
          second.close();
        },
      );

      test(
        'a stale extracted copy (older bundled version than what is now '
        'bundled) is replaced — this is the exact bug scenario: a device '
        'that extracted an old asset must not keep serving it forever '
        'once the bundled asset is updated',
        () async {
          final oldAssetBytes = buildFixtureMbtilesBytes(
            tileBytes: [1, 1, 1],
          );
          final newAssetBytes = buildFixtureMbtilesBytes(
            tileBytes: [2, 2, 2],
          );

          final first = SykeBathymetryTileSource(
            supportDirectoryProvider: () async => tempDir,
            loadAsset: routedLoadAsset(
              mbtilesBytes: oldAssetBytes,
              version: 'v1-old',
            ),
          );
          await first.ensureExtracted();
          expect(first.tileFor(5, 10, 19), equals([1, 1, 1]));
          first.close();

          var mbtilesLoads = 0;
          final second = SykeBathymetryTileSource(
            supportDirectoryProvider: () async => tempDir,
            loadAsset: routedLoadAsset(
              mbtilesBytes: newAssetBytes,
              version: 'v2-new',
              onMbtilesLoad: () => mbtilesLoads++,
            ),
          );
          await second.ensureExtracted();

          expect(mbtilesLoads, 1, reason: 'a stale version must trigger a '
              'real re-copy of the new bundled asset');
          expect(second.lastExtractionWasReplace, isTrue);
          expect(second.bundledVersion, 'v2-new');
          expect(
            second.tileFor(5, 10, 19),
            equals([2, 2, 2]),
            reason: 'the replaced file must actually serve the NEW '
                'content, not the stale one',
          );
          second.close();
        },
      );

      test(
        'stale MBTiles containing the old sparse zoom pyramid cannot be '
        'silently reused once the bundled asset\'s version has moved on to '
        'a continuous pyramid — directly reproduces the physical-device '
        'symptom (contours disappearing at some zooms) and proves the fix',
        () async {
          final sparseBytes = buildContiguousFixtureBytes(
            zooms: const [8, 10, 12, 14],
            x: 1,
            tmsRow: 1,
            suffix: '_sparse',
          );
          final continuousBytes = buildContiguousFixtureBytes(
            zooms: const [10, 11, 12, 13, 14],
            x: 1,
            tmsRow: 1,
            suffix: '_continuous',
          );

          final stale = SykeBathymetryTileSource(
            supportDirectoryProvider: () async => tempDir,
            loadAsset: routedLoadAsset(
              mbtilesBytes: sparseBytes,
              version: 'sparse-pyramid-v1',
            ),
          );
          await stale.ensureExtracted();
          // z=11 is genuinely missing in the old sparse pyramid.
          final y11 = (1 << 11) - 1 - 1;
          expect(stale.tileFor(11, 1, y11), isNull);
          stale.close();

          final fresh = SykeBathymetryTileSource(
            supportDirectoryProvider: () async => tempDir,
            loadAsset: routedLoadAsset(
              mbtilesBytes: continuousBytes,
              version: 'continuous-pyramid-v2',
            ),
          );
          await fresh.ensureExtracted();

          expect(fresh.lastExtractionWasReplace, isTrue);
          expect(
            fresh.tileFor(11, 1, y11),
            equals([11]),
            reason: 'z11 must now be present — the stale sparse copy must '
                'not have been silently reused',
          );
          fresh.close();
        },
      );

      test(
        'a failed replacement attempt does not destroy the previously-'
        'valid extracted copy — the new load fails (simulating, e.g., a '
        'transient asset-bundle read error), so a subsequent source '
        'instance must still find and serve the original, still-valid '
        'file rather than a missing or half-written one',
        () async {
          final goodBytes = buildFixtureMbtilesBytes(tileBytes: [5, 5, 5]);

          final good = SykeBathymetryTileSource(
            supportDirectoryProvider: () async => tempDir,
            loadAsset: routedLoadAsset(
              mbtilesBytes: goodBytes,
              version: 'v1-good',
            ),
          );
          await good.ensureExtracted();
          final extractedPath = good.extractedPath!;
          good.close();

          final failing = SykeBathymetryTileSource(
            supportDirectoryProvider: () async => tempDir,
            loadAsset: (String path) async {
              if (path.endsWith('.version')) {
                return Uint8List.fromList(
                  utf8.encode('v2-new-but-fails'),
                ).buffer.asByteData();
              }
              throw Exception('simulated asset read failure');
            },
          );

          await expectLater(failing.ensureExtracted(), throwsException);

          // The previously-valid file on disk must be untouched.
          expect(File(extractedPath).existsSync(), isTrue);
          expect(File(extractedPath).lengthSync(), goodBytes.length);

          final recovery = SykeBathymetryTileSource(
            supportDirectoryProvider: () async => tempDir,
            loadAsset: routedLoadAsset(
              mbtilesBytes: goodBytes,
              version: 'v1-good',
            ),
          );
          await recovery.ensureExtracted();
          expect(recovery.lastExtractionWasReplace, isFalse);
          expect(recovery.tileFor(5, 10, 19), equals([5, 5, 5]));
          recovery.close();
        },
      );

      test(
        'a zero-length target file forces re-extraction even if a version '
        'sidecar happens to already be present and matching',
        () async {
          final assetBytes = buildFixtureMbtilesBytes(tileBytes: [3, 3]);
          final targetDir = Directory(
            '${tempDir.path}/assets/syke_bathymetry',
          );
          await targetDir.create(recursive: true);
          final targetFile = File(
            '${targetDir.path}/${SykeBathymetryTileSource.defaultAssetFileName}',
          );
          await targetFile.writeAsBytes(<int>[]);
          final versionFile = File(
            '${targetDir.path}/'
            '${SykeBathymetryTileSource.defaultAssetFileName}.version',
          );
          await versionFile.writeAsString('v1');

          var mbtilesLoads = 0;
          final source = SykeBathymetryTileSource(
            supportDirectoryProvider: () async => tempDir,
            loadAsset: routedLoadAsset(
              mbtilesBytes: assetBytes,
              version: 'v1',
              onMbtilesLoad: () => mbtilesLoads++,
            ),
          );

          await source.ensureExtracted();

          expect(mbtilesLoads, 1);
          expect(source.lastExtractionWasReplace, isTrue);
          expect(source.tileFor(5, 10, 19), equals([3, 3]));
          source.close();
        },
      );

      test(
        'a missing target file forces re-extraction (the ordinary first-'
        'launch case, restated explicitly for this group)',
        () async {
          final assetBytes = buildFixtureMbtilesBytes(tileBytes: [4]);
          var mbtilesLoads = 0;
          final source = SykeBathymetryTileSource(
            supportDirectoryProvider: () async => tempDir,
            loadAsset: routedLoadAsset(
              mbtilesBytes: assetBytes,
              version: 'v1',
              onMbtilesLoad: () => mbtilesLoads++,
            ),
          );

          await source.ensureExtracted();

          expect(mbtilesLoads, 1);
          expect(source.lastExtractionWasReplace, isTrue);
          source.close();
        },
      );

      test(
        'an existing extracted file with no version sidecar at all (a '
        'device upgrading from an app version that predates this fix) is '
        'treated as stale and replaced, rather than trusted just because '
        'a file happens to be present at the target path',
        () async {
          final oldBytes = buildFixtureMbtilesBytes(tileBytes: [1]);
          final newBytes = buildFixtureMbtilesBytes(tileBytes: [2]);

          // Simulate a pre-fix extraction: mbtiles present, no sidecar.
          final targetDir = Directory(
            '${tempDir.path}/assets/syke_bathymetry',
          );
          await targetDir.create(recursive: true);
          final targetFile = File(
            '${targetDir.path}/${SykeBathymetryTileSource.defaultAssetFileName}',
          );
          await targetFile.writeAsBytes(oldBytes);

          var mbtilesLoads = 0;
          final source = SykeBathymetryTileSource(
            supportDirectoryProvider: () async => tempDir,
            loadAsset: routedLoadAsset(
              mbtilesBytes: newBytes,
              version: 'v2',
              onMbtilesLoad: () => mbtilesLoads++,
            ),
          );

          await source.ensureExtracted();

          expect(mbtilesLoads, 1);
          expect(source.lastExtractionWasReplace, isTrue);
          expect(source.tileFor(5, 10, 19), equals([2]));
          source.close();
        },
      );

      test(
        'when the bundled version sidecar itself cannot be read, an '
        'already-present, non-empty target file is conservatively kept '
        '(no way to verify freshness either way) rather than forcing an '
        'unconditional, likely-pointless re-copy on every single launch',
        () async {
          final assetBytes = buildFixtureMbtilesBytes(tileBytes: [6, 6]);

          final first = SykeBathymetryTileSource(
            supportDirectoryProvider: () async => tempDir,
            loadAsset: routedLoadAsset(
              mbtilesBytes: assetBytes,
              version: 'v1',
            ),
          );
          await first.ensureExtracted();
          first.close();

          var mbtilesLoads = 0;
          final second = SykeBathymetryTileSource(
            supportDirectoryProvider: () async => tempDir,
            loadAsset: routedLoadAsset(
              mbtilesBytes: assetBytes,
              version: null,
              onMbtilesLoad: () => mbtilesLoads++,
            ),
          );
          await second.ensureExtracted();

          expect(mbtilesLoads, 0);
          expect(second.lastExtractionWasReplace, isFalse);
          expect(second.bundledVersion, isNull);
          second.close();
        },
      );
    },
  );
}
