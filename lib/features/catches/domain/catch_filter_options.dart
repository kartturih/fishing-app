import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';

/// The selectable values for each filter category (MFS-025 FR-8), computed
/// from the angler's *actual catch history* only (TD-025 Key Design
/// Decision 10) — never the full reference-data universe. A water body,
/// species, or lure with zero recorded catches is never offered, since
/// selecting it would trivially always produce zero results. Loaded once
/// when the filter sheet is first opened; the date-range category needs no
/// data-sourced options.
final class CatchFilterOptions {
  const CatchFilterOptions({
    required this.waterBodies,
    required this.species,
    required this.lures,
  });

  final List<WaterBody> waterBodies;
  final List<FishSpecies> species;
  final List<LureCatalogEntry> lures;

  static const empty = CatchFilterOptions(
    waterBodies: [],
    species: [],
    lures: [],
  );
}
