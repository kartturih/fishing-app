import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';

void main() {
  test('constructs successfully with a non-empty name', () {
    final waterBody = WaterBody(
      id: 'water-body-1',
      name: 'Merrasjärvi',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    expect(waterBody.id, 'water-body-1');
    expect(waterBody.name, 'Merrasjärvi');
  });

  test('rejects an empty name', () {
    expect(
      () => WaterBody(
        id: 'water-body-1',
        name: '',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
