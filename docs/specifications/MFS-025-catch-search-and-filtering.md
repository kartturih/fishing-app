# MFS-025 — Catch Search & Filtering

## Status

Implemented — architecture-reviewed and approved, all automated tests passing (818/818), `flutter analyze` clean (8 pre-existing/accepted info-level lints, none introduced by this milestone), and physical Android testing completed successfully. See TD-025 for the technical design and its Implementation Notes for full detail, and `docs/project-status.md` for the validation record. This specification defines the MVP scope for the "Catch Search & Filtering" idea previously named, unnumbered, in `docs/roadmap.md` §3.1 (originally drafted as an earlier MFS-024 candidate, abandoned before being scoped, then reassigned — the identifier `MFS-024` itself was later given to Water Bodies and Fishing Spot Hierarchy). This document assigns it the next available identifier, `MFS-025`. The stale "MFS-024" references identified when this specification was drafted (`docs/roadmap.md` §3.1 and four references in `docs/specifications/MFS-023-catch-notes.md`) have not yet been corrected — see TD-025 §23.

Approved with two small UX refinements requested before Technical Design: an explicit search-field clear ("X") button (FR-20) and an explicit tap-to-focus requirement (FR-21). Both were implemented as MVP requirements, not deferred enhancements.

## Related

- Depends on: MFS-009 — Catch Foundation (the `Catch` domain model, `Catches` table, and `CatchRepository` this milestone searches and filters)
- Depends on: MFS-011 — View Catches for Fishing Spot (the existing, per-fishing-spot catch list this milestone's global search complements, and whose "filtering" was explicitly deferred in its own Out of Scope)
- Depends on: MFS-014 — Catch Details View (the existing, unmodified navigation target for every search result)
- Depends on: MFS-017 — Assign Lure to Catch (the `Catch.lureVariantId` reference this milestone searches and filters by)
- Depends on: MFS-023 — Catch Notes (explicitly named search/filtering as future scope belonging to this milestone; notes content is not part of this milestone's text search — see [Out of Scope](#out-of-scope-1))
- Depends on: MFS-024 / TD-024 / ADR-0007 — Water Bodies and Fishing Spot Hierarchy (the `WaterBody` domain concept and the `FishingSpot → WaterBody` relationship this milestone reads and filters by)
- Related, undocumented prior art: a "group catch statistics by water body" change already exists in the codebase (`lib/features/statistics/presentation/widgets/water_body_statistics_page.dart`, `lib/features/statistics/data/water_body_statistics_repository.dart`) with no corresponding MFS/TD number and no mention in `docs/project-status.md` or `docs/roadmap.md`. It is an aggregated, water-body-scoped statistics view, not a global catch-browsing or search surface, so it does not satisfy this milestone's product goal — see the Report accompanying this document's creation.
- Precedes: nothing currently scoped; natural future extensions are listed under [Future Extensions](#future-extensions)

---

## Purpose

Let an angler quickly find a specific catch they remember some detail of — a species, a lake, an exact spot, or a lure — by typing that detail into an always-visible search field, with an accompanying compact filter control for narrowing by water body, species, lure, or date range. This milestone also introduces the global, all-catches browsing surface this search lives on, since no such surface exists in the application today (see [Conceptual Model](#no-global-catch-browsing-surface-exists-today)).

---

## User Value

The project charter's Problem Statement is answered today only at narrow, pre-scoped grains: catches at one fishing spot (MFS-011), catches of one species (MFS-021), catches at one fishing spot's statistics (MFS-022), catches by one lure (MFS-019), and now catches at one water body (the undocumented water-body statistics view — see [Related](#related)). None of these let an angler start from a half-remembered detail — "I caught a decent pike on that spinner somewhere near Merrasjärvi last spring" — and find the actual catch without first guessing which spot, species, or lure list to open. This milestone answers that directly: one search field, typed into from wherever the angler already is looking at their catch history, narrows live to matching results.

---

## Scope

### In Scope

- A new, minimal global catch-browsing surface listing every recorded catch (see [Conceptual Model](#no-global-catch-browsing-surface-exists-today)), reachable from the existing Map Screen entry-point convention.
- An always-visible text search field on that surface, searching fish species, water body name, fishing spot name, lure brand (manufacturer), and lure model/name in one query.
- Case-insensitive, partial-match, whitespace-trimmed, live-updating (debounced) search with no explicit submit action.
- A compact filter control (bottom sheet) supporting: water body, fish species, lure, and date range.
- Combined text search and filters, applied together.
- Clear visual indication of active filters, and a way to clear both search and filters at once.
- Each result showing enough information to identify the catch at a glance: species, date, weight/length when available, water body, fishing spot, and lure when available.
- Tapping a result opens the existing, unmodified `CatchDetailsPage` (MFS-014).
- Defined empty and error states for every relevant combination (no catches at all, no search match, no filter match, load failure).
- A data-layer design that performs search and filtering as Drift queries, not by loading the full catch history into Dart.
- Fully offline operation.

### Out of Scope

See [Out of Scope](#out-of-scope-1) for the complete list. Notably: natural-language or AI search, weight/length range filters, "only catches with photos," personal-record filtering, weather filtering, saved searches, cloud search, search suggestions/autocomplete, searching note content, multi-select per filter category, and any redesign of the application's primary navigation shell.

---

## User Stories

**As an angler**
I want to type a species, lake, spot, or lure name into a search field and see matching catches immediately
So that I don't have to remember which fishing spot, species list, or lure I recorded a catch under.

**As an angler**
I want to narrow my catch history by water body, species, lure, or a date range
So that I can answer more specific questions ("what did I catch at Merrasjärvi in June?") without scrolling through everything.

**As an angler**
I want to combine a text search with active filters
So that I can, for example, search "hauki" while a date range filter is active, and see only pike caught in that period.

**As an angler**
I want it to be obvious when a filter is active, and easy to clear it
So that I don't get confused about why my catch history looks smaller than I expect.

**As an angler**
I want tapping a search result to open the same Catch Details view I already know
So that finding a catch this new way doesn't behave differently from finding it any other way.

---

## Conceptual Model

This section resolves the product-level questions this milestone must answer before Technical Design work begins, following the same discipline established by MFS-021/MFS-022/MFS-024's own Conceptual Model sections. Exact query, repository, constant, and widget design remain a Technical Design concern.

### No global catch-browsing surface exists today

The task that produced this document explicitly warned not to assume a global "My Catches" page already exists, and directed that the correct location be identified from the actual implementation rather than assumed. Direct inspection of the current codebase confirms: every place a `Catch` list is rendered today is scoped —

- `FishingSpotDetailsBottomSheet` ([fishing_spot_details_bottom_sheet.dart](../../lib/features/fishing_spots/presentation/widgets/fishing_spot_details_bottom_sheet.dart)) shows catches for exactly one fishing spot, inside a modal bottom sheet (MFS-011).
- `SpeciesStatisticsPage`, `FishingSpotStatisticsPage`, and the undocumented `WaterBodyStatisticsPage` each show catches scoped to one species, one fishing spot, or one water body respectively, as part of an aggregated statistics view, not a browsing surface.
- `GeneralCatchStatisticsTab` shows aggregate summaries and a Top 3 Largest Catches list — never a plain, complete, unscoped catch list.
- `CatchRepository` ([catch_repository.dart](../../lib/features/catches/data/catch_repository.dart)) itself has no `loadAll()`/`watchAll()`-style unscoped query; its only list-returning method is `getByFishingSpotId()`.

**No screen, route, or repository method in the current implementation lets an angler see or search their entire catch history at once.** This milestone therefore must define that minimal browsing surface itself, per the task's explicit instruction, rather than attach search to something that does not yet exist.

### The correct entry point follows the existing, established navigation convention — not a new one

`MapScreen` is, by its own doc comments, the application's single de facto navigation hub today: it has "no dedicated navigation shell (no drawer, bottom navigation, or home menu)," and instead exposes a small, explicitly named-as-temporary set of AppBar icon buttons (`openLureToolsButton`, `openStatisticsButton`) that each push a full-screen page via `MaterialPageRoute`. `lib/features/home/presentation/home_page.dart` is a dead stub, wired into no route, and is not a candidate entry point.

This milestone adds one more icon button to that same AppBar, following the exact existing pattern, pushing a new page (see [Navigation](#navigation)). This is **not** a redesign of the application's primary navigation architecture — it is the same pattern applied a third time, with no new navigation shell, no drawer, and no bottom navigation introduced. Per the task's own guidance, an ADR is not warranted for this: nothing about how the application is structured for navigation changes, only one more entry point of the same already-established kind is added. This decision is documented here, as directed, rather than assumed silently.

### Fish species requires a small, bounded, in-memory match — never a scan of catch history

`FishSpecies` ([fish_species.dart](../../lib/features/catches/domain/fish_species.dart)) is a fixed Dart enum of 19 values; its Finnish display name ([fish_species_extensions.dart](../../lib/features/catches/domain/fish_species_extensions.dart)) exists only as a Dart-side `switch`, never stored in the database — `Catches.species` stores the enum's English `name` (e.g. `"pike"`), not its Finnish label (e.g. `"Hauki"`). A search for "hauki" therefore cannot be satisfied by a direct SQL `LIKE` against the stored column.

This is resolved the same way this application already resolves anything a SQL column cannot directly answer: by matching the query text against the **fixed, 19-value enum** in Dart — a bounded, constant-size operation, never proportional to the angler's catch history — to determine which `FishSpecies` values' Finnish names match, and then passing those matched values into a Drift `WHERE species IN (...)` clause. This is the only place in this milestone where anything resembling "matching in Dart" occurs, and it is explicitly not the same thing as loading and filtering catches in Dart, which the Architecture Constraints below prohibit.

### Every relationship a live catch depends on is already guaranteed non-null — "deleted" edge cases are narrower than they first sound

The task lists "deleted WaterBody, FishingSpot, or lure relationships" among the empty/error states to define. Inspecting the current, already-implemented invariants:

- `Catch.fishingSpotId` is a required foreign key with cascading delete (MFS-009): a fishing spot cannot be deleted while leaving orphaned catches behind — deleting it deletes its catches too. A live catch's `FishingSpot` can therefore never be missing.
- `FishingSpot.waterBodyId` is non-nullable at the domain level, and `FishingSpotEntityMapper.toDomain()` fails loudly (`StateError`) rather than silently if this is ever violated (TD-024 Key Design Decision 1). A live catch's water body (resolved through its fishing spot) can therefore also never be missing.
- `Catch.lureVariantId` **is** genuinely optional (nullable), and even when set, may reference a retired `LureVariant` — which remains fully resolvable, by existing design (MFS-017, MFS-019 FR-10): "the assigned lure survives its `TackleBoxEntry` being later removed... and remains resolvable even if the underlying catalog variant is later retired."

The only real "nullable/legacy data" case this milestone must handle gracefully is therefore an **absent lure** (no lure assigned) — already an ordinary, expected state elsewhere in the application — and, defensively, the same "unresolvable lure reference handled without crashing" discipline MFS-019 FR-10 already established, in case a genuinely dangling reference is ever encountered. Water body and fishing spot are structurally guaranteed present for any catch this milestone can ever display, and this milestone must not weaken that guarantee (e.g. by introducing an `OUTER JOIN` that silently tolerates a missing fishing spot where the existing invariant says one cannot be missing).

### Filters hold one active value per category in this MVP

To keep the first version's UI and query shape simple (per this project's "avoid unnecessary abstractions" development rule), each filter category — water body, species, lure, date range — holds at most one active selection at a time in this MVP. Selecting a new value within a category replaces the previous one; there is no "OR" selection within a single category in this first version. Multiple *categories* combine with AND semantics, per the product brief (e.g. water body = Merrasjärvi AND species = pike). Multi-select within a single category is listed as a future enhancement, not built here.

### Text search and filters combine, but only text search updates live

Filters are chosen deliberately, in a bottom sheet, and applied when the sheet is dismissed with a selection — they do not need to "update while typing" the way free text does, since there is no typing involved in choosing a water body, species, lure, or date range from a list/picker. Only the text field has a live-update/debounce requirement. Once filters are applied, they combine with whatever text query is currently active (or empty) using AND semantics: a result must match the current text query (if any) **and** every currently active filter category.

---

## Functional Requirements

### FR-1 — Global Catch-Browsing Surface

A new page must exist that can display every recorded catch, independent of fishing spot, water body, species, or lure — the minimum surface required for this milestone's search and filtering to have something to operate on (see [Conceptual Model](#no-global-catch-browsing-surface-exists-today)).

### FR-2 — Entry Point

The new page must be reachable from a new icon button on the existing `MapScreen` AppBar, following the same established pattern already used for the Lure Tools and Statistics entry points (see [Conceptual Model](#the-correct-entry-point-follows-the-existing-established-navigation-convention--not-a-new-one)). No new navigation shell, drawer, bottom navigation, or home screen is introduced.

### FR-3 — Always-Visible Text Search

The new page must show a text search field, visible at all times while browsing, without requiring any prior action to reveal it.

### FR-4 — Text Search Fields

A single text query must match against, in one combined search: fish species (by Finnish display name), water body name, fishing spot name, lure manufacturer, and lure model/name.

### FR-5 — Search Behavior

Text search must be: case-insensitive; capable of partial (substring) matches; insensitive to leading/trailing whitespace in the query; live-updating as the user types, with no separate submit or Enter action required; and debounced by approximately 250–300 ms before a new query is issued, to avoid querying on every keystroke.

### FR-6 — Empty Query Shows the Full List

An empty search query (after trimming) must show the full, unfiltered catch list — subject to whatever filters (FR-8) are currently active.

### FR-7 — Compact Filter Control

A compact filter icon/button must appear alongside the search field. Activating it opens a bottom sheet offering the filter categories in [FR-8](#fr-8--filter-categories).

### FR-8 — Filter Categories

The filter bottom sheet must offer: water body (from the angler's existing water bodies), fish species (from species present in the angler's catch history), lure (from lures the angler has actually assigned to a catch — mirroring the existing "only lures with recorded catches" precedent, MFS-019 FR-6), and a date range (start and end date, inclusive, applied to `caughtAt`).

### FR-9 — Filter Combination

Text search and active filters must apply together: a result must satisfy the current text query (if any) and every active filter category (AND semantics across categories, per [Conceptual Model](#filters-hold-one-active-value-per-category-in-this-mvp)).

### FR-10 — Active-Filter Indication

The filter control must visibly indicate when one or more filters are active, distinguishable from its no-filters-active appearance.

### FR-11 — Clearing Search and Filters

The angler must be able to clear the text query and every active filter, independently or together, restoring the full, unfiltered catch list.

### FR-12 — Filters Persist Across Catch Details

Navigating to `CatchDetailsPage` from a result and returning must preserve the currently active search text and filters exactly as they were — reopening the browsing surface must not reset either.

### FR-13 — Result Content

Each result must show: fish species, catch date, weight and/or length when available, water body, fishing spot, and lure when available — sufficient to identify the catch without opening it.

### FR-14 — Opens Existing Catch Details

Tapping a result must open the existing, unmodified `CatchDetailsPage` (MFS-014) for that catch — no new or parallel catch-detail view is introduced.

### FR-15 — Live Updates

The browsing surface must reflect catches created, edited, or deleted elsewhere in the application (Add Catch, Edit Catch, Delete Catch) the next time it is shown or its query re-runs — consistent with this application's existing "reload on return" convention (MFS-021/MFS-022), not a background sync mechanism.

### FR-16 — Data-Layer Search and Filtering

Search and filtering must be performed as Drift queries against the existing `catches`/`fishing_spots`/`water_bodies`/`lure_catalog` tables, not by loading the full catch history into Dart and filtering it in memory (see [Architecture Constraints](#architecture-constraints)). The only permitted Dart-side matching is the bounded, fixed-size `FishSpecies` enum match described in [Conceptual Model](#fish-species-requires-a-small-bounded-in-memory-match--never-a-scan-of-catch-history).

### FR-17 — Enriched Read Results

The data layer must return catch results already carrying whatever information the list (FR-13) and `CatchDetailsPage` (FR-14) need — at minimum the resolved `FishingSpot`, resolved `WaterBody`, and resolved lure information when present — so neither the list nor the details navigation needs a second, separate lookup per result.

### FR-18 — No Schema Change

This milestone requires no new database table, column, or schema version — every field it searches or filters by already exists in `catches`, `fishing_spots`, `water_bodies`, and `lure_catalog`.

### FR-19 — Offline Operation

Every capability in this milestone — the browsing surface, text search, and every filter — must work with no network connection.

### FR-20 — Search Field Clear Button

When the search field contains text, a clear ("X") button must appear inside the trailing end of the field, consistent with standard Material Design search field behavior. Pressing it must: clear the current search query, immediately restore the full catch list (subject to any active filters, per FR-9), and remove focus from the search field where that is the platform-appropriate behavior. This is an MVP requirement, not a deferred enhancement — it is the same "clear" action FR-11 already requires, made directly available from within the field itself rather than only from a separate no-results affordance.

### FR-21 — Search Field Focus Behavior

Tapping the search field must give it focus immediately, letting the user begin typing with no additional interaction (no intermediate confirmation, no separate "activate search" step). This must feel native to Android, using the platform's ordinary text-field focus behavior rather than a custom-built interaction.

---

## UI Expectations

- The search field's suggested placeholder text is **"Hae kalalajia, vesistöä tai viehettä…"** — final wording is a Technical Design/implementation concern, not fixed here.
- The compact filter icon sits alongside the search field (for example, as a trailing icon/button in the same row), not in a separate location requiring extra navigation to discover.
- A clear ("X") button appears inside the trailing end of the search field whenever it contains text, and is absent when it is empty — the same pattern used by standard Material Design search fields (for example, `TextField`'s built-in `suffixIcon` clear-affordance convention), not a custom control.
- Tapping the search field focuses it immediately, with no intermediate step, using ordinary platform text-input focus behavior (FR-21).
- The filter control opens a Material 3 bottom sheet, consistent with this application's existing bottom-sheet conventions (e.g. `WaterBodySelectionBottomSheet`).
- Search and filtering must feel minimal and unobtrusive — no separate "search mode," no full-screen search takeover, and no visual redesign of how a catch result looks beyond what FR-13 requires. The clear button and focus behavior are standard field affordances, not new interaction states — they must not add a distinct "editing" mode or otherwise complicate the search experience.
- All user-visible text is Finnish, consistent with the application's existing UI text convention.
- No search-suggestion dropdown, autocomplete list, or recent-searches affordance is shown.

---

## Navigation

This milestone introduces exactly one new entry point and one new page:

- A new icon button on the existing `MapScreen` AppBar, alongside the existing Lure Tools and Statistics buttons, following the same established "temporary entry point, pushes a full-screen page" pattern (see [Conceptual Model](#the-correct-entry-point-follows-the-existing-established-navigation-convention--not-a-new-one)).
- The new page itself (the global catch-browsing/search surface, FR-1), pushed via `MaterialPageRoute`, mirroring how Lure Tools and Statistics are already opened.
- From a result on that page, the existing `CatchDetailsPage` opens exactly as it already does from every other current entry point (MFS-011, MFS-021, MFS-022, and the undocumented water-body statistics view) — no new navigation target is introduced there.

No drawer, bottom navigation, home screen, or other navigation-shell change is introduced or required by this milestone.

---

## Data Ownership

- This milestone's natural owner is the existing **catches** feature (MFS-009), the feature that already owns `Catch`, `CatchRepository`, and `CatchMapper` — the entity this milestone searches. This mirrors the precedent already set twice: Catch Notes (MFS-023) extended `catches` itself, and Water Bodies (MFS-024) extended the feature that already owned the entity being extended (`fishing_spots`), rather than creating a new feature directory for a closely related concern. Final confirmation of this placement (versus, for example, a narrow addition to `catches`' own presentation layer only) is left to Technical Design/architecture review, consistent with how MFS-024 itself left an equivalent placement question open (see [Design Notes](#design-notes)).
- `FishingSpot`/`WaterBody` (owned by `fishing_spots`) and `LureCatalogEntry`/`LureVariant` (owned by `lure_catalog`) are read directly by whatever new query this milestone introduces, following the existing "a repository reads whichever tables it needs directly, rather than going through another feature's repository instance" discipline already established by `GeneralCatchStatisticsRepository` (TD-020) and `WaterBodyRepository` (TD-024 Key Design Decision 5) — not by calling into `FishingSpotRepository` or `LureCatalogRepository`'s own instance methods.
- No domain model, schema, or repository contract in `fishing_spots`, `lure_catalog`, `personal_tackle_box`, or `catch_photos` changes as a result of this milestone.
- `CatchDetailsPage` (MFS-014) is reused entirely unmodified as the navigation target for every result.
- `CatchListItem` currently renders only species, measurement, date, and a photo thumbnail — it does not receive or render a fishing spot, water body, or lure today. Satisfying FR-13's result-content requirement therefore requires either extending this widget additively (optional parameters, defaulting to today's exact behavior for every existing call site — the same non-breaking pattern already used for `AddToTackleBoxAction`'s `initialIsOwned`, TD-018) or introducing a narrowly-scoped result-row widget specific to this page. Which of these is preferable is a Technical Design decision, not resolved here; either way, this milestone must not duplicate `CatchListItem`'s existing photo-thumbnail-resolution or tap-to-details logic in a second, parallel implementation (per `docs/development-rules.md`'s "avoid duplicate widgets").

---

## Empty, Loading, and Error States

- **No catches recorded at all:** the browsing surface shows a clear "no catches yet" message — distinct from a no-results-from-search/filter message — since there is nothing to search regardless of query or filter state.
- **No results matching the current search text:** a clear message states that nothing matched the typed query, with an easy, one-action way to clear the search text.
- **No results matching active filters:** a clear message states that nothing matched the active filters, with an easy, one-action way to clear them.
- **No results matching a combination of search text and filters:** the same no-results treatment applies; the clear action(s) offered must let the angler clear search, filters, or both, so they are never stuck looking at an empty list with no visible way out.
- **Loading:** while the initial catch list or a re-queried search/filter result is loading, a clear loading indicator is shown, consistent with this application's existing loading-state convention.
- **Query/filter failure (e.g. a database error):** the application must not crash; a clear error message is shown, and the previously visible results (or the search/filter controls themselves) remain usable/retryable, consistent with this application's existing "don't discard user context on failure" convention.
- **An assigned lure that cannot be resolved:** the result renders without a lure line (or with a clearly non-crashing fallback), the same "unresolvable lure reference handled without crashing" discipline already established by MFS-019 FR-10 — this must not be treated as an error state.

---

## Edge Cases

- A catch with no weight, no length, or neither still appears in results and in search matches, using the existing missing-measurement handling already established (MFS-011).
- A catch with no assigned lure is included in every text search and every filter combination that does not specifically filter by lure; it simply shows no lure line in its result (per [Conceptual Model](#every-relationship-a-live-catch-depends-on-is-already-guaranteed-non-null--deleted-edge-cases-are-narrower-than-they-first-sound)).
- A search query matching a fish species' Finnish name (e.g. "hauki") returns every catch of that species, resolved via the bounded enum match described in the Conceptual Model — not a literal substring match against the stored English enum value.
- A search query that happens to be a substring of a water body name and a fishing spot name and a lure name simultaneously still returns the correct, deduplicated set of matching catches (no catch is listed twice because it matched on more than one field).
- Two water bodies (or two fishing spots, or two lures) sharing the same display name are both valid, independent filter selections, exactly mirroring this application's existing accepted duplicate-name behavior (MFS-022, MFS-024) — selecting one filters strictly by its identifier, never by name text.
- Applying a filter, then opening and returning from `CatchDetailsPage`, leaves the filter and search state exactly as it was (FR-12) — including after an edit or deletion that changes whether the currently open catch would still match.
- Editing a catch so it no longer matches the active search/filter (e.g. changing its species away from an active species filter) removes it from the visible results the next time the list reloads, consistent with FR-15.
- Deleting a catch from `CatchDetailsPage` and returning removes it from the results the next time the list reloads; it must not still render as an outdated row.
- A date range filter with only a start date, only an end date, or neither behaves as an open-ended range on whichever side is unset (a Technical Design/implementation detail of exact UI, not fixed further here).
- Pressing the search field's clear button while active filters remain set does not clear those filters — only the text query is cleared (FR-20); the resulting list reflects the active filters against the full, unfiltered catch list.
- Pressing the search field's clear button on an already-empty field has no effect (there is nothing to clear), and must not error.

---

## Accessibility Expectations

- The search field exposes an accessible label distinguishing it from a generic text field, consistent with this application's existing form accessibility.
- The clear button exposes an accessible label (e.g. "Tyhjennä haku") distinguishing it from the search field itself and from the filter button.
- The filter button exposes an accessible label, and its active/inactive indication (FR-10) is conveyed to assistive technology, not only visually.
- Each result row's accessible label/semantics convey the same information sighted users see (species, date, measurements when present, water body, fishing spot, lure when present), consistent with `CatchListItem`'s existing accessible-row precedent elsewhere in the application.
- Tap targets and text throughout this milestone follow the application's existing Material 3 sizing and text-scaling conventions.

---

## Feature Ownership and Placement

Following the existing feature-first structure, Repository pattern, and database ownership rules (ADR-0001, ADR-0003, ADR-0004, ADR-0006):

- No repository interface, DAO, service layer, or use-case layer is introduced, consistent with every prior milestone in this project.
- The new query/repository logic is a concrete class, following the exact "a repository reads whichever tables it needs directly" discipline already established by `GeneralCatchStatisticsRepository` and `WaterBodyRepository` (see [Data Ownership](#data-ownership)).
- Exact implementation design — repository/method signatures, the enriched read-model's shape, the new page's exact widget structure, the debounce mechanism, and whether `CatchListItem` is extended or a new result-row widget is introduced — is a Technical Design concern, out of scope for this specification.

---

## Acceptance Criteria

1. Typing a full or partial fish-species name (by its Finnish display name) returns every catch of that species.
2. Typing a full or partial water body name returns every catch recorded at a fishing spot belonging to that water body.
3. Typing a full or partial fishing spot name returns every catch recorded at that fishing spot.
4. Typing a full or partial lure brand (manufacturer) name returns every catch whose assigned lure is made by that manufacturer.
5. Typing a full or partial lure model/name returns every catch whose assigned lure matches that model.
6. Search matching is case-insensitive for every field in scope (species, water body, fishing spot, lure brand, lure model).
7. Leading and trailing whitespace in the search query does not affect matching or results.
8. An empty (or whitespace-only, after trimming) search query shows the full catch list, subject to any active filters.
9. Selecting a water body filter restricts results to catches recorded at a fishing spot belonging to that water body.
10. Selecting a species filter restricts results to catches of that species.
11. Selecting a lure filter restricts results to catches with that lure assigned.
12. Selecting a date range filter restricts results to catches caught within that range (inclusive).
13. An active text search and one or more active filters combine correctly (AND semantics) to narrow results to catches matching all of them.
14. The filter control visibly indicates when one or more filters are currently active.
15. The angler can clear the search text, clear all active filters, or clear both, restoring the full catch list.
16. A clear ("X") button appears inside the trailing end of the search field whenever it contains text, and is absent when the field is empty.
17. Pressing the search field's clear button clears the search query, immediately restores the full catch list (subject to any active filters), and removes focus from the field where platform-appropriate.
18. Tapping the search field immediately gives it focus, letting the user begin typing with no additional interaction.
19. Each result displays species, date, weight/length when available, water body, fishing spot, and lure when available.
20. Tapping a result opens the existing `CatchDetailsPage` for the correct catch.
21. Creating, editing, or deleting a catch elsewhere in the application is reflected in this milestone's browsing/search/filter results the next time they are shown or reloaded.
22. An empty catch database shows a distinct "no catches yet" message; a search or filter combination with no matches shows a distinct no-results message with an easy way to clear the query/filters.
23. Every capability in this milestone functions correctly with no network connection.
24. `flutter analyze` passes.
25. Automated tests cover: text search across each of the five searchable fields individually and in combination; case-insensitivity; whitespace handling; empty-query behavior; each filter category individually and in combination with text search and with each other; active-filter indication; clearing search/filters; the clear button's appearance/disappearance and its clear-and-refocus-removal behavior; the search field's tap-to-focus behavior; result content correctness (including a catch with no lure, no weight, or no length); navigation to and back from `CatchDetailsPage` preserving search/filter state; recomputation after a catch is created, edited, or deleted; and both empty-database and no-match states.
26. Physical Android testing is completed for this milestone.

---

## Out of Scope

- Natural-language or AI-assisted search of any kind
- Weight or length range filters
- An "only catches with photos" filter
- Personal-record ("is this a record catch") filtering
- Weather or environmental-condition filtering (no such data exists yet — `docs/roadmap.md` §3.2, unresolved)
- Saved searches or saved filter presets
- Cloud-backed or server-side search
- Search suggestions, autocomplete, or a recent-searches list
- Searching note content (`Catch.notes`, MFS-023) — notes remain excluded from search in this milestone
- Multi-select within a single filter category (one active value per category in this MVP — see [Conceptual Model](#filters-hold-one-active-value-per-category-in-this-mvp))
- Filter persistence across a full application restart (in-memory/session-only state is sufficient for this MVP, per the task's own guidance, unless a stronger existing project convention required otherwise — none was found)
- Sorting controls beyond whatever the underlying query already orders by (no user-facing sort picker is introduced)
- Pagination (consistent with every other catch list in this application to date)
- Editing, deleting, or creating catches from this new surface — it is a read-only browsing/search view; existing Add/Edit/Delete flows are unchanged
- Any redesign of the application's primary navigation shell (drawer, bottom navigation, or a home screen) — see [Conceptual Model](#the-correct-entry-point-follows-the-existing-established-navigation-convention--not-a-new-one)
- A second, parallel Catch Details implementation — `CatchDetailsPage` (MFS-014) is reused unmodified
- Any change to `Catch`, `FishingSpot`, `WaterBody`, `LureCatalogEntry`/`LureVariant`, `TackleBoxEntry`, or `CatchPhoto` domain models, database schema, or repository contracts beyond the new read-only query this milestone requires
- A new database table, column, or schema version of any kind
- A service layer, use-case layer, DAO layer, or repository interface of any kind
- Cloud synchronization

---

## Architecture Constraints

Restated here from the task brief, as binding constraints on Technical Design, not merely aspirational:

- Preserve the existing `Catch → FishingSpot → WaterBody` relationship exactly as established by MFS-009/MFS-024 — this milestone only reads it.
- Search and filtering logic must live in the data layer, not in presentation widgets.
- The data layer must return enriched catch results carrying what the list and `CatchDetailsPage` need (FR-17).
- Query filtering must be performed by Drift, not by loading all catches and filtering in Dart — with the sole, explicitly bounded exception of the fixed-size `FishSpecies` enum match (see [Conceptual Model](#fish-species-requires-a-small-bounded-in-memory-match--never-a-scan-of-catch-history)).
- No generic, reusable "search framework" is introduced — this milestone's query logic is specific to catches.
- No new database column, and no schema version increase, is introduced.
- No online service of any kind is involved.
- Existing catch creation, editing, deletion, map, and statistics behavior must remain unchanged.

---

## Relationship to Previous MFS Documents

- **MFS-009 (Catch Foundation)** established `Catch`, `CatchRepository`, and `CatchMapper`, which this milestone reads without modification to their write paths.
- **MFS-011 (View Catches for Fishing Spot)** explicitly deferred "filtering" in its own Out of Scope — the gap this milestone finally closes, at the global rather than per-spot grain.
- **MFS-014 (Catch Details View)** established the read-only detail page this milestone reuses entirely unmodified as its sole navigation target.
- **MFS-017 (Assign Lure to Catch)** established the `Catch.lureVariantId` reference this milestone searches and filters by, and the "remains resolvable even if retired" guarantee this milestone relies on for graceful degradation.
- **MFS-019 (Lure-Based Catch Statistics)** established the "only lures with recorded catches" list-scoping precedent this milestone's lure filter follows, and the "unresolvable lure reference handled without crashing" precedent this milestone's empty/error states rely on.
- **MFS-023 (Catch Notes)** explicitly named this milestone (then unnumbered, referenced as "MFS-024") as the future home for searching/filtering — this milestone fulfills that, for every field named in its own scope, while deliberately continuing to exclude note content itself (see [Out of Scope](#out-of-scope-1)).
- **MFS-024 / TD-024 / ADR-0007 (Water Bodies and Fishing Spot Hierarchy)** established `WaterBody`, its non-null relationship to `FishingSpot`, and the "resolved through the fishing spot, never duplicated onto the catch" discipline this milestone's search and filtering both depend on and preserve.

---

## Dependencies

No new external dependencies are required. This milestone reuses the existing stack and patterns:

- Flutter, Dart
- Drift (read-only queries against the existing `catches`, `fishing_spots`, `water_bodies`, and `lure_catalog` tables — no migration)
- The existing Repository pattern and feature-first structure (ADR-0001, ADR-0003, ADR-0004, ADR-0006)
- The existing `Catch`/`FishingSpot`/`WaterBody`/`LureCatalogEntry` domain models and their existing repositories, read directly
- The existing `CatchDetailsPage` (MFS-014), reused as this milestone's sole navigation target
- The existing `MapScreen` AppBar entry-point convention (MFS-019/TD-019 and its successors)

---

## Future Extensions

This milestone is expected to support, in later milestones, if real usage demonstrates the need:

- Multi-select within a single filter category (e.g. two or more species at once).
- Filter persistence across a full application restart.
- Searching note content (`Catch.notes`, MFS-023), once a real need to search free-text notes is demonstrated.
- Weight/length range filters, a "has photos" filter, and personal-record filtering — all explicitly deferred here, not rejected outright.
- Search suggestions or autocomplete, if real usage shows the plain text field is insufficient.
- Saved searches or filter presets.
- Weather/environmental filtering, contingent on the still-unresolved offline environmental-data-source question (`docs/roadmap.md` §3.2).

---

## Design Notes

This section records the open judgment calls this specification surfaces explicitly rather than resolving unilaterally, following the same discipline established by MFS-022/MFS-024's own Design Notes sections.

**Feature ownership placement is not settled here.** This document proposes housing the new query/repository logic and the new page within the existing `catches` feature, since it already owns the entity being searched — but, exactly as MFS-024 left `WaterBody`'s feature placement open for its own Technical Design, this document does not force that choice. A narrower alternative (a small, self-contained addition to `catches`' presentation layer only, with the actual cross-table query living wherever architecture review judges it fits best) is equally defensible.

**Whether `CatchListItem` is extended or a new result-row widget is introduced is not settled here.** See [Data Ownership](#data-ownership) — this is deliberately left to Technical Design, since it depends on how invasive an additive extension to the existing widget would be in practice, something better judged while actually implementing it.

**This document treats the previously abandoned "MFS-024 — Catch Search & Filtering" references as needing correction, not as already correct.** Several existing documents — `docs/roadmap.md` §3.1 and `docs/specifications/MFS-023-catch-notes.md` in multiple places — still refer to this feature as "MFS-024," reflecting the identifier's original, later-reassigned placement. Per the task that produced this document, those references are deliberately **not** corrected as part of creating this specification; they are catalogued in the accompanying report so they can be corrected together once this specification is actually approved, avoiding a half-updated documentation state if this draft is revised before approval.

**An ADR is not recommended for this milestone.** Unlike MFS-024 (which introduced a new persistent domain entity, a new parent-deletion lifecycle rule, and an open feature-placement question of ADR-0004's own caliber), this milestone introduces no new persistent entity, no new lifecycle/deletion rule, and no schema change — only a new read-only query surface and one new, precedented navigation entry point. Per the task's own guidance, an ADR is warranted only if the proposed solution changes the application's primary navigation architecture; it does not.
