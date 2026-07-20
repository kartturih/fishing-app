# TD-019 — Lure-Based Catch Statistics

## Status

Draft

## Related Specification

* MFS-019: Lure-Based Catch Statistics

---

## Goal

Implement the new **Statistics** feature and its first tab, **Lure Statistics** — three summary cards, a per-lure catch-count list, and a per-lure-type catch-count breakdown, all computed live from existing `Catch`, `LureVariant`, and `LureModel` data — fully satisfying MFS-019, with no new database table, no schema migration, and no change to the `catches`, `lure_catalog`, or `personal_tackle_box` features.

The implementation shall satisfy MFS-019.

---

## Scope

Implement:

* a new `statistics` feature directory, owning no Drift table
* three read-only domain/read-model types: a lure paired with its catch count, a lure type paired with its catch count, and a summary aggregate wrapping both plus the total-linked-catches count
* a concrete, feature-owned `LureStatisticsRepository` computing all of the above from two plain, read-only queries against the existing `Catches`, `LureVariants`, and `LureModels` tables
* deterministic tie-breaking for "most successful lure" and "most successful lure type", per MFS-019's Conceptual Model
* a tabbed `StatisticsPage` shell (one tab in this milestone: Lure Statistics), consistent with the tab-shell precedent already established by `LureToolsPage` (TD-016)
* the Lure Statistics tab: summary cards, lure list, lure type breakdown
* loading, empty, and error states
* a new, temporary `MapScreen` `AppBar` entry point, following the exact pattern TD-015/TD-016/TD-018 already established
* accessibility labeling
* tests

Do **not** implement:

* any new Drift table, column, or schema migration
* any cached, stored, or persisted statistic of any kind
* graphs, charts, filters, percentages, averages, biggest fish, seasonal/time-based/water/weather statistics, export, or comparison features (MFS-019 Out of Scope)
* a second Statistics tab (e.g. General Catch / Fishing Statistics)
* any change to `catches`, `lure_catalog`, or `personal_tackle_box`'s domain models, tables, repositories, or read-only/reference-only guarantees
* background computation of any kind — statistics are computed synchronously, on demand, when the tab is opened
* sync logic of any kind
* Riverpod, repository interfaces, DAO/service/use-case layers, reactive database streams (`watch()`)

---

## Key Design Decisions

This section answers the questions most likely to be raised in review, before the detailed sections implement them.

**1. `LureStatisticsRepository` performs its own two-table-plus-catches join, exactly like `PersonalTackleBoxRepository`'s established precedent — it does not call `CatchRepository` or `LureCatalogRepository`'s instance methods.** This is precisely the design TD-017's Key Design Decision 2 anticipated and explicitly deferred: *"If a future milestone needs to resolve assigned lures for a collection of catches at once (Lure-Based Catch Statistics, ...), it must not be built by calling `getEntryById()` in a loop... Such a future milestone should design a dedicated bulk-resolution query (e.g. a join or a batched lookup...), the same way `PersonalTackleBoxRepository.getAll()` already does."* This document implements exactly that. `LureStatisticsRepository` reads `Catches`, `LureVariants`, and `LureModels` directly, reusing `lure_catalog`'s already-public `LureCatalogMapper.entryFromRows()` for the catalog portion (the same reuse TD-016 already established for `PersonalTackleBoxRepository`). No method on `CatchRepository` or `LureCatalogRepository` is added, changed, or called.

**2. Two plain queries, not one complex query — and no SQL `GROUP BY`.** MFS-019 FR-3 requires the *total* count of catches with a non-null `lureVariantId`, including any that are structurally unresolvable (see Key Design Decision 3), while FR-6/FR-7 require *per-lure* and *per-lure-type* breakdowns computed only from the *resolvable* subset. One query (`selectOnly` + `count()`) answers the first; a second query (a plain three-table inner join, no aggregation) returns one row per resolvable catch, which is then grouped and counted in Dart. This mirrors the exact "no `GROUP BY`, single in-memory pass" precedent already established twice in this codebase (TD-016 Key Design Decision 3 for tackle box grouping; TD-018 Key Design Decision 1 for model grouping).

**Architectural rationale, stated explicitly** (per architecture review — this is a documentation clarification, not a new decision):

- **Dataset size:** a single user's own catch history is small (tens to low hundreds of rows), never the shared-catalog scale (MFS-015's own "thousands of variants" ceiling). An in-memory count carries no realistic performance risk at this scale.
- **Simplicity:** two plain `select`/`selectOnly` queries plus a `Map`-based count are less code, and less Drift query-builder surface, than composing an aggregate `GROUP BY` join — there is no aggregate-expression syntax to get right, review, or later re-verify against Drift's SQL generation.
- **Readability:** the aggregation is ordinary Dart control flow (a loop, then a sort). A reviewer or future maintainer verifies it by reading one language, not by mentally cross-checking SQL `GROUP BY`/join semantics against a separate Dart post-processing step.
- **Testability:** repository tests assert directly against `LureStatisticsSummary`'s plain Dart fields (see [§11](#11-testing-strategy)). There is no separate SQL aggregate expression whose correctness must be verified against SQLite's own grouping/counting semantics — the whole computation is exercised the same way any other Dart function would be.
- **Sufficiency for this application's model:** Fishing App is offline-first, single-user, and single-device (ADR-0001) — there is no concurrent access, multi-user contention, or server-side aggregation scenario this design needs to anticipate. The entire computation always runs locally, once per tab open, over one person's own data.

Taken together, this is the correct-scale choice, not a shortcut: a SQL `GROUP BY` would be more machinery than this data volume or this application's usage pattern ever calls for.

**3. The catalog join is a plain `innerJoin`, which structurally does two things at once: excludes catches with no assigned lure, and excludes any (expected-never-to-occur) unresolvable reference.** `Catches.lureVariantId → LureVariants.id` already carries a `KeyAction.restrict` foreign key (TD-017), so a dangling reference cannot arise through any code path this application exposes. An `innerJoin` on `LureVariants.id.equalsExp(Catches.lureVariantId)` naturally matches nothing when `lureVariantId` is `null` (SQL `NULL` never equals anything) and naturally matches nothing if the id somehow does not resolve — both cases fall out of ordinary `INNER JOIN` semantics, with no extra `WHERE lureVariantId IS NOT NULL` clause needed on this second query. This is exactly the outcome MFS-019 FR-10 requires (an unresolvable reference is excluded from the lure list/lure-type breakdown) and MFS-019 FR-9's "historical stability" requires implicitly (nothing here ever reads `TackleBoxEntries` at all — see Key Design Decision 6).

