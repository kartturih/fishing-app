import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';

class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    required this.isSelectionMode,
    required this.onLocationPressed,
    required this.onAddFishingSpotPressed,
    required this.onCancelSelectionPressed,
    required this.onAddHerePressed,
  });

  final bool isSelectionMode;
  final VoidCallback onLocationPressed;
  final VoidCallback onAddFishingSpotPressed;
  final VoidCallback onCancelSelectionPressed;
  final VoidCallback onAddHerePressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: isSelectionMode
                ? _selectionControls()
                : _defaultControls(),
          ),
        ),
      ),
    );
  }

  // FloatingActionButton.small keeps every map control the same compact
  // size (40x40 visual, 48x48 tap target per Flutter's own FAB layout —
  // still a comfortable, standard Material touch target despite the
  // smaller visual footprint) as `BaseMapLayersControl`'s button, so the
  // two form one visually consistent control system rather than a mix of
  // full-size and shrunk-only-for-one-button FABs.
  List<Widget> _defaultControls() {
    return [
      FloatingActionButton.small(
        heroTag: 'mapSettingsButton',
        onPressed: () {},
        child: const Icon(Icons.settings),
      ),
      const SizedBox(height: AppSpacing.xs),
      FloatingActionButton.small(
        heroTag: 'addFishingSpotButton',
        onPressed: onAddFishingSpotPressed,
        child: const Icon(Icons.add_location_alt),
      ),
      const SizedBox(height: AppSpacing.xs),
      FloatingActionButton.small(
        heroTag: 'currentLocationButton',
        onPressed: onLocationPressed,
        child: const Icon(Icons.my_location),
      ),
    ];
  }

  List<Widget> _selectionControls() {
    return [
      FloatingActionButton.small(
        heroTag: 'cancelSelectionButton',
        onPressed: onCancelSelectionPressed,
        child: const Icon(Icons.close),
      ),
      const SizedBox(height: AppSpacing.xs),
      FloatingActionButton.small(
        heroTag: 'addHereButton',
        onPressed: onAddHerePressed,
        child: const Icon(Icons.check),
      ),
    ];
  }
}
