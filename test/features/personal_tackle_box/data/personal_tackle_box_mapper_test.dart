import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_mapper.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/tackle_box_entry.dart';

void main() {
  const mapper = PersonalTackleBoxMapper();

  group('entryFromRow', () {
    test('maps a row with no personal photo', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database
          .into(database.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: 'model-1',
              manufacturer: 'Rapala',
              modelName: 'X-Rap Shad XRS08',
              lureType: 'crankbait',
              searchText: 'rapala x-rap shad xrs08',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      await database
          .into(database.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'variant-1',
              lureModelId: 'model-1',
              colorName: const Value('Hot Craw'),
              searchText: 'hot craw',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      await database
          .into(database.tackleBoxEntries)
          .insert(
            TackleBoxEntriesCompanion.insert(
              id: 'entry-1',
              lureVariantId: 'variant-1',
              addedAt: 2000,
              createdAt: 2000,
              updatedAt: 3000,
            ),
          );

      final row = await (database.select(
        database.tackleBoxEntries,
      )..where((t) => t.id.equals('entry-1'))).getSingle();

      final entry = mapper.entryFromRow(row);

      expect(entry.id, 'entry-1');
      expect(entry.lureVariantId, 'variant-1');
      expect(entry.personalPhotoRelativePath, isNull);
      expect(entry.addedAt, DateTime.fromMillisecondsSinceEpoch(2000));
      expect(entry.createdAt, DateTime.fromMillisecondsSinceEpoch(2000));
      expect(entry.updatedAt, DateTime.fromMillisecondsSinceEpoch(3000));
    });

    test('maps a row with a personal photo', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database
          .into(database.lureModels)
          .insert(
            LureModelsCompanion.insert(
              id: 'model-1',
              manufacturer: 'Rapala',
              modelName: 'X-Rap Shad XRS08',
              lureType: 'crankbait',
              searchText: 'rapala x-rap shad xrs08',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      await database
          .into(database.lureVariants)
          .insert(
            LureVariantsCompanion.insert(
              id: 'variant-1',
              lureModelId: 'model-1',
              colorName: const Value('Hot Craw'),
              searchText: 'hot craw',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      await database
          .into(database.tackleBoxEntries)
          .insert(
            TackleBoxEntriesCompanion.insert(
              id: 'entry-1',
              lureVariantId: 'variant-1',
              personalPhotoRelativePath: const Value(
                'tackle_box_photos/entry-1.jpg',
              ),
              addedAt: 2000,
              createdAt: 2000,
              updatedAt: 2000,
            ),
          );

      final row = await (database.select(
        database.tackleBoxEntries,
      )..where((t) => t.id.equals('entry-1'))).getSingle();

      final entry = mapper.entryFromRow(row);

      expect(entry.personalPhotoRelativePath, 'tackle_box_photos/entry-1.jpg');
    });
  });

  group('toInsertCompanion', () {
    test('round-trips all fields, including a null photo', () {
      final entry = TackleBoxEntry(
        id: 'entry-1',
        lureVariantId: 'variant-1',
        addedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(3000),
      );

      final companion = mapper.toInsertCompanion(entry);

      expect(companion.id.value, 'entry-1');
      expect(companion.lureVariantId.value, 'variant-1');
      expect(companion.personalPhotoRelativePath.value, isNull);
      expect(companion.addedAt.value, 2000);
      expect(companion.createdAt.value, 2000);
      expect(companion.updatedAt.value, 3000);
    });

    test('round-trips a non-null photo path', () {
      final entry = TackleBoxEntry(
        id: 'entry-1',
        lureVariantId: 'variant-1',
        personalPhotoRelativePath: 'tackle_box_photos/entry-1.jpg',
        addedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      );

      final companion = mapper.toInsertCompanion(entry);

      expect(
        companion.personalPhotoRelativePath.value,
        'tackle_box_photos/entry-1.jpg',
      );
    });
  });
}
