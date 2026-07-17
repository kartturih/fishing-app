import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/domain/pending_catch_photo.dart';

enum CatchPhotoSource { camera, gallery }

/// Outcome of a photo-picking attempt, translated into the project's own
/// vocabulary so callers never need to branch on `image_picker` or
/// `PlatformException` details.
sealed class CatchPhotoPickOutcome {
  const CatchPhotoPickOutcome();
}

final class CatchPhotosSelected extends CatchPhotoPickOutcome {
  const CatchPhotosSelected(this.photos, {this.exceededCapacity = false});

  final List<PendingCatchPhoto> photos;

  /// True when the user selected more gallery photos than the remaining
  /// capacity, and the selection was truncated.
  final bool exceededCapacity;
}

final class CatchPhotoPickCancelled extends CatchPhotoPickOutcome {
  const CatchPhotoPickCancelled();
}

final class CatchPhotoPickPermissionDenied extends CatchPhotoPickOutcome {
  const CatchPhotoPickPermissionDenied();
}

final class CatchPhotoPickFailed extends CatchPhotoPickOutcome {
  const CatchPhotoPickFailed();
}

/// Shows a small Material action dialog for choosing a photo source.
///
/// Deliberately a plain dialog rather than another Bottom Sheet, so it never
/// stacks a second modal sheet over the Add/Edit Catch Bottom Sheet.
Future<CatchPhotoSource?> showCatchPhotoSourceDialog(BuildContext context) {
  return showDialog<CatchPhotoSource>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Lisää kuva'),
      children: [
        SimpleDialogOption(
          key: const Key('catchPhotoSourceCamera'),
          onPressed: () => Navigator.of(context).pop(CatchPhotoSource.camera),
          child: const Row(
            children: [
              Icon(Icons.camera_alt_outlined),
              SizedBox(width: AppSpacing.md),
              Text('Kamera'),
            ],
          ),
        ),
        SimpleDialogOption(
          key: const Key('catchPhotoSourceGallery'),
          onPressed: () => Navigator.of(context).pop(CatchPhotoSource.gallery),
          child: const Row(
            children: [
              Icon(Icons.photo_library_outlined),
              SizedBox(width: AppSpacing.md),
              Text('Galleria'),
            ],
          ),
        ),
        SimpleDialogOption(
          key: const Key('catchPhotoSourceCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Peruuta'),
        ),
      ],
    ),
  );
}

/// Wraps [ImagePicker] camera/gallery calls.
///
/// An [ImagePicker] instance may be injected for tests; production code uses
/// the default. Widget tests swap the underlying platform implementation via
/// `ImagePickerPlatform.instance`, which this class picks up automatically.
class CatchPhotoPicker {
  CatchPhotoPicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  /// Captures a single photo with the camera.
  Future<CatchPhotoPickOutcome> pickFromCamera() async {
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.camera);
      if (file == null) {
        return const CatchPhotoPickCancelled();
      }
      return CatchPhotosSelected([PendingCatchPhoto(sourcePath: file.path)]);
    } on PlatformException {
      return const CatchPhotoPickPermissionDenied();
    } catch (_) {
      return const CatchPhotoPickFailed();
    }
  }

  /// Selects one or more photos from the gallery.
  ///
  /// [remainingCapacity] must be greater than zero. The underlying picker
  /// cannot enforce a limit below 2, so a selection larger than
  /// [remainingCapacity] is truncated after the fact and reported through
  /// [CatchPhotosSelected.exceededCapacity].
  Future<CatchPhotoPickOutcome> pickFromGallery({
    required int remainingCapacity,
  }) async {
    try {
      final files = await _imagePicker.pickMultiImage(
        limit: remainingCapacity >= 2 ? remainingCapacity : null,
      );
      if (files.isEmpty) {
        return const CatchPhotoPickCancelled();
      }

      final exceededCapacity = files.length > remainingCapacity;
      final accepted = exceededCapacity
          ? files.sublist(0, remainingCapacity)
          : files;

      return CatchPhotosSelected([
        for (final file in accepted) PendingCatchPhoto(sourcePath: file.path),
      ], exceededCapacity: exceededCapacity);
    } on PlatformException {
      return const CatchPhotoPickPermissionDenied();
    } catch (_) {
      return const CatchPhotoPickFailed();
    }
  }
}
