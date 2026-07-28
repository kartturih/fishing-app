import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'package:fishing_app/core/map/syke_bathymetry_tile_source.dart';

/// The local, on-device loopback proxy for MML's official v21 vector base
/// map (TD-027 §3F) and, on the same loopback listener, the bundled SYKE
/// bathymetry overlay (TD-027 §20) — "one loopback HTTP listener, multiple
/// route prefixes," not two separate servers and not a generalized
/// "pluggable local tile server" abstraction (MFS-027 FR-33).
///
/// Rewritten from the temporary `MmlVectorPocStyleFetcher` PoC, which fetched
/// MML's real v21 style directly and wrote it — API key embedded in its own
/// `sources.taustakartta.url`/`glyphs` fields — straight to a plaintext file
/// on disk. That is exactly the problem this class exists to fix (MFS-027
/// FR-27): [fetchMmlStyleFragment] returns a style fragment whose source/
/// glyphs URLs point at *this service's own* loopback address instead, and
/// the real MML API key is used only inside this class's own upstream
/// requests — never written to any file, logged, or included in any error
/// message (TD-027 §16).
///
/// Reuses the local-HTTP-service *shape* already proven by the (now-retired)
/// raster `MmlTileMaskService` — ephemeral port binding, in-memory + disk
/// caching, request coalescing — but proxies real tile/glyph bytes through
/// unmodified rather than decoding/masking/re-encoding them: MML's v21
/// vector tiles do not have the raster no-data-fill defect that machinery
/// existed to fix (TD-027 §3F "Why vector, restated precisely"; verified
/// directly against real MML v21 responses, not assumed).
class MmlVectorProxyService {
  MmlVectorProxyService({
    required String apiKey,
    this.sykeBathymetryTileSource,
    Duration upstreamTimeout = const Duration(seconds: 10),
    this.memoryCacheCapacity = 256,
    Future<Uint8List> Function(Uri uri)? httpGetBytes,
    Future<String> Function(Uri uri)? httpGetString,
    Future<Directory> Function() cacheDirectoryProvider = getTemporaryDirectory,
  }) : _apiKey = apiKey,
       _httpGetBytes = httpGetBytes ?? _defaultHttpGetBytes(upstreamTimeout),
       _httpGetString = httpGetString ?? _defaultHttpGetString(upstreamTimeout),
       _cacheDirectoryProvider = cacheDirectoryProvider,
       _tileCache = _LruCache(memoryCacheCapacity),
       _glyphCache = _LruCache(64);

  /// The optional bundled-SYKE-bathymetry tile source (TD-027 §20/§22),
  /// served on this same loopback listener under `/syke/bathymetry/...`.
  /// `null` means the SYKE overlay route is not available (e.g. the asset
  /// failed to extract) — requests to it degrade to 204, never a crash,
  /// exactly like any other genuinely-no-data tile (MFS-027 FR-29).
  final SykeBathymetryTileSource? sykeBathymetryTileSource;

  final String _apiKey;
  final int memoryCacheCapacity;
  final Future<Uint8List> Function(Uri uri) _httpGetBytes;
  final Future<String> Function(Uri uri) _httpGetString;

  final Future<Directory> Function() _cacheDirectoryProvider;

  /// MML's own official v21 vector-tile style document. Verified directly
  /// against MML's live service (not guessed) — TD-027 §3F.
  static const _styleUrlBase =
      'https://avoin-karttakuva.maanmittauslaitos.fi/vectortiles/stylejson/v21/backgroundmap.json';

  /// MML's own reversed `{TileMatrix}/{TileRow}/{TileCol}` (`{z}/{y}/{x}`)
  /// `ResourceURL` convention for v21 vector tiles — translated here so
  /// MapLibre never needs to know about it, exactly as the retired raster
  /// `MmlTileMaskService` already did for WMTS raster tiles.
  static const _tilesUrlBase =
      'https://avoin-karttakuva.maanmittauslaitos.fi/vectortiles/taustakartta/wmts/1.0.0/taustakartta/default/v21/WGS84_Pseudo-Mercator';

  static const _glyphsUrlBase =
      'https://avoin-karttakuva.maanmittauslaitos.fi/vectortiles/glyphs';

