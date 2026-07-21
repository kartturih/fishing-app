import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/catch_notes_limits.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';

void main() {
  Catch buildCatch({String? lureVariantId, String? notes}) {
    return Catch(
      id: 'catch-1',
      fishingSpotId: 'spot-1',
      species: FishSpecies.pike,
      caughtAt: DateTime.utc(2026, 1, 1),
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      lureVariantId: lureVariantId,
      notes: notes,
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

  test('constructs successfully with no notes', () {
    final catchModel = buildCatch();
    expect(catchModel.notes, isNull);
  });

  test('constructs successfully with a normal notes value', () {
    final catchModel = buildCatch(
      notes: 'Tuulinen ilta, hauki iski laineeseen.',
    );
    expect(catchModel.notes, 'Tuulinen ilta, hauki iski laineeseen.');
  });

  test('constructs successfully with notes at exactly the limit', () {
    final notes = 'a' * maxCatchNotesLength;
    final catchModel = buildCatch(notes: notes);
    expect(catchModel.notes, hasLength(maxCatchNotesLength));
  });

  test('rejects notes longer than the limit', () {
    final notes = 'a' * (maxCatchNotesLength + 1);
    expect(() => buildCatch(notes: notes), throwsA(isA<AssertionError>()));
  });

  test('rejects an empty notes value', () {
    expect(() => buildCatch(notes: ''), throwsA(isA<AssertionError>()));
  });
}
