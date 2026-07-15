import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:fishing_app/core/location/location_service.dart';
import 'package:fishing_app/features/fishing_spots/data/sample_fishing_spots.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/fishing_spots/presentation/widgets/add_fishing_spot_bottom_sheet.dart';
import 'package:fishing_app/features/fishing_spots/presentation/widgets/fishing_spot_name_bottom_sheet.dart';
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
  bool _isSelectionMode = false;
  bool _isCreatingFishingSpot = false;

  String _generateFishingSpotId() =>
      'spot-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _addFishingSpotMarkers() async {
    final controller = _mapController;
    if (controller == null || _fishingSpotMarkersAdded) {
      return;
    }

    var allMarkersAdded = true;

    for (final spot in sampleFishingSpots) {
      final success = await _addFishingSpotMarker(spot);
      if (!success) {
        allMarkersAdded = false;
      }
    }

    if (allMarkersAdded) {
      _fishingSpotMarkersAdded = true;
    }
  }

  Future<bool> _addFishingSpotMarker(FishingSpot spot) async {
    final controller = _mapController;
    if (controller == null) {
      return false;
    }

    try {
      await controller.addCircle(
        CircleOptions(
          geometry: LatLng(spot.latitude, spot.longitude),
          circleRadius: 8,
          circleColor: '#009688',
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 2,
        ),
      );

      await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(spot.latitude, spot.longitude),
          textField: spot.name,
          textOffset: const Offset(0, 1.2),
        ),
      );

      return true;
    } catch (error) {
      debugPrint('Failed to add fishing spot marker: $error');
      return false;
    }
  }

  Future<void> _onLocationPressed() async {
    final result = await _locationService.getCurrentPosition();

    if (!mounted) return;

    switch (result) {
      case LocationSuccess(:final position):
        setState(() => _myLocationEnabled = true);
        await _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      case LocationFailure(:final reason):
        _showLocationFailureMessage(reason);
    }
  }

  Future<void> _onAddFishingSpotPressed() async {
    final method = await AddFishingSpotBottomSheet.show(context);
    if (!mounted || method == null) {
      return;
    }

    switch (method) {
      case FishingSpotCreationMethod.currentLocation:
        await _createFishingSpotFromCurrentLocation();
      case FishingSpotCreationMethod.selectFromMap:
        setState(() => _isSelectionMode = true);
    }
  }

  Future<void> _createFishingSpotFromCurrentLocation() async {
    if (_isCreatingFishingSpot) {
      return;
    }
    _isCreatingFishingSpot = true;

    try {
      final result = await _locationService.getCurrentPosition();
      if (!mounted) return;

      switch (result) {
        case LocationSuccess(:final position):
          await _promptAndCreateFishingSpot(
            LatLng(position.latitude, position.longitude),
          );
        case LocationFailure(:final reason):
          _showLocationFailureMessage(reason);
      }
    } finally {
      _isCreatingFishingSpot = false;
    }
  }

  void _onCancelSelectionPressed() {
    setState(() => _isSelectionMode = false);
  }

  Future<void> _onAddHerePressed() async {
    if (_isCreatingFishingSpot) {
      return;
    }

    final target = _mapController?.cameraPosition?.target;
    if (target == null) {
      return;
    }

    _isCreatingFishingSpot = true;
    try {
      await _promptAndCreateFishingSpot(target);
    } finally {
      _isCreatingFishingSpot = false;
      if (mounted) {
        setState(() => _isSelectionMode = false);
      }
    }
  }

  Future<void> _promptAndCreateFishingSpot(LatLng position) async {
    final name = await FishingSpotNameBottomSheet.show(context);
    if (!mounted || name == null) {
      return;
    }

    final spot = FishingSpot(
      id: _generateFishingSpotId(),
      name: name,
      latitude: position.latitude,
      longitude: position.longitude,
      createdAt: DateTime.now(),
    );

    sampleFishingSpots.add(spot);
    await _addFishingSpotMarker(spot);
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fishing App')),
      body: Stack(
        children: [
          MapLibreMap(
            initialCameraPosition: _initialCameraPosition,
            myLocationEnabled: _myLocationEnabled,
            trackCameraPosition: true,
            onMapCreated: (controller) => _mapController = controller,
            onStyleLoadedCallback: _addFishingSpotMarkers,
            styleString: 'https://demotiles.maplibre.org/style.json',
          ),
          if (_isSelectionMode)
            const IgnorePointer(
              child: Center(child: Icon(Icons.add, size: 32)),
            ),
          MapControls(
            isSelectionMode: _isSelectionMode,
            onLocationPressed: _onLocationPressed,
            onAddFishingSpotPressed: _onAddFishingSpotPressed,
            onCancelSelectionPressed: _onCancelSelectionPressed,
            onAddHerePressed: _onAddHerePressed,
          ),
        ],
      ),
    );
  }
}
