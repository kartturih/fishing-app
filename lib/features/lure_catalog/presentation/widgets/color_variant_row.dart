import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_image.dart';

/// A single color variant's compact row inside `LureModelDetailsPage`:
/// image, color/distinguishing name, length and weight (when present), and
/// a trailing action slot supplied by the caller. See MFS-018 / TD-018.
///
/// Pure presentation: no repository access, no business logic. [action] is
/// built entirely by the caller (via `LureModelDetailsPage.variantActionBuilder`)
/// — this widget never constructs it, so `lure_catalog` never depends on
/// `personal_tackle_box`. Because [action] already renders its own owned/
/// not-owned state (`AddToTackleBoxAction` already does this, per MFS-016),
/// this row does not duplicate an "owned" indicator of its own.
///
/// [onTap] fires only from the row's own content area (image + text), kept
/// outside the [action] slot's tap target so the two never conflict — the
/// row body opens `LureDetailsPage` for this variant's full field set, and
/// [action] performs the "Add to Tackle Box" interaction.
class ColorVariantRow extends StatelessWidget {
  const ColorVariantRow({
    super.key,
    required this.entry,
    required this.onTap,
    this.action,
  });

  final LureCatalogEntry entry;
  final VoidCallback onTap;
  final Widget? action;

  String get _distinguishingDetail {
    final variant = entry.variant;
    return variant.variantName ??
        variant.colorName ??
        variant.manufacturerColorCode ??
        '';
  }

  String? get _measurementsLine {
    final variant = entry.variant;
    final parts = [
      if (variant.lengthMillimeters != null)
        _formatCentimeters(variant.lengthMillimeters!),
      if (variant.weightGrams != null) '${variant.weightGrams} g',
    ];
    return parts.isEmpty ? null : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final distinguishingDetail = _distinguishingDetail;
    final measurementsLine = _measurementsLine;
    final semanticLabel = distinguishingDetail.isEmpty
        ? '${entry.manufacturer} ${entry.modelName}'
        : distinguishingDetail;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Semantics(
                label: semanticLabel,
                button: true,
                excludeSemantics: true,
                child: Row(
                  children: [
                    LureImage(
                      imageReference: entry.effectiveImageReference,
                      semanticLabel: semanticLabel,
                      size: 48,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            distinguishingDetail.isEmpty
                                ? '—'
                                : distinguishingDetail,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (measurementsLine != null)
                            Text(
                              measurementsLine,
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
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Mirrors `LureDetailsPage`'s own private centimeter formatter exactly.
/// Duplicated rather than shared: TD-018 keeps `LureDetailsPage` completely
/// unmodified (Key Design Decision 3), so its private helper cannot be
/// exported without touching that file.
String _formatCentimeters(int millimeters) {
  final centimeters = millimeters / 10;
  final text = centimeters.toStringAsFixed(1);
  final trimmed = text.endsWith('.0')
      ? text.substring(0, text.length - 2)
      : text;
  return '$trimmed cm';
}
