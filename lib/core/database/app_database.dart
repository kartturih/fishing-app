import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:fishing_app/features/catches/data/local/catches_table.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spots_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [FishingSpots, Catches])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'fishing_app'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(catches);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
