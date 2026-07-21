# TD-022 — Fishing Spot Statistics

## Status

Draft

## Related Specification

* MFS-022: Fishing Spot Statistics

---

## Goal

Implement MFS-022: a new Fishing Spot List within the Catches tab, and a new, pushed Fishing Spot Statistics page reached from it — a header (fishing spot name, total catches, Last Catch Date), a Record Catch section, a Species Breakdown, and a full Catch List — all computed live from existing `Catch`/`CatchPhoto`/`FishingSpot` data, with no new database table, no schema migration, and no change to the `catches`, `catch_photos`, or `fishing_spots` features.

This document is the direct continuation of TD-021: wherever TD-021 already answered a question this milestone shares (deterministic ordering, Record Catch derivation, post-navigation refresh, missing-value rendering), this document reuses that answer rather than re-deriving it. Where MFS-022's own shape differs from MFS-021's — a Fishing Spot List that has to be built, not only wired; a Record Catch card that shows species instead of location; a Species Breakdown that must stay static — this document says so explicitly and explains why.

The implementation shall satisfy MFS-022.

---

## Scope

Implement:

* a new, minimal `FishingSpotStatisticsRepository` — the simplest repository in the Statistics feature, reading only `Catches` filtered by fishing spot id, no join
* two new read-only domain/read-model types: a fishing spot statistics summary, and a fishing spot paired with its catch count
* an additive extension to the existing `GeneralCatchStatisticsRepository`/`GeneralCatchStatisticsSummary` (MFS-020/TD-020): a Fishing Spot List, computed from the same query that already runs, with no new query
* `FishingSpotStatisticsPage`: a header (name, total, Last Catch Date), a `FishingSpotRecordCatchCard`, a static Species Breakdown, and a Catch List reusing `CatchListItem` unmodified
* a generalized, reused row widget for every "label + catch count [+ tap]" list row in this feature (Species List, Species Breakdown, Fishing Spot List) — a rename-in-place of `SpeciesCatchStatisticRow`, mirroring the precedent TD-018 and TD-020 already set for exactly this kind of generalization
* the post-Catch-Details refresh pattern TD-021 had to retrofit, applied to `FishingSpotStatisticsPage` from the start
* loading, empty, and error states
* accessibility labeling
* tests

Do **not** implement:

* any new Drift table, column, or schema migration
* any cached, stored, or persisted statistic of any kind
* averages, totals, or any other derived arithmetic aggregate (MFS-022 Out of Scope)
* charts, graphs, filters, searching, exporting, map interaction, or AI recommendations of any kind
* first catch date (MFS-022 explicitly excludes it; only Last Catch Date is in scope)
* navigation from a Species Breakdown row to Species Statistics (a named future extension, not this milestone)
* any change to `GeneralCatchStatisticsRepository`'s or `SpeciesStatisticsRepository`'s existing public contracts, only additive internal changes where MFS-022 requires them
* any change to `LureStatisticsRepository` or the Lure Statistics tab
* editing or deleting fishing spots, or any change to `fishing_spots`' domain model, schema, or repository contract
* a service layer, use-case layer, DAO layer, or repository interface of any kind
* Riverpod, Provider, reactive Drift streams (`watch()`), or any new state-management mechanism

---

## Key Design Decisions

This section answers the questions most likely to be raised in review, before the detailed sections implement them.

**1. `SpeciesCatchStatisticRow` is generalized into `CatchCountRow`, a rename-in-place, not a new parallel widget.** MFS-022 needs the exact "label, catch count, optional chevron, optional tap" shape in *three* places: the existing whole-history Species List (MFS-020/021, interactive), the new Fishing Spot List (MFS-022, interactive), and the new per-fishing-spot Species Breakdown (MFS-022, deliberately static). `SpeciesCatchStatisticRow` already renders exactly this shape, but is typed to `SpeciesCatchStatistic` and — since MFS-021 — always requires a non-null `onTap`. Rather than forking a second near-identical row, this document renames it in place to `CatchCountRow`, taking a plain `label`/`catchCount` pair instead of a domain-typed `statistic`, with `onTap` made nullable (`VoidCallback?`): non-null renders exactly as it does today (a real, accessible button); null renders exactly as this same widget did *before* MFS-021 made it mandatory (static, no button semantics). This mirrors two precedents already established in this project — TD-018's `LureCatalogListItem` → `LureCatalogModelListItem` and TD-020's `LureStatisticsSummaryCard` → `StatisticsSummaryCard`, both "rename in place once a widget's real scope outgrows its original name, not a new abstraction." Three real call sites is the threshold this project has already used twice to justify exactly this move.

