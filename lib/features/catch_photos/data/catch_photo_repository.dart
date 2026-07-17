import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_mapper.dart';
import 'package:fishing_app/features/catch_photos/data/storage/catch_photo_storage.dart';
import 'package:fishing_app/features/catch_photos/domain/catch_photo.dart';
import 'package:fishing_app/features/catch_photos/domain/catch_photo_limits.dart';
import 'package:fishing_app/features/catch_photos/domain/pending_catch_photo.dart';

/// Outcome of persisting a batch of pending photos.
///
/// [added] holds the successfully persisted photos (in input order); every
/// photo that could not be added — whether it exceeded the remaining capacity
/// or failed during processing/insertion — is counted in [failedCount].
final class AddCatchPhotosResult {
  const AddCatchPhotosResult({required this.added, required this.failedCount});

  final List<CatchPhoto> added;
  final int failedCount;

  bool get hasFailures => failedCount > 0;
}

/// Concrete repository coordinating Catch photo persistence between Drift and
/// [CatchPhotoStorage].
///
/// The repository is the source of truth for the [maxCatchPhotos] limit, ID
/// generation, sort-order assignment, and cleanup after failures. It owns no
/// UI, picker, or Bottom Sheet state. See TD-013.
class CatchPhotoRepository {
  CatchPhotoRepository(
    this._database,
    this._storage, {
    CatchPhotoMapper mapper = const CatchPhotoMapper(),
    Uuid uuid = const Uuid(),
    DateTime Function()? now,
  }) : _mapper = mapper,
       _uuid = uuid,
       _now = now ?? DateTime.now;

