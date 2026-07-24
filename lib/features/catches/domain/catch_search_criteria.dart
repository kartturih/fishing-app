import 'package:fishing_app/features/catches/domain/fish_species.dart';

/// Sentinel used by [CatchSearchCriteria.copyWith] to distinguish "leave
/// this field unchanged" from "explicitly set this field to null" for each
/// of its nullable filter fields.
const Object _unset = Object();

/// One immutable snapshot of "what the angler is currently asking to see" on
/// the global catch-browsing page (MFS-025): a free-text query plus up to
/// one active selection per filter category (single-select per category,
/// MFS-025's own MVP decision — enforced structurally here by each filter
/// field being a single nullable value, not a collection).
///
/// [query] is the trimmed (not lowercased) text the angler typed — see
/// `CatchSearchRepository` for where and how case-insensitive matching is
/// actually performed. [dateFrom]/[dateTo] are each expected to already be
/// normalized to that calendar day's start/end (00:00:00.000 /
/// 23:59:59.999) by the caller before being placed here, so the repository
/// can apply a plain inclusive `>=`/`<=` comparison with no date-boundary
/// logic of its own.
///
/// Deliberately given value equality and [copyWith], unlike `Catch`/
/// `FishingSpot`/`WaterBody` (which intentionally have neither) — this type
/// is a query/comparison value object, constructed fresh on every state
/// change and compared directly in tests, not a mutable, identity-bearing
/// entity. See TD-025 Key Design Decision 8.
final class CatchSearchCriteria {
  const CatchSearchCriteria({
    this.query = '',
    this.waterBodyId,
    this.species,
    this.lureVariantId,
    this.dateFrom,
    this.dateTo,
  });

  final String query;
  final String? waterBodyId;
  final FishSpecies? species;
  final String? lureVariantId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  static const empty = CatchSearchCriteria();

  bool get hasActiveFilters =>
      waterBodyId != null ||
      species != null ||
      lureVariantId != null ||
      dateFrom != null ||
      dateTo != null;

  bool get isEmpty => query.isEmpty && !hasActiveFilters;

  /// Returns a copy with the given fields replaced. Every filter parameter
  /// accepts an explicit `null` to *clear* that field — distinguished from
  /// "not passed at all" (leave unchanged) via the [_unset] sentinel, since a
  /// plain `T? copyWith({T? x})` cannot tell the two apart for a field that
  /// is itself nullable.
  CatchSearchCriteria copyWith({
    String? query,
    Object? waterBodyId = _unset,
    Object? species = _unset,
    Object? lureVariantId = _unset,
    Object? dateFrom = _unset,
    Object? dateTo = _unset,
  }) {
    return CatchSearchCriteria(
      query: query ?? this.query,
      waterBodyId: identical(waterBodyId, _unset)
          ? this.waterBodyId
          : waterBodyId as String?,
      species: identical(species, _unset)
          ? this.species
          : species as FishSpecies?,
      lureVariantId: identical(lureVariantId, _unset)
          ? this.lureVariantId
          : lureVariantId as String?,
      dateFrom: identical(dateFrom, _unset)
          ? this.dateFrom
          : dateFrom as DateTime?,
      dateTo: identical(dateTo, _unset) ? this.dateTo : dateTo as DateTime?,
    );
  }

  /// Every filter cleared; [query] left untouched — backs the filter sheet's
  /// "clear all filters" action (MFS-025 FR-11), which must not also clear
  /// the text search (that is FR-20's own, separate clear-button action).
  CatchSearchCriteria clearFilters() => CatchSearchCriteria(query: query);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatchSearchCriteria &&
          other.query == query &&
          other.waterBodyId == waterBodyId &&
          other.species == species &&
          other.lureVariantId == lureVariantId &&
          other.dateFrom == dateFrom &&
          other.dateTo == dateTo);

  @override
  int get hashCode =>
      Object.hash(query, waterBodyId, species, lureVariantId, dateFrom, dateTo);
}
