import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_mapper.dart';
import 'package:fishing_app/features/catches/domain/catch_filter_options.dart';
import 'package:fishing_app/features/catches/domain/catch_search_criteria.dart';
import 'package:fishing_app/features/catches/domain/catch_search_result.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_mapper.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_mapper.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_mapper.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';

/// Concrete, read-only repository for the global catch-browsing/search
/// surface (MFS-025). A sibling to `CatchRepository`, not a method on it —
/// mirrors the same "one focused repository per read-model, reading
/// whichever tables it needs directly" discipline already established by
/// every Statistics repository (`GeneralCatchStatisticsRepository`,
/// `SpeciesStatisticsRepository`, `WaterBodyStatisticsRepository`,
/// `LureStatisticsRepository`) and by `WaterBodyRepository` itself. See
/// TD-025 Key Design Decision 1.
///
/// Deliberately does **not** call `LureCatalogRepository.browse()` for
/// lure-name matching: `browse()` excludes retired variants, but a catch's
/// assigned lure must remain searchable even after the underlying catalog
/// variant is retired (MFS-019 FR-10's established historical-stability
/// precedent). This repository therefore runs its own small, targeted query
/// directly against `LureModels`/`LureVariants`' own precomputed
/// `searchText` columns instead. See TD-025 Key Design Decision 5.
class CatchSearchRepository {
  CatchSearchRepository(
    this._database, [
    this._catchMapper = const CatchMapper(),
    this._lureCatalogMapper = const LureCatalogMapper(),
  ]);

  final AppDatabase _database;
  final CatchMapper _catchMapper;
  final LureCatalogMapper _lureCatalogMapper;

  /// The `ESCAPE` character used in this repository's own lure-name `LIKE`
  /// pattern. Mirrors `LureCatalogRepository`'s private constant of the same
  /// name/value — a small, deliberate duplication of a ~3-line escaping
  /// utility rather than a shared, cross-feature import, since
  /// `lure_catalog` is not modified by this milestone (MFS-025 Data
  /// Ownership). See TD-025 Key Design Decision 5.
  static const String _likeEscapeChar = r'\';

  /// Returns every catch matching [criteria], fully enriched with its
  /// fishing spot, water body, and (when present/resolvable) assigned lure —
  /// so neither the results list nor `CatchDetailsPage` needs a further
  /// per-row repository call (MFS-025 FR-17).
  ///
  /// Explicit filters ([CatchSearchCriteria.waterBodyId], `.species`,
  /// `.lureVariantId`, `.dateFrom`/`.dateTo`) combine with AND semantics.
  /// A non-empty [CatchSearchCriteria.query] combines with OR across five
  /// candidate categories (species, water body, fishing spot, lure brand,
  /// lure model), then ANDs that whole group into the explicit filters. See
  /// TD-025 §9.
  Future<List<CatchSearchResult>> search(CatchSearchCriteria criteria) async {
    final query = _database.select(_database.catches).join([
      innerJoin(
        _database.fishingSpots,
        _database.fishingSpots.id.equalsExp(_database.catches.fishingSpotId),
      ),
      innerJoin(
        _database.waterBodies,
        _database.waterBodies.id.equalsExp(_database.fishingSpots.waterBodyId),
      ),
      leftOuterJoin(
        _database.lureVariants,
        _database.lureVariants.id.equalsExp(_database.catches.lureVariantId),
      ),
      leftOuterJoin(
        _database.lureModels,
        _database.lureModels.id.equalsExp(_database.lureVariants.lureModelId),
      ),
    ]);

    final predicate = await _buildPredicate(criteria);
    if (predicate != null) {
      query.where(predicate);
    }

    query.orderBy([
      OrderingTerm.desc(_database.catches.caughtAt),
      OrderingTerm.desc(_database.catches.createdAt),
      OrderingTerm.asc(_database.catches.id),
    ]);

    final rows = await query.get();
    return [for (final row in rows) _resultFromRow(row)];
  }

