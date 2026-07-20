import 'package:fishing_app/features/catches/domain/fish_species.dart';

/// One fish species paired with how many catches of that species the
/// angler has logged. See MFS-020 / TD-020.
final class SpeciesCatchStatistic {
  const SpeciesCatchStatistic({required this.species, required this.catchCount})
    : assert(catchCount > 0, 'catchCount must be greater than zero');

  final FishSpecies species;
  final int catchCount;
}
