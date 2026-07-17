import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/core/location/location_service.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/presentation/widgets/add_catch_bottom_sheet.dart';
import 'package:fishing_app/features/catches/presentation/widgets/edit_catch_bottom_sheet.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/fishing_spots/presentation/widgets/add_fishing_spot_bottom_sheet.dart';
import 'package:fishing_app/features/fishing_spots/presentation/widgets/fishing_spot_details_bottom_sheet.dart';
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

  static const String _fishingSpotsSourceId = 'fishing-spots-source';
  static const String _fishingSpotsCircleLayerId = 'fishing-spots-circle-layer';
  static const String _fishingSpotsSymbolLayerId = 'fishing-spots-symbol-layer';

  final LocationService _locationService = const LocationService();
  final AppDatabase _database = AppDatabase();
  late final FishingSpotRepository _fishingSpotRepository =
      FishingSpotRepository(_database);
  late final CatchRepository _catchRepository = CatchRepository(_database);

  final Map<String, FishingSpot> _fishingSpotsById = {};

  MapLibreMapController? _mapController;
  bool _myLocationEnabled = false;
  bool _fishingSpotMarkersAdded = false;
  bool _isSelectionMode = false;
  bool _isCreatingFishingSpot = false;

  @override
  void dispose() {
    _mapController?.onFeatureTapped.remove(_onFishingSpotFeatureTapped);
    unawaited(_database.close());
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    controller.onFeatureTapped.add(_onFishingSpotFeatureTapped);
  }

  Map<String, dynamic> _fishingSpotToFeature(FishingSpot spot) {
    return {
      'type': 'Feature',
      'id': spot.id,
      'properties': {'id': spot.id, 'name': spot.name},
      'geometry': {
        'type': 'Point',
        'coordinates': [spot.longitude, spot.latitude],
      },
    };
  }

  Map<String, dynamic> _buildFeatureCollection(Iterable<FishingSpot> spots) {
    return {
      'type': 'FeatureCollection',
      'features': [for (final spot in spots) _fishingSpotToFeature(spot)],
    };
  }

  /// Sets up a single shared GeoJSON source backing two style layers (a
  /// circle for the marker dot, a symbol for the name label). Managed
  /// MapLibre annotations (`addCircle`/`addSymbol`/`updateSymbol`) always
  /// replace their *entire* backing GeoJSON source on every single call —
  /// even to add or relabel one marker — which on Android briefly stalls the
  /// embedded map surface and shows as a black flash. Using one feature-owned
  /// source for both layers means one full-collection update per fishing
  /// spot change instead of two (previously one for the circle annotation,
  /// one for the symbol annotation), halving how often that native refresh
  /// happens.
  Future<void> _addFishingSpotMarkers() async {
    final controller = _mapController;
    if (controller == null || _fishingSpotMarkersAdded) {
      return;
    }

    List<FishingSpot> spots;
    try {
      spots = await _fishingSpotRepository.loadAll();
    } catch (error) {
      debugPrint('Failed to load fishing spots: $error');
      return;
    }

    for (final spot in spots) {
      _fishingSpotsById[spot.id] = spot;
    }

    try {
      await controller.addGeoJsonSource(
        _fishingSpotsSourceId,
        _buildFeatureCollection(_fishingSpotsById.values),
        promoteId: 'id',
      );

      await controller.addLayer(
        _fishingSpotsSourceId,
        _fishingSpotsCircleLayerId,
        const CircleLayerProperties(
          circleRadius: 8,
          circleColor: '#009688',
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 2,
        ),
      );

      await controller.addLayer(
        _fishingSpotsSourceId,
        _fishingSpotsSymbolLayerId,
        SymbolLayerProperties(
          textField: [Expressions.get, 'name'],
          textOffset: [0, 1.2],
          textFont: kIsWeb
              ? null
              : const ['Open Sans Regular', 'Arial Unicode MS Regular'],
        ),
      );

      _fishingSpotMarkersAdded = true;
    } catch (error) {
      debugPrint('Failed to set up fishing spot markers: $error');
    }
  }

  Future<bool> _addFishingSpotFeature(FishingSpot spot) async {
    final controller = _mapController;
    if (controller == null) {
      return false;
    }

    _fishingSpotsById[spot.id] = spot;

    try {
      await controller.setGeoJsonSource(
        _fishingSpotsSourceId,
        _buildFeatureCollection(_fishingSpotsById.values),
      );
      return true;
    } catch (error) {
      debugPrint('Failed to add fishing spot marker: $error');
      return false;
    }
  }

  void _onFishingSpotFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (_isSelectionMode) {
      return;
    }

    if (layerId != _fishingSpotsCircleLayerId &&
        layerId != _fishingSpotsSymbolLayerId) {
      return;
    }

    final spot = _fishingSpotsById[id];
    if (spot == null) {
      return;
    }

    unawaited(_openFishingSpotDetails(spot));
  }

  Future<void> _openFishingSpotDetails(FishingSpot spot) async {
    final result = await FishingSpotDetailsBottomSheet.show(
      context,
      spot,
      _catchRepository,
    );
    if (!mounted || result == null) {
      return;
    }

    switch (result) {
      case FishingSpotRenamed(:final name):
        await _renameFishingSpot(spot, name);
      case FishingSpotDeleted():
        await _deleteFishingSpot(spot);
      case FishingSpotAddCatchRequested():
        await _openAddCatchBottomSheet(spot);
      case FishingSpotEditCatchRequested(:final catchModel):
        await _openEditCatchBottomSheet(spot, catchModel);
    }
  }

  Future<void> _openAddCatchBottomSheet(FishingSpot spot) async {
    final createdCatch = await AddCatchBottomSheet.show(
      context,
      spot,
      _catchRepository,
    );

    if (createdCatch != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saalis tallennettu')));
    }
  }

  Future<void> _openEditCatchBottomSheet(
    FishingSpot spot,
    Catch catchModel,
  ) async {
    final result = await EditCatchBottomSheet.show(
      context,
      spot,
      catchModel,
      _catchRepository,
    );

    if (!mounted || result == null) {
      return;
    }

    switch (result) {
      case CatchUpdated():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saalis päivitetty')));
      case CatchDeleted():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saalis poistettu')));
    }
  }

  Future<void> _renameFishingSpot(FishingSpot spot, String newName) async {
    FishingSpot updated;
    try {
      updated = await _fishingSpotRepository.updateName(
        id: spot.id,
        name: newName,
      );
    } catch (error) {
      debugPrint('Failed to update fishing spot: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kalastuspaikan päivittäminen epäonnistui. Yritä uudelleen.',
            ),
          ),
        );
      }
      return;
    }

    _fishingSpotsById[updated.id] = updated;

    final controller = _mapController;
    if (controller == null) {
      return;
    }

    try {
      await controller.setGeoJsonFeature(
        _fishingSpotsSourceId,
        _fishingSpotToFeature(updated),
      );
    } catch (error) {
      debugPrint('Failed to update fishing spot marker: $error');
    }
  }

  Future<void> _deleteFishingSpot(FishingSpot spot) async {
    try {
      await _fishingSpotRepository.delete(spot.id);
    } catch (error) {
      debugPrint('Failed to delete fishing spot: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kalastuspaikan poistaminen epäonnistui. Yritä uudelleen.',
            ),
          ),
        );
      }
      return;
    }

    _fishingSpotsById.remove(spot.id);

    final controller = _mapController;
    if (controller == null) {
      return;
    }

    try {
      await controller.setGeoJsonSource(
        _fishingSpotsSourceId,
        _buildFeatureCollection(_fishingSpotsById.values),
      );
    } catch (error) {
      debugPrint('Failed to refresh fishing spot markers: $error');
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

    try {
      final spot = await _fishingSpotRepository.create(
        name: name,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      await _addFishingSpotFeature(spot);
    } catch (error) {
      debugPrint('Failed to save fishing spot: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kalastuspaikan tallentaminen epäonnistui. Yritä uudelleen.',
            ),
          ),
        );
      }
    }
  }

  void _showLocationFailureMessage(LocationFailureReason reason) {
    final message = switch (reason) {
      LocationFailureReason.serviceDisabled =>
        'Sijaintipalvelut on poistettu käytöstä.',
      LocationFailureReason.permissionDenied => 'Sijaintilupa evättiin.',
      LocationFailureReason.permissionDeniedForever =>
        'Sijaintilupa on evätty pysyvästi. Ota se käyttöön järjestelmäasetuksista.',
      LocationFailureReason.positionUnavailable =>
        'Nykyinen sijainti ei ole käytettävissä.',
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('Kalastussovellus')),
      body: Stack(
        children: [
          MapLibreMap(
            initialCameraPosition: _initialCameraPosition,
            myLocationEnabled: _myLocationEnabled,
            trackCameraPosition: true,
            onMapCreated: _onMapCreated,
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
