# MFS-021 — Species Statistics

## Status

Draft

## Related

- Depends on: MFS-009 — Catch Foundation
- Depends on: MFS-011 — View Catches for Fishing Spot (ordering and per-catch information conventions this milestone's Catch List reuses)
- Depends on: MFS-013 — Catch Photos (photo display, image-fallback convention)
- Depends on: MFS-014 — Catch Details View (the navigation target for this milestone's Catch List)
- Depends on: MFS-020 — General Catch Statistics (the Species List whose rows this milestone finally wires to a real destination)
- Introduces: a new, pushed Species Statistics page within the existing **Statistics** feature (MFS-019/MFS-020) — not a new tab
- Replaces: MFS-020's own placeholder framing of "MFS-021 Candidate" (`docs/roadmap.md` §3.1) with an actual, scoped specification

---

## Purpose

Let an angler tap a species in MFS-020's Species List and see everything about their own catch history for that one species specifically: how many times they've caught it, their record catch of that species, and every individual catch of that species, each opening the existing Catch Details view when selected.

This milestone is the follow-up MFS-020 deliberately anticipated but did not build: MFS-020's Species List rows already use this application's selectable-row appearance and are explicitly excluded from assistive-technology button semantics, precisely because navigation to this page was expected later (MFS-020 FR-8, Accessibility Expectations). This milestone is exactly that later navigation.

---

## User Value

MFS-020 already lets an angler see which species they catch most often and how many catches each species has, as a single flat list. It deliberately stops there — a Species List row shows only a species name and a count. This milestone answers the questions that flat list cannot:

- Of everything I've caught of this species, what's my best one?
- What did that catch look like — photo, weight, length, when, and where?
- Every time I've caught this species, in one place, ordered by size?
- Can I open the full details of any one of those catches, the same way I already can from MFS-020's Top 3 Largest Catches?

## Scope

### In Scope

- A new Species Statistics page, reached by tapping a row in MFS-020's Species List.
- A header showing the species name and the total number of catches of that species.
- A **Record Catch** section prominently showing the angler's best catch of that species — photo (if available), weight, length (if available), catch date, and catch location (if available).
- A **Catch List** showing every catch of the selected species, ordered by weight descending, then date descending, then catch id as a deterministic tie-breaker, reusing the existing `CatchListItem` widget unmodified.
- Selecting a Catch List entry opens the existing Catch Details view (MFS-014).
- Graceful handling of missing photo, weight, length, and location on any catch, including the Record Catch.
- Loading and error states.
- All values computed live from existing `Catch`/`CatchPhoto`/`FishingSpot` data — nothing is cached, stored, or persisted.

### Out of Scope

See [Out of Scope](#out-of-scope-1) for the complete list. Notably: charts/graphs, averages, seasonal statistics, lure statistics, weather statistics, maps, filters, searching, exporting, and any other new analytics beyond what is explicitly listed above.

---

## User Stories

**As an angler**
I want to tap a species in my catch statistics
So that I can see everything about my history with that specific species, not just its total count.

**As an angler**
I want to see my record catch of a species — the biggest one — front and center
So that I don't have to scan a whole list to find my best result.

**As an angler**
I want to see every catch I've made of that species, ordered from biggest to smallest
So that I can compare my own catches of that species against each other.

**As an angler**
I want to open a catch's full details from this list
So that I can see everything about it — photo, lure, fishing spot — the same way I already can elsewhere in this app.

**As an angler**
I want catches with a missing photo, weight, length, or location to still display cleanly
So that incomplete data never makes the page look broken.

---

## Conceptual Model

This section resolves the product-level questions this milestone must answer before Technical Design work begins, following the same discipline MFS-019/MFS-020's own Conceptual Model sections already established. Exact query, repository, and widget design remain a Technical Design concern, not addressed here.

### Scoped to one species, across the angler's entire catch history

This milestone looks at every catch of one specific species, across every fishing spot — the same "entire catch history, not one fishing spot at a time" scope MFS-020 already established (MFS-020's Conceptual Model), narrowed here to a single species rather than every species at once.

### Record Catch is the top-ranked entry of the Catch List, not a separately computed value

Rather than a separately derived "best catch" computation, the Record Catch is simply the first entry of the same deterministically ordered Catch List this milestone already produces (see [Deterministic Ordering](#deterministic-ordering) below) — the same "derived from an already-sorted list, not recomputed" relationship MFS-020 established between "most caught species" and its own Species List (MFS-020's Conceptual Model, itself following MFS-019's precedent for "most successful lure").

This differs deliberately from MFS-020's Top 3 Largest Catches, which excludes any catch with no recorded weight entirely (MFS-020 FR-3). This milestone's Catch List includes every catch of the species regardless of whether it has a recorded weight, so its top entry — the Record Catch — may itself have no recorded weight, if none of the angler's catches of that species do. In that situation the Record Catch is simply the most recently caught entry (per the ordering's later tie-break levels), displayed with its weight omitted like any other catch with a missing value ([Missing Data Handling](#missing-data-handling-is-per-field-not-all-or-nothing) below) — not withheld, and not treated as an error.

### Deterministic ordering

The Catch List — and, by extension, the Record Catch, which is simply its first entry — is ordered:

1. weight, **descending** (a catch with no recorded weight sorts after every catch that has one)
2. catch date, **descending**
3. catch id, **ascending** (a guaranteed-unique final tie-breaker, since no two catches share an id)

Unlike MFS-019/MFS-020, which left tie-breaking specifics to their respective Technical Designs, this ordering is specified directly here because it was already fully determined at the product level before this document was drafted. A Technical Design may still choose exact comparator implementation details, but the ordering rule itself — including where a missing weight sorts — is not open for reinterpretation.

### Missing data handling is per-field, not all-or-nothing

A catch's photo, weight, length, and (for the Record Catch) location are each independently optional. Each is handled on its own: a catch missing one of these values still displays normally, showing every value it does have, with no broken layout, empty placeholder box, or blank line where the missing value would go. This is the same "missing optional value" discipline already used throughout this application (MFS-011 FR-6, MFS-014 FR-2, MFS-020 FR-4), applied here per catch and per field rather than excluding the catch altogether.

### Catch location means the catch's fishing spot

A catch does not carry a location of its own — it belongs to a `FishingSpot` (MFS-009), which is where its location comes from. "Catch location," as shown in the Record Catch section, means resolving and displaying that fishing spot, the same relationship MFS-020's Top 3 Largest Catches navigation already resolves for its own catches (MFS-020's Key Design Decision 1/2, TD-020). A catch whose fishing spot cannot be resolved is treated the same as any other missing field — omitted, not an error, since this should not occur in practice (a fishing spot is never deleted out from under a catch that still references it, per MFS-008's cascading deletion).

### No new stored data

This milestone introduces no new persisted statistic, cache, or aggregate of any kind, and no new database table, column, or migration. The species' total catch count, the Record Catch, and the full Catch List are all computed from existing `Catch`, `CatchPhoto`, and `FishingSpot` data each time the page is opened — the same "computed live, never stored" discipline MFS-019 established and MFS-020 already extended to the angler's full catch history.

---

## Functional Requirements

### FR-1 — Navigation Entry

Tapping a row in MFS-020's Species List must open the Species Statistics page for that specific species. This is the navigation MFS-020 FR-8 explicitly left unimplemented.

### FR-2 — Header

The page must show, for the selected species: the species name, and the total number of catches of that species in the angler's entire catch history.

### FR-3 — Species-Scoped, Full History

Every value on this page must reflect every catch of the selected species across every fishing spot, not catches scoped to a single fishing spot, per [Conceptual Model](#scoped-to-one-species-across-the-anglers-entire-catch-history).

### FR-4 — Record Catch

The page must prominently show a Record Catch section representing the angler's top-ranked catch of the selected species, per the ordering defined in [FR-7](#fr-7--deterministic-catch-list-ordering). See [Conceptual Model](#record-catch-is-the-top-ranked-entry-of-the-catch-list-not-a-separately-computed-value) for why this may be a catch with no recorded weight.

### FR-5 — Record Catch Content

The Record Catch section may show:

- the catch's photo, if one exists (the first photo by `sortOrder`, per the existing image-fallback convention — MFS-013, MFS-014 FR-8/FR-9, MFS-020 FR-4),
- weight, if recorded,
- length, if recorded,
- catch date,
- catch location, if resolvable (per [Conceptual Model](#catch-location-means-the-catchs-fishing-spot)).

A missing photo, weight, length, or location must not leave an empty placeholder, broken layout, or blank line — per [Missing Data Handling](#missing-data-handling-is-per-field-not-all-or-nothing).

### FR-6 — Catch List

The page must show every catch of the selected species, below the Record Catch section, reusing the existing `CatchListItem` widget (MFS-011/MFS-014, already reused unmodified by MFS-020's Top 3 Largest Catches list) with no modification.

### FR-7 — Deterministic Catch List Ordering

The Catch List must be ordered by weight descending, then catch date descending, then catch id ascending, exactly as specified in [Conceptual Model](#deterministic-ordering). This ordering must be applied unconditionally, not only when a tie is observed. The same ordering determines the Record Catch, per [FR-4](#fr-4--record-catch).

### FR-8 — Catch List Navigation

Selecting an entry in the Catch List must open the existing, unmodified Catch Details view (MFS-014) for that specific catch — the same navigation target MFS-020's Top 3 Largest Catches list already uses (MFS-020 FR-5). This milestone does not change Catch Details in any way; it only adds one more entry point into it.

### FR-9 — Missing Data Handling

A catch anywhere on this page — in the Record Catch section or the Catch List — missing a photo, weight, length, or (Record Catch only) location must render cleanly, showing every value it does have with no broken or empty UI for the values it lacks, per [Conceptual Model](#missing-data-handling-is-per-field-not-all-or-nothing).

### FR-10 — Computed Live, Never Stored

Every value this milestone displays — the header's total, the Record Catch, and the Catch List — is computed at the moment the Species Statistics page is opened, directly from existing `Catch`/`CatchPhoto`/`FishingSpot` data. No aggregate, ranking, or "record catch" is written to persistent storage anywhere.

### FR-11 — Offline Operation

Every capability in this milestone works with no network connection, consistent with the rest of the application.

---

## UI Expectations

- The page follows the same general presentation shape already established elsewhere in this application's read-only detail views (MFS-014's Catch Details, MFS-020's Catches tab): a prominent summary/header area, followed by list content below.
- The Record Catch section is visually distinct from the Catch List entries below it — it is the angler's single best catch of the species, not just the first row of an otherwise-uniform list.
- The Catch List is a simple, scrollable list, consistent with the plain list presentation already used throughout this application (MFS-011, MFS-019, MFS-020) — not a chart, graph, or other visual data representation (explicitly out of scope).
- No search field, filter control, or sort control is shown. The Catch List always shows its full, fixed order as defined in [FR-7](#fr-7--deterministic-catch-list-ordering).
- All user-visible text is in Finnish, consistent with the application's existing UI text convention. Exact wording is a Technical Design/implementation concern, not specified here.
- The page is recomputed each time it is opened, so newly logged, edited, or deleted catches are reflected without requiring the user to take any explicit refresh action — the same behavior already established for the Catches and Lure Statistics tabs (MFS-019/MFS-020).

---

## Navigation

```text
Statistics
  └── Catches (MFS-020)
        └── Species List entry tapped → Species Statistics (this milestone)
                └── Catch List entry tapped → Catch Details (MFS-014, existing, unmodified)
```

Species Statistics is a pushed, full-screen page reached from a Species List row (FR-1) — the same navigation pattern already used for Catch Details (MFS-014) and for MFS-020's Top 3 Largest Catches entries, not a new tab of the Statistics feature. Selecting a Catch List entry opens the existing Catch Details view for that catch (FR-8); the exact navigation mechanism is a Technical Design concern.

---

## Data Ownership

- This milestone extends the existing **Statistics** feature (introduced by MFS-019, extended by MFS-020); it does not introduce a new top-level feature directory.
- The Statistics feature reads existing `Catch` data (MFS-009), existing `CatchPhoto` data (MFS-013), and existing `FishingSpot` data (MFS-004) directly, read-only — the same reference-not-copy, read-only-across-feature-boundary pattern already established by MFS-019/MFS-020.
- The `catches`, `catch_photos`, and `fishing_spots` features remain entirely unmodified — no change to their domain models, database schemas, or repository contracts is required or permitted by this milestone.
- The Statistics feature never duplicates catch, photo, or fishing spot data. Every value displayed is resolved live from existing data; nothing is copied into a Statistics-owned record.

---

## Empty, Loading, and Error States

- **The selected species has no catches at the moment the page loads** (e.g. its only catch was deleted between MFS-020's Species List rendering and this page opening): the header shows a total of 0, and both the Record Catch section and Catch List show a clear empty-state message rather than an empty-looking blank area. This should be rare in practice but must not crash or render a broken page.
- **Loading:** while this page's data is being computed, it shows a clear loading indicator, distinct from the empty and error states, consistent with the loading-state convention already established elsewhere in the Statistics feature (MFS-019/MFS-020).
- **Computation failure:** if reading or computing this page's data fails (e.g. a database read error), the page shows a clear error message and must not crash the application. The user can retry, consistent with the retry convention already established for the Catches and Lure Statistics tabs (MFS-019/MFS-020).

---

## Edge Cases

- A species caught exactly once shows a header total of 1, a Record Catch equal to that single catch, and a Catch List containing exactly that one entry — a fully valid state, not a special case.
- Multiple catches of the species tied at the same weight resolve deterministically (FR-7) — the Catch List, and therefore the Record Catch, never show an ambiguous or randomly-varying result across app restarts.
- A species where no catch has a recorded weight still has a Record Catch (the most recently caught entry, per [Conceptual Model](#record-catch-is-the-top-ranked-entry-of-the-catch-list-not-a-separately-computed-value)), shown with its weight omitted.
- A catch with a recorded weight but no photo, length, or resolvable fishing spot still qualifies as the Record Catch and renders cleanly with those values omitted (FR-9).
- Deleting a catch (MFS-012) that was the species' Record Catch is reflected the next time the Species Statistics page is opened — a different catch becomes the new Record Catch, or the list becomes empty, per [Empty, Loading, and Error States](#empty-loading-and-error-states).
- Editing a catch's weight, date, or species (MFS-012) is reflected in this page's ordering, Record Catch, and total the next time it is opened. If the edit changes the catch's species away from the one this page was opened for, that catch simply no longer appears here on the next load.
- A catch belonging to a fishing spot that is later deleted (MFS-008, which cascades catch deletion) is removed from this page's total, Record Catch, and Catch List exactly as any other deleted catch would be — no special-casing.

---

## Accessibility Expectations

- The Record Catch section exposes a semantic label combining species, weight, length, date, and location (each only when present) — not just decorative text — mirroring the accessibility requirement already established for catch information elsewhere in the application (MFS-011, MFS-014, MFS-020).
- Each Catch List row exposes the same semantic label `CatchListItem` already provides unmodified (MFS-014), unchanged by this milestone.
- Empty, loading, and error states are each conveyed accessibly, not only through visual presentation, consistent with the equivalent requirement in MFS-019/MFS-020.
- Tap targets and text throughout this milestone follow the application's existing Material 3 sizing and text-scaling conventions.

---

## Feature Ownership and Placement

Following the existing feature-first structure, Repository pattern, and database ownership rules (ADR-0001, ADR-0003, ADR-0006), this milestone extends the **Statistics** feature introduced by MFS-019 and extended by MFS-020; it does not introduce a new feature directory.

- The Statistics feature gains whatever presentation-only read models and read-only data access it needs to compute this page's content (a species' total, a Record Catch, and its full Catch List). It owns no new database table, column, or schema version.
- Consistent with every other repository in the Statistics feature, data access is a concrete, feature-owned, repository-based class — no service layer, no use-case layer, no DAO layer, and no repository interface are introduced, matching the architecture already established by `GeneralCatchStatisticsRepository` (MFS-020/TD-020) and `LureStatisticsRepository` (MFS-019/TD-019).
- Navigation reuses this application's existing patterns exactly: a manually pushed, full-screen page (the same mechanism already used for Catch Details and MFS-020's Top 3 Largest Catches navigation), not a new navigation paradigm.
- Presentation reuses existing UI components wherever one already fits — most notably `CatchListItem` (FR-6) — rather than introducing duplicate near-identical widgets, consistent with this project's "avoid unnecessary abstractions and duplication" rule.
- The `catches` feature (MFS-009), `catch_photos` feature (MFS-013), and `fishing_spots` feature (MFS-004) are read from, never modified.
- Exact implementation design — including data access, presentation widget breakdown, and file naming — is a Technical Design concern, out of scope for this specification.

---

## Acceptance Criteria

- Tapping a row in MFS-020's Species List opens the Species Statistics page for that species.
- The page's header shows the species name and the total number of catches of that species across the angler's entire catch history.
- A Record Catch section shows the angler's top-ranked catch of the species (per the ordering below), with photo, weight, length, and location shown only when available, and no broken UI when any are missing.
- A Catch List shows every catch of the selected species, using the existing `CatchListItem` widget unmodified.
- The Catch List — and, by extension, the Record Catch — is ordered by weight descending, then catch date descending, then catch id ascending, applied deterministically and unconditionally.
- A catch missing a photo, weight, length, or location renders cleanly at every point on this page, with no empty placeholder or broken layout.
- Selecting a Catch List entry opens the existing Catch Details view (MFS-014) for that specific catch.
- No new Drift table, column, schema version, or migration is introduced.
- The `catches`, `catch_photos`, and `fishing_spots` features are functionally and structurally unchanged by this milestone.
- Data access follows the existing repository-based architecture, with no service layer, use-case layer, DAO layer, or repository interface introduced.
- Navigation reuses this application's existing pushed-page pattern, consistent with Catch Details and MFS-020's Top 3 Largest Catches navigation.
- Loading and error states are shown clearly and distinctly from the empty and populated states.
- Every capability in this milestone works with no network connection.
- `flutter analyze` passes.
- Automated tests cover: total-count computation for a species, Record Catch selection (including a weight tie and the no-weight-recorded case), Catch List ordering (weight descending, date descending, id ascending, including ties), missing-field rendering (photo, weight, length, location, independently and in combination), Catch List navigation to Catch Details, and recomputation after a catch of that species is created, edited, or deleted.
- Physical Android testing is completed for this milestone.

---

## Out of Scope

- Charts or graphs of any kind
- Averages of any kind (including average weight or average length)
- Seasonal statistics
- Time-based/monthly/yearly statistics
- Lure statistics (unchanged, MFS-019 territory)
- Weather statistics
- Maps or any map-based presentation of catch location
- Filtering
- Searching
- Export of any kind
- Any new analytics beyond the total, Record Catch, and Catch List defined in this specification
- Editing or deleting catches (unchanged, MFS-012 territory)
- Any change to the `catches`, `catch_photos`, `fishing_spots`, `lure_catalog`, or `personal_tackle_box` domain models, database schemas, or repository contracts
- Any change to MFS-020's Catches tab or MFS-019's Lure Statistics tab
- Any persisted/stored statistic, cache, or aggregate table
- A service layer, use-case layer, DAO layer, or repository interface of any kind
- Cloud synchronization

---

## Relationship to Previous MFS Documents

- **MFS-009 (Catch Foundation)** established `Catch` as a framework-independent domain model. This milestone reads it read-only, exactly as MFS-019/MFS-020 already do.
- **MFS-011 (View Catches for Fishing Spot)** established the caught-at-descending ordering convention and per-catch information display this milestone's Catch List builds on, extended here with a weight-first ordering and scoped to one species across every fishing spot rather than one spot at a time.
- **MFS-013 (Catch Photos)** established the image-fallback and `sortOrder`-based "first photo" convention this milestone's Record Catch section reuses unchanged.
- **MFS-014 (Catch Details View)** established the read-only Catch Details view this milestone's Catch List opens as its navigation target, the `CatchListItem` widget this milestone's Catch List reuses unmodified, and the "missing optional value" rendering discipline this milestone also follows.
- **MFS-020 (General Catch Statistics)** introduced the Species List this milestone's rows now finally navigate from, deliberately leaving that navigation unimplemented and explicitly naming this milestone ("MFS-021 Candidate") as its own anticipated follow-up in its Conceptual Model, Accessibility Expectations, and Future Extensions sections. This milestone also reuses MFS-020's "resolve a catch's fishing spot" precedent (its Key Design Decision 1/2, TD-020) for this milestone's own catch-location resolution, and its "derived, not recomputed" relationship between a summary value and its underlying sorted list (applied here as Record Catch → Catch List).

---

## Dependencies

No new external dependencies are required. This milestone reuses the existing stack and patterns:

- Flutter, Dart
- Drift (read-only queries against existing tables, per ADR-0005)
- The existing Repository pattern and feature-first structure (ADR-0001, ADR-0003, ADR-0006)
- The existing `Catch` domain model (MFS-009), `CatchPhoto` domain model (MFS-013), and `FishingSpot` domain model (MFS-004), all read-only
- The existing `CatchListItem` widget (MFS-011/MFS-014), reused unmodified
- The existing Catch Details view (MFS-014), reused unmodified as this milestone's navigation target
- The Statistics feature's existing presentation conventions and read-only data access patterns already established by MFS-019/MFS-020

---

## Future Extensions

This milestone is expected to support, in later milestones:

- Average weight and average length for a species, if that proves useful once real statistics are in use (explicitly excluded from this milestone, unlike the earlier, unscoped roadmap sketch of this idea — see `docs/roadmap.md` §3.1).
- Filtering this page's Catch List (e.g. by date range or fishing spot).
- Seasonal or time-based breakdowns for a single species.
- A map-based presentation of where a species has been caught.
- Visual (chart/graph) presentation of the data this milestone introduces in list/card form.
