import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_mapper.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_search_text.dart';
import 'package:fishing_app/features/lure_catalog/data/local/lure_catalog_seed_data.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_model.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';

/// Concrete, read-only repository for the shared Lure Catalog.
///
/// Owns the join between `LureModels`/`LureVariants`, search/filter/sort,
/// and versioned seed reconciliation. Exposes no create/update/delete
/// operation — the catalog is shared product data, not user-owned data.
/// See MFS-015 / TD-015.
class LureCatalogRepository {
  LureCatalogRepository(
    this._database, [
    this._mapper = const LureCatalogMapper(),
  ]);

  final AppDatabase _database;
  final LureCatalogMapper _mapper;

  /// Reconciles the local catalog with the compiled-in seed data:
  /// - inserts any seed id with no existing row
  /// - corrects any still seed-owned row whose stored `seedVersion` is
  ///   behind [currentLureCatalogSeedVersion]
  /// - never touches a row whose stored `seedVersion` is `null` (owned by
  ///   something other than this seed process, e.g. a future server sync)
  /// - retires (never deletes) a still seed-owned variant whose id is no
  ///   longer present in the current seed source
  /// - clears `retiredAt` for a variant that has reappeared in the current
  ///   seed source
  ///
  /// Idempotent: after a successful reconciliation at a given seed version,
  /// calling this again performs no writes. Must be called before the first
  /// [browse]/[getEntryById] call each time the catalog is opened; it is not
  /// called at application startup.
  Future<void> ensureSeeded() async {
    await _database.transaction(() async {
      for (final model in lureCatalogSeedModels) {
        await _reconcileModel(model);
      }
      for (final variant in lureCatalogSeedVariants) {
        await _reconcileVariant(variant);
      }
      final stillPresentIds = {
        for (final variant in lureCatalogSeedVariants) variant.id,
      };
      await _retireRemovedVariants(stillPresentIds: stillPresentIds);
    });
  }

