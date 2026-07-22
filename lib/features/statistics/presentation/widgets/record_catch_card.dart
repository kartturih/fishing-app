import 'dart:io';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_radius.dart';
import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_thumbnail.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/catch_formatters.dart';
import 'package:fishing_app/features/catches/presentation/widgets/add_catch_bottom_sheet.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_entry.dart';

/// A prominent card for a species' Record Catch — the top-ranked entry of
/// the same deterministically ordered Catch List `SpeciesStatisticsPage`
/// also renders (MFS-021's Conceptual Model; TD-021 Key Design Decision 5).
///
/// Unlike the reused, unmodified `CatchListItem` (which this milestone's
/// Catch List uses as-is), this card also shows the catch's location — a
/// field `CatchListItem` never renders — so it cannot simply wrap that
/// widget. Since MFS-024/TD-024, the location line shows the catch's water
/// body rather than its exact fishing spot, since this card already spans
/// every fishing spot the species was ever caught at (TD-024 Key Design
/// Decision 9/FR-10). It resolves its own first-photo file independently,
/// mirroring `CatchListItem`'s private thumbnail-loading pattern rather
/// than sharing it — see TD-021 Key Design Decision 9. Its photo tile
/// reuses `CatchPhotoThumbnail` unmodified — see TD-021 Key Design
/// Decision 8.
class RecordCatchCard extends StatefulWidget {
  const RecordCatchCard({
    super.key,
    required this.entry,
    required this.catchPhotoRepository,
    required this.onTap,
  });

  final SpeciesCatchEntry entry;
  final CatchPhotoRepository catchPhotoRepository;
  final VoidCallback onTap;

  @override
  State<RecordCatchCard> createState() => _RecordCatchCardState();
}

class _RecordCatchCardState extends State<RecordCatchCard> {
  late final Future<File?> _thumbnailFileFuture = _loadThumbnail();

  Future<File?> _loadThumbnail() async {
    try {
      final photos = await widget.catchPhotoRepository.getByCatchId(
        widget.entry.catchModel.id,
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
    final catchModel = widget.entry.catchModel;
    final measurementLine = formatCatchMeasurementLine(catchModel);

    return Card(
      child: InkWell(
        key: const Key('recordCatchCard'),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Semantics(
            label: _semanticLabel(measurementLine),
            button: true,
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumbnail(context),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (measurementLine != null)
                        Text(
                          measurementLine,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      Text(formatCatchDate(catchModel.caughtAt)),
                      Text(
                        widget.entry.waterBody.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Combines species, weight/length, date, and location into one
  /// screen-reader label — per MFS-021's Accessibility Expectations. Weight
  /// and length are folded in only through [measurementLine], which is
  /// already `null` when both are absent (`formatCatchMeasurementLine`).
  String _semanticLabel(String? measurementLine) {
    final catchModel = widget.entry.catchModel;
    final parts = [
      catchModel.species.finnishName,
      ?measurementLine,
      formatCatchDate(catchModel.caughtAt),
      widget.entry.waterBody.name,
    ];
    return parts.join(', ');
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
          semanticLabel: '${widget.entry.catchModel.species.finnishName} kuva',
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