  /// The selectable values for each filter category (MFS-025 FR-8),
  /// restricted to values actually present in the angler's own catch
  /// history — never the full reference-data universe (TD-025 Key Design
  /// Decision 10). One joined query, aggregated/deduplicated in Dart via
  /// keyed maps/sets, mirroring `WaterBodyRepository.loadAllWithSpotCounts`'s
  /// established "one join, aggregate in Dart" idiom.
  Future<CatchFilterOptions> getFilterOptions() async {
    final query = _database.select(_database.catches).join([
      innerJoin(
        _database.fishingSpots,
        _database.fishingSpots.id.equalsExp(_database.catches.fishingSpotId),
      ),
      innerJoin(
        _database.waterBodies,
        _database.waterBodies.id.equalsExp(_database.fishingSpots.waterBodyId),
      ),
      leftOuterJoin(
        _database.lureVariants,
        _database.lureVariants.id.equalsExp(_database.catches.lureVariantId),
      ),
      leftOuterJoin(
        _database.lureModels,
        _database.lureModels.id.equalsExp(_database.lureVariants.lureModelId),
      ),
    ]);
    final rows = await query.get();

    final waterBodies = <String, WaterBody>{};
    final species = <FishSpecies>{};
    final lures = <String, LureCatalogEntry>{};

    for (final row in rows) {
      final waterBody = row.readTable(_database.waterBodies).toDomain();
      waterBodies[waterBody.id] = waterBody;

      final catchModel = _catchMapper.toDomain(
        row.readTable(_database.catches),
      );
      species.add(catchModel.species);

      final variantRow = row.readTableOrNull(_database.lureVariants);
      final modelRow = row.readTableOrNull(_database.lureModels);
      if (variantRow != null && modelRow != null) {
        lures[variantRow.id] = _lureCatalogMapper.entryFromRows(
          variantRow: variantRow,
          modelRow: modelRow,
        );
      }
    }

    final sortedWaterBodies = waterBodies.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final sortedSpecies = species.toList()
      ..sort(
        (a, b) =>
            a.finnishName.toLowerCase().compareTo(b.finnishName.toLowerCase()),
      );
    final sortedLures = lures.values.toList()
      ..sort((a, b) {
        final manufacturerCompare = a.manufacturer.toLowerCase().compareTo(
          b.manufacturer.toLowerCase(),
        );
        if (manufacturerCompare != 0) {
          return manufacturerCompare;
        }
        return a.modelName.toLowerCase().compareTo(b.modelName.toLowerCase());
      });

    return CatchFilterOptions(
      waterBodies: sortedWaterBodies,
      species: sortedSpecies,
      lures: sortedLures,
    );
  }

  Future<Expression<bool>?> _buildPredicate(
    CatchSearchCriteria criteria,
  ) async {
    Expression<bool>? predicate;
    void and(Expression<bool> expr) {
      predicate = predicate == null ? expr : predicate! & expr;
    }

    if (criteria.waterBodyId != null) {
      and(_database.waterBodies.id.equals(criteria.waterBodyId!));
    }
    if (criteria.species != null) {
      and(_database.catches.species.equals(criteria.species!.name));
    }
    if (criteria.lureVariantId != null) {
      and(_database.catches.lureVariantId.equals(criteria.lureVariantId!));
    }
    if (criteria.dateFrom != null) {
      and(
        _database.catches.caughtAt.isBiggerOrEqualValue(
          criteria.dateFrom!.millisecondsSinceEpoch,
        ),
      );
    }
    if (criteria.dateTo != null) {
      and(
        _database.catches.caughtAt.isSmallerOrEqualValue(
          criteria.dateTo!.millisecondsSinceEpoch,
        ),
      );
    }

    final normalizedQuery = criteria.query.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      and(await _textMatchPredicate(normalizedQuery));
    }

