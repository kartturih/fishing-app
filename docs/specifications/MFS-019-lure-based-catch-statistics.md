# MFS-019 — Lure-Based Catch Statistics

## Status

Implemented — architecture-reviewed, all automated tests passing, `flutter analyze` clean, and physical Android verification completed, including one post-testing presentation refinement (the original three-card summary row replaced with two full-width ranking cards). See TD-019 for the technical design and `docs/project-status.md` for the verification record.

## Related

- Depends on: MFS-009 — Catch Foundation
- Depends on: MFS-015 — Lure Catalog Foundation
- Depends on: MFS-016 — Personal Tackle Box Foundation
- Depends on: MFS-017 — Assign Lure to Catch (the `Catch → LureVariant` reference this milestone reads)
- Related: MFS-018 — Lure Catalog UX Improvements (no dependency; referenced only for its model-grouped browsing precedent, not reused here)
- Introduces: the new **Statistics** feature, with this milestone delivering its first tab, Lure Statistics
- Future: General Catch / Fishing Statistics (see `docs/roadmap.md` §3.3) is expected to become a second tab of the same Statistics feature, not a separate one

---

## Purpose

Let an angler see, at a glance, which of their own lures have actually produced catches — without introducing any new persisted data. This milestone reads the reference MFS-017 created (`Catch.lureVariantId`) and the catalog data MFS-015/MFS-016 already expose, and presents it as read-only, computed-on-demand statistics.

This is the first delivery under the new **Statistics** feature. The feature is intentionally structured to hold more than one tab over time (see `docs/roadmap.md` §3.3, General Catch / Fishing Statistics), but this milestone scopes and ships exactly one: **Lure Statistics**.

---

## User Value

Anglers have been able to log catches (MFS-009–MFS-014), track owned lures (MFS-015/016), and link a catch to the lure that caught it (MFS-017) as three separate capabilities. This milestone is the first to look back across that accumulated history and answer a question none of the previous milestones could:

- Which lure has actually caught the most fish?
- Which type of lure — jerkbait, spoon, jig, and so on — has been the most productive overall?
- For each lure that has caught something, how many catches does it account for?

MFS-016's own Future Extensions section named this outcome directly: "lure-based catch statistics ... built on top of the Personal Tackle Box." This milestone delivers exactly that, at MVP scope.

---

## Scope

### In Scope

