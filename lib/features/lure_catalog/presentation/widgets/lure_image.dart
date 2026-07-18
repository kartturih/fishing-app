import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_radius.dart';

/// Displays a Lure Catalog product image, or a placeholder when none is
/// available.
///
/// [imageReference] is interpreted as a Flutter asset path (all catalog
/// images in this milestone are local placeholder assets, never embedded
/// binary data or a remote URL). See MFS-015 / TD-015.
class LureImage extends StatelessWidget {
  const LureImage({
    super.key,
    required this.imageReference,
    required this.semanticLabel,
    this.size,
  });

  final String? imageReference;
  final String semanticLabel;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final reference = imageReference;
    if (reference == null) {
      return _LurePlaceholder(semanticLabel: semanticLabel, size: size);
    }

    final cachePixels = size == null
        ? null
        : (size! * MediaQuery.devicePixelRatioOf(context)).round();

    return Semantics(
      label: semanticLabel,
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Image.asset(
          reference,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cachePixels,
          cacheHeight: cachePixels,
          errorBuilder: (context, error, stackTrace) =>
              _LurePlaceholder(semanticLabel: semanticLabel, size: size),
        ),
      ),
    );
  }
}

class _LurePlaceholder extends StatelessWidget {
  const _LurePlaceholder({required this.semanticLabel, this.size});

  final String semanticLabel;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.phishing,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
