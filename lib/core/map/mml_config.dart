/// Reads the MML WMTS API key supplied at build time via `--dart-define`.
/// Never hardcode a real key here or anywhere else in source, tests,
/// fixtures, or documentation (TD-026 §8/§16).
class MmlConfig {
  const MmlConfig._();

  static const String _apiKey = String.fromEnvironment('MML_API_KEY');

  /// True when no key was supplied at build time (an unconfigured
  /// development/test build). Checked before any MML tile request is
  /// attempted — this is a reliably, cheaply, entirely Dart-side-detectable
  /// condition, unlike a network/tile failure.
  static bool get isMissing => _apiKey.isEmpty;

  static String get apiKey => _apiKey;
}
