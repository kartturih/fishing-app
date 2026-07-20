import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_mapper.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/statistics/domain/lure_catch_statistic.dart';
import 'package:fishing_app/features/statistics/domain/lure_distinguishing_detail.dart';
import 'package:fishing_app/features/statistics/domain/lure_statistics_summary.dart';
import 'package:fishing_app/features/statistics/domain/lure_type_catch_statistic.dart';

/// Concrete, read-only repository computing lure-based catch statistics live
/// from existing `Catches`/`LureVariants`/`LureModels` data.
///
/// Performs its own join directly against those tables (reusing
/// `lure_catalog`'s already-public `LureCatalogMapper.entryFromRows()` for
/// the catalog portion), exactly like `PersonalTackleBoxRepository`'s
/// established precedent — never through `CatchRepository` or
/// `LureCatalogRepository`'s instance methods. Never reads
/// `TackleBoxEntries`: statistics reflect catch history, not current
/// tackle box membership. See MFS-019 / TD-019.
class LureStatisticsRepository {
  LureStatisticsRepository(
    this._database, [
    this._catalogMapper = const LureCatalogMapper(),
  ]);

  final AppDatabase _database;
  final LureCatalogMapper _catalogMapper;

  /// Computes the full summary fresh — nothing is cached or stored. See
  /// MFS-019 FR-8.
  Future<LureStatisticsSummary> getLureStatistics() async {
    final totalCatchesLinkedToLure = await _countCatchesWithLure();
    final rows = await _resolvableCatchLureRows();

    final variantCounts = <String, _MutableLureCount>{};
    final typeCounts = <String, int>{};

    for (final row in rows) {
      final entry = _catalogMapper.entryFromRows(
        variantRow: row.readTable(_database.lureVariants),
        modelRow: row.readTable(_database.lureModels),
      );
      variantCounts
          .putIfAbsent(entry.id, () => _MutableLureCount(entry))
          .increment();
      typeCounts.update(
        entry.lureType,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final lures = [
      for (final counted in variantCounts.values)
        LureCatchStatistic(lure: counted.lure, catchCount: counted.count),
    ]..sort(_compareLureStatistics);

    final lureTypeBreakdown = [
      for (final entry in typeCounts.entries)
        LureTypeCatchStatistic(lureType: entry.key, catchCount: entry.value),
    ]..sort(_compareLureTypeStatistics);

    return LureStatisticsSummary(
      totalCatchesLinkedToLure: totalCatchesLinkedToLure,
      lures: lures,
      lureTypeBreakdown: lureTypeBreakdown,
    );
  }

  /// Every catch with a non-null assigned lure, whether or not that
  /// reference currently resolves. See MFS-019 FR-3.
  Future<int> _countCatchesWithLure() async {
    final query = _database.selectOnly(_database.catches)
      ..addColumns([_database.catches.id.count()])
      ..where(_database.catches.lureVariantId.isNotNull());
    final row = await query.getSingle();
    return row.read(_database.catches.id.count()) ?? 0;
  }

  /// One row per catch whose assigned lure resolves. The `innerJoin`
  /// naturally excludes both a null `lureVariantId` and any (structurally
  /// prevented by the `restrict` foreign key, TD-017) unresolvable
  /// reference — no extra `WHERE` clause is needed. Never filters on
  /// `LureVariants.retiredAt`: a retired variant is counted identically to
  /// an active one (MFS-019 FR-11).
  Future<List<TypedResult>> _resolvableCatchLureRows() {
    final query = _database.select(_database.catches).join([
      innerJoin(
        _database.lureVariants,
        _database.lureVariants.id.equalsExp(_database.catches.lureVariantId),
      ),
      innerJoin(
        _database.lureModels,
        _database.lureModels.id.equalsExp(_database.lureVariants.lureModelId),
      ),
    ]);
    return query.get();
  }
}

class _MutableLureCount {
  _MutableLureCount(this.lure);

  final LureCatalogEntry lure;
  int count = 0;

  void increment() => count++;
}

/// Sorts by catch count descending; ties broken deterministically by
/// manufacturer, then model name, then distinguishing detail, then the
/// variant id itself as a guaranteed-unique final tiebreak. Applied
/// unconditionally — Dart's `List.sort` is not guaranteed stable.
int _compareLureStatistics(LureCatchStatistic a, LureCatchStatistic b) {
  final byCount = b.catchCount.compareTo(a.catchCount);
  if (byCount != 0) return byCount;
  final byManufacturer = a.lure.manufacturer.toLowerCase().compareTo(
    b.lure.manufacturer.toLowerCase(),
  );
  if (byManufacturer != 0) return byManufacturer;
  final byModel = a.lure.modelName.toLowerCase().compareTo(
    b.lure.modelName.toLowerCase(),
  );
  if (byModel != 0) return byModel;
  final byDetail = lureDistinguishingDetail(
    a.lure,
  ).toLowerCase().compareTo(lureDistinguishingDetail(b.lure).toLowerCase());
  if (byDetail != 0) return byDetail;
  return a.lure.id.compareTo(b.lure.id); // guaranteed-unique final tiebreak
}

/// Sorts by catch count descending; ties broken by lure type code ascending
/// (already unique per map key, so no further tiebreak is needed).
int _compareLureTypeStatistics(
  LureTypeCatchStatistic a,
  LureTypeCatchStatistic b,
) {
  final byCount = b.catchCount.compareTo(a.catchCount);
  if (byCount != 0) return byCount;
  return a.lureType.compareTo(b.lureType);
}
