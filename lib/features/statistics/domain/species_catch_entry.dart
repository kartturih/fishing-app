import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';

/// One catch of a specific species, paired with the fishing spot it belongs
/// to — everything `CatchDetailsPage` needs to open for it. Unlike
/// `LargestCatch` (TD-020), this type carries no weight requirement: a
/// species-scoped Catch List includes every catch of that species, whether
/// or not it has a recorded weight. See MFS-021 / TD-021 Key Design
/// Decision 4.
///
/// [waterBody] was added additively by MFS-024/TD-024: `RecordCatchCard`'s
/// location line shows it in place of [fishingSpot]'s exact name, but
/// [fishingSpot] is kept unchanged — it is still required to open
/// `CatchDetailsPage` for this catch. See TD-024 Key Design Decision 9.
final class SpeciesCatchEntry {
  const SpeciesCatchEntry({
    required this.catchModel,
    required this.fishingSpot,
    required this.waterBody,
  });

  final Catch catchModel;
  final FishingSpot fishingSpot;
  final WaterBody waterBody;
}
