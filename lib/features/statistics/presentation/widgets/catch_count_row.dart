import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';

/// Renders a plain "label, catch count" row with a trailing chevron —
/// reused across every list in the Statistics feature that needs exactly
/// this shape: the whole-history Species List and the Fishing Spot List
/// (both interactive, MFS-020/MFS-021/MFS-022) and a fishing spot's own
/// Species Breakdown (deliberately static, MFS-022 FR-7).
///
/// Renamed in place from `SpeciesCatchStatisticRow` once a third real call
/// site needed the same shape — the same "rename in place once a widget's
/// real scope outgrows its original name" move already established twice
/// in this project (`LureCatalogListItem` → `LureCatalogModelListItem`,
/// TD-018; `LureStatisticsSummaryCard` → `StatisticsSummaryCard`, TD-020).
/// See TD-022 Key Design Decision 1.
///
/// When [onTap] is non-null, the row is wrapped in an `InkWell`, exposes
/// real button semantics, and shows a trailing chevron — unchanged from
/// `SpeciesCatchStatisticRow`'s existing (MFS-021) behavior. When [onTap]
/// is `null`, the row renders without the `InkWell` wrapper, without
/// button semantics, and without the chevron — a chevron conventionally
/// signals "tap to navigate," which would be misleading on a row that
/// does nothing when tapped (approved UX refinement to TD-022, made
/// during Technical Lead review). This widget owns no feature-specific
/// logic: which case applies, and what [label]/[catchCount] mean, is
/// entirely up to the caller.
class CatchCountRow extends StatelessWidget {
  const CatchCountRow({
    super.key,
    required this.label,
    required this.catchCount,
    this.onTap,
  });

  final String label;
  final int catchCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    final semanticLabel = '$label, $catchCount saalista';
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('$catchCount', style: Theme.of(context).textTheme.titleMedium),
          // A chevron conventionally signals "tap to navigate" — shown only
          // when the row is actually tappable, so a static row (e.g. the
          // Fishing Spot Statistics Species Breakdown) does not imply
          // navigation that doesn't exist.
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return Semantics(
        label: semanticLabel,
        excludeSemantics: true,
        child: content,
      );
    }

    return InkWell(
      onTap: onTap,
      child: Semantics(
        label: semanticLabel,
        button: true,
        excludeSemantics: true,
        child: content,
      ),
    );
  }
}
