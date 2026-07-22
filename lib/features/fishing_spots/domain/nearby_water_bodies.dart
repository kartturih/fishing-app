import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';

/// The result of a nearby-water-body query (MFS-024 FR-5): every candidate
/// within this repository's ranking, ordered nearest-first, plus at most one
/// of them singled out as [preselected] when it is unambiguously the most
/// likely match. [preselected], when non-null, is always the first entry of
/// [candidates] as well — this type never introduces a candidate the list
/// itself does not already contain. See TD-024.
class NearbyWaterBodies {
  const NearbyWaterBodies({
    required this.candidates,
    required this.preselected,
  });

  final List<WaterBody> candidates;
  final WaterBody? preselected;

  static const empty = NearbyWaterBodies(candidates: [], preselected: null);
}
