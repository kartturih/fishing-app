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
          padding: const EdgeInsets.all(AppSpacing.lg),
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

  List<Widget> _defaultControls() {
    return [
      FloatingActionButton(
        heroTag: 'mapSettingsButton',
        onPressed: () {},
        child: const Icon(Icons.settings),
      ),
      const SizedBox(height: AppSpacing.sm),
      FloatingActionButton(
        heroTag: 'addFishingSpotButton',
        onPressed: onAddFishingSpotPressed,
        child: const Icon(Icons.add_location_alt),
      ),
      const SizedBox(height: AppSpacing.sm),
      FloatingActionButton(
        heroTag: 'currentLocationButton',
        onPressed: onLocationPressed,
        child: const Icon(Icons.my_location),
      ),
    ];
  }

  List<Widget> _selectionControls() {
    return [
      FloatingActionButton(
        heroTag: 'cancelSelectionButton',
        onPressed: onCancelSelectionPressed,
        child: const Icon(Icons.close),
      ),
      const SizedBox(height: AppSpacing.sm),
      FloatingActionButton(
        heroTag: 'addHereButton',
        onPressed: onAddHerePressed,
        child: const Icon(Icons.check),
      ),
    ];
  }
}
