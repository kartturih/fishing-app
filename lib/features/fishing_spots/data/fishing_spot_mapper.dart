import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

extension FishingSpotEntityMapper on FishingSpotEntity {
  FishingSpot toDomain() {
    final resolvedWaterBodyId = waterBodyId;
    if (resolvedWaterBodyId == null) {
      throw StateError(
        'FishingSpot "$id" has no waterBodyId — migration invariant violated.',
      );
    }
    return FishingSpot(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      waterBodyId: resolvedWaterBodyId,
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
      waterBodyId: Value(waterBodyId),
      createdAt: createdAt.millisecondsSinceEpoch,
    );
  }
}
