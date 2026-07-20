# MFS-020 — General Catch Statistics

## Status

Draft

## Related

- Depends on: MFS-009 — Catch Foundation
- Depends on: MFS-011 — View Catches for Fishing Spot (existing catch information/formatting conventions this milestone reuses)
- Depends on: MFS-013 — Catch Photos (photo display, image-fallback convention)
- Depends on: MFS-014 — Catch Details View (the navigation target for this milestone's Top 3 Largest Catches list)
- Depends on: MFS-019 — Lure-Based Catch Statistics (introduces the Statistics feature and its tabbed shell, `StatisticsPage`, that this milestone adds a second tab to)
- Introduces: the Statistics feature's first tab, **Catches** — MFS-019's existing Lure Statistics tab moves to the second tab position, unchanged in every other respect
- Future: MFS-021 Candidate — Species Statistics (see `docs/roadmap.md`) — the Species List this milestone introduces is designed for that future navigation, which is not implemented here

---

## Purpose

Let an angler see general statistics about their own catch history — not tied to any specific lure — as the new first tab of the Statistics feature MFS-019 already introduced: which catches were the biggest, how many fish they've logged in total, which species they catch most, and a full breakdown of catches by species.

This milestone reuses the exact "computed live, never stored" discipline MFS-019 established (FR-8 of that milestone), extended here from lure-scoped catch data to the angler's entire catch history across every fishing spot.

---

## User Value

Anglers have been able to log catches (MFS-009–MFS-014) and see lure-scoped statistics (MFS-019) as two separate capabilities. Neither one answers a simple question an angler naturally has about their own fishing history, independent of which lure was used:

- What are the biggest fish I've ever caught?
- How many fish have I caught in total?
- What species do I catch the most?
- How many of each species have I caught?

This milestone answers exactly that, reusing the Statistics feature's existing shell (MFS-019) rather than introducing a new, separate screen for it.

---

## Scope

### In Scope

- Reordering the Statistics feature's tabs so **Catches** (this milestone) is first and **Lure Statistics** (MFS-019) is second. MFS-019's own tab — its computation, its data, its behavior — is otherwise completely unmodified.
- **Top 3 Largest Catches:** the three catches with the greatest recorded weight, descending, each representing a real, existing `Catch` and navigating to the existing Catch Details view (MFS-014) when selected.
- **Summary statistics:** total number of catches, and the most caught species.
- **Species List:** all species present in the user's catch history, and how many catches of that species, sorted by catch count descending. Rows are designed for future navigation to species-specific statistics (see [Future Extensions](#future-extensions)); that navigation is not part of this milestone.
- Loading, empty, and error states for all of the above.
- All values computed live from existing `Catch`/`CatchPhoto` data — nothing is cached, stored, or persisted.

### Out of Scope

See [Out of Scope](#out-of-scope-1) for the complete list. Notably: charts/graphs, yearly/monthly statistics, averages, trends, weather statistics, location statistics, lure statistics (unchanged, MFS-019 territory), exports, filtering, searching, achievements, and any navigation from the Species List (MFS-021 Candidate, not this milestone).

---

## User Stories

**As an angler**
I want to see the biggest fish I've ever caught
So that I can recall my best catches without scrolling through every fishing spot's catch list.

**As an angler**
I want to see how many fish I've caught in total
So that I have a simple sense of my own fishing history at a glance.

**As an angler**
I want to see which species I catch most often
So that I understand my own fishing habits without doing the counting myself.

**As an angler**
I want to see a full breakdown of how many of each species I've caught
So that I can compare species against each other, not just see the single most-caught one.

**As an angler**
I want to open a catch's full details from the biggest-catches list
So that I can see everything about that catch — photo, lure, fishing spot — without hunting for it in a fishing spot's catch list.

**As an angler**
I want these statistics to update automatically as I log, edit, or delete catches
So that I never have to remember to refresh anything myself.

---

## Conceptual Model

This section resolves the product-level questions this milestone must answer before Technical Design work begins, following the same discipline MFS-019's Conceptual Model already established. Exact query, repository, and aggregation design remain a Technical Design (TD-020) concern, not addressed here.

### Computed from the angler's entire catch history, not a single fishing spot

Every existing catch-related view in this application (MFS-011's catch list, and by extension MFS-014's Catch Details reached from it) is scoped to one fishing spot at a time. This milestone is the first to look across **every** fishing spot's catches at once — the Top 3 Largest Catches, the total count, the most caught species, and the Species List all consider the angler's complete catch history, not catches belonging to any single fishing spot.

### Granularity: the individual Catch, not an aggregate

Each entry in the Top 3 Largest Catches list represents one real, existing `Catch` — the same domain object MFS-009 already defines and MFS-014 already displays in full. Nothing about a catch is duplicated or summarized into a new type for this purpose beyond what is needed to rank and display it; selecting an entry opens the actual Catch Details view for that actual catch (MFS-014), not a summary or a copy of it.

### Species List: all species present in the user's catch history

The Species List displays all species present in the user's catch history — every species the angler has actually caught. A species the angler has never caught has nothing to show yet, so it does not appear in this list. This mirrors the same choice MFS-019 made for its own lure list (a lure the angler has never caught anything with does not appear there either). As with that precedent, this is not a permanent product rule — a future version may optionally show every species, including ones never caught, if that proves useful once this milestone is in real use.

### "Most caught species" is the top-ranked entry of the Species List

Rather than a separately computed value, "most caught species" (the second summary statistic) is simply the Species List's own top-ranked entry — the same relationship MFS-019 established between its "most successful lure" summary card and its lure list (MFS-019's Key Design Decision 5). This avoids computing the same ranking twice.

### Deterministic ranking

The Top 3 Largest Catches (ranked by weight) and the Species List / "most caught species" (ranked by catch count) must each resolve to a single, stable result — the same underlying data must always produce the same displayed order, never one that varies across app restarts or reloads because of a tie. Results shall be deterministic when multiple catches share the same weight, or multiple species share the same catch count. The specific tie-breaking strategy is a Technical Design (TD-020) concern and is not defined in this specification — this mirrors MFS-019's own architecture-review correction, which moved from specifying a tie-break algorithm in the MFS to requiring only the product-level guarantee of determinism.

### Species List rows anticipate future navigation

Species List rows are designed for future navigation to species-specific statistics (MFS-021 Candidate — a roadmap idea, not yet drafted or approved; see `docs/roadmap.md`), expected to give each row a real destination: a dedicated Species Statistics page for that species. This milestone presents each row using this application's existing selectable-row appearance, consistent with how selectable rows already look elsewhere in the app, so a future milestone does not need to restyle the list. Navigation to species-specific statistics is planned for a future milestone, not delivered here — selecting a row in this milestone has no effect.

### No new stored data

This milestone introduces no new persisted statistic, cache, or aggregate of any kind, and no new database table, column, or migration. Every value shown — the Top 3 Largest Catches, the total count, the most caught species, and the Species List — is computed from existing `Catch` and `CatchPhoto` data each time the Catches tab is viewed, exactly matching MFS-019 FR-8's "computed live, never stored" discipline.

---

## Functional Requirements

### FR-1 — Statistics Tab Order

The Statistics feature's tabs must appear in the order **Catches** (this milestone), then **Lure Statistics** (MFS-019). Opening the Statistics feature must default to the Catches tab. MFS-019's Lure Statistics tab is not modified in any other way by this milestone — its computation, data, and behavior remain exactly as MFS-019/TD-019 already define them.

### FR-2 — Catches Tab Reflects the Full Catch History

Every statistic on the Catches tab must reflect the angler's entire catch history — every catch across every fishing spot — not catches scoped to a single fishing spot, per [Conceptual Model](#computed-from-the-anglers-entire-catch-history-not-a-single-fishing-spot).

### FR-3 — Top 3 Largest Catches

A list shows the three catches with the greatest recorded weight, in descending order. A catch with no recorded weight must never appear in this list, regardless of any other field it has. If fewer than three catches have a recorded weight, the list shows only the ones that do. If no catch has a recorded weight at all, the list shows a clear empty state rather than appearing broken, blank, or incomplete.

### FR-4 — Top 3 Largest Catches Row Content

Each row represents one real, existing `Catch` and may show:

- the catch's photo, if one exists (the first photo by `sortOrder`, per the existing image-fallback convention already established for catch photos — MFS-013, MFS-014 FR-8/FR-9),
- species,
- weight,
- length, if present.

A catch with no photo, or no recorded length, must render cleanly with no empty placeholder — the same "missing optional value" discipline already used throughout this application (e.g. MFS-011 FR-6, MFS-014 FR-2).

### FR-5 — Top 3 Largest Catches Navigation

Selecting an entry in the Top 3 Largest Catches list must open the existing, unmodified Catch Details view (MFS-014) for that specific catch. This milestone does not change Catch Details in any way — it only adds one more entry point into it, alongside the existing catch-list entry point (MFS-014 FR-1). The exact navigation mechanism is a Technical Design concern and is not defined further here.

### FR-6 — Summary Statistics

Two summary values are shown: the total number of catches the angler has ever logged, and the most caught species (per [Conceptual Model](#most-caught-species-is-the-top-ranked-entry-of-the-species-list)). If the angler has no catches at all, the total reads 0 and the most caught species shows a clear "no data yet" state, not a placeholder or misleading value.

### FR-7 — Species List

A list shows all species present in the user's catch history (see [Conceptual Model](#species-list-all-species-present-in-the-users-catch-history)), each row showing the species and how many catches the angler has of that species. The list is sorted by catch count descending, with ties broken deterministically per [Conceptual Model](#deterministic-ranking).

### FR-8 — Species List Rows Anticipate Future Navigation

Each Species List row must be presented using this application's existing selectable-row appearance, signaling that navigation to species-specific statistics is planned for a future milestone (see [Future Extensions](#future-extensions)) without requiring a future restyle. Selecting a row in this milestone must have no effect whatsoever. See [Conceptual Model](#species-list-rows-anticipate-future-navigation).

### FR-9 — Deterministic Ranking

Wherever this milestone orders data by a value that can tie — the Top 3 Largest Catches by weight, and the Species List / most caught species by catch count — the result must be deterministic. The same underlying data must always produce the same displayed order and the same displayed "most caught species." The specific tie-breaking strategy is a Technical Design concern, per [Conceptual Model](#deterministic-ranking).

### FR-10 — Computed Live, Never Stored

Every value this milestone displays — the Top 3 Largest Catches, the total, the most caught species, and the Species List — is computed at the moment the Catches tab is opened, directly from existing `Catch`/`CatchPhoto` data. No aggregate, count, ranking, or "largest catches" list is written to persistent storage anywhere.

### FR-11 — Lure Statistics Tab Unchanged

MFS-019's Lure Statistics tab — its computation, its data, its UI, and its own internal behavior — is not modified by this milestone in any way. The only externally visible change to that tab is its position within the `TabBar` (now second instead of first).

### FR-12 — Offline Operation

Every capability in this milestone works with no network connection, consistent with the rest of the application.

---

## UI Expectations

- The Catches tab follows the same general presentation shape MFS-019 already established for Lure Statistics — summary content near the top, followed by list content below — without requiring a new layout paradigm for the Statistics feature.
- The Top 3 Largest Catches list and the Species List are simple, scrollable lists, consistent with the plain list presentation already used throughout this application — not a chart, graph, or other visual data representation (explicitly out of scope).
- No search field, filter control, or sort control is shown on the Catches tab. The Top 3 Largest Catches list and the Species List always show their full, fixed order as defined in [Functional Requirements](#functional-requirements).
- All user-visible text is in Finnish, consistent with the application's existing UI text convention. Exact wording is a Technical Design/implementation concern, not specified here.
- The Catches tab is recomputed whenever it becomes visible (initial open, and returning to it), so newly logged, edited, or deleted catches are reflected without any explicit refresh action — the same behavior already established for the Lure Statistics tab (MFS-019).

---

## Navigation

```text
Statistics
  ├── Catches (this milestone, first tab, default)
  │     └── Top 3 Largest Catches entry → Catch Details (MFS-014, existing, unmodified)
  └── Lure Statistics (MFS-019, second tab, unchanged)
```

Opening the Statistics feature now opens directly to the Catches tab by default (FR-1). Selecting an entry in the Top 3 Largest Catches list opens the existing Catch Details view for that catch (FR-5); the exact navigation mechanism is a Technical Design concern. Selecting a Species List row does nothing in this milestone (FR-8).

---

## Data Ownership

- This milestone extends the existing **Statistics** feature (introduced by MFS-019); it does not introduce a new top-level feature directory.
- The Statistics feature reads existing `Catch` data (MFS-009) and existing `CatchPhoto` data (MFS-013) directly, read-only — the same reference-not-copy, read-only-across-feature-boundary pattern MFS-019 already established for reading `catches` and `lure_catalog` data from within the Statistics feature.
- The `catches` and `catch_photos` features remain entirely unmodified — no change to their domain models, database schemas, or repository contracts is required or permitted by this milestone.
- The Statistics feature never duplicates catch or photo data. Every value displayed is resolved live from existing data; nothing is copied into a Statistics-owned record.

---

## Empty, Loading, and Error States

- **No catches logged at all:** the total reads 0, the most caught species shows "no data yet," the Top 3 Largest Catches list and the Species List each show a clear, distinct empty-state message — not an empty-looking blank area.
- **Catches exist, but none have a recorded weight:** the Top 3 Largest Catches list shows its own empty state (per FR-3), while the total, most caught species, and Species List continue to populate normally — weight has no bearing on those.
- **Loading:** while the Catches tab's statistics are being computed, it shows a clear loading indicator, distinct from the empty and error states, consistent with the loading-state convention already established for the Lure Statistics tab (MFS-019).
- **Computation failure:** if reading or computing the Catches tab's statistics fails (e.g. a database read error), the tab shows a clear error message and must not crash the application. The user can retry, consistent with the retry convention already established for the Lure Statistics tab (MFS-019).

---

## Edge Cases

- A catch with a recorded weight but no photo is still eligible for the Top 3 Largest Catches list and renders cleanly with no photo placeholder issue (FR-4).
- Multiple catches tied at the same largest weight resolve deterministically (FR-9) — the Top 3 Largest Catches list never shows an ambiguous or randomly-varying result across app restarts.
- Multiple species tied at the same catch count resolve deterministically (FR-9) in both the Species List's order and the "most caught species" summary value.
- A species caught exactly once appears in the Species List with a catch count of 1 — a fully valid entry, not a special case.
- Deleting a catch (MFS-012) that was part of the Top 3 Largest Catches is reflected the next time the Catches tab is computed — a different catch may take its place, or the list may shrink, per FR-3.
- Editing a catch's weight (MFS-012) such that it newly qualifies for, or no longer qualifies for, the Top 3 Largest Catches is reflected the next time the Catches tab is computed.
- Editing a catch's species (MFS-012) is reflected in the Species List and, if applicable, the most caught species the next time the Catches tab is computed.
- A catch belonging to a fishing spot that is later deleted (MFS-008, which cascades catch deletion) is removed from every statistic on the Catches tab exactly as any other deleted catch would be — no special-casing.

---

## Accessibility Expectations

- Each entry in the Top 3 Largest Catches list exposes a semantic label combining species, weight, and length (when present) — not just decorative text — mirroring the accessibility requirement already established for catch information elsewhere in the application (MFS-011, MFS-014).
- Each row in the Species List exposes a semantic label combining the species and its catch count.
- Because navigation to species-specific statistics is planned for a future milestone rather than delivered here (FR-8), Species List rows must not be exposed to assistive technology as a button or other actionable element in this milestone — only as static content (species and catch count) — avoiding a dead-end affordance for screen reader users. This is expected to change once that future milestone (MFS-021 Candidate) adds real navigation.
- Empty, loading, and error states are each conveyed accessibly, not only through visual presentation, consistent with the equivalent requirement in MFS-019.
- Tap targets and text throughout this milestone follow the application's existing Material 3 sizing and text-scaling conventions.

---

## Feature Ownership and Placement

Following the existing feature-first structure and database ownership rules (ADR-0001, ADR-0003, ADR-0006), this milestone extends the **Statistics** feature introduced by MFS-019; it does not introduce a new feature directory.

- The Statistics feature gains whatever presentation-only read models and read-only data access it needs to compute the Catches tab's content (a Top 3 Largest Catches list, a total, a most caught species, and a Species List). It owns no new database table.
- The `catches` feature (MFS-009) and `catch_photos` feature (MFS-013) are read from, never modified.
- Exact implementation design — including data access, presentation widget breakdown, and file naming — is a Technical Design concern, out of scope for this specification.

---

## Acceptance Criteria

- The Statistics feature shows two tabs, in order: Catches (this milestone) first, Lure Statistics (MFS-019) second.
- Opening the Statistics feature defaults to the Catches tab.
- The Top 3 Largest Catches list shows up to three catches, ordered by weight descending, with deterministic tie-breaking.
- A catch with no recorded weight never appears in the Top 3 Largest Catches list.
- If fewer than three catches have a recorded weight, only the available ones are shown; if none do, a clear empty state is shown.
- Each Top 3 Largest Catches entry represents a real `Catch` and may show its photo (if available), species, weight, and length (if available), rendering cleanly when any of those are absent.
- Selecting a Top 3 Largest Catches entry opens the existing Catch Details view for that catch.
- The total number of catches and the most caught species are shown, with a clear "no data yet" state when the angler has no catches.
- The Species List displays all species present in the user's catch history, with its catch count, sorted by catch count descending, with deterministic tie-breaking.
- Species list rows are designed for future navigation to species-specific statistics; tapping a row performs no action in this milestone.
- Every value on the Catches tab is computed fresh on each open — no cached, stored, or persisted aggregate exists anywhere.
- No new Drift table, column, schema version, or migration is introduced.
- The `catches`, `catch_photos`, and `lure_catalog`/`personal_tackle_box` features are functionally and structurally unchanged by this milestone.
- MFS-019's Lure Statistics tab is functionally unchanged; only its tab position changes.
- Loading and error states are shown clearly and distinctly from the empty and populated states.
- Every capability in this milestone works with no network connection.
- `flutter analyze` passes.
- Automated tests cover: Top 3 Largest Catches ranking and weight-based exclusion (including fewer-than-three and zero-weighted-catches cases), a tie in largest-catch weight, Top 3 Largest Catches navigation to Catch Details, total-count and most-caught-species computation (including a tie), Species List sort order and content, Species List rows performing no action when tapped, and recomputation after a catch is created, edited, or deleted.

---

## Out of Scope

- Charts or graphs of any kind
- Yearly statistics
- Monthly statistics
- Averages of any kind
- Trends of any kind
- Weather statistics
- Location statistics
- Lure statistics (unchanged, MFS-019 territory — this milestone reorders its tab position only)
- Export of any kind
- Filtering
- Searching
- Achievements
- Navigation from the Species List to any destination (MFS-021 Candidate, not this milestone — see `docs/roadmap.md`)
- A dedicated Species Statistics page or any per-species detail view
- Editing or deleting catches (unchanged, MFS-012 territory)
- Any change to the `catches`, `catch_photos`, `lure_catalog`, or `personal_tackle_box` domain models, database schemas, or repository contracts
- Any change to MFS-019's Lure Statistics tab computation, data, or behavior
- Any persisted/stored statistic, cache, or aggregate table
- Including species with zero catches in the Species List (see [Conceptual Model](#species-list-all-species-present-in-the-users-catch-history) — not a permanent rule, just not part of this milestone)
- Cloud synchronization

---

## Relationship to Previous MFS Documents

- **MFS-009 (Catch Foundation)** established `Catch` as a framework-independent domain model and listed "Catch Statistics" among its expected Future Milestones. This milestone, together with MFS-019, is what finally delivers that — MFS-019 covered lure-scoped statistics; this milestone covers everything general.
- **MFS-011 (View Catches for Fishing Spot)** established the existing per-fishing-spot catch list and its weight/length formatting conventions, reused unchanged by this milestone's Top 3 Largest Catches rows. This milestone is the first to look across every fishing spot at once, rather than one at a time as MFS-011 does.
- **MFS-013 (Catch Photos)** established the image-fallback and `sortOrder`-based "first photo" convention this milestone's Top 3 Largest Catches rows reuse unchanged.
- **MFS-014 (Catch Details View)** established the read-only Catch Details view this milestone's Top 3 Largest Catches list opens as its navigation target, and the "missing optional value" rendering discipline this milestone's rows also follow.
- **MFS-019 (Lure-Based Catch Statistics)** introduced the Statistics feature and its tabbed shell (`StatisticsPage`), explicitly built to hold more than one tab (per TD-019's Key Design Decision 7 and Future Compatibility section). This milestone is exactly the second tab TD-019 anticipated, added with no restructuring of the existing Lure Statistics tab. This milestone also directly reuses MFS-019's "computed live, never stored" principle (FR-8), its precedent for excluding zero-catch entries from an initial list implementation, and its architecture-review-corrected approach to deterministic ranking (tie-breaking specified at the Technical Design level, not the MFS level).

---

## Dependencies

No new external dependencies are required. This milestone reuses the existing stack and patterns:

- Flutter, Dart
- Drift (read-only queries against existing tables, per ADR-0005)
- The existing Repository pattern and feature-first structure (ADR-0001, ADR-0003, ADR-0006)
- The existing `Catch` domain model (MFS-009) and `CatchPhoto` domain model (MFS-013), read-only
- The existing Catch Details view (MFS-014), reused unmodified as this milestone's navigation target
- The Statistics feature's tabbed shell (`StatisticsPage`) and presentation conventions already established by MFS-019/TD-019

---

## Future Extensions

This milestone is expected to support, in later milestones:

- **Species Statistics** (MFS-021 Candidate — see `docs/roadmap.md`): connecting the Species List's rows to a dedicated per-species page showing a species summary, record catch, average weight/length, total catches, every catch of that species sorted by weight, and (per catch) an optional photo, date, and fishing location — tapping a catch there opening the existing Catch Details page, exactly as this milestone's own Top 3 Largest Catches list already does.
- Including species with zero catches in the Species List, if that proves useful once real statistics are in use (mirroring the equivalent extension already named for MFS-019's lure list).
- Filtering these statistics (e.g. by date range or fishing spot).
- Percentages, averages, trends, and other derived metrics explicitly excluded from this milestone.
- Weather and location-based statistics, once (if ever) an offline-compatible data source is decided (`docs/roadmap.md` §3.3).
- Visual (chart/graph) presentation of the data this milestone introduces in list/card form.
