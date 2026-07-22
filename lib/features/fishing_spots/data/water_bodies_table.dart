import 'package:drift/drift.dart';

@DataClassName('WaterBodyEntity')
class WaterBodies extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
