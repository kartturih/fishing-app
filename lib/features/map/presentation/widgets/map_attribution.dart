import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/core/map/base_map.dart';

/// The small, always-visible attribution text required while an MML base
/// map is active (MFS-026 FR-18). Renders `BaseMap.attributionText`
/// directly — no MapLibre-native attribution control is relied upon — so it
/// stays correct across a base-map switch by simply re-rendering from
/// current state, like any other widget. Positioned bottom-left,
/// deliberately away from the existing bottom-right `MapControls` and the
/// new upper-right `BaseMapLayersControl`.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, required this.baseMap});

  final BaseMap baseMap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.75),
            ),
            child: Text(
              baseMap.attributionText,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
      ),
    );
  }
}
