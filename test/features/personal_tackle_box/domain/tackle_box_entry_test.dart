import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/personal_tackle_box/domain/tackle_box_entry.dart';

void main() {
  TackleBoxEntry buildEntry({
    String id = 'entry-1',
    String lureVariantId = 'variant-1',
    String? personalPhotoRelativePath,
  }) {
    return TackleBoxEntry(
      id: id,
      lureVariantId: lureVariantId,
      personalPhotoRelativePath: personalPhotoRelativePath,
      addedAt: DateTime.utc(2026, 7, 1),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
  }

  group('TackleBoxEntry', () {
    test('creates a valid instance with no photo', () {
      final entry = buildEntry();

      expect(entry.id, 'entry-1');
      expect(entry.lureVariantId, 'variant-1');
      expect(entry.personalPhotoRelativePath, isNull);
      expect(entry.addedAt, DateTime.utc(2026, 7, 1));
    });

    test('creates a valid instance with a photo', () {
      final entry = buildEntry(
        personalPhotoRelativePath: 'tackle_box_photos/entry-1.jpg',
      );

      expect(entry.personalPhotoRelativePath, 'tackle_box_photos/entry-1.jpg');
    });

    test('rejects an empty id', () {
      expect(() => buildEntry(id: ''), throwsA(isA<AssertionError>()));
    });

    test('rejects an empty lureVariantId', () {
      expect(
        () => buildEntry(lureVariantId: ''),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
