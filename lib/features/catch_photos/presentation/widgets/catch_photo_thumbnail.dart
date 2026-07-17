import 'dart:io';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_radius.dart';

/// A single square Catch photo preview tile.
///
/// Takes an already-resolved [file] (the caller resolves persistent photos
/// through `CatchPhotoRepository.resolveFile` and pending photos via their
/// `sourcePath` directly) so this widget stays free of storage/repository
/// concerns. A missing or corrupt file falls back to a placeholder through
/// `Image.file`'s own `errorBuilder`.
class CatchPhotoThumbnail extends StatelessWidget {
  const CatchPhotoThumbnail({
    super.key,
    required this.file,
    required this.onTap,
    required this.semanticLabel,
    this.onRemove,
    this.isRemoving = false,
    this.removeButtonKey,
  });

  static const double size = 88;

  final File file;
  final VoidCallback onTap;
  final String semanticLabel;
  final VoidCallback? onRemove;
  final bool isRemoving;

  /// Identifies the remove/delete affordance regardless of whether it is
  /// currently showing the icon or a busy spinner, so callers (including
  /// tests) can target it without depending on that transient visual state.
  final Key? removeButtonKey;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cachePixels = (size * devicePixelRatio).round();

    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: InkWell(
                  onTap: onTap,
                  child: Image.file(
                    file,
                    fit: BoxFit.cover,
                    cacheWidth: cachePixels,
                    cacheHeight: cachePixels,
                    errorBuilder: (context, error, stackTrace) =>
                        const _ThumbnailPlaceholder(),
                  ),
                ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: 2,
                right: 2,
                child: _RemoveButton(
                  key: removeButtonKey,
                  onPressed: isRemoving ? null : onRemove,
                  isBusy: isRemoving,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({
    super.key,
    required this.onPressed,
    required this.isBusy,
  });

  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 24,
          height: 24,
          child: isBusy
              ? const Padding(
                  padding: EdgeInsets.all(4),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.close, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
