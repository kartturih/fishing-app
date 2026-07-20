import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

/// One catch with a recorded weight, paired with the fishing spot it
/// belongs to — everything `CatchDetailsPage` needs to open for it. See
/// MFS-020 / TD-020.
///
/// Not `const`-constructible: the assertion below reads a nested field of
/// [catchModel] (`catchModel.weightGrams`), which Dart does not accept as
/// a constant expression, unlike the simple primitive-parameter asserts
/// used elsewhere in this feature (e.g. `SpeciesCatchStatistic.catchCount`).
final class LargestCatch {
  LargestCatch({required this.catchModel, required this.fishingSpot})
    : assert(
        catchModel.weightGrams != null,
        'catchModel must have a recorded weight',
      );

  final Catch catchModel;
  final FishingSpot fishingSpot;
}
