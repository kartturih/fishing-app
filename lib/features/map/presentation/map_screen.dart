import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:fishing_app/features/map/presentation/widgets/map_controls.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(61.9241, 25.7482),
    zoom: 5,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fishing App'),
      ),
      body: Stack(
        children: [
          MapLibreMap(
            initialCameraPosition: _initialCameraPosition,
            styleString: 'https://demotiles.maplibre.org/style.json',
          ),
          const MapControls(),
        ],
      ),
    );
  }
}
