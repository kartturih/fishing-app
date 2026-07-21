# Roadmap

## Last Updated

2026-07-21

---

## 1. Roadmap Principles

* This roadmap is **directional**, not a fixed delivery promise. It communicates likely sequencing and intent, not committed dates.
* Only an approved MFS (Feature Specification) document defines actual feature scope. Nothing in this roadmap should be read as a substitute for one.
* Sequencing follows architectural and product dependencies (e.g. a feature that references catalog or ownership data cannot precede the feature that creates that data), not arrival order or convenience.
* Roadmap items may be reordered, rescoped, split, or dropped after architecture reviews, user testing, or real fishing-trip usage. Nothing past the current milestone is locked in.
* Offline-first operation and the project's existing architecture (feature-first structure, Repository pattern, Drift/SQLite as the local source of truth — see `docs/architecture.md` and ADR-0001/0003/0005/0006) remain governing constraints for every item on this roadmap, near-term or later.

---

## 2. Current Milestone

MFS-017 (Assign Lure to Catch), MFS-018 (Lure Catalog UX Improvements), MFS-019 (Lure-Based Catch Statistics), MFS-020 (General Catch Statistics), MFS-021 (Species Statistics), MFS-022 (Fishing Spot Statistics), and MFS-023 (Catch Notes) are all complete. MFS-017 let an angler assign an owned lure (referencing the catalog `LureVariant`, not the `TackleBoxEntry` — see MFS-017's Conceptual Relationship) to a `Catch`, displayed in Catch Details. MFS-018 followed it with a presentation-only reorganization of the Lure Catalog and Personal Tackle Box add flow: the browsing list groups by lure model instead of by variant, a new Lure Model Details view lists every color variant of a selected model, and the add-photo dialog no longer silently completes an add on dismissal. MFS-019 introduced the new Statistics feature and its first tab, Lure Statistics: two summary cards (most successful lure, most successful lure type), a per-lure catch-count list, and a per-lure-type catch-count breakdown, all computed live from existing catch and lure catalog data with no new persisted statistic, table, or migration. MFS-020 added the Statistics feature's first tab, Catches — moving Lure Statistics to the second tab position, unchanged in every other respect — presenting a Top 3 Largest Catches list ranked by weight (each entry opening the existing Catch Details view, MFS-014, and presented as a medal-bordered "Hall of Fame" after three rounds of post-testing presentation refinement), summary statistics (total catches, most caught species, rendered as equal-height cards), and a full per-species catch-count list. MFS-021 wired up the navigation MFS-020 deliberately left unimplemented: tapping a species row in the Species List now opens a pushed Species Statistics page for that species — a header (species name, total catches), a Record Catch card, and a full Catch List ordered by recorded weight, then catch date, then catch id, each entry opening the existing Catch Details view, with the page refreshing automatically on return from it. MFS-022 completed the Statistics feature's third grouping axis, alongside Species Statistics and Lure Statistics: a new Fishing Spot List within the Catches tab and a pushed Fishing Spot Statistics page for a selected spot, showing its total catch count, Last Catch Date, a Record Catch card, a static Species Breakdown, and its full Catch List, each entry opening the existing Catch Details view. MFS-023 let an angler attach one optional, multiline, plain-text note (up to 1000 characters) to a `Catch` — editable in Add Catch and Edit Catch, and shown as the final, selectable section of Catch Details when present — via an additive schema migration (schema version 6 to 7), with no new table, repository, or feature. All seven are architecture-reviewed, fully tested (682/682 automated tests), and physically verified on Android (see `docs/project-status.md`).

**Catch Search & Filtering has been selected as the next milestone, to be specified as MFS-024.** It has not yet been drafted or approved — drafting begins immediately following this roadmap update. The Near-Term Roadmap (§3) has been reprioritized accordingly: Catch Search & Filtering (MFS-024) is now first. A milestone's scope only becomes binding once its own MFS has been drafted and approved — this roadmap entry is a sequencing decision, not a specification.

---

## 3. Near-Term Roadmap

Proposed logical milestones after MFS-023, in the confirmed next-implementation order below. Only MFS-024 (Catch Search & Filtering) is about to be drafted; it is prioritized first, but is not scoped yet — only an approved MFS defines actual feature scope (§1).

### 3.1 MFS-024 – Catch Search & Filtering

* **Identifier:** Confirmed as the next milestone to specify, as MFS-024. Not yet drafted or approved — drafting begins immediately following this roadmap update.
* **Intent:** Let an angler search and filter their catch history (e.g. by species, date range, or fishing spot). Addresses the gap MFS-011 (View Catches for Fishing Spot) explicitly deferred in its own Out of Scope ("filtering"), which no subsequent milestone has picked up since.
* **Depends on:** MFS-009 (Catch Foundation) and MFS-011 (View Catches for Fishing Spot) — both complete.
* **Status:** Confirmed as the next milestone. Not yet scoped, drafted, or approved — this remains a roadmap-level description only, not a specification.

### 3.2 Weather / Environmental Data on Catches

* **Intent:** Attach environmental context (e.g. weather conditions) to a catch, to help answer "what has worked in similar conditions before" (project charter, Problem Statement).
* **Depends on:** Catch Foundation (already complete). Would require a new decision on data source, since it is the first candidate that plausibly needs an external data feed — in tension with the offline-first constraint and requiring architectural review (likely a new ADR) before scoping.
* **Status:** Candidate. "Weather information" and "Water conditions" are both explicitly listed as excluded-for-now in MFS-009's Non-Goals (not rejected), and "Environmental data" appears in the README/charter Vision — but no MFS has ever scoped it, and the offline-data-source question is unresolved.

### 3.3 Smart Lure / Fishing Recommendations

* **Intent:** Suggest a lure or approach based on the user's own accumulated catch and tackle-box history.
* **Depends on:** MFS-019 (Lure-Based Catch Statistics) and MFS-016 (Personal Tackle Box) at minimum. Both are now complete, so a lure/catch history exists to recommend from — but this candidate's own scope, data model, and priority remain entirely undefined.
* **Status:** Candidate — the most speculative item in this list. Named in MFS-016's Future Extensions and the project charter's long-term vision, and explicitly marked "(future)" in the README Vision section. Its dependencies are now built, which removes a blocker but is not itself a scoping or scheduling decision.

---

## 4. Later Roadmap

Broader future directions, well beyond the near-term list above. These are themes the existing documentation acknowledges as plausible future territory — not approved scope, not sequenced, and not assigned to any milestone number.

* **Cloud synchronization.** Named across the codebase as the reason the Repository pattern exists (ADR-0001, `docs/architecture.md`), and listed in `README.md` as "planned for later" (Supabase). Every feature shipped so far (MFS-013, MFS-015, MFS-016) has explicitly excluded it from its own scope.
* **Account support.** Listed as out of scope for the MVP in the project charter and in MFS-004/MFS-006, but noted there as something that "may be added in future versions." A likely prerequisite for cloud synchronization and multi-device use.
* **Multi-device use.** Not separately documented, but a natural corollary of cloud synchronization and account support once both exist — the local-first data model would need a defined sync/conflict strategy first.
* **Sharing / community features.** The project charter explicitly excludes "Community features" from the MVP (future candidate); MFS-013 separately excludes "photo sharing" for Catch Photos. Any shared-catch or shared-fishing-spot capability would fall under this same, currently out-of-scope theme.
* **Expanded recommendation engine.** The narrower "Smart Lure / Fishing Recommendations" candidate in the near-term list (§3.3) is the first step; the project charter's long-term goal describes a broader "smart fishing companion that learns from the user's own fishing history," which is a larger, later theme than any single near-term milestone.
* **Richer maps.** MFS-001's Future Extensions already names offline map storage, environmental overlays, custom layers, and route recording as expected later map capabilities. Depth or other environmental overlays would fall under this same theme.
* **Import / export.** Listed as out of scope in MFS-005 and MFS-006, with no committed future date — a plausible later data-portability feature.
* **Advanced analytics.** A deeper, longer-horizon extension of the completed Lure-Based Catch Statistics (MFS-019), General Catch Statistics (MFS-020), and Species Statistics (MFS-021) milestones — trend analysis across seasons, locations, or conditions, once enough catch history and (if built) environmental data exist.

---

## 5. Deferred and Out-of-Scope Items

Already-decided exclusions, captured here so they are not repeatedly rediscovered or re-debated. Each of these is explicitly stated in an existing MFS document; this section only summarizes.

**Lure Catalog (MFS-015 — Out of Scope)**
* User-created catalog entries, user-uploaded lure photos, favorites
* Admin/moderation tooling, external APIs, web scraping, barcode scanning
* Cast or usage tracking, purchase history, quantity tracking at the catalog level

**Personal Tackle Box (MFS-016 — Out of Scope)**
* Editing or replacing a personal photo on an already-saved entry (remove-and-re-add is the only supported path)
* Search or filtering within the Personal Tackle Box itself
* Quantity, purchase price/history, condition, or notes on owned entries
* Custom (non-catalog) lures, favorites, lure boxes/sub-collections, tackle-boxes-inside-tackle-boxes
* Reflecting a catalog "retired/active" status as a visual indicator (explicitly listed as a future extension, not this milestone)

**Catch Photos (MFS-013 — Out of Scope)**
* Cloud synchronization, remote image storage, photo sharing
* Videos, photo editing/filters/cropping, captions, EXIF display, manual reordering, cover photos, undo deletion

**Catch Foundation (MFS-009 — Non-Goals, still open for later)**
* Weather information, water conditions, notes, lure information at the time — all superseded/being picked up incrementally by MFS-013 (photos, done), MFS-015/016/017 (lures, done), MFS-023 (notes, done), and the Weather (§3.2) candidate above

**Project-wide (project charter — Out of Scope for MVP)**
* User accounts, cloud synchronization, community features, AI recommendations, Garmin integration, weather-based recommendations

---

## 6. Roadmap Maintenance Rules

This file must be updated:

* after a feature is completed (move it out of "Current Milestone", update "Near-Term Roadmap" sequencing behind it),
* when the next MFS is chosen (update "Current Milestone" to the newly chosen feature),
* when dependencies or priorities change (re-order or re-Status "Near-Term Roadmap" items),
* when an idea is promoted from Candidate to Likely or Committed (update its Status level and, if applicable, move it into "Current Milestone" once an MFS is drafted for it), and
* whenever `docs/project-status.md`'s "Next Planned Task" changes.

**`docs/roadmap.md` and `docs/project-status.md` must never contradict each other.** `docs/project-status.md` is the authoritative record of what is currently planned next; this file must always name the same feature as its "Current Milestone." If a discrepancy is found, treat `docs/project-status.md` as authoritative and correct this file, not the other way around.
