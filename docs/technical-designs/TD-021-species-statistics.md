# TD-021 — Species Statistics

## Status

Draft

## Related Specification

* MFS-021: Species Statistics

---

## Goal

Implement the new Species Statistics page MFS-021 introduces: a pushed, full-screen page reached by tapping a row in MFS-020's Species List, showing a header (species name, total catches), a Record Catch section (the angler's top-ranked catch of that species), and a full Catch List of every catch of that species — all computed live from existing `Catch`/`CatchPhoto`/`FishingSpot` data, with no new database table, no schema migration, and no change to the `catches`, `catch_photos`, or `fishing_spots` features.

The implementation shall satisfy MFS-021.

---

## Scope

Implement:

* two read-only, presentation-facing read-model types: a catch paired with its fishing spot (species-scoped, no weight requirement), and a summary aggregate wrapping a species, its full ordered catch list, and derived total/record-catch getters
* a concrete, feature-owned `SpeciesStatisticsRepository` computing the above from one plain, read-only, species-filtered join against the existing `Catches` and `FishingSpots` tables
* the fully specified, deterministic ordering MFS-021 already gives explicitly (weight descending, missing weight last, then catch date descending, then catch id ascending)
* `SpeciesStatisticsPage`: a header, a `RecordCatchCard`, and a Catch List reusing `CatchListItem` unmodified
* the navigation wiring MFS-020 deliberately left unimplemented: `SpeciesCatchStatisticRow` gains a real `onTap` and button semantics; `GeneralCatchStatisticsTab` opens `SpeciesStatisticsPage` from it
* threading one new repository (`SpeciesStatisticsRepository`) through `StatisticsPage` and `MapScreen`, exactly like every prior Statistics milestone
* loading, empty, and error states
* accessibility labeling
* tests

Do **not** implement:

* any new Drift table, column, or schema migration
* any cached, stored, or persisted statistic of any kind
* graphs, charts, averages (including average weight/length), seasonal/time-based statistics, lure statistics, weather statistics, maps, filtering, searching, exporting, or any other new analytics beyond the total, Record Catch, and Catch List MFS-021 defines
* any change to `catches`, `catch_photos`, or `fishing_spots`'s domain models, tables, repositories, or read-only/reference-only guarantees
* any change to `GeneralCatchStatisticsRepository`'s query, aggregation, or return shape, or to `LureStatisticsRepository`/the Lure Statistics tab in any way
* a service layer, use-case layer, DAO layer, or repository interface of any kind
* Riverpod, reactive database streams (`watch()`), background computation, or sync logic
* editing, deleting, or otherwise mutating a catch from this page

---

## Key Design Decisions

This section answers the questions most likely to be raised in review, before the detailed sections implement them.

**1. Wiring MFS-020's Species List navigation is this document's responsibility, and touches exactly two existing `statistics`-owned files — this is not the "change to MFS-020's Catches tab" MFS-021's own Out of Scope list rules out.** MFS-021 FR-1 explicitly requires that tapping a Species List row opens this milestone's new page — the exact navigation MFS-020 FR-8 left unimplemented and MFS-020's own Accessibility Expectations flagged as "expected to change once a future milestone (MFS-021 Candidate) adds real navigation." MFS-021's Out of Scope bullet ("Any change to MFS-020's Catches tab or MFS-019's Lure Statistics tab") is read the same way MFS-020's own equivalent bullet about the Lure Statistics tab was always intended — as ruling out changes to that tab's *computation, data, or already-shipped behavior*, not the one piece of wiring MFS-020 itself explicitly deferred to this milestone by name. Concretely, this document changes exactly two things inside the Catches tab: `SpeciesCatchStatisticRow` gains a required `onTap` and is exposed as a real button (reversing MFS-020's deliberate, self-described *temporary* "not yet a button" state — MFS-020 FR-8/Accessibility Expectations), and `GeneralCatchStatisticsTab` gains one new constructor dependency (`speciesStatisticsRepository`) and one new private method wiring that tap to `SpeciesStatisticsPage.open()`. Nothing about `GeneralCatchStatisticsRepository`, its query, its sort order, or any other part of the Catches tab changes.

**2. `SpeciesStatisticsRepository` performs its own species-filtered join against `Catches`/`FishingSpots` — the same join shape `GeneralCatchStatisticsRepository` already established (TD-020 Key Design Decision 2), scoped by a `WHERE` clause instead of left unfiltered.** `Catches.fishingSpotId` is a required (non-nullable) foreign key, so this `innerJoin` never excludes a row, exactly as TD-020 already established. No new repository method is added to `CatchRepository` or `FishingSpotRepository` — this mirrors every prior Statistics repository's precedent of reading tables directly rather than through another feature's repository instance methods (TD-019 Key Design Decision 1, TD-020 Key Design Decision 1/2).

**3. Every returned catch carries its own resolved `FishingSpot` — not only the Record Catch.** This is a correctness requirement, not an optimization: MFS-021 FR-8 lets the angler open Catch Details from *any* Catch List entry, and `CatchDetailsPage.open()` requires a fully-resolved `FishingSpot` object (`required this.fishingSpot`), exactly the constraint TD-020 Key Design Decision 1 already documented. Because the one join query already resolves every catch's fishing spot at no extra query cost, there is no reason to special-case the Record Catch's resolution separately from the rest of the list — the same single pass produces both.

**4. A new `SpeciesCatchEntry` type, not `LargestCatch` reused or modified.** `LargestCatch` (TD-020) has an identical field shape (`catchModel` + `fishingSpot`), but its constructor asserts `catchModel.weightGrams != null` — precisely the invariant this milestone's Catch List must *not* enforce (MFS-021's Conceptual Model explicitly allows a weight-less Record Catch when no catch of the species has a recorded weight). Relaxing that assertion would change an already-shipped TD-020 type's documented contract for a caller it was never designed for. A second, minimal type with the same shape but no weight assertion is the smaller, more contained change — consistent with this project's preference for a small amount of duplication over weakening an existing invariant for an unrelated caller.

**5. Record Catch is a derived getter over the already-sorted `catches` list, not a separate query or field.** `SpeciesStatisticsSummary.recordCatch` is simply `catches.isEmpty ? null : catches.first` — the same "top of an already-sorted list" relationship TD-020 Key Design Decision 5 established for `mostCaughtSpecies`, applied here per MFS-021's own Conceptual Model ("Record Catch is the top-ranked entry of the Catch List, not a separately computed value").

**6. `totalCatches` is a derived getter (`catches.length`), not a stored field — a deliberate, narrow departure from `GeneralCatchStatisticsSummary`'s own explicit `totalCatches` field.** `GeneralCatchStatisticsSummary` needs a real field because its `largestCatches` list is capped at three, so the list's length cannot stand in for the true total. This milestone's `catches` list is never capped — it always contains every catch of the species — so its length *is* the total, exactly, at all times. Storing a second value that must always equal `catches.length` would be a value with nothing to disagree with, contrary to this project's "avoid unnecessary duplication" rule; a getter is simpler and cannot drift out of sync.

