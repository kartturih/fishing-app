import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/tackle_box_entry.dart';

/// Converts between Drift rows/companions and the [TackleBoxEntry] domain
/// type. The joined catalog portion of `TackleBoxItem` is assembled by the
/// repository directly using `lure_catalog`'s own `LureCatalogMapper`, not
/// by this mapper. See MFS-016 / TD-016.
class PersonalTackleBoxMapper {
  const PersonalTackleBoxMapper();

  TackleBoxEntry entryFromRow(TackleBoxEntryEntity row) => TackleBoxEntry(
    id: row.id,
    lureVariantId: row.lureVariantId,
    personalPhotoRelativePath: row.personalPhotoRelativePath,
    addedAt: DateTime.fromMillisecondsSinceEpoch(row.addedAt),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );

  TackleBoxEntriesCompanion toInsertCompanion(TackleBoxEntry entry) =>
      TackleBoxEntriesCompanion.insert(
        id: entry.id,
        lureVariantId: entry.lureVariantId,
        personalPhotoRelativePath: Value(entry.personalPhotoRelativePath),
        addedAt: entry.addedAt.millisecondsSinceEpoch,
        createdAt: entry.createdAt.millisecondsSinceEpoch,
        updatedAt: entry.updatedAt.millisecondsSinceEpoch,
      );
}