  /// Verified directly against MML's real v21 WMTS vector endpoint
  /// (TD-027 §3F "Zoom range"): the server genuinely serves distinct,
  /// correctly-scoped content through z18 — not merely the TileJSON's own
  /// (conservative/inaccurate) declared `maxzoom: 14` — with HTTP 404 at
  /// z19+. This matches raster's own confirmed `0`–`18` range (§0, TD-026).
  static const int minZoom = 0;
  static const int maxZoom = 18;

  /// MML's own real style contains exactly one unconditional (no-source)
  /// layer, confirmed by inspecting the complete, real 113-layer response
  /// (TD-027 §3F Pre-Implementation Verification) — every other layer,
  /// filtered or not, is scoped to a real `source-layer` and therefore only
  /// paints where that layer genuinely has features. Removing this one
  /// layer is the full extent of this class's content edit to MML's own
  /// style; every other layer is passed through unmodified.
  static const _unconditionalLayerId = 'background';

  static final RegExp _mmlTileRoute = RegExp(
    r'^/mml/v21/tiles/(\d+)/(\d+)/(\d+)\.pbf$',
  );
  static final RegExp _glyphRoute = RegExp(
    r'^/mml/v21/glyphs/([^/]+)/([^/]+)\.pbf$',
  );
  static final RegExp _sykeTileRoute = RegExp(
    r'^/syke/bathymetry/(\d+)/(\d+)/(\d+)\.pbf$',
  );

  HttpServer? _server;
  Directory? _diskCacheDir;
  final _LruCache _tileCache;
  final _LruCache _glyphCache;
  final Map<String, Future<Uint8List>> _inFlight = {};
  String? _cachedStyleFragment;

  int? get port => _server?.port;

  /// `http://127.0.0.1:<port>` — `null` before [start] completes.
  String? get baseUrl {
    final boundPort = port;
    return boundPort == null ? null : 'http://127.0.0.1:$boundPort';
  }

