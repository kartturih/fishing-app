import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';

/// One fully-enriched search result row: a [Catch] paired with everything
/// the results list (MFS-025 FR-13) and `CatchDetailsPage` (FR-14) need to
/// render/navigate, with no further per-row repository call. Mirrors
/// `statistics`' own `SpeciesCatchEntry` shape (catch + fishingSpot +
/// waterBody) exactly, extended with an optional, already-resolved [lure] —
/// reusing `lure_catalog`'s own [LureCatalogEntry] read-model by reference
/// rather than duplicating manufacturer/model fields onto this type, per
/// this project's established "reference, never duplicate" discipline
/// (ADR-0007).
///
/// [lure] is `null` when the catch has no assigned lure, or when its
/// assigned `lureVariantId` cannot be resolved at all (a dangling
/// reference) — both render identically (no lure line), per MFS-019 FR-10's
/// established "unresolvable lure reference handled without crashing"
/// precedent. A *retired* (but still resolvable) lure is not `null` here.
final class CatchSearchResult {
  const CatchSearchResult({
    required this.catchModel,
    required this.fishingSpot,
    required this.waterBody,
    this.lure,
  });

  final Catch catchModel;
  final FishingSpot fishingSpot;
  final WaterBody waterBody;
  final LureCatalogEntry? lure;
}
