import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

/// One fishing spot paired with how many catches the angler has logged
/// there. Backs the Fishing Spot List within the Catches tab, the same
/// "reference domain object, plus a count" shape `SpeciesCatchStatistic`
/// already established. See MFS-022 / TD-022.
final class FishingSpotCatchStatistic {
  const FishingSpotCatchStatistic({
    required this.fishingSpot,
    required this.catchCount,
  }) : assert(catchCount > 0, 'catchCount must be greater than zero');

  final FishingSpot fishingSpot;
  final int catchCount;
}
