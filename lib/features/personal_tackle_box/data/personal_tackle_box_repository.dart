import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_mapper.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_mapper.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/pending_tackle_box_photo.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/tackle_box_entry.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/tackle_box_item.dart';

/// Outcome of [PersonalTackleBoxRepository.add].
///
/// The entry itself is always created (unless [PersonalTackleBoxRepository.add]
/// throws for an already-owned variant); [photoFailed] reports whether an
/// optional photo could not be attached, mirroring `AddCatchPhotosResult`
/// (catch_photos)'s partial-failure reporting shape.
final class AddTackleBoxEntryResult {
  const AddTackleBoxEntryResult({
    required this.item,
    required this.photoFailed,
  });

  final TackleBoxItem item;
  final bool photoFailed;
}

/// Concrete repository for the user-owned Personal Tackle Box.
///
/// Performs its own join across `TackleBoxEntries`, `LureVariants`, and
/// `LureModels` (reusing `lure_catalog`'s already-public
/// `LureCatalogMapper.entryFromRows` for the catalog portion) rather than
/// depending on `LureCatalogRepository`'s instance methods, so every screen
/// resolves in one query. Never filters on `LureVariants.retiredAt` — a
/// retired catalog variant remains fully resolvable, exactly like
/// `LureCatalogRepository.getEntryById()`. See MFS-016 / TD-016.
class PersonalTackleBoxRepository {
  PersonalTackleBoxRepository(
    this._database,
    this._storage, {
    this._mapper = const PersonalTackleBoxMapper(),
    this._catalogMapper = const LureCatalogMapper(),
    this._uuid = const Uuid(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _database;
  final TackleBoxPhotoStorage _storage;
  final PersonalTackleBoxMapper _mapper;
  final LureCatalogMapper _catalogMapper;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// Whether [lureVariantId] already backs a tackle box entry.
  Future<bool> isOwned(String lureVariantId) async {
    _requireNonEmpty(lureVariantId, 'lureVariantId');

    final query = _database.select(_database.tackleBoxEntries)
      ..where((t) => t.lureVariantId.equals(lureVariantId))
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row != null;
  }

  /// Adds [catalogEntry]'s variant to the tackle box, optionally with
  /// [pendingPhoto].
  ///
  /// Throws [StateError] if the variant is already owned — checked first,
  /// with the database's `uniqueKeys` constraint as the authoritative,
  /// race-safe backstop. A photo failure does not prevent the entry from
  /// being created — it is reported via [AddTackleBoxEntryResult.photoFailed]
  /// instead, per MFS-016's Error Handling.
  Future<AddTackleBoxEntryResult> add({
    required LureCatalogEntry catalogEntry,
    PendingTackleBoxPhoto? pendingPhoto,
  }) async {
    final lureVariantId = catalogEntry.id;
    if (await isOwned(lureVariantId)) {
      throw StateError(
        'LureVariant "$lureVariantId" is already in the tackle box.',
      );
    }

    final id = _uuid.v4();
    final now = _now();

    String? relativePath;
    var photoFailed = false;
    if (pendingPhoto != null) {
      try {
        relativePath = await _storage.store(
          tackleBoxEntryId: id,
          sourcePath: pendingPhoto.sourcePath,
        );
      } catch (error, stackTrace) {
        photoFailed = true;
        developer.log(
          'lureVariantId=$lureVariantId stage=add',
          name: 'PersonalTackleBoxRepository',
          level: 900,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final entry = TackleBoxEntry(
      id: id,
      lureVariantId: lureVariantId,
      personalPhotoRelativePath: relativePath,
      addedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _database
          .into(_database.tackleBoxEntries)
          .insert(_mapper.toInsertCompanion(entry));
    } catch (_) {
      if (relativePath != null) {
        try {
          await _storage.delete(relativePath);
        } catch (_) {
          // Best-effort cleanup; surface the original insert failure.
        }
      }
      rethrow;
    }

    return AddTackleBoxEntryResult(
      item: TackleBoxItem(entry: entry, catalogEntry: catalogEntry),
      photoFailed: photoFailed,
    );
  }

  /// Returns every owned entry, sorted manufacturer -> model
  /// (case-insensitive) -> variant id — the same sort
  /// `LureCatalogRepository.browse()` uses, so grouping boundaries fall out
  /// of a single linear pass over the result.
  Future<List<TackleBoxItem>> getAll() async {
    final query =
        _database.select(_database.tackleBoxEntries).join([
          innerJoin(
            _database.lureVariants,
            _database.lureVariants.id.equalsExp(
              _database.tackleBoxEntries.lureVariantId,
            ),
          ),
          innerJoin(
            _database.lureModels,
            _database.lureModels.id.equalsExp(
              _database.lureVariants.lureModelId,
            ),
          ),
        ])..orderBy([
          OrderingTerm(
            expression: _database.lureModels.manufacturer.collate(
              Collate.noCase,
            ),
          ),
          OrderingTerm(
            expression: _database.lureModels.modelName.collate(Collate.noCase),
          ),
          OrderingTerm(expression: _database.lureVariants.id),
        ]);

    final rows = await query.get();
    return [for (final row in rows) _itemFromTypedResult(row)];
  }

  /// Looks up a single owned entry by its `TackleBoxEntry.id`.
  Future<TackleBoxItem?> getById(String tackleBoxEntryId) async {
    _requireNonEmpty(tackleBoxEntryId, 'tackleBoxEntryId');

    final query = _database.select(_database.tackleBoxEntries).join([
      innerJoin(
        _database.lureVariants,
        _database.lureVariants.id.equalsExp(
          _database.tackleBoxEntries.lureVariantId,
        ),
      ),
      innerJoin(
        _database.lureModels,
        _database.lureModels.id.equalsExp(_database.lureVariants.lureModelId),
      ),
    ])..where(_database.tackleBoxEntries.id.equals(tackleBoxEntryId));

    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _itemFromTypedResult(row);
  }

  /// Attaches [pendingPhoto] to an already-created entry that has no photo
  /// yet.
  ///
  /// Exists **only** to satisfy the narrow post-add retry described in
  /// MFS-016/TD-016 — never a general "replace photo" capability. Throws
  /// [StateError] if [tackleBoxEntryId] is unknown or already has a photo.
  Future<TackleBoxItem> attachPhoto({
    required String tackleBoxEntryId,
    required PendingTackleBoxPhoto pendingPhoto,
  }) async {
    _requireNonEmpty(tackleBoxEntryId, 'tackleBoxEntryId');

    final item = await getById(tackleBoxEntryId);
    if (item == null) {
      throw StateError('Tackle box entry "$tackleBoxEntryId" was not found.');
    }
    if (item.personalPhotoRelativePath != null) {
      throw StateError(
        'Tackle box entry "$tackleBoxEntryId" already has a photo.',
      );
    }

    final relativePath = await _storage.store(
      tackleBoxEntryId: tackleBoxEntryId,
      sourcePath: pendingPhoto.sourcePath,
    );

    final updatedAt = _now();
    try {
      await (_database.update(
        _database.tackleBoxEntries,
      )..where((t) => t.id.equals(tackleBoxEntryId))).write(
        TackleBoxEntriesCompanion(
          personalPhotoRelativePath: Value(relativePath),
          updatedAt: Value(updatedAt.millisecondsSinceEpoch),
        ),
      );
    } catch (_) {
      try {
        await _storage.delete(relativePath);
      } catch (_) {
        // Best-effort cleanup; surface the original update failure.
      }
      rethrow;
    }

    final updatedEntry = TackleBoxEntry(
      id: item.entry.id,
      lureVariantId: item.entry.lureVariantId,
      personalPhotoRelativePath: relativePath,
      addedAt: item.entry.addedAt,
      createdAt: item.entry.createdAt,
      updatedAt: updatedAt,
    );
    return TackleBoxItem(entry: updatedEntry, catalogEntry: item.catalogEntry);
  }

  /// Removes the entry [tackleBoxEntryId], deleting its photo file first (if
  /// any). A missing file is tolerated; a genuine file-deletion failure
  /// preserves the row and rethrows so the caller can retry. Removing an
  /// unknown id completes successfully.
  Future<void> remove(String tackleBoxEntryId) async {
    _requireNonEmpty(tackleBoxEntryId, 'tackleBoxEntryId');

    final row = await (_database.select(
      _database.tackleBoxEntries,
    )..where((t) => t.id.equals(tackleBoxEntryId))).getSingleOrNull();
    if (row == null) {
      return;
    }

    final relativePath = row.personalPhotoRelativePath;
    if (relativePath != null) {
      await _storage.delete(relativePath);
    }

    await (_database.delete(
      _database.tackleBoxEntries,
    )..where((t) => t.id.equals(tackleBoxEntryId))).go();
  }

  TackleBoxItem _itemFromTypedResult(TypedResult row) {
    final entry = _mapper.entryFromRow(
      row.readTable(_database.tackleBoxEntries),
    );
    final catalogEntry = _catalogMapper.entryFromRows(
      variantRow: row.readTable(_database.lureVariants),
      modelRow: row.readTable(_database.lureModels),
    );
    return TackleBoxItem(entry: entry, catalogEntry: catalogEntry);
  }

  void _requireNonEmpty(String value, String name) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, name, 'must not be empty');
    }
  }
}
