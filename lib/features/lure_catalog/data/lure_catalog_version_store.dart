import 'package:shared_preferences/shared_preferences.dart';

/// Caches the last successfully reconciled Lure Catalog `catalogVersion`,
/// letting `LureCatalogRepository.ensureSeeded()` skip a full reconciliation
/// pass when nothing has changed. Modeled directly on the existing
/// `BaseMapPreferenceStore` (`lib/core/map/base_map_preference_store.dart`).
///
/// This store is a fast-path cache, never a correctness dependency. If it
/// is empty, stale, or wrong, the worst outcome is `ensureSeeded()` doing a
/// full reconciliation pass it could have skipped — never an incorrect
/// catalog state, since the authoritative per-row `seedVersion` check inside
/// the reconciliation transaction is unchanged and always still runs when a
/// full pass does happen. See TD-028 Section 7.
class LureCatalogVersionStore {
  const LureCatalogVersionStore();

  static const _key = 'lure_catalog_last_reconciled_version';

  /// Returns the last successfully reconciled `catalogVersion`, or `null`
  /// if never reconciled (or unreadable — treated the same as never).
  Future<int?> loadLastReconciledVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_key);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastReconciledVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, version);
  }
}
