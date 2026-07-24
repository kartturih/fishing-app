# TD-025 — Catch Search & Filtering

## Status

Implemented — architecture review passed, all automated tests passing (818/818), `flutter analyze` clean (8 pre-existing/accepted info-level lints, none introduced by this milestone), and physical Android testing completed successfully. This document designs MFS-025's approved MVP scope (including its two post-approval refinements: the search field's clear button and its tap-to-focus requirement); the implementation follows this document's domain, database, repository, and presentation design with no architectural deviation — see Implementation Notes below for the two test-only conventions applied and for the `MapScreen` widget-test coverage added.

## Related

- Implements: MFS-025 — Catch Search & Filtering (the approved specification this document designs)
- Depends on: MFS-009 / TD-009 — Catch Foundation (`Catch`, `Catches`, `CatchRepository`, `CatchMapper` — read, not modified)
- Depends on: MFS-011 / TD-011 — View Catches for Fishing Spot (`CatchRepository.getByFishingSpotId`'s existing deterministic ordering, reused verbatim for this milestone's own ordering)
- Depends on: MFS-014 / TD-014 — Catch Details View (`CatchDetailsPage`/`CatchDetailsPage.open()`, reused entirely unmodified as this milestone's sole navigation target)
- Depends on: MFS-017 / TD-017 — Assign Lure to Catch (`Catch.lureVariantId`, the `KeyAction.restrict` precedent, and the "unresolvable/retired lure handled without crashing" precedent this design relies on)
- Depends on: MFS-019 / TD-019 — Lure-Based Catch Statistics (the "only lures with recorded catches" filter-scoping precedent; the historical-stability principle this document's lure-matching design deliberately preserves)
- Depends on: MFS-023 / TD-023 — Catch Notes (`Catch.notes`, explicitly excluded from this milestone's search — unchanged)
- Depends on: MFS-024 / TD-024 / ADR-0007 — Water Bodies and Fishing Spot Hierarchy (`WaterBody`, `WaterBodyRepository`, `FishingSpot.waterBodyId`'s non-null-at-the-domain-level guarantee, and the `Catches ⨝ FishingSpots ⨝ WaterBodies` join idiom this document extends one step further)
- Sibling precedent: `GeneralCatchStatisticsRepository` / `SpeciesStatisticsRepository` / `WaterBodyStatisticsRepository` / `LureStatisticsRepository` (`lib/features/statistics/data/`) — the established "one focused, concrete, sibling repository per read-model, reading whichever tables it needs directly" pattern this document's own new repository follows
- Sibling precedent: `LureCatalogRepository.browse()` (`lib/features/lure_catalog/data/lure_catalog_repository.dart`) — the closest existing text-search-with-filters repository method in this codebase; reused as a design template, not as a dependency (see [Key Design Decision 5](#key-design-decisions))

---

## Goal

Implement MFS-025: a new, minimal global catch-browsing page, reached from `MapScreen`'s existing AppBar entry-point convention, with an always-visible, debounced, live text search across species/water body/fishing spot/lure brand/lure model, and a single-select-per-category filter bottom sheet (water body, species, lure, date range) — entirely as Drift-driven queries against the existing schema, with no new table, column, or schema version, and no change to catch creation, editing, deletion, map, statistics, photo, or notes behavior.

The implementation shall satisfy MFS-025.

---

## Fixed Architectural Decisions (not reconsidered here)

Restated from MFS-025 and the task brief that commissioned this document — binding constraints, not open questions:

- No new database table, column, or schema version, unless proven genuinely unavoidable (none is found necessary — see [Query Strategy](#9-query-strategy--drift-design) and [Performance Considerations](#16-performance-considerations)).
- No repository interface, DAO, service layer, or use-case layer — concrete repositories only, per `docs/development-rules.md` and every prior TD in this project.
- No generic, reusable "search framework" — this milestone's query and state logic is specific to catches.
- No online service, no AI/NLP search, no autocomplete/suggestions.
- No redesign of the application's primary navigation shell — exactly one more `MapScreen` AppBar entry, following the existing, established pattern.
- No per-row repository lookups from the results list (the data layer returns an already-enriched read-model — MFS-025 FR-17).
- No implementation logic inside presentation widgets — all search/filter query construction lives in the data layer (MFS-025 Architecture Constraints).
- Existing catch creation, editing, deletion, map, statistics, photo, and notes behavior is unaffected.
- Each filter category is single-select in this MVP (MFS-025 Conceptual Model — "Filters hold one active value per category").
- The search field's clear button and tap-to-focus behavior are MVP requirements (MFS-025 FR-20/FR-21, added after initial approval), not deferred enhancements.

---

## Constraint Compliance Summary

| Constraint (task brief / MFS-025) | How this design satisfies it |
|---|---|
| Offline-first | Every query in this document is a local Drift/SQLite query; no network call anywhere. |
| No schema version increase unless unavoidable | Not needed — see [§9](#9-query-strategy--drift-design)/[§16](#16-performance-considerations); schema stays at version 8. |
| No cloud dependency | None introduced. |
| No AI/NLP search, no autocomplete | Not designed; plain substring/enum-membership matching only. |
| No generic search framework | One page-specific, non-generic repository (`CatchSearchRepository`) and one page-specific presentation-state class (`CatchSearchPageState`) — neither is reusable/abstracted beyond this feature. |
| No primary-navigation redesign | One more `MapScreen` AppBar `IconButton`, identical in kind to the two that already exist. |
| No per-row repository lookups | `CatchSearchRepository.search()` returns fully enriched `CatchSearchResult`s from one joined query; the widget layer performs zero additional repository calls per row (only the existing, already-established per-row *photo-thumbnail* lookup inside `CatchListItem`, unchanged from every other catch list in this app). |
| No implementation logic inside widgets | All criteria-building, matching, and query execution live in `CatchSearchRepository`/`CatchSearchCriteria`; `CatchSearchPage` only holds UI state and delegates. |
| Preserve existing catch/map/statistics/photos/notes behavior | No file under `catches` (beyond the two additive changes in [§17](#17-files-affected--file-plan)), `catch_photos`, `fishing_spots`, `water_bodies`, `lure_catalog`, `personal_tackle_box`, or existing `statistics` pages is behaviorally changed. |

---

## Current State

Inspected directly, in the current codebase, before designing this change:

| Area | Current shape |
|---|---|
| Schema version | `8` (per `lib/core/database/app_database.dart`). Tables: `FishingSpots`, `Catches`, `CatchPhotos`, `LureModels`, `LureVariants`, `TackleBoxEntries`, `WaterBodies`. |
| `Catches` table ([catches_table.dart](../../lib/features/catches/data/local/catches_table.dart)) | `id`, `fishingSpotId` (→ `FishingSpots.id`, `onDelete: cascade`), `species` (raw `TEXT`, the `FishSpecies` enum's `.name`, e.g. `"pike"` — never the Finnish display name), `caughtAt` (epoch millis `INTEGER`), `weightGrams`/`lengthMillimeters` (nullable, `CHECK > 0`), `lureVariantId` (nullable → `LureVariants.id`, `onDelete: restrict`), `notes` (nullable), `createdAt`, `updatedAt`. **No index of any kind exists on this table** — no index on `species`, `caughtAt`, `fishingSpotId`, or `lureVariantId`. |
| `FishingSpots` table | `id`, `name`, `latitude`, `longitude`, `waterBodyId` (schema-nullable, domain-non-nullable → `WaterBodies.id`, `onDelete: restrict`), `createdAt`. No index. |
| `WaterBodies` table | `id`, `name`, `createdAt`. No FK, no index. |
| `LureModels` table | `id`, `manufacturer`, `productFamily` (nullable), `modelName`, `lureType`, `defaultImageReference` (nullable), `searchText` (precomputed, Dart-lowercased, Finnish-case-correct), `seedVersion` (nullable), `createdAt`, `updatedAt`. Indexed on `manufacturer` and `lureType`. |
| `LureVariants` table | `id`, `lureModelId` (→ `LureModels.id`, cascade), `variantName`/`colorName`/`manufacturerColorCode` (nullable), `lengthMillimeters`/`weightGrams`/`minRunningDepthMillimeters`/`maxRunningDepthMillimeters` (nullable, `CHECK`), `buoyancy`/`imageReference` (nullable), `searchText` (precomputed, same convention as `LureModels`), `seedVersion` (nullable), `retiredAt` (nullable — soft delete), `createdAt`, `updatedAt`. Indexed on `lureModelId`. |
| `CatchRepository` ([catch_repository.dart](../../lib/features/catches/data/catch_repository.dart)) | Concrete class. `create()`, `update()`, `delete()`, `getByFishingSpotId()` (the only list query — ordered `caughtAt` desc, `createdAt` desc, `id` asc), `getById()`. No `search`/`browse`/unscoped-list method. No `.watch()`. |
| `WaterBodyRepository` / `FishingSpotRepository` | Concrete classes (TD-024). `WaterBodyRepository.loadAll()`/`loadAllWithSpotCounts()`/`getNearby()` establish the "one join, aggregate/dedupe in a Dart `Map`" idiom this document reuses. |
| `LureCatalogRepository.browse()` ([lure_catalog_repository.dart](../../lib/features/lure_catalog/data/lure_catalog_repository.dart)) | `Future<List<LureCatalogEntry>> browse({String? searchText, String? manufacturer, String? lureType})` — the closest existing text-search precedent: normalizes (`trim().toLowerCase()`), builds a `%pattern%` via a private `_escapeLikePattern`/`_likeEscapeChar` helper, matches against the precomputed `searchText` columns on both `LureModels`/`LureVariants`, and **excludes retired variants** (`retiredAt.isNull()`). This last point matters directly to this document — see [Key Design Decision 5](#key-design-decisions). |
| `LureCatalogMapper.entryFromRows()` ([lure_catalog_mapper.dart](../../lib/features/lure_catalog/data/lure_catalog_mapper.dart)) | A pure, stateless mapping function (`variantRow` + `modelRow` → `LureCatalogEntry`) — no filtering, no query. Freely reusable without touching `lure_catalog` at all. |
| State management / DI | `flutter_riverpod` is a dependency and wraps `main.dart` in `ProviderScope`, but is used nowhere else in the codebase (confirmed by an exhaustive grep). The actual, universal convention is: plain `StatefulWidget` + repositories constructed once as `late final` fields on `MapScreen` and threaded down via required constructor parameters + `setState`. No sealed/enum view-state type exists anywhere — every page hand-rolls its own `bool _isLoading` / `String? _errorMessage` / nullable-data-field trio (confirmed in `SpeciesStatisticsPage`, `LureCatalogListPage`, and others). `.watch()`/`Stream` is used in exactly one place in the whole codebase (`FishingSpotRepository.watchAll()`) and is never actually consumed by any widget. |
| Stale-response guarding | `LureCatalogListPage` already establishes an incrementing `int _requestId` guard (`final requestId = ++_requestId; ...; if (!mounted \|\| requestId != _requestId) return;`) around its own async load — the established idiom this document reuses for its debounced search. |
| `MapScreen` AppBar ([map_screen.dart](../../lib/features/map/presentation/map_screen.dart)) | Two `IconButton`s (`openLureToolsButton` → `Icons.menu_book` → `_openLureTools()`; `openStatisticsButton` → `Icons.bar_chart` → `_openStatistics()`), each pushing a full page via `MaterialPageRoute`, repositories passed as already-constructed `late final` fields. Explicitly documented in-code as a temporary entry point ("no drawer, bottom navigation, or home menu"). |
| `CatchDetailsPage` / `.open()` ([catch_details_page.dart](../../lib/features/catches/presentation/widgets/catch_details_page.dart)) | `static Future<CatchDetailsResult> open(BuildContext, {required FishingSpot fishingSpot, required Catch catchModel, required CatchRepository, required CatchPhotoRepository, required LureCatalogRepository, required PersonalTackleBoxRepository, required TackleBoxPhotoStorage, required WaterBodyRepository})`. Every existing caller (`FishingSpotDetailsBottomSheet`, `SpeciesStatisticsPage`, `WaterBodyStatisticsPage`) discards the returned `CatchDetailsResult` and unconditionally reloads its own list afterward — the established "just reload, don't branch on the result" convention this document also follows. |
| `CatchListItem` ([catch_list_item.dart](../../lib/features/catches/presentation/widgets/catch_list_item.dart)) | Constructor takes exactly `catchModel`, `catchPhotoRepository`, `onTap` — renders species, `formatCatchMeasurementLine`, `formatCatchDateTime`, and a lazily-resolved first-photo thumbnail. No location or lure rendering capability today. |
| `RecordCatchCard` ([record_catch_card.dart](../../lib/features/statistics/presentation/widgets/record_catch_card.dart)) | The closest existing "enriched catch row" precedent: takes a pre-joined `SpeciesCatchEntry` (`catchModel` + `fishingSpot` + `waterBody`) rather than three separate parameters, and renders the water body name as its location line. Lives in `statistics`, not reusable as-is (different domain type, different feature), but its shape is the template this document's own `CatchSearchResult` follows. |
| Test conventions | Repository tests: real `AppDatabase(NativeDatabase.memory())`, no mocks. Widget tests: same in-memory database plus fake repositories built by **subclassing the real repository and overriding one method** (e.g. `_PendingRepository extends SpeciesStatisticsRepository`), not a separate mock framework. No `fakeAsync`/`Timer` testing precedent exists anywhere in `test/` — this document's debounce tests are the first of their kind in this codebase (see [Testing Strategy](#18-testing-strategy)). |

---

## Key Design Decisions

This section answers the questions most likely to be raised in review, before the detailed sections below implement them.

**1. A new, concrete `CatchSearchRepository` is introduced inside the existing `catches` feature — not a method added to `CatchRepository`, and not a new feature directory.** `CatchRepository` today has a narrow, single-table-scoped CRUD contract (create/update/delete, one fishing-spot-scoped list query). Every other read-model this application has ever built on top of `Catches` — `GeneralCatchStatisticsRepository`, `SpeciesStatisticsRepository`, `WaterBodyStatisticsRepository`, `LureStatisticsRepository` — is its **own, separate, sibling repository class**, despite all of them reading `Catches` directly; none is a method bolted onto `CatchRepository`. `CatchSearchRepository` follows that exact same established precedent, one level closer to `catches` itself (since global browsing, unlike Statistics, is not an aggregation concern) rather than living in `statistics`. This keeps `CatchRepository`'s existing, simple, heavily-tested CRUD surface completely unchanged and gives the new multi-table-joined, criteria-driven query its own focused, independently testable home. It is placed in `lib/features/catches/data/` (not a new feature directory) because `catches` already imports and directly uses `fishing_spots`, `lure_catalog`, and `personal_tackle_box` data/domain types inside its own presentation layer today (`CatchDetailsPage` already does exactly this) — this milestone's cross-feature reads are not a new kind of coupling for this feature, only a new repository doing them.

**2. `CatchSearchRepository` reads `Catches`/`FishingSpots`/`WaterBodies`/`LureVariants`/`LureModels` directly — never through `FishingSpotRepository`, `WaterBodyRepository`, or `LureCatalogRepository`'s own instance methods (with one deliberate, narrow exception — see Decision 5).** This is the same "a repository reads whichever tables it needs directly" discipline already established by `GeneralCatchStatisticsRepository` (TD-020) and `WaterBodyRepository` (TD-024 Key Design Decision 5).

**3. No new database index, and no schema version increase.** `Catches` currently has zero indexes. Every predicate this milestone's main query needs (`fishingSpotId`, `species`, `caughtAt`, `lureVariantId`) would benefit from an index at a large enough scale, but this application's expected scale — one angler's own personal catch log, the same "tens to low hundreds" (and, over years, plausibly low thousands) assumption every prior TD in this project has made — is well within what SQLite resolves via full-table scan in single-digit milliseconds on modern mobile hardware, especially amortized by the 250–300 ms debounce this milestone already requires. Adding an index now would be optimizing for data that does not exist yet, which this project's own development rules caution against ("avoid premature abstractions"). This mirrors TD-017's deferral of an index on `Catches.lureVariantId` and TD-024's deferral of one on `FishingSpots.waterBodyId` — both accepted, both still undone, both explicitly revisitable. See [Performance Considerations](#16-performance-considerations) for the concrete revisit trigger.

**4. Fish species text-matching is resolved by scanning the fixed, 19-value `FishSpecies` enum in Dart — never the `Catches` table.** `Catches.species` stores the enum's English `.name` (`"pike"`), never its Finnish display name (`"Hauki"`, which exists only as a Dart `switch` in `fish_species_extensions.dart`). A SQL `LIKE` against the stored column can never match a Finnish query. The resolution: normalize the query, then compute `FishSpecies.values.where((s) => s.finnishName.toLowerCase().contains(normalizedQuery)).map((s) => s.name)` — a bounded, constant-time (19 comparisons) operation regardless of catch-history size — and pass the result into `catches.species.isIn(matchedNames)`. Dart's `String.toLowerCase()` is Unicode-aware and folds `Ä`/`Ö`/`Å` correctly, unlike SQLite's built-in `LIKE`/`LOWER()` (ASCII-only without the ICU extension, which this project does not use) — so this is not merely a workaround for the missing column, it is also the *more correct* way to match Finnish text than a SQL `LIKE` would be.

**5. Water body and fishing spot name-matching reuses the exact same bounded, in-Dart-enum-style resolution — extended to two more small, bounded reference tables — rather than a SQL `LIKE`.** `WaterBodies`/`FishingSpots` have no precomputed lowercase search column (unlike `lure_catalog`, which added one specifically to get correct Finnish case-folding at a "thousands of variants" scale it explicitly anticipated — MFS-015). Rather than repeat that schema investment here (which MFS-025 explicitly forbids for this milestone — FR-18/FR-19 constraints), this document treats `WaterBodies`/`FishingSpots` the same way it treats the `FishSpecies` enum: **small, bounded reference tables** (this project's own repeated "tens to low hundreds" scale assumption, already relied on by `WaterBodyRepository.loadAll()`/`getNearby()` and `FishingSpotRepository.loadAll()` today) that can be loaded whole and matched in Dart with fully correct Unicode case-folding, then reduced to a small candidate-id list passed into the main query as `.isIn(...)`. **This is never a scan of catch history** — it is a scan of two small reference tables, run once per search, structurally identical in kind (and cost) to the species-enum resolution above.
For lure brand/model text, however, `LureVariants`/`LureModels` are **not** treated the same way, because MFS-015 explicitly anticipates that table growing to "thousands of variants" — the same scale `lure_catalog` already solved correctly with its precomputed `searchText` columns. Loading the *whole* lure catalog into Dart to string-match it would repeat exactly the mistake `lure_catalog` already avoided. Instead, `CatchSearchRepository` runs its own small, targeted SQL query directly against `LureModels.searchText`/`LureVariants.searchText` (reusing the columns that already exist, already correctly Finnish-lowercased) — **not** by calling `LureCatalogRepository.browse()`. This is a deliberate exception to Decision 2: `browse()` excludes retired variants (`retiredAt.isNull()`), but MFS-019 FR-10 already established that a catch's assigned lure "remains resolvable even if the underlying catalog variant is later retired" — searching by a retired lure's own brand/model name must still find catches that used it, exactly the same historical-stability principle Lure-Based Catch Statistics already relies on. Calling `browse()` would silently and incorrectly exclude those catches from text search. `CatchSearchRepository` therefore writes its own minimal `LureModels ⨝ LureVariants` join with no `retiredAt` filter, reusing the same `searchText` columns and the same LIKE-escaping technique `browse()` already established (reimplemented locally as a small, private, ~3-line helper — a narrow, deliberate, and explicitly acknowledged duplication of a trivial escaping utility, not of `browse()`'s substantially larger feature set). `LureCatalogRepository`/`browse()` itself is not modified, called, or depended on anywhere in this design — satisfying MFS-025's explicit "no change to `lure_catalog`" Data Ownership constraint.

**6. The main search query therefore never needs a SQL `LIKE` of its own.** Because every name-based match (species, water body, fishing spot, lure) is pre-resolved into a small candidate-id list *before* the main query runs, `CatchSearchRepository`'s own joined `Catches` query only ever needs `.isIn(...)`/`.equals(...)` predicates — never a `LIKE` pattern, and therefore no wildcard-escaping concern of its own (the one place `LIKE` is used — the lure-matching auxiliary query in Decision 5 — already handles its own escaping). This keeps the main, potentially-larger-table query as cheap as a plain equality/membership scan.

**7. `CatchListItem` is extended additively with three new, optional, nullable `String?` parameters (`waterBodyName`, `fishingSpotName`, `lureLabel`) rather than duplicated into a second, parallel result-row widget.** MFS-025 left this choice open for Technical Design. Every existing call site (MFS-011, MFS-014, MFS-019 through MFS-022, and the undocumented water-body statistics view) constructs `CatchListItem` today with none of these parameters; adding them as optional, defaulting to `null` (meaning "render nothing extra," i.e. today's exact existing appearance), changes nothing for any of them. This follows the exact same additive-optional-parameter precedent already used for `AddToTackleBoxAction.initialIsOwned` (TD-018) and is preferred over a new, parallel widget because a second widget would have to duplicate `CatchListItem`'s existing photo-thumbnail resolution and tap-to-details wiring — exactly the "avoid duplicate widgets" the project's development rules warn against.

**8. One plain, non-generic, page-owned immutable presentation-state class — `CatchSearchPageState` — holds every piece of this page's state.** MFS-025/the task brief explicitly asked for "one clear immutable presentation-state model" while also explicitly forbidding "a generic search framework" and any "additional search states or complexity." This document resolves that tension the same way `SpeciesStatisticsPage`/`LureCatalogListPage` already resolve their own analogous tension — a plain `StatefulWidget` holding one state value, replaced wholesale via `copyWith`/`setState` — except bundled into a single class (rather than several loose fields) because this page genuinely has more moving state than a typical page (raw text, debounced criteria, filter options, loading, error, results). It is not a sealed hierarchy, not a state machine, and not reusable outside this one page — see [State Management](#12-state-management).

**9. A `Timer`-based debounce (250–300 ms) plus the existing `_requestId`-increment stale-response guard, both already established elsewhere in this codebase, are reused verbatim rather than any new async-coordination primitive.** See [State Management](#12-state-management) for the full lifecycle.

**10. Filter categories list only values actually present in the angler's own catch history, never the full reference-data universe.** Mirrors the already-established Statistics-feature convention (Lure Statistics' "only lures with recorded catches," MFS-019 FR-6; the Species List/Fishing Spot List's own "only entries with at least one logged catch" convention, MFS-020/MFS-022) — a water body, species, or lure with zero catches would trivially always produce zero results if offered as a filter, so it is never offered. See [Filter Data Sources](#10-filter-data-sources).

**11. A selected filter value can never reference a now-deleted or now-unavailable value, by construction — this is not defended against with special-case code, it is a consequence of this application's own existing deletion invariants.** A water body appears as a filter option only if it has at least one catch through one of its fishing spots (Decision 10); ADR-0007/MFS-024 already guarantee a water body with any fishing spot (and therefore any catch) cannot be deleted. A fishing spot can be deleted, but doing so cascades and deletes its catches with it (MFS-008/MFS-009) — and fishing spot is not a filter category in this milestone (only a text-search/display field), so this case does not even arise for filters. A lure variant can be retired but never deleted while referenced (`KeyAction.restrict`, MFS-017), and retired variants remain fully resolvable (MFS-019 FR-10) and remain in the filter list (Decision 10 makes no retired-status distinction). `FishSpecies` is a fixed enum, never deleted. The only remaining defensive behavior needed is that a filter value matching nothing simply produces zero rows — never a crash — which is true of `.equals()`/`.isIn()` by construction.

---

## 1. Overview and Folder Structure

This document extends the existing **`catches`** feature only; no new feature directory is introduced, and no other feature's domain model, schema, or repository contract changes.

```text
lib/
├── features/
│   ├── catches/
│   │   ├── data/
│   │   │   └── catch_search_repository.dart                (new)
│   │   ├── domain/
│   │   │   ├── catch_search_criteria.dart                  (new)
│   │   │   ├── catch_search_result.dart                    (new)
│   │   │   └── catch_filter_options.dart                   (new)
│   │   └── presentation/
│   │       └── widgets/
│   │           ├── catch_search_page.dart                  (new)
│   │           ├── catch_filter_bottom_sheet.dart          (new)
│   │           └── catch_list_item.dart                    (modified: + optional waterBodyName/fishingSpotName/lureLabel)
│   └── map/
│       └── presentation/
│           └── map_screen.dart                              (modified: new AppBar entry + repository field)
```

No file under `fishing_spots`, `water_bodies`-owning code, `lure_catalog`, `personal_tackle_box`, `catch_photos`, or `statistics` is modified.

---

## 2. Domain Objects

### `CatchSearchCriteria` (new)

```dart
// lib/features/catches/domain/catch_search_criteria.dart
import 'package:fishing_app/features/catches/domain/fish_species.dart';

/// One immutable snapshot of "what the angler is currently asking to see" on
/// the global catch-browsing page (MFS-025): a free-text query plus up to
/// one active selection per filter category (single-select per category,
/// MFS-025's own MVP decision — enforced structurally here by each filter
/// field being a single nullable value, not a collection).
///
/// [query] is the trimmed (not lowercased) text the angler typed — see
/// [CatchSearchRepository] for where and how case-insensitive matching is
/// actually performed. [dateFrom]/[dateTo] are each normalized to that
/// calendar day's start/end (00:00:00.000 / 23:59:59.999) by the caller
/// before being placed here, so the repository can apply a plain inclusive
/// `>=`/`<=` comparison with no date-boundary logic of its own.
///
/// Deliberately given value equality and `copyWith`, unlike `Catch`/
/// `FishingSpot`/`WaterBody` (which intentionally have neither, per their
/// own TDs) — this type is a query/comparison value object, constructed
/// fresh on every state change and compared directly in widget tests
/// ("was the repository called with the expected criteria?"), not a
/// mutable, identity-bearing entity. See Key Design Decision 8.
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
      species: identical(species, _unset) ? this.species : species as FishSpecies?,
      lureVariantId: identical(lureVariantId, _unset)
          ? this.lureVariantId
          : lureVariantId as String?,
      dateFrom: identical(dateFrom, _unset) ? this.dateFrom : dateFrom as DateTime?,
      dateTo: identical(dateTo, _unset) ? this.dateTo : dateTo as DateTime?,
    );
  }

  /// Every filter cleared; [query] left untouched — used by the filter
  /// sheet's "clear all filters" action (MFS-025 FR-11), which must not
  /// also clear the text search (that is FR-20's own, separate action).
  CatchSearchCriteria clearFilters() => CatchSearchCriteria(query: query);

  @override
  bool operator ==(Object other) =>
      other is CatchSearchCriteria &&
      other.query == query &&
      other.waterBodyId == waterBodyId &&
      other.species == species &&
      other.lureVariantId == lureVariantId &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo;

  @override
  int get hashCode =>
      Object.hash(query, waterBodyId, species, lureVariantId, dateFrom, dateTo);
}

const Object _unset = Object();
```

The `_unset`-sentinel `copyWith` shape (rather than plain nullable parameters) is required because every filter field is itself nullable and must be independently *clearable* (set back to `null`) — a plain `T? copyWith({T? x})` cannot distinguish "leave unchanged" from "set to null." This is the same sentinel-`copyWith` technique required anywhere a nullable field must be explicitly clearable; no existing domain model in this codebase needed it before (none has a clearable nullable field driven by `copyWith`), so this is a new, narrow, one-off addition local to this one class, not a new project-wide convention.

### `CatchSearchResult` (new)

```dart
// lib/features/catches/domain/catch_search_result.dart
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';

/// One fully-enriched search result row: a [Catch] paired with everything
/// the results list (MFS-025 FR-13) and `CatchDetailsPage` (FR-14) need to
/// render/navigate, with no further per-row repository call. Mirrors
/// `statistics`' own `SpeciesCatchEntry` shape (catch + fishingSpot +
/// waterBody) exactly, extended with an optional, already-resolved
/// [lure] — reusing `lure_catalog`'s own [LureCatalogEntry] read-model by
/// reference rather than duplicating manufacturer/model fields onto this
/// type, per this project's established "reference, never duplicate"
/// discipline (ADR-0007).
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
```

No `==`/`hashCode`/`copyWith` — like `SpeciesCatchEntry`, this is a read-only row freshly constructed per query, never compared or mutated by the presentation layer.

### `CatchFilterOptions` (new)

```dart
// lib/features/catches/domain/catch_filter_options.dart
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';

/// The selectable values for each filter category (MFS-025 FR-8), computed
/// from the angler's *actual catch history* only (Key Design Decision 10)
/// — never the full reference-data universe. Loaded once when the
/// filter sheet is first opened; the date-range category needs no
/// data-sourced options (a plain calendar-range picker, see UI Flow).
final class CatchFilterOptions {
  const CatchFilterOptions({
    required this.waterBodies,
    required this.species,
    required this.lures,
  });

  final List<WaterBody> waterBodies;
  final List<FishSpecies> species;
  final List<LureCatalogEntry> lures;

  static const empty = CatchFilterOptions(waterBodies: [], species: [], lures: []);
}
```

---

## 3. Schema Impact

**None.** No new table, no new column, no schema version increase (remains `8`). Every field this milestone searches, filters, or displays already exists in `Catches`, `FishingSpots`, `WaterBodies`, `LureModels`, and `LureVariants`. `lib/core/database/app_database.dart` is not modified.

---

## 4. Repository Implementation — `CatchSearchRepository` (new)

```dart
// lib/features/catches/data/catch_search_repository.dart
class CatchSearchRepository {
  CatchSearchRepository(this._database);

  final AppDatabase _database;

  Future<List<CatchSearchResult>> search(CatchSearchCriteria criteria) async {
    final query = _buildBaseJoin();
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

  Future<CatchFilterOptions> getFilterOptions() async {
    final rows = await _buildBaseJoin().get();

    final waterBodies = <String, WaterBody>{};
    final species = <FishSpecies>{};
    final lures = <String, LureCatalogEntry>{};

    for (final row in rows) {
      final waterBody = row.readTable(_database.waterBodies).toDomain();
      waterBodies[waterBody.id] = waterBody;
      species.add(_speciesFromStored(row.readTable(_database.catches).species));

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
      ..sort((a, b) => a.finnishName.toLowerCase().compareTo(b.finnishName.toLowerCase()));
    final sortedLures = lures.values.toList()
      ..sort((a, b) {
        final manufacturerCompare = a.manufacturer.toLowerCase().compareTo(b.manufacturer.toLowerCase());
        if (manufacturerCompare != 0) return manufacturerCompare;
        return a.modelName.toLowerCase().compareTo(b.modelName.toLowerCase());
      });

    return CatchFilterOptions(
      waterBodies: sortedWaterBodies,
      species: sortedSpecies,
      lures: sortedLures,
    );
  }

  // --- query construction (private) ---

  JoinedSelectStatement<Table, dynamic> _buildBaseJoin() {
    return _database.select(_database.catches).join([
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
  }

  Future<Expression<bool>?> _buildPredicate(CatchSearchCriteria criteria) async {
    Expression<bool>? predicate;
    void and(Expression<bool> expr) => predicate = predicate == null ? expr : predicate! & expr;

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
      and(_database.catches.caughtAt.isBiggerOrEqualValue(
        criteria.dateFrom!.millisecondsSinceEpoch,
      ));
    }
    if (criteria.dateTo != null) {
      and(_database.catches.caughtAt.isSmallerOrEqualValue(
        criteria.dateTo!.millisecondsSinceEpoch,
      ));
    }

    final normalizedQuery = criteria.query.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      and(await _textMatchPredicate(normalizedQuery));
    }

    return predicate;
  }

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

    final matchedFishingSpotIds = await _matchingFishingSpotIds(normalizedQuery);
    if (matchedFishingSpotIds.isNotEmpty) {
      expr = expr | _database.fishingSpots.id.isIn(matchedFishingSpotIds);
    }

    final matchedLureVariantIds = await _matchingLureVariantIds(normalizedQuery);
    if (matchedLureVariantIds.isNotEmpty) {
      expr = expr | _database.catches.lureVariantId.isIn(matchedLureVariantIds);
    }

    return expr;
  }

  /// Bounded, in-memory match over the fixed 19-value [FishSpecies] enum —
  /// never a scan of `Catches`. See Key Design Decision 4.
  List<String> _matchingSpeciesNames(String normalizedQuery) {
    return [
      for (final species in FishSpecies.values)
        if (species.finnishName.toLowerCase().contains(normalizedQuery)) species.name,
    ];
  }

  /// Bounded, in-memory match over every existing water body — a small
  /// reference table at this application's scale, the same assumption
  /// `WaterBodyRepository.loadAll()`/`getNearby()` already rely on
  /// (TD-024 §16). See Key Design Decision 5.
  Future<List<String>> _matchingWaterBodyIds(String normalizedQuery) async {
    final rows = await _database.select(_database.waterBodies).get();
    return [
      for (final row in rows)
        if (row.name.toLowerCase().contains(normalizedQuery)) row.id,
    ];
  }

  /// Bounded, in-memory match over every existing fishing spot — same
  /// "small reference table" assumption as above.
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
  /// exclude retired variants (`browse()` does) — see Key Design Decision 5.
  Future<List<String>> _matchingLureVariantIds(String normalizedQuery) async {
    final pattern = '%${_escapeLikePattern(normalizedQuery)}%';
    final query = _database.select(_database.lureVariants).join([
      innerJoin(
        _database.lureModels,
        _database.lureModels.id.equalsExp(_database.lureVariants.lureModelId),
      ),
    ])..where(
      _database.lureModels.searchText.like(pattern, escapeChar: _likeEscapeChar) |
          _database.lureVariants.searchText.like(pattern, escapeChar: _likeEscapeChar),
    );
    final rows = await query.get();
    return [for (final row in rows) row.readTable(_database.lureVariants).id];
  }

  CatchSearchResult _resultFromRow(TypedResult row) {
    final catchEntity = row.readTable(_database.catches);
    final variantRow = row.readTableOrNull(_database.lureVariants);
    final modelRow = row.readTableOrNull(_database.lureModels);

    return CatchSearchResult(
      catchModel: _catchMapper.toDomain(catchEntity),
      fishingSpot: row.readTable(_database.fishingSpots).toDomain(),
      waterBody: row.readTable(_database.waterBodies).toDomain(),
      lure: (variantRow != null && modelRow != null)
          ? _lureCatalogMapper.entryFromRows(variantRow: variantRow, modelRow: modelRow)
          : null,
    );
  }

  FishSpecies _speciesFromStored(String storedValue) =>
      FishSpecies.values.firstWhere((s) => s.name == storedValue);

  static const String _likeEscapeChar = r'\';

  /// Escapes `%`, `_`, and the escape character itself, so a query
  /// containing those characters is matched literally — mirrors
  /// `LureCatalogRepository`'s own private helper of the same shape. A
  /// small, deliberate, acknowledged duplication of a ~3-line utility (see
  /// Key Design Decision 5) rather than a shared, cross-feature import.
  String _escapeLikePattern(String input) {
    return input
        .replaceAll(_likeEscapeChar, '$_likeEscapeChar$_likeEscapeChar')
        .replaceAll('%', '$_likeEscapeChar%')
        .replaceAll('_', '$_likeEscapeChar_');
  }

  final CatchMapper _catchMapper = const CatchMapper();
  final LureCatalogMapper _lureCatalogMapper = const LureCatalogMapper();
}
```

No `getById`/CRUD methods — this repository is read-only and additive to `CatchRepository`, never a replacement for it.

---

## 5. Repository Interfaces

None. Per `docs/development-rules.md` and every prior TD in this project, `CatchSearchRepository` is a concrete class only, constructed directly against `AppDatabase` and passed via constructor injection.

---

## 6. Dependency Injection

Following this project's established manual-constructor-injection convention (no Riverpod provider anywhere for a repository):

- `MapScreen` gains one new field: `late final CatchSearchRepository _catchSearchRepository = CatchSearchRepository(_database);` — same pattern as every existing repository field there.
- `CatchSearchPage` receives `catchSearchRepository` plus every repository `CatchDetailsPage.open()` itself requires (`catchRepository`, `catchPhotoRepository`, `lureCatalogRepository`, `personalTackleBoxRepository`, `personalTackleBoxPhotoStorage`, `waterBodyRepository`) — mirroring `StatisticsPage`'s existing constructor exactly, which already threads this same repository set through for its own `CatchDetailsPage` navigation needs.
- `CatchFilterBottomSheet` receives only `CatchFilterOptions` (already loaded by its caller) plus the currently-active `CatchSearchCriteria` — it performs no repository access of its own.
- No Riverpod provider, no service locator, no DI framework is introduced.

---

## 7. UI Flow — Navigation and Page Ownership

### Entry point

`MapScreen`'s AppBar gains a third `IconButton`, alongside the existing two, in the same `actions` list:

```dart
IconButton(
  key: const Key('openCatchSearchButton'),
  icon: const Icon(Icons.search),
  tooltip: 'Etsi saaliita',
  onPressed: _openCatchSearch,
),
```

```dart
void _openCatchSearch() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => CatchSearchPage(
        catchSearchRepository: _catchSearchRepository,
        catchRepository: _catchRepository,
        catchPhotoRepository: _catchPhotoRepository,
        lureCatalogRepository: _lureCatalogRepository,
        personalTackleBoxRepository: _personalTackleBoxRepository,
        personalTackleBoxPhotoStorage: _tackleBoxPhotoStorage,
        waterBodyRepository: _waterBodyRepository,
      ),
    ),
  );
}
```

This is the exact shape of `_openLureTools()`/`_openStatistics()` — same `IconButton`/`tooltip`/`MaterialPageRoute` idiom, same repository-field-passthrough style, same `Key(...)` naming convention (`open<Feature>Button`). **Why this remains consistent with `MapScreen` as the current navigation hub:** nothing about how the application navigates changes — there is still no drawer, no bottom navigation, no home screen; one more icon button pushing one more full-screen page is the same pattern applied a third time, not a fourth kind of thing. Per MFS-025's own Conceptual Model and this task's brief, this does not warrant an ADR.

### Preserving query/filters across `CatchDetailsPage`

`CatchSearchPage` is pushed once via `Navigator.push` and remains mounted, underneath, for the entire duration of a `CatchDetailsPage` visit — standard `Navigator` stack semantics, the same reason `FishingSpotDetailsBottomSheet`'s own catch list and `SpeciesStatisticsPage` already survive a Catch Details visit unchanged today. `CatchSearchPageState` therefore requires **no special persistence mechanism** to survive the round trip — it is simply never disposed during that visit. Following the established "just reload, don't branch on the result" convention already used by every existing `CatchDetailsPage.open()` caller:

```dart
Future<void> _openCatchDetails(CatchSearchResult result) async {
  await CatchDetailsPage.open(
    context,
    fishingSpot: result.fishingSpot,
    catchModel: result.catchModel,
    catchRepository: widget.catchRepository,
    catchPhotoRepository: widget.catchPhotoRepository,
    lureCatalogRepository: widget.lureCatalogRepository,
    personalTackleBoxRepository: widget.personalTackleBoxRepository,
    personalTackleBoxPhotoStorage: widget.personalTackleBoxPhotoStorage,
    waterBodyRepository: widget.waterBodyRepository,
  );
  if (!mounted) return;
  _executeSearch(_state.effectiveCriteria); // unconditional reload, same criteria
}
```

The active `_state.effectiveCriteria` (raw text, every filter) is untouched by this round trip; only the *results* are re-queried, so a create/edit/delete made from Catch Details is reflected (MFS-025 FR-15) while the angler's search/filter context is preserved exactly (FR-12).

---

## 8. UI Structure

```text
CatchSearchPage (StatefulWidget)
└── Scaffold
    ├── AppBar(title: Text('Saaliit'))
    └── body: Column
        ├── _SearchAndFilterRow (private widget within catch_search_page.dart — small
        │   enough not to warrant its own file)
        │   ├── Expanded(TextField(
        │   │     controller: _searchController,
        │   │     focusNode: _searchFocusNode,
        │   │     decoration: InputDecoration(
        │   │       hintText: 'Hae kalalajia, vesistöä tai viehettä…',
        │   │       suffixIcon: _state.rawQuery.isNotEmpty
        │   │           ? IconButton(icon: Icon(Icons.clear), tooltip: 'Tyhjennä haku', onPressed: _onClearPressed)
        │   │           : null,
        │   │     ),
        │   │   ))
        │   └── Badge(
        │         isLabelVisible: _state.effectiveCriteria.hasActiveFilters,
        │         child: IconButton(icon: Icon(Icons.filter_list), tooltip: 'Suodattimet', onPressed: _openFilterSheet),
        │       )
        └── Expanded(body content, by state — see below)
```

Body content, by `_state`:

| Condition | Rendered |
|---|---|
| `_state.isLoading && _state.results == null` | `Center(child: CircularProgressIndicator())` — first load only. |
| `_state.errorMessage != null` | Centered error text + a `FilledButton` retrying `_executeSearch(_state.effectiveCriteria)`. |
| `_state.results!.isEmpty && _state.effectiveCriteria.isEmpty` | "Ei vielä saaliita." (genuinely empty catch history — see [§13](#13-empty-and-legacy-data-handling)). |
| `_state.results!.isEmpty && !_state.effectiveCriteria.isEmpty` | "Hakuehdoilla ei löytynyt saaliita." + a `TextButton`/`FilledButton` "Tyhjennä haku ja suodattimet" calling `_clearAll()`. |
| otherwise | `ListView.builder` of `CatchListItem`s (extended, [Key Design Decision 7](#key-design-decisions)), one per `CatchSearchResult`. |

Each row:

```dart
CatchListItem(
  catchModel: result.catchModel,
  catchPhotoRepository: widget.catchPhotoRepository,
  waterBodyName: result.waterBody.name,
  fishingSpotName: result.fishingSpot.name,
  lureLabel: result.lure == null
      ? null
      : '${result.lure!.manufacturer} ${result.lure!.modelName}',
  onTap: () => _openCatchDetails(result),
)
```

`CatchListItem`'s new optional lines render beneath the existing measurement/date lines, only when non-null — every existing caller (passing none of these three parameters) is visually and behaviorally unchanged.

The filter sheet (`CatchFilterBottomSheet`, a new `showModalBottomSheet`-based widget, following the exact Material 3 bottom-sheet convention already used by `WaterBodySelectionBottomSheet`) offers: a `WaterBody` picker (radio-style list from `CatchFilterOptions.waterBodies`, "Ei valintaa" to clear), a `FishSpecies` picker (same shape, from `CatchFilterOptions.species`, showing `finnishName`), a lure picker (same shape, from `CatchFilterOptions.lures`, showing `'${manufacturer} ${modelName}'`), and a date range control (`showDateRangePicker` with static `firstDate: DateTime(2000)`/`lastDate: DateTime.now()` bounds — no query needed to determine real bounds, per "avoid unnecessary abstractions"), plus "Tyhjennä suodattimet" (calls `criteria.clearFilters()`) and "Käytä" (apply) actions. It returns an updated `CatchSearchCriteria` (or `null` on cancel) to its caller, which merges it into `_state` and immediately re-queries (no debounce for filter changes — only free-text entry debounces).

---

## 9. Query Strategy / Drift Design

| Query | Shape | Notes |
|---|---|---|
| `CatchSearchRepository.search(criteria)` | One `Catches ⨝ FishingSpots [inner] ⨝ WaterBodies [inner] ⨝ LureVariants [left outer] ⨝ LureModels [left outer]`, `WHERE` built from up to 5 AND-ed explicit-filter predicates plus one OR-group text predicate, `ORDER BY caughtAt DESC, createdAt DESC, id ASC`. | `innerJoin` for `FishingSpots`/`WaterBodies` is correct because `Catches.fishingSpotId` and `FishingSpots.waterBodyId` are both always populated for every real row (the same reasoning already documented in TD-020/TD-024 for their own identical two-hop join). `leftOuterJoin` for `LureVariants`/`LureModels` is required because `Catches.lureVariantId` is genuinely nullable, and even when set may reference an unresolvable row — see [§13](#13-empty-and-legacy-data-handling). |
| `CatchSearchRepository.getFilterOptions()` | The same base join, no `WHERE`, aggregated/deduped into three `Map`/`Set`s in Dart. | Mirrors `WaterBodyRepository.loadAllWithSpotCounts()`'s exact "one join, aggregate in Dart via a keyed `Map`" idiom — one query, no SQL `GROUP BY`, consistent with every Statistics repository in this project. |
| `_matchingWaterBodyIds`/`_matchingFishingSpotIds` | Two single, unfiltered `SELECT`s (`WaterBodies`, `FishingSpots`), matched in Dart. | Bounded by this app's own "small reference table" scale assumption (Key Design Decision 5) — run once per non-empty text search, never per catch row. |
| `_matchingLureVariantIds` | One `LureVariants ⨝ LureModels` `innerJoin`, `WHERE searchText LIKE ? ESCAPE '\'` on either table's `searchText`, no `retiredAt` filter. | The one `LIKE` in this whole design; reuses `lure_catalog`'s own precomputed, Finnish-safe `searchText` columns without depending on `LureCatalogRepository`. |

**Text matching strategy, end to end:** normalize (`trim().toLowerCase()`, Dart's Unicode-aware case folding); resolve up to four candidate-id/name lists (species names, water body ids, fishing spot ids, lure variant ids), each via the smallest query/scan appropriate to that table's actual scale; combine with `|` (OR) into one `Expression<bool>`; AND that into the same predicate as every active, explicit filter. **Empty-candidate-list safety:** each candidate list is `isIn`-ed only when non-empty — an empty list is skipped entirely (contributing nothing, i.e. effectively `false`, to the OR-group) rather than ever emitting a Drift `.isIn([])`, which would need to be confirmed not to generate an invalid empty-`IN ()` SQL clause; skipping avoids relying on that assumption at all.

**Whitespace normalization:** `criteria.query.trim()` happens once, at the point the debounced/applied query is committed into `CatchSearchCriteria` (in the presentation layer, not repeated inside the repository) — consistent with `CatchSearchCriteria.query`'s own documented contract of already being trimmed.

**Empty-query behavior:** `criteria.query.trim().isEmpty` skips the entire text-match predicate construction (no auxiliary queries run at all) — an empty search costs nothing beyond whatever explicit filters are active.

**Filter AND semantics:** every explicit filter (`waterBodyId`, `species`, `lureVariantId`, `dateFrom`, `dateTo`) is unconditionally AND-ed via the `and(...)` helper; the text-match OR-group (when present) is itself AND-ed in as one more term — exactly MFS-025 FR-9's required shape.

**Inclusive date-range boundaries:** `caughtAt.isBiggerOrEqualValue(dateFrom.millisecondsSinceEpoch)` / `.isSmallerOrEqualValue(dateTo.millisecondsSinceEpoch)` — inclusive at both ends by construction (`>=`/`<=`, not `>`/`<`). The picker/state layer is responsible for normalizing a user-picked calendar day into a start-of-day/end-of-day `DateTime` before it reaches `CatchSearchCriteria` (see [§2](#2-domain-objects)'s doc comment) — the repository itself performs no date-boundary arithmetic.

**No raw/string-built SQL anywhere in this design** — every predicate above is a typed Drift `Expression<bool>`, every join a typed `innerJoin`/`leftOuterJoin`, every ordering a typed `OrderingTerm`.

---

## 10. Filter Data Sources

- **Water body, species, lure:** `CatchFilterOptions`, loaded once via `CatchSearchRepository.getFilterOptions()` the first time the filter sheet is opened (cached in `_state.filterOptions` for the remainder of the page's lifetime — re-fetching on every sheet open is unnecessary since a new catch/water body/lure appearing mid-session is not expected to be common enough to justify a refetch-per-open; if it is ever felt to matter, refetching is a one-line change, not an architectural one).
- **Date range:** no data-sourced options — a plain `showDateRangePicker` with static bounds (`DateTime(2000)` to `DateTime.now()`), per "avoid unnecessary abstractions."
- **Only currently-used values are shown** (Key Design Decision 10) — not the full `WaterBodyRepository.loadAll()`/full lure catalog universe.
- **Single-select per category:** enforced structurally by `CatchSearchCriteria`'s fields each being a single nullable scalar (`String?`/`FishSpecies?`), not a `List` — the filter sheet's own picker UI (radio-list-style selection) is a direct reflection of that type shape, not a separately-enforced UI rule.
- **Deleted/unavailable selected values:** cannot occur for any currently-active filter, by construction — see [Key Design Decision 11](#key-design-decisions).
- **"Clear all" vs. per-filter clearing:** `CatchSearchCriteria.clearFilters()` (clears every filter, keeps `query`) backs the sheet's "Tyhjennä suodattimet" action; each individual picker's own "Ei valintaa" entry clears just that one field via `copyWith(waterBodyId: null)` (etc., using the sentinel-aware `copyWith`).
- **Active-filter indicator:** a Material `Badge` wrapping the filter `IconButton`, `isLabelVisible: criteria.hasActiveFilters` — a standard Material 3 widget, no custom painting.

---

## 11. Domain-to-Database Mapping

No new mapper file. `CatchSearchRepository` reuses, unchanged: `CatchMapper.toDomain()` (`catches` feature), `FishingSpotEntityMapper.toDomain()`/`WaterBodyEntityMapper.toDomain()` (`fishing_spots` feature), and `LureCatalogMapper.entryFromRows()` (`lure_catalog` feature, a pure function with no filtering logic — reusing it duplicates nothing and changes nothing in `lure_catalog`).

---

## 12. State Management

### `CatchSearchPageState` (new, immutable)

```dart
// declared privately within catch_search_page.dart — page-specific, not
// reusable, per Key Design Decision 8; not a generic search-state framework.
@immutable
class _CatchSearchPageState {
  const _CatchSearchPageState({
    required this.rawQuery,
    required this.effectiveCriteria,
    required this.filterOptions,
    required this.isLoading,
    required this.errorMessage,
    required this.results,
  });

  const _CatchSearchPageState.initial()
      : rawQuery = '',
        effectiveCriteria = CatchSearchCriteria.empty,
        filterOptions = null,
        isLoading = true,
        errorMessage = null,
        results = null;

  final String rawQuery;
  final CatchSearchCriteria effectiveCriteria;
  final CatchFilterOptions? filterOptions;
  final bool isLoading;
  final String? errorMessage;
  final List<CatchSearchResult>? results;

  _CatchSearchPageState copyWith({...}) => ...; // plain, no sentinel needed —
      // every field here is either non-nullable or freely reassignable to
      // null via an explicit named parameter; unlike CatchSearchCriteria,
      // nothing here needs "leave unchanged" vs. "clear" disambiguation.
}
```

No `==`/`hashCode` on this class — nothing diffs the whole state object; `build()` reads individual fields directly each time, and it is held as a single mutable field on the `State`, replaced wholesale via `setState`.

### Controller/lifecycle

```dart
class _CatchSearchPageState extends State<CatchSearchPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  int _requestId = 0;
  _CatchSearchPageState _state = const _CatchSearchPageState.initial();

  static const _debounceDuration = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _executeSearch(CatchSearchCriteria.empty); // initial, unfiltered load
  }

  @override
  void dispose() {
    _debounceTimer?.cancel(); // must run before disposal — an in-flight
        // timer firing after dispose would call setState on an unmounted
        // State; the request-id guard inside _executeSearch is a second,
        // independent safety net for the async gap between dispatch and
        // completion, not a substitute for cancelling the timer itself.
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    final text = _searchController.text;
    setState(() => _state = _state.copyWith(rawQuery: text));
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _executeSearch(_state.effectiveCriteria.copyWith(query: text.trim()));
    });
  }

  void _onClearPressed() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchTextChanged); // avoid a
        // redundant, debounce-delayed re-query from .clear()'s own
        // listener notification — this action must refresh immediately.
    _searchController.clear();
    _searchController.addListener(_onSearchTextChanged);
    _searchFocusNode.unfocus();
    setState(() => _state = _state.copyWith(rawQuery: ''));
    _executeSearch(_state.effectiveCriteria.copyWith(query: '')); // immediate — FR-20
  }

  Future<void> _executeSearch(CatchSearchCriteria criteria) async {
    final requestId = ++_requestId;
    setState(() => _state = _state.copyWith(isLoading: true, errorMessage: null));
    try {
      final results = await widget.catchSearchRepository.search(criteria);
      if (!mounted || requestId != _requestId) return;
      setState(() => _state = _state.copyWith(
        effectiveCriteria: criteria,
        results: results,
        isLoading: false,
      ));
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Hakutulosten lataaminen epäonnistui.',
      ));
    }
  }
}
```

- **`TextEditingController`:** owned by the page's `State`, created in `initState`, disposed in `dispose`. Its `addListener`/`removeListener` around `.clear()` in `_onClearPressed` is the only place listening is temporarily suspended.
- **`FocusNode`:** owned the same way; `TextField(focusNode: _searchFocusNode)` gives tap-to-focus (FR-21) for free via Flutter's own default `TextField` behavior — no custom gesture handling is written; unfocusing on clear (`_searchFocusNode.unfocus()`) satisfies FR-20's "remove focus where appropriate."
- **Debounce `Timer`:** a single nullable field, cancelled before every new scheduling and in `dispose()`. 250–300 ms is satisfied by a named `_debounceDuration` constant (280 ms picked as a concrete midpoint — trivially adjustable, exactly the same "named constant, not fixed forever" framing TD-024 used for its own preselection thresholds).
- **Stale-response guard:** the `_requestId` increment-and-compare idiom, reused verbatim from `LureCatalogListPage` — necessary because a slow query for an earlier keystroke could otherwise resolve *after* a faster query for a later one and incorrectly overwrite its results.
- **State notifier/controller:** none — plain `State<CatchSearchPage>` + `setState`, per this project's universal convention; no Riverpod, no `ChangeNotifier`, no BLoC.
- **Disposal order:** cancel the timer first, then dispose the two Flutter objects — cancelling first ensures no pending callback can fire and touch a controller/focus node mid-teardown.

### Clear button requirements — explicit mapping

| Requirement (MFS-025 FR-20) | Where satisfied |
|---|---|
| Appears only when raw text is non-empty | `suffixIcon: _state.rawQuery.isNotEmpty ? IconButton(...) : null` in `_SearchAndFilterRow`. |
| Clears the raw and effective query | `_onClearPressed()` sets both `_state.rawQuery` and calls `_executeSearch` with `query: ''`. |
| Refreshes results immediately using remaining active filters | `_executeSearch` runs synchronously-dispatched (no debounce), and `criteria` still carries whatever `waterBodyId`/`species`/`lureVariantId`/`dateFrom`/`dateTo` were already active — only `query` changes. |
| Removes focus where appropriate | `_searchFocusNode.unfocus()`. |
| Does not clear active filters | `_executeSearch(_state.effectiveCriteria.copyWith(query: ''))` — every other field of `effectiveCriteria` is preserved untouched. |

---

## 13. Empty and Legacy Data Handling

| Scenario | Behavior |
|---|---|
| No catches recorded at all | The very first load (`initState`'s `_executeSearch(CatchSearchCriteria.empty)`) returns an empty list under empty criteria. Since an *unfiltered* query returning nothing is unambiguous proof there are zero catches in the whole database, this state is derived directly (`_state.results!.isEmpty && _state.effectiveCriteria.isEmpty`) — no separate `hasAnyCatches()` query is needed. |
| Search has no matches | `_state.results!.isEmpty && !_state.effectiveCriteria.isEmpty` (criteria carries a non-empty `query` and/or an active filter) — the distinct "Hakuehdoilla ei löytynyt saaliita" state, with a one-action "Tyhjennä haku ja suodattimet" control. |
| Filters have no matches (no text) | Same condition as above — `effectiveCriteria.isEmpty` is `false` whenever any filter is active, text or not, so this is not a separately-coded case. |
| Both search and filters have no matches | Same condition again — the state is derived from "is *anything* active," not enumerated per combination, keeping this simple per the task's explicit "avoid additional search states" instruction. |
| Lure absent | `CatchSearchResult.lure == null` → the row renders with no lure line (`lureLabel: null` passed to `CatchListItem`) — an ordinary, expected state, not an error. |
| Legacy/null relationship data | Per [Key Design Decision 11](#key-design-decisions) and MFS-025's own Conceptual Model, a live catch's `FishingSpot` and `WaterBody` can never be absent (non-nullable at the domain level, cascade-delete removes catches with their fishing spot) — the `innerJoin`s for both are therefore safe and will never silently drop a row that should be present. Only `lureVariantId` is genuinely nullable/potentially-dangling, handled by the `leftOuterJoin` + `readTableOrNull` pair above. |
| A dangling (non-retired-but-unresolvable) `lureVariantId` | `leftOuterJoin` still returns the `Catches` row with a null `LureVariants`/`LureModels` reading — `CatchSearchResult.lure` is `null`, rendered exactly like "no lure assigned," per MFS-019 FR-10's established precedent (no crash, no special-casing). |
| Related records "deleted where the schema allows it" | The only FK this design's main query treats as removable independent of the catch is `lureVariantId`'s target — already covered above. `FishingSpots`/`WaterBodies` cannot be removed while referenced (cascade/restrict respectively), so no other row in this query can ever point at a missing parent. |
| Query/filter failure (e.g. a database error) | `_executeSearch`'s `catch` branch sets `errorMessage`, never crashes; the previous `results`/`filterOptions` remain in `_state` untouched (not cleared), so the retry button reappears over whatever was last successfully shown rather than a jarring blank screen. |

The UI distinguishes "genuinely empty catch history" from "filtered/no-results" purely via `effectiveCriteria.isEmpty` (see table above) — no additional state field, enum, or flag is introduced to track this separately, per the task's explicit "do not introduce additional search states" instruction.

---

## 14. Accessibility

- The search `TextField` carries a `labelText`/semantic label distinguishing it from a generic field, consistent with existing form accessibility.
- The clear `IconButton` carries `tooltip: 'Tyhjennä haku'`, exposed to assistive technology the same way every other icon-only action in this app already is (e.g. the existing AppBar buttons' own `tooltip` usage).
- The filter `IconButton`'s `Badge`-driven active-state is additionally conveyed via a semantic label change (e.g. `Semantics(label: hasActiveFilters ? 'Suodattimet, aktiivisia suodattimia' : 'Suodattimet')`), not color/badge alone.
- Each `CatchListItem` row's existing `Semantics` composition is extended to include the new water body/fishing spot/lure lines when present, mirroring `RecordCatchCard`'s existing pattern of folding its own location line into one combined semantic label.
- Tap targets and text scaling follow this application's existing Material 3 conventions throughout.

---

## 15. Testing Strategy

Follows this project's established layered approach: domain, repository, widget, physical.

### Domain tests (new)

`catch_search_criteria_test.dart`: `isEmpty`/`hasActiveFilters` correctness across every field combination; `copyWith` correctly distinguishes "unchanged" from "explicitly cleared" for every nullable field (the sentinel behavior); `clearFilters()` preserves `query` and clears every filter field; `==`/`hashCode` behave correctly (two criteria with identical fields are equal; differing in any one field makes them unequal).

### Repository tests (new — `catch_search_repository_test.dart`)

Using the established `AppDatabase(NativeDatabase.memory())` + real repositories pattern (no mocks):

- Unfiltered `search(CatchSearchCriteria.empty)` returns every catch, correctly enriched (fishing spot, water body, and lure when present).
- Full and partial species search (Finnish display name, e.g. `"hauki"` and `"hau"`), including a mid-word partial match.
- Localized species-name matching does not depend on the stored English enum value being searched directly (searching the enum's raw `.name`, e.g. `"pike"`, does **not** match, confirming the match is genuinely against the Finnish name, not an accidental substring hit).
- Water-body-name search (full and partial), including a name containing `ä`/`ö` matched with the exact same case as stored.
- Fishing-spot-name search (full and partial).
- Lure-brand search and lure-model search (full and partial), including a catch whose lure has since been **retired** still being found by name (the specific regression this design's Key Design Decision 5 exists to prevent).
- Case-insensitive matching for every one of the five fields.
- Leading/trailing whitespace in the query is ignored.
- Empty query returns the full list (subject to active filters).
- Each filter individually: water body, species, lure, date range (inclusive at both boundaries — a catch caught exactly on `dateFrom`/`dateTo` is included; one day outside either boundary is excluded).
- Filters combined with AND semantics (two filters active together narrow correctly; a combination matching nothing returns an empty list, not an error).
- Text search combined with one or more active filters.
- A catch with a `null` `lureVariantId` renders with `lure: null` and is unaffected by a lure-name search.
- A catch whose `lureVariantId` references a **non-existent** row (seeded directly at the SQL layer with foreign-key enforcement temporarily disabled, mirroring the existing dangling-reference testing technique already established for Lure-Based Catch Statistics, TD-019) still returns correctly with `lure: null`, no crash.
- Live updates: creating, editing (e.g. changing species so it now/no-longer matches), or deleting a catch via `CatchRepository` is reflected by a subsequent `search()` call with the same criteria (this repository has no caching of its own to invalidate).
- Deterministic ordering: two catches sharing the same `caughtAt` are ordered by `createdAt` then `id`, matching `CatchRepository.getByFishingSpotId`'s existing tie-break exactly.
- `getFilterOptions()`: returns only water bodies/species/lures with at least one catch (a water body with a fishing spot but zero catches is excluded; a fully retired-but-still-referenced lure is included); alphabetical ordering for water bodies and lures (by manufacturer then model), Finnish-alphabetical for species (by display name).

### Widget tests (new — `catch_search_page_test.dart`, `catch_filter_bottom_sheet_test.dart`)

- The search field is visible immediately on page open, with no prior interaction required.
- Tapping the search field gives it focus immediately (`tester.tap` + checking `_searchFocusNode.hasFocus`/the field shows a cursor) — FR-21.
- The clear button is absent when the field is empty and appears after `tester.enterText(...)`.
- Pressing the clear button clears the text, restores the unfiltered-by-text (but still filter-respecting) list, and removes focus — verified with an active filter also set, to confirm the filter survives (FR-20's "does not clear active filters").
- The filter icon shows its active-indicator (`Badge`) only when a filter is active, and not otherwise.
- Opening the filter sheet, selecting a value per category, and applying it narrows the results; selecting "Tyhjennä suodattimet" restores the full (or text-filtered-only) list.
- The empty-database state renders distinctly from the no-match state (two separate test cases, one with a genuinely empty seeded database, one with seeded catches that just don't match the entered query).
- Clearing search and filters together (via the no-match state's own action) restores the full list.
- Each result's displayed metadata (species, date, weight/length, water body, fishing spot, lure) matches the seeded catch exactly, including a catch with no lure and one with no weight/length.
- Tapping a result opens `CatchDetailsPage` for the correct catch (verified via `find.byType(CatchDetailsPage)` after the push, and via the fishing spot passed to it).
- Query and filters survive a round trip through `CatchDetailsPage`: apply a search/filter, tap a result, return (via the AppBar back button), and confirm the search field's text and the filter indicator are unchanged, and the list still reflects the same criteria (re-queried, not stale).
- Debounce behavior: `tester.enterText(...)` followed by `tester.pump(const Duration(milliseconds: 100))` (before the debounce elapses) confirms no query has yet run (e.g. a fake repository's call count is still at its pre-typing value); `tester.pump(const Duration(milliseconds: 300))` (past the debounce) confirms exactly one query then ran — using `tester.pump(duration)`, which `flutter_test` already fast-forwards pending `Timer`s against, the standard Flutter idiom for testing debounced input (this codebase's first use of it — no prior `Timer`/`fakeAsync` test existed before this milestone, per the Current State investigation).
- Narrow Android screen layout (a `MediaQuery`-wrapped test at a small width, e.g. 360 logical pixels) confirms the search row and result rows do not overflow.

Fake repositories for these tests follow the established "subclass the real repository, override one method" idiom (e.g. `_StaticCatchSearchRepository extends CatchSearchRepository` overriding `search()`/`getFilterOptions()` to return fixed data, or a `_PendingCatchSearchRepository` with a `Completer` to test the loading state) — not a separate mock framework.

### `CatchListItem` extension tests (extended — `catch_list_item_test.dart`)

Every existing test continues to pass unmodified (no parameter is required); new tests cover: the water body/fishing spot/lure lines render only when their respective parameter is non-null, and every existing call site (a regression sweep across `catch_details_page_test.dart`/`fishing_spot_details_bottom_sheet_test.dart`/statistics widget tests that already construct `CatchListItem`) continues to render identically to before this milestone.

### Physical Android testing checklist

- The on-screen keyboard opens automatically when the search field is tapped, and the field visibly has focus/cursor with no extra tap.
- Typing produces a visible debounce delay (not an immediate, per-keystroke query) but still feels responsive.
- The clear button appears/disappears correctly as text is typed/cleared, and tapping it dismisses the keyboard.
- The filter bottom sheet opens, each category is selectable, "Käytä" narrows the list, and the filter icon's active indicator appears/disappears correctly.
- Scrolling a long result list is smooth (no jank) at a realistic personal-catch-history size.
- Tapping a result opens Catch Details correctly; returning (back button and Android system back gesture) preserves the search text, filters, and scroll position reasonably.
- Creating, editing, and deleting a catch (via the existing Add/Edit/Delete flows) is reflected on returning to this page.
- Full offline/airplane-mode operation throughout.

---

## 16. Performance Considerations

- **Debounce:** 250–300 ms (280 ms concrete default), preventing a query per keystroke while still feeling live.
- **Query frequency:** at most one `search()` call per debounce-settled typing burst, plus one immediate call per filter change, clear-button press, and initial load — never per-keystroke, never per-row.
- **No N+1:** the main query is one joined `SELECT`; the per-row lure/fishing-spot/water-body data all come from that same row via `readTable`/`readTableOrNull` — zero additional queries per result. The only per-row query in the whole feature is `CatchListItem`'s own existing, unchanged, already-established per-row photo-thumbnail lookup (unrelated to this milestone, identical to every other catch list in this app).
- **No Dart-side catch-history filtering:** every catch-level predicate is a Drift `WHERE` clause; the only Dart-side data inspection touches the fixed 19-value species enum, the small `WaterBodies`/`FishingSpots` tables (bounded at this app's own established "tens to low hundreds" scale), or reuses `lure_catalog`'s own indexed `searchText` SQL match — never the `Catches` table itself.
- **Pagination:** intentionally deferred (MFS-025 Out of Scope). `ListView.builder` still lazily builds row widgets regardless of total result count, giving basic scroll-performance headroom without a real pagination mechanism.
- **Indexes:** none added. `Catches` has zero indexes today; this design does not add one, per [Key Design Decision 3](#key-design-decisions) — deferred, not forgotten, with the same reasoning TD-017/TD-024 already used for their own analogous deferrals. **Concrete revisit trigger:** if a future milestone's real-usage/physical-testing feedback shows this page's query latency is noticeable at real catch-history volumes, add `@TableIndex` declarations on `Catches.species`, `Catches.caughtAt`, and `Catches.fishingSpotId` (this would require a schema version bump to 9, purely additive, no data migration needed beyond `migrator.createIndex(...)` calls — the same low-risk shape as the three index-adding steps already in this schema's own migration history).
- **No caching:** every query runs at most once per relevant user action; `_state.filterOptions` is the one deliberate exception (loaded once per page lifetime, not per sheet-open — see [§10](#10-filter-data-sources)).

---

## 17. Files Affected — File Plan

### New files

```text
lib/features/catches/domain/catch_search_criteria.dart
lib/features/catches/domain/catch_search_result.dart
lib/features/catches/domain/catch_filter_options.dart
lib/features/catches/data/catch_search_repository.dart
lib/features/catches/presentation/widgets/catch_search_page.dart
lib/features/catches/presentation/widgets/catch_filter_bottom_sheet.dart

test/features/catches/domain/catch_search_criteria_test.dart
test/features/catches/data/catch_search_repository_test.dart
test/features/catches/presentation/widgets/catch_search_page_test.dart
test/features/catches/presentation/widgets/catch_filter_bottom_sheet_test.dart
```

### Modified production files

```text
lib/features/catches/presentation/widgets/catch_list_item.dart   (+ optional waterBodyName/fishingSpotName/lureLabel params)
lib/features/map/presentation/map_screen.dart                    (+ CatchSearchRepository field, + AppBar button, + _openCatchSearch())
```

### Modified tests

```text
test/features/catches/presentation/widgets/catch_list_item_test.dart   (new coverage for the three new optional params; existing tests unmodified/still passing)
test/features/map/presentation/map_screen_test.dart                     (if this file exists and asserts the exact AppBar action count/order — confirm at implementation time; add coverage for the new button's presence and that it pushes CatchSearchPage)
```

### Generated files

None. No schema/table change means no `dart run build_runner build` regeneration is required for `app_database.g.dart`.

### Not modified

Every file under `fishing_spots`, `water_bodies`-owning code, `lure_catalog`, `personal_tackle_box`, `catch_photos`, and every existing file in `statistics` (including the undocumented water-body statistics view) — none is touched by this design.

---

## 18. Implementation Order

1. Add `CatchSearchCriteria`, `CatchSearchResult`, `CatchFilterOptions` (domain).
2. Add `catch_search_criteria_test.dart`.
3. Add `CatchSearchRepository` (data), including its private candidate-resolution helpers.
4. Add `catch_search_repository_test.dart`.
5. Extend `CatchListItem` with the three new optional parameters; extend `catch_list_item_test.dart`.
6. Build `CatchFilterBottomSheet`.
7. Build `CatchSearchPage` (search row, debounce/focus/clear wiring, body-state rendering, filter-sheet integration, `CatchDetailsPage` navigation + reload).
8. Add `catch_search_page_test.dart`/`catch_filter_bottom_sheet_test.dart`.
9. Wire the new `MapScreen` AppBar button and `_catchSearchRepository` field; extend/confirm `map_screen_test.dart` coverage.
10. `dart format .`, `flutter analyze`, `flutter test`.
11. Architecture review.
12. Physical Android testing (checklist in [§15](#15-testing-strategy)).

---

## 19. Risks and Mitigations

| Risk | Category | Mitigation |
|---|---|---|
| No index exists on `Catches` for any of the columns this milestone filters/searches by; a large future catch history could make `search()` noticeably slow. | Performance | Deliberately deferred per [Key Design Decision 3](#key-design-decisions), consistent with two prior TDs' own identical deferrals; a concrete, cheap, purely-additive revisit path (`@TableIndex` + a schema bump to 9) is named in [§16](#16-performance-considerations) rather than left unaddressed. |
| The `TextEditingController` listener add/remove dance around `.clear()` in `_onClearPressed` is a slightly unusual pattern that could be implemented incorrectly (e.g. forgetting to re-add the listener, silently breaking all further typing). | Correctness | Called out explicitly with an inline rationale comment in [§12](#12-state-management); covered directly by a dedicated widget test asserting that typing *after* pressing clear still triggers a debounced search. |
| Reimplementing a small, private LIKE-escaping helper inside `CatchSearchRepository` (rather than sharing `lure_catalog`'s) is a deliberate, acknowledged duplication that could drift out of sync if `lure_catalog`'s own escaping logic is ever changed. | Duplication | Explicitly documented as a narrow, ~3-line, low-risk exception in [Key Design Decision 5](#key-design-decisions) — the alternative (modifying `lure_catalog` to export a shared helper) would touch a feature MFS-025 explicitly forbids changing. Revisit only if `lure_catalog`'s own escaping logic changes and drift becomes a real, observed problem. |
| This is the first `Timer`/debounce-based UI in this codebase's test suite; the `tester.pump(duration)` debounce-testing idiom, while standard Flutter practice, has no prior local precedent to copy exactly. | Testing | The exact expected pump/assert sequence is spelled out in [§15](#15-testing-strategy) rather than left to be improvised during implementation. |
| Extending `CatchListItem` with three new optional parameters touches a widget reused across many existing features (MFS-011, MFS-014, MFS-019–022, and the undocumented water-body statistics view); an implementation mistake could regress one of them. | Regression | Every existing call site's test suite runs unmodified in addition to new coverage; the new parameters default to `null` and are purely additive rendering, with no change to existing layout when absent — reducing (not eliminating) regression risk to a rendering-conditional bug, not a structural one. |
| `CatchSearchRepository._matchingWaterBodyIds`/`_matchingFishingSpotIds` assume these tables stay "small" at this app's personal-use scale; if a future milestone changes that assumption (e.g. bulk import), this Dart-side scan could become a real cost. | Scalability | Explicitly named as an assumption (Key Design Decision 5), not silently relied upon — the same assumption `WaterBodyRepository`/`FishingSpotRepository` already make today for their own existing `loadAll()`/`getNearby()` methods, so this design introduces no new scaling risk beyond what already exists. |

---

## 20. Dependencies

No new external package dependencies. This document reuses, unchanged:

- Flutter, Dart (`dart:async` for `Timer`, already used elsewhere in this codebase)
- Drift (typed joins/expressions only, per ADR-0005 — no migration, no new table)
- The existing Repository pattern, feature-first structure, and manual constructor injection (ADR-0001, ADR-0003, ADR-0006)
- The existing `Catch`/`CatchRepository`/`CatchMapper` (MFS-009), `FishingSpot`/`WaterBody` domain models and their mappers (MFS-004/MFS-024), and `LureCatalogEntry`/`LureCatalogMapper` (MFS-015) — all read/reused, none modified
- The existing `CatchDetailsPage`/`CatchDetailsPage.open()` (MFS-014), reused as this milestone's sole navigation target
- The existing `MapScreen` AppBar entry-point convention (MFS-019 and its successors)
- The existing `LureCatalogRepository.browse()`'s searchText/LIKE-escaping technique, reused as a design template (not a dependency — see Key Design Decision 5)

---

## 21. Validation

```bash
dart format .
flutter analyze
flutter test
```

All must pass. Confirm the schema version is still `8` before implementing, in case it has moved since this document was written — no migration is expected either way, but this is the same hedge every prior TD in this project requires.

---

## 22. Definition of Done

- The implementation satisfies every requirement and acceptance criterion in MFS-025, including its two post-approval refinements (FR-20 clear button, FR-21 tap-to-focus).
- The implementation follows this document, or documents and justifies each deviation.
- A new global catch-browsing page exists, reachable from a new `MapScreen` AppBar entry, with no other navigation-shell change.
- Text search across species (Finnish name), water body, fishing spot, lure brand, and lure model works, case-insensitively, with partial matching, whitespace-trimmed, live-updating with a 250–300 ms debounce, and no explicit submit action.
- The filter bottom sheet supports water body, species, lure, and date-range filtering, single-select per category, combined with text search and with each other via AND semantics.
- The search field's clear button appears only with non-empty text, clears the query, immediately refreshes results using any remaining active filters, and removes focus where appropriate.
- Tapping the search field focuses it immediately with no extra interaction.
- Active filters are visibly indicated and independently clearable, together or per-category.
- Search text and filters survive a round trip through `CatchDetailsPage` unchanged, and results reflect any create/edit/delete made during that visit.
- Each result shows species, date, weight/length when available, water body, fishing spot, and lure when available, with no per-row repository call beyond the existing photo-thumbnail lookup.
- No new database table, column, index, or schema version.
- No change to `Catch`/`CatchRepository`'s existing CRUD behavior, `FishingSpot`/`WaterBody`/`LureCatalogEntry`, `catch_photos`, `lure_catalog`, `personal_tackle_box`, or any existing `statistics` page.
- No repository interface, service layer, use-case layer, or DAO layer is introduced anywhere.
- `dart format .`, `flutter analyze`, and `flutter test` all pass.
- Architecture review is completed.
- Physical Android testing (checklist in [§15](#15-testing-strategy)) is completed.
- Documentation updates (below) are performed in a separate, subsequent step — not part of this document's own completion.

---

## Implementation Notes

Implementation followed this document's domain, database, repository, dependency-injection, and UI design as specified, with no architectural deviation. `dart format .`, `flutter analyze` (8 pre-existing/accepted info-level lints, none introduced), and `flutter test` all pass (818/818). The following discoveries were made during implementation:

1. **Two pre-existing, already-documented test-environment conventions had to be applied to this milestone's own new tests.** `FishingSpotRepository`/`CatchRepository`'s `DateTime.now().microsecondsSinceEpoch`-based id generation (the same latent flakiness already documented in TD-024's own Implementation Notes) required the same short-real-delay-before-rapid-creation mitigation already used throughout this project's repository tests; inside `testWidgets`-based tests specifically, that delay additionally had to run via `tester.runAsync()` (a bare `Future.delayed` never resolves under the fake-async `testWidgets` binding), matching `general_catch_statistics_tab_test.dart`'s established convention. Neither is a new pattern introduced by this milestone, and neither required any production-code change.
2. **`MapScreen` widget-test coverage was added** (`test/features/map/presentation/widgets/map_screen_test.dart` — no test file for `MapScreen` existed before this milestone) covering the new Catch Search AppBar entry point (icon, tooltip, navigation, `CatchSearchRepository` wiring) and regression coverage confirming the pre-existing Lure Tools/Statistics entry points are unaffected. `MapScreen` embeds a `MapLibreMap` platform view that perpetually schedules frames in this headless test environment, so these tests use bounded `tester.pump()`/`pump(duration)` calls rather than `tester.pumpAndSettle()`, which never settles.
3. **Architecture review and physical Android testing have both been completed successfully** for this milestone, consistent with every prior milestone in this project.

---

## 23. Documentation Cleanup

Carried out as part of finalizing this milestone's documentation:

- **`docs/project-status.md`:** updated — MFS-025 marked complete and moved into the Implemented Features/Validation/Project Metrics sections, following this project's established per-milestone update convention. Database schema version remains `8`.

Deliberately left for a separate step, not performed here:

1. **`docs/roadmap.md` §3.1:** still shows "Catch Search & Filtering"'s identifier as "Not assigned" — updating it to `MFS-025`/`TD-025` and moving it into the Current Milestone section was out of scope for this documentation pass.
2. **`docs/specifications/MFS-023-catch-notes.md`:** its four existing "MFS-024 — Catch Search & Filtering" references (Related section; two Out of Scope lines; Future Extensions) still need correcting to "MFS-025" — also out of scope for this pass.
3. **Undocumented `WaterBody` statistics work:** the already-implemented `WaterBodyStatisticsPage`/`WaterBodyStatisticsRepository` (git history: "feat: group catch statistics by water body") has no MFS/TD identifier and is not mentioned in `docs/project-status.md` or `docs/roadmap.md`. This remains undecided — no retrospective MFS/TD number is assigned by this document or by this documentation pass; it is a separate documentation/process decision, on its own merits, not a byproduct of this milestone's paperwork.
