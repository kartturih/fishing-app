import 'dart:io';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_radius.dart';
import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_thumbnail.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/catch_formatters.dart';
import 'package:fishing_app/features/catches/presentation/widgets/add_catch_bottom_sheet.dart';

/// A prominent card for a fishing spot's Record Catch — the top-ranked
/// entry of the same deterministically ordered Catch List
/// `FishingSpotStatisticsPage` also renders (MFS-022's Conceptual Model;
/// TD-022 Key Design Decision 3).
///
/// A dedicated widget, not a generalized `RecordCatchCard` (TD-021): that
/// card shows the catch's fishing spot (location), since a species-scoped
/// view spans every fishing spot and location genuinely varies from catch
/// to catch there. Here every catch already shares the one fishing spot
/// this page is about, so location would be redundant — species is the
/// field that now varies and isn't otherwise implied, so it takes
/// location's place, shown first. This is not a single substitutable
/// field swap (the two cards differ in which field appears *and* in its
/// prominence), so a shared, parameterized widget would need more
/// conditional branching than two small, purpose-built ones cost in
/// total — see TD-022 Key Design Decision 8. No `FishingSpot` is needed
/// here at all (unlike `RecordCatchCard`'s `SpeciesCatchEntry`), since the
/// page already knows its own fishing spot — see TD-022 Key Design
/// Decision 3.
///
/// Resolves its own first-photo file independently, mirroring
/// `CatchListItem`'s and `RecordCatchCard`'s own private thumbnail-loading
/// pattern rather than sharing it (a third instance of the same accepted
/// trade-off — TD-021 Key Design Decision 9). Its photo tile reuses
/// `CatchPhotoThumbnail` unmodified.
class FishingSpotRecordCatchCard extends StatefulWidget {
  const FishingSpotRecordCatchCard({
    super.key,
    required this.catchModel,
    required this.catchPhotoRepository,
    required this.onTap,
  });

  final Catch catchModel;
  final CatchPhotoRepository catchPhotoRepository;
  final VoidCallback onTap;

  @override
  State<FishingSpotRecordCatchCard> createState() =>
      _FishingSpotRecordCatchCardState();
}

class _FishingSpotRecordCatchCardState
    extends State<FishingSpotRecordCatchCard> {
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
    final catchModel = widget.catchModel;
    final measurementLine = formatCatchMeasurementLine(catchModel);

    return Card(
      child: InkWell(
        key: const Key('fishingSpotRecordCatchCard'),
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
                      Text(
                        catchModel.species.finnishName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (measurementLine != null) Text(measurementLine),
                      Text(
                        formatCatchDate(catchModel.caughtAt),
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

  /// Combines species, weight/length, and date into one screen-reader
  /// label — per MFS-022's Accessibility Expectations. No location is
  /// included, since every catch on this page already shares the same
  /// fishing spot. Weight and length are folded in only through
  /// [measurementLine], which is already `null` when both are absent
  /// (`formatCatchMeasurementLine`).
  String _semanticLabel(String? measurementLine) {
    final catchModel = widget.catchModel;
    final parts = [
      catchModel.species.finnishName,
      ?measurementLine,
      formatCatchDate(catchModel.caughtAt),
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
