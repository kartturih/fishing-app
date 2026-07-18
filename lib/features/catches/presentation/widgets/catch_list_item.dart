import 'dart:io';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_radius.dart';
import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_thumbnail.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/catch_formatters.dart';

/// A single row in a fishing spot's Catch list: a photo thumbnail (the first
/// photo by `sortOrder`, or a placeholder when there is none) plus the
/// catch's species, measurements, and date/time. Tapping the row (including
/// the thumbnail) opens Catch Details, never a photo viewer or editor
/// directly. See MFS-014 / TD-014.
class CatchListItem extends StatefulWidget {
  const CatchListItem({
    super.key,
    required this.catchModel,
    required this.catchPhotoRepository,
    required this.onTap,
  });

  final Catch catchModel;
  final CatchPhotoRepository catchPhotoRepository;
  final VoidCallback onTap;

  @override
  State<CatchListItem> createState() => _CatchListItemState();
}

class _CatchListItemState extends State<CatchListItem> {
  late final Future<File?> _thumbnailFileFuture = _loadThumbnail();

  Future<File?> _loadThumbnail() async {
    try {
      final photos = await widget.catchPhotoRepository.getByCatchId(
        widget.catchModel.id,
      );
      if (photos.isEmpty) {
        return null;
      }
      return await widget.catchPhotoRepository.resolveFile(photos.first);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final measurementLine = formatCatchMeasurementLine(widget.catchModel);

    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(context),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.catchModel.species.finnishName,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (measurementLine != null) Text(measurementLine),
                  Text(
                    formatCatchDateTime(widget.catchModel.caughtAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return FutureBuilder<File?>(
      future: _thumbnailFileFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done || file == null) {
          return _buildPlaceholder(context);
        }
        return CatchPhotoThumbnail(
          file: file,
          semanticLabel: '${widget.catchModel.species.finnishName} kuva',
          onTap: widget.onTap,
        );
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return SizedBox(
      width: CatchPhotoThumbnail.size,
      height: CatchPhotoThumbnail.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.set_meal,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
