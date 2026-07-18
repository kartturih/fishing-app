import 'package:drift/drift.dart';

/// Drift table for shared, read-only Lure Catalog product lines.
///
/// `id` is an opaque, authored UUID — never derived from `manufacturer`,
/// `modelName`, or any other display text. `searchText` is a precomputed,
/// Dart-lowercased concatenation written by the mapper, used only for
/// case-insensitive search matching (including Finnish ä/ö); it is never
/// read back into the domain layer. `seedVersion` is null once a row is no
/// longer owned by the local seed process (e.g. a future server-managed
/// row) — see `LureCatalogRepository.ensureSeeded`. See MFS-015 / TD-015.
@DataClassName('LureModelEntity')
@TableIndex(name: 'lure_models_manufacturer', columns: {#manufacturer})
@TableIndex(name: 'lure_models_lure_type', columns: {#lureType})
class LureModels extends Table {
  TextColumn get id => text()();
  TextColumn get manufacturer => text()();
  TextColumn get productFamily => text().nullable()();
  TextColumn get modelName => text()();
  TextColumn get lureType => text()();
  TextColumn get defaultImageReference => text().nullable()();
  TextColumn get searchText => text()();
  IntColumn get seedVersion => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
