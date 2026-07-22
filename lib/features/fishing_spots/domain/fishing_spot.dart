class FishingSpot {
  const FishingSpot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.waterBodyId,
    required this.createdAt,
  }) : assert(waterBodyId != '', 'waterBodyId must not be empty');

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String waterBodyId;
  final DateTime createdAt;
}
