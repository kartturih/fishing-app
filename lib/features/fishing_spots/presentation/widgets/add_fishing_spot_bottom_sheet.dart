import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';

enum FishingSpotCreationMethod { currentLocation, selectFromMap }

class AddFishingSpotBottomSheet extends StatelessWidget {
  const AddFishingSpotBottomSheet({super.key});

  static Future<FishingSpotCreationMethod?> show(BuildContext context) {
    return showModalBottomSheet<FishingSpotCreationMethod>(
      context: context,
      showDragHandle: true,
      builder: (context) => const AddFishingSpotBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('Current Location'),
              onTap: () => Navigator.of(context).pop(
                FishingSpotCreationMethod.currentLocation,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Select From Map'),
              onTap: () => Navigator.of(context).pop(
                FishingSpotCreationMethod.selectFromMap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
