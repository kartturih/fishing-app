import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fishing_app/core/map/base_map.dart';
import 'package:fishing_app/core/map/base_map_preference_store.dart';

void main() {
  const store = BaseMapPreferenceStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load() returns the fallback when nothing is stored', () async {
    expect(await store.load(), BaseMap.fallback);
  });

  test('save() then load() round-trips for Maastokartta', () async {
    await store.save(BaseMap.maastokartta);
    expect(await store.load(), BaseMap.maastokartta);
  });

  test('save() then load() round-trips for Ilmakuva', () async {
    await store.save(BaseMap.ilmakuva);
    expect(await store.load(), BaseMap.ilmakuva);
  });

  test(
    'load() falls back to Maastokartta when the stored value does not '
    'match any BaseMap',
    () async {
      SharedPreferences.setMockInitialValues({
        'selected_base_map': 'some_unknown_future_value',
      });

      expect(await store.load(), BaseMap.fallback);
    },
  );
}
