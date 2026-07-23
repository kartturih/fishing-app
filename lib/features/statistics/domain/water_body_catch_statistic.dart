import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';

/// One water body paired with how many catches the angler has logged across
/// every fishing spot that belongs to it. Backs the Water Body List within
/// the Catches tab — the same "reference domain object, plus a count" shape
/// `SpeciesCatchStatistic`/`FishingSpotCatchStatistic` already established.
final class WaterBodyCatchStatistic {
  const WaterBodyCatchStatistic({
    required this.waterBody,
    required this.catchCount,
  }) : assert(catchCount > 0, 'catchCount must be greater than zero');

  final WaterBody waterBody;
  final int catchCount;
}
