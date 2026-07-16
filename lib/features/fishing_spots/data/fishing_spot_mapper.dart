import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

extension FishingSpotEntityMapper on FishingSpotEntity {
  FishingSpot toDomain() {
    return FishingSpot(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    );
  }
}

extension FishingSpotCompanionMapper on FishingSpot {
  FishingSpotsCompanion toCompanion() {
    return FishingSpotsCompanion.insert(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      createdAt: createdAt.millisecondsSinceEpoch,
    );
  }
}
