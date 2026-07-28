import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/map/mml_vector_proxy_service.dart';
import 'package:fishing_app/core/map/syke_bathymetry_tile_source.dart';

/// Covers `MmlVectorProxyService` (TD-027 §3F/§20/§25): the local, on-device
/// loopback proxy for MML's real v21 vector base map and, on the same
/// listener, the bundled SYKE bathymetry overlay. Every upstream MML
/// request is intercepted via the injectable `httpGetBytes`/`httpGetString`
/// constructor parameters — no real network call, no real key, anywhere in
/// this file (mirroring the retired raster `MmlTileMaskService`'s own
/// established testing pattern).
void main() {
  group('fetchMmlStyleFragment', () {
    test(
      'strips the single unconditional "background" layer, rewrites the '
      'source/glyphs URLs to this service\'s own loopback address, and '
      'never includes the real api-key anywhere in the returned fragment',
      () async {
        final realStyle = jsonEncode({
          'version': 8,
          'sources': {
            'taustakartta': {
              'type': 'vector',
              'url': 'https://real.mml.example/tilejson.json?api-key=SECRET',
            },
          },
          'glyphs':
              'https://real.mml.example/glyphs/{fontstack}/{range}.pbf?api-key=SECRET',
          'layers': [
            {
              'id': 'background',
              'type': 'background',
              'paint': {'background-color': '#dceacc'},
            },
            {
              'id': 'vesisto_alue',
              'type': 'fill',
              'source': 'taustakartta',
              'source-layer': 'vesisto_alue',
            },
          ],
        });

        final service = MmlVectorProxyService(
          apiKey: 'real-secret-key',
          httpGetString: (uri) async {
            expect(uri.queryParameters['api-key'], 'real-secret-key');
            return realStyle;
          },
        );
        await service.start();
        addTearDown(service.stop);

        final fragmentJson = await service.fetchMmlStyleFragment();
        expect(fragmentJson, isNotNull);
        expect(fragmentJson, isNot(contains('SECRET')));
        expect(fragmentJson, isNot(contains('real-secret-key')));
        expect(fragmentJson, isNot(contains('real.mml.example')));

        final fragment = jsonDecode(fragmentJson!) as Map<String, dynamic>;
        final layers = fragment['layers'] as List<dynamic>;
        expect(
          layers.any((l) => (l as Map)['id'] == 'background'),
          isFalse,
          reason: 'the unconditional background layer must be removed',
        );
        expect(layers.any((l) => (l as Map)['id'] == 'vesisto_alue'), isTrue);

        final sources = fragment['sources'] as Map<String, dynamic>;
        final taustakartta = sources['taustakartta'] as Map<String, dynamic>;
        expect(taustakartta['type'], 'vector');
        expect(
          (taustakartta['tiles'] as List).single,
          startsWith('${service.baseUrl}/mml/v21/tiles/'),
        );
        expect(taustakartta['minzoom'], MmlVectorProxyService.minZoom);
        expect(taustakartta['maxzoom'], MmlVectorProxyService.maxZoom);
        expect(
          fragment['glyphs'],
          '${service.baseUrl}/mml/v21/glyphs/{fontstack}/{range}.pbf',
        );
      },
    );

    test(
      'declares maxzoom 18 (verified real MML server behavior, TD-027 §3F), '
      'not the TileJSON-declared 14',
      () {
        expect(MmlVectorProxyService.maxZoom, 18);
        expect(MmlVectorProxyService.minZoom, 0);
      },
    );

    test('returns null (never throws) when the upstream style fetch fails — '
        'MapScreen treats this exactly like "MML unavailable"', () async {
      final service = MmlVectorProxyService(
        apiKey: 'k',
        httpGetString: (_) async => throw const HttpException('boom'),
      );
      await service.start();
      addTearDown(service.stop);

      expect(await service.fetchMmlStyleFragment(), isNull);
    });

    test('caches the fetched fragment — a second call does not re-fetch', () async {
      var fetchCount = 0;
      final service = MmlVectorProxyService(
        apiKey: 'k',
        httpGetString: (_) async {
          fetchCount++;
          return jsonEncode({
            'sources': {
              'taustakartta': {'type': 'vector', 'url': 'https://x/y'},
            },
            'glyphs': 'https://x/glyphs/{fontstack}/{range}.pbf',
            'layers': <dynamic>[],
          });
        },
      );
      await service.start();
      addTearDown(service.stop);

      await service.fetchMmlStyleFragment();
      await service.fetchMmlStyleFragment();

      expect(fetchCount, 1);
    });

    test('returns null before start() has completed (no baseUrl yet)', () async {
      final service = MmlVectorProxyService(
        apiKey: 'k',
        httpGetString: (_) async => '{}',
      );
      expect(await service.fetchMmlStyleFragment(), isNull);
    });
  });

  group('local HTTP routes', () {
    test(
      'GET /mml/v21/tiles/{z}/{x}/{y}.pbf proxies to MML\'s real, reversed '
      '{z}/{y}/{x} endpoint with the real key attached server-side, and '
      'returns the upstream bytes unmodified',
      () async {
        Uri? capturedUri;
        final service = MmlVectorProxyService(
          apiKey: 'real-key',
          httpGetBytes: (uri) async {
            capturedUri = uri;
            return Uint8List.fromList([1, 2, 3, 4]);
          },
        );
        final port = await service.start();
        addTearDown(service.stop);

        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/mml/v21/tiles/7/64/32.pbf'),
        );
        final response = await request.close();
        final bytes = await response.fold<List<int>>(
          [],
          (acc, chunk) => acc..addAll(chunk),
        );

        expect(response.statusCode, HttpStatus.ok);
        expect(bytes, [1, 2, 3, 4]);
        // MML's own reversed {z}/{y}/{x} order: the real upstream request
        // for z=7 x=64 y=32 must ask MML for .../7/32/64.pbf, not .../7/64/32.pbf.
        expect(capturedUri!.path, endsWith('/7/32/64.pbf'));
        expect(capturedUri!.queryParameters['api-key'], 'real-key');
        client.close();
      },
    );

    test(
      'GET /mml/v21/glyphs/{fontstack}/{range}.pbf proxies with the real '
      'key attached',
      () async {
        Uri? capturedUri;
        final service = MmlVectorProxyService(
          apiKey: 'real-key',
          httpGetBytes: (uri) async {
            capturedUri = uri;
            return Uint8List.fromList([9]);
          },
        );
        final port = await service.start();
        addTearDown(service.stop);

        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse(
            'http://127.0.0.1:$port/mml/v21/glyphs/Open%20Sans/0-255.pbf',
          ),
        );
        final response = await request.close();
        await response.drain<void>();

        expect(response.statusCode, HttpStatus.ok);
        expect(capturedUri!.queryParameters['api-key'], 'real-key');
        expect(Uri.decodeFull(capturedUri!.path), contains('Open Sans'));
        client.close();
      },
    );

    test(
      'a failed upstream tile fetch answers 404, never a crash, and never '
      'writes the failure to the persistent cache',
      () async {
        final service = MmlVectorProxyService(
          apiKey: 'k',
          httpGetBytes: (_) async =>
              throw const HttpException('upstream failed'),
        );
        final port = await service.start();
        addTearDown(service.stop);

        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/mml/v21/tiles/1/0/0.pbf'),
        );
        final response = await request.close();
        await response.drain<void>();

        expect(response.statusCode, HttpStatus.notFound);
        client.close();
      },
    );

    test(
      'GET /syke/bathymetry/{z}/{x}/{y}.pbf delegates to the injected '
      'SykeBathymetryTileSource and returns its bytes',
      () async {
        final source = _FakeSykeTileSource({'5/10/12': [42, 43]});
        final service = MmlVectorProxyService(
          apiKey: 'k',
          sykeBathymetryTileSource: source,
        );
        final port = await service.start();
        addTearDown(service.stop);

        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/syke/bathymetry/5/10/12.pbf'),
        );
        final response = await request.close();
        final bytes = await response.fold<List<int>>(
          [],
          (acc, chunk) => acc..addAll(chunk),
        );

        expect(response.statusCode, HttpStatus.ok);
        expect(bytes, [42, 43]);
        client.close();
      },
    );

    test(
      'GET /syke/bathymetry/{z}/{x}/{y}.pbf answers 204 (not 404/500) for a '
      'genuinely absent tile — the correct, expected no-bathymetry case '
      '(MFS-027 FR-29)',
      () async {
        final source = _FakeSykeTileSource({});
        final service = MmlVectorProxyService(
          apiKey: 'k',
          sykeBathymetryTileSource: source,
        );
        final port = await service.start();
        addTearDown(service.stop);

        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/syke/bathymetry/5/10/12.pbf'),
        );
        final response = await request.close();
        await response.drain<void>();

        expect(response.statusCode, HttpStatus.noContent);
        client.close();
      },
    );

    test(
      'GET /syke/bathymetry/... answers 204, not a crash, when no '
      'SykeBathymetryTileSource was supplied at all',
      () async {
        final service = MmlVectorProxyService(apiKey: 'k');
        final port = await service.start();
        addTearDown(service.stop);

        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/syke/bathymetry/5/10/12.pbf'),
        );
        final response = await request.close();
        await response.drain<void>();

        expect(response.statusCode, HttpStatus.noContent);
        client.close();
      },
    );

    test('an unrecognized path answers 404', () async {
      final service = MmlVectorProxyService(apiKey: 'k');
      final port = await service.start();
      addTearDown(service.stop);

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/unknown/path'),
      );
      final response = await request.close();
      await response.drain<void>();

      expect(response.statusCode, HttpStatus.notFound);
      client.close();
    });
  });

  group(
    'SYKE route zoom continuity (TD-027 §20/§22, root-cause regression '
    'coverage for the "contours disappear when zooming in" bug)',
    () {
      Future<int> statusFor(int port, int z, int x, int y) async {
        final client = HttpClient();
        try {
          final request = await client.getUrl(
            Uri.parse('http://127.0.0.1:$port/syke/bathymetry/$z/$x/$y.pbf'),
          );
          final response = await request.close();
          await response.drain<void>();
          return response.statusCode;
        } finally {
          client.close();
        }
      }

      test(
        'z10 through z14 (the production pipeline\'s own contiguous '
        'tiling range) all return 200 with data, with no gap at any '
        'intermediate zoom',
        () async {
          final source = _FakeSykeTileSource({
            for (final z in [10, 11, 12, 13, 14]) '$z/1/1': [z],
          });
          final service = MmlVectorProxyService(
            apiKey: 'k',
            sykeBathymetryTileSource: source,
          );
          final port = await service.start();
          addTearDown(service.stop);

          for (final z in [10, 11, 12, 13, 14]) {
            expect(
              await statusFor(port, z, 1, 1),
              HttpStatus.ok,
              reason: 'z$z must not be a gap',
            );
          }
        },
      );

      test(
        'z9 (below the real floor) answers 204, matching the presentation '
        'layer\'s own minzoom of 10 — nothing is ever shown there anyway',
        () async {
          final source = _FakeSykeTileSource({
            for (final z in [10, 11, 12, 13, 14]) '$z/1/1': [z],
          });
          final service = MmlVectorProxyService(
            apiKey: 'k',
            sykeBathymetryTileSource: source,
          );
          final port = await service.start();
          addTearDown(service.stop);

          expect(await statusFor(port, 9, 1, 1), HttpStatus.noContent);
        },
      );

      test(
        'z15 through z18 (beyond the real z14 ceiling) all answer 204, '
        'never a crash or an error status — the expected, correct '
        'behavior once MapLibre\'s own vector-source overzoom (reusing '
        'the real z14 tile client-side) is what actually keeps contours '
        'visible there, not a further server-side tile',
        () async {
          final source = _FakeSykeTileSource({
            for (final z in [10, 11, 12, 13, 14]) '$z/1/1': [z],
          });
          final service = MmlVectorProxyService(
            apiKey: 'k',
            sykeBathymetryTileSource: source,
          );
          final port = await service.start();
          addTearDown(service.stop);

          for (final z in [15, 16, 17, 18]) {
            expect(
              await statusFor(port, z, 1, 1),
              HttpStatus.noContent,
              reason: 'z$z should never reach this route under correct '
                  'MapLibre operation, but must degrade gracefully if it '
                  'ever does',
            );
          }
        },
      );
    },
  );

  group('lifecycle', () {
    test('start() binds an ephemeral (non-zero) loopback port, and baseUrl '
        'reflects it', () async {
      final service = MmlVectorProxyService(apiKey: 'k');
      final port = await service.start();
      addTearDown(service.stop);

      expect(port, greaterThan(0));
      expect(service.baseUrl, 'http://127.0.0.1:$port');
    });

    test('port/baseUrl are null before start() and after stop()', () async {
      final service = MmlVectorProxyService(apiKey: 'k');
      expect(service.port, isNull);
      expect(service.baseUrl, isNull);

      await service.start();
      expect(service.port, isNotNull);

      await service.stop();
      expect(service.port, isNull);
      expect(service.baseUrl, isNull);
    });

    test('start() throws if called while already started', () async {
      final service = MmlVectorProxyService(apiKey: 'k');
      await service.start();
      addTearDown(service.stop);

      expect(service.start, throwsStateError);
    });

    test('stop() is safe to call even if start() was never called', () async {
      final service = MmlVectorProxyService(apiKey: 'k');
      await service.stop();
    });
  });
}

class _FakeSykeTileSource implements SykeBathymetryTileSource {
  _FakeSykeTileSource(this._tiles);

  final Map<String, List<int>> _tiles;

  @override
  Uint8List? tileFor(int z, int x, int y) {
    final data = _tiles['$z/$x/$y'];
    return data == null ? null : Uint8List.fromList(data);
  }

  @override
  Future<void> ensureExtracted() async {}

  @override
  void close() {}

  @override
  String? get extractedPath => '/fake/path.mbtiles';

  @override
  int? get extractedByteSize => 1024;

  @override
  String? get bundledVersion => 'fake-version';

  @override
  bool? get lastExtractionWasReplace => false;

  @override
  String get assetFileName => SykeBathymetryTileSource.defaultAssetFileName;
}
