import 'package:geolocator/geolocator.dart';

enum LocationFailureReason {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  positionUnavailable,
}

sealed class LocationResult {
  const LocationResult();
}

final class LocationSuccess extends LocationResult {
  const LocationSuccess(this.position);

  final Position position;
}

final class LocationFailure extends LocationResult {
  const LocationFailure(this.reason);

  final LocationFailureReason reason;
}

class LocationService {
  const LocationService();

  Future<LocationResult> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationFailure(LocationFailureReason.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const LocationFailure(LocationFailureReason.permissionDenied);
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationFailure(
        LocationFailureReason.permissionDeniedForever,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      return LocationSuccess(position);
    } catch (_) {
      return const LocationFailure(LocationFailureReason.positionUnavailable);
    }
  }
}
