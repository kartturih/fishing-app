import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_asset_loader.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_mapper.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_search_text.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_version_store.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_model.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';

/// Concrete, read-only repository for the shared Lure Catalog.
///
/// Owns the join between `LureModels`/`LureVariants`, search/filter/sort,
/// and versioned catalog-content reconciliation. Exposes no create/update/
/// delete operation — the catalog is shared product data, not user-owned
/// data. See MFS-015 / TD-015, MFS-028 / TD-028.
class LureCatalogRepository {
  LureCatalogRepository(
    this._database, [
    this._mapper = const LureCatalogMapper(),
  ]);

  final AppDatabase _database;
  final LureCatalogMapper _mapper;

  /// Reconciles the local catalog with the bundled, generated catalog asset
  /// (`assets/lure_catalog/catalog_v1.json`, loaded via [assetLoader] and
  /// produced by `tools/lure_catalog/build_catalog.py` from the
  /// manufacturer authoring files under `assets/lure_catalog/source/` — see
  /// TD-028):
  /// - inserts any catalog id with no existing row
  /// - corrects any still catalog-owned row whose stored `seedVersion` is
  ///   behind the asset's `catalogVersion`
  /// - never touches a row whose stored `seedVersion` is `null` (owned by
  ///   something other than this reconciliation process, e.g. a future
  ///   server sync)
  /// - retires (never deletes) a still catalog-owned variant whose id is no
  ///   longer present in the current catalog asset
  /// - clears `retiredAt` for a variant that has reappeared in the current
  ///   catalog asset
  ///
  /// Idempotent: after a successful reconciliation at a given catalog
  /// version, calling this again performs no writes — [versionStore]
  /// short-circuits the common case entirely (a pure performance fast-path,
  /// never a correctness dependency: the per-row `seedVersion` check inside
  /// the transaction below is still what actually decides correctness, any
  /// time a full pass does run). Must be called before the first
  /// [browse]/[getEntryById] call each time the catalog is opened; it is not
  /// called at application startup.
  Future<void> ensureSeeded({
    LureCatalogAssetLoader assetLoader = const LureCatalogAssetLoader(),
    LureCatalogVersionStore versionStore = const LureCatalogVersionStore(),
  }) async {
    final parsed = await assetLoader.load();

    final lastReconciled = await versionStore.loadLastReconciledVersion();
    if (lastReconciled != null && lastReconciled >= parsed.catalogVersion) {
      return;
    }

    await _database.transaction(() async {
      final existingModels = await _loadAllExistingModels();
      final existingVariants = await _loadAllExistingVariants();

      final modelPlan = _planModelWrites(
        parsedModels: parsed.models,
        existingModels: existingModels,
        catalogVersion: parsed.catalogVersion,
      );
      final variantPlan = _planVariantWrites(
        parsedVariants: parsed.variants,
        existingVariants: existingVariants,
        catalogVersion: parsed.catalogVersion,
      );
      final stillPresentIds = {
        for (final variant in parsed.variants) variant.id,
      };
      final retirements = _planVariantRetirements(
        existingVariants: existingVariants,
        stillPresentIds: stillPresentIds,
      );

      await _applyReconciliationPlan(
        modelInserts: modelPlan.inserts,
        modelUpdates: modelPlan.updates,
        variantInserts: variantPlan.inserts,
        variantUpdates: variantPlan.updates,
        variantRetirements: retirements,
      );
    });

    await versionStore.saveLastReconciledVersion(parsed.catalogVersion);
  }

  /// Loads every existing `LureModels` row in one query, keyed by id, so
  /// reconciliation never issues one `SELECT` per catalog entry. See
  /// TD-028 Section 7/Section 10.
  Future<Map<String, LureModelEntity>> _loadAllExistingModels() async {
    final rows = await _database.select(_database.lureModels).get();
    return {for (final row in rows) row.id: row};
  }

  /// Loads every existing `LureVariants` row in one query, keyed by id.
  /// Unlike [_loadAllExistingModels], this deliberately loads *all* rows,
  /// not only ones matching the new catalog content's ids: retirement
  /// detection needs to see every existing catalog-owned row to notice
  /// which ones are no longer present in the new content, not merely
  /// resolve the ones that still are.
  Future<Map<String, LureVariantEntity>> _loadAllExistingVariants() async {
    final rows = await _database.select(_database.lureVariants).get();
    return {for (final row in rows) row.id: row};
  }