  final AppDatabase _database;
  final CatchPhotoStorage _storage;
  final CatchPhotoMapper _mapper;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// Returns the photos for [catchId] in stable display order.
  ///
  /// Records are returned even when their files are missing on disk.
  Future<List<CatchPhoto>> getByCatchId(String catchId) async {
    _requireNonEmpty(catchId, 'catchId');

    final query = _database.select(_database.catchPhotos)
      ..where((t) => t.catchId.equals(catchId))
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.createdAt),
        (t) => OrderingTerm.asc(t.id),
      ]);

    final rows = await query.get();
    return [for (final row in rows) _mapper.toDomain(row)];
  }

  /// Number of persisted photos for [catchId].
  Future<int> countByCatchId(String catchId) async {
    _requireNonEmpty(catchId, 'catchId');

    final countExpression = _database.catchPhotos.id.count();
    final query = _database.selectOnly(_database.catchPhotos)
      ..addColumns([countExpression])
      ..where(_database.catchPhotos.catchId.equals(catchId));

    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  /// Persists a single [pendingPhoto] for [catchId].
  ///
  /// Throws [ArgumentError] for empty input and [StateError] when the Catch is
  /// already at [maxCatchPhotos]. If the database insert fails after the file
  /// has been written, the stored file is removed before rethrowing.
  Future<CatchPhoto> add({
    required String catchId,
    required PendingCatchPhoto pendingPhoto,
  }) async {
    _requireNonEmpty(catchId, 'catchId');
    _requireNonEmpty(pendingPhoto.sourcePath, 'sourcePath');

    final existing = await getByCatchId(catchId);
    if (existing.length >= maxCatchPhotos) {
      throw StateError(
        'Catch "$catchId" already has the maximum of $maxCatchPhotos photos.',
      );
    }

    return _storeAndInsert(
      catchId: catchId,
      sourcePath: pendingPhoto.sourcePath,
      sortOrder: _nextSortOrder(existing),
    );
  }

  /// Persists multiple pending photos, enforcing the remaining capacity.
  ///
  /// Photos are processed independently: a failure in one does not roll back
  /// the others. Photos beyond the remaining capacity and photos that fail to
  /// process/insert are both counted in [AddCatchPhotosResult.failedCount].
  Future<AddCatchPhotosResult> addMany({
    required String catchId,
    required List<PendingCatchPhoto> pendingPhotos,
  }) async {
    _requireNonEmpty(catchId, 'catchId');

    if (pendingPhotos.isEmpty) {
      return const AddCatchPhotosResult(added: [], failedCount: 0);
    }

    final existing = await getByCatchId(catchId);
    final remaining = maxCatchPhotos - existing.length;
    if (remaining <= 0) {
      return AddCatchPhotosResult(
        added: const [],
        failedCount: pendingPhotos.length,
      );
    }

    final toProcess = pendingPhotos.length <= remaining
        ? pendingPhotos
        : pendingPhotos.sublist(0, remaining);
    var failedCount = pendingPhotos.length - toProcess.length;

    final added = <CatchPhoto>[];
    var nextSortOrder = _nextSortOrder(existing);

    for (final pending in toProcess) {
      if (pending.sourcePath.isEmpty) {
        failedCount++;
        continue;
      }
      try {
        final photo = await _storeAndInsert(
          catchId: catchId,
          sourcePath: pending.sourcePath,
          sortOrder: nextSortOrder,
        );
        added.add(photo);
        nextSortOrder++;
      } catch (error, stackTrace) {
        failedCount++;
        developer.log(
          'catchId=$catchId stage=addMany',
          name: 'CatchPhotoRepository',
          level: 900,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return AddCatchPhotosResult(added: added, failedCount: failedCount);
  }

  /// Deletes a single photo by [photoId].
  ///
  /// Deleting an unknown photo completes successfully. The physical file is
  /// removed before the database row; if a genuine file-deletion failure occurs
  /// (other than the file already being gone), the row is preserved and the
  /// failure is rethrown so the caller can retry.
  Future<void> delete(String photoId) async {
    _requireNonEmpty(photoId, 'photoId');

    final row = await (_database.select(
      _database.catchPhotos,
    )..where((t) => t.id.equals(photoId))).getSingleOrNull();
    if (row == null) {
      return;
    }

    final photo = _mapper.toDomain(row);
    await _storage.delete(photo.relativePath);
    await (_database.delete(
      _database.catchPhotos,
    )..where((t) => t.id.equals(photoId))).go();
  }

  /// Removes every photo file for [catchId] (and its now-empty photo
  /// directory), leaving CatchPhoto database rows untouched.
  ///
  /// Missing files are ignored. A genuine file-system failure aborts before
  /// the remaining files are touched, so surviving files stay consistent with
  /// their rows.
  ///
  /// Intended to run before the Catch itself is deleted: deleting the Catch
  /// afterwards lets the database's cascading foreign key remove the
  /// CatchPhoto rows. If that Catch deletion then fails, the rows are still
  /// present (this method never touched them) and correctly display as
  /// missing-file placeholders rather than disappearing. See MapScreen /
  /// EditCatchBottomSheet.
  Future<void> deleteFilesForCatch(String catchId) async {
    _requireNonEmpty(catchId, 'catchId');

    final photos = await getByCatchId(catchId);
    for (final photo in photos) {
      await _storage.delete(photo.relativePath);
    }
    await _storage.deleteCatchDirectory(catchId);
  }

  /// Removes every photo file for [catchId] and then its database rows.
  ///
  /// Unlike [deleteFilesForCatch], this also deletes the CatchPhoto rows
  /// directly, independent of the Catch row. Use this only when photos must
  /// be cleared without deleting the Catch itself; when deleting the Catch,
  /// prefer [deleteFilesForCatch] followed by `CatchRepository.delete` so the
  /// database cascade removes the rows.
  Future<void> deleteAllForCatch(String catchId) async {
    await deleteFilesForCatch(catchId);
    await (_database.delete(
      _database.catchPhotos,
    )..where((t) => t.catchId.equals(catchId))).go();
  }

  /// Resolves a photo's stored relative path to an absolute [File].
  Future<File> resolveFile(CatchPhoto photo) =>
      _storage.resolve(photo.relativePath);

  Future<CatchPhoto> _storeAndInsert({
    required String catchId,
    required String sourcePath,
    required int sortOrder,
  }) async {
    final photoId = _uuid.v4();
    final relativePath = await _storage.store(
      catchId: catchId,
      photoId: photoId,
      sourcePath: sourcePath,
    );

    final photo = CatchPhoto(
      id: photoId,
      catchId: catchId,
      relativePath: relativePath,
      sortOrder: sortOrder,
      createdAt: _now(),
    );

    try {
      await _database
          .into(_database.catchPhotos)
          .insert(_mapper.toCompanion(photo));
    } catch (_) {
      try {
        await _storage.delete(relativePath);
      } catch (_) {
        // Best-effort cleanup; surface the original insert failure.
      }
      rethrow;
    }

    return photo;
  }

  int _nextSortOrder(List<CatchPhoto> existing) {
    if (existing.isEmpty) {
      return 0;
    }
    return existing.map((photo) => photo.sortOrder).reduce(math.max) + 1;
  }

  void _requireNonEmpty(String value, String name) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, name, 'must not be empty');
    }
  }
}
