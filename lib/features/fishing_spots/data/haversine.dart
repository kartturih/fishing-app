import 'dart:math';

/// Great-circle distance between two coordinates, in meters, using the
/// standard haversine formula. Pure `dart:math`, no platform or external
/// package dependency. Feature-owned (used only by `WaterBodyRepository`'s
/// nearby-water-body ranking) rather than placed in `core`, per ADR-0003's
/// placement rule. See TD-024.
double haversineDistanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _degreesToRadians(lat2 - lat1);
  final dLon = _degreesToRadians(lon2 - lon1);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _degreesToRadians(double degrees) => degrees * pi / 180;
