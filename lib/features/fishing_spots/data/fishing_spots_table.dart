import 'package:drift/drift.dart';

import 'package:fishing_app/features/fishing_spots/data/water_bodies_table.dart';

@DataClassName('FishingSpotEntity')
class FishingSpots extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  // Nullable at the schema level only because SQLite's `ALTER TABLE ... ADD
  // COLUMN` cannot add a NOT NULL column to a table with existing rows.
  // Non-null is guaranteed by the domain model (FishingSpot.waterBodyId is
  // a plain, non-nullable String), by FishingSpotRepository requiring it on
  // every write, and by the 7->8 migration back-filling every existing row.
  // See TD-024 Key Design Decision 1.
  TextColumn get waterBodyId => text().nullable().references(
    WaterBodies,
    #id,
    onDelete: KeyAction.restrict,
  )();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
