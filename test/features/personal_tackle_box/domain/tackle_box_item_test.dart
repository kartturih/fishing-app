import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/tackle_box_entry.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/tackle_box_item.dart';

void main() {
  LureCatalogEntry buildCatalogEntry() {
    return LureCatalogEntry(
      variant: LureVariant(
        id: 'variant-1',
        lureModelId: 'model-1',
        colorName: 'Hot Craw',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      manufacturer: 'Rapala',
      modelName: 'X-Rap Shad XRS08',
      lureType: 'crankbait',
      modelDefaultImageReference: null,
    );
  }

  TackleBoxEntry buildEntry({String? personalPhotoRelativePath}) {
    return TackleBoxEntry(
      id: 'entry-1',
      lureVariantId: 'variant-1',
      personalPhotoRelativePath: personalPhotoRelativePath,
      addedAt: DateTime.utc(2026, 7, 1),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
  }

  test('id delegates to the wrapped entry', () {
    final item = TackleBoxItem(
      entry: buildEntry(),
      catalogEntry: buildCatalogEntry(),
    );

    expect(item.id, 'entry-1');
  });

  test('personalPhotoRelativePath delegates to the wrapped entry', () {
    final item = TackleBoxItem(
      entry: buildEntry(
        personalPhotoRelativePath: 'tackle_box_photos/entry-1.jpg',
      ),
      catalogEntry: buildCatalogEntry(),
    );

    expect(item.personalPhotoRelativePath, 'tackle_box_photos/entry-1.jpg');
  });

  test('personalPhotoRelativePath is null when no photo was added', () {
    final item = TackleBoxItem(
      entry: buildEntry(),
      catalogEntry: buildCatalogEntry(),
    );

    expect(item.personalPhotoRelativePath, isNull);
  });
}