  /// Pure planning, no I/O: decides, for every model in [parsedModels],
  /// whether it needs to be inserted, corrected in place, or left
  /// untouched — never touching a row whose stored `seedVersion` is `null`
  /// (owned by something other than this reconciliation process). See
  /// TD-028 Section 8.
  ({List<LureModelsCompanion> inserts, List<(String, LureModelsCompanion)> updates})
  _planModelWrites({
    required List<LureModel> parsedModels,
    required Map<String, LureModelEntity> existingModels,
    required int catalogVersion,
  }) {
    final inserts = <LureModelsCompanion>[];
    final updates = <(String, LureModelsCompanion)>[];

    for (final model in parsedModels) {
      final companion = _mapper.modelToCompanion(
        model,
        seedVersion: catalogVersion,
        searchText: buildLureModelSearchText(model),
      );
      final existing = existingModels[model.id];
      if (existing == null) {
        inserts.add(companion);
        continue;
      }
      final storedSeedVersion = existing.seedVersion;
      if (storedSeedVersion == null || storedSeedVersion >= catalogVersion) {
        continue;
      }
      updates.add((
        model.id,
        companion.copyWith(
          createdAt: Value(existing.createdAt),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      ));
    }

    return (inserts: inserts, updates: updates);
  }

  /// Pure planning, no I/O: the variant equivalent of [_planModelWrites].
  /// Also proceeds (rather than skipping) when a variant is already at the
  /// current `catalogVersion` but still `retiredAt`-set, since reappearing
  /// in the current catalog content always clears retirement — see
  /// [LureCatalogMapper.variantToCompanion].
  ({List<LureVariantsCompanion> inserts, List<(String, LureVariantsCompanion)> updates})
  _planVariantWrites({
    required List<LureVariant> parsedVariants,
    required Map<String, LureVariantEntity> existingVariants,
    required int catalogVersion,
  }) {
    final inserts = <LureVariantsCompanion>[];
    final updates = <(String, LureVariantsCompanion)>[];

    for (final variant in parsedVariants) {
      final companion = _mapper.variantToCompanion(
        variant,
        seedVersion: catalogVersion,
        searchText: buildLureVariantSearchText(variant),
      );
      final existing = existingVariants[variant.id];
      if (existing == null) {
        inserts.add(companion);
        continue;
      }
      final storedSeedVersion = existing.seedVersion;
      if (storedSeedVersion == null) {
        continue;
      }
      if (storedSeedVersion >= catalogVersion && existing.retiredAt == null) {
        continue;
      }
      updates.add((
        variant.id,
        companion.copyWith(
          createdAt: Value(existing.createdAt),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      ));
    }

    return (inserts: inserts, updates: updates);
  }

  /// Pure planning, no I/O: every existing catalog-owned, currently-active
  /// variant row whose id is no longer present in the parsed catalog —
  /// retired (never deleted) by [_applyReconciliationPlan]. Materialized
  /// eagerly to a `List` (not left as a lazy `Iterable`) so a caller can
  /// check emptiness and then iterate without evaluating the filter twice.
  List<LureVariantEntity> _planVariantRetirements({
    required Map<String, LureVariantEntity> existingVariants,
    required Set<String> stillPresentIds,
  }) {
    return existingVariants.values
        .where(
          (row) =>
              row.seedVersion != null &&
              row.retiredAt == null &&
              !stillPresentIds.contains(row.id),
        )
        .toList(growable: false);
  }

  /// Applies a previously computed plan as one batch, inside the caller's
  /// already-open transaction — the only place `ensureSeeded()` actually
  /// writes. A plan with nothing to do performs zero database calls.
  Future<void> _applyReconciliationPlan({
    required List<LureModelsCompanion> modelInserts,
    required List<(String, LureModelsCompanion)> modelUpdates,
    required List<LureVariantsCompanion> variantInserts,
    required List<(String, LureVariantsCompanion)> variantUpdates,
    required List<LureVariantEntity> variantRetirements,
  }) async {
    final hasWrites =
        modelInserts.isNotEmpty ||
        modelUpdates.isNotEmpty ||
        variantInserts.isNotEmpty ||
        variantUpdates.isNotEmpty ||
        variantRetirements.isNotEmpty;
    if (!hasWrites) {
      return;
    }

    final retireNow = DateTime.now().millisecondsSinceEpoch;
    await _database.batch((batch) {
      if (modelInserts.isNotEmpty) {
        batch.insertAll(_database.lureModels, modelInserts);
      }
      for (final (id, companion) in modelUpdates) {
        batch.update(
          _database.lureModels,
          companion,
          where: (t) => t.id.equals(id),
        );
      }
      if (variantInserts.isNotEmpty) {
        batch.insertAll(_database.lureVariants, variantInserts);
      }
      for (final (id, companion) in variantUpdates) {
        batch.update(
          _database.lureVariants,
          companion,
          where: (t) => t.id.equals(id),
        );
      }
      for (final row in variantRetirements) {
        batch.update(
          _database.lureVariants,
          LureVariantsCompanion(retiredAt: Value(retireNow)),
          where: (t) => t.id.equals(row.id),
        );
      }
    });
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
