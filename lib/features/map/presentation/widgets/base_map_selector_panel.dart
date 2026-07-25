import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_colors.dart';
import 'package:fishing_app/app/theme/app_radius.dart';
import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/core/map/base_map.dart';

/// The compact anchored selector opened by [BaseMapLayersControl] (MFS-026).
/// Positioned in the same `Stack` as the control — no overlay/portal needed.
/// Deliberately built as a vertical column of option tiles, so a later
/// milestone can append overlay toggles as further rows without
/// restructuring this widget (MFS-026: "keep expandable for future overlay
/// controls without implementing overlays now") — no overlay-specific code
/// exists yet, only room for it.
///
/// Each option is image-only (MFS-026 polish pass) — no visible text label
/// — since [BaseMap.previewAssetPath] now points at a real, recognizable
/// crop of that base map's own MML cartography (see its doc comment), the
/// image itself identifies the choice. The base map's name is retained as
/// this tile's accessible [Semantics] label so the choice stays identifiable
/// to assistive technology and in tests, even with no on-screen text.
class BaseMapSelectorPanel extends StatelessWidget {
  const BaseMapSelectorPanel({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final BaseMap selected;
  final ValueChanged<BaseMap> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final baseMap in BaseMap.values) ...[
              if (baseMap != BaseMap.values.first)
                const SizedBox(height: AppSpacing.xs),
              _BaseMapOptionTile(
                baseMap: baseMap,
                isActive: baseMap == selected,
                onTap: () => onSelected(baseMap),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BaseMapOptionTile extends StatelessWidget {
  const _BaseMapOptionTile({
    required this.baseMap,
    required this.isActive,
    required this.onTap,
  });

  final BaseMap baseMap;
  final bool isActive;
  final VoidCallback onTap;

  // Fixed (not content-derived) so both options are always exactly the same
  // size (MFS-026 polish pass requirement), and large enough to be useful
  // as an actual map preview rather than an icon, while keeping the overall
  // stacked panel compact.
  static const double _size = 88;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${baseMap.label}, ${isActive ? 'valittu' : 'ei valittu'}',
      // Since ExcludeSemantics (below) hides the InkWell's own tap action
      // from assistive technology, it is re-exposed explicitly here so a
      // "double-tap to activate" gesture still works.
      onTap: onTap,
      // The Image below would otherwise merge its own semantics into this
      // node — ExcludeSemantics keeps this tile's accessible label exactly
      // the explicit one above, even though nothing is visibly rendered as
      // text.
      child: ExcludeSemantics(
        child: InkWell(
          key: Key('baseMapOption-${baseMap.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: Container(
            width: _size,
            height: _size,
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.small),
              // Subtle active-state treatment (MFS-026 polish pass,
              // unchanged from the previous round): a mild tinted
              // background plus a thin theme-colored border — no checkmark
              // or other redundant indicator. The inactive tile has no
              // border at all, keeping it lightweight.
              color: isActive ? AppColors.primary.withValues(alpha: 0.1) : null,
              border: isActive
                  ? Border.all(color: AppColors.primary, width: 1)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: Image.asset(baseMap.previewAssetPath, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }
}
