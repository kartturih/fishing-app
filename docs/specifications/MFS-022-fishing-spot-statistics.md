# MFS-022 — Fishing Spot Statistics

## Status

Implemented — architecture-reviewed, all automated tests passing (640/640), `flutter analyze` clean (8 pre-existing/accepted info-level lints, none introduced by this milestone), and physical Android verification completed. Two lifecycle bugs were found during physical Android testing and fixed: `CatchDetailsPage` could pop before its own in-flight delete completed if the user navigated away independently while it was running, and `GeneralCatchStatisticsTab` did not reload after returning from either Fishing Spot Statistics or Species Statistics, leaving its own totals/lists stale. Neither changed this document's functional requirements. See TD-022 for the technical design and its Implementation Notes for full detail, and `docs/project-status.md` for the verification record.

## Related

- Depends on: MFS-004 — Fishing Spot Foundation (the `FishingSpot` domain model this milestone reads)
- Depends on: MFS-008 — Delete Fishing Spot (cascading catch deletion this milestone must remain correct under)
- Depends on: MFS-009 — Catch Foundation
- Depends on: MFS-011 — View Catches for Fishing Spot (the existing, un-aggregated per-spot catch list this milestone's richer statistics sit alongside, not replace)
- Depends on: MFS-013 — Catch Photos (photo display, image-fallback convention)
- Depends on: MFS-014 — Catch Details View (the navigation target for this milestone's Catch List)
- Depends on: MFS-020 — General Catch Statistics (the Catches tab this milestone extends with a new Fishing Spot List, and whose Species List supplies the per-spot species breakdown pattern)
- Depends on: MFS-021 — Species Statistics (the direct architectural precedent this milestone's design deliberately mirrors: a pushed detail page with a header, a Record Catch section, and a full Catch List)
- Introduces: a new Fishing Spot List within the Catches tab, and a new, pushed Fishing Spot Statistics page reached from it — not a new tab

---

## Purpose

Let an angler see everything about their own catch history at one specific fishing spot: how many times they've fished it productively, their record catch there, which species they've caught there, and every individual catch at that spot, each opening the existing Catch Details view when selected.

This milestone completes the third natural grouping axis the Statistics feature has been built around — lure (MFS-019), species (MFS-021), and now fishing spot — reusing the exact "pushed detail page over a live, computed-on-open summary" shape MFS-021 already established, adapted for a fishing spot instead of a species.

Unlike MFS-021, which wired navigation onto an already-existing Species List (MFS-020 built the list but deliberately left it inert), no equivalent Fishing Spot List exists yet anywhere in the Statistics feature. This milestone therefore introduces that list as well as the detail page it opens — see [Conceptual Model](#a-new-fishing-spot-list-is-introduced-not-only-wired) and [Design Notes](#design-notes).

---

## User Value

Anglers can already see every catch logged at a fishing spot as a plain, unordered-by-size list (MFS-011's Fishing Spot Details bottom sheet), and can see catch history summarized by species (MFS-020/MFS-021) and by lure (MFS-019) — but nothing today answers a question the project charter's own Problem Statement names directly: **"How can I keep track of my best fishing spots?"**

This milestone answers that, for one spot at a time:

- What's the best catch I've ever made at this spot?
- How many fish have I caught here in total?
- When did I last fish at this location?
- Which species actually bite here?
- Every catch I've made at this spot, ordered from biggest to smallest?
- Can I see, at a glance across all my spots, which ones have actually produced?

---

## Scope

### In Scope

- A new **Fishing Spot List** section within the Catches tab (MFS-020), directly alongside its existing Top 3 Largest Catches and Species List sections: every fishing spot with at least one logged catch, and how many catches at that spot, sorted by catch count descending.
- A new, pushed **Fishing Spot Statistics** page, reached by tapping a Fishing Spot List row.
- A header showing the fishing spot name, the total number of catches at that spot, and the date of the most recent catch there.
- A **Record Catch** section prominently showing the angler's best catch at that spot — photo (if available), species, weight (if available), length (if available), and catch date.
- A **Species Breakdown** showing every species caught at that spot, with its catch count, sorted by catch count descending.
- A **Catch List** showing every catch at that spot, ordered by recorded weight descending, then catch date descending, then catch id ascending, reusing the existing `CatchListItem` widget unmodified.
- Selecting a Catch List entry, or the Record Catch section, opens the existing Catch Details view (MFS-014).
- Graceful handling of missing photo, weight, and length on any catch, including the Record Catch.
- Loading and error states.
- All values computed live from existing `Catch`/`CatchPhoto`/`FishingSpot` data — nothing is cached, stored, or persisted.

### Out of Scope

See [Out of Scope](#out-of-scope-1) for the complete list. Notably: editing or deleting fishing spots, map interaction, weather analysis, AI recommendations, charts, heatmaps, filtering/searching, exporting statistics, and any derived arithmetic aggregate (total weight, average weight, average length) — see [Conceptual Model](#evaluated-and-excluded-derived-aggregate-statistics) for why each of those was considered and rejected.

---

## User Stories

**As an angler**
I want to see at a glance which of my fishing spots have actually produced catches
So that I don't have to open each spot individually to find out.

**As an angler**
I want to see my record catch at a specific fishing spot
So that I can recall my best result there without scrolling through its full catch list.

**As an angler**
I want to see which species I've actually caught at a specific spot
So that I know what to expect or target the next time I fish there.

**As an angler**
I want to see every catch I've made at that spot, ordered from biggest to smallest
So that I can judge how productive the spot has really been.

**As an angler**
I want to open a catch's full details from either the record catch or the full list
So that I can see everything about it — photo, lure, exact date — the same way I already can elsewhere in this app.

**As an angler**
I want catches with a missing photo, weight, or length to still display cleanly
So that incomplete data never makes the page look broken.

---

## Conceptual Model

This section resolves the product-level questions this milestone must answer before Technical Design work begins, following the same discipline MFS-021's own Conceptual Model established. Exact query, repository, and widget design remain a Technical Design concern, not addressed here.

### A new Fishing Spot List is introduced, not only wired

MFS-021 was able to wire navigation onto a Species List that MFS-020 had already built and deliberately left inert. No equivalent list exists for fishing spots today — the Catches tab currently offers a Top 3 Largest Catches list and a Species List only. This milestone therefore both **introduces** a Fishing Spot List within the Catches tab and **wires** its navigation to the new Fishing Spot Statistics page, in the same milestone, rather than splitting that into two separate milestones the way Species Statistics was split from General Catch Statistics. There is no product reason to ship an inert Fishing Spot List first: unlike MFS-020's Species List (which anticipated a genuinely future, not-yet-decided follow-up), this milestone's own detail page is being specified at the same time as its entry point.

### The Fishing Spot List is intentionally lightweight — navigation, not analytics

The Fishing Spot List's purpose is to let the angler identify and choose a fishing spot to open Fishing Spot Statistics for — nothing more. Each row shows only the fishing spot's name and its catch count, the same two-field shape already established for the Species List (MFS-020); no record catch, no species preview, no date, and no other statistic belongs on the list itself. Any further detail belongs on the Fishing Spot Statistics page a row opens, not on the list that leads to it. This is a deliberate constraint: the moment the list itself starts previewing a spot's own statistics, it stops being a navigational entry point and starts duplicating the very page it exists to link to — the same discipline the Species List already models within the same Catches tab.

### Scoped to one fishing spot, across its entire catch history

This milestone looks at every catch logged at one specific fishing spot, regardless of when it was caught — the same "entire relevant history, not an arbitrary slice" scope MFS-021 already established for species, applied here to a single spot instead of a single species.

### Record Catch is the top-ranked entry of the Catch List, not a separately computed value

Exactly as MFS-021 established for species, the Record Catch is simply the first entry of the same deterministically ordered Catch List this milestone already produces — not a separately derived "best catch" computation. Because the Catch List includes every catch at the spot regardless of whether it has a recorded weight, the Record Catch may itself have no recorded weight, if none of the angler's catches at that spot do; in that case it is simply the most recently caught entry, displayed with its weight omitted like any other missing value, never withheld or treated as an error.

### Last Catch Date is a simple, independent derived value, not tied to the weight-based ordering

The header's Last Catch Date answers a narrow, concrete question: "When did I last fish at this location?" It is the most recent `caughtAt` among every catch logged at the fishing spot — a plain maximum over already-available data, not an arithmetic aggregate (no sum, no division) and not dependent on the Catch List's own weight-based ordering. Unlike the Record Catch, it does not need to identify one specific catch to link anywhere, so no tie-break question ever arises for it: two catches sharing the same date simply produce that one date. This keeps it structurally closer to "the most recently caught entry" the Record Catch's own ordering already falls back to when no catch has a recorded weight (see above) than to a new kind of computation this feature has not already relied on elsewhere. If the fishing spot has no catches, the value shows a clear "no data yet" state rather than a blank or misleading one.

### Record Catch shows species, not location

MFS-021's Record Catch showed the catch's fishing spot, because a species-scoped view spans every fishing spot and the location genuinely varies from catch to catch. This milestone is the mirror image: every catch on this page already shares the same fishing spot (the page's own context, shown once in the header), so repeating it on the Record Catch would be redundant. Species, conversely, is the field that now varies from catch to catch and is not otherwise implied by the page's context, so it is shown here in its place. This is a deliberate adaptation of MFS-021's pattern, not an oversight — see [Design Notes](#design-notes).

### Species Breakdown reuses the Species List pattern, rescoped to one fishing spot — and, like it, ships static

The Species Breakdown is the same "species paired with its catch count, sorted by catch count descending" pattern MFS-020 already established for its own, whole-history Species List — rescoped here to one fishing spot's catches only. Following MFS-020's own precedent for that list, Species Breakdown rows are presented using this application's existing selectable-row appearance but perform no navigation in this milestone and are not exposed to assistive technology as buttons. A future milestone could wire a Species Breakdown row to open Species Statistics (MFS-021) for that species — the same relationship MFS-021 itself was, one milestone ago, to MFS-020's own Species List. This milestone does not build that wiring; see [Future Extensions](#future-extensions).

### Deterministic ordering

The Catch List — and, by extension, the Record Catch, which is simply its first entry — is ordered by the exact rule MFS-021 already established for species-scoped statistics, reused unchanged here for fishing-spot-scoped statistics:

1. weight, **descending** (a catch with no recorded weight sorts after every catch that has one)
2. catch date, **descending**
3. catch id, **ascending** (a guaranteed-unique final tie-breaker)

The Species Breakdown is ordered by catch count descending, ties broken deterministically (by species identifier, the same stable tiebreak MFS-020 already established for its own Species List).

The Fishing Spot List is ordered by catch count descending, ties broken by fishing spot name (case-insensitive ascending), then by fishing spot id ascending as a guaranteed-unique final tiebreak. Unlike species (a fixed, closed set with a stable identifier), fishing spot names are angler-authored free text and are not guaranteed unique — two spots can share a display name — so a name-based tiebreak alone is not sufficient on its own and a final id-based tiebreak is required, the same shape already used for lure name tiebreaks in MFS-019.

As with every ordering rule already established elsewhere in this feature, these must be applied unconditionally, not only when a tie happens to be noticed.

### Missing data handling is per-field, not all-or-nothing

A catch's photo, weight, and length are each independently optional. Each is handled on its own: a catch missing one of these values still displays normally, showing every value it does have, with no broken layout, empty placeholder box, or blank line where the missing value would go — the same "missing optional value" discipline already used throughout this application (MFS-011, MFS-014, MFS-020, MFS-021), applied here per catch and per field.

### Evaluated and excluded: derived aggregate statistics

Several additional statistics were evaluated for this milestone. Two classes of them were deliberately excluded, to keep the page focused rather than becoming an analytics dashboard; a third, Last Catch Date, was reconsidered and included (see above) precisely because it does not fall into either excluded class.

- **Total recorded weight** and **average recorded weight/length** — every prior Statistics milestone in this project has drawn the same line: MFS-019 explicitly excluded average weight/length, and MFS-021 explicitly excluded "averages of any kind." Including a sum or average here, even though a fishing spot's "total yield" is an intuitively appealing number, would break a boundary this feature has held consistently three times already. Excluded for consistency; a legitimate future extension if real usage ever asks for it.
- **First catch date** — remains excluded, on reconsideration, precisely because it sits on the opposite side of the line Last Catch Date now sits on. Last Catch Date answers a currency question the angler can act on this week ("is this spot still worth going back to, and when did I last check"); First Catch Date only answers a historical curiosity ("how long have I been coming here") that changes no near-term fishing decision and does not appear anywhere in the project charter's own Problem Statement. It is also only visible today by scrolling the entire weight-ordered Catch List to its earliest-dated entry, unlike Last Catch Date, which cannot be read off the list without first re-sorting it by date. Excluded as marginal value for the page-focus cost; see [Future Extensions](#future-extensions).

None of these are permanent exclusions, but none of them clearly earn a place in this milestone's minimal, focused page the way Last Catch Date does.

### The fishing spot's identity is established when the page opens

The header's fishing spot name reflects the fishing spot as it was at the moment the page was opened, consistent with how MFS-021 receives its `species` value directly rather than re-resolving it. The page's statistics (total, Record Catch, Species Breakdown, Catch List) are always computed fresh, so if the underlying fishing spot's catches change while the page is open, the numbers reflect that on the next load — but the header itself does not need to re-resolve the fishing spot's own record to do so. See [Edge Cases](#edge-cases).

### No new stored data

This milestone introduces no new persisted statistic, cache, or aggregate of any kind, and no new database table, column, or migration. The fishing spot's total catch count, Record Catch, Species Breakdown, and full Catch List are all computed from existing `Catch`, `CatchPhoto`, and `FishingSpot` data each time the relevant page is opened — the same "computed live, never stored" discipline every prior Statistics milestone has already established.

---

## Functional Requirements

### FR-1 — Fishing Spot List

The Catches tab must show a Fishing Spot List: every fishing spot with at least one logged catch, and how many catches the angler has logged there, sorted by catch count descending with deterministic tie-breaking (per [Conceptual Model](#deterministic-ordering)). A fishing spot with no catches does not appear, mirroring MFS-020's own Species List precedent. The list is intentionally lightweight: a fishing spot's name and catch count are the only information shown per row. It exists to let the angler identify and choose a fishing spot, not to preview that spot's own statistics — see [Conceptual Model](#the-fishing-spot-list-is-intentionally-lightweight--navigation-not-analytics).

### FR-2 — Fishing Spot List Navigation

Tapping a row in the Fishing Spot List must open the Fishing Spot Statistics page for that specific fishing spot.

### FR-3 — Header

The Fishing Spot Statistics page must show the fishing spot's name, the total number of catches logged at that spot, and the date of the most recently caught catch logged there (see [Conceptual Model](#last-catch-date-is-a-simple-independent-derived-value-not-tied-to-the-weight-based-ordering)). If the fishing spot has no catches, the last-catch-date value shows a clear "no data yet" state rather than a blank or misleading value.

### FR-4 — Fishing-Spot-Scoped, Full History

Every value on the Fishing Spot Statistics page must reflect every catch logged at the selected fishing spot, for as long as that spot has existed, not a filtered or time-limited slice.

### FR-5 — Record Catch

The page must prominently show a Record Catch section representing the angler's top-ranked catch at the selected fishing spot, per the ordering defined in [FR-8](#fr-8--deterministic-catch-list-ordering). See [Conceptual Model](#record-catch-is-the-top-ranked-entry-of-the-catch-list-not-a-separately-computed-value) for why this may be a catch with no recorded weight.

### FR-6 — Record Catch Content

The Record Catch section may show: the catch's photo, if one exists (the first photo by `sortOrder`, per the existing image-fallback convention — MFS-013, MFS-014, MFS-021); species; weight, if recorded; length, if recorded; catch date. A missing photo, weight, or length must not leave an empty placeholder, broken layout, or blank line — per [Missing Data Handling](#missing-data-handling-is-per-field-not-all-or-nothing).

### FR-7 — Species Breakdown

The page must show every species caught at the selected fishing spot, with its catch count, sorted by catch count descending with deterministic tie-breaking. Rows are presented using this application's existing selectable-row appearance, signaling that navigation to species-specific statistics is a plausible future extension, without requiring a future restyle — but selecting a row in this milestone must have no effect whatsoever, and rows must not be exposed to assistive technology as buttons. See [Conceptual Model](#species-breakdown-reuses-the-species-list-pattern-rescoped-to-one-fishing-spot--and-like-it-ships-static).

### FR-8 — Deterministic Catch List Ordering

The Catch List must be ordered by weight descending, then catch date descending, then catch id ascending, exactly as specified in [Conceptual Model](#deterministic-ordering). This ordering must be applied unconditionally. The same ordering determines the Record Catch, per [FR-5](#fr-5--record-catch).

### FR-9 — Catch List

The page must show every catch at the selected fishing spot, below the Species Breakdown, reusing the existing `CatchListItem` widget (MFS-011/MFS-014/MFS-021) with no modification.

### FR-10 — Catch List and Record Catch Navigation

Selecting an entry in the Catch List, or the Record Catch section, must open the existing, unmodified Catch Details view (MFS-014) for that specific catch. This milestone does not change Catch Details in any way; it only adds two more entry points into it.

### FR-11 — Missing Data Handling

A catch anywhere on this page — in the Record Catch section or the Catch List — missing a photo, weight, or length must render cleanly, showing every value it does have with no broken or empty UI for the values it lacks.

### FR-12 — Computed Live, Never Stored

Every value this milestone displays — the Fishing Spot List, the header's total, the Record Catch, the Species Breakdown, and the Catch List — is computed at the moment the relevant view is opened, directly from existing `Catch`/`CatchPhoto`/`FishingSpot` data. No aggregate, ranking, or list is written to persistent storage anywhere.

### FR-13 — Offline Operation

Every capability in this milestone works with no network connection, consistent with the rest of the application.

---

## UI Expectations

- The Fishing Spot List follows the same plain, scrollable list presentation already used for the Species List and Top 3 Largest Catches within the Catches tab — not a chart, graph, or other visual data representation (explicitly out of scope). Each row shows only the fishing spot's name and its catch count; nothing that previews the destination page's own statistics.
- The Fishing Spot Statistics page follows the same general presentation shape MFS-021 already established: a header/summary area near the top, the Record Catch section prominently below it, then the Species Breakdown, then the full Catch List.
- The Species Breakdown and Catch List are simple, scrollable lists, consistent with the plain list presentation already used throughout this application.
- No search field, filter control, or sort control is shown anywhere in this milestone. Every list always shows its full, fixed order as defined in [Functional Requirements](#functional-requirements).
- All user-visible text is in Finnish, consistent with the application's existing UI text convention. Exact wording is a Technical Design/implementation concern, not specified here.
- The Fishing Spot List (within the Catches tab) and the Fishing Spot Statistics page are each recomputed whenever they become visible, so newly logged, edited, or deleted catches are reflected without any explicit refresh action — the same behavior already established for every other Statistics view.

---

## Navigation

```text
Statistics
  └── Catches (MFS-020)
        └── Fishing Spot List entry tapped → Fishing Spot Statistics (this milestone)
                └── Record Catch, or a Catch List entry, tapped → Catch Details (MFS-014, existing, unmodified)
```

Fishing Spot Statistics is a pushed, full-screen page reached from a Fishing Spot List row (FR-2) — the same navigation pattern already used for Catch Details and for Species Statistics (MFS-021), not a new tab of the Statistics feature. Selecting the Record Catch section or a Catch List entry opens the existing Catch Details view for that catch (FR-10); the exact navigation mechanism is a Technical Design concern. Selecting a Species Breakdown row performs no action in this milestone (FR-7).

---

## Data Ownership

- This milestone extends the existing **Statistics** feature (introduced by MFS-019, extended by MFS-020 and MFS-021); it does not introduce a new top-level feature directory.
- The Statistics feature reads existing `Catch` data (MFS-009), existing `CatchPhoto` data (MFS-013), and existing `FishingSpot` data (MFS-004) directly, read-only — the same reference-not-copy, read-only-across-feature-boundary pattern already established by MFS-019/MFS-020/MFS-021.
- The `catches`, `catch_photos`, and `fishing_spots` features remain entirely unmodified — no change to their domain models, database schemas, or repository contracts is required or permitted by this milestone.
- The Statistics feature never duplicates catch, photo, or fishing spot data. Every value displayed is resolved live from existing data; nothing is copied into a Statistics-owned record.
- Unlike MFS-021, this milestone does add new content to MFS-020's own Catches tab (the Fishing Spot List, FR-1) — a deliberate, in-scope extension of that tab, not an unrelated modification. MFS-020's existing Top 3 Largest Catches and Species List sections, and their underlying computation, are otherwise unchanged.

---

## Empty, Loading, and Error States

- **No fishing spot has any logged catches at all:** the Fishing Spot List shows a clear empty-state message rather than an empty-looking blank area, consistent with the equivalent state already handled for the Species List and Top 3 Largest Catches.
- **The selected fishing spot has no catches at the moment its page loads** (e.g. its only catch was deleted between the Fishing Spot List rendering and this page opening, or the fishing spot itself was deleted — see [Edge Cases](#edge-cases)): the header shows a total of 0 and a "no data yet" Last Catch Date, and the Record Catch section, Species Breakdown, and Catch List each show a clear, distinct empty-state message rather than an empty-looking blank area.
- **Loading:** while the Fishing Spot List or the Fishing Spot Statistics page's data is being computed, it shows a clear loading indicator, distinct from the empty and error states, consistent with the loading-state convention already established elsewhere in the Statistics feature.
- **Computation failure:** if reading or computing either the Fishing Spot List or the Fishing Spot Statistics page's data fails (e.g. a database read error), the affected view shows a clear error message and must not crash the application. The user can retry, consistent with the retry convention already established for every other Statistics view.

---

## Edge Cases

- A fishing spot caught at exactly once shows a header total of 1, a Record Catch equal to that single catch, a Species Breakdown with exactly one entry, and a Catch List containing exactly that one entry — a fully valid state, not a special case.
- Multiple catches at the fishing spot tied at the same weight resolve deterministically (FR-8) — the Catch List, and therefore the Record Catch, never show an ambiguous or randomly-varying result across app restarts.
- A fishing spot where no catch has a recorded weight still has a Record Catch (the most recently caught entry, per [Conceptual Model](#record-catch-is-the-top-ranked-entry-of-the-catch-list-not-a-separately-computed-value)), shown with its weight omitted.
- Two fishing spots sharing the same display name (fishing spot names are not required to be unique — ADR-0004/MFS-005) each appear as their own, independently correct entry in the Fishing Spot List and open their own correct Fishing Spot Statistics page; the list never merges or deduplicates entries by name.
- Deleting a catch (MFS-012) that was the fishing spot's Record Catch is reflected the next time the Fishing Spot Statistics page is opened — a different catch becomes the new Record Catch, or the page's lists become empty.
- Deleting the fishing spot itself (MFS-008) cascades the deletion of every catch logged there (existing foreign key behavior). If the Fishing Spot Statistics page for that spot happens to still be open when this occurs, its data reflects the resulting empty state the next time it is computed; the header continues to show the fishing spot's name as it was when the page was opened, per [Conceptual Model](#the-fishing-spots-identity-is-established-when-the-page-opens).
- Editing a catch's weight, species, or date (MFS-012) is reflected in this page's ordering, Record Catch, and Species Breakdown the next time it is opened.
- Editing a catch's fishing spot is not a supported operation anywhere in this application today; if that ever changes, this page's totals would simply reflect the catch's current fishing spot on the next load, the same way Species Statistics already handles a catch's species changing.

---

## Accessibility Expectations

- Each Fishing Spot List row exposes a semantic label combining the fishing spot's name and its catch count, and is exposed to assistive technology as a real, actionable button, since this milestone wires its navigation from the start (unlike MFS-020's original Species List, which shipped intentionally inert).
- The Record Catch section exposes a semantic label combining species, weight, length, and date (each only when present) — not just decorative text — mirroring the accessibility requirement already established for catch information elsewhere in the application (MFS-011, MFS-014, MFS-020, MFS-021).
- Each Catch List row exposes the same semantic label `CatchListItem` already provides unmodified (MFS-014), unchanged by this milestone.
- Each Species Breakdown row exposes a semantic label combining the species and its catch count, but — because navigation from it is a future extension, not delivered here (FR-7) — must not be exposed to assistive technology as a button or other actionable element, avoiding a dead-end affordance for screen reader users, the same discipline MFS-020 already applied to this exact row shape.
- Empty, loading, and error states are each conveyed accessibly, not only through visual presentation, consistent with the equivalent requirement in MFS-019/MFS-020/MFS-021.
- Tap targets and text throughout this milestone follow the application's existing Material 3 sizing and text-scaling conventions.

---

## Feature Ownership and Placement

Following the existing feature-first structure, Repository pattern, and database ownership rules (ADR-0001, ADR-0003, ADR-0004, ADR-0006), this milestone extends the **Statistics** feature introduced by MFS-019 and extended by MFS-020/MFS-021; it does not introduce a new feature directory.

- The Statistics feature gains whatever presentation-only read models and read-only data access it needs to compute the Fishing Spot List and the Fishing Spot Statistics page's content. It owns no new database table, column, or schema version.
- Consistent with every other repository in the Statistics feature, data access is concrete and repository-based — no service layer, no use-case layer, no DAO layer, and no repository interface are introduced.
- Navigation reuses this application's existing patterns exactly: a manually pushed, full-screen page (the same mechanism already used for Catch Details and Species Statistics), not a new navigation paradigm.
- Presentation reuses existing UI components wherever one already fits — most notably `CatchListItem` (FR-9) — rather than introducing duplicate near-identical widgets.
- The `catches` feature (MFS-009), `catch_photos` feature (MFS-013), and `fishing_spots` feature (MFS-004) are read from, never modified.
- Exact implementation design — including data access, presentation widget breakdown, and file naming — is a Technical Design concern, out of scope for this specification.

---

## Acceptance Criteria

- The Catches tab shows a Fishing Spot List: every fishing spot with at least one logged catch, with its catch count, sorted by catch count descending with deterministic tie-breaking; a fishing spot with no catches does not appear.
- Each Fishing Spot List row shows only the fishing spot's name and its catch count — no other statistic (record catch, species, date, or anything else) is shown on the list itself.
- Tapping a row in the Fishing Spot List opens the Fishing Spot Statistics page for that specific fishing spot.
- The page's header shows the fishing spot's name, the total number of catches logged there, and the date of the most recent catch there, with a clear "no data yet" state for the last-catch-date value when the fishing spot has no catches.
- A Record Catch section shows the top-ranked catch at the fishing spot (per the ordering below), with photo, species, weight, and length shown only when available, and no broken UI when any are missing.
- A Species Breakdown shows every species caught at the fishing spot, with its catch count, sorted by catch count descending with deterministic tie-breaking; rows perform no action when tapped and are not exposed to assistive technology as buttons.
- A Catch List shows every catch at the fishing spot, using the existing `CatchListItem` widget unmodified.
- The Catch List — and, by extension, the Record Catch — is ordered by weight descending, then catch date descending, then catch id ascending, applied deterministically and unconditionally.
- A catch missing a photo, weight, or length renders cleanly at every point on this page, with no empty placeholder or broken layout.
- Selecting the Record Catch section, or a Catch List entry, opens the existing Catch Details view (MFS-014) for that specific catch.
- No total, average, or other derived arithmetic aggregate (weight or length) is shown anywhere in this milestone.
- No new Drift table, column, schema version, or migration is introduced.
- The `catches`, `catch_photos`, and `fishing_spots` features are functionally and structurally unchanged by this milestone; MFS-020's existing Top 3 Largest Catches and Species List sections are functionally unchanged.
- Data access follows the existing repository-based architecture, with no service layer, use-case layer, DAO layer, or repository interface introduced.
- Navigation reuses this application's existing pushed-page pattern, consistent with Catch Details and Species Statistics.
- Loading and error states are shown clearly and distinctly from the empty and populated states, for both the Fishing Spot List and the Fishing Spot Statistics page.
- Every capability in this milestone works with no network connection.
- `flutter analyze` passes.
- Automated tests cover: Fishing Spot List content, sort order, and zero-catch exclusion; Fishing Spot List navigation to the correct fishing spot; total-count computation for a fishing spot; Last Catch Date computation (including the no-catches "no data yet" case); Record Catch selection (including a weight tie and the no-weight-recorded case); Catch List ordering (weight descending, date descending, id ascending, including ties); Species Breakdown aggregation, sort order, and no-action-on-tap behavior; missing-field rendering (photo, weight, length, independently and in combination); Catch List and Record Catch navigation to Catch Details; and recomputation after a catch at that fishing spot is created, edited, or deleted.
- Physical Android testing is completed for this milestone.

---

## Out of Scope

- Editing fishing spots (unchanged, MFS-007 territory)
- Deleting fishing spots (unchanged, MFS-008 territory)
- Map interaction of any kind (no map preview, no marker linking, no location display beyond the fishing spot's own name)
- Weather analysis or any environmental data
- AI recommendations of any kind
- Charts or graphs of any kind
- Heatmaps
- Filtering
- Searching
- Exporting statistics of any kind
- Total recorded weight, average recorded weight, or average recorded length (see [Conceptual Model](#evaluated-and-excluded-derived-aggregate-statistics) — not a permanent rule, just not part of this milestone)
- First catch date (see [Conceptual Model](#evaluated-and-excluded-derived-aggregate-statistics) — considered, not included; Last Catch Date, its more actionable sibling, is included — see [FR-3](#fr-3--header))
- Navigation from a Species Breakdown row to any destination (a plausible future extension, not this milestone)
- A dedicated per-species detail view scoped to one fishing spot
- Lure statistics of any kind (unchanged, MFS-019 territory)
- Any change to MFS-020's Top 3 Largest Catches list, its Species List, or MFS-021's Species Statistics page
- Any change to the `catches`, `catch_photos`, `fishing_spots`, `lure_catalog`, or `personal_tackle_box` domain models, database schemas, or repository contracts
- Any persisted/stored statistic, cache, or aggregate table
- A service layer, use-case layer, DAO layer, or repository interface of any kind
- Cloud synchronization

---

## Relationship to Previous MFS Documents

- **MFS-004 (Fishing Spot Foundation)** established `FishingSpot` as a framework-independent domain model. This milestone reads it read-only, exactly as MFS-020/MFS-021 already read `Catch`/`FishingSpot` data.
- **MFS-008 (Delete Fishing Spot)** established that deleting a fishing spot cascades deletion of every catch logged there. This milestone's Edge Cases rely on that existing, unmodified behavior to remain correct when a fishing spot disappears out from under its own Statistics page.
- **MFS-011 (View Catches for Fishing Spot)** established the first, un-aggregated per-fishing-spot catch list. This milestone is the analytical counterpart to it — the same underlying data, now totaled, ranked, and broken down by species — and does not replace or modify MFS-011's own bottom-sheet list.
- **MFS-013 (Catch Photos)** established the image-fallback and `sortOrder`-based "first photo" convention this milestone's Record Catch section reuses unchanged.
- **MFS-014 (Catch Details View)** established the read-only Catch Details view this milestone's Record Catch and Catch List open as their navigation target, the `CatchListItem` widget this milestone's Catch List reuses unmodified, and the "missing optional value" rendering discipline this milestone also follows.
- **MFS-020 (General Catch Statistics)** established the Catches tab's Species List pattern this milestone's Species Breakdown directly reuses, rescoped to one fishing spot, and is the tab this milestone extends with a new Fishing Spot List section.
- **MFS-021 (Species Statistics)** is this milestone's direct architectural precedent: the "pushed page, header, Record Catch derived from an already-sorted Catch List, full Catch List reusing `CatchListItem`" shape is reused deliberately, adapted (not copied) for a fishing spot instead of a species — see [Design Notes](#design-notes) for exactly how it was adapted.

---

## Dependencies

No new external dependencies are required. This milestone reuses the existing stack and patterns:

- Flutter, Dart
- Drift (read-only queries against existing tables, per ADR-0005)
- The existing Repository pattern and feature-first structure (ADR-0001, ADR-0003, ADR-0004, ADR-0006)
- The existing `Catch` domain model (MFS-009), `CatchPhoto` domain model (MFS-013), and `FishingSpot` domain model (MFS-004), all read-only
- The existing `CatchListItem` widget (MFS-011/MFS-014/MFS-021), reused unmodified
- The existing Catch Details view (MFS-014), reused unmodified as this milestone's navigation target
- The Statistics feature's existing presentation conventions and read-only data access patterns already established by MFS-019/MFS-020/MFS-021

---

## Future Extensions

This milestone is expected to support, in later milestones:

- Wiring a Species Breakdown row to open Species Statistics (MFS-021) for that species — the same relationship MFS-021 itself was to MFS-020's Species List one milestone ago.
- Total recorded weight, average recorded weight, and average recorded length for a fishing spot, if real usage ever shows they're worth the exception to this feature's consistent no-averages precedent (see [Conceptual Model](#evaluated-and-excluded-derived-aggregate-statistics)).
- First catch date, if real usage shows it answers a question anglers actually have.
- Filtering this page's Catch List (e.g. by date range or species).
- A map preview showing the fishing spot's location from within its own Statistics page.
- Visual (chart/graph) presentation of the data this milestone introduces in list/card form.

---

## Design Notes

This section explains where this specification deliberately departs from a literal copy of MFS-021, and why.

**The Fishing Spot List had to be designed, not assumed.** The task that produced this document described a user flow of "General Catch Statistics → Fishing Spot List → Fishing Spot Statistics," treating a Fishing Spot List as if it already existed the way MFS-020's Species List did before MFS-021. It does not — nothing in the current Catches tab groups or counts catches by fishing spot today. Rather than silently assuming otherwise, this specification explicitly scopes the Fishing Spot List's introduction into MFS-022 itself (FR-1/FR-2), and calls out in [Data Ownership](#data-ownership) that this makes MFS-022's touch on MFS-020's Catches tab meaningfully bigger than MFS-021's was (MFS-021 only added an `onTap` to an already-existing row; MFS-022 adds an entire new section). This is a legitimate, in-scope extension, not an accidental scope creep — but it's different enough from MFS-021's shape that it deserved to be named explicitly rather than left for a Technical Design to discover and reconcile after the fact (which is exactly what happened with MFS-021/TD-021's own Out-of-Scope wording, and this document tries not to repeat that ambiguity).

**Record Catch shows species instead of location.** A mechanical copy of MFS-021's Record Catch fields (photo, weight, length, date, location) would put "fishing spot" on a page whose entire context is already one fishing spot — pure redundancy. Species is the field that actually varies from catch to catch on this page and isn't otherwise implied, so it takes location's place. This is the clearest example in this document of "adapt, don't copy."

**All five originally-evaluated candidate statistics (first/latest catch date, total weight, average weight, average length) were considered explicitly, not silently omitted — and one of them, Last Catch Date, was reconsidered and moved into scope after review.** The three arithmetic aggregates (total weight, average weight, average length) stay excluded: they would break a no-averages boundary this feature has now held across three consecutive milestones (MFS-019, MFS-020, MFS-021), and nothing about this milestone earns an exception to it. First Catch Date also stays excluded, on the sharpened reasoning in [Conceptual Model](#evaluated-and-excluded-derived-aggregate-statistics): it answers a historical curiosity, not a decision. Last Catch Date, however, was re-examined on review and judged to clear the bar the others don't: it is a plain maximum over data already being read, not an arithmetic aggregate; it answers a concrete, day-to-day question ("when did I last fish here") the mandatory Catch List cannot answer without first re-sorting it by date; and displaying one additional date string alongside the existing total-catches value does not meaningfully add UI complexity — it follows the same two-value header shape MFS-020's own Catches tab already established (total catches, most caught species, shown side by side). Reconsidering it, rather than treating the original exclusion as final, produced a better-scoped milestone than the first draft did.

**Species Breakdown ships static, mirroring MFS-020's own original choice for its Species List, not MFS-021's later, wired one.** It would have been easy to make Species Breakdown rows tappable immediately, opening Species Statistics (MFS-021) for that species. This was deliberately not done: doing so would mean this single milestone introduces a second new cross-page navigation relationship (Fishing Spot Statistics → Species Statistics) in addition to everything else already in scope, and Species Statistics was itself intentionally shipped one milestone after the list it now animates. The same discipline applies here — the row is designed to make that future wiring an easy follow-up, not to force it into this milestone.

**The Fishing Spot List's own tie-break differs from the Species List's.** Species is a closed, stable enum, so MFS-020's Species List could simply break ties by the species' own identifier. Fishing spot names are angler-authored free text with no uniqueness guarantee (confirmed in ADR-0004/`fishing_spots` schema — nothing enforces a unique name), so this specification instead orders by name (case-insensitive) with a guaranteed-unique id as the final tiebreak — the same shape MFS-019 already used for lure name ties, not the shape MFS-020 used for species.

**The Fishing Spot List stays deliberately minimal — name and catch count only** (see [Conceptual Model](#the-fishing-spot-list-is-intentionally-lightweight--navigation-not-analytics)). It would be easy, once a fishing spot's own statistics exist on the page it links to, to start surfacing a preview of them (a record catch thumbnail, a top species) directly on the list row. This specification deliberately rules that out: the list's only job is letting the angler identify and choose a fishing spot, exactly mirroring the Species List's own two-field shape (MFS-020) — any richer per-row preview would blur the line between "an index" and "a second, smaller statistics page," which is a distinction worth protecting explicitly rather than letting erode gradually.

**This page intentionally leaves room for future enhancement, deliberately deferred rather than built now.** A tappable Species Breakdown linking to Species Statistics (MFS-021), additional statistics beyond this milestone's mandatory items and Last Catch Date, charts or graphs, and broader analytics of any kind are all plausible, natural extensions of this page — but building any of them now would be exactly the kind of scope creep this specification, and its three Statistics predecessors (MFS-019, MFS-020, MFS-021), have consistently avoided. Keeping MFS-022 focused on a minimal, clearly useful set of statistics, with well-defined seams for later growth (see [Future Extensions](#future-extensions)), is itself a deliberate design choice, not an oversight, and is what keeps the Statistics feature's four milestones reading as one consistent product rather than four differently-scoped experiments.
