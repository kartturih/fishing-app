import 'dart:io';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_radius.dart';
import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/domain/catch_photo.dart';
import 'package:fishing_app/features/catch_photos/domain/pending_catch_photo.dart';
import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_thumbnail.dart';

/// Renders the combined existing + pending Catch photos for the Add/Edit
/// Catch Bottom Sheets, plus an "add photo" tile.
///
/// This widget owns no repository or storage logic: [existingFiles] must
/// already contain a resolved [File] for every entry in [existingPhotos].
/// [onOpenViewer] receives an index into the *combined* existing-then-pending
/// order so the caller can build the matching `List<File>` for the viewer.
class CatchPhotoPreviewList extends StatelessWidget {
  const CatchPhotoPreviewList({
    super.key,
    required this.existingPhotos,
    required this.existingFiles,
    required this.pendingPhotos,
    required this.maxPhotos,
    required this.onAddPressed,
    required this.onRemovePending,
    required this.onDeleteExisting,
    required this.onOpenViewer,
    this.isAddEnabled = true,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.deletingPhotoIds = const {},
  });

  final List<CatchPhoto> existingPhotos;
  final Map<String, File> existingFiles;
  final List<PendingCatchPhoto> pendingPhotos;
  final int maxPhotos;
  final VoidCallback onAddPressed;
  final void Function(PendingCatchPhoto pendingPhoto) onRemovePending;
  final void Function(CatchPhoto photo) onDeleteExisting;
  final void Function(int index) onOpenViewer;
  final bool isAddEnabled;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Set<String> deletingPhotoIds;

  int get _totalCount => existingPhotos.length + pendingPhotos.length;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.md),
            Text('Ladataan kuvia…'),
          ],
        ),
      );
    }

    final errorMessage = this.errorMessage;
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                errorMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('Yritä uudelleen'),
              ),
          ],
        ),
      );
    }

    final canAddMore = _totalCount < maxPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < existingPhotos.length; i++)
              _buildExistingThumbnail(context, i),
            for (var i = 0; i < pendingPhotos.length; i++)
              _buildPendingThumbnail(context, i),
            if (canAddMore) _buildAddTile(context),
          ],
        ),
        if (!canAddMore)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Kuvien enimmäismäärä (5) on saavutettu.',
              style: TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildExistingThumbnail(BuildContext context, int index) {
    final photo = existingPhotos[index];
    final file = existingFiles[photo.id];
    if (file == null) {
      return const SizedBox.shrink();
    }

    return CatchPhotoThumbnail(
      key: ValueKey('existingPhoto-${photo.id}'),
      removeButtonKey: ValueKey('deleteExistingPhoto-${photo.id}'),
      file: file,
      semanticLabel: 'Saaliin kuva ${index + 1}',
      isRemoving: deletingPhotoIds.contains(photo.id),
      onTap: () => onOpenViewer(index),
      onRemove: () => onDeleteExisting(photo),
    );
  }

  Widget _buildPendingThumbnail(BuildContext context, int index) {
    final pendingPhoto = pendingPhotos[index];
    final combinedIndex = existingPhotos.length + index;

    return CatchPhotoThumbnail(
      key: ValueKey('pendingPhoto-${pendingPhoto.sourcePath}-$index'),
      file: File(pendingPhoto.sourcePath),
      semanticLabel: 'Uusi kuva ${index + 1}',
      onTap: () => onOpenViewer(combinedIndex),
      onRemove: () => onRemovePending(pendingPhoto),
    );
  }

  Widget _buildAddTile(BuildContext context) {
    return SizedBox(
      width: CatchPhotoThumbnail.size,
      height: CatchPhotoThumbnail.size,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: InkWell(
          key: const Key('catchPhotoAddButton'),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          onTap: isAddEnabled ? onAddPressed : null,
          child: Icon(
            Icons.add_a_photo_outlined,
            color: isAddEnabled
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).disabledColor,
          ),
        ),
      ),
    );
  }
}
