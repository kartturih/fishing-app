import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';

/// The upper-right floating control that opens the base-map selector
/// (MFS-026). Stateless and callback-driven, mirroring `MapControls`'
/// existing shape — no repository/service access of its own.
class BaseMapLayersControl extends StatelessWidget {
  const BaseMapLayersControl({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          // .small matches `MapControls`' own buttons (MFS-026 polish pass)
          // so both form one visually consistent control system rather
          // than a full-size button next to shrunk ones.
          child: FloatingActionButton.small(
            key: const Key('baseMapLayersButton'),
            heroTag: 'baseMapLayersButton',
            tooltip: 'Karttatasot',
            onPressed: onPressed,
            child: const Icon(Icons.layers),
          ),
        ),
      ),
    );
  }
}
