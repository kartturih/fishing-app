import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:fishing_app/features/fishing_spots/data/fishing_spots_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [FishingSpots])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'fishing_app'));

  @override
  int get schemaVersion => 1;
}
