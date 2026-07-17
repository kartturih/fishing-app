import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catch_photos/domain/pending_catch_photo.dart';

void main() {
  group('PendingCatchPhoto', () {
    test('carries the given source path', () {
      const pending = PendingCatchPhoto(sourcePath: '/tmp/picked-image.jpg');

      expect(pending.sourcePath, '/tmp/picked-image.jpg');
    });

    test('allows an empty source path to be constructed', () {
      const pending = PendingCatchPhoto(sourcePath: '');

      expect(pending.sourcePath, '');
    });
  });
}
