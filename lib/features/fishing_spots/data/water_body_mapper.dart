import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';

extension WaterBodyEntityMapper on WaterBodyEntity {
  WaterBody toDomain() {
    return WaterBody(
      id: id,
      name: name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    );
  }
}

extension WaterBodyCompanionMapper on WaterBody {
  WaterBodiesCompanion toCompanion() {
    return WaterBodiesCompanion.insert(
      id: id,
      name: name,
      createdAt: createdAt.millisecondsSinceEpoch,
    );
  }
}
