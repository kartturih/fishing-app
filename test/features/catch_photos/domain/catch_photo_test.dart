import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catch_photos/domain/catch_photo.dart';

void main() {
  CatchPhoto buildPhoto({
    String id = 'photo-1',
    String catchId = 'catch-1',
    String relativePath = 'catch_photos/catch-1/photo-1.jpg',
    int sortOrder = 0,
  }) {
    return CatchPhoto(
      id: id,
      catchId: catchId,
      relativePath: relativePath,
      sortOrder: sortOrder,
      createdAt: DateTime(2026, 7, 17),
    );
  }

  group('CatchPhoto', () {
    test('creates a valid instance', () {
      final photo = buildPhoto();

      expect(photo.id, 'photo-1');
      expect(photo.catchId, 'catch-1');
      expect(photo.relativePath, 'catch_photos/catch-1/photo-1.jpg');
      expect(photo.sortOrder, 0);
      expect(photo.createdAt, DateTime(2026, 7, 17));
    });

    test('rejects an empty id', () {
      expect(() => buildPhoto(id: ''), throwsA(isA<AssertionError>()));
    });

    test('rejects an empty catchId', () {
      expect(() => buildPhoto(catchId: ''), throwsA(isA<AssertionError>()));
    });

    test('rejects an empty relativePath', () {
      expect(
        () => buildPhoto(relativePath: ''),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a negative sortOrder', () {
      expect(() => buildPhoto(sortOrder: -1), throwsA(isA<AssertionError>()));
    });

    test('accepts a zero sortOrder', () {
      expect(() => buildPhoto(sortOrder: 0), returnsNormally);
    });
  });
}
