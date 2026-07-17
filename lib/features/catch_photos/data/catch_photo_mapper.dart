import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catch_photos/domain/catch_photo.dart';

/// Converts between the Drift [CatchPhotoEntity] row and the [CatchPhoto]
/// domain model. `createdAt` is persisted as epoch milliseconds, matching the
/// existing Catch mapper convention.
class CatchPhotoMapper {
  const CatchPhotoMapper();

  CatchPhoto toDomain(CatchPhotoEntity row) {
    return CatchPhoto(
      id: row.id,
      catchId: row.catchId,
      relativePath: row.relativePath,
      sortOrder: row.sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    );
  }

  CatchPhotosCompanion toCompanion(CatchPhoto photo) {
    return CatchPhotosCompanion.insert(
      id: photo.id,
      catchId: photo.catchId,
      relativePath: photo.relativePath,
      sortOrder: photo.sortOrder,
      createdAt: photo.createdAt.millisecondsSinceEpoch,
    );
  }
}