  Future<void> _reconcileModel(LureModel model) async {
    final existing = await (_database.select(
      _database.lureModels,
    )..where((t) => t.id.equals(model.id))).getSingleOrNull();

    final companion = _mapper.modelToCompanion(
      model,
      seedVersion: currentLureCatalogSeedVersion,
      searchText: buildLureModelSearchText(model),
    );

    if (existing == null) {
      await _database.into(_database.lureModels).insert(companion);
      return;
    }

    // A null seedVersion means something other than this seed process now
    // owns the row (e.g. a future server sync) — never touch it.
    final storedSeedVersion = existing.seedVersion;
    if (storedSeedVersion == null ||
        storedSeedVersion >= currentLureCatalogSeedVersion) {
      return;
    }

    await (_database.update(
      _database.lureModels,
    )..where((t) => t.id.equals(model.id))).write(
      companion.copyWith(
        createdAt: Value(existing.createdAt),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> _reconcileVariant(LureVariant variant) async {
    final existing = await (_database.select(
      _database.lureVariants,
    )..where((t) => t.id.equals(variant.id))).getSingleOrNull();

    final companion = _mapper.variantToCompanion(
      variant,
      seedVersion: currentLureCatalogSeedVersion,
      searchText: buildLureVariantSearchText(variant),
    );

    if (existing == null) {
      await _database.into(_database.lureVariants).insert(companion);
      return;
    }

    final storedSeedVersion = existing.seedVersion;
    if (storedSeedVersion == null) {
      return;
    }
    if (storedSeedVersion >= currentLureCatalogSeedVersion &&
        existing.retiredAt == null) {
      return;
    }

    // Reconciling a variant that is present in the current seed source
    // always clears retiredAt: it is, by definition, no longer retired.
    await (_database.update(
      _database.lureVariants,
    )..where((t) => t.id.equals(variant.id))).write(
      companion.copyWith(
        createdAt: Value(existing.createdAt),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> _retireRemovedVariants({
    required Set<String> stillPresentIds,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ownedRows = await (_database.select(
      _database.lureVariants,
    )..where((t) => t.seedVersion.isNotNull() & t.retiredAt.isNull())).get();

    for (final row in ownedRows) {
      if (!stillPresentIds.contains(row.id)) {
        await (_database.update(_database.lureVariants)
              ..where((t) => t.id.equals(row.id)))
            .write(LureVariantsCompanion(retiredAt: Value(now)));
      }
    }
  }

  /// Browses the catalog, optionally narrowed by [searchText] (matched
  /// case-insensitively, including Finnish `ä`/`ö`, against manufacturer,
  /// product family, model name, variant name, color name, and manufacturer
  /// color code) and/or an exact [manufacturer]/[lureType]. Retired variants
  /// are excluded.
  Future<List<LureCatalogEntry>> browse({
    String? searchText,
    String? manufacturer,
    String? lureType,
  }) async {
    final query = _database.select(_database.lureVariants).join([
      innerJoin(
        _database.lureModels,
        _database.lureModels.id.equalsExp(_database.lureVariants.lureModelId),
      ),
    ])..where(_database.lureVariants.retiredAt.isNull());

    final normalizedSearch = searchText?.trim().toLowerCase();
    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      final pattern = '%${_escapeLikePattern(normalizedSearch)}%';
      query.where(
        _database.lureModels.searchText.like(
              pattern,
              escapeChar: _likeEscapeChar,
            ) |
            _database.lureVariants.searchText.like(
              pattern,
              escapeChar: _likeEscapeChar,
            ),
      );
    }
    if (manufacturer != null) {
      query.where(_database.lureModels.manufacturer.equals(manufacturer));
    }
    if (lureType != null) {
      query.where(_database.lureModels.lureType.equals(lureType));
    }

    query.orderBy([
      OrderingTerm(
        expression: _database.lureModels.manufacturer.collate(Collate.noCase),
      ),
      OrderingTerm(
        expression: _database.lureModels.modelName.collate(Collate.noCase),
      ),
      OrderingTerm(expression: _database.lureVariants.id),
    ]);

    final rows = await query.get();
    return [
      for (final row in rows)
        _mapper.entryFromRows(
          variantRow: row.readTable(_database.lureVariants),
          modelRow: row.readTable(_database.lureModels),
        ),
    ];
  }

  /// Returns every non-retired variant belonging to [lureModelId], ordered
  /// by variant id (matching [browse]'s own tertiary sort). Unaffected by
  /// any search text or filter — always the model's complete variant set.
  ///
  /// Added during MFS-018/TD-018 implementation: [browse]'s search filter
  /// matches at the individual variant row, so a search/filter-narrowed
  /// `browse()` result cannot be relied on to already contain every variant
  /// of a matched model in memory. `LureModelDetailsPage` requires the
  /// complete set regardless of what search/filter surfaced the model
  /// (MFS-018 FR-6), so its caller queries this method once, at open time,
  /// instead. See TD-018's Implementation Notes.
  Future<List<LureVariant>> getVariantsForModel(String lureModelId) async {
    final query = _database.select(_database.lureVariants)
      ..where((t) => t.lureModelId.equals(lureModelId) & t.retiredAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.id)]);
    final rows = await query.get();
    return [for (final row in rows) _mapper.variantFromRow(row)];
  }

  /// Looks up a single catalog entry by variant id. Deliberately does not
  /// filter on `retiredAt`: a future reference to a retired variant
  /// (Personal Tackle Box, Assign Lure to Catch) must still resolve.
  Future<LureCatalogEntry?> getEntryById(String variantId) async {
    final query = _database.select(_database.lureVariants).join([
      innerJoin(
        _database.lureModels,
        _database.lureModels.id.equalsExp(_database.lureVariants.lureModelId),
      ),
    ])..where(_database.lureVariants.id.equals(variantId));

    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapper.entryFromRows(
      variantRow: row.readTable(_database.lureVariants),
      modelRow: row.readTable(_database.lureModels),
    );
  }

  /// Manufacturers with at least one non-retired variant. A manufacturer
  /// whose every variant has been retired is not a usable filter option, so
  /// it is excluded here even though its `LureModels` rows still exist.
  Future<List<String>> getDistinctManufacturers() async {
    final query = _database.selectOnly(_database.lureModels, distinct: true)
      ..addColumns([_database.lureModels.manufacturer])
      ..join([
        innerJoin(
          _database.lureVariants,
          _database.lureVariants.lureModelId.equalsExp(_database.lureModels.id),
        ),
      ])
      ..where(_database.lureVariants.retiredAt.isNull())
      ..orderBy([
        OrderingTerm(
          expression: _database.lureModels.manufacturer.collate(Collate.noCase),
        ),
      ]);
    final rows = await query.get();
    return [
      for (final row in rows) row.read(_database.lureModels.manufacturer)!,
    ];
  }

  /// Lure types with at least one non-retired variant. See
  /// [getDistinctManufacturers] for why fully-retired groups are excluded.
  Future<List<String>> getDistinctLureTypes() async {
    final query = _database.selectOnly(_database.lureModels, distinct: true)
      ..addColumns([_database.lureModels.lureType])
      ..join([
        innerJoin(
          _database.lureVariants,
          _database.lureVariants.lureModelId.equalsExp(_database.lureModels.id),
        ),
      ])
      ..where(_database.lureVariants.retiredAt.isNull())
      ..orderBy([OrderingTerm(expression: _database.lureModels.lureType)]);
    final rows = await query.get();
    return [for (final row in rows) row.read(_database.lureModels.lureType)!];
  }
}

/// The `ESCAPE` character used in [LureCatalogRepository.browse]'s `LIKE`
/// patterns. Chosen because it cannot appear in a normalized (lowercased)
/// search term produced by user input through the search field.
const String _likeEscapeChar = r'\';

/// Escapes SQL `LIKE` metacharacters (`%`, `_`) and the escape character
/// itself in [input] so that free-text search treats them as literal
/// characters rather than wildcards. Must be paired with
/// `like(pattern, escapeChar: _likeEscapeChar)`.
String _escapeLikePattern(String input) {
  return input
      .replaceAll(_likeEscapeChar, '$_likeEscapeChar$_likeEscapeChar')
      .replaceAll('%', '$_likeEscapeChar%')
      .replaceAll('_', '${_likeEscapeChar}_');
}
