import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_image.dart';

/// A single row in the Lure Catalog browse list: a thumbnail (or
/// placeholder) plus manufacturer/model and lure type for one lure model.
/// Tapping the row opens `LureModelDetailsPage`, where the user chooses a
/// specific color variant. See MFS-018 / TD-018.
///
/// Renamed and refactored from `LureCatalogListItem` (MFS-015/TD-015), which
/// rendered one row per variant with a per-variant distinguishing-detail
/// line. Now that the browsing list groups by model (MFS-018), that line no
/// longer applies — there is no single color to show for a whole model — so
/// it has been removed rather than carried forward. See TD-018's Key Design
/// Decision 9 for why this was a rename-and-refactor of the existing file
/// rather than a delete-and-recreate.
///
/// [fullyOwned] draws a small badge over the thumbnail when every one of
/// the model's non-retired variants is already in the user's Personal
/// Tackle Box. This widget takes a plain `bool` rather than reaching into
/// `personal_tackle_box` itself — the caller (`LureCatalogListPage`) decides
/// ownership, keeping `lure_catalog` free of any dependency on that
/// feature.
class LureCatalogModelListItem extends StatelessWidget {
  const LureCatalogModelListItem({
    super.key,
    required this.modelEntry,
    required this.onTap,
    this.fullyOwned = false,
  });

  final LureCatalogEntry modelEntry;
  final VoidCallback onTap;
  final bool fullyOwned;

  @override
  Widget build(BuildContext context) {
    final baseLabel = '${modelEntry.manufacturer} ${modelEntry.modelName}';
    final semanticLabel = fullyOwned ? '$baseLabel, omistuksessa' : baseLabel;

    return InkWell(
      onTap: onTap,
      child: Semantics(
        label: semanticLabel,
        button: true,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  LureImage(
                    imageReference: modelEntry.modelDefaultImageReference,
                    semanticLabel: baseLabel,
                    size: 56,
                  ),
                  if (fullyOwned)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: _OwnedBadge(key: const Key('ownedBadge')),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baseLabel,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      lureTypeDisplayLabel(modelEntry.lureType),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small, subtle badge marking a catalog thumbnail as already owned. Purely
/// decorative — the accessible "omistuksessa" wording lives on the row's own
/// [Semantics] label, so this badge excludes itself from the semantics tree.
class _OwnedBadge extends StatelessWidget {
  const _OwnedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary,
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.check,
          size: 14,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
