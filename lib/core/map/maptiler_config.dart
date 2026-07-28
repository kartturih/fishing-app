/// Reads the MapTiler API key supplied at build time via `--dart-define`.
/// Mirrors `MmlConfig` exactly — a second, entirely independent credential,
/// never combined with or derived from the MML key. Never hardcode a real
/// key here or anywhere else in source, tests, fixtures, or documentation
/// (TD-027 §8/§16).
class MapTilerConfig {
  const MapTilerConfig._();

  static const String _apiKey = String.fromEnvironment('MAPTILER_API_KEY');

  /// True when no key was supplied at build time. Checked before any
  /// MapTiler tile request is attempted — independent of `MmlConfig.isMissing`.
  static bool get isMissing => _apiKey.isEmpty;

  static String get apiKey => _apiKey;
}
