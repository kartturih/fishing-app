import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';

/// A [WaterBody] paired with how many [FishingSpot]s currently reference it —
/// used only by the water-body management surface (MFS-024 FR-16). Not a
/// persisted aggregate; computed fresh on each load, the same "computed
/// live, never stored" discipline the Statistics feature already
/// established. See TD-024.
class WaterBodyWithSpotCount {
  const WaterBodyWithSpotCount({
    required this.waterBody,
    required this.fishingSpotCount,
  });

  final WaterBody waterBody;
  final int fishingSpotCount;
}