**4. Tie-breaking is fully deterministic and owned entirely by this document, per MFS-019's explicit deferral.** "Most successful lure" ties are broken by manufacturer, then model name, then distinguishing color/variant detail (all case-insensitive ascending), then, as a final guaranteed-unique tiebreak, `LureVariant.id` ascending. "Most successful lure type" ties are broken by the lure type code ascending (already unique per group, so no further tiebreak is needed). Both comparators are applied unconditionally — not only when a tie is detected — so `List.sort`'s lack of a stability guarantee in Dart can never produce a different order for the same underlying data. See [§4](#4-data-layer).

**5. "Most successful lure" and "most successful lure type" are derived getters on the summary read-model, not separately queried or stored.** Both are simply the first element of the already-sorted `lures`/`lureTypeBreakdown` lists (`null` when empty). This avoids computing the same ranking twice and avoids a fourth domain type — the summary card is a view over data the lists already carry, exactly as MFS-019's Conceptual Model frames it ("This is the top-ranked entry of the list...").

**6. Nothing in this feature reads `TackleBoxEntries` or depends on `PersonalTackleBoxRepository`.** MFS-019's Conceptual Model resolves that statistics are computed from catch history (`Catch.lureVariantId`), not from current tackle box membership. Concretely, this means `LureStatisticsRepository` has no dependency on `personal_tackle_box` at all — not its repository, not its table. This makes MFS-019 FR-9 (statistics survive a `TackleBoxEntry` removal) true by construction rather than by any explicit check: there is nothing in this feature's query that could be affected by a `TackleBoxEntries` row disappearing.

**7. `StatisticsPage` is a `TabBar`/`TabBarView` shell with exactly one tab, because MFS-019 FR-2 requires that shape as a stated product requirement — not a speculative addition.** This mirrors `LureToolsPage`'s shell shape (TD-016) at the widget level, but unlike `LureToolsPage` — which exists specifically as the one place two otherwise-independent features (`lure_catalog`, `personal_tackle_box`) are allowed to meet — `StatisticsPage` and its tab(s) all belong to the same feature (`statistics`), since a future second tab (General Catch / Fishing Statistics, `docs/roadmap.md` §3.3) would also be a `statistics`-owned concern. `StatisticsPage` therefore lives inside `lib/features/statistics/presentation/`, not inside `map/`, unlike `LureToolsPage`.

**8. `LureStatisticsTab`'s `State` is deliberately not kept alive across tab switches (no `AutomaticKeepAliveClientMixin`).** Reaffirmed after architecture review, with the fuller reasoning below (this is a documentation clarification of an already-correct decision, not a design change).

**Why disposal is preferred over an explicit refresh.** The product requirement (MFS-019's UI Expectations) is that statistics are recomputed whenever the tab becomes visible — not that any particular widget instance survives between visits. Flutter's default, un-kept-alive `TabBarView` behavior already delivers exactly that: disposing `LureStatisticsTab`'s `State` when it scrolls off-screen and constructing a brand new one (running `initState` → `getLureStatistics()`) when it scrolls back on — with zero extra code. An explicit-refresh design would have to *re-implement*, by hand, the one thing disposal already gives for free: detecting "this tab just became visible again" (via a `TabController` listener comparing the previous and current index, or an `AutomaticKeepAliveClientMixin` combined with a `RouteObserver`/visibility callback) and triggering a reload from that hook instead of from `initState`. That is strictly more code, doing the same job disposal already does correctly, for a screen that has no state worth preserving in the first place (see below). Preferring disposal here is the same "don't build a mechanism you don't need" judgment this project's Development Rules already ask for ("Avoid premature abstractions," "Keep implementations simple"), not a default reached without considering the alternative.

**Would a kept-alive page with an explicit refresh-on-resume produce the same product behavior with less widget reconstruction?** In principle, yes — the *product-visible* outcome (fresh numbers shown each time the tab is revisited) is achievable either way, and a kept-alive page would avoid rebuilding the summary cards and list rows from scratch on every revisit. In practice, that saved reconstruction cost is not worth what it would cost to obtain, for two reasons specific to this screen:

- The two SQL queries plus the Dart aggregation pass ([§4](#4-data-layer), [§10](#10-performance-considerations)) dominate the total latency of a reload, not the cost of rebuilding a handful of `Card`/`Row` widgets over a list bounded to a single user's own catch history (tens to low hundreds of rows). Keeping the widget tree alive would shave a small, already-cheap fraction of the work; the expensive part (re-querying and re-aggregating) still has to happen every time regardless, because MFS-019 FR-8 forbids caching the *result*, only the *widget instance* — so a kept-alive page still refetches from scratch on every visibility change, it just also carries the overhead of the keep-alive machinery to trigger that refetch correctly.
- A kept-alive page would, for a brief moment on every revisit, show the *previous* visit's numbers while the new query runs (unless it is explicitly coded to clear its state first, in which case it has recreated the disposal behavior's own visible loading state anyway, just with more code). MFS-019 does not ask for a no-flicker/stale-then-swap refresh experience — an explicit, momentary loading indicator on every open (what disposal already produces) is a perfectly acceptable, arguably clearer signal that the numbers are being freshly computed, consistent with how every other data-loading screen in this application already behaves (`PersonalTackleBoxPage`, `CatchDetailsPage`'s lure resolution) — none of which use `AutomaticKeepAliveClientMixin` either.

**Drawbacks of `AutomaticKeepAliveClientMixin` here.** Its actual, intended benefit — established by its one existing use in this codebase, `LureCatalogListPage` (TD-018) — is *preserving user-entered state* (search text, filter selections, scroll position) that would be annoying for a user to lose. `LureStatisticsTab` has no equivalent state: no search field, no filter, nothing the user has typed or chosen that a rebuild would discard. The only thing a kept-alive `LureStatisticsTab` would actually be preserving is the *previously computed statistics themselves* — which is precisely the caching MFS-019 FR-8 ("Computed Live, Never Stored") rules out. Adopting the mixin here would therefore mean carrying its complexity (the `wantKeepAlive` override, the mandatory `super.build(context)` call, and — to still satisfy "recompute on revisit" — a hand-rolled visibility-change listener with its own edge cases: guarding against a double-load if both `initState` and the listener fire, and cancelling/ignoring a superseded in-flight query if the user switches tabs again before the first one resolves) for a benefit (state preservation) this screen has nothing to preserve. That is added risk and code for no corresponding product value.

**Conclusion: the original decision stands.** Relying on `TabBarView`'s ordinary dispose/recreate behavior remains the simplest design that is *also* correct by construction — there is no separate "remember to refresh" step to get right, because there is no stale state to refresh away in the first place. Because this milestone ships only one tab, this decision is not yet exercised in practice — reopening the whole `StatisticsPage` screen already forces a fresh `initState` regardless of which choice is made here — but it is recorded in this depth so a future second tab (`docs/roadmap.md` §3.3) makes its own deliberate choice, informed by whether *that* tab ever grows user-entered state worth preserving, rather than copying TD-018's mixin, or this document's absence of it, by reflex.

**9. A single per-section empty-state mechanism serves both empty scenarios MFS-019 describes, rather than a separate whole-screen "empty" branch.** The total-catches card always renders its numeric value, including `0` — a plain count is a legitimate, unambiguous value at `0` and needs no special-casing. The two ranking cards ("most successful lure"/"most successful lure type") render an explicit "no data yet" message whenever their respective getter is `null`, since there is no meaningful zero-value lure or lure type to show. The lure list and lure type breakdown each independently render an inline empty message when their own list is empty. Because a fully-empty state (`totalCatchesLinkedToLure == 0`) and the "resolvable total with an empty breakdown" edge case (MFS-019's own explicit edge case, [FR-10](../specifications/MFS-019-lure-based-catch-statistics.md#fr-10--unresolvable-lure-references)) both reduce to "the ranking cards and lists are empty, the total may or may not be zero," one mechanism handles both — no second, whole-screen empty state is built.

---

## 1. Overview

`statistics` is a new, independent feature. It owns no Drift table and depends, read-only, on two existing features:

| Feature | Responsibility in this milestone |
|---|---|
| `statistics` (new) | Owns `LureStatisticsRepository`, the three read-model domain types, and every presentation surface (`StatisticsPage`, `LureStatisticsTab`, summary cards, list rows). |
| `catches` (unmodified) | Continues to own `Catch`/`CatchRepository`/the `Catches` table. `statistics` reads the `Catches` table directly (not through `CatchRepository`) — see [Key Design Decision 1](#key-design-decisions). |
| `lure_catalog` (unmodified) | Continues to own `LureVariant`/`LureModel`/`LureCatalogEntry`/`LureCatalogMapper`/the `LureVariants`/`LureModels` tables. `statistics` reads these tables directly and reuses the already-public `LureCatalogMapper.entryFromRows()`, exactly as `PersonalTackleBoxRepository` already does (TD-016). |
| `personal_tackle_box` (untouched) | Not read from, not depended on, at all — see [Key Design Decision 6](#key-design-decisions). |

**No new repository instances are required beyond one.** `MapScreen` already constructs `AppDatabase`. This milestone adds exactly one more manually-constructed repository, `LureStatisticsRepository(_database)`, alongside the existing `CatchRepository`/`LureCatalogRepository`/`PersonalTackleBoxRepository` instances it already holds.

---

## 2. Folder Structure

```text
lib/features/statistics/
  domain/
    lure_catch_statistic.dart
    lure_type_catch_statistic.dart
    lure_statistics_summary.dart
    lure_distinguishing_detail.dart
  data/
    lure_statistics_repository.dart
  presentation/
    widgets/
      statistics_page.dart
      lure_statistics_tab.dart
      lure_statistics_summary_card.dart
      lure_catch_statistic_row.dart
      lure_type_catch_statistic_row.dart
```

No `data/local/` (no table), no `data/lure_statistics_mapper.dart` (aggregation happens directly in the repository, reusing `LureCatalogMapper` — a dedicated mapper class would have nothing of its own to map), no `presentation/providers/`. Exact widget file separation may be adjusted if a smaller structure is clearer, consistent with the same allowance given in TD-013/TD-015/TD-016.

`lure_distinguishing_detail.dart` is a small file of pure top-level functions, mirroring `lure_catalog`'s own `lure_type_labels.dart` in shape and purpose (an open, presentation-facing derivation with no class, no state) — see [§3](#3-domain-layer).

---

## 3. Domain Layer

### LureCatchStatistic

```dart
final class LureCatchStatistic {
  const LureCatchStatistic({required this.lure, required this.catchCount})
    : assert(catchCount > 0, 'catchCount must be greater than zero');

  final LureCatalogEntry lure;
  final int catchCount;
}
```

`lure` reuses `lure_catalog`'s own `LureCatalogEntry` directly — manufacturer, model name, lure type, image resolution, and the underlying `LureVariant` are never duplicated into a `statistics`-owned type. This is the same "reference, not copy" discipline already established for `TackleBoxItem.catalogEntry` (MFS-016) and `Catch.lureVariantId` (MFS-017).

### LureTypeCatchStatistic

```dart
final class LureTypeCatchStatistic {
  const LureTypeCatchStatistic({
    required this.lureType,
    required this.catchCount,
  }) : assert(lureType != '', 'lureType must not be empty'),
       assert(catchCount > 0, 'catchCount must be greater than zero');

  final String lureType;
  final int catchCount;
}
```

`lureType` is the same open, stable string code already used by `LureModel.lureType` (MFS-015) — never a closed enum. Resolving it to a Finnish display label is a presentation concern (`lureTypeDisplayLabel`, reused unchanged from `lure_catalog`), not stored here.

### LureStatisticsSummary

```dart
final class LureStatisticsSummary {
  const LureStatisticsSummary({
    required this.totalCatchesLinkedToLure,
    required this.lures,
    required this.lureTypeBreakdown,
  }) : assert(
         totalCatchesLinkedToLure >= 0,
         'totalCatchesLinkedToLure must not be negative',
       );

  /// Every catch with a non-null assigned lure, whether or not that
  /// reference currently resolves. See MFS-019 FR-3/FR-10.
  final int totalCatchesLinkedToLure;

  /// Every lure with at least one resolvable catch, sorted by [catchCount]
  /// descending, ties broken deterministically. May be shorter than
  /// [totalCatchesLinkedToLure] implies if any catches are unresolvable.
  final List<LureCatchStatistic> lures;

  /// Every lure type with at least one resolvable catch, sorted by
  /// [catchCount] descending, ties broken deterministically.
  final List<LureTypeCatchStatistic> lureTypeBreakdown;

  LureCatchStatistic? get mostSuccessfulLure =>
      lures.isEmpty ? null : lures.first;

  LureTypeCatchStatistic? get mostSuccessfulLureType =>
      lureTypeBreakdown.isEmpty ? null : lureTypeBreakdown.first;
}
```

Per [Key Design Decision 5](#key-design-decisions), `mostSuccessfulLure`/`mostSuccessfulLureType` are plain getters over already-sorted lists — not separate fields the repository must compute or keep in sync.

### lure_distinguishing_detail.dart

```dart
/// The single piece of text that distinguishes one [LureCatalogEntry] from
/// a sibling variant of the same model — the same fallback chain
/// `LureVariant`'s own constructor assertion already requires at least one
/// of to be present (MFS-015). Reused by [LureStatisticsRepository]'s
/// deterministic tie-break and by the lure list's "Color" column, so the
/// same fallback logic is never duplicated within this feature.
String lureDistinguishingDetail(LureCatalogEntry entry) =>
    entry.variant.colorName ??
    entry.variant.manufacturerColorCode ??
    entry.variant.variantName ??
    '';
```

### No value objects, no repository interface

`lureType` is a plain `String`, identical treatment to every other reference to it elsewhere in this codebase (MFS-015/016/017). `LureStatisticsRepository` is a concrete class, constructed manually — consistent with every other repository in this project.

---

## 4. Data Layer

### LureStatisticsRepository

```text
lib/features/statistics/data/lure_statistics_repository.dart
```

```dart
class LureStatisticsRepository {
  LureStatisticsRepository(
    this._database, [
    this._catalogMapper = const LureCatalogMapper(),
  ]);

  final AppDatabase _database;
  final LureCatalogMapper _catalogMapper;

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

  Future<int> _countCatchesWithLure() async {
    final query = _database.selectOnly(_database.catches)
      ..addColumns([_database.catches.id.count()])
      ..where(_database.catches.lureVariantId.isNotNull());
    final row = await query.getSingle();
    return row.read(_database.catches.id.count()) ?? 0;
  }

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
  final byDetail = lureDistinguishingDetail(a.lure).toLowerCase().compareTo(
    lureDistinguishingDetail(b.lure).toLowerCase(),
  );
  if (byDetail != 0) return byDetail;
  return a.lure.id.compareTo(b.lure.id); // guaranteed-unique final tiebreak
}

int _compareLureTypeStatistics(
  LureTypeCatchStatistic a,
  LureTypeCatchStatistic b,
) {
  final byCount = b.catchCount.compareTo(a.catchCount);
  if (byCount != 0) return byCount;
  return a.lureType.compareTo(b.lureType); // unique per map key
}
```

### Required Drift queries

| Query | Shape | Purpose |
|---|---|---|
| `_countCatchesWithLure()` | `SELECT COUNT(id) FROM catches WHERE lureVariantId IS NOT NULL` (via `selectOnly`/`count()`) | MFS-019 FR-3's total — every catch with an assigned lure, resolvable or not. |
| `_resolvableCatchLureRows()` | `catches INNER JOIN lure_variants ON lure_variants.id = catches.lureVariantId INNER JOIN lure_models ON lure_models.id = lure_variants.lureModelId` | One row per catch whose assigned lure resolves — the raw material for both the lure list and the lure-type breakdown. Excludes null and (structurally-impossible) unresolvable references by ordinary `INNER JOIN` semantics — see [Key Design Decision 3](#key-design-decisions). |

Exactly two queries per `getLureStatistics()` call, regardless of how many catches or lures exist — never one query per lure, never one per lure type (no N+1).

### Repository responsibilities

* running exactly the two queries above
* grouping and counting the joined rows into per-lure and per-lure-type counts, in memory
* applying the deterministic sort/tie-break to both resulting lists
* assembling `LureStatisticsSummary`

The repository does not own: display-label resolution (`lureTypeDisplayLabel` is called by the presentation layer, not stored here), image resolution (`LureCatalogEntry.effectiveImageReference`, already resolved by the reused `LureCatalogEntry`), or any caching (MFS-019 FR-8 — every call recomputes from scratch).

### Business rules enforced by this layer

* A catch with `lureVariantId == null` never contributes to any part of the summary (MFS-019 Edge Cases).
* A catch whose `lureVariantId` is set but does not resolve counts toward `totalCatchesLinkedToLure` but not toward `lures`/`lureTypeBreakdown` (MFS-019 FR-10).
* A retired `LureVariant` is counted identically to an active one — no `retiredAt` filtering anywhere in this feature's queries (MFS-019 FR-11), mirroring `LureCatalogRepository.getEntryById()`'s and `PersonalTackleBoxRepository`'s own deliberate omission of that filter.
* `lures`/`lureTypeBreakdown` are always sorted by catch count descending, with the deterministic tie-break from [Key Design Decision 4](#key-design-decisions) applied unconditionally.

---

## 5. Presentation Layer

All screens are manually constructed and pushed with `Navigator.push` — no GoRouter routes, no Riverpod, consistent with every other page in this app.

### Tabbed shell — `StatisticsPage`

```text
lib/features/statistics/presentation/widgets/statistics_page.dart
```

```dart
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key, required this.repository});

  final LureStatisticsRepository repository;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tilastot'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Viehetilastot', icon: Icon(Icons.bar_chart))],
          ),
        ),
        body: TabBarView(
          children: [LureStatisticsTab(repository: repository)],
        ),
      ),
    );
  }
}
```

A `StatelessWidget`, per [Key Design Decision 7](#key-design-decisions) — it owns no state of its own; tab selection is `DefaultTabController`'s, and `LureStatisticsTab` owns its own load state.

### Lure Statistics tab — `LureStatisticsTab`

```text
lib/features/statistics/presentation/widgets/lure_statistics_tab.dart
```

A `StatefulWidget` constructed with a required `LureStatisticsRepository`.

Load sequence (`initState`): `await repository.getLureStatistics()` → on success, `setState` with the resolved `LureStatisticsSummary`; on failure, `setState` with an error message. No `AutomaticKeepAliveClientMixin` — see [Key Design Decision 8](#key-design-decisions).

Rendering, once loaded (a single scrollable `ListView`, not a `CustomScrollView` — this screen has no long, independently-scrolling sections that would justify one):

1. Three `LureStatisticsSummaryCard`s in a row/wrap (total, most successful lure, most successful lure type).
2. A "Vieheet" (lure list) section: one `LureCatchStatisticRow` per entry in `summary.lures`, or an inline empty message if `summary.lures.isEmpty`.
3. A "Viehetyypit" (lure type breakdown) section: one `LureTypeCatchStatisticRow` per entry in `summary.lureTypeBreakdown`, or an inline empty message if `summary.lureTypeBreakdown.isEmpty`.

Per [Key Design Decision 9](#key-design-decisions), there is no separate whole-screen "empty" branch — the total card always shows its numeric value (including `0`), the two ranking cards show "Ei vielä tietoja" whenever their getter is `null`, and the two list sections show their own inline empty message whenever their own list is empty.

### Summary card — `LureStatisticsSummaryCard`

```text
lib/features/statistics/presentation/widgets/lure_statistics_summary_card.dart
```

A small, stateless, reusable Material 3 `Card` taking a `title` and a `value` (both plain `String`s) — used three times by `LureStatisticsTab`, which is responsible for formatting each card's specific content:

* **Total:** title "Saaliiseen liitettyjä vieheitä", value `'${summary.totalCatchesLinkedToLure}'`.
* **Most successful lure:** title "Menestynein viehe", value either `'${manufacturer} ${modelName}, ${distinguishing detail} (${catchCount} saalista)'` or, when `null`, "Ei vielä tietoja".
* **Most successful lure type:** title "Menestynein viehetyyppi", value either `'${lureTypeDisplayLabel(lureType)} (${catchCount} saalista)'` or, when `null`, "Ei vielä tietoja".

The card itself contains no business logic and no repository access — it renders exactly the `title`/`value` strings it is given, mirroring the "pure presentation component" discipline TD-017 already established for `AssignedLureRow`.

### Lure list row — `LureCatchStatisticRow`

```text
lib/features/statistics/presentation/widgets/lure_catch_statistic_row.dart
```

Renders one `LureCatchStatistic`: `LureImage` (reused unchanged from `lure_catalog`, using `lure.effectiveImageReference`), manufacturer + model name, `lureDistinguishingDetail(lure)` for the color/variant detail, `lureTypeDisplayLabel(lure.lureType)`, and `catchCount`. A pure, stateless, `const`-constructible row — no repository access, no navigation.

### Lure type row — `LureTypeCatchStatisticRow`

```text
lib/features/statistics/presentation/widgets/lure_type_catch_statistic_row.dart
```

Renders one `LureTypeCatchStatistic`: `lureTypeDisplayLabel(lureType)` and `catchCount`. Equally small and pure.

### Loading / Error / Empty summary

| State | Where | Behavior |
|---|---|---|
| Loading | `LureStatisticsTab` | Centered `CircularProgressIndicator`, replacing the entire tab body. |
| Load error | `LureStatisticsTab` | A clear error message ("Tilastojen lataaminen epäonnistui.") plus a "Yritä uudelleen" (retry) button re-running the load — the same Finnish retry wording already established for `personal_tackle_box`'s photo-attach retry (TD-016). |
| No catches linked to a lure at all | `LureStatisticsTab` | Total card shows `0`; both ranking cards show "Ei vielä tietoja"; both list sections show their inline empty message. No separate whole-screen empty widget — see [Key Design Decision 9](#key-design-decisions). |
| Total nonzero, but every linked catch is unresolvable (should not occur) | `LureStatisticsTab` | Total card shows the nonzero count; both ranking cards and both list sections behave exactly as the fully-empty case above, since `lures`/`lureTypeBreakdown` are empty either way. |

---

## 6. Navigation

Following the exact temporary-entry-point pattern already established three times (TD-015 for the Lure Catalog, TD-016 for the Personal Tackle Box, TD-018 unchanged), `MapScreen` gains one more `AppBar` `IconButton`:

```dart
appBar: AppBar(
  title: const Text('Kalastussovellus'),
  actions: [
    IconButton(
      key: const Key('openLureToolsButton'),
      icon: const Icon(Icons.menu_book),
      tooltip: 'Viehekatalogi ja oma vieherasia',
      onPressed: _openLureTools,
    ),
    IconButton(
      key: const Key('openStatisticsButton'),
      icon: const Icon(Icons.bar_chart),
      tooltip: 'Tilastot',
      onPressed: _openStatistics,
    ),
  ],
),
```

```dart
void _openStatistics() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => StatisticsPage(repository: _lureStatisticsRepository),
    ),
  );
}
```

`MapScreen` constructs `_lureStatisticsRepository` the same way it already constructs every other repository — `late final LureStatisticsRepository _lureStatisticsRepository = LureStatisticsRepository(_database);` — reusing the already-open `AppDatabase` instance, no new database connection.

```text
MapScreen (temporary entry point)   [existing, unchanged pattern from TD-015/016/018]
        ↓ (new AppBar action)
StatisticsPage                      [statistics]
        ↓ (DefaultTabController, one tab)
LureStatisticsTab                   [statistics]
```

No broader navigation redesign is attempted; this entry point is explicitly temporary, exactly like the three before it (per MFS-019's Navigation section, which defers exact placement to this document).

---

## 7. State Management

No Riverpod, no `Provider`, no `InheritedWidget` — consistent with every other feature in this codebase. `LureStatisticsTab` is the only stateful widget this milestone introduces; its state (`_summary`, `_isLoading`, `_errorMessage`) is plain `State` fields, following the exact `initState` → async load → `setState` pattern already used by `PersonalTackleBoxPage` (TD-016) and `CatchDetailsPage`'s lure-resolution loading (TD-017).

`StatisticsPage` and every row/card widget (`LureStatisticsSummaryCard`, `LureCatchStatisticRow`, `LureTypeCatchStatisticRow`) are stateless — they render data handed to them and hold no mutable state of their own.

---

## 8. Error Handling

| Scenario | Behavior |
|---|---|
| `getLureStatistics()` throws (e.g. a database read error) | Caught in `LureStatisticsTab._load()`; the tab shows a clear error message plus a retry action; the application does not crash. |
| Retry after a load failure | Tapping "Yritä uudelleen" re-runs `_load()` from scratch; no partial or stale data is shown while the retry is in flight (the loading state is shown again). |
| A catch's `lureVariantId` does not resolve to any `LureVariant` (should not occur — structurally prevented by the `restrict` foreign key established in TD-017) | Handled by construction, not by a runtime check: the `innerJoin` in `_resolvableCatchLureRows()` simply never returns that row, so it cannot reach the aggregation step or crash it (see [Key Design Decision 3](#key-design-decisions)). It still counts toward `_countCatchesWithLure()`'s total. |
| Retired catalog variant referenced by a catch | No special-casing anywhere in this feature — resolved and counted identically to an active variant, exactly as `LureCatalogRepository.getEntryById()` and `PersonalTackleBoxRepository` already guarantee elsewhere in this codebase. |
| `TackleBoxEntry` for a counted lure is removed while the Statistics tab is not open | No effect whatsoever the next time the tab loads — this feature never reads `TackleBoxEntries` (see [Key Design Decision 6](#key-design-decisions)), so there is nothing for a tackle box change to invalidate. |

---

## 9. Empty and Loading States

Covered in full in [§5](#loading--error--empty-summary). Summary: a single centered `CircularProgressIndicator` for loading; a single error message plus retry for failure; per-card and per-section empty handling (no dedicated whole-screen empty widget) for the no-data cases, per [Key Design Decision 9](#key-design-decisions).

---

## 10. Performance Considerations

**Query count:** exactly two per `getLureStatistics()` call — one `COUNT`, one joined `SELECT` — regardless of how many catches, lures, or lure types exist. Never one query per lure or per lure type (no N+1), matching the discipline already established across every repository in this codebase.

**Aggregation cost:** O(n) over the resolvable-catch rows returned by the second query, using a single linear pass with `Map`-based accumulation — no nested loops, no repeated scans. A single user's own catch history is expected to remain small (tens to low hundreds of rows) for the lifetime of this application on a single device, several orders of magnitude below the "thousands of variants, in the limit" scale MFS-015's Performance Expectations anticipate for the *shared catalog* — so an in-memory count, rather than a SQL `GROUP BY`, is not a premature-optimization risk in the other direction either; it is simply the simplest correct approach at this data's actual scale.

**Sorting cost:** O(k log k) over the number of distinct lures/lure types actually caught (bounded above by the number of resolvable catches), using `List.sort` with the explicit multi-key comparators from [§4](#4-data-layer) — never relying on sort stability.

**No caching.** Every open of the Statistics tab re-runs both queries and recomputes the aggregation from scratch, per MFS-019 FR-8 ("Computed Live, Never Stored") and [Key Design Decision 8](#key-design-decisions)'s deliberate choice not to preserve `LureStatisticsTab` state across tab switches.

**Image loading:** `LureImage`'s existing `cacheWidth`/`cacheHeight` sizing (decode at display size, never full source resolution) is reused unchanged for each lure list row's thumbnail — no new image-loading code.

**List rendering:** the lure list and lure type breakdown render via `ListView`/`ListView.builder` (an implementation-time choice between a single outer `ListView` with inline sections versus per-section `ListView.builder`s inside a `CustomScrollView`, with no behavioral consequence either way), matching the lazy/virtualized discipline already established by every other list in this application. Given the expected scale of a single user's catch history, this is a consistency choice, not a scale-driven necessity.

---

## 11. Testing Strategy

Follows the same layered testing philosophy as every prior TD in this project: domain tests for construction/assertions/getters, repository tests for query and aggregation behavior against a real in-memory database, widget tests for the presentation surfaces, and a physical-device pass at the end. No migration test is needed — this milestone changes no schema.

**Domain** (`test/features/statistics/domain/`):
`lure_catch_statistic_test.dart` — valid construction; rejects `catchCount <= 0`. `lure_type_catch_statistic_test.dart` — valid construction; rejects an empty `lureType`; rejects `catchCount <= 0`. `lure_statistics_summary_test.dart` — `mostSuccessfulLure`/`mostSuccessfulLureType` return the first list element when non-empty and `null` when empty; rejects a negative `totalCatchesLinkedToLure`. `lure_distinguishing_detail_test.dart` — returns `colorName` when present; falls back to `manufacturerColorCode`, then `variantName`, in order.

**Repository** (`lure_statistics_repository_test.dart`, against `AppDatabase(NativeDatabase.memory())`, seeded directly via Drift inserts, mirroring every other repository test in this project):

* no catches at all → `totalCatchesLinkedToLure == 0`, `lures`/`lureTypeBreakdown` both empty
* catches with no assigned lure never contribute to any part of the summary
* one catch with a resolvable assigned lure → total is `1`, that lure appears with `catchCount == 1`, its lure type appears with `catchCount == 1`
* multiple catches assigned to the same `LureVariant` → that lure's `catchCount` reflects all of them
* multiple lures of the same `lureType` → the lure-type breakdown sums across them correctly
* `lures`/`lureTypeBreakdown` are sorted by catch count descending
* a tie in catch count between two lures resolves deterministically and matches the documented comparator (manufacturer → model → distinguishing detail → id)
* a tie in catch count between two lure types resolves deterministically by lure type code
* a catch assigned to a retired `LureVariant` is still counted normally, in the total, the lure list, and the lure-type breakdown
* removing a `TackleBoxEntry` for a counted lure (seeded and then deleted directly) does not change that lure's `catchCount` — regression coverage for [Key Design Decision 6](#key-design-decisions)
* a catch with a dangling `lureVariantId` (seeded by inserting the row directly with `PRAGMA foreign_keys` temporarily off, mirroring how TD-016 exercised its own `restrict` foreign key "directly at the SQL layer, since nothing in the application issues that delete") counts toward the total but is excluded from the lure list and lure-type breakdown

**Widget** (`test/features/statistics/presentation/widgets/`):
`lure_statistics_tab_test.dart` (against a real in-memory `AppDatabase`/`LureStatisticsRepository`, mirroring `personal_tackle_box_page_test.dart`'s setup) — loading indicator shown while pending; error message and retry shown on failure, and retry re-attempts the load; fully-empty state renders the total as `0` and both ranking cards as "Ei vielä tietoja" with both list sections showing their empty message; a populated summary renders all three cards, the lure list in the correct sorted order, and the lure-type breakdown in the correct sorted order. `lure_statistics_summary_card_test.dart` — renders the given title/value. `lure_catch_statistic_row_test.dart` — renders manufacturer/model/color/type/count; falls back to a placeholder image when `effectiveImageReference` is `null`. `lure_type_catch_statistic_row_test.dart` — renders the display label and count. `statistics_page_test.dart` — the single tab renders and shows `LureStatisticsTab`'s content.

**Integration/physical Android testing:**
open Statistics from the new `MapScreen` entry point; verify the three summary cards, lure list, and lure type breakdown against a real, previously-logged set of catches with assigned lures; verify the empty state on a fresh install with no lure-linked catches; verify reopening the screen after logging an additional catch reflects the new data with no manual refresh action; verify full offline/airplane-mode operation.

---

## 12. Risks

| Risk | Category | Mitigation |
|---|---|---|
| Two separate queries per load (a `COUNT` plus a joined `SELECT`) instead of one combined statement. | Design | Considered and rejected: a single statement covering both an unfiltered total and a filtered, joined breakdown would require a `UNION`/subquery Drift's typed query builder does not express as cleanly as two small, well-understood queries. Two queries, run once per tab open (never per row), is simpler to read, test, and maintain — consistent with this project's preference for clarity over cleverness. |
| In-memory aggregation (rather than SQL `GROUP BY`) could become slow if a user's catch history grows far beyond what this design anticipates. | Performance | Not expected at this application's scale (see [§10](#10-performance-considerations)). If a future real-world usage pattern ever proves this wrong, moving the count/group into SQL is a small, purely additive change confined to `LureStatisticsRepository`'s two private query methods — not a reason to build that complexity speculatively now. |
| `LureCatalogMapper.entryFromRows()` is now reused by a third feature (`lure_catalog` itself, `personal_tackle_box`, and now `statistics`), increasing the cost of ever changing its signature. | Maintainability | Accepted: this is the same, already-proven reuse point TD-016 established specifically to be reused this way, and its signature (`variantRow`, `modelRow`) has not changed since. |
| The "unresolvable `lureVariantId`" code path ([FR-10](../specifications/MFS-019-lure-based-catch-statistics.md#fr-10--unresolvable-lure-references)) cannot be exercised through any normal application flow, since the `restrict` foreign key (TD-017) prevents it structurally. | Test coverage | Exercised in the repository test suite by seeding a dangling row directly at the SQL layer with foreign key enforcement temporarily disabled — the same technique TD-016 already used to test its own `restrict` foreign key. |
| A future second Statistics tab could be tempted to reuse `LureStatisticsTab`'s "recompute on every build" approach even where it is not appropriate, or conversely copy `AutomaticKeepAliveClientMixin` without checking whether this tab still wants that. | Maintainability | [Key Design Decision 8](#key-design-decisions) records the reasoning explicitly, so a future implementer evaluates each tab's own state-preservation needs rather than copying either precedent blindly. |

---

## 13. Future Compatibility

* **General Catch / Fishing Statistics as a second tab** (`docs/roadmap.md` §3.3) — `StatisticsPage`'s `DefaultTabController(length: 1, ...)` becomes `length: 2`, with one more `Tab`/`TabBarView` child added; no restructuring of the existing Lure Statistics tab is required.
* **Including zero-catch lure variants in the lure list** (MFS-019 Future Extensions) — would require reading `PersonalTackleBoxRepository.getAll()` (or a similar owned-lures source) in addition to the current catch-history query, then left-joining that against `lures`' current catch-count map (defaulting to `0` for an owned lure with no catches yet). This is an additive change to `LureStatisticsRepository.getLureStatistics()`'s method body, not a redesign of its return shape.
* **Filtering statistics** (e.g. by date range or fishing spot) — the existing `_resolvableCatchLureRows()` join already has access to every `Catches` column; a filter would add a `.where(...)` clause to that one query, with no change to the aggregation or sorting logic that follows it.
* **Percentages, averages, and other derived metrics** — computable from the same `LureCatchStatistic`/`LureTypeCatchStatistic` lists this milestone already produces (e.g. a percentage is `catchCount / totalCatchesLinkedToLure`), with no new query.
* **Smart lure/fishing recommendations** (`docs/roadmap.md` §3.5) — would naturally consume `LureStatisticsSummary.lures` as an input, rather than a flat catch list.
* **Cloud synchronization** — unaffected. This feature is entirely read-only over data owned elsewhere; nothing here touches the repository-hides-the-data-source principle (ADR-0001, ADR-0005) that already governs `catches`' and `lure_catalog`'s own data layers.

---

## Dependencies

No new external package dependencies. This milestone reuses, unchanged:

* Flutter, Dart
* Drift (per ADR-0005) — read-only queries against existing tables only; no schema change
* The existing Repository pattern, feature-first structure, and manual dependency construction (ADR-0001, ADR-0003, ADR-0006)
* `LureCatalogMapper.entryFromRows()` (MFS-015/TD-015), consumed read-only, unmodified
* `LureImage`, `lureTypeDisplayLabel` (MFS-015/TD-015), reused unchanged
* The existing `Catches`, `LureVariants`, `LureModels` Drift tables (MFS-009/MFS-015/TD-017), read directly, unmodified

`flutter_riverpod` is not used by this feature, for the same reasons documented in TD-015/TD-016/TD-017/TD-018.

---

## Expected Files To Create

```text
lib/features/statistics/domain/lure_catch_statistic.dart
lib/features/statistics/domain/lure_type_catch_statistic.dart
lib/features/statistics/domain/lure_statistics_summary.dart
lib/features/statistics/domain/lure_distinguishing_detail.dart
lib/features/statistics/data/lure_statistics_repository.dart
lib/features/statistics/presentation/widgets/statistics_page.dart
lib/features/statistics/presentation/widgets/lure_statistics_tab.dart
lib/features/statistics/presentation/widgets/lure_statistics_summary_card.dart
lib/features/statistics/presentation/widgets/lure_catch_statistic_row.dart
lib/features/statistics/presentation/widgets/lure_type_catch_statistic_row.dart
```

Plus new test files under `test/features/statistics/...` per [§11](#11-testing-strategy).

## Expected Files To Modify

```text
lib/features/map/presentation/map_screen.dart   (construct LureStatisticsRepository; one new AppBar entry point, _openStatistics)
```

No other existing file is modified. `lib/core/database/app_database.dart` is **not** modified — see [Database Impact](#database-impact).

---

## Database Impact

**None.** No new Drift table, no new column, no schema version change, no migration. The schema version remains at `6`, as established by TD-017. `LureStatisticsRepository` reads the existing `Catches`, `LureVariants`, and `LureModels` tables through plain, read-only `select`/`selectOnly`/join queries — nothing about `AppDatabase`'s table registration, migration strategy, or schema version changes.

Confirm at implementation time that the live schema version is still `6` before beginning, consistent with the same hedge every prior TD in this project has required.

---

## Test Impact

* **New tests only.** Every test file listed in [§11](#11-testing-strategy) is new, under `test/features/statistics/...`.
* **No existing test file is modified.** `catches`, `lure_catalog`, and `personal_tackle_box`'s existing domain, database, mapper, repository, and widget test suites are untouched, since none of those features' code changes.
* `test/features/map/presentation/map_screen_test.dart` (if it exists and asserts on the `AppBar`'s action set) may need a new assertion added for the additional `IconButton`, mirroring however the existing `openLureToolsButton` entry point is already asserted there — confirm at implementation time.

---

## Implementation Notes

To be completed during implementation, following the established convention of recording any deviation from this document here, with justification.

---

## Implementation Notes for Claude Code

* **Confirm the live schema version is `6` before starting** (see [Database Impact](#database-impact)) — if it has moved past `6` since this document was written, nothing in this design changes, but double-check no other in-flight TD is also mid-migration.
* **Do not touch `lib/core/database/app_database.dart`.** This is the one file every prior TD in this project modified and this one deliberately does not — a stray edit here (even an unused import) would be an unexplained deviation from [Database Impact](#database-impact).
* **Do not modify anything under `lib/features/catches/`, `lib/features/lure_catalog/`, or `lib/features/personal_tackle_box/`.** This design reads their tables and reuses `LureCatalogMapper.entryFromRows()` exactly as it exists today — if satisfying a requirement here seems to need a change to one of those three features, stop and re-read [Key Design Decision 1](#key-design-decisions)/[6](#key-design-decisions) rather than adding one.
* **All user-visible text must be Finnish**, per this project's Development Rules. Suggested strings are given throughout this document (§5, §6, §8) — reuse them as given rather than inventing new phrasing, so terminology stays consistent with the rest of the application (in particular, reuse "Yritä uudelleen" verbatim for the retry action, matching `personal_tackle_box`'s existing photo-retry wording).
* **No Riverpod, no repository interface, no DAO/service/use-case layer, no `watch()`.** Construct `LureStatisticsRepository` manually in `MapScreen`, exactly like every other repository already there.
* **Reuse `LureImage` and `lureTypeDisplayLabel` by importing them from `lure_catalog`** — do not recreate an image-fallback widget or a lure-type-label map inside `statistics`.
* **The two repository queries in [§4](#4-data-layer) are given close to verbatim** — implement them as written rather than merging them into one query or introducing a SQL `GROUP BY`, per [Key Design Decision 2](#key-design-decisions).
* **The tie-break comparators in [§4](#4-data-layer) must be applied unconditionally**, not only when `catchCount` happens to tie in a manual test — Dart's `List.sort` is not guaranteed stable, so omitting the secondary/tertiary/final keys "because it usually doesn't matter" would reintroduce nondeterminism MFS-019 explicitly forbids.
* **Run the full validation sequence below before considering this done**, and update this document's own `Status`, `Implementation Notes`, and `Definition of Done` sign-off the same way every prior TD in this project has.
* **Do not update `docs/project-status.md` or `docs/roadmap.md`** as part of this TD's implementation — that happens as a separate, later step per this project's own Development Workflow, and is explicitly out of scope for the task that produced this document.

---

## Validation

```bash
dart format .
flutter analyze
flutter test
```

All must pass. Confirm the schema version is unaffected (still `6`) before and after implementation.

---

## Definition of Done

* The implementation satisfies all requirements in MFS-019.
* The implementation follows TD-019, or documents and justifies each deviation.
* A new `statistics` feature exists, with `StatisticsPage`'s Lure Statistics as its only tab in this milestone.
* The three summary cards show the correct total, most successful lure, and most successful lure type, with deterministic tie-breaking.
* The lure list shows every lure with at least one resolvable catch, sorted by catch count descending, with photo/name/color/type/count per row.
* The lure type breakdown shows catch count per lure type, sorted by catch count descending.
* Statistics are computed fresh on every load — no cached, stored, or persisted aggregate exists anywhere.
* Removing a `TackleBoxEntry` for a counted lure does not change that lure's statistics.
* A retired catalog variant assigned to a catch is counted normally.
* A catch with no assigned lure, or an unresolvable assigned lure, is handled per MFS-019 FR-3/FR-9/FR-10 without crashing.
* No new Drift table, column, schema version, or migration was introduced.
* `catches`, `lure_catalog`, and `personal_tackle_box` are functionally and structurally unchanged.
* Every capability works with no network connection.
* `dart format .`, `flutter analyze`, and `flutter test` all pass.
* Architecture review is completed.
* Physical Android testing is completed.
* Documentation (`docs/project-status.md`) is updated in a separate, subsequent step — not part of this document's own completion.
