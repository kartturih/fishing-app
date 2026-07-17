import 'dart:async';

import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// A controllable [ImagePickerPlatform] for widget tests.
///
/// Production code always talks to the real [ImagePicker], which delegates to
/// `ImagePickerPlatform.instance`. Tests swap that static instance for this
/// fake before pumping a widget, so no picker abstraction is needed in
/// production code and no real camera/gallery is ever launched.
class FakeImagePickerPlatform extends ImagePickerPlatform {
  XFile? nextCameraImage;
  Object? cameraError;
  int cameraCallCount = 0;

  List<XFile> nextGalleryImages = [];
  Object? galleryError;
  int galleryCallCount = 0;
  int? lastGalleryLimit;

  /// When set, every pick call awaits this before returning, so tests can
  /// verify that a second invocation is suppressed while one is in flight.
  Completer<void>? gate;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    cameraCallCount++;
    if (gate case final gate?) {
      await gate.future;
    }
    final error = cameraError;
    if (error != null) {
      throw error;
    }
    return nextCameraImage;
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    galleryCallCount++;
    lastGalleryLimit = options.limit;
    if (gate case final gate?) {
      await gate.future;
    }
    final error = galleryError;
    if (error != null) {
      throw error;
    }
    return nextGalleryImages;
  }
}