    return predicate;
  }

  /// Builds the OR-group matching [normalizedQuery] against species
  /// (Finnish name), water body name, fishing spot name, and lure
  /// brand/model — see TD-025 Key Design Decisions 4/5/6. Each candidate
  /// category is only OR-ed in when it actually produced at least one
  /// match, so an empty candidate list never becomes a Drift `.isIn([])`
  /// call.
  Future<Expression<bool>> _textMatchPredicate(String normalizedQuery) async {
    Expression<bool> expr = const Constant(false);

    final matchedSpeciesNames = _matchingSpeciesNames(normalizedQuery);
    if (matchedSpeciesNames.isNotEmpty) {
      expr = expr | _database.catches.species.isIn(matchedSpeciesNames);
    }

    final matchedWaterBodyIds = await _matchingWaterBodyIds(normalizedQuery);
    if (matchedWaterBodyIds.isNotEmpty) {
      expr = expr | _database.waterBodies.id.isIn(matchedWaterBodyIds);
    }

    final matchedFishingSpotIds = await _matchingFishingSpotIds(
      normalizedQuery,
    );
    if (matchedFishingSpotIds.isNotEmpty) {
      expr = expr | _database.fishingSpots.id.isIn(matchedFishingSpotIds);
    }

    final matchedLureVariantIds = await _matchingLureVariantIds(
      normalizedQuery,
    );
    if (matchedLureVariantIds.isNotEmpty) {
      expr = expr | _database.catches.lureVariantId.isIn(matchedLureVariantIds);
    }

    return expr;
  }

  /// Bounded, in-memory match over the fixed, 19-value [FishSpecies] enum —
  /// never a scan of `Catches`. Dart's `String.toLowerCase()` folds Finnish
  /// `ä`/`ö`/`å` correctly, unlike SQLite's built-in, ASCII-only `LIKE`. See
  /// TD-025 Key Design Decision 4.
  List<String> _matchingSpeciesNames(String normalizedQuery) {
    return [
      for (final species in FishSpecies.values)
        if (species.finnishName.toLowerCase().contains(normalizedQuery))
          species.name,
    ];
  }

  /// Bounded, in-memory match over every existing water body — a small
  /// reference table at this application's scale, the same assumption
  /// `WaterBodyRepository.loadAll()`/`getNearby()` already rely on. See
  /// TD-025 Key Design Decision 5.
  Future<List<String>> _matchingWaterBodyIds(String normalizedQuery) async {
    final rows = await _database.select(_database.waterBodies).get();
    return [
      for (final row in rows)
        if (row.name.toLowerCase().contains(normalizedQuery)) row.id,
    ];
  }

  /// Bounded, in-memory match over every existing fishing spot — same
  /// "small reference table" assumption as [_matchingWaterBodyIds].
  Future<List<String>> _matchingFishingSpotIds(String normalizedQuery) async {
    final rows = await _database.select(_database.fishingSpots).get();
    return [
      for (final row in rows)
        if (row.name.toLowerCase().contains(normalizedQuery)) row.id,
    ];
  }

  /// A small, targeted SQL match directly against `LureModels`/
  /// `LureVariants`' own precomputed, Finnish-lowercased `searchText`
  /// columns — reusing the columns `lure_catalog` already maintains, but
  /// *not* calling `LureCatalogRepository.browse()`. Deliberately does not
  /// exclude retired variants (`browse()` does) — see TD-025 Key Design
  /// Decision 5.
  Future<List<String>> _matchingLureVariantIds(String normalizedQuery) async {
    final pattern = '%${_escapeLikePattern(normalizedQuery)}%';
    final query =
        _database.select(_database.lureVariants).join([
          innerJoin(
            _database.lureModels,
            _database.lureModels.id.equalsExp(
              _database.lureVariants.lureModelId,
            ),
          ),
        ])..where(
          _database.lureModels.searchText.like(
                pattern,
                escapeChar: _likeEscapeChar,
              ) |
              _database.lureVariants.searchText.like(
                pattern,
                escapeChar: _likeEscapeChar,
              ),
        );
    final rows = await query.get();
    return [for (final row in rows) row.readTable(_database.lureVariants).id];
  }

  CatchSearchResult _resultFromRow(TypedResult row) {
    final variantRow = row.readTableOrNull(_database.lureVariants);
    final modelRow = row.readTableOrNull(_database.lureModels);

    return CatchSearchResult(
      catchModel: _catchMapper.toDomain(row.readTable(_database.catches)),
      fishingSpot: row.readTable(_database.fishingSpots).toDomain(),
      waterBody: row.readTable(_database.waterBodies).toDomain(),
      lure: (variantRow != null && modelRow != null)
          ? _lureCatalogMapper.entryFromRows(
              variantRow: variantRow,
              modelRow: modelRow,
            )
          : null,
    );
  }

  /// Escapes `%`, `_`, and the escape character itself, so a query
  /// containing those characters is matched literally. Mirrors
  /// `LureCatalogRepository`'s own private helper of the same shape (not
  /// shared — see this class's own doc comment).
  String _escapeLikePattern(String input) {
    return input
        .replaceAll(_likeEscapeChar, '$_likeEscapeChar$_likeEscapeChar')
        .replaceAll('%', '$_likeEscapeChar%')
        .replaceAll('_', '${_likeEscapeChar}_');
  }
}