- A new **Statistics** feature, accessible from the application UI (see [Navigation](#navigation)).
- The feature's first tab: **Lure Statistics**.
- Three summary cards: total catches linked to a lure, the most successful lure, and the most successful lure type.
- A list of lures, each showing photo (if available), name, color, lure type, and catch count, sorted by catch count descending. The initial implementation may limit this list to lures with recorded catches (see [FR-6](#fr-6--lure-list)).
- A breakdown of catch count per lure type.
- All of the above computed live from existing `Catch`, Lure Catalog, and (indirectly, via the catch reference) Personal Tackle Box data — nothing here is stored as a separate aggregate.

### Out of Scope

See [Out of Scope](#out-of-scope-1) for the complete list. Notably: graphs/charts, filters, percentages, average weight, average length, biggest fish, seasonal/time-based statistics, water and weather statistics, export, comparison features, and any change to the `catches`, `lure_catalog`, or `personal_tackle_box` domain models, database schemas, or repository contracts.

---

## User Stories

**As an angler**
I want to see which of my lures has caught the most fish
So that I know what has actually been working for me.

**As an angler**
I want to see which type of lure has been most productive overall
So that I can think about technique, not just one specific product.

**As an angler**
I want to see a list of every lure that has caught something, with how many catches each one has
So that I can compare my own lures against each other at a glance.

**As an angler**
I want these statistics to update automatically as I log more catches
So that I never have to remember to refresh or recalculate anything myself.

**As an angler**
I want to see a clear, honest empty state if I haven't linked any catches to a lure yet
So that I understand why the screen has nothing to show, instead of it looking broken.

---

## Conceptual Model

This section resolves the product-level questions this milestone must answer before any Technical Design work begins. It deliberately mirrors how MFS-017's Conceptual Relationship section resolved its own open question — exact query and aggregation implementation remain a Technical Design concern, not addressed here.

### Computed from catch history, not from current tackle box contents

Lure statistics are computed from existing `Catch` rows that have a non-null `lureVariantId` (MFS-017), resolved against the Lure Catalog (MFS-015) for display. They are **not** filtered by, or limited to, what currently sits in the Personal Tackle Box.

This follows directly from MFS-017 FR-6 (Historical Stability): removing a `TackleBoxEntry` must never alter, hide, or invalidate a catch that already referenced its `LureVariant`. If lure statistics excluded a lure the moment it left the tackle box, that guarantee would be silently broken one screen away. A lure the angler no longer owns, but that caught fish in the past, must continue to appear in these statistics exactly as it did before it was removed.

### Granularity: the catalog variant, not the model

A "lure" in this milestone's statistics is a specific `LureVariant` (the same granularity `Catch.lureVariantId` already references, per MFS-017's Conceptual Relationship) — not a `LureModel` grouped across all its colors. Two different colors of the same model are counted, listed, and ranked as two separate lures. This is a deliberate difference from MFS-018's browsing-list grouping (which groups by model for scannability); this milestone counts catches against the exact physical item a catch was attributed to, and a color is part of that identity.

### No new stored data

This milestone introduces **no new persisted statistic, cache, or aggregate of any kind**. Statistics are computed from existing persisted data — the `Catch` and Lure Catalog data already owned by MFS-009, MFS-015, and MFS-017 — each time they are viewed. If catch or lure data changes, the next time this screen is opened it reflects that change automatically, because nothing is cached or snapshotted. This is the same "resolved live, never stored" discipline already established for lure metadata shown anywhere in the Personal Tackle Box (MFS-016) and Catches (MFS-017) features, extended here to counts and rankings rather than individual field values.

### Deterministic ranking

"Most successful lure" and "most successful lure type" must each resolve to a single answer. Results shall be deterministic when multiple lure variants or lure types share the same catch count — the same underlying data must always produce the same displayed result. The specific tie-breaking strategy is a Technical Design (TD-019) concern and is not defined in this specification.

---

## Functional Requirements

### FR-1 — New Statistics Feature

A new, independent Statistics feature is introduced. It owns no data of its own beyond what is required to compute and present its tabs; in this milestone, no persisted data at all (see [Conceptual Model](#conceptual-model)).

### FR-2 — Lure Statistics Tab

The Statistics feature's screen is a tabbed presentation, structured to accommodate additional tabs in later milestones (see `docs/roadmap.md` §3.3). This milestone implements exactly one tab: **Lure Statistics**.

### FR-3 — Total Catches Linked to a Lure

A summary card shows the total number of catches that have a non-null assigned lure (`Catch.lureVariantId`), regardless of whether that specific lure reference can currently be resolved (see [FR-10](#fr-10--unresolvable-lure-references)).

### FR-4 — Most Successful Lure

A summary card shows the single lure (catalog variant) with the highest catch count among all catches with a resolvable assigned lure, together with that count. This is the top-ranked entry of the list defined in [FR-6](#fr-6--lure-list). Ties are broken per [Conceptual Model](#deterministic-ranking).

### FR-5 — Most Successful Lure Type

A summary card shows the single lure type with the highest total catch count across all its variants and models, together with that count. This is the top-ranked entry of the breakdown defined in [FR-7](#fr-7--lure-type-statistics). Ties are broken per [Conceptual Model](#deterministic-ranking).

### FR-6 — Lure List

A list shows lures (catalog variants), each row showing:

- the variant's photo, using the same image-fallback behavior already established for a lure's display elsewhere in the application (variant image, then model default image, then a neutral placeholder — MFS-015/MFS-016),
- the lure's name (manufacturer and model),
- the lure's color/variant-distinguishing detail,
- the lure's type (Finnish display label, per the existing `lure_type_labels` mapping — MFS-015),
- the number of catches attributed to that specific lure.

The list is sorted by catch count descending, with ties broken deterministically per [Conceptual Model](#deterministic-ranking). The initial implementation may limit this list to lure variants with at least one recorded catch — this is a catch-history view, distinct from the tackle box and catalog browsing views that already exist (MFS-015/MFS-016) and are unchanged by this milestone. This is not a permanent product rule: a future version may optionally also include lure variants that have not yet produced a catch (see [Future Extensions](#future-extensions)).

### FR-7 — Lure Type Statistics

A breakdown shows, for every lure type that has at least one resolvable catch attributed to it, the total number of catches across all lures of that type. This is aggregated at the lure-type level (a `LureModel`-level field, shared by every variant of that model — MFS-015), not per individual lure. The breakdown is sorted by catch count descending, with ties broken deterministically per [Conceptual Model](#deterministic-ranking).

### FR-8 — Computed Live, Never Stored

Every value shown by this milestone — the three summary cards, the lure list, and the lure type breakdown — is computed at the moment the screen is opened (or refreshed), directly from existing Catch and Lure Catalog data. No aggregate, count, or ranking is written to persistent storage anywhere.

### FR-9 — Statistics Reflect Full Catch History, Not Current Ownership

A lure's catch statistics are unaffected by whether that lure is still present in the Personal Tackle Box. Removing a `TackleBoxEntry` (MFS-016 FR-8) must not remove, hide, or alter the catch count attributed to the `LureVariant` it referenced, consistent with the historical stability principle already established by MFS-017 FR-6.

### FR-10 — Unresolvable Lure References

A catch whose assigned `lureVariantId` cannot be resolved against the Lure Catalog at all (an unexpected data-integrity condition, not ordinary catalog retirement — see MFS-017's own equivalent edge case) counts toward the total in [FR-3](#fr-3--total-catches-linked-to-a-lure), but is excluded from the lure list ([FR-6](#fr-6--lure-list)) and the lure type breakdown ([FR-7](#fr-7--lure-type-statistics)), since it cannot be attributed to a specific lure or lure type. This must never crash or block the rest of the screen from rendering.

### FR-11 — Retired Catalog Variants Are Counted Normally

A catch assigned to a `LureVariant` that has since been retired from the actively presented catalog (MFS-015's retirement mechanism) is counted exactly like any other resolvable catch — in the total, in the lure list, and in the lure type breakdown. Retirement is a catalog-presentation concept (MFS-015) with no bearing on catch history, consistent with how a retired variant already remains fully resolvable in Catch Details (MFS-017 FR-7).

### FR-12 — Offline Operation

Every capability in this milestone works with no network connection, consistent with the rest of the application.

---

## UI Expectations

- The Statistics screen presents its tabs using a tabbed presentation, consistent with how multi-view screens are already presented elsewhere in the application. Both the current Lure Statistics tab and the future General Catch Statistics tab (`docs/roadmap.md` §3.3) are Statistics-feature concepts, not a meeting point of two otherwise-unrelated features.
- The three summary cards are presented prominently at the top of the Lure Statistics tab, above the lure list and lure type breakdown, using the application's existing Material 3 card conventions.
- The lure list and lure type breakdown are simple, scrollable lists — consistent with the plain list presentation already used throughout the application (Lure Catalog, Personal Tackle Box) — not a chart, graph, or other visual data representation (explicitly out of scope, see [Out of Scope](#out-of-scope-1)).
- No search field, filter control, or sort control is shown. The lure list and lure type breakdown always show their full, fixed sort order (catch count descending).
- All user-visible text is in Finnish, consistent with the application's existing UI text convention, including the lure type display labels (already Finnish, per `lure_type_labels` — MFS-015).
- Statistics are recomputed whenever the tab becomes visible (initial open, and returning to it), so newly logged or edited catches are reflected without requiring the user to take any explicit refresh action.

---

## Navigation

The Statistics feature shall be accessible from the application UI.

```text
Statistics
  ├── Lure Statistics (this milestone)
  └── (future tabs, e.g. General Catch Statistics — not part of this milestone)
```

Opening the Statistics screen always opens directly to the Lure Statistics tab in this milestone, since it is the only tab that exists. The exact entry point through which the Statistics feature is reached is a Technical Design (TD-019) concern.

---

## Data Ownership

- A new **Statistics** feature is introduced. Statistics are computed from existing persisted data (see [Conceptual Model](#no-new-stored-data)) — this milestone introduces no new persisted data of its own.
- The Statistics feature reads existing Catch data (MFS-009/MFS-017) and existing Lure Catalog data (MFS-015). It never writes to either.
- The Catches, Lure Catalog, and Personal Tackle Box features remain entirely unmodified — no change to their domain models, database schemas, or repository contracts is required or permitted by this milestone.
- The Statistics feature never duplicates catch or catalog data. Every value displayed is resolved live from existing data; nothing is copied into a Statistics-owned record.

---

## Empty, Loading, and Error States

- **No catches have an assigned lure yet:** the three summary cards show a clear "no data yet" state (not zero-as-if-computed, but an explicit message that no catches have been linked to a lure), and the lure list and lure type breakdown each show a clear empty-state message rather than an empty-looking blank list. This is a normal, expected state for a new user, or a user who has not yet used MFS-017's lure-assignment feature.
- **Loading:** while statistics are being computed, the tab shows a clear loading indicator, distinct from the empty and error states, consistent with loading-state conventions already used throughout the application.
- **Computation failure:** if reading or computing statistics fails (e.g. a database read error), the tab shows a clear error message and must not crash the application. The user can retry (e.g. by reopening the tab or an explicit retry action).
- **A resolvable total with an empty breakdown (should not occur):** if catches exist with a non-null `lureVariantId` but every one of them is unresolvable ([FR-10](#fr-10--unresolvable-lure-references)), the total summary card still shows a nonzero count, while the "most successful lure," "most successful lure type," lure list, and lure type breakdown all show their empty state rather than crashing or showing misleading zero-catch entries.

---

## Edge Cases

- A lure assigned to exactly one catch appears in the lure list with a catch count of 1; it is a fully valid entry, not a special case.
- Multiple lures or lure types tied for the highest catch count resolve deterministically (see [Conceptual Model](#deterministic-ranking)) — the summary cards never show an ambiguous or randomly-varying result across app restarts.
- Removing a `TackleBoxEntry` for a lure that has produced catches does not change that lure's catch count, its position in the lure list, or its contribution to its lure type's total ([FR-9](#fr-9--statistics-reflect-full-catch-history-not-current-ownership)).
- A `LureVariant` retired from the catalog after producing catches continues to appear in the lure list and lure type breakdown exactly as before retirement ([FR-11](#fr-11--retired-catalog-variants-are-counted-normally)).
- Deleting a catch (MFS-012) that had an assigned lure reduces that lure's catch count (and its lure type's total) the next time statistics are computed; it has no effect on the Personal Tackle Box or Lure Catalog, consistent with existing catch-deletion behavior (MFS-012, MFS-017).
- Changing a catch's assigned lure (MFS-017 FR-3) moves that catch's contribution from the old lure/lure type to the new one the next time statistics are computed.
- A catch with no assigned lure never contributes to any part of this milestone's statistics, consistent with it not being "linked to a lure" ([FR-3](#fr-3--total-catches-linked-to-a-lure)).

---

## Accessibility Expectations

- Each summary card exposes a semantic label combining its title and value (e.g. "Onnistunein viehe: Rapala X-Rap 10, Firetiger, 7 saalista") — not just decorative text — mirroring the accessibility requirement already established for lure information elsewhere in the application (MFS-015/016/017).
- Each row in the lure list exposes a semantic label combining manufacturer, model, color/variant detail, lure type, and catch count.
- Each row in the lure type breakdown exposes a semantic label combining the lure type's display name and its catch count.
- Empty, loading, and error states are each conveyed accessibly, not only through visual presentation, consistent with the equivalent requirement in MFS-016/017.
- Tap targets and text throughout this milestone follow the application's existing Material 3 sizing and text-scaling conventions.

---

## Feature Ownership and Placement

Following the existing feature-first structure and database ownership rules (ADR-0001, ADR-0003, ADR-0006), Statistics is introduced as its own, new feature:

```text
lib/
└── features/
    └── statistics/
        ├── data/
        ├── domain/
        └── presentation/
            └── widgets/
```

- The Statistics feature owns whatever presentation-only read models it needs to display its statistics (e.g. a lure paired with its catch count, a lure type paired with its catch count). It introduces no new database table.
- The `catches` feature (MFS-009/MFS-017) and `lure_catalog` feature (MFS-015) are read from, never modified. The `personal_tackle_box` feature is not read from directly by this milestone (statistics are computed from catch history, not tackle box contents — see [Conceptual Model](#computed-from-catch-history-not-from-current-tackle-box-contents)).
- Exact implementation design — including data access, presentation widget breakdown, and file naming — is a Technical Design concern, out of scope for this specification.

---

## Acceptance Criteria

- A new Statistics feature exists, reachable from the application's navigation, structured to support more than one tab.
- The Lure Statistics tab is the first and, in this milestone, only tab shown.
- A summary card shows the total number of catches with a non-null assigned lure.
- A summary card shows the single most successful lure (by catch count) and its count, with deterministic tie-breaking.
- A summary card shows the single most successful lure type (by aggregate catch count) and its count, with deterministic tie-breaking.
- A list shows every lure with at least one resolvable catch, each with photo (if available), name, color, lure type, and catch count, sorted by catch count descending.
- A breakdown shows catch count per lure type, sorted by catch count descending.
- No graph, chart, percentage, average, filter, or export control is shown anywhere in this milestone.
- Statistics reflect the full catch history, including catches assigned to lures later removed from the Personal Tackle Box or retired from the Lure Catalog.
- A catch with no assigned lure never contributes to any statistic in this milestone.
- Deleting a catch, or changing/removing its assigned lure, is reflected in these statistics the next time the tab is computed.
- No new Drift table, schema version, or migration is introduced.
- The `catches`, `lure_catalog`, and `personal_tackle_box` features are functionally and structurally unchanged by this milestone.
- The empty state (no catches linked to a lure yet) renders clearly and distinctly from loading and error states.
- Every capability in this milestone works with no network connection.
- `flutter analyze` passes.
- Automated tests cover: total-count computation, most-successful-lure and most-successful-lure-type ranking (including a tie), the lure list's sort order and zero-catch exclusion, the lure type breakdown's aggregation and sort order, historical stability after tackle box removal, retired-variant inclusion, and unresolvable-lure-reference handling.

---

## Out of Scope

- Graphs or charts of any kind
- Filters (by date, species, fishing spot, or anything else)
- Percentages of any kind
- Average weight
- Average length
- Biggest fish (by weight or length)
- Seasonal statistics
- Water statistics
- Weather statistics
- Time-based statistics (trends over time, catches per month/year, etc.)
- Export of any kind
- Comparison features (e.g. comparing two lures or two time periods side by side)
- A second Statistics tab (e.g. General Catch / Fishing Statistics, `docs/roadmap.md` §3.3) — named here only so the tabbed structure anticipates it, not to scope it
- Recommendations based on lure/catch history
- Any change to the `catches`, `lure_catalog`, or `personal_tackle_box` domain models, database schemas, or repository contracts
- Any persisted/stored statistic, cache, or aggregate table
- Sorting or grouping options for the lure list or lure type breakdown other than the fixed catch-count-descending order defined here
- Cloud synchronization

---

## Relationship to Previous MFS Documents

- **MFS-009 (Catch Foundation)** listed "Catch Statistics" among its expected Future Milestones. This milestone is the first to deliver any statistics, scoped specifically to lure-based statistics rather than the broader, still-undefined statistics theme MFS-009 gestured at.
- **MFS-015 (Lure Catalog Foundation)** established the stable `LureVariant`/`LureModel` identity and the lure type code/display-label mapping this milestone reads from, unmodified.
- **MFS-016 (Personal Tackle Box Foundation)** explicitly named "Lure-based catch statistics and recommendations built on top of the Personal Tackle Box rather than the global catalog" in its own Future Extensions — this milestone delivers the statistics half of that, while resolving (see [Conceptual Model](#computed-from-catch-history-not-from-current-tackle-box-contents)) that the computation is actually anchored to catch history via MFS-017's reference, not to current tackle box membership.
- **MFS-017 (Assign Lure to Catch)** created the `Catch.lureVariantId` reference this milestone's every statistic is computed from, and explicitly named "Lure-Based Catch Statistics" as its own next milestone in its Future Extensions section. This milestone also directly reuses MFS-017's Historical Stability guarantee (FR-6) and retired-variant resolvability guarantee (FR-7) as the basis for [FR-9](#fr-9--statistics-reflect-full-catch-history-not-current-ownership) and [FR-11](#fr-11--retired-catalog-variants-are-counted-normally).
- **MFS-018 (Lure Catalog UX Improvements)** is not a dependency of this milestone. It is referenced only in [Conceptual Model](#granularity-the-catalog-variant-not-the-model) to distinguish this milestone's per-variant granularity from MFS-018's per-model browsing grouping.

---

## Dependencies

No new external dependencies are required. This milestone reuses the existing stack and patterns:

- Flutter, Dart
- Drift (local persistence, per ADR-0005)
- The existing Repository pattern and feature-first structure (ADR-0001, ADR-0003, ADR-0006)
- The existing `Catch` domain model and its `lureVariantId` reference (MFS-009/MFS-017)
- The Lure Catalog domain model, `LureVariant`/`LureModel` fields, and lure type display-label mapping (MFS-015)

---

## Future Extensions

This milestone is expected to support, in later milestones:

- General Catch / Fishing Statistics as a second Statistics tab, not tied to lures specifically (`docs/roadmap.md` §3.3)
- Optionally including lure variants with zero catches in the lure list, if that proves useful once real statistics are in use (see [FR-6](#fr-6--lure-list))
- Filtering these statistics (e.g. by date range or fishing spot)
- Percentages, averages, and other derived metrics explicitly excluded from this milestone
- Smart lure or fishing recommendations built on top of accumulated lure/catch history (`docs/roadmap.md` §3.5), for which this milestone's lure list is a plausible input
- Visual (chart/graph) presentation of the data this milestone introduces in list/card form
