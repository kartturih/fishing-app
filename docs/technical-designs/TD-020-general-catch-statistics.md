# TD-020 — General Catch Statistics

## Status

Implemented — architecture review passed, all automated tests passing (535/535), `flutter analyze` clean (8 pre-existing/accepted info-level lints, none introduced by this milestone), and physical Android verification completed successfully. No architectural deviations from this document were required in production code. Three rounds of presentation-only refinement were made after physical Android testing and are recorded in [Implementation Notes](#implementation-notes): equal-height summary cards, a medal-bordered "Hall of Fame" redesign of the Top 3 Largest Catches list (replacing the original left-side rank badge), and a brightened gold border with a subtle warm first-place tint.

## Related Specification

* MFS-020: General Catch Statistics

---

## Goal

Implement MFS-020's Catches tab — the Statistics feature's new first tab — fully consistent with the architecture TD-019 already established: a Top 3 Largest Catches list, two summary values (total catches, most caught species), and a per-species catch-count list, all computed live from existing `Catch`/`FishingSpot` data, with the existing Lure Statistics tab moving to the second tab position unchanged.

The implementation shall satisfy MFS-020.

---

## Scope

Implement:

* three read-only domain/read-model types: a largest catch paired with its fishing spot, a species paired with its catch count, and a summary aggregate wrapping both plus the total-catches count
* a concrete, feature-owned `GeneralCatchStatisticsRepository` computing all of the above from one plain, read-only query against the existing `Catches` and `FishingSpots` tables
* deterministic, explicitly-defined tie-breaking for the Top 3 Largest Catches and for "most caught species"
* the Catches tab: two summary cards, a Top 3 Largest Catches list, and a Species List
* reordering `StatisticsPage`'s tabs so Catches is first and Lure Statistics (TD-019, unmodified) is second
* Top 3 Largest Catches navigation to the existing Catch Details view
* loading, empty, and error states
* accessibility labeling
* tests

Do **not** implement:

* any new Drift table, column, or schema migration
* any cached, stored, or persisted statistic of any kind
* a Species Statistics page or any navigation from the Species List (MFS-021 Candidate, not this milestone)
* graphs, charts, filters, searching, achievements, averages, trends, weather statistics, location statistics, exports, or comparison features (MFS-020 Out of Scope)
* any change to `catches`, `catch_photos`, `fishing_spots`, `lure_catalog`, or `personal_tackle_box`'s domain models, tables, repositories, or read-only/reference-only guarantees
* any change to the Lure Statistics tab's computation, data, or behavior
* Riverpod, repository interfaces, DAO/service/use-case layers, reactive database streams (`watch()`)

---

## Key Design Decisions

This section answers the questions most likely to be raised in review, before the detailed sections implement them.

**1. Resolving a `FishingSpot` for an arbitrary catch is a genuinely new requirement — MFS-020's Top 3 Largest Catches navigation is the first thing in this codebase that needs it.** `CatchDetailsPage.open()` requires a fully-resolved `FishingSpot` object, not just an id (`required this.fishingSpot`). Its only existing caller, `FishingSpotDetailsBottomSheet`, always already has that object in scope, because it is itself scoped to one fishing spot (`widget.fishingSpot`). The Catches tab is different: it looks across every fishing spot at once (MFS-020 FR-2), so by the time it has picked its Top 3 Largest Catches, it does not yet know which fishing spot each one belongs to. `FishingSpotRepository` has no single-record lookup (`loadAll()`/`watchAll()`/`create()`/`updateName()`/`delete()` only) — adding one (e.g. `getById()`) would be one option, but nothing else in the codebase needs it, and it would mean the Catches tab still has to make a second query per catch to use it. See Key Design Decision 2 for the chosen alternative.

**2. One joined query resolves the fishing spot for every catch at once — not a per-catch lookup, and not a new `FishingSpotRepository` method.** `GeneralCatchStatisticsRepository` joins `Catches` directly to `FishingSpots` (`Catches.fishingSpotId → FishingSpots.id`) in its one query, exactly like `LureStatisticsRepository`'s own precedent (TD-019) of joining tables directly rather than depending on another feature's repository instance methods. Because `Catches.fishingSpotId` is a **required** (non-nullable) foreign key — unlike MFS-019's nullable `lureVariantId` — this `innerJoin` never excludes a row: every catch always has exactly one fishing spot. This is a deliberate simplification over TD-019's shape: TD-019 needed two queries (a `COUNT` plus a filtered joined `SELECT`) because its join *could* legitimately drop rows (an unresolvable or absent lure reference) and still needed the true total separately. That distinction does not exist here, so one query serves the total count, the species distribution, and the largest-catch candidates all at once. See [§4](#4-data-layer).

**3. Aggregation happens entirely in memory, for the same reasons TD-019 already established, stated here from the start rather than added after review.** A single user's own catch history is small (tens to low hundreds of rows) — several orders of magnitude below the catalog-scale data MFS-015's own Performance Expectations anticipate. In-memory grouping/sorting is simpler to write and review than a SQL aggregate, easier to test (assertions run directly against plain Dart values, not against SQLite's own `GROUP BY`/`ORDER BY` semantics), and easier to maintain (one language, not two, to hold in mind at once) — while remaining entirely sufficient for this application's offline-first, single-user, single-device model (ADR-0001), which has no concurrent-access or server-side aggregation scenario to design around. This mirrors TD-019's Key Design Decision 2 and its architecture-review-added rationale, applied here proactively.

**4. Tie-breaking is fully specified in this document, not deferred — per MFS-020's explicit instruction, unlike MFS-019/TD-019's original split.** Every ordering rule below is a complete, explicit chain; nothing is left to an implementer's judgment or to `List.sort`'s (unguaranteed) stability.

Largest catches, in order:

1. weight — **descending**
2. `caughtAt` — **descending**
3. `createdAt` — **descending**
4. `id` — **ascending** (guaranteed-unique final tiebreak, since no two catches share an id)

This is not a new convention — it is the exact ordering `CatchRepository.getByFishingSpotId` already uses (MFS-009/TD-009: `caughtAt` desc → `createdAt` desc → `id` asc), with weight prepended as the new primary key, so a catch that ranks highest by weight and then most-recently-caught among ties is picked the same way this codebase already breaks catch-ordering ties elsewhere.

Species statistics, in order:

1. catch count — **descending**
2. species identifier (`FishSpecies.name`, e.g. `'pike'`) — **ascending** (guaranteed-unique final tiebreak, since no two `FishSpecies` values share a name)

This is the same "stable string code ascending" shape `LureStatisticsRepository` already uses for lure-type ties (TD-019).

**5. "Most caught species" is a derived getter on the summary read-model, not separately queried or stored.** It is simply the first element of the already-sorted `speciesCatchCounts` list (`null` when empty) — the exact same relationship TD-019 established between `mostSuccessfulLure`/`mostSuccessfulLureType` and their respective lists (TD-019 Key Design Decision 5).

**6. `GeneralCatchStatisticsRepository` never reads `CatchPhotos`.** Resolving "the catch's photo, if one exists" (MFS-020 FR-4) is left entirely to the presentation layer, exactly as it already is for the existing fishing-spot-scoped catch list: `CatchListItem` already takes a `CatchPhotoRepository` and resolves its own thumbnail (`getByCatchId` + `resolveFile`) independently, per catch, in a `FutureBuilder`. Reusing that exact, already-working pattern (see Key Design Decision 7) means the repository's only dependency is `AppDatabase` plus the already-public `CatchMapper` — no new dependency on `catch_photos` at all, and no risk of re-deriving photo-resolution logic that already exists and is already tested.

**7. Top 3 Largest Catches rows reuse `CatchListItem` completely unmodified, wrapped in a new, lightweight rank indicator — not a duplicate catch-row widget.** `CatchListItem`'s existing contract (`catchModel`, `catchPhotoRepository`, `onTap`) already renders exactly what MFS-020 FR-4 asks for (photo-or-placeholder, species, weight/length via the shared `formatCatchMeasurementLine`) and already delegates navigation entirely to its caller via `onTap` — nothing about it is fishing-spot-specific, and it stays untouched by this milestone. It also shows the catch's date/time, which MFS-020 does not require but does not forbid either; reusing the widget unchanged is preferred over forking a near-identical new one just to omit one line, per this project's "reuse existing helper functions instead of duplicating logic" rule.

Three plain `CatchListItem` rows in sequence do not communicate first/second/third place clearly enough on their own, so each entry is wrapped in a new, small `RankedLargestCatchRow`: a leading numbered badge (1/2/3) placed beside an unmodified `CatchListItem`. This is a *composition*, not a duplicate row widget — `RankedLargestCatchRow` renders nothing about the catch itself, owns no catch-related logic, and would be trivial to delete without losing any catch-rendering capability; it exists solely to make the list's already-correct order visually legible. No fundamentally different component is introduced for first place specifically in this MVP — the same wrapper, with a different badge value, covers all three positions. See [§5](#top-3-largest-catches-row--rankedlargestcatchrow-new).

**8. Summary cards reuse the existing generic card widget, renamed to drop its now-inaccurate "Lure" prefix.** `LureStatisticsSummaryCard` (TD-019) already takes only a plain `title`/`value` string pair with no lure-specific knowledge — it fits the Catches tab's two summary values exactly as-is. Rather than introduce a second, near-identical card type, it is renamed to `StatisticsSummaryCard` (file: `lure_statistics_summary_card.dart` → `statistics_summary_card.dart`) now that it is genuinely shared by both tabs, and its one existing caller (`LureStatisticsTab`) is updated to match. This mirrors the precedent TD-018 already set for `LureCatalogListItem` → `LureCatalogModelListItem`: a rename-in-place once a widget's real scope outgrows its original name, not a new abstraction.

**9. Species List rows are a new, small, presentation-only widget — nothing existing fits a species-plus-count pairing.** `SpeciesCatchStatisticRow` mirrors `LureTypeCatchStatisticRow`'s shape closely (a label and a count), with one addition: a trailing, static chevron icon signaling that the row is designed for future navigation (MFS-020 FR-8), without an `InkWell`, `GestureDetector`, or any other tap handling — tapping a row does nothing, and the row is not exposed to assistive technology as a button (MFS-020's Accessibility Expectations). This mirrors the same static trailing-chevron visual convention already used elsewhere in this codebase (e.g. `_TackleBoxItemRow`'s chevron), applied here to a row that — unlike that one — is not actually tappable yet.

**10. `StatisticsPage` becomes a two-tab composing shell, taking every dependency both tabs need — the same shape `LureToolsPage` already established for a comparable reason.** Its constructor grows from one parameter to seven (`generalCatchStatisticsRepository`, `lureStatisticsRepository`, plus five objects the Catches tab needs only to open Catch Details: `catchRepository`, `catchPhotoRepository`, `lureCatalogRepository`, `personalTackleBoxRepository`, `personalTackleBoxPhotoStorage`). This is not a new complexity this milestone introduces — `LureToolsPage` (TD-016) already takes a comparable number of constructor parameters for the same reason (a thin shell threading dependencies down to the tabs it composes), consistent with this project's manual-construction, no-DI-framework convention (ADR-0001/ADR-0003).

---

## Architecture Review — Approved Decisions

The following were raised and explicitly approved during architecture review of this document. Nothing here changes the design already described above — this section exists to record the approval itself as a clear, auditable reference, not to introduce anything new.

* **Reusing the `catches`-owned `CatchListItem` for the Top 3 Largest Catches list (Key Design Decision 7) is an intentional and limited cross-feature presentation dependency.** `statistics` now depends on one specific, already-stable `catches` presentation widget, in addition to the read-only data dependency it already had (via `LureStatisticsRepository`/`GeneralCatchStatisticsRepository`).
* **This is preferred over duplicating the same catch-row presentation inside `statistics`.** A second, near-identical widget rendering the same `Catch` fields the same way would be exactly the kind of duplicated logic this project's Development Rules warn against, for no corresponding benefit.
* **`CatchListItem` is not moved into a shared module (e.g. `lib/shared/` or `lib/core/`) at this stage.** It remains owned by `catches`, with `statistics` depending on it directly — consistent with this project's existing precedent of one feature depending on another's presentation widget directly (e.g. `personal_tackle_box` depending on `lure_catalog`'s `LureImage`) rather than pre-emptively centralizing shared UI before there is a second, unrelated consumer.
* **`LureStatisticsSummaryCard` is renamed to `StatisticsSummaryCard`** (Key Design Decision 8), reflecting that it is now genuinely shared by both Statistics tabs rather than lure-specific.
* **`StatisticsPage` keeps its explicit constructor parameters** (Key Design Decision 10) — every dependency it threads to its two tabs remains a named, typed constructor parameter.
* **No dependency-bundle object is introduced merely to shorten the constructor parameter list.** Grouping the five Catch-Details-only objects into a single wrapper purely to reduce parameter count would be an abstraction introduced for its own sake, not because those objects share any actual behavior or lifecycle — contrary to this project's "avoid unnecessary abstractions" rule. If `StatisticsPage`'s parameter list grows meaningfully again in a future milestone, this trade-off should be reconsidered then, not pre-empted now.

---

## 1. Overview

`statistics` is extended, not replaced. It gains a second data source and a second tab, while everything TD-019 built remains structurally untouched:

| Feature | Responsibility in this milestone |
|---|---|
| `statistics` (extended) | Gains `GeneralCatchStatisticsRepository`, three new read-model domain types, the Catches tab's presentation surfaces, and a renamed-in-place shared card widget. `LureStatisticsRepository`, `LureStatisticsTab`, and every other TD-019 file are otherwise unmodified. |
| `catches` (unmodified) | Continues to own `Catch`/`CatchRepository`/the `Catches` table, and now also `CatchListItem`, reused unchanged and wrapped with a new rank indicator by `statistics` (Key Design Decision 7). `statistics` reads the `Catches` table directly, exactly as it already does for `LureStatisticsRepository`. |
| `fishing_spots` (unmodified) | Continues to own `FishingSpot`/`FishingSpotRepository`/the `FishingSpots` table. `statistics` reads this table directly for the first time (Key Design Decision 1/2), gaining no new dependency on `FishingSpotRepository`'s instance methods. |
| `catch_photos` (unmodified, read from presentation only) | `GeneralCatchStatisticsRepository` never reads it (Key Design Decision 6); the Catches tab's presentation layer does, via the already-existing `CatchPhotoRepository`, exactly as the catch list already does. |

**One new repository instance is required.** `MapScreen` already constructs `AppDatabase` and every repository this milestone needs to reuse. This document adds exactly one more manually-constructed repository, `GeneralCatchStatisticsRepository(_database)`, alongside the existing ones.

---

## 2. Folder Structure

```text
lib/features/statistics/
  domain/
    largest_catch.dart                       (new)
    species_catch_statistic.dart              (new)
    general_catch_statistics_summary.dart     (new)
    lure_catch_statistic.dart                 (unchanged, TD-019)
    lure_type_catch_statistic.dart            (unchanged, TD-019)
    lure_statistics_summary.dart              (unchanged, TD-019)
    lure_distinguishing_detail.dart           (unchanged, TD-019)
  data/
    general_catch_statistics_repository.dart  (new)
    lure_statistics_repository.dart           (unchanged, TD-019)
  presentation/
    widgets/
      statistics_page.dart                    (modified — two tabs)
      general_catch_statistics_tab.dart       (new)
      ranked_largest_catch_row.dart           (new)
      species_catch_statistic_row.dart        (new)
      statistics_summary_card.dart            (renamed from lure_statistics_summary_card.dart)
      lure_statistics_tab.dart                (modified — import/reference only)
      lure_catch_statistic_row.dart           (unchanged, TD-019)
      lure_type_catch_statistic_row.dart      (unchanged, TD-019)
```

No `data/local/` (no table), no dedicated mapper file (this repository reuses `CatchMapper` and the existing `FishingSpotEntityMapper` extension directly — neither needs a new wrapper). Exact widget file separation may be adjusted if a smaller structure is clearer, consistent with the same allowance given in TD-013/TD-015/TD-016/TD-019.

---

## 3. Domain Layer

### LargestCatch

```dart
final class LargestCatch {
  const LargestCatch({required this.catchModel, required this.fishingSpot})
    : assert(
        catchModel.weightGrams != null,
        'catchModel must have a recorded weight',
      );

  final Catch catchModel;
  final FishingSpot fishingSpot;
}
```

Reuses `catches`' own `Catch` and `fishing_spots`' own `FishingSpot` directly — neither is duplicated into a `statistics`-owned type. This is the same "reference, not copy" discipline already established for `LureCatchStatistic.lure` (TD-019) and, before that, `TackleBoxItem.catalogEntry` (TD-016). The constructor assertion documents the invariant this type exists to express: a `LargestCatch` is never constructed for a weight-less catch.

### SpeciesCatchStatistic

```dart
final class SpeciesCatchStatistic {
  const SpeciesCatchStatistic({
    required this.species,
    required this.catchCount,
  }) : assert(catchCount > 0, 'catchCount must be greater than zero');

  final FishSpecies species;
  final int catchCount;
}
```

`species` is the existing `FishSpecies` enum (MFS-009) — never re-derived or duplicated as a string. Resolving it to a Finnish display name is a presentation concern (`FishSpecies.finnishName`, reused unchanged from `catches`), not stored here.

### GeneralCatchStatisticsSummary

```dart
final class GeneralCatchStatisticsSummary {
  const GeneralCatchStatisticsSummary({
    required this.totalCatches,
    required this.largestCatches,
    required this.speciesCatchCounts,
  }) : assert(totalCatches >= 0, 'totalCatches must not be negative'),
       assert(
         largestCatches.length <= 3,
         'largestCatches must contain at most three entries',
       );

  /// Every catch the angler has ever logged, across every fishing spot.
  final int totalCatches;

  /// The catches with the greatest recorded weight, descending, ties
  /// broken deterministically. At most three entries; a catch with no
  /// recorded weight is never included.
  final List<LargestCatch> largestCatches;

  /// Every species with at least one logged catch, with its catch count,
  /// sorted by catch count descending, ties broken deterministically.
  final List<SpeciesCatchStatistic> speciesCatchCounts;

  SpeciesCatchStatistic? get mostCaughtSpecies =>
      speciesCatchCounts.isEmpty ? null : speciesCatchCounts.first;
}
```

Per [Key Design Decision 5](#key-design-decisions), `mostCaughtSpecies` is a plain getter over an already-sorted list, not a field the repository must separately compute or keep in sync.

### No value objects, no repository interface

`totalCatches`/`catchCount` are plain `int`s; `species` is the existing `FishSpecies` enum. `GeneralCatchStatisticsRepository` is a concrete class, constructed manually — consistent with every other repository in this project.

---

## 4. Data Layer

### GeneralCatchStatisticsRepository

```text
lib/features/statistics/data/general_catch_statistics_repository.dart
```

```dart
class GeneralCatchStatisticsRepository {
  GeneralCatchStatisticsRepository(
    this._database, [
    this._catchMapper = const CatchMapper(),
  ]);

  final AppDatabase _database;
  final CatchMapper _catchMapper;

  Future<GeneralCatchStatisticsSummary> getGeneralCatchStatistics() async {
    final rows = await _catchesWithFishingSpot();

    final speciesCounts = <FishSpecies, int>{};
    final weightedCatches = <LargestCatch>[];

    for (final row in rows) {
      final catchModel = _catchMapper.toDomain(
        row.readTable(_database.catches),
      );
      speciesCounts.update(
        catchModel.species,
        (count) => count + 1,
        ifAbsent: () => 1,
      );

      if (catchModel.weightGrams != null) {
        weightedCatches.add(
          LargestCatch(
            catchModel: catchModel,
            fishingSpot: row.readTable(_database.fishingSpots).toDomain(),
          ),
        );
      }
    }

    weightedCatches.sort(_compareLargestCatches);

    final speciesCatchCounts = [
      for (final entry in speciesCounts.entries)
        SpeciesCatchStatistic(species: entry.key, catchCount: entry.value),
    ]..sort(_compareSpeciesStatistics);

    return GeneralCatchStatisticsSummary(
      totalCatches: rows.length,
      largestCatches: weightedCatches.take(3).toList(),
      speciesCatchCounts: speciesCatchCounts,
    );
  }

  /// Every catch, joined with its fishing spot. `Catches.fishingSpotId` is
  /// a required foreign key, so this `innerJoin` never excludes a row —
  /// see Key Design Decision 2.
  Future<List<TypedResult>> _catchesWithFishingSpot() {
    final query = _database.select(_database.catches).join([
      innerJoin(
        _database.fishingSpots,
        _database.fishingSpots.id.equalsExp(_database.catches.fishingSpotId),
      ),
    ]);
    return query.get();
  }
}

/// Sorts by weight descending; ties broken by caught-at date/time
/// descending, then created-at descending, then the catch id ascending as
/// a guaranteed-unique final tiebreak — see Key Design Decision 4.
int _compareLargestCatches(LargestCatch a, LargestCatch b) {
  final byWeight = b.catchModel.weightGrams!.compareTo(
    a.catchModel.weightGrams!,
  );
  if (byWeight != 0) return byWeight;
  final byCaughtAt = b.catchModel.caughtAt.compareTo(a.catchModel.caughtAt);
  if (byCaughtAt != 0) return byCaughtAt;
  final byCreatedAt = b.catchModel.createdAt.compareTo(
    a.catchModel.createdAt,
  );
  if (byCreatedAt != 0) return byCreatedAt;
  return a.catchModel.id.compareTo(b.catchModel.id);
}

/// Sorts by catch count descending; ties broken by the species' stable
/// stored identifier ascending — see Key Design Decision 4.
int _compareSpeciesStatistics(
  SpeciesCatchStatistic a,
  SpeciesCatchStatistic b,
) {
  final byCount = b.catchCount.compareTo(a.catchCount);
  if (byCount != 0) return byCount;
  return a.species.name.compareTo(b.species.name);
}
```

### Required Drift queries

| Query | Shape | Purpose |
|---|---|---|
| `_catchesWithFishingSpot()` | `catches INNER JOIN fishing_spots ON fishing_spots.id = catches.fishing_spot_id` | Every catch, joined with its fishing spot. Serves the total count (`rows.length`), the species distribution (grouped in Dart), and the largest-catch candidates (filtered and sorted in Dart) — all from this one query. |

Exactly one query per `getGeneralCatchStatistics()` call, regardless of how many catches exist — never one query per catch, never one per species.

### Repository responsibilities

* running the one query above
* grouping and counting the joined rows into a species distribution, in memory
* filtering to weighted catches and applying the deterministic sort/tie-break, in memory
* assembling `GeneralCatchStatisticsSummary`

The repository does not own: photo resolution (left to the presentation layer — Key Design Decision 6), display-label resolution (`FishSpecies.finnishName` is called by the presentation layer, not stored here), or any caching (MFS-020 FR-10 — every call recomputes from scratch).

### Business rules enforced by this layer

* A catch with no recorded weight never appears in `largestCatches` (MFS-020 FR-3).
* `largestCatches` never has more than three entries.
* Every catch contributes to `speciesCatchCounts`, regardless of whether it has a recorded weight (weight has no bearing on species counting).
* `largestCatches`/`speciesCatchCounts` are always sorted with the deterministic tie-break from [Key Design Decision 4](#key-design-decisions) applied unconditionally.

---

## 5. Presentation Layer

All screens are manually constructed and pushed with `Navigator.push` — no GoRouter routes, no Riverpod, consistent with every other page in this app.

### Tabbed shell — `StatisticsPage` (modified)

```text
lib/features/statistics/presentation/widgets/statistics_page.dart
```

```dart
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({
    super.key,
    required this.generalCatchStatisticsRepository,
    required this.lureStatisticsRepository,
    required this.catchRepository,
    required this.catchPhotoRepository,
    required this.lureCatalogRepository,
    required this.personalTackleBoxRepository,
    required this.personalTackleBoxPhotoStorage,
  });

  final GeneralCatchStatisticsRepository generalCatchStatisticsRepository;
  final LureStatisticsRepository lureStatisticsRepository;

  /// Forwarded to [GeneralCatchStatisticsTab], needed only to open Catch
  /// Details from a largest-catch entry (FR-5) — this page has no use for
  /// them itself.
  final CatchRepository catchRepository;
  final CatchPhotoRepository catchPhotoRepository;
  final LureCatalogRepository lureCatalogRepository;
  final PersonalTackleBoxRepository personalTackleBoxRepository;
  final TackleBoxPhotoStorage personalTackleBoxPhotoStorage;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tilastot'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Saalistilastot', icon: Icon(Icons.set_meal)),
              Tab(text: 'Viehetilastot', icon: Icon(Icons.bar_chart)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            GeneralCatchStatisticsTab(
              repository: generalCatchStatisticsRepository,
              catchRepository: catchRepository,
              catchPhotoRepository: catchPhotoRepository,
              lureCatalogRepository: lureCatalogRepository,
              personalTackleBoxRepository: personalTackleBoxRepository,
              personalTackleBoxPhotoStorage: personalTackleBoxPhotoStorage,
            ),
            LureStatisticsTab(repository: lureStatisticsRepository),
          ],
        ),
      ),
    );
  }
}
```

Catches is listed first, so it is `DefaultTabController`'s default (`initialIndex: 0`) with no extra parameter needed — satisfying MFS-020 FR-1. `LureStatisticsTab` itself receives no new parameter and is otherwise byte-for-byte unchanged.

### Catches tab — `GeneralCatchStatisticsTab`

```text
lib/features/statistics/presentation/widgets/general_catch_statistics_tab.dart
```

A `StatefulWidget`, following the exact `initState` → async load → `setState` pattern `LureStatisticsTab` already established (TD-019), with the same deliberate omission of `AutomaticKeepAliveClientMixin` for the same reason (TD-019 Key Design Decision 8: statistics must be recomputed whenever the tab becomes visible, not preserved).

Load sequence: `await repository.getGeneralCatchStatistics()` → on success, `setState` with the resolved `GeneralCatchStatisticsSummary`; on failure, `setState` with an error message (the same message text `LureStatisticsTab` already uses: "Tilastojen lataaminen epäonnistui." — a generic "loading statistics failed" message, not lure-specific, so reusing it verbatim keeps both tabs' error copy consistent).

Rendering, once loaded (a single `ListView`, matching `LureStatisticsTab`'s structure):

1. Two `StatisticsSummaryCard`s, stacked full-width (total catches, most caught species) — the same layout `LureStatisticsTab` already uses for its own two ranking cards, chosen for the same reason (TD-019's post-physical-testing UI refinement: full width reads better than a cramped multi-column row for text that can be long).
2. A "Suurimmat saaliit" (Top 3 Largest Catches) section: one `RankedLargestCatchRow` per entry in `summary.largestCatches`, numbered by its position in that already-sorted list (rank 1, 2, 3 — see [below](#top-3-largest-catches-row--rankedlargestcatchrow-new)), each wrapping an unmodified `CatchListItem` with `onTap` wired to `CatchDetailsPage.open`, or an inline empty message if `summary.largestCatches.isEmpty`.
3. A "Lajit" (Species List) section: one `SpeciesCatchStatisticRow` per entry in `summary.speciesCatchCounts`, or an inline empty message if `summary.speciesCatchCounts.isEmpty`.

```dart
Future<void> _openCatchDetails(LargestCatch largestCatch) {
  return CatchDetailsPage.open(
    context,
    fishingSpot: largestCatch.fishingSpot,
    catchModel: largestCatch.catchModel,
    catchRepository: widget.catchRepository,
    catchPhotoRepository: widget.catchPhotoRepository,
    lureCatalogRepository: widget.lureCatalogRepository,
    personalTackleBoxRepository: widget.personalTackleBoxRepository,
    personalTackleBoxPhotoStorage: widget.personalTackleBoxPhotoStorage,
  );
}
```

```dart
for (var i = 0; i < summary.largestCatches.length; i++)
  RankedLargestCatchRow(
    key: ValueKey(summary.largestCatches[i].catchModel.id),
    rank: i + 1,
    catchModel: summary.largestCatches[i].catchModel,
    catchPhotoRepository: widget.catchPhotoRepository,
    onTap: () => unawaited(_openCatchDetails(summary.largestCatches[i])),
  ),
```

A plain indexed loop, not `Iterable.indexed` — `summary.largestCatches` is already sorted (Key Design Decision 4), so `i + 1` is exactly the rank to display; no separate ranking computation exists anywhere.

Per [Key Design Decision 9](#key-design-decisions)'s mirror in the empty-state design: as with `LureStatisticsTab`, there is no separate whole-screen empty state — the total card always renders its numeric value (including `0`), the most-caught-species card shows "Ei vielä tietoja" when its getter is `null`, and each list section shows its own inline empty message when its own list is empty.

### Top 3 Largest Catches row — `RankedLargestCatchRow` (new)

```text
lib/features/statistics/presentation/widgets/ranked_largest_catch_row.dart
```

Wraps an unmodified `CatchListItem` with a leading rank badge — see [Key Design Decision 7](#key-design-decisions) for why this is a composition, not a new catch-row widget.

```dart
class RankedLargestCatchRow extends StatelessWidget {
  const RankedLargestCatchRow({
    super.key,
    required this.rank,
    required this.catchModel,
    required this.catchPhotoRepository,
    required this.onTap,
  }) : assert(rank >= 1 && rank <= 3, 'rank must be between 1 and 3');

  final int rank;
  final Catch catchModel;
  final CatchPhotoRepository catchPhotoRepository;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: _RankBadge(rank: rank),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: CatchListItem(
            catchModel: catchModel,
            catchPhotoRepository: catchPhotoRepository,
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rank. sija',
      excludeSemantics: true,
      child: CircleAvatar(
        radius: 14,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          '$rank',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
```

A plain numbered circular badge (`CircleAvatar`, an existing Material widget — no new package, no new icon asset), using the application's existing `colorScheme` rather than a fixed color, so it already adapts to the app's theme the same way every other Material 3 surface in this codebase does. A medal icon or emoji was considered and rejected: this application has no existing emoji-based UI anywhere, and a numbered badge is unambiguous regardless of locale or font support, whereas medal color alone (gold/silver/bronze) can be harder to distinguish for some users — the numeral is always present either way. No fundamentally different treatment is given to first place specifically (per MFS-020's own instruction) — the same `_RankBadge` renders `1`, `2`, or `3` alike.

### Summary card — `StatisticsSummaryCard` (renamed)

```text
lib/features/statistics/presentation/widgets/statistics_summary_card.dart
(renamed from lure_statistics_summary_card.dart; class renamed
LureStatisticsSummaryCard → StatisticsSummaryCard)
```

No behavioral change — see [Key Design Decision 8](#key-design-decisions). Used by both tabs:

* **Total catches** (Catches tab): title "Saaliita yhteensä", value `'${summary.totalCatches}'`.
* **Most caught species** (Catches tab): title "Yleisin laji", value either `'${species.finnishName} (${catchCount} saalista)'` or, when `null`, "Ei vielä tietoja".
* Both existing Lure Statistics cards (TD-019), unchanged in content.

### Species list row — `SpeciesCatchStatisticRow`

```text
lib/features/statistics/presentation/widgets/species_catch_statistic_row.dart
```

Renders one `SpeciesCatchStatistic`: `species.finnishName`, `catchCount`, and a trailing static chevron icon (no tap handling of any kind) signaling future navigation per [Key Design Decision 9](#key-design-decisions). A pure, stateless, `const`-constructible row — no repository access, no navigation, no `InkWell`/`GestureDetector`.

### Loading / Error / Empty summary

| State | Where | Behavior |
|---|---|---|
| Loading | `GeneralCatchStatisticsTab` | Centered `CircularProgressIndicator`, replacing the entire tab body. |
| Load error | `GeneralCatchStatisticsTab` | "Tilastojen lataaminen epäonnistui." plus a "Yritä uudelleen" retry button re-running the load — same copy as `LureStatisticsTab`. |
| No catches logged at all | `GeneralCatchStatisticsTab` | Total card shows `0`; most-caught-species card shows "Ei vielä tietoja"; both list sections show their inline empty message ("Yksikään saalis ei ole vielä punnittu." / "Ei vielä saaliita."). |
| Catches exist, none have a recorded weight | `GeneralCatchStatisticsTab` | Total and most-caught-species cards populate normally; the Top 3 Largest Catches section shows its empty message; the Species List populates normally. |

---

## 6. Navigation

```text
MapScreen (existing temporary entry point, unchanged pattern from TD-015/016/018/019)
        ↓ (existing AppBar action)
StatisticsPage                      [statistics]
        ↓ (DefaultTabController, two tabs, Catches default)
GeneralCatchStatisticsTab           [statistics]
        ↓ (Top 3 Largest Catches entry tapped)
CatchDetailsPage                    [catches, existing, unmodified — MFS-014]
```

`_openStatistics()` in `MapScreen` is updated to construct `GeneralCatchStatisticsRepository` and pass every dependency `StatisticsPage` now requires, threaded from `MapScreen`'s own already-existing repository instances (`_catchRepository`, `_catchPhotoRepository`, `_lureCatalogRepository`, `_personalTackleBoxRepository`, `_tackleBoxPhotoStorage`) — no new repository is constructed there beyond the one new `GeneralCatchStatisticsRepository`. Selecting a Species List row performs no navigation (MFS-020 FR-8).

---

## 7. Accessibility

* Each `CatchListItem` row reused for the Top 3 Largest Catches list already exposes a semantic label for its thumbnail (`'${species.finnishName} kuva'`, MFS-014) and its own accessible content — unchanged by this milestone.
* Each `RankedLargestCatchRow`'s rank badge exposes its own semantic label (`'$rank. sija'`, e.g. "1. sija") separately from `CatchListItem`'s own semantics, so the rank is announced alongside the catch's details, not folded into or lost within them.
* Each `SpeciesCatchStatisticRow` exposes a semantic label combining the species and its catch count. Per MFS-020's Accessibility Expectations and [Key Design Decision 9](#key-design-decisions), it is **not** exposed to assistive technology as a button or other actionable element — only as static content — since it performs no action in this milestone. This is expected to change once a future milestone (MFS-021 Candidate) adds real navigation.
* Each `StatisticsSummaryCard` exposes a semantic label combining its title and value, unchanged from TD-019's existing behavior, now shared by both tabs' cards.
* Empty, loading, and error states are each conveyed accessibly, not only through visual presentation, consistent with TD-019's equivalent requirement.
* Tap targets and text throughout this milestone follow the application's existing Material 3 sizing and text-scaling conventions.

---

## 8. State Management

No Riverpod, no `Provider`, no `InheritedWidget` — consistent with every other feature in this codebase. `GeneralCatchStatisticsTab` is the only new stateful widget this milestone introduces; its state (`_summary`, `_isLoading`, `_errorMessage`) is plain `State` fields, following the exact pattern `LureStatisticsTab` (TD-019) and `PersonalTackleBoxPage` (TD-016) already use.

`StatisticsPage`, `StatisticsSummaryCard`, `RankedLargestCatchRow`, and `SpeciesCatchStatisticRow` are stateless — they render data handed to them and hold no mutable state of their own. `CatchListItem` (reused, `catches`-owned, wrapped by `RankedLargestCatchRow`) keeps its own existing thumbnail-loading state, unchanged.

---

## 9. Error Handling

| Scenario | Behavior |
|---|---|
| `getGeneralCatchStatistics()` throws (e.g. a database read error) | Caught in `GeneralCatchStatisticsTab._load()`; the tab shows a clear error message plus a retry action; the application does not crash. |
| Retry after a load failure | Tapping "Yritä uudelleen" re-runs `_load()` from scratch; no partial or stale data is shown while the retry is in flight. |
| A catch's photo fails to resolve | Unchanged — `CatchListItem`'s existing `FutureBuilder`/placeholder handling (MFS-014) applies exactly as it already does in the fishing-spot-scoped catch list; this milestone introduces no new photo-resolution code. |
| `CatchDetailsPage.open` is invoked for a catch whose fishing spot cannot be re-resolved (should not occur — `FishingSpots.id` is never deleted out from under an existing `Catches.fishingSpotId` without cascading catch deletion first, per MFS-008) | Not applicable by construction: `LargestCatch.fishingSpot` is resolved in the same query that produced `LargestCatch.catchModel`, from the same still-open transactionless read, so the two are always consistent with each other at the moment they are displayed. |

---

## 10. Empty and Loading States

Covered in full in [§5](#loading--error--empty-summary). Summary: a single centered `CircularProgressIndicator` for loading; a single error message plus retry for failure; per-card and per-section empty handling (no dedicated whole-screen empty widget) for the no-data cases, mirroring TD-019's Key Design Decision 9 exactly.

---

## 11. Performance Considerations

**Query count:** exactly one per `getGeneralCatchStatistics()` call — regardless of how many catches, species, or fishing spots exist. Never one query per catch, never one per species (no N+1), matching the discipline already established across every repository in this codebase.

**Aggregation cost:** O(n) over every catch, using a single linear pass with `Map`-based species accumulation and a filtered `List` build for weighted catches — no nested loops, no repeated scans. A single user's own catch history is expected to remain small for the lifetime of this application on a single device (see [Key Design Decision 3](#key-design-decisions)).

**Sorting cost:** O(w log w) over the number of weighted catches (`w`, bounded above by `n`) for the largest-catch sort, and O(s log s) over the number of distinct species (`s`, bounded above by `n`) for the species sort — both using explicit multi-key comparators, never relying on sort stability.

**No caching.** Every open of the Catches tab re-runs the query and recomputes from scratch, per MFS-020 FR-10 and the same deliberate choice TD-019 already made not to preserve tab state across visits.

**Photo loading:** unchanged from the existing catch list — `CatchListItem`'s own thumbnail resolution and `LureImage`-equivalent caching discipline apply exactly as they already do (MFS-013/MFS-014), reused, not reimplemented.

**List rendering:** the Top 3 Largest Catches list is capped at three rows by construction (no virtualization needed). The Species List renders via a plain `ListView`/inline `for` loop, matching `LureStatisticsTab`'s existing discipline; given the expected scale of a single user's catch history (at most as many species as `FishSpecies` has values), this is a consistency choice, not a scale-driven necessity.

---

## 12. Testing Strategy

Follows the same layered testing philosophy as TD-019: domain tests for construction/assertions/getters, repository tests for query and aggregation behavior against a real in-memory database, widget tests for the presentation surfaces, and a physical-device pass at the end. No migration test is needed — this milestone changes no schema.

**Domain** (`test/features/statistics/domain/`):
`largest_catch_test.dart` — valid construction; rejects a `catchModel` with no recorded weight. `species_catch_statistic_test.dart` — valid construction; rejects `catchCount <= 0`. `general_catch_statistics_summary_test.dart` — `mostCaughtSpecies` returns the first list element when non-empty and `null` when empty; rejects a negative `totalCatches`; rejects more than three `largestCatches` entries.

**Repository** (`general_catch_statistics_repository_test.dart`, against `AppDatabase(NativeDatabase.memory())`, seeded directly via Drift inserts, mirroring `lure_statistics_repository_test.dart`'s setup):

* no catches at all → `totalCatches == 0`, `largestCatches`/`speciesCatchCounts` both empty
* one catch with a recorded weight → appears in `largestCatches` with its fishing spot correctly resolved
* a catch with no recorded weight never appears in `largestCatches`, but still contributes to `totalCatches` and `speciesCatchCounts`
* more than three weighted catches → only the top three appear, in weight-descending order
* a tie in weight between two catches resolves deterministically and matches the documented comparator (weight descending → `caughtAt` descending → `createdAt` descending → id ascending)
* multiple catches of the same species → `speciesCatchCounts` sums them correctly
* a tie in catch count between two species resolves deterministically by species identifier ascending
* `mostCaughtSpecies` matches the top of `speciesCatchCounts`
* two catches at two different fishing spots each resolve to their own correct `FishingSpot` in `largestCatches` (not swapped or duplicated)
* deleting a catch (simulated via direct row deletion) changes `totalCatches`/`speciesCatchCounts`/`largestCatches` on the next call, with no stale data

**Widget** (`test/features/statistics/presentation/widgets/`):
`general_catch_statistics_tab_test.dart` (against a real in-memory `AppDatabase`/`GeneralCatchStatisticsRepository`, mirroring `lure_statistics_tab_test.dart`'s setup and its `_PendingRepository`/`_FailingRepository`/`_FailOnceRepository`/`_StaticRepository` fakes) — loading indicator shown while pending; error message and retry shown on failure, and retry re-attempts the load; fully-empty state renders the total as `0`, the most-caught-species card as "Ei vielä tietoja", and both list sections showing their empty message; a populated summary renders both cards and both lists in the given (already-sorted) order; **a populated Top 3 Largest Catches list shows rank badges `1`, `2`, `3` attached to the correct catch in list order (verified against `summary.largestCatches`' own order, not re-derived independently in the test)**; tapping a Top 3 Largest Catches entry (including tapping through its rank badge's row) opens `CatchDetailsPage` for the correct catch and fishing spot; tapping a Species List row performs no navigation. `ranked_largest_catch_row_test.dart` — renders the given rank (`1`/`2`/`3`) as a badge alongside the wrapped `CatchListItem`'s own content; the badge exposes a `'$rank. sija'` semantic label; tapping the row (via the wrapped `CatchListItem`) invokes `onTap`; rejects a `rank` outside `1..3`. `species_catch_statistic_row_test.dart` — renders the species name and count; exposes no button semantics. `statistics_summary_card_test.dart` — renamed/retained from `lure_statistics_summary_card_test.dart`, asserting against the renamed class, otherwise unchanged. `statistics_page_test.dart` — both tabs render in the correct order (Catches first, Lure Statistics second), and the Catches tab is the default.

**Regression:** `lure_statistics_tab_test.dart` continues to pass unmodified in behavior — only its import of the renamed `StatisticsSummaryCard` changes, per [Key Design Decision 8](#key-design-decisions).

**Integration/physical Android testing:**
open Statistics from the existing `MapScreen` entry point and confirm it opens to the Catches tab; verify the summary cards, Top 3 Largest Catches list, and Species List against a real, previously-logged set of catches spanning multiple fishing spots and species; tap a Top 3 Largest Catches entry and confirm Catch Details opens for the correct catch; verify the empty state on a fresh install with no catches; verify switching to the Lure Statistics tab still works exactly as before; verify full offline/airplane-mode operation.

---

## 13. Risks

| Risk | Category | Mitigation |
|---|---|---|
| Reusing `CatchListItem` (wrapped in the new `RankedLargestCatchRow`) couples the Catches tab to a `catches`-owned presentation widget, rather than a `statistics`-owned one. | Architectural | Accepted and explicitly approved during review — see [Architecture Review — Approved Decisions](#architecture-review--approved-decisions). `CatchListItem`'s contract (`catchModel`, `catchPhotoRepository`, `onTap`) is already minimal, stable, and has no fishing-spot-specific assumption baked in; `RankedLargestCatchRow` only wraps it, never modifies or forks it. |
| Renaming `LureStatisticsSummaryCard` → `StatisticsSummaryCard` touches an already-shipped, tested file. | Maintainability | Low risk: exactly one existing production caller (`LureStatisticsTab`) and one existing test file, both explicitly listed in [Expected Files To Modify](#expected-files-to-modify). |
| `StatisticsPage`'s constructor grows to seven parameters. | Maintainability | Matches the already-accepted `LureToolsPage` (TD-016) precedent for the same reason — a thin composing shell threading dependencies to the tabs it hosts, not a new pattern this milestone introduces (Key Design Decision 10). |
| The one joined query fetches every catch's fishing spot data, even for the vast majority of catches that will never appear in `largestCatches`. | Performance | Accepted at this application's scale (see [§11](#11-performance-considerations)): the join itself is a single indexed lookup per row (`Catches.fishingSpotId` is a foreign key), and discarding the unused `FishingSpot` decode for non-weighted catches (done inline, only when `weightGrams != null`) avoids the one avoidable cost. |

---

## 14. Future Compatibility

* **Species Statistics** (MFS-021 Candidate, `docs/roadmap.md`) — `SpeciesCatchStatisticRow` already renders the future affordance (Key Design Decision 9); wiring it would add an `onTap` there and a new destination page, with no change to `GeneralCatchStatisticsRepository`'s existing query or return shape.
* **Including zero-catch species in the Species List** (MFS-020 Future Extensions) — would require iterating `FishSpecies.values` instead of only the species seen in `speciesCounts`, defaulting absent ones to `0`. An additive change to `getGeneralCatchStatistics()`'s method body, not a redesign of its return shape.
* **Filtering these statistics** (e.g. by date range or fishing spot) — the existing `_catchesWithFishingSpot()` join already has access to every relevant column; a filter would add a `.where(...)` clause to that one query, with no change to the aggregation or sorting logic that follows it.
* **Cloud synchronization** — unaffected. This feature is entirely read-only over data owned elsewhere; nothing here touches the repository-hides-the-data-source principle (ADR-0001, ADR-0005) that already governs `catches`' and `fishing_spots`' own data layers.

---

## Dependencies

No new external package dependencies. This milestone reuses the existing stack and patterns:

* Flutter, Dart
* Drift (per ADR-0005) — read-only queries against existing tables only; no schema change
* The existing Repository pattern, feature-first structure, and manual dependency construction (ADR-0001, ADR-0003, ADR-0006)
* The existing `Catch` domain model and `CatchMapper` (MFS-009/TD-009), consumed read-only, unmodified
* The existing `FishingSpot` domain model and `FishingSpotEntityMapper` extension (MFS-004), consumed read-only, unmodified
* `CatchListItem`, `CatchPhotoThumbnail`, `formatCatchMeasurementLine`, `FishSpecies.finnishName` (MFS-013/MFS-014), reused unchanged
* `CatchDetailsPage.open()` (MFS-014), reused unmodified as this milestone's navigation target
* The Statistics feature's tabbed shell and presentation conventions already established by MFS-019/TD-019

`flutter_riverpod` is not used by this feature, for the same reasons documented in TD-015/TD-016/TD-017/TD-018/TD-019.

---

## Expected Files To Create

```text
lib/features/statistics/domain/largest_catch.dart
lib/features/statistics/domain/species_catch_statistic.dart
lib/features/statistics/domain/general_catch_statistics_summary.dart
lib/features/statistics/data/general_catch_statistics_repository.dart
lib/features/statistics/presentation/widgets/general_catch_statistics_tab.dart
lib/features/statistics/presentation/widgets/ranked_largest_catch_row.dart
lib/features/statistics/presentation/widgets/species_catch_statistic_row.dart
```

Plus new test files under `test/features/statistics/...` per [§12](#12-testing-strategy).

## Expected Files To Rename

```text
lib/features/statistics/presentation/widgets/lure_statistics_summary_card.dart
    → lib/features/statistics/presentation/widgets/statistics_summary_card.dart
    (class LureStatisticsSummaryCard → StatisticsSummaryCard; see Key Design Decision 8)

test/features/statistics/presentation/widgets/lure_statistics_summary_card_test.dart
    → test/features/statistics/presentation/widgets/statistics_summary_card_test.dart
    (assertions updated in place for the renamed class; no behavioral change)
```

Confirm at implementation time that `LureStatisticsTab` is the only production caller of `LureStatisticsSummaryCard` before renaming it (per this document's review, it is).

## Expected Files To Modify

```text
lib/features/statistics/presentation/widgets/statistics_page.dart       (two tabs; seven constructor parameters — see §5)
lib/features/statistics/presentation/widgets/lure_statistics_tab.dart   (import/reference the renamed StatisticsSummaryCard only — no other change)
lib/features/map/presentation/map_screen.dart                          (construct GeneralCatchStatisticsRepository; update _openStatistics to pass every StatisticsPage dependency)
test/features/statistics/presentation/widgets/lure_statistics_tab_test.dart   (no behavioral change expected; confirm the renamed import compiles)
test/features/statistics/presentation/widgets/statistics_page_test.dart      (constructor signature changed — update to the new two-tab shape and assert tab order)
```

Modify generated Drift files only through code generation — none are expected to change, since no schema changes are made.

---

## Database Impact

**None.** No new Drift table, no new column, no schema version change, no migration. The schema version remains at `6`, as established by TD-017. `GeneralCatchStatisticsRepository` reads the existing `Catches` and `FishingSpots` tables through a single, read-only join query — nothing about `AppDatabase`'s table registration, migration strategy, or schema version changes.

Confirm at implementation time that the live schema version is still `6` before beginning, consistent with the same hedge every prior TD in this project has required.

---

## Test Impact

* **New tests:** every domain, repository, and widget test file listed in [§12](#12-testing-strategy) that does not already exist.
* **Renamed, not rewritten:** `lure_statistics_summary_card_test.dart` → `statistics_summary_card_test.dart` — assertions updated to the new class name only, no behavioral change ([Expected Files To Rename](#expected-files-to-rename)).
* **Updated for a changed constructor signature:** `statistics_page_test.dart` (new required parameters, two-tab assertions) and `lure_statistics_tab_test.dart` (renamed import only).
* **Untouched:** every `catches`, `catch_photos`, `fishing_spots`, `lure_catalog`, and `personal_tackle_box` test file, and every existing `lure_statistics_repository_test.dart`/domain test in `statistics`, since none of that code changes.

---

## Implementation Notes

No architectural deviations from this document were required in production code. Three rounds of presentation-only refinement were made after physical Android testing of the original design (§5's plain `StatisticsSummaryCard` stack and `RankedLargestCatchRow`'s small left-side `CircleAvatar` badge). None changed `GeneralCatchStatisticsRepository`, any domain model, navigation, or `CatchListItem`, which remains reused completely unchanged throughout.

### Presentation refinement: Equal-height summary cards

**What changed.** The two `StatisticsSummaryCard`s at the top of the Catches tab are wrapped in `IntrinsicHeight` with `CrossAxisAlignment.stretch` (previously `.start`), so both cards always share the taller card's height regardless of how much text either one holds.

**Why.** Physical Android testing showed the two cards rendering at visibly different heights whenever the "most caught species" value was long — an uneven, unbalanced grid appearance.

**What did not change.** `StatisticsSummaryCard` itself is untouched; the fix is entirely in `GeneralCatchStatisticsTab`'s call site, per this document's own "no unnecessary abstractions" principle — no new summary card widget was introduced.

### Presentation refinement: "Hall of Fame" redesign of the Top 3 Largest Catches list

**What changed.** `RankedLargestCatchRow` (§5) was redesigned twice after physical Android testing, converging on the following final design:

* The small left-side `CircleAvatar` badge next to `CatchListItem` was removed. `CatchListItem` itself remains completely unmodified and unmoved — it is still the sole widget rendering photo, species, weight, length, and date, and its `onTap` still opens Catch Details exactly as originally designed (Key Design Decision 7).
* Each entry is now a `Card` with a full, medal-colored border — gold for 1st, silver for 2nd, bronze for 3rd — instead of a colored badge sitting beside a plain row.
* The rank number is a small circular badge that floats above the card, centered horizontally, overlapping the card's top border by half its own height ("the card wearing its rank"). This is built with `Stack(alignment: Alignment.topCenter)` around two *non-positioned* children — the badge, and the card wrapped in `Padding(top: badgeRadius)` — rather than a `Positioned` widget with a negative offset. Because both children are aligned (not manually offset), the badge's space is genuinely reserved in layout and can never paint over a neighboring card or the section header above it.
* 1st place is modestly more prominent: a thicker border (3px vs. 2px), higher elevation (4 vs. 1), slightly larger badge and internal padding, and — after the final refinement round — a very subtle warm-tinted card background, produced by blending the medal gold color at 6% alpha onto `colorScheme.surface` (`Color.alphaBlend`), replacing an earlier, less deliberate `colorScheme.surfaceContainerHigh` tint. The blend is theme-derived (adapts to light/dark mode) rather than a fixed literal background.
* The medal gold border color was brightened from an initial dark goldenrod (`0xFFB8860B`) to Material Amber 700 (`0xFFFFA000`), reading clearly as "gold" rather than "bronze."
* Each card is centered on the page via `Center` + `ConstrainedBox(maxWidth: 560)`, removing the visual left-alignment the old badge implied. On typical phone widths this has no visible effect, since the card already fills the available width.
* No emoji and no trophy icon are used anywhere, per this document's original rationale for a plain numbered badge (Key Design Decision 7) — only the number and the medal-colored border/badge communicate rank.

**Why.** Physical Android testing found the original left-side numbered badge visually weak and the Top 3 section too similar to an ordinary list, not distinct enough from the rest of the page.

**Accessibility preserved.** The badge's `Semantics(label: '$rank. sija', excludeSemantics: true)` is unchanged in content from the original design — it still exposes "1. sija"/"2. sija"/"3. sija" (§7). One fix was required to preserve it: `Card`'s implicit `semanticContainer: true` was found to merge the badge's label into `CatchListItem`'s own tap-semantics node once the badge moved inside the `Card`. Adding `container: true` to the badge's own `Semantics` widget restores it as an independent semantics node, verified via `debugDumpSemanticsTree()` and the existing `bySemanticsLabel('$rank. sija')` test.

**Testing.** `ranked_largest_catch_row_test.dart` and `general_catch_statistics_tab_test.dart` (§12) were updated to assert against the new structure — badge background color and card border color/width/elevation distinctness per rank, equal-height/side-by-side summary card layout, and a narrow-screen (320px) render with no overflow — in addition to the pre-existing rank, semantics, and navigation assertions, all of which continue to pass unchanged in intent.

---

## Implementation Notes for Claude Code

* **Confirm the live schema version is `6` before starting** — if it has moved past `6` since this document was written, nothing in this design changes.
* **Do not touch `lib/core/database/app_database.dart`.** This milestone reads two already-registered tables directly; no table registration, schema version, or migration changes.
* **Do not modify anything under `lib/features/catches/`, `lib/features/catch_photos/`, `lib/features/fishing_spots/`, `lib/features/lure_catalog/`, or `lib/features/personal_tackle_box/`.** This design reads their tables/domain models and reuses `CatchMapper`, `FishingSpotEntityMapper`, `CatchListItem`, `CatchPhotoThumbnail`, and `CatchDetailsPage.open()` exactly as they exist today.
* **The rename in [Expected Files To Rename](#expected-files-to-rename) is a plain rename-in-place**, not a new widget: `LureStatisticsSummaryCard`'s body does not change, only its file name, class name, and the one import/call site that uses it.
* **`CatchListItem` itself is reused as-is — do not fork it or add fields to it.** Its `onTap` callback is where this milestone's Catch Details navigation is wired. The rank badge is a *separate*, wrapping widget (`RankedLargestCatchRow`, [§5](#top-3-largest-catches-row--rankedlargestcatchrow-new)) composed around an unmodified `CatchListItem` — do not add rank-related parameters to `CatchListItem` itself.
* **`GeneralCatchStatisticsRepository` must not call `CatchRepository`, `FishingSpotRepository`, or `CatchPhotoRepository`'s instance methods.** It reads `Catches`/`FishingSpots` directly via its own query, per [Key Design Decision 2](#key-design-decisions).
* **All user-visible text is Finnish**, per this project's Development Rules. Suggested strings are given throughout [§5](#5-presentation-layer) — reuse them as given (in particular, reuse "Tilastojen lataaminen epäonnistui." and "Yritä uudelleen" verbatim, matching the existing Lure Statistics tab's wording) rather than inventing new phrasing.
* **The tie-break comparators in [§4](#4-data-layer) must be applied unconditionally**, not only when a tie is manually observed — Dart's `List.sort` is not guaranteed stable.
* **Run the full validation sequence below before considering this done**, and update this document's own `Status`, `Implementation Notes`, and `Definition of Done` sign-off the same way every prior TD in this project has.
* **Do not update `docs/project-status.md` or `docs/roadmap.md`** as part of this TD's implementation — that happens as a separate, later step per this project's own Development Workflow.

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

All criteria below are satisfied as of the completed implementation (see Status).

* The implementation satisfies all requirements in MFS-020.
* The implementation follows TD-020, or documents and justifies each deviation.
* The Statistics feature shows two tabs, Catches first and Lure Statistics second, with Catches as the default.
* The Top 3 Largest Catches list shows up to three catches, ordered by weight descending, with deterministic tie-breaking, excluding any catch with no recorded weight.
* Each Top 3 Largest Catches entry visibly shows its rank (1/2/3) via `RankedLargestCatchRow`'s floating, medal-colored badge, so first/second/third place is immediately distinguishable without reading catch details.
* Selecting a Top 3 Largest Catches entry opens the existing Catch Details view for the correct catch and its correct fishing spot.
* The total catches and most caught species summary cards show correct values, with a clear "no data yet" state where applicable, and render at equal height.
* The Species List shows every species present in the user's catch history, with correct counts, sorted by catch count descending, with deterministic tie-breaking.
* Species List rows are visually distinct as future-navigable but perform no action when tapped, and are not exposed as buttons to assistive technology.
* Statistics are computed fresh on every load — no cached, stored, or persisted aggregate exists anywhere.
* No new Drift table, column, schema version, or migration was introduced.
* `catches`, `catch_photos`, `fishing_spots`, `lure_catalog`, and `personal_tackle_box` are functionally and structurally unchanged; the Lure Statistics tab is functionally unchanged.
* Every capability works with no network connection.
* `dart format .`, `flutter analyze`, and `flutter test` all pass (535/535 tests, 8 pre-existing/accepted info-level lints).
* Architecture review is completed.
* Physical Android testing is completed, including verification of the three post-testing presentation refinements recorded in [Implementation Notes](#implementation-notes).
* Documentation (`docs/project-status.md`, `docs/roadmap.md`) is updated in a separate, subsequent step — not part of this document's own completion.