**2. `FishingSpotStatisticsRepository` reads no join at all — it is the simplest repository in this feature.** `SpeciesStatisticsRepository` needs `Catches INNER JOIN FishingSpots` because catches of one species are scattered across many fishing spots, so each returned catch needs its *own* resolved `FishingSpot`. That reasoning does not apply here: every catch this repository returns already shares the *one* fishing spot the page was opened for, and the page already holds that `FishingSpot` object directly (passed in at navigation time, per MFS-022's Conceptual Model — "the fishing spot's identity is established when the page opens"). `FishingSpotStatisticsRepository` therefore reads `Catches` alone, filtered by `fishingSpotId`, and never touches the `FishingSpots` table. This is a genuine simplification discovered while designing this document, not an assumption carried over from TD-021 — see [§4](#4-data-layer).

**3. `FishingSpotStatisticsSummary.catches` is a plain `List<Catch>` — no wrapper entry type is introduced.** `SpeciesStatisticsSummary` needed `SpeciesCatchEntry` (a `Catch` paired with its own `FishingSpot`) specifically because different catches of one species can belong to different fishing spots. Here, every catch already belongs to the one fishing spot the page already knows, so pairing each catch with a `FishingSpot` would duplicate information the page already has. `FishingSpotStatisticsPage` opens `CatchDetailsPage` using its own already-known `widget.fishingSpot` for every entry, not a per-catch one. This is fewer new types than MFS-021 needed, not a coincidence — it falls directly out of Key Design Decision 2.

**4. The Species Breakdown reuses the existing `SpeciesCatchStatistic` domain type (MFS-020/TD-020) unmodified — no new domain type for it.** `SpeciesCatchStatistic` is already exactly "a species paired with its catch count." Rescoping it to one fishing spot's catches instead of the whole history changes nothing about its shape.

**5. Last Catch Date is computed in the same single pass that already builds the sorted Catch List and the Species Breakdown — no second query, no second scan of the data.** Every catch is already visited once to (a) accumulate species counts and (b) collect the list that gets sorted for the Catch List. Tracking the maximum `caughtAt` seen during that same pass costs one comparison per catch, not a new pass over the data. It is stored as an explicit field on `FishingSpotStatisticsSummary` (not a getter over `catches`) because `catches` is sorted by weight, not by date, so `catches.first.caughtAt` would not generally be the correct answer.

**6. The Fishing Spot List costs zero new queries in `GeneralCatchStatisticsRepository`.** Its existing `_catchesWithFishingSpot()` join already returns every catch's row *and* its joined `FishingSpot` row — that query already has everything a per-fishing-spot count needs. The only change is that the existing aggregation loop, which currently resolves `FishingSpot` only for catches that have a recorded weight (to build `LargestCatch`), now resolves it unconditionally, and accumulates a second `Map<String, ...>` (fishing spot id → running count/reference) alongside the existing species-count map. One query, one pass, two more small pieces of bookkeeping — not a second query.

**7. The catch-ordering comparator is duplicated between `SpeciesStatisticsRepository` and `FishingSpotStatisticsRepository`, not extracted into a shared helper.** Both repositories now need "weight descending (missing last), then catch date descending, then id ascending." This is tempting to unify, but this document deliberately does not, for the same reason TD-021's Key Design Decision 9 already accepted an equivalent small duplication (private thumbnail-loading logic) rather than extracting a shared helper for a second caller: the comparator is small (four lines), private to each file, and extracting it would add a new shared module for a saving of a few lines. If a *third* repository ever needs this exact ordering, that is the point to extract it, not before.

**8. Record Catch needs a new, small widget, `FishingSpotRecordCatchCard` — generalizing the existing `RecordCatchCard` was considered and rejected.** MFS-022's Conceptual Model is explicit that Record Catch here shows species (which varies per catch) instead of location (which is now redundant, since it's the page's own context) — the mirror image of MFS-021's own card. This is not a single substitutable field: the two cards differ in *which* field appears and in its *prominence* (species reads as a headline, alongside/before the measurement line; location in MFS-021 is a subdued trailing line). Parameterizing one widget to conditionally render either shape would need more conditional branching in the widget itself than two small, purpose-built ones cost in total. `FishingSpotRecordCatchCard` duplicates `RecordCatchCard`'s thumbnail-loading pattern a third time (after `CatchListItem`), which is the same accepted trade-off TD-021 already recorded, not a new one.

**9. `FishingSpotStatisticsPage` applies TD-021's post-Catch-Details refresh pattern from the start, not as a later fix.** TD-021 shipped once, found (via lifecycle review) that returning from Catch Details left the page stale, and fixed it by reusing `FishingSpotDetailsBottomSheet`'s existing convention: `await CatchDetailsPage.open(...); if (!mounted) return; await _load();`. That lesson is already known, so this document specifies it as the original design for `FishingSpotStatisticsPage._openCatchDetails`, not a retrofit — no lifecycle bug is expected to need a follow-up fix here.

**10. The header's two summary values (total catches, Last Catch Date) reuse two side-by-side `StatisticsSummaryCard`s, not one card with a secondary value.** `StatisticsSummaryCard` already supports a `title`/`value`/`secondaryValue` shape (used for the Catches tab's "most caught species" card, where the secondary value elaborates on the primary one). Total catches and Last Catch Date are not a primary/elaboration pair — they are two independent facts. The Catches tab's own existing equal-height, side-by-side two-card row (`IntrinsicHeight` + `Row` + `Expanded`, TD-020 §5) already exists for exactly this shape and is reused here unchanged, rather than reusing the differently-shaped primary/secondary pattern from a conceptually different card.

---

## 1. Overview

`statistics` is extended a third time. Nothing TD-019/TD-020/TD-021 already built is restructured.

| Feature | Responsibility in this milestone |
|---|---|
| `statistics` (extended) | Gains `FishingSpotStatisticsRepository`, two new read-model types, `FishingSpotStatisticsPage`/`FishingSpotRecordCatchCard`, a renamed-in-place shared row widget (`CatchCountRow`), and an additive extension to `GeneralCatchStatisticsRepository`/`GeneralCatchStatisticsSummary`/`GeneralCatchStatisticsTab`. `SpeciesStatisticsRepository`, `SpeciesStatisticsPage`, `RecordCatchCard`, `LureStatisticsRepository`, and every other TD-019/020/021 file not named above are unmodified. |
| `catches` (unmodified) | Continues to own `Catch`/`CatchRepository`/the `Catches` table, and `CatchListItem`, reused unchanged — its fourth reuse across the Statistics feature. |
| `fishing_spots` (unmodified) | Continues to own `FishingSpot`/`FishingSpotRepository`/the `FishingSpots` table. `statistics` already reads this table directly (TD-020); this milestone reads it *less*, not more — see Key Design Decision 2. |
| `catch_photos` (unmodified, read from presentation only) | Neither new repository reads it; photo resolution for both the Fishing Spot List's destination page and the Catch List is a presentation-layer concern, exactly as already established. |

**One new repository instance is required.** `MapScreen` already constructs `AppDatabase` and every repository this milestone needs to reuse. This document adds exactly one more manually-constructed repository, `FishingSpotStatisticsRepository(_database)`, alongside the existing ones.

---

## 2. Folder Structure

```text
lib/features/statistics/
  domain/
    fishing_spot_statistics_summary.dart      (new)
    fishing_spot_catch_statistic.dart         (new)
    species_catch_entry.dart                  (unchanged, TD-021)
    species_statistics_summary.dart           (unchanged, TD-021)
    largest_catch.dart                        (unchanged, TD-020)
    species_catch_statistic.dart              (unchanged, TD-020 — reused directly by this milestone's Species Breakdown)
    general_catch_statistics_summary.dart     (modified — one new field)
    lure_catch_statistic.dart                 (unchanged, TD-019)
    lure_type_catch_statistic.dart            (unchanged, TD-019)
    lure_statistics_summary.dart              (unchanged, TD-019)
    lure_distinguishing_detail.dart           (unchanged, TD-019)
  data/
    fishing_spot_statistics_repository.dart   (new)
    general_catch_statistics_repository.dart  (modified — additive aggregation, no new query)
    species_statistics_repository.dart        (unchanged, TD-021)
    lure_statistics_repository.dart           (unchanged, TD-019)
  presentation/
    widgets/
      fishing_spot_statistics_page.dart       (new)
      fishing_spot_record_catch_card.dart     (new)
      catch_count_row.dart                    (renamed from species_catch_statistic_row.dart)
      statistics_page.dart                    (modified — one new constructor parameter)
      general_catch_statistics_tab.dart       (modified — one new constructor parameter, Fishing Spot List section)
      species_statistics_page.dart            (unchanged, TD-021)
      record_catch_card.dart                  (unchanged, TD-021)
      ranked_largest_catch_row.dart           (unchanged, TD-020)
      statistics_summary_card.dart            (unchanged, TD-019/020 — reused a fourth time)
      lure_statistics_tab.dart                (unchanged, TD-019)
      lure_catch_statistic_row.dart           (unchanged, TD-019)
      lure_type_catch_statistic_row.dart      (unchanged, TD-019)
```

No `data/local/` (no table), no dedicated mapper file — `FishingSpotStatisticsRepository` reuses the already-public `CatchMapper` directly, and needs no mapper of its own since it never reads `FishingSpots`. Exact widget file separation may be adjusted if a smaller structure is clearer, consistent with the same allowance given in every prior TD in this project.

