import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fishing_app/features/lure_catalog/data/lure_catalog_version_store.dart';

/// Covers `LureCatalogVersionStore` (TD-028 Section 7), modeled directly on
/// the existing `base_map_preference_store_test.dart` pattern.
void main() {
  const store = LureCatalogVersionStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadLastReconciledVersion() returns null when nothing is stored', () async {
    expect(await store.loadLastReconciledVersion(), isNull);
  });

  test('save() then load() round-trips', () async {
    await store.saveLastReconciledVersion(1);
    expect(await store.loadLastReconciledVersion(), 1);
  });

  test('saving a newer version overwrites an older one', () async {
    await store.saveLastReconciledVersion(1);
    await store.saveLastReconciledVersion(2);
    expect(await store.loadLastReconciledVersion(), 2);
  });

  test(
    'load() returns null when the stored value is not an int',
    () async {
      SharedPreferences.setMockInitialValues({
        'lure_catalog_last_reconciled_version': 'not-an-int',
      });

      expect(await store.loadLastReconciledVersion(), isNull);
    },
  );
}
