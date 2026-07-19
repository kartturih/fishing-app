import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';

void main() {
  Catch buildCatch({String? lureVariantId}) {
    return Catch(
      id: 'catch-1',
      fishingSpotId: 'spot-1',
      species: FishSpecies.pike,
      caughtAt: DateTime.utc(2026, 1, 1),
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      lureVariantId: lureVariantId,
    );
  }

  test('constructs successfully with a lureVariantId', () {
    final catchModel = buildCatch(lureVariantId: 'variant-1');
    expect(catchModel.lureVariantId, 'variant-1');
  });

  test('constructs successfully with no lureVariantId', () {
    final catchModel = buildCatch();
    expect(catchModel.lureVariantId, isNull);
  });

  test('rejects an empty lureVariantId', () {
    expect(() => buildCatch(lureVariantId: ''), throwsA(isA<AssertionError>()));
  });
}