---

## 3. Domain Layer

### FishingSpotCatchStatistic

One fishing spot paired with how many catches the angler has logged there. Backs the new Fishing Spot List within the Catches tab, the same "reference domain object, plus a count" shape `SpeciesCatchStatistic` already established:

```text
FishingSpotCatchStatistic
  fishingSpot: FishingSpot   — reused by reference, never duplicated
  catchCount: int            — must be > 0 (a fishing spot with no catches never appears)
```

`fishingSpot` reuses `fishing_spots`' own `FishingSpot` directly. Carrying the full object (not just an id/name pair) is deliberate: tapping a Fishing Spot List row opens `FishingSpotStatisticsPage`, which needs a real `FishingSpot` instance for its own header — the same "reference, not copy" discipline already established for `LargestCatch.fishingSpot` and `SpeciesCatchEntry.fishingSpot`.

### FishingSpotStatisticsSummary

The complete, read-only result of computing one fishing spot's statistics at a single point in time. Nothing here is ever persisted (MFS-022 FR-12).

```text
FishingSpotStatisticsSummary
  catches: List<Catch>                          — every catch at the fishing spot, sorted per §4; never capped
  speciesCatchCounts: List<SpeciesCatchStatistic> — every species caught there, sorted by count descending, deterministic tiebreak (reused type, TD-020)
  lastCatchDate: DateTime?                        — the most recent caughtAt among catches; null when catches is empty

  totalCatches: int            (getter) → catches.length
  recordCatch: Catch?          (getter) → catches.isEmpty ? null : catches.first
```

Per Key Design Decisions 3 and 5: `catches` needs no wrapper type (unlike `SpeciesStatisticsSummary.catches`), and `lastCatchDate` is a stored field, not a getter, because `catches`' own sort order is by weight, not by date.

### general_catch_statistics_summary.dart (modified)

`GeneralCatchStatisticsSummary` gains one new field, additive to its existing three:

```text
GeneralCatchStatisticsSummary  (existing fields unchanged: totalCatches, largestCatches, speciesCatchCounts)
  + fishingSpotCatchCounts: List<FishingSpotCatchStatistic>  — every fishing spot with at least one catch, sorted by count descending, deterministic tiebreak
```

No new derived getter is added (e.g. no "most productive fishing spot") — MFS-022 does not ask for one, and adding one would be exactly the kind of unasked-for statistic this feature has consistently avoided (MFS-019/020/021's own restraint, and MFS-022's explicit evaluation-and-exclusion of extra derived values).

### No value objects, no repository interface

`lastCatchDate` is a plain `DateTime?`; `catchCount` is a plain `int`. `FishingSpotStatisticsRepository` is a concrete class, constructed manually — consistent with every other repository in this project.

---

## 4. Data Layer

### Repository Design — FishingSpotStatisticsRepository

```text
lib/features/statistics/data/fishing_spot_statistics_repository.dart
```

**Responsibilities:** run one read-only query against `Catches`, filtered to one fishing spot; map every returned row via the existing `CatchMapper`; in a single pass over those rows, accumulate a species-count map and track the maximum `caughtAt`; sort the resulting catch list deterministically; assemble `FishingSpotStatisticsSummary`. Nothing is cached — every call recomputes from scratch (MFS-022 FR-12).

**Public API:**

```text
FishingSpotStatisticsRepository(AppDatabase database, [CatchMapper mapper])

Future<FishingSpotStatisticsSummary> getFishingSpotStatistics(String fishingSpotId)
```

