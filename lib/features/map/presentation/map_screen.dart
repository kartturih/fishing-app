import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:fishing_app/core/location/location_service.dart';
import 'package:fishing_app/features/fishing_spots/data/sample_fishing_spots.dart';
import 'package:fishing_app/features/map/presentation/widgets/map_controls.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(61.9241, 25.7482),
    zoom: 5,
  );

  final LocationService _locationService = const LocationService();

  MapLibreMapController? _mapController;
  bool _myLocationEnabled = false;
  bool _fishingSpotMarkersAdded = false;

  Future<void> _addFishingSpotMarkers() async {
    final controller = _mapController;
    if (controller == null || _fishingSpotMarkersAdded) {
      return;
    }


    try {
      await controller.addCircles([
        for (final spot in sampleFishingSpots)
          CircleOptions(
            geometry: LatLng(spot.latitude, spot.longitude),
            circleRadius: 8,
            circleColor: '#009688',
            circleStrokeColor: '#ffffff',
            circleStrokeWidth: 2,
          ),
      ]);

      await controller.addSymbols([
        for (final spot in sampleFishingSpots)
          SymbolOptions(
            geometry: LatLng(spot.latitude, spot.longitude),
            textField: spot.name,
            textOffset: const Offset(0, 1.2),
          ),
      ]);

      _fishingSpotMarkersAdded = true;
    } catch (error) {
      debugPrint('Failed to add fishing spot markers: $error');
    }
  }

  Future<void> _onLocationPressed() async {
    final result = await _locationService.getCurrentPosition();

    if (!mounted) return;

    switch (result) {
      case LocationSuccess(:final position):
        setState(() => _myLocationEnabled = true);
        await _mapController?.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ),
        );
      case LocationFailure(:final reason):
        _showLocationFailureMessage(reason);
    }
  }

  void _showLocationFailureMessage(LocationFailureReason reason) {
    final message = switch (reason) {
      LocationFailureReason.serviceDisabled =>
        'Location services are disabled.',
      LocationFailureReason.permissionDenied =>
        'Location permission was denied.',
      LocationFailureReason.permissionDeniedForever =>
        'Location permission is permanently denied. Enable it in system settings.',
      LocationFailureReason.positionUnavailable =>
        'Current location is unavailable.',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

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
            myLocationEnabled: _myLocationEnabled,
            onMapCreated: (controller) => _mapController = controller,
            onStyleLoadedCallback: _addFishingSpotMarkers,
            styleString: 'https://demotiles.maplibre.org/style.json',
          ),
          MapControls(onLocationPressed: _onLocationPressed),
        ],
      ),
    );
  }
}
