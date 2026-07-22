/// A body of water (lake, pond, river, reservoir, sea/coastal area, or
/// another user-defined water area) that one or more [FishingSpot]s belong
/// to. Identity only in this milestone — no depth, species, vegetation, or
/// weather metadata. See MFS-024 / ADR-0007 / TD-024.
class WaterBody {
  const WaterBody({
    required this.id,
    required this.name,
    required this.createdAt,
  }) : assert(name != '', 'name must not be empty');

  final String id;
  final String name;
  final DateTime createdAt;
}