**7. The ordering comparator explicitly defines where a missing weight sorts, since MFS-021's own three-line ordering list does not spell this out.** MFS-021 gives "weight descending, then date descending, then catch id ascending" but does not state where a catch with no recorded weight falls relative to one that has a value — a genuine well-definedness gap this document must close before the ordering is implementable at all. Per MFS-021's Conceptual Model text ("a catch with no recorded weight sorts after every catch that has one"), the comparator treats a missing weight as strictly lower than every recorded weight, never as `0` or as excluded from the list. See [§4](#4-data-layer).

**8. `RecordCatchCard` reuses `CatchPhotoThumbnail` unmodified (the same fixed 88px tile already used by `CatchListItem`) rather than introducing a new, larger image widget.** "Prominent," per MFS-021's UI Expectations, is achieved through the card's placement (top of the page, its own labeled section, more surrounding whitespace and text) and through showing fields `CatchListItem` does not (location), not through a bigger photo. This avoids a second image-loading/caching implementation for a single new card.

**9. `RecordCatchCard` resolves its own first-photo file independently, duplicating roughly a dozen lines of `CatchListItem`'s private thumbnail-loading logic rather than extracting a shared helper.** `CatchListItem`'s thumbnail resolution (`catchPhotoRepository.getByCatchId` → `resolveFile`, wrapped in a `FutureBuilder`) lives entirely inside its own private `State` class, with nothing exposed for reuse. `RecordCatchCard` cannot reuse `CatchListItem` itself, since it needs a different layout (photo, weight, length, date, *and* location — a field `CatchListItem` never renders), per MFS-021's own Conceptual Model distinguishing the two. Extracting a shared thumbnail-resolution helper for exactly one additional caller would be exactly the premature abstraction this project's Development Rules warn against; if a third caller ever needs the same pattern, that is the point to factor it out, not before.

**10. `SpeciesStatisticsPage` is a pushed page (`Navigator.push`/`MaterialPageRoute`, with a `static open()` helper), mirroring `CatchDetailsPage`'s exact precedent — not a third Statistics tab.** MFS-021's own Navigation section is explicit that this is reached by tapping a Species List row, not by switching tabs. Because every open is a brand-new `MaterialPageRoute` push, there is no tab-revisit/`AutomaticKeepAliveClientMixin` question to resolve at all (unlike TD-019 Key Design Decision 8) — a fresh widget is constructed and disposed on every visit by construction, which already satisfies MFS-021 FR-10 ("Computed Live, Never Stored") with zero extra mechanism.

**11. No new database index.** The species-filtered `WHERE` clause runs a full scan of the `catches` table, which — per the same dataset-scale rationale TD-019 Key Design Decision 2 already stated in full and TD-020 Key Design Decision 3 reused — holds at most tens to low hundreds of rows for a single user on a single device. A per-species subset of that is smaller still. Adding an index for a query this cheap, over data this small, would be optimizing a cost that does not exist at this application's scale.

---

## 1. Overview

`statistics` is extended again, for the third time, exactly as `docs/roadmap.md` and MFS-020's own Future Extensions anticipated. Nothing TD-019/TD-020 already built is restructured.

| Feature | Responsibility in this milestone |
|---|---|
| `statistics` (extended) | Gains `SpeciesStatisticsRepository`, two new read-model types, `SpeciesStatisticsPage`/`RecordCatchCard`, and a small navigation wiring change to two existing files (`species_catch_statistic_row.dart`, `general_catch_statistics_tab.dart`). `LureStatisticsRepository`, `GeneralCatchStatisticsRepository`, and every other TD-019/TD-020 file are otherwise unmodified. |
| `catches` (unmodified) | Continues to own `Catch`/`CatchRepository`/the `Catches` table, and `CatchListItem`, reused unchanged for this milestone's Catch List — its third reuse, after MFS-011's own fishing-spot-scoped list and MFS-020's Top 3 Largest Catches. |
| `fishing_spots` (unmodified) | Continues to own `FishingSpot`/`FishingSpotRepository`/the `FishingSpots` table. `statistics` reads this table directly, exactly as `GeneralCatchStatisticsRepository` already does (TD-020 Key Design Decision 1/2) — no new dependency on `FishingSpotRepository`'s instance methods. |
| `catch_photos` (unmodified, read from presentation only) | `SpeciesStatisticsRepository` never reads it, mirroring `GeneralCatchStatisticsRepository`'s own Key Design Decision 6. Photo resolution is a presentation-layer concern, handled by the reused `CatchListItem` for the Catch List and by `RecordCatchCard`'s own small, independent resolution for the Record Catch section. |

**One new repository instance is required.** `MapScreen` already constructs `AppDatabase` and every repository this milestone needs to reuse. This document adds exactly one more manually-constructed repository, `SpeciesStatisticsRepository(_database)`, alongside the existing ones.

---

## 2. Folder Structure

```text
lib/features/statistics/
  domain/
    species_catch_entry.dart                  (new)
    species_statistics_summary.dart            (new)
    largest_catch.dart                         (unchanged, TD-020)
    species_catch_statistic.dart               (unchanged, TD-020)
    general_catch_statistics_summary.dart      (unchanged, TD-020)
    lure_catch_statistic.dart                  (unchanged, TD-019)
    lure_type_catch_statistic.dart             (unchanged, TD-019)
    lure_statistics_summary.dart               (unchanged, TD-019)
    lure_distinguishing_detail.dart            (unchanged, TD-019)
  data/
    species_statistics_repository.dart         (new)
    general_catch_statistics_repository.dart   (unchanged, TD-020)
    lure_statistics_repository.dart            (unchanged, TD-019)
  presentation/
    widgets/
      species_statistics_page.dart             (new)
      record_catch_card.dart                   (new)
      statistics_page.dart                     (modified — one new constructor parameter)
      general_catch_statistics_tab.dart        (modified — one new constructor parameter, Species List navigation wired)
      species_catch_statistic_row.dart         (modified — onTap added, exposed as a real button)
      ranked_largest_catch_row.dart            (unchanged, TD-020)
      statistics_summary_card.dart             (unchanged, TD-019/TD-020 — reused a third time)
      lure_statistics_tab.dart                 (unchanged, TD-019)
      lure_catch_statistic_row.dart            (unchanged, TD-019)
      lure_type_catch_statistic_row.dart       (unchanged, TD-019)
```

No `data/local/` (no table), no dedicated mapper file (this repository reuses `CatchMapper` and the existing `FishingSpotEntityMapper` extension directly, exactly like `GeneralCatchStatisticsRepository`). Exact widget file separation may be adjusted if a smaller structure is clearer, consistent with the same allowance given in every prior TD in this project.

---

## 3. Domain Layer

### SpeciesCatchEntry

```dart
/// One catch of a specific species, paired with the fishing spot it belongs
/// to — everything `CatchDetailsPage` needs to open for it. Unlike
/// `LargestCatch` (TD-020), this type carries no weight requirement: a
/// species-scoped Catch List includes every catch of that species, whether
/// or not it has a recorded weight. See MFS-021 / TD-021 Key Design
/// Decision 4.
final class SpeciesCatchEntry {
  const SpeciesCatchEntry({required this.catchModel, required this.fishingSpot});

  final Catch catchModel;
  final FishingSpot fishingSpot;
}
```

`catchModel`/`fishingSpot` reuse `catches`' own `Catch` and `fishing_spots`' own `FishingSpot` directly — neither is duplicated into a `statistics`-owned type, the same "reference, not copy" discipline already established for `LargestCatch.catchModel`/`.fishingSpot` (TD-020) and `LureCatchStatistic.lure` (TD-019).

### SpeciesStatisticsSummary

```dart
/// The complete, read-only result of computing one species' statistics at a
/// single point in time. Nothing here is ever persisted — see MFS-021
/// FR-10.
final class SpeciesStatisticsSummary {
  const SpeciesStatisticsSummary({required this.species, required this.catches});

  /// The species this summary was computed for.
  final FishSpecies species;

  /// Every catch of [species] in the angler's entire catch history, sorted
  /// by weight descending (a missing weight sorts last), then catch date
  /// descending, then catch id ascending — see TD-021 Key Design Decision 7.
  /// Never capped; unlike `GeneralCatchStatisticsSummary.largestCatches`,
  /// this list always contains every matching catch.
  final List<SpeciesCatchEntry> catches;

  /// Every catch of [species], per [catches]'s own length — see TD-021 Key
  /// Design Decision 6.
  int get totalCatches => catches.length;

  /// The top-ranked entry of [catches] — see MFS-021's Conceptual Model
  /// ("Record Catch is the top-ranked entry of the Catch List") and TD-021
  /// Key Design Decision 5.
  SpeciesCatchEntry? get recordCatch => catches.isEmpty ? null : catches.first;
}
```

Per [Key Design Decision 5/6](#key-design-decisions), `recordCatch` and `totalCatches` are plain getters over `catches` — neither is a field the repository must separately compute or keep in sync.

### No value objects, no repository interface

`species` is the existing `FishSpecies` enum (MFS-009) — never re-derived or duplicated as a string. Resolving it to a Finnish display name (`FishSpecies.finnishName`) is a presentation concern, reused unchanged from `catches`, not stored here. `SpeciesStatisticsRepository` is a concrete class, constructed manually — consistent with every other repository in this project.

---

## 4. Data Layer

### SpeciesStatisticsRepository

```text
lib/features/statistics/data/species_statistics_repository.dart
```

```dart
class SpeciesStatisticsRepository {
  SpeciesStatisticsRepository(
    this._database, [
    this._catchMapper = const CatchMapper(),
  ]);

  final AppDatabase _database;
  final CatchMapper _catchMapper;

  /// Computes the full summary for [species] fresh — nothing is cached or
  /// stored. See MFS-021 FR-10.
  Future<SpeciesStatisticsSummary> getSpeciesStatistics(
    FishSpecies species,
  ) async {
    final rows = await _catchesForSpecies(species);

    final entries = [
      for (final row in rows)
        SpeciesCatchEntry(
          catchModel: _catchMapper.toDomain(row.readTable(_database.catches)),
          fishingSpot: row.readTable(_database.fishingSpots).toDomain(),
        ),
    ]..sort(_compareSpeciesCatchEntries);

    return SpeciesStatisticsSummary(species: species, catches: entries);
  }

  /// Every catch of [species], joined with its fishing spot.
  /// `Catches.fishingSpotId` is a required foreign key, so this `innerJoin`
  /// never excludes a row — the same guarantee `GeneralCatchStatisticsRepository`
  /// already relies on (TD-020 Key Design Decision 2).
  Future<List<TypedResult>> _catchesForSpecies(FishSpecies species) {
    final query = _database.select(_database.catches).join([
      innerJoin(
        _database.fishingSpots,
        _database.fishingSpots.id.equalsExp(_database.catches.fishingSpotId),
      ),
    ])..where(_database.catches.species.equals(species.name));
    return query.get();
  }
}

/// Sorts by weight descending (a missing weight sorts after every catch
/// that has one), then catch date descending, then the catch id ascending
/// as a guaranteed-unique final tiebreak — see MFS-021's ordering
/// requirement and TD-021 Key Design Decision 7.
int _compareSpeciesCatchEntries(SpeciesCatchEntry a, SpeciesCatchEntry b) {
  final aWeight = a.catchModel.weightGrams;
  final bWeight = b.catchModel.weightGrams;
  if (aWeight == null && bWeight != null) return 1;
  if (aWeight != null && bWeight == null) return -1;
  if (aWeight != null && bWeight != null) {
    final byWeight = bWeight.compareTo(aWeight);
    if (byWeight != 0) return byWeight;
  }
  final byCaughtAt = b.catchModel.caughtAt.compareTo(a.catchModel.caughtAt);
  if (byCaughtAt != 0) return byCaughtAt;
  return a.catchModel.id.compareTo(b.catchModel.id);
}
```

### Required Drift queries

| Query | Shape | Purpose |
|---|---|---|
| `_catchesForSpecies(species)` | `catches INNER JOIN fishing_spots ON fishing_spots.id = catches.fishing_spot_id WHERE catches.species = ?` | Every catch of the given species, joined with its fishing spot in the same pass. Serves the total (`catches.length`), the Record Catch (`catches.first`), and the full Catch List — all from this one query. |

Exactly one query per `getSpeciesStatistics()` call, regardless of how many catches of that species exist — never one query per catch, and never a second query to resolve the Record Catch's fishing spot separately from the rest of the list.

### Data Flow

```text
Species selected (Species List row tapped, or SpeciesStatisticsPage.open() called directly)
        ↓
SpeciesStatisticsRepository.getSpeciesStatistics(species)
        ↓
Drift: one INNER JOIN query, filtered by species (Catches ⨝ FishingSpots WHERE species = ?)
        ↓
In-memory: TypedResult rows → SpeciesCatchEntry list (CatchMapper.toDomain + FishingSpotEntityMapper.toDomain) → sorted (weight desc, missing last → date desc → id asc)
        ↓
SpeciesStatisticsSummary (species, catches; totalCatches/recordCatch derived getters)
        ↓
SpeciesStatisticsPage: header (StatisticsSummaryCard), RecordCatchCard (summary.recordCatch), Catch List (CatchListItem × summary.catches)
```

### Repository responsibilities

* running the one query above, filtered to the requested species
* mapping the joined rows into `SpeciesCatchEntry` objects, in memory
* applying the deterministic sort/tie-break, in memory
* assembling `SpeciesStatisticsSummary`

The repository does not own: photo resolution (left to the presentation layer, exactly as `GeneralCatchStatisticsRepository` already establishes — Key Design Decision 6 of TD-020), display-label resolution (`FishSpecies.finnishName` is called by the presentation layer), or any caching (MFS-021 FR-10 — every call recomputes from scratch).

### Business rules enforced by this layer

* Every catch of the requested species is included in `catches`, whether or not it has a recorded weight (MFS-021's Catch List is not weight-filtered, unlike MFS-020's Top 3 Largest Catches).
* A catch with no recorded weight sorts after every catch that has one, never treated as a tie or excluded.
* `catches` is always sorted with the deterministic tie-break from [Key Design Decision 7](#key-design-decisions) applied unconditionally.
* `catches` contains only catches of the exact species requested — no partial match, no case-insensitive comparison beyond what `FishSpecies`'s own stable `.name` equality already provides.

---

## 5. Presentation Layer

All screens are manually constructed and pushed with `Navigator.push` — no GoRouter routes, no Riverpod, consistent with every other page in this app.

### SpeciesStatisticsPage

```text
lib/features/statistics/presentation/widgets/species_statistics_page.dart
```

A `StatefulWidget`, following the exact `initState` → async load → `setState` pattern `GeneralCatchStatisticsTab`/`LureStatisticsTab` already established, pushed via a `static open()` helper mirroring `CatchDetailsPage.open()`'s own precedent (TD-014) exactly — per [Key Design Decision 10](#key-design-decisions).

```dart
class SpeciesStatisticsPage extends StatefulWidget {
  const SpeciesStatisticsPage({
    super.key,
    required this.species,
    required this.repository,
    required this.catchRepository,
    required this.catchPhotoRepository,
    required this.lureCatalogRepository,
    required this.personalTackleBoxRepository,
    required this.personalTackleBoxPhotoStorage,
  });

  final FishSpecies species;
  final SpeciesStatisticsRepository repository;

  /// Forwarded to `CatchDetailsPage.open()` when a Catch List entry (or the
  /// Record Catch card) is tapped — this page has no other use for them.
  final CatchRepository catchRepository;
  final CatchPhotoRepository catchPhotoRepository;
  final LureCatalogRepository lureCatalogRepository;
  final PersonalTackleBoxRepository personalTackleBoxRepository;
  final TackleBoxPhotoStorage personalTackleBoxPhotoStorage;

  static Future<void> open(
    BuildContext context, {
    required FishSpecies species,
    required SpeciesStatisticsRepository repository,
    required CatchRepository catchRepository,
    required CatchPhotoRepository catchPhotoRepository,
    required LureCatalogRepository lureCatalogRepository,
    required PersonalTackleBoxRepository personalTackleBoxRepository,
    required TackleBoxPhotoStorage personalTackleBoxPhotoStorage,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SpeciesStatisticsPage(
          species: species,
          repository: repository,
          catchRepository: catchRepository,
          catchPhotoRepository: catchPhotoRepository,
          lureCatalogRepository: lureCatalogRepository,
          personalTackleBoxRepository: personalTackleBoxRepository,
          personalTackleBoxPhotoStorage: personalTackleBoxPhotoStorage,
        ),
      ),
    );
  }

  @override
  State<SpeciesStatisticsPage> createState() => _SpeciesStatisticsPageState();
}
```

Load sequence (`initState`): `await widget.repository.getSpeciesStatistics(widget.species)` → on success, `setState` with the resolved `SpeciesStatisticsSummary`; on failure, `setState` with the same error message text `GeneralCatchStatisticsTab`/`LureStatisticsTab` already use ("Tilastojen lataaminen epäonnistui."), for consistent copy across the whole Statistics feature.

Rendering, once loaded (a single `ListView`, matching `GeneralCatchStatisticsTab`'s structure), inside a `Scaffold` whose `AppBar` title is `widget.species.finnishName` (satisfying MFS-021 FR-2's "species name," the same way `CatchDetailsPage`'s `AppBar` title already shows the catch's species — MFS-014 FR-3):

1. One `StatisticsSummaryCard` — title "Saaliita yhteensä", value `'${summary.totalCatches}'` — reusing the exact same title text already established for the Catches tab's own total-catches card, its third use overall.
2. An "Ennätyssaalis" (Record Catch) section: a `RecordCatchCard` for `summary.recordCatch`, or an inline empty message if `summary.recordCatch == null` (the species has no catches at the moment this page loaded — see [§9](#9-empty-and-loading-states)).
3. A "Kaikki saaliit" (Catch List) section: one `CatchListItem` per entry in `summary.catches`, in the already-sorted order, or an inline empty message if `summary.catches.isEmpty`. The Record Catch's own entry is not excluded from this list — MFS-021 FR-6 defines the Catch List as *every* catch of the species, with no carve-out for the one already shown above, the same "the same underlying data shown from two angles" pattern MFS-020 already established between its Top 3 Largest Catches and Species List.

```dart
Future<void> _openCatchDetails(SpeciesCatchEntry entry) {
  return CatchDetailsPage.open(
    context,
    fishingSpot: entry.fishingSpot,
    catchModel: entry.catchModel,
    catchRepository: widget.catchRepository,
    catchPhotoRepository: widget.catchPhotoRepository,
    lureCatalogRepository: widget.lureCatalogRepository,
    personalTackleBoxRepository: widget.personalTackleBoxRepository,
    personalTackleBoxPhotoStorage: widget.personalTackleBoxPhotoStorage,
  );
}
```

```dart
for (final entry in summary.catches)
  CatchListItem(
    key: ValueKey(entry.catchModel.id),
    catchModel: entry.catchModel,
    catchPhotoRepository: widget.catchPhotoRepository,
    onTap: () => unawaited(_openCatchDetails(entry)),
  ),
```

### RecordCatchCard

```text
lib/features/statistics/presentation/widgets/record_catch_card.dart
```

A small `StatefulWidget` resolving its own first-photo file, mirroring `CatchListItem`'s own resolution pattern (`catchPhotoRepository.getByCatchId` → `resolveFile`, in a `FutureBuilder`) rather than reusing `CatchListItem` itself, per [Key Design Decision 8/9](#key-design-decisions).

```dart
class RecordCatchCard extends StatefulWidget {
  const RecordCatchCard({
    super.key,
    required this.entry,
    required this.catchPhotoRepository,
    required this.onTap,
  });

  final SpeciesCatchEntry entry;
  final CatchPhotoRepository catchPhotoRepository;
  final VoidCallback onTap;

  @override
  State<RecordCatchCard> createState() => _RecordCatchCardState();
}
```

Rendering: a `Card`, `InkWell`-wrapped (`onTap: widget.onTap`), containing a `Row` with:

* a leading `CatchPhotoThumbnail` (reused unmodified, 88px, same fallback-to-placeholder behavior already established by `CatchListItem` — [Key Design Decision 8](#key-design-decisions)) when a photo resolves, or the same broken/missing-photo placeholder treatment `CatchListItem` already uses when it does not,
* a trailing `Column` showing: `formatCatchMeasurementLine(entry.catchModel)` (weight/length, joined and gracefully `null` when both are absent — reused unchanged from `catch_formatters.dart`), `formatCatchDate(entry.catchModel.caughtAt)`, and `entry.fishingSpot.name` (the catch's location — always present, since `fishingSpotId` is a required foreign key; see [§8](#8-error-handling)).

A semantic label combining species (via the page's already-known `FishSpecies`), weight/length, date, and location is attached at the card level, per MFS-021's Accessibility Expectations.

### Species List row — `SpeciesCatchStatisticRow` (modified)

```text
lib/features/statistics/presentation/widgets/species_catch_statistic_row.dart
```

Gains a required `onTap` parameter. The row's content is unchanged (species name, catch count, trailing chevron); what changes is that the row is now wrapped in an `InkWell(onTap: onTap, ...)`, and the `Semantics(..., excludeSemantics: true)` wrapper that previously suppressed button semantics (MFS-020 FR-8) is removed — the row is now a real, accessible button, exposing the same semantic label as before (species and catch count) plus the implicit tap action `InkWell` already provides, the identical pattern `CatchListItem` already uses. This is exactly the change MFS-020's own Accessibility Expectations text names as expected once this milestone ships.

### Catches tab — `GeneralCatchStatisticsTab` (modified)

```text
lib/features/statistics/presentation/widgets/general_catch_statistics_tab.dart
```

Gains one new required constructor parameter, `speciesStatisticsRepository` (a `SpeciesStatisticsRepository`), and one new private method:

```dart
Future<void> _openSpeciesStatistics(SpeciesCatchStatistic statistic) {
  return SpeciesStatisticsPage.open(
    context,
    species: statistic.species,
    repository: widget.speciesStatisticsRepository,
    catchRepository: widget.catchRepository,
    catchPhotoRepository: widget.catchPhotoRepository,
    lureCatalogRepository: widget.lureCatalogRepository,
    personalTackleBoxRepository: widget.personalTackleBoxRepository,
    personalTackleBoxPhotoStorage: widget.personalTackleBoxPhotoStorage,
  );
}
```

Every other dependency `SpeciesStatisticsPage` needs is already present on `widget` — this tab already threads `catchRepository`/`catchPhotoRepository`/`lureCatalogRepository`/`personalTackleBoxRepository`/`personalTackleBoxPhotoStorage` to open Catch Details from a Top 3 Largest Catches entry (TD-020 §5), so opening Species Statistics needs exactly one additional constructor parameter, not five.

The Species List's `for` loop gains an `onTap`:

```dart
for (final statistic in summary.speciesCatchCounts)
  SpeciesCatchStatisticRow(
    key: ValueKey(statistic.species.name),
    statistic: statistic,
    onTap: () => unawaited(_openSpeciesStatistics(statistic)),
  ),
```

### Tabbed shell — `StatisticsPage` (modified)

```text
lib/features/statistics/presentation/widgets/statistics_page.dart
```

Gains one new required constructor parameter, `speciesStatisticsRepository`, threaded straight through to `GeneralCatchStatisticsTab` — the same "thin composing shell taking every dependency its tabs need" shape TD-020 Key Design Decision 10 already established (growing from seven parameters to eight, following the exact precedent of TD-020 growing `StatisticsPage` from one parameter to seven). No other part of `StatisticsPage` changes.

### Loading / Error / Empty summary

| State | Where | Behavior |
|---|---|---|
| Loading | `SpeciesStatisticsPage` | Centered `CircularProgressIndicator`, replacing the entire page body — the same treatment `GeneralCatchStatisticsTab`/`LureStatisticsTab` already use. |
| Load error | `SpeciesStatisticsPage` | "Tilastojen lataaminen epäonnistui." plus a "Yritä uudelleen" retry button re-running the load — the same copy reused verbatim from both existing tabs. |
| The species has no catches at load time | `SpeciesStatisticsPage` | The total card shows `0`; the Record Catch section shows an inline empty message (e.g. "Ei vielä saaliita."); the Catch List section shows the same empty message. See [§9](#9-empty-and-loading-states) for why this can occur despite normally being unreachable through ordinary navigation. |

---

## 6. Navigation

```text
Statistics
        ↓ (existing AppBar entry point, unchanged)
StatisticsPage                       [statistics]
        ↓ (DefaultTabController, Catches tab, MFS-020, unchanged in this milestone beyond the Species List's onTap)
GeneralCatchStatisticsTab            [statistics]
        ↓ (Species List row tapped — the wiring this document adds)
SpeciesStatisticsPage                [statistics, new]
        ↓ (Catch List entry, or the Record Catch card, tapped)
CatchDetailsPage                     [catches, existing, unmodified — MFS-014]
```

`GeneralCatchStatisticsTab._openSpeciesStatistics()` pushes `SpeciesStatisticsPage` via its own `static open()` helper (§5), the same `Navigator.push`/`MaterialPageRoute` pattern used everywhere else in this application — no GoRouter route, no new navigation primitive. `MapScreen._openStatistics()` is updated only to construct `SpeciesStatisticsRepository` and pass it to `StatisticsPage`; the entry point into `StatisticsPage` itself is unchanged.

---

## 7. State Management

No Riverpod, no `Provider`, no `InheritedWidget` — consistent with every other feature in this codebase. `SpeciesStatisticsPage` is a `StatefulWidget` whose state (`_summary`, `_isLoading`, `_errorMessage`) is plain `State` fields, following the exact pattern `GeneralCatchStatisticsTab`/`LureStatisticsTab` already use. `RecordCatchCard` is the only other stateful widget this milestone introduces, holding only its own resolved thumbnail `Future`, mirroring `CatchListItem`'s own minimal state exactly.

`SpeciesCatchStatisticRow`'s modification (an added `onTap` parameter) does not make it stateful — it remains a pure, stateless, `const`-constructible row. `StatisticsPage` and `GeneralCatchStatisticsTab` remain a `StatelessWidget` and a `StatefulWidget` respectively, unchanged in kind.

---

## 8. Error Handling

| Scenario | Behavior |
|---|---|
| `getSpeciesStatistics()` throws (e.g. a database read error) | Caught in `SpeciesStatisticsPage._load()`; the page shows a clear error message plus a retry action; the application does not crash. |
| Retry after a load failure | Tapping "Yritä uudelleen" re-runs `_load()` from scratch; no partial or stale data is shown while the retry is in flight. |
| A Record Catch or Catch List entry's photo fails to resolve | Unchanged, in two places: `CatchListItem`'s existing `FutureBuilder`/placeholder handling (MFS-014) applies exactly as-is for the Catch List; `RecordCatchCard`'s own equivalent, independently-implemented handling ([Key Design Decision 9](#key-design-decisions)) applies for the Record Catch section. Neither introduces new photo-resolution logic. |
| `CatchDetailsPage.open()` is invoked for a catch whose fishing spot cannot be re-resolved (should not occur — `FishingSpots.id` is never deleted out from under an existing `Catches.fishingSpotId` without cascading catch deletion first, per MFS-008) | Not applicable by construction, the exact same reasoning TD-020 §9 already documented for its own Top 3 Largest Catches navigation: `SpeciesCatchEntry.fishingSpot` is resolved in the same query that produced `SpeciesCatchEntry.catchModel`, so the two are always mutually consistent at the moment they are displayed. |
| The species has zero catches when `SpeciesStatisticsPage` loads (e.g. its one catch was deleted, or its species reassigned via edit, between MFS-020's Species List rendering and this page's own load completing) | Not an error — treated as the ordinary empty state ([§9](#9-empty-and-loading-states)), since MFS-021's Edge Cases explicitly allow for a catch's species changing away mid-session. |

---

## 9. Empty and Loading States

Covered in full in [§5](#loading--error--empty-summary). Summary: a single centered `CircularProgressIndicator` for loading; a single error message plus retry for failure; an inline empty message for the Record Catch section and the Catch List section independently, mirroring the per-section empty-state discipline TD-019/TD-020 already established, rather than a single whole-page empty widget.

This page's "species has zero catches" state is reachable in practice only through a narrow timing window (a concurrent deletion or species edit between MFS-020's Species List render and this page's own load), since `SpeciesStatisticsPage` is only ever opened by tapping a Species List row that, at the moment it was rendered, had at least one catch (MFS-020's Species List only lists species with `catchCount >= 1`). It is still fully handled, per MFS-021's own Edge Cases, rather than assumed impossible.

---

## 10. Performance Considerations

**Query count:** exactly one per `getSpeciesStatistics()` call — regardless of how many catches of that species exist. Never one query per catch, never a second query to resolve the Record Catch's fishing spot separately (no N+1), matching the discipline already established across every repository in this codebase.

**Aggregation cost:** O(n) over the species' own catch rows, where `n` is bounded above by the angler's entire catch history (already established as small — tens to low hundreds of rows — by TD-019 Key Design Decision 2 and reaffirmed by TD-020 Key Design Decision 3) and, for any single species, necessarily smaller still. A single linear mapping pass (`TypedResult` → `SpeciesCatchEntry`), no nested loops, no repeated scans.

**Sorting cost:** O(k log k) over the number of catches of that one species (`k`, bounded above by `n`), using an explicit multi-key comparator ([§4](#4-data-layer)), never relying on `List.sort`'s lack of a stability guarantee.

**No caching.** Every open of `SpeciesStatisticsPage` re-runs the query and recomputes from scratch, per MFS-021 FR-10. Because this page is a freshly pushed route on every open rather than a tab that can be revisited without reconstruction, this is the natural behavior with no extra mechanism required — see [Key Design Decision 10](#key-design-decisions).

**Photo loading:** the Catch List's thumbnails are unchanged from every other reuse of `CatchListItem` (MFS-013/MFS-014/MFS-020) — its own `cacheWidth`/`cacheHeight` sizing and `FutureBuilder`-based resolution apply exactly as-is. `RecordCatchCard`'s own thumbnail reuses `CatchPhotoThumbnail`'s existing `cacheWidth`/`cacheHeight` sizing unchanged (decoded at 88px display size, never full source resolution), per [Key Design Decision 8](#key-design-decisions).

**List rendering:** the Catch List renders via a plain `ListView`/inline `for` loop, matching `GeneralCatchStatisticsTab`'s existing discipline (TD-020 §11). Given the expected scale of a single species' worth of a single user's catch history, this is a consistency choice, not a scale-driven necessity.

**No new database index.** See [Key Design Decision 11](#key-design-decisions) — a full-table scan filtered by species, over a table already established to hold at most low hundreds of rows, carries no realistic performance risk at this application's scale.

---

## 11. Testing Strategy

Follows the same layered testing philosophy as TD-019/TD-020: domain tests for construction/getters, repository tests for query and ordering behavior against a real in-memory database, widget tests for the presentation surfaces, and a physical-device pass at the end. No migration test is needed — this milestone changes no schema.

**Domain** (`test/features/statistics/domain/`):
`species_catch_entry_test.dart` — valid construction with and without a recorded weight (no assertion to reject, unlike `LargestCatch`). `species_statistics_summary_test.dart` — `recordCatch` returns the first list element when `catches` is non-empty and `null` when empty; `totalCatches` always equals `catches.length`, including `0`.

**Repository** (`species_statistics_repository_test.dart`, against `AppDatabase(NativeDatabase.memory())`, seeded directly via Drift inserts, mirroring `general_catch_statistics_repository_test.dart`'s setup):

* no catches of the requested species at all → `catches` empty, `totalCatches == 0`, `recordCatch == null`
* catches of other species are never included in the result
* one catch of the species, with a recorded weight → appears in `catches`, is `recordCatch`, with its fishing spot correctly resolved
* multiple catches of the species with different weights → sorted weight descending, `recordCatch` is the heaviest
* a catch with no recorded weight sorts after every catch that has one, regardless of its own catch date
* every catch of the species has no recorded weight → `catches` sorted by catch date descending, then id ascending; `recordCatch` is the most recently caught entry, not an error or `null`
* a tie in weight between two catches of the species resolves deterministically and matches the documented comparator (weight descending → catch date descending → id ascending)
* two catches of the species at two different fishing spots each resolve to their own correct `FishingSpot` in `catches` (not swapped or duplicated)
* deleting a catch of the species (simulated via direct row deletion), or editing one's species away from the requested value, changes `catches`/`totalCatches`/`recordCatch` on the next call, with no stale data
* editing an existing catch's weight such that it becomes, or stops being, the heaviest of the species is reflected on the next call

**Widget** (`test/features/statistics/presentation/widgets/`):

`species_statistics_page_test.dart` (against a real in-memory `AppDatabase`/`SpeciesStatisticsRepository`, mirroring `general_catch_statistics_tab_test.dart`'s setup) — `AppBar` title shows the species' Finnish name; loading indicator shown while pending; error message and retry shown on failure, and retry re-attempts the load; a species with no catches renders the total as `0` and both the Record Catch and Catch List sections showing their empty message; a populated summary renders the total card, `RecordCatchCard` for the top-ranked entry, and every catch (including the record catch's own entry again) in the Catch List in the documented sort order; tapping a Catch List entry (and, separately, tapping the `RecordCatchCard`) opens `CatchDetailsPage` for the correct catch and fishing spot; a catch missing a photo, weight, length, or (in the unreachable-by-construction case) fishing spot renders without a broken layout anywhere on the page.

`record_catch_card_test.dart` — renders a resolved photo when one exists, a placeholder when it does not; renders `formatCatchMeasurementLine`'s output when at least one of weight/length is present, and omits it cleanly when both are absent; always renders the catch date and the fishing spot's name; tapping the card invokes `onTap`; exposes the documented combined semantic label.

`species_catch_statistic_row_test.dart` (updated from its MFS-020-era assertions) — tapping the row now invokes the given `onTap`; the row now exposes button semantics (a regression update from the original "no button semantics" assertion, per MFS-020's own anticipated future change).

`general_catch_statistics_tab_test.dart` (updated) — tapping a Species List row now opens `SpeciesStatisticsPage` for the correct species; every other existing assertion in this file (summary cards, Top 3 Largest Catches ranking/navigation) continues to pass unmodified in intent.

`statistics_page_test.dart` (updated) — constructor signature gains `speciesStatisticsRepository`; both tabs still render in the correct order with Catches as the default, unchanged from TD-020.

**Integration/physical Android testing:**
open Statistics from the existing entry point, confirm the Catches tab still opens by default; tap a Species List row and confirm Species Statistics opens for the correct species with the correct total, Record Catch, and Catch List against a real, previously-logged set of catches of that species (including at least one with a missing photo, missing weight/length, and — indirectly, via a catch at a different fishing spot — verify the correct location shown); tap a Catch List entry and confirm Catch Details opens for the correct catch; tap the Record Catch card itself and confirm the same; verify a species whose only catch has no recorded weight still shows a Record Catch; verify switching back to the Lure Statistics tab, and the rest of the Catches tab, still work exactly as before; verify full offline/airplane-mode operation.

---

## 12. Risks

| Risk | Category | Mitigation |
|---|---|---|
| This document changes two existing MFS-020-owned presentation files (`species_catch_statistic_row.dart`, `general_catch_statistics_tab.dart`) in a project where MFS-021's own Out of Scope list mentions "no change to MFS-020's Catches tab." | Specification interpretation | Addressed explicitly in [Key Design Decision 1](#key-design-decisions): MFS-021 FR-1 requires exactly this wiring, and MFS-020's own text already named it as an expected future change. The change is narrowly scoped to navigation wiring — no computation, query, or ordering logic in the Catches tab is touched. |
| `RecordCatchCard` duplicates a small amount of `CatchListItem`'s private thumbnail-resolution logic rather than sharing it. | Maintainability | Accepted per [Key Design Decision 9](#key-design-decisions): the duplicated logic is small (roughly a dozen lines), `CatchListItem`'s version is not exposed for reuse, and extracting a shared helper for a single second caller would be a premature abstraction under this project's own Development Rules. |
| A second read-model type (`SpeciesCatchEntry`) with the same field shape as `LargestCatch` (TD-020) now exists in the same feature. | Design clarity | Deliberate, per [Key Design Decision 4](#key-design-decisions): the two types differ in exactly the constraint that matters (weight required vs. not), and a future reader comparing them will find that difference documented in both files, not an unexplained duplicate. |
| `StatisticsPage`'s constructor grows to eight parameters. | Maintainability | Matches the already-accepted growth pattern TD-020 Key Design Decision 10 itself established when `StatisticsPage` grew from one parameter to seven; the same "no dependency-bundle object introduced merely to shorten the list" reasoning from TD-020's Architecture Review applies unchanged here. |
| The species-filtered query performs a full table scan with no dedicated index. | Performance | Accepted at this application's scale — see [Key Design Decision 11](#key-design-decisions) and [§10](#10-performance-considerations). If a future real-world usage pattern ever proves this wrong, adding an index on `Catches.species` is a small, purely additive schema change confined to a future migration, not a reason to add one speculatively now. |

---

## 13. Future Compatibility

* **Average weight and average length for a species** (MFS-021 Future Extensions) — computable directly from `SpeciesStatisticsSummary.catches` (e.g. `catches.where((e) => e.catchModel.weightGrams != null)`), with no new query and no change to this document's return shape.
* **Filtering this page's Catch List** (e.g. by date range or fishing spot) — `_catchesForSpecies()`'s existing `WHERE` clause already has room for an additional condition; a filter would extend that one query, with no change to the aggregation or sorting logic that follows it.
* **A map-based presentation of where a species has been caught** (MFS-021 Future Extensions) — `SpeciesCatchEntry.fishingSpot` already carries `latitude`/`longitude` for every catch in the list; no new data dependency would be required.
* **Visual (chart/graph) presentation** — would consume `SpeciesStatisticsSummary.catches` as its input, the same already-computed list this milestone's list/card presentation already uses.
* **Cloud synchronization** — unaffected. This feature is entirely read-only over data owned elsewhere; nothing here touches the repository-hides-the-data-source principle (ADR-0001, ADR-0005) that already governs `catches`' and `fishing_spots`' own data layers.

---

## Dependencies

No new external package dependencies. This milestone reuses the existing stack and patterns:

* Flutter, Dart
* Drift (per ADR-0005) — read-only queries against existing tables only; no schema change
* The existing Repository pattern, feature-first structure, and manual dependency construction (ADR-0001, ADR-0003, ADR-0006)
* The existing `Catch` domain model and `CatchMapper` (MFS-009/TD-009), consumed read-only, unmodified
* The existing `FishingSpot` domain model and `FishingSpotEntityMapper` extension (MFS-004), consumed read-only, unmodified
* `CatchListItem`, `CatchPhotoThumbnail`, `formatCatchMeasurementLine`, `formatCatchDate`, `FishSpecies.finnishName` (MFS-011/MFS-013/MFS-014), reused unchanged
* `CatchDetailsPage.open()` (MFS-014), reused unmodified as this milestone's navigation target
* `StatisticsSummaryCard` (MFS-019/TD-019, renamed by TD-020), reused a third time with no change
* The Statistics feature's existing tabbed shell, presentation conventions, and Species List (MFS-019/MFS-020/TD-019/TD-020)

`flutter_riverpod` is not used by this feature, for the same reasons documented in TD-015 through TD-020.

---

## Expected Files To Create

```text
lib/features/statistics/domain/species_catch_entry.dart
lib/features/statistics/domain/species_statistics_summary.dart
lib/features/statistics/data/species_statistics_repository.dart
lib/features/statistics/presentation/widgets/species_statistics_page.dart
lib/features/statistics/presentation/widgets/record_catch_card.dart
```

Plus new test files under `test/features/statistics/...` per [§11](#11-testing-strategy).

## Expected Files To Modify

```text
lib/features/statistics/presentation/widgets/species_catch_statistic_row.dart   (add required onTap; expose real button semantics)
lib/features/statistics/presentation/widgets/general_catch_statistics_tab.dart  (add speciesStatisticsRepository constructor parameter; wire Species List onTap to SpeciesStatisticsPage.open())
lib/features/statistics/presentation/widgets/statistics_page.dart              (add speciesStatisticsRepository constructor parameter, threaded to GeneralCatchStatisticsTab)
lib/features/map/presentation/map_screen.dart                                  (construct SpeciesStatisticsRepository; pass it through _openStatistics to StatisticsPage)
test/features/statistics/presentation/widgets/species_catch_statistic_row_test.dart   (updated for onTap/button semantics)
test/features/statistics/presentation/widgets/general_catch_statistics_tab_test.dart  (add Species List navigation assertion)
test/features/statistics/presentation/widgets/statistics_page_test.dart              (constructor signature updated)
```

No other existing file is modified. `lib/core/database/app_database.dart` is **not** modified — see [Database Impact](#database-impact). `lib/features/catches/`, `lib/features/catch_photos/`, `lib/features/fishing_spots/`, `lib/features/lure_catalog/`, and `lib/features/personal_tackle_box/` are not modified.

---

## Database Impact

**None.** No new Drift table, no new column, no schema version change, no migration. The schema version remains at `6`, as established by TD-017 and unchanged through TD-018/TD-019/TD-020. `SpeciesStatisticsRepository` reads the existing `Catches` and `FishingSpots` tables through a single, read-only, filtered join query — nothing about `AppDatabase`'s table registration, migration strategy, or schema version changes.

Confirm at implementation time that the live schema version is still `6` before beginning, consistent with the same hedge every prior TD in this project has required.

---

## Test Impact

* **New tests:** every domain, repository, and widget test file listed in [§11](#11-testing-strategy) that does not already exist.
* **Updated for a changed constructor signature or added behavior:** `species_catch_statistic_row_test.dart` (onTap/button semantics), `general_catch_statistics_tab_test.dart` (new navigation assertion), `statistics_page_test.dart` (new required constructor parameter).
* **Untouched:** every `catches`, `catch_photos`, `fishing_spots`, `lure_catalog`, and `personal_tackle_box` test file; `general_catch_statistics_repository_test.dart`, `lure_statistics_repository_test.dart`, and every other existing `statistics` domain/repository/widget test not listed above, since none of that code changes.

---

## Implementation Notes

To be completed during implementation, following the established convention of recording any deviation from this document here, with justification.

---

## Implementation Notes for Claude Code

* **Confirm the live schema version is `6` before starting** — if it has moved past `6` since this document was written, nothing in this design changes.
* **Do not touch `lib/core/database/app_database.dart`.** This milestone reads two already-registered tables directly; no table registration, schema version, or migration changes.
* **Do not modify anything under `lib/features/catches/`, `lib/features/catch_photos/`, `lib/features/fishing_spots/`, `lib/features/lure_catalog/`, or `lib/features/personal_tackle_box/`.** This design reads their tables/domain models and reuses `CatchMapper`, `FishingSpotEntityMapper`, `CatchListItem`, `CatchPhotoThumbnail`, `formatCatchMeasurementLine`, `formatCatchDate`, and `CatchDetailsPage.open()` exactly as they exist today.
* **Do not modify `lib/features/statistics/data/general_catch_statistics_repository.dart` or `lib/features/statistics/data/lure_statistics_repository.dart`, or any of their domain types.** This milestone reads no data through either repository and changes no query, sort, or aggregation logic belonging to MFS-019/MFS-020.
* **The only permitted changes to existing `statistics` presentation files are the two named in [Expected Files To Modify](#expected-files-to-modify)** (`species_catch_statistic_row.dart`, `general_catch_statistics_tab.dart`), plus `statistics_page.dart`'s one new constructor parameter — per [Key Design Decision 1](#key-design-decisions). If satisfying a requirement here seems to need touching anything else in `catches`/`catch_photos`/`fishing_spots`, stop and re-read that decision rather than adding one.
* **`CatchListItem` itself is reused as-is — do not fork it or add fields to it (including a location field).** The Catch List's rows show exactly what `CatchListItem` already shows; location is shown only in `RecordCatchCard`, a separate, new widget.
* **`RecordCatchCard` must reuse `CatchPhotoThumbnail` unmodified** — do not build a new, larger image-display widget for it, per [Key Design Decision 8](#key-design-decisions).
* **The ordering comparator in [§4](#4-data-layer) must be applied unconditionally**, including its explicit "missing weight sorts last" handling — do not simplify it to a plain `weightGrams` comparison, which would crash or misorder on a `null` value.
* **All user-visible text is Finnish**, per this project's Development Rules. Reuse "Tilastojen lataaminen epäonnistui." and "Yritä uudelleen" verbatim (matching every existing Statistics tab), and reuse "Saaliita yhteensä" verbatim for this page's own total-catches card, per [§5](#5-presentation-layer).
* **No Riverpod, no repository interface, no DAO/service/use-case layer, no `watch()`.** Construct `SpeciesStatisticsRepository` manually in `MapScreen`, exactly like every other repository already there.
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

* The implementation satisfies all requirements in MFS-021.
* The implementation follows TD-021, or documents and justifies each deviation.
* Tapping a row in MFS-020's Species List opens `SpeciesStatisticsPage` for that species.
* The page's header shows the species name (via the `AppBar` title) and the total number of catches of that species.
* A Record Catch section shows the top-ranked catch of the species (per the documented ordering), with photo, weight, length, and location shown only when available, rendering cleanly when any are missing.
* The Catch List shows every catch of the species, reusing `CatchListItem` unmodified, in the documented deterministic order.
* Selecting any Catch List entry, or the Record Catch card, opens the existing Catch Details view for the correct catch and fishing spot.
* No new Drift table, column, schema version, or migration was introduced.
* `catches`, `catch_photos`, `fishing_spots`, `lure_catalog`, and `personal_tackle_box` are functionally and structurally unchanged; `GeneralCatchStatisticsRepository` and `LureStatisticsRepository`'s computation, data, and behavior are unchanged.
* Data access follows the existing repository-based architecture, with no service layer, use-case layer, DAO layer, or repository interface introduced.
* Every capability works with no network connection.
* `dart format .`, `flutter analyze`, and `flutter test` all pass.
* Architecture review is completed.
* Physical Android testing is completed.
* Documentation (`docs/project-status.md`, `docs/roadmap.md`) is updated in a separate, subsequent step — not part of this document's own completion.
