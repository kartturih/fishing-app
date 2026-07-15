import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';

class MapControls extends StatelessWidget {
  const MapControls({super.key, required this.onLocationPressed});

  final VoidCallback onLocationPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'mapSettingsButton',
                onPressed: () {},
                child: const Icon(Icons.settings),
              ),
              const SizedBox(height: AppSpacing.sm),
              FloatingActionButton(
                heroTag: 'currentLocationButton',
                onPressed: onLocationPressed,
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
