import 'package:drift/drift.dart';

import 'package:fishing_app/features/fishing_spots/data/fishing_spots_table.dart';

@DataClassName('CatchEntity')
class Catches extends Table {
  TextColumn get id => text()();

  TextColumn get fishingSpotId =>
      text().references(FishingSpots, #id, onDelete: KeyAction.cascade)();

  TextColumn get species => text()();

  IntColumn get caughtAt => integer()();

  IntColumn get weightGrams =>
      integer().nullable()
      // ignore: recursive_getters
      .check(weightGrams.isNull() | weightGrams.isBiggerThanValue(0))();

  IntColumn get lengthMillimeters => integer().nullable().check(
    // ignore: recursive_getters
    lengthMillimeters.isNull() | lengthMillimeters.isBiggerThanValue(0),
  )();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
