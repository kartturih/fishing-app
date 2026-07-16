import 'package:drift/drift.dart';

@DataClassName('FishingSpotEntity')
class FishingSpots extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