`fishingSpotId` (a plain `String`, matching `Catches.fishingSpotId`'s own type), not a full `FishingSpot`, is deliberate: the repository only ever needs the id to filter by — it has no use for the fishing spot's name, coordinates, or creation date, all of which the calling page already holds (Key Design Decision 2).

**Returned domain model:** `FishingSpotStatisticsSummary`, per [§3](#3-domain-layer).

**Ordering guarantees:** `catches` is ordered by recorded weight descending (a catch with no recorded weight sorts after every catch that has one), then catch date descending, then catch id ascending — the exact rule TD-021 already specified for `SpeciesStatisticsRepository`, reused unchanged (per MFS-022's own Conceptual Model, which states this is the same rule, not a new one). `speciesCatchCounts` is ordered by catch count descending, ties broken by species identifier ascending — the exact rule TD-020 already specified for `GeneralCatchStatisticsRepository`'s own Species List, reused unchanged, since `SpeciesCatchStatistic` and its ordering are reused directly (Key Design Decision 4). Both orderings are applied unconditionally, never relying on `List.sort`'s lack of a stability guarantee.

**Empty-state handling:** a fishing spot with no catches produces `catches: []`, `speciesCatchCounts: []`, `lastCatchDate: null` — a fully valid, ordinary result, not a special case requiring different handling by the repository. The presentation layer is responsible for rendering that as an empty state (per [§5](#5-presentation-layer)).

**What this repository does not own:** display-label resolution (`FishSpecies.finnishName` is a presentation concern), photo resolution (left to `CatchListItem`/`FishingSpotRecordCatchCard`, exactly as `SpeciesStatisticsRepository` already establishes for its own Catch List/Record Catch), and any resolution of the fishing spot's own name or other fields (the repository never reads `FishingSpots` at all — Key Design Decision 2).

### general_catch_statistics_repository.dart (modified)

`GeneralCatchStatisticsRepository.getGeneralCatchStatistics()`'s existing single query and existing aggregation loop are extended, not replaced. The query itself (`Catches INNER JOIN FishingSpots`) is unchanged. Within the existing per-row loop:

* `FishingSpot` resolution (`row.readTable(_database.fishingSpots).toDomain()`), previously performed only inside the "does this catch have a recorded weight" branch (to build `LargestCatch`), now also happens for every row, to support the new per-fishing-spot count.
* A second running map (fishing spot id → count, alongside a reference to the resolved `FishingSpot`) is accumulated in the same loop that already accumulates the species-count map.
* After the loop, that map is converted into a sorted `List<FishingSpotCatchStatistic>`, the same "accumulate in a `Map`, then sort into a `List`" shape already used for `speciesCatchCounts`.

No new query is added (Key Design Decision 6). The existing `totalCatches`, `largestCatches`, and `speciesCatchCounts` computation is unchanged in behavior — this is a strictly additive extension.

**Required queries — full picture:**

| Query | Owner | Shape (conceptual) | Purpose |
|---|---|---|---|
| Every catch at one fishing spot | `FishingSpotStatisticsRepository` | `catches` filtered by `fishing_spot_id`, no join | Serves the Catch List, the Record Catch, the Species Breakdown, and Last Catch Date — all from this one query. |
| Every catch, joined with its fishing spot | `GeneralCatchStatisticsRepository` (existing, unchanged shape) | `catches INNER JOIN fishing_spots` | Already serves the total, Top 3 Largest Catches, and Species List; now also serves the Fishing Spot List, from the same rows. |

### Query behavior — conceptual description

* **Deterministic ordering:** both the fishing-spot-scoped Catch List and the whole-history structures reuse the exact tie-break chains already specified in TD-020/TD-021 — nothing new is invented here. Every ordering is applied unconditionally.
* **Handling missing weights:** a catch with no recorded weight is never excluded from `FishingSpotStatisticsSummary.catches` (unlike MFS-020's Top 3 Largest Catches) — it simply sorts after every catch that has a recorded weight, exactly as MFS-021/TD-021 already established for species-scoped statistics.
* **Record Catch derivation:** never separately queried or computed — it is `catches.first` after sorting, per Key Design Decision 3, the same relationship TD-021 already established between `SpeciesStatisticsSummary.recordCatch` and its own `catches` list.
* **Species Breakdown derivation:** an in-memory grouping pass over the same rows already fetched for the Catch List — for each catch, increment a per-species counter — then sorted into the reused `SpeciesCatchStatistic` shape. No SQL aggregation; the same "small dataset, plain Dart grouping" discipline every repository in this feature already uses (first justified at length in TD-019 Key Design Decision 2).
* **Last Catch Date derivation:** a running maximum of `caughtAt`, tracked during the same single pass over the fishing spot's own catches, per Key Design Decision 5. Never a separate query, never derived from the (weight-ordered) `catches` list after the fact.

---

## 5. Presentation Layer

All screens are manually constructed and pushed with `Navigator.push` — no GoRouter routes, no Riverpod, consistent with every other page in this app.

### Fishing Spot List — within `GeneralCatchStatisticsTab` (modified)

A third list section, appended after the existing Species List, using the same `CatchCountRow` (below) the Species List now also uses: one row per entry in `summary.fishingSpotCatchCounts`, each showing the fishing spot's name and catch count, with a real, tappable `onTap` from the start (MFS-022 FR-1/FR-2 — this list is interactive from day one, unlike MFS-020's original Species List). An inline empty message (`'Ei vielä saaliita.'`, reused verbatim) is shown when `summary.fishingSpotCatchCounts.isEmpty`.

`GeneralCatchStatisticsTab` gains one new required constructor parameter, `fishingSpotStatisticsRepository` (a `FishingSpotStatisticsRepository`), and one new private method mirroring `_openSpeciesStatistics` exactly:

```text
Future<void> _openFishingSpotStatistics(FishingSpotCatchStatistic statistic)
  → FishingSpotStatisticsPage.open(context, fishingSpot: statistic.fishingSpot, repository: widget.fishingSpotStatisticsRepository, catchRepository: ..., catchPhotoRepository: ..., lureCatalogRepository: ..., personalTackleBoxRepository: ..., personalTackleBoxPhotoStorage: ...)
```

Every other dependency `FishingSpotStatisticsPage` needs is already present on `widget` (this tab already threads `catchRepository`/`catchPhotoRepository`/`lureCatalogRepository`/`personalTackleBoxRepository`/`personalTackleBoxPhotoStorage` to open Catch Details from a Top 3 entry and from Species Statistics), so opening Fishing Spot Statistics needs exactly one additional constructor parameter, matching TD-021's own precedent exactly.

### CatchCountRow (renamed from SpeciesCatchStatisticRow)

```text
lib/features/statistics/presentation/widgets/catch_count_row.dart
```

Per Key Design Decision 1. Renders `label` and `catchCount`, with a trailing chevron, unchanged visually from today's `SpeciesCatchStatisticRow`. When `onTap` is non-null, wraps in `InkWell` with `Semantics(button: true, ...)`, identical to today's behavior. When `onTap` is null, renders without the `InkWell` wrapper and without `button: true` — a plain `Semantics(label: ..., excludeSemantics: true, ...)`, the exact shape this widget had before MFS-021. Used three times:

* The whole-history Species List (`GeneralCatchStatisticsTab`) — `onTap` non-null, unchanged behavior.
* The new Fishing Spot List (`GeneralCatchStatisticsTab`) — `onTap` non-null.
* The new per-fishing-spot Species Breakdown (`FishingSpotStatisticsPage`) — `onTap` omitted (null), per MFS-022 FR-7.

### FishingSpotStatisticsPage

```text
lib/features/statistics/presentation/widgets/fishing_spot_statistics_page.dart
```

A `StatefulWidget`, structurally a near-mirror of `SpeciesStatisticsPage` (TD-021 §5): `initState` → async load → `setState`, a `static open()` helper pushing a `MaterialPageRoute`, and the same loading/error/retry shape.

```text
FishingSpotStatisticsPage({
  required FishingSpot fishingSpot,
  required FishingSpotStatisticsRepository repository,
  required CatchRepository catchRepository,
  required CatchPhotoRepository catchPhotoRepository,
  required LureCatalogRepository lureCatalogRepository,
  required PersonalTackleBoxRepository personalTackleBoxRepository,
  required TackleBoxPhotoStorage personalTackleBoxPhotoStorage,
})

static Future<void> open(BuildContext context, {...same parameters...})
```

`fishingSpot` (not just an id) is received directly, per Key Design Decision 2 — the AppBar title is `fishingSpot.name`, resolved once, not re-queried.

Load sequence: `await widget.repository.getFishingSpotStatistics(widget.fishingSpot.id)`. On success, `setState` with the resolved summary; on failure, the same "Tilastojen lataaminen epäonnistui." message every other Statistics view already uses.

Catch Details navigation and refresh, per Key Design Decision 9:

```text
Future<void> _openCatchDetails(Catch catchModel) async {
  await CatchDetailsPage.open(context, fishingSpot: widget.fishingSpot, catchModel: catchModel, ...forwarded dependencies...);
  if (!mounted) return;
  await _load();
}
```

Both the Record Catch card and every Catch List entry call this same method, so the refresh covers both navigation paths from one implementation, exactly as `SpeciesStatisticsPage._openCatchDetails` does today.

Rendering, once loaded (a single `ListView`, matching `SpeciesStatisticsPage`'s structure):

1. Two side-by-side `StatisticsSummaryCard`s (equal height, `IntrinsicHeight`/`Row`/`Expanded`, reusing the Catches tab's own layout — Key Design Decision 10): "Saaliita yhteensä" (total catches) and "Viimeisin saalis" (Last Catch Date, formatted via the existing `formatCatchDate`, or "Ei vielä tietoja" — reused verbatim from the Catches tab's own no-data-yet text — when `lastCatchDate` is null).
2. An "Ennätyssaalis" section: a `FishingSpotRecordCatchCard` for `summary.recordCatch`, or the exact empty message `SpeciesStatisticsPage` already uses ("Ei vielä ennätyssaalista.") when null.
3. A "Lajit" section: one `CatchCountRow` (`onTap: null`) per entry in `summary.speciesCatchCounts`, or an inline empty message when empty.
4. A "Kaikki saaliit" section: one `CatchListItem` per entry in `summary.catches`, in the already-sorted order, or an inline empty message when empty — reusing `CatchListItem` completely unmodified, exactly as `SpeciesStatisticsPage` already does.

### FishingSpotRecordCatchCard

```text
lib/features/statistics/presentation/widgets/fishing_spot_record_catch_card.dart
```

Per Key Design Decision 8. Structurally close to `RecordCatchCard` (same `Card`/`InkWell`/`Semantics` shell, same private `Future<File?>` thumbnail-loading pattern, same reuse of `CatchPhotoThumbnail` unmodified), but content differs:

```text
FishingSpotRecordCatchCard({
  required Catch catchModel,
  required CatchPhotoRepository catchPhotoRepository,
  required VoidCallback onTap,
})
```

No `FishingSpot`/`entry` wrapper is needed (per Key Design Decision 3) — just the plain `Catch`. Rendering order: photo (or placeholder) leading; species name (`finnishName`) as the first text line; the measurement line (`formatCatchMeasurementLine`, reused, omitted when both weight and length are absent) below it; catch date last. No location line. The combined semantic label follows the same "join the present parts" pattern `RecordCatchCard` already uses, substituting species-first/no-location for location-last/no-species.

### Loading / Error / Empty summary

| State | Where | Behavior |
|---|---|---|
| Loading | `FishingSpotStatisticsPage` | Centered `CircularProgressIndicator`, replacing the entire page body. |
| Load error | `FishingSpotStatisticsPage` | "Tilastojen lataaminen epäonnistui." plus a "Yritä uudelleen" retry button — copy reused verbatim. |
| Fishing spot has no catches (should be rare — see MFS-022 Edge Cases) | `FishingSpotStatisticsPage` | Total card shows `0`; Last Catch Date card shows "Ei vielä tietoja"; Record Catch, Species Breakdown, and Catch List sections each show their own empty message. |
| Fishing Spot List itself is empty (no fishing spot has any catches) | `GeneralCatchStatisticsTab` | The same inline empty message already used for the Species List. |

---

## 6. Navigation

```text
Statistics
        ↓ (existing AppBar entry point, unchanged)
StatisticsPage                       [statistics]
        ↓ (DefaultTabController, Catches tab, unchanged default)
GeneralCatchStatisticsTab            [statistics]
        ↓ (Fishing Spot List row tapped — new)
FishingSpotStatisticsPage            [statistics, new]
        ↓ (Record Catch, or a Catch List entry, tapped)
CatchDetailsPage                     [catches, existing, unmodified — MFS-014]
```

`FishingSpotStatisticsPage` is pushed via its own `static open()` helper, mirroring `SpeciesStatisticsPage.open()`/`CatchDetailsPage.open()` exactly — the same `Navigator.push`/`MaterialPageRoute` pattern used everywhere in this application, not a new navigation primitive, not a tab.

**Lifecycle and refresh:** because `FishingSpotStatisticsPage` is a freshly-pushed route on every open, reopening it from the Fishing Spot List always recomputes from scratch (MFS-022 FR-12), with no extra mechanism required — the same "no state survives a fresh push" argument TD-021 Key Design Decision 10 already made. While the page remains mounted underneath a pushed `CatchDetailsPage`, returning from it always triggers `_load()` again, per Key Design Decision 9 — so an edit, a species change, or a delete performed in Catch Details is reflected the moment the user returns, regardless of which of the two entry points (Record Catch or Catch List) was used to get there.

`MapScreen._openStatistics()` is updated only to construct `FishingSpotStatisticsRepository` and pass it to `StatisticsPage`; the entry point into `StatisticsPage` itself, and everything downstream of the Fishing Spot List that isn't new, is unchanged.

---

## 7. State Management

No Riverpod, no `Provider`, no `InheritedWidget` — consistent with every other feature in this codebase. `FishingSpotStatisticsPage` is a `StatefulWidget` whose state (`_summary`, `_isLoading`, `_errorMessage`) is plain `State` fields, following the exact pattern `SpeciesStatisticsPage`/`GeneralCatchStatisticsTab` already use. `FishingSpotRecordCatchCard` is the only other stateful widget this milestone introduces, holding only its own resolved thumbnail `Future`, mirroring `RecordCatchCard`'s own minimal state exactly.

`CatchCountRow` remains a pure, stateless, `const`-constructible widget after its rename — no new state is introduced by making `onTap` nullable. `GeneralCatchStatisticsTab` and `StatisticsPage` are unchanged in kind (`StatefulWidget`/`StatelessWidget` respectively).

---

## 8. Error Handling

| Scenario | Behavior |
|---|---|
| `getFishingSpotStatistics()` throws (e.g. a database read error) | Caught in `FishingSpotStatisticsPage._load()`; the page shows a clear error message plus a retry action; the application does not crash. |
| `getGeneralCatchStatistics()` throws | Unchanged — already handled by `GeneralCatchStatisticsTab._load()`; the new Fishing Spot List section is simply part of the same summary object that either loads or doesn't. |
| Retry after a load failure | Tapping "Yritä uudelleen" re-runs `_load()` from scratch; no partial or stale data is shown while the retry is in flight. |
| A Record Catch or Catch List entry's photo fails to resolve | Unchanged, in two places: `CatchListItem`'s existing handling applies exactly as-is; `FishingSpotRecordCatchCard`'s own equivalent, independently-implemented handling (Key Design Decision 8) applies for the Record Catch section. |
| `CatchDetailsPage.open()` is invoked for a catch at a fishing spot that was deleted moments earlier (should not occur through any normal flow — MFS-008's cascade would already have removed the catch itself) | Not applicable by construction: `FishingSpotStatisticsPage` always uses its own already-known `widget.fishingSpot`, and any catch it lists at all is, by definition, still a catch at that fishing spot as of the last `_load()`. |
| The fishing spot itself is deleted while its own Statistics page happens to be open (MFS-022 Edge Cases) | The cascading catch deletion (MFS-008, unmodified) means the next `_load()` simply returns an empty summary; the header continues to show the fishing spot's name as passed in at open time, per Key Design Decision 2. No crash, no special-casing. |

---

## 9. Empty and Loading States

Covered in full in [§5](#loading--error--empty-summary). Summary: a single centered `CircularProgressIndicator` for loading; a single error message plus retry for failure; per-section empty handling (no dedicated whole-page empty widget) for the no-data cases, mirroring TD-021's own Key Design Decision 9-equivalent precedent exactly.

---

## 10. Performance Considerations

**Query count:** `FishingSpotStatisticsRepository` — exactly one query per `getFishingSpotStatistics()` call, no join (Key Design Decision 2), regardless of how many catches exist at that fishing spot. `GeneralCatchStatisticsRepository` — still exactly one query per `getGeneralCatchStatistics()` call, unchanged from TD-020; the Fishing Spot List adds zero additional queries (Key Design Decision 6). Neither repository issues a query per row, per fishing spot, or per species — no N+1 anywhere in this milestone.

**Avoiding duplicate work:** the Fishing Spot List's aggregation reuses rows the Catches tab was already fetching for the Top 3 Largest Catches and Species List — there is no second read of the same data under a different shape. `FishingSpotStatisticsRepository` deliberately never reads `FishingSpots` at all, avoiding a join that would exist only to produce a value (the fishing spot's own name) the calling page already has.

**Aggregation cost:** O(n) over the fishing spot's own catches for `FishingSpotStatisticsRepository`, and O(n) over the angler's entire catch history for the (unchanged) `GeneralCatchStatisticsRepository` pass — both already-established, already-accepted scales (TD-019 Key Design Decision 2, reaffirmed in TD-020/TD-021). A single fishing spot's own catch count is a subset of that already-small total, so this is smaller still, not a new scale concern.

**Sorting cost:** O(k log k) over the number of catches at the fishing spot for the Catch List, and O(s log s) over the number of distinct species there for the Species Breakdown — both bounded well below the whole-history totals this feature already sorts elsewhere.

**No caching.** Every open of the Fishing Spot List (part of the Catches tab) and every open of `FishingSpotStatisticsPage` recomputes from scratch, per MFS-022 FR-12 and Key Design Decision 9's "fresh push" reasoning — no premature optimization is introduced to avoid this, consistent with every prior Statistics milestone's own explicit choice not to cache.

**Photo loading:** unchanged from every other reuse of `CatchListItem`/`CatchPhotoThumbnail` in this feature — existing `cacheWidth`/`cacheHeight` sizing and `FutureBuilder`-based resolution apply exactly as-is, with no new image-loading code.

---

## 11. Testing Strategy

Follows the same layered testing philosophy as TD-019/020/021: domain tests for construction/getters, repository tests for query and ordering behavior against a real in-memory database, widget tests for the presentation surfaces, and a physical-device pass at the end.

**Migration testing: no migration tests required.** This milestone introduces no schema change of any kind.

**Domain** (`test/features/statistics/domain/`):
`fishing_spot_catch_statistic_test.dart` — valid construction; rejects `catchCount <= 0`. `fishing_spot_statistics_summary_test.dart` — `totalCatches` equals `catches.length`; `recordCatch` returns the first entry when non-empty and `null` when empty; `lastCatchDate` is stored as given, independent of `catches`' own (weight-based) order. `general_catch_statistics_summary_test.dart` (updated) — existing assertions unchanged; new coverage for `fishingSpotCatchCounts` construction.

**Repository tests:**

`fishing_spot_statistics_repository_test.dart` (against `AppDatabase(NativeDatabase.memory())`, seeded via `CatchRepository`/`FishingSpotRepository`, mirroring `species_statistics_repository_test.dart`'s setup):

* no catches at the fishing spot → empty `catches`, `totalCatches == 0`, `recordCatch == null`, `lastCatchDate == null`
* catches at other fishing spots are excluded
* catches are sorted by weight descending; a catch with no recorded weight sorts after every catch that has one; a tie in weight resolves by catch date descending; a tie in both resolves by catch id ascending
* `recordCatch` equals the first entry of the already-sorted `catches`
* `speciesCatchCounts` aggregates and sorts correctly, including a tie broken by species identifier
* `lastCatchDate` equals the true maximum `caughtAt` — including a case where the chronologically most recent catch is *not* the heaviest one, proving `lastCatchDate` is not derived from `catches.first`
* deleting, editing, or adding a catch at the fishing spot changes `catches`/`speciesCatchCounts`/`lastCatchDate` on the next call, with no stale data

`general_catch_statistics_repository_test.dart` (updated):

* new coverage: `fishingSpotCatchCounts` content, sort order (count descending, name-then-id tiebreak), and zero-catch exclusion
* existing coverage (`totalCatches`, `largestCatches`, `speciesCatchCounts`) re-run unchanged, asserting no regression from the loop's extended aggregation

**Widget tests:**

`fishing_spot_statistics_page_test.dart` (mirroring `species_statistics_page_test.dart`'s structure and its `_PendingRepository`/`_FailingRepository`/`_FailOnceRepository`/`_StaticRepository` fakes) — loading indicator; error message and retry; the two header cards (total, Last Catch Date, including its own "Ei vielä tietoja" empty case); a populated summary renders `FishingSpotRecordCatchCard`, the Species Breakdown in sorted order with no tap handling, and the full Catch List in sorted order; a catch missing photo/weight/length renders without a broken layout; tapping the Record Catch card and tapping a Catch List entry each open `CatchDetailsPage` for the correct catch; the fishing spot with no catches renders every section's empty state.

`fishing_spot_record_catch_card_test.dart` (mirroring `record_catch_card_test.dart`, including its real-photo test via `tester.runAsync()`) — placeholder when no photo; real photo when one exists; species always rendered; measurement line rendered/omitted; date always rendered; no location text anywhere; tap invokes `onTap`; combined semantic label.

`catch_count_row_test.dart` (renamed from `species_catch_statistic_row_test.dart`) — renders `label`/`catchCount`; when `onTap` is non-null, tapping invokes it and the row exposes button semantics (today's existing coverage, retargeted to the new generic API); when `onTap` is null, the row renders identically but exposes no button semantics and cannot be tapped into anything (new coverage, proving the static path).

`general_catch_statistics_tab_test.dart` (updated) — new: Fishing Spot List renders in sorted order; tapping a row opens `FishingSpotStatisticsPage` for the correct fishing spot. Existing: Top 3 Largest Catches and Species List assertions re-run unchanged.

`statistics_page_test.dart` (updated) — constructor signature includes `fishingSpotStatisticsRepository`; both tabs still render in the correct order with Catches as the default.

**Navigation tests:** covered by the `general_catch_statistics_tab_test.dart` and `fishing_spot_statistics_page_test.dart` cases above — Statistics → Fishing Spot List → Fishing Spot Statistics → Catch Details, from both the Record Catch and Catch List entry points.

**Lifecycle refresh tests** (in `fishing_spot_statistics_page_test.dart`, mirroring TD-021's own four-test shape exactly): editing a catch's weight while Catch Details is open, then confirming the change on return via the Record Catch path; deleting a catch while Catch Details is open, then confirming the empty state on return; editing a catch so the Record Catch and Catch List order (and Last Catch Date) change, exercised via the Catch List path; disposing the page while a post-return reload is still pending (a repository double resolving once then never completing, per TD-021's `_FirstThenPendingRepository` precedent), confirming no `setState`-after-dispose exception.

**Empty-state tests:** covered above — a fishing spot with no catches (`fishing_spot_statistics_page_test.dart`) and an entirely empty Fishing Spot List (`general_catch_statistics_tab_test.dart`).

**Integration/physical Android testing:** open Statistics → Catches tab → confirm the Fishing Spot List appears below the Species List, in the correct order; tap a fishing spot and confirm the header, Record Catch, Species Breakdown, and Catch List against a real, previously-logged set of catches at that spot; tap the Record Catch card and a Catch List entry and confirm Catch Details opens correctly for each; edit and then delete a catch from within Catch Details and confirm Fishing Spot Statistics reflects both changes on return; verify a fishing spot with a single catch and no recorded weight still shows a Record Catch and a Last Catch Date; verify the whole-history Species List and Top 3 Largest Catches still behave exactly as before; verify full offline/airplane-mode operation.

---

## 12. Risks

| Risk | Category | Mitigation |
|---|---|---|
| `SpeciesCatchStatisticRow` is renamed and its `onTap` made nullable, touching an already-shipped, tested widget and its one existing caller. | Maintainability | The signature change is additive/backward-compatible (the existing caller already passes a non-null callback, which remains valid); the rename is mechanical (TD-018/TD-020 already established this exact move twice); the widget's visual output for a non-null `onTap` is unchanged byte-for-byte. |
| `GeneralCatchStatisticsRepository`'s existing aggregation loop changes (unconditional `FishingSpot` resolution, a second accumulator map), touching an already-shipped, tested repository. | Maintainability | Purely additive — no existing computation path is removed or altered; the existing repository test suite is re-run unchanged as regression coverage alongside new Fishing Spot List assertions. |
| The catch-ordering comparator now exists in two files (`SpeciesStatisticsRepository`, `FishingSpotStatisticsRepository`) and could drift if the ordering rule ever changes. | Design | Accepted explicitly — see Key Design Decision 7. A third caller needing the same ordering is the documented trigger to extract a shared helper. |
| `StatisticsPage`'s and `GeneralCatchStatisticsTab`'s constructor parameter lists grow again (to 9 and 8 parameters respectively). | Maintainability | Matches the already-accepted growth pattern from TD-020 (which itself grew `StatisticsPage` from one parameter to seven) and TD-021; the same "no dependency-bundle object introduced merely to shorten the list" reasoning from TD-020's Architecture Review applies unchanged. |
| `FishingSpotRecordCatchCard` duplicates `RecordCatchCard`'s thumbnail-loading pattern a third time in this feature. | Maintainability | Accepted per Key Design Decision 8, the same trade-off TD-021 already recorded for its own second instance of this pattern. |

---

## 13. Future Compatibility

* **Wiring the Species Breakdown to Species Statistics** (MFS-022 Future Extensions) — `CatchCountRow` already supports a non-null `onTap`; wiring it here means passing `onTap: () => SpeciesStatisticsPage.open(...)` at the `FishingSpotStatisticsPage` call site, with no change to the row widget itself.
* **First catch date** (MFS-022 Future Extensions) — computable with the same "running extremum during the existing single pass" technique already used for Last Catch Date (Key Design Decision 5), tracking a minimum instead of a maximum.
* **Total/average recorded weight or length** (MFS-022 Future Extensions) — computable from `FishingSpotStatisticsSummary.catches` directly, with no new query.
* **A map preview within Fishing Spot Statistics** — `FishingSpotStatisticsPage` already receives the full `FishingSpot` object, including its coordinates; no new data dependency would be required.
* **Filtering, charts, or broader analytics** — out of scope for this milestone and its three Statistics predecessors alike; would extend the existing repository/read-model shape rather than replace it.
* **Cloud synchronization** — unaffected. This feature remains entirely read-only over data owned elsewhere.

---

## Dependencies

No new external package dependencies. This milestone reuses the existing stack and patterns:

* Flutter, Dart
* Drift (per ADR-0005) — read-only queries against existing tables only; no schema change
* The existing Repository pattern, feature-first structure, and manual dependency construction (ADR-0001, ADR-0003, ADR-0004, ADR-0006)
* The existing `Catch` domain model and `CatchMapper` (MFS-009/TD-009), consumed read-only, unmodified
* The existing `FishingSpot` domain model (MFS-004), consumed read-only, unmodified
* `CatchListItem`, `CatchPhotoThumbnail`, `formatCatchMeasurementLine`, `formatCatchDate`, `FishSpecies.finnishName` (MFS-011/MFS-013/MFS-014), reused unchanged
* `CatchDetailsPage.open()` (MFS-014), reused unmodified as this milestone's navigation target
* `SpeciesCatchStatistic` (MFS-020/TD-020), reused unmodified for the Species Breakdown
* `StatisticsSummaryCard` (MFS-019/TD-019, renamed by TD-020), reused a fourth time with no further change
* The Statistics feature's existing tabbed shell, presentation conventions, and post-navigation refresh pattern (MFS-019/MFS-020/MFS-021/TD-019/TD-020/TD-021)

`flutter_riverpod` is not used by this feature, for the same reasons documented in TD-015 through TD-021.

---

## Expected Files To Create

```text
lib/features/statistics/domain/fishing_spot_statistics_summary.dart
lib/features/statistics/domain/fishing_spot_catch_statistic.dart
lib/features/statistics/data/fishing_spot_statistics_repository.dart
lib/features/statistics/presentation/widgets/fishing_spot_statistics_page.dart
lib/features/statistics/presentation/widgets/fishing_spot_record_catch_card.dart
```

Plus new test files under `test/features/statistics/...` per [§11](#11-testing-strategy).

## Expected Files To Rename

```text
lib/features/statistics/presentation/widgets/species_catch_statistic_row.dart
    → lib/features/statistics/presentation/widgets/catch_count_row.dart
    (class SpeciesCatchStatisticRow → CatchCountRow; constructor takes label/catchCount instead
    of a SpeciesCatchStatistic; onTap becomes VoidCallback?; see Key Design Decision 1)

test/features/statistics/presentation/widgets/species_catch_statistic_row_test.dart
    → test/features/statistics/presentation/widgets/catch_count_row_test.dart
    (assertions updated for the generalized API; new coverage added for the onTap == null path)
```

Confirm at implementation time that `GeneralCatchStatisticsTab` is the only production caller of `SpeciesCatchStatisticRow` before renaming it (per this document's review, it is).

## Expected Files To Modify

```text
lib/features/statistics/domain/general_catch_statistics_summary.dart     (one new field, fishingSpotCatchCounts)
lib/features/statistics/data/general_catch_statistics_repository.dart    (additive aggregation in the existing loop; no new query — see §4)
lib/features/statistics/presentation/widgets/general_catch_statistics_tab.dart  (fishingSpotStatisticsRepository parameter; Fishing Spot List section; _openFishingSpotStatistics)
lib/features/statistics/presentation/widgets/statistics_page.dart        (fishingSpotStatisticsRepository parameter, threaded to GeneralCatchStatisticsTab)
lib/features/map/presentation/map_screen.dart                            (construct FishingSpotStatisticsRepository; pass it through _openStatistics to StatisticsPage)
test/features/statistics/domain/general_catch_statistics_summary_test.dart      (new field coverage; existing assertions unchanged)
test/features/statistics/data/general_catch_statistics_repository_test.dart     (new Fishing Spot List coverage; existing assertions re-run unchanged)
test/features/statistics/presentation/widgets/general_catch_statistics_tab_test.dart  (new Fishing Spot List coverage; existing assertions re-run unchanged)
test/features/statistics/presentation/widgets/statistics_page_test.dart         (constructor signature updated)
```

No other existing file is modified. `lib/core/database/app_database.dart` is **not** modified — see [Database Impact](#database-impact). `lib/features/catches/`, `lib/features/catch_photos/`, `lib/features/fishing_spots/`, `lib/features/lure_catalog/`, and `lib/features/personal_tackle_box/` are not modified. `species_statistics_repository.dart`, `species_statistics_page.dart`, `record_catch_card.dart`, and `lure_statistics_repository.dart` are not modified.

---

## Database Impact

**None.** No new Drift table, no new column, no schema version change, no migration. The schema version remains at `6`, as established by TD-017 and unchanged through TD-018/TD-019/TD-020/TD-021. `FishingSpotStatisticsRepository` reads the existing `Catches` table through a single, read-only, filtered query; `GeneralCatchStatisticsRepository`'s existing query and join are unchanged. Nothing about `AppDatabase`'s table registration, migration strategy, or schema version changes.

Confirm at implementation time that the live schema version is still `6` before beginning, consistent with the same hedge every prior TD in this project has required.

**No migration tests required.**

---

## Test Impact

* **New tests:** every domain, repository, and widget test file listed in [§11](#11-testing-strategy) that does not already exist.
* **Renamed, not rewritten:** `species_catch_statistic_row_test.dart` → `catch_count_row_test.dart` — existing assertions retargeted to the generalized API (no behavioral change for the `onTap != null` path), plus new coverage for `onTap == null`.
* **Updated for additive behavior:** `general_catch_statistics_summary_test.dart`, `general_catch_statistics_repository_test.dart`, `general_catch_statistics_tab_test.dart`, `statistics_page_test.dart` — all gain new assertions while their existing assertions continue to pass unchanged, serving as this milestone's regression coverage for MFS-020's untouched behavior.
* **Untouched:** every `catches`, `catch_photos`, `fishing_spots`, `lure_catalog`, and `personal_tackle_box` test file; `species_statistics_repository_test.dart`, `species_statistics_page_test.dart`, `record_catch_card_test.dart`, and every `lure_statistics_*` test, since none of that code changes.

---

## Implementation Notes

To be completed during implementation, following the established convention of recording any deviation from this document here, with justification.

---

## Implementation Notes for Claude Code

* **Confirm the live schema version is `6` before starting** — if it has moved past `6` since this document was written, nothing in this design changes.
* **Do not touch `lib/core/database/app_database.dart`.** This milestone reads one already-registered table (`Catches`, filtered) and reuses one already-registered join (`Catches`/`FishingSpots`, unchanged) — no table registration, schema version, or migration changes.
* **Do not modify anything under `lib/features/catches/`, `lib/features/catch_photos/`, `lib/features/fishing_spots/`, `lib/features/lure_catalog/`, or `lib/features/personal_tackle_box/`.** This design reads their tables/domain models and reuses `CatchMapper`, `CatchListItem`, `CatchPhotoThumbnail`, `formatCatchMeasurementLine`, `formatCatchDate`, and `CatchDetailsPage.open()` exactly as they exist today.
* **Do not modify `lib/features/statistics/data/species_statistics_repository.dart` or `lib/features/statistics/presentation/widgets/species_statistics_page.dart`/`record_catch_card.dart`.** Nothing in this milestone changes MFS-021's own computation, data, or behavior.
* **The only permitted changes to existing `statistics` files are the ones named in [Expected Files To Rename](#expected-files-to-rename) and [Expected Files To Modify](#expected-files-to-modify).** If satisfying a requirement here seems to need touching anything else, stop and re-read the relevant Key Design Decision rather than adding one.
* **`CatchListItem` is reused as-is — do not fork it or add fields to it.** The Catch List's rows show exactly what `CatchListItem` already shows.
* **`FishingSpotRecordCatchCard` must reuse `CatchPhotoThumbnail` unmodified**, mirroring `RecordCatchCard`'s own precedent (Key Design Decision 8) — do not build a new image-display widget.
* **The rename in [Expected Files To Rename](#expected-files-to-rename) changes `SpeciesCatchStatisticRow`'s constructor shape** (a `SpeciesCatchStatistic` parameter becomes plain `label`/`catchCount` parameters) as well as its file/class name — update `GeneralCatchStatisticsTab`'s existing Species List call site accordingly, not just its import.
* **The ordering comparators in [§4](#4-data-layer) must be applied unconditionally**, matching TD-021's own instruction on this point exactly — do not simplify the missing-weight handling.
* **All user-visible text is Finnish**, per this project's Development Rules. Reuse "Tilastojen lataaminen epäonnistui.", "Yritä uudelleen", "Saaliita yhteensä", "Ei vielä tietoja", "Ei vielä ennätyssaalista.", and "Ei vielä saaliita." verbatim wherever this document reuses them — do not invent new phrasing for text that already exists elsewhere in this feature.
* **No Riverpod, no repository interface, no DAO/service/use-case layer, no `watch()`.** Construct `FishingSpotStatisticsRepository` manually in `MapScreen`, exactly like every other repository already there.
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

* The implementation satisfies all requirements in MFS-022.
* The implementation follows TD-022, or documents and justifies each deviation.
* The Catches tab shows a Fishing Spot List (name, catch count, sorted by count descending with deterministic tie-breaking), tappable from the start, appended after the existing Species List.
* Tapping a Fishing Spot List row opens `FishingSpotStatisticsPage` for the correct fishing spot.
* The page's header shows the fishing spot's name, its total catch count, and its Last Catch Date (or a clear "no data yet" state).
* A Record Catch section shows the top-ranked catch at the fishing spot (species, weight, length, date — no location), rendering cleanly when any optional field is missing.
* A Species Breakdown shows every species caught at the fishing spot, sorted by count descending, performing no action when tapped and exposing no button semantics.
* A Catch List shows every catch at the fishing spot, using `CatchListItem` unmodified, in the documented deterministic order.
* Selecting the Record Catch card, or any Catch List entry, opens the existing Catch Details view for the correct catch.
* Returning from Catch Details — after an edit, a delete, or no change — always refreshes Fishing Spot Statistics, from both entry points, without a stale total, Record Catch, Species Breakdown, or Catch List.
* No total, average, or other derived arithmetic aggregate is shown anywhere in this milestone.
* No new Drift table, column, schema version, or migration was introduced.
* `catches`, `catch_photos`, `fishing_spots`, `lure_catalog`, and `personal_tackle_box` are functionally and structurally unchanged; `SpeciesStatisticsRepository`/`SpeciesStatisticsPage`/`RecordCatchCard`/`LureStatisticsRepository` are unchanged; `GeneralCatchStatisticsRepository`'s existing total/Top-3/Species List computation is unchanged in behavior.
* Data access follows the existing repository-based architecture, with no service layer, use-case layer, DAO layer, or repository interface introduced.
* Every capability works with no network connection.
* `dart format .`, `flutter analyze`, and `flutter test` all pass.
* Architecture review is completed.
* Physical Android testing is completed.
* Documentation (`docs/project-status.md`, `docs/roadmap.md`) is updated in a separate, subsequent step — not part of this document's own completion.
