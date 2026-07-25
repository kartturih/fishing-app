import 'package:shared_preferences/shared_preferences.dart';

import 'package:fishing_app/core/map/base_map.dart';

/// Persists the angler's selected [BaseMap] across application restarts
/// (MFS-026 FR-8). Stores the enum's own `.name` string — the same
/// established convention already used for `Catches.species`
/// (`FishSpecies.name`) — rather than an integer index (fragile if enum
/// order ever changes) or a custom string constant.
class BaseMapPreferenceStore {
  const BaseMapPreferenceStore();

  static const _key = 'selected_base_map';

  /// Returns the persisted [BaseMap], or [BaseMap.fallback] (Maastokartta)
  /// if nothing is stored, or the stored value is unreadable/unrecognized.
  Future<BaseMap> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      return BaseMap.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => BaseMap.fallback,
      );
    } catch (_) {
      return BaseMap.fallback;
    }
  }

  Future<void> save(BaseMap baseMap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, baseMap.name);
  }
}
