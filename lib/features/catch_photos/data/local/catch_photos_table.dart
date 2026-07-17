import 'package:drift/drift.dart';

import 'package:fishing_app/features/catches/data/local/catches_table.dart';

/// Drift table for persisted Catch photos.
///
/// `createdAt` is stored as epoch milliseconds in an [IntColumn], consistent
/// with the existing `Catches` and `FishingSpots` tables. Only an
/// application-managed relative path is stored; never image bytes or an
/// absolute path. See TD-013.
@DataClassName('CatchPhotoEntity')
@TableIndex(name: 'catch_photos_catch_id_sort', columns: {#catchId, #sortOrder})
class CatchPhotos extends Table {
  TextColumn get id => text()();

  TextColumn get catchId =>
      text().references(Catches, #id, onDelete: KeyAction.cascade)();

  TextColumn get relativePath => text()();

  IntColumn get sortOrder => integer()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
