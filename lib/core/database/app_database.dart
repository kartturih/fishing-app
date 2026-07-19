import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:fishing_app/features/catch_photos/data/local/catch_photos_table.dart';
import 'package:fishing_app/features/catches/data/local/catches_table.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spots_table.dart';
import 'package:fishing_app/features/lure_catalog/data/local/lure_models_table.dart';
import 'package:fishing_app/features/lure_catalog/data/local/lure_variants_table.dart';
import 'package:fishing_app/features/personal_tackle_box/data/local/tackle_box_entries_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    FishingSpots,
    Catches,
    CatchPhotos,
    LureModels,
    LureVariants,
    TackleBoxEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'fishing_app'));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(catches);
      }
      if (from < 3) {
        await migrator.createTable(catchPhotos);
        await migrator.createIndex(catchPhotosCatchIdSort);
      }
      if (from < 4) {
        await migrator.createTable(lureModels);
        await migrator.createTable(lureVariants);
        await migrator.createIndex(lureModelsManufacturer);
        await migrator.createIndex(lureModelsLureType);
        await migrator.createIndex(lureVariantsLureModelId);
      }
      if (from < 5) {
        await migrator.createTable(tackleBoxEntries);
      }
      if (from < 6) {
        await migrator.addColumn(catches, catches.lureVariantId);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
