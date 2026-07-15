class FishingSpot {
  const FishingSpot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
}
