import 'package:drift/drift.dart';

import 'package:fishing_app/features/lure_catalog/data/local/lure_variants_table.dart';

/// Drift table for user-owned Personal Tackle Box entries.
///
/// `id` is an opaque, runtime-generated UUID (unlike catalog ids, this is
/// user-created data with no seed source to reconcile against). `lureVariantId`
/// references the shared, read-only `LureVariants.id` by identifier only —
/// this table never duplicates catalog fields.
///
/// `onDelete: KeyAction.restrict` is a deliberate departure from
/// `LureVariants.lureModelId`'s cascade: nothing in this codebase ever
/// deletes a `LureVariant` (retirement is a flag, never a `DELETE`), so a
/// cascading foreign key here would only ever silently destroy a user's
/// ownership record if that ever changed. `restrict` makes that impossible
/// by construction. See MFS-016 / TD-016.
@DataClassName('TackleBoxEntryEntity')
class TackleBoxEntries extends Table {
  TextColumn get id => text()();

  TextColumn get lureVariantId =>
      text().references(LureVariants, #id, onDelete: KeyAction.restrict)();

  TextColumn get personalPhotoRelativePath => text().nullable()();

  IntColumn get addedAt => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// One catalog variant can be owned at most once. A `UNIQUE` constraint
  /// creates its own index in SQLite, so no separate `@TableIndex` is needed
  /// for lookups by `lureVariantId`.
  @override
  List<Set<Column>> get uniqueKeys => [
    {lureVariantId},
  ];
}
