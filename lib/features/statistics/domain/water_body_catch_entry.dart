import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

/// One catch logged at a water body, paired with the specific fishing spot
/// (under that water body) it belongs to — everything `CatchDetailsPage`
/// needs to open for it. A wrapper type is needed here (unlike
/// `FishingSpotStatisticsSummary.catches`) because a water body's Catch List
/// spans every fishing spot under it, so the fishing spot varies from catch
/// to catch — the same reason `SpeciesCatchEntry` wraps a `Catch` with its
/// `FishingSpot`.
final class WaterBodyCatchEntry {
  const WaterBodyCatchEntry({required this.catchModel, required this.fishingSpot});

  final Catch catchModel;
  final FishingSpot fishingSpot;
}
