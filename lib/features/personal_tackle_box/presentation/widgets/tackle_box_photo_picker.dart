import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/pending_tackle_box_photo.dart';

enum TackleBoxPhotoSource { camera, gallery }

/// Outcome of a photo-picking attempt, translated into the project's own
/// vocabulary so callers never need to branch on `image_picker` or
/// `PlatformException` details.
sealed class TackleBoxPhotoPickOutcome {
  const TackleBoxPhotoPickOutcome();
}

final class TackleBoxPhotoSelected extends TackleBoxPhotoPickOutcome {
  const TackleBoxPhotoSelected(this.photo);

  final PendingTackleBoxPhoto photo;
}

final class TackleBoxPhotoPickCancelled extends TackleBoxPhotoPickOutcome {
  const TackleBoxPhotoPickCancelled();
}

final class TackleBoxPhotoPickPermissionDenied
    extends TackleBoxPhotoPickOutcome {
  const TackleBoxPhotoPickPermissionDenied();
}

final class TackleBoxPhotoPickFailed extends TackleBoxPhotoPickOutcome {
  const TackleBoxPhotoPickFailed();
}

/// Shows a small Material dialog for choosing how to add a photo, or to skip.
///
/// Mirrors `showCatchPhotoSourceDialog` (catch_photos)'s shape, but is this
/// feature's own small widget: a `TackleBoxEntry` holds at most one photo,
/// never up to five, so `CatchPhotoPicker`'s multi-select/capacity logic
/// does not apply, and importing it would create a `personal_tackle_box ->
/// catch_photos` dependency the architecture does not call for. See
/// MFS-016 / TD-016.
Future<TackleBoxPhotoSource?> showTackleBoxPhotoSourceDialog(
  BuildContext context,
) {
  return showDialog<TackleBoxPhotoSource>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Lisää kuva'),
      children: [
        SimpleDialogOption(
          key: const Key('tackleBoxPhotoSourceCamera'),
          onPressed: () =>
              Navigator.of(context).pop(TackleBoxPhotoSource.camera),
          child: const Row(
            children: [
              Icon(Icons.camera_alt_outlined),
              SizedBox(width: AppSpacing.md),
              Text('Kamera'),
            ],
          ),
        ),
        SimpleDialogOption(
          key: const Key('tackleBoxPhotoSourceGallery'),
          onPressed: () =>
              Navigator.of(context).pop(TackleBoxPhotoSource.gallery),
          child: const Row(
            children: [
              Icon(Icons.photo_library_outlined),
              SizedBox(width: AppSpacing.md),
              Text('Galleria'),
            ],
          ),
        ),
        SimpleDialogOption(
          key: const Key('tackleBoxPhotoSourceSkip'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ei kuvaa'),
        ),
      ],
    ),
  );
}

/// Wraps [ImagePicker] camera/single-gallery-image calls.
///
/// An [ImagePicker] instance may be injected for tests; production code uses
/// the default. Widget tests swap the underlying platform implementation via
/// `ImagePickerPlatform.instance`, which this class picks up automatically —
/// the same approach `catch_photos`' widget tests already use.
class TackleBoxPhotoPicker {
  TackleBoxPhotoPicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  /// Captures a single photo with the camera.
  Future<TackleBoxPhotoPickOutcome> pickFromCamera() =>
      _pick(ImageSource.camera);

  /// Selects a single photo from the gallery.
  Future<TackleBoxPhotoPickOutcome> pickFromGallery() =>
      _pick(ImageSource.gallery);

  Future<TackleBoxPhotoPickOutcome> _pick(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(source: source);
      if (file == null) {
        return const TackleBoxPhotoPickCancelled();
      }
      return TackleBoxPhotoSelected(
        PendingTackleBoxPhoto(sourcePath: file.path),
      );
    } on PlatformException {
      return const TackleBoxPhotoPickPermissionDenied();
    } catch (_) {
      return const TackleBoxPhotoPickFailed();
    }
  }
}