  /// Starts the loopback HTTP listener on an always-ephemeral port (never a
  /// fixed one — the same reasoning already established for the retired
  /// raster service applies unchanged: a fixed port risks a bind failure
  /// against a not-yet-terminated previous instance, and the actual
  /// expensive work is cached independently of which port happens to be
  /// bound this session). Throws if already started; call [stop] first to
  /// restart.
  Future<int> start() async {
    if (_server != null) {
      throw StateError('MmlVectorProxyService is already started');
    }

    try {
      final root = await _cacheDirectoryProvider();
      _diskCacheDir = Directory('${root.path}/mml_vector_proxy_cache');
      await _diskCacheDir!.create(recursive: true);
    } catch (_) {
      // Disk cache is a pure performance optimization — proceed without it.
      _diskCacheDir = null;
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    unawaited(_serve(server));
    return server.port;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _diskCacheDir = null;
    _inFlight.clear();
    if (server != null) {
      await server.close(force: true);
    }
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handle(request));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;

    final tileMatch = _mmlTileRoute.firstMatch(path);
    if (tileMatch != null) {
      final z = int.parse(tileMatch.group(1)!);
      final x = int.parse(tileMatch.group(2)!);
      final y = int.parse(tileMatch.group(3)!);
      await _respondProxied(
        request,
        cache: _tileCache,
        cacheKey: 'tile/$z/$x/$y',
        fetch: () => _fetchMmlTile(z, x, y),
      );
      return;
    }

    final glyphMatch = _glyphRoute.firstMatch(path);
    if (glyphMatch != null) {
      final fontstack = glyphMatch.group(1)!;
      final range = glyphMatch.group(2)!;
      await _respondProxied(
        request,
        cache: _glyphCache,
        cacheKey: 'glyph/$fontstack/$range',
        fetch: () => _fetchMmlGlyph(fontstack, range),
      );
      return;
    }

    final sykeMatch = _sykeTileRoute.firstMatch(path);
    if (sykeMatch != null) {
      await _handleSykeTile(
        request,
        z: int.parse(sykeMatch.group(1)!),
        x: int.parse(sykeMatch.group(2)!),
        y: int.parse(sykeMatch.group(3)!),
      );
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  Future<void> _handleSykeTile(
    HttpRequest request, {
    required int z,
    required int x,
    required int y,
  }) async {
    final source = sykeBathymetryTileSource;
    Uint8List? bytes;
    if (source != null) {
      try {
        bytes = source.tileFor(z, x, y);
      } catch (error) {
        _logFailure('SYKE tile $z/$x/$y', error);
        bytes = null;
      }
    }

    if (bytes == null) {
      // Genuinely no data at this coordinate (or the source failed to
      // initialize) — the correct, expected, non-error "no bathymetry
      // here" response (MFS-027 FR-29), never a 404/500.
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType('application', 'x-protobuf')
      ..add(bytes);
    await request.response.close();
  }

  /// Shared request-coalescing/caching wrapper for both MML proxy routes
  /// (tiles and glyphs): a duplicate concurrent request for the same key
  /// awaits the same in-flight `Future` rather than issuing a second
  /// upstream request (TD-027 §3C's original design, reused unchanged in
  /// shape for the vector-proxy role).
  Future<void> _respondProxied(
    HttpRequest request, {
    required _LruCache cache,
    required String cacheKey,
    required Future<Uint8List> Function() fetch,
  }) async {
    try {
      final bytes = await _cachedOrFetch(cache, cacheKey, fetch);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('application', 'x-protobuf')
        ..add(bytes);
    } catch (error) {
      _logFailure(cacheKey, error);
      // Never exposed to the angler as a distinct failure — MapLibre
      // simply does not render that specific tile/glyph range, and the
      // request is retried the next time it is needed (e.g. after a
      // re-pan), exactly mirroring the retired raster service's own
      // "self-healing, not a permanent record" failure treatment.
      request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  }

  Future<Uint8List> _cachedOrFetch(
    _LruCache cache,
    String key,
    Future<Uint8List> Function() fetch,
  ) async {
    final memoryCached = cache.get(key);
    if (memoryCached != null) {
      return memoryCached;
    }

    final inFlight = _inFlight[key];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _computeAndCache(cache, key, fetch);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<Uint8List> _computeAndCache(
    _LruCache cache,
    String key,
    Future<Uint8List> Function() fetch,
  ) async {
    final diskCached = await _readDiskCache(key);
    if (diskCached != null) {
      cache.put(key, diskCached);
      return diskCached;
    }

    final bytes = await fetch();
    cache.put(key, bytes);
    unawaited(_writeDiskCache(key, bytes));
    return bytes;
  }

  Future<Uint8List?> _readDiskCache(String key) async {
    final dir = _diskCacheDir;
    if (dir == null) {
      return null;
    }
    final file = File('${dir.path}/${_safeFileName(key)}');
    if (!await file.exists()) {
      return null;
    }
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDiskCache(String key, Uint8List bytes) async {
    final dir = _diskCacheDir;
    if (dir == null) {
      return;
    }
    try {
      final file = File('${dir.path}/${_safeFileName(key)}');
      await file.writeAsBytes(bytes);
    } catch (error) {
      _logFailure('disk cache write for $key', error);
    }
  }

  String _safeFileName(String key) => key.replaceAll('/', '_');

  Future<Uint8List> _fetchMmlTile(int z, int x, int y) {
    // MML's own reversed {z}/{y}/{x} order, translated here — the only
    // place this service's callers/MapLibre need never know about it.
    final uri = Uri.parse('$_tilesUrlBase/$z/$y/$x.pbf').replace(
      queryParameters: {'api-key': _apiKey},
    );
    return _httpGetBytes(uri);
  }

  Future<Uint8List> _fetchMmlGlyph(String fontstack, String range) {
    final uri = Uri.parse('$_glyphsUrlBase/$fontstack/$range.pbf').replace(
      queryParameters: {'api-key': _apiKey},
    );
    return _httpGetBytes(uri);
  }

  /// Fetches (once — cached in memory for the rest of this session, since
  /// MML's own style document changes rarely, unlike per-tile content),
  /// rewrites, and returns MML's real v21 style as a `sources`/`layers`
  /// fragment ready to merge into the composed Maastokartta style document
  /// (`WorldwideStyleFactory`).
  ///
  /// Rewriting, precisely (TD-027 §3F):
  /// - `sources.taustakartta` becomes a plain `tiles`-array vector source
  ///   pointing at this service's own `baseUrl` tile endpoint, with the
  ///   verified real [minZoom]/[maxZoom] — no `api-key` anywhere.
  /// - The top-level `glyphs` URL is rewritten to this service's own glyph
  ///   endpoint — no `api-key`.
  /// - The single unconditional [_unconditionalLayerId] layer is removed;
  ///   every other layer (~99 of MML's own ~100) is passed through
  ///   completely unmodified, preserving MML's own cartographic design.
  ///
  /// Returns `null` if [start] has not completed yet, or if the real style
  /// could not be fetched (network failure, invalid key) — the caller
  /// (`MapScreen`) treats this exactly like "MML is unavailable," omitting
  /// MML's fragment from the composed style with no crash and no technical
  /// detail ever surfaced (mirrors MFS-026 FR-16/FR-17).
  Future<String?> fetchMmlStyleFragment() async {
    final cached = _cachedStyleFragment;
    if (cached != null) {
      return cached;
    }

    final localBase = baseUrl;
    if (localBase == null) {
      return null;
    }

    final Map<String, dynamic> style;
    try {
      final uri = Uri.parse(_styleUrlBase).replace(
        queryParameters: {'TileMatrixSet': 'WGS84_Pseudo-Mercator', 'api-key': _apiKey},
      );
      final raw = await _httpGetString(uri);
      style = jsonDecode(raw) as Map<String, dynamic>;
    } catch (error) {
      _logFailure('MML v21 style fetch', error);
      return null;
    }

    final rewrittenSources = <String, dynamic>{
      for (final entry in (style['sources'] as Map<String, dynamic>).entries)
        entry.key: {
          'type': 'vector',
          'tiles': ['$localBase/mml/v21/tiles/{z}/{x}/{y}.pbf'],
          'minzoom': minZoom,
          'maxzoom': maxZoom,
        },
    };

    final rewrittenLayers = [
      for (final layer in (style['layers'] as List<dynamic>)
          .cast<Map<String, dynamic>>())
        if (layer['id'] != _unconditionalLayerId) layer,
    ];

    final fragment = jsonEncode({
      'sources': rewrittenSources,
      'layers': rewrittenLayers,
      'glyphs': '$localBase/mml/v21/glyphs/{fontstack}/{range}.pbf',
    });
    _cachedStyleFragment = fragment;
    return fragment;
  }

  static Future<Uint8List> Function(Uri uri) _defaultHttpGetBytes(
    Duration timeout,
  ) {
    return (uri) async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(uri).timeout(timeout);
        final response = await request.close().timeout(timeout);
        if (response.statusCode != HttpStatus.ok) {
          // Never includes `uri` itself (would leak the api-key).
          throw HttpException(
            'MML vector proxy upstream returned HTTP ${response.statusCode}',
          );
        }
        final builder = BytesBuilder();
        await for (final chunk in response.timeout(timeout)) {
          builder.add(chunk);
        }
        return builder.toBytes();
      } finally {
        client.close();
      }
    };
  }

  static Future<String> Function(Uri uri) _defaultHttpGetString(
    Duration timeout,
  ) {
    return (uri) async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(uri).timeout(timeout);
        final response = await request.close().timeout(timeout);
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'MML vector proxy upstream returned HTTP ${response.statusCode}',
          );
        }
        return await response.transform(utf8.decoder).join().timeout(timeout);
      } finally {
        client.close();
      }
    };
  }

  /// Logs a diagnosable message only — never the request URL (would include
  /// the MML API key) or the raw error object, only its type (TD-027 §16).
  void _logFailure(String what, Object error) {
    // ignore: avoid_print
    print('MmlVectorProxyService: $what failed (${error.runtimeType})');
  }
}

/// A small, bounded in-memory LRU cache of recently-served bytes — the
/// fastest path for tiles/glyphs the angler is actively panning near, ahead
/// of the disk cache. Identical in shape to the retired raster service's own
/// cache (TD-027 §3F: this pattern is explicitly reused, not reinvented).
class _LruCache {
  _LruCache(this._capacity);

  final int _capacity;
  final LinkedHashMap<String, Uint8List> _entries = LinkedHashMap();

  Uint8List? get(String key) {
    final value = _entries.remove(key);
    if (value == null) {
      return null;
    }
    _entries[key] = value;
    return value;
  }

  void put(String key, Uint8List value) {
    _entries.remove(key);
    _entries[key] = value;
    if (_entries.length > _capacity) {
      _entries.remove(_entries.keys.first);
    }
  }
}
