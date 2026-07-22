# Roadmap

## Last Updated

2026-07-22

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

### 3.4 Water Bodies and Fishing Spot Hierarchy

* **Intent:** Introduce a parent concept above `FishingSpot` so that multiple fishing spots on the same lake, pond, river, or sea area can be grouped, browsed, and one day analyzed together, while each `Catch` continues to retain its own exact fishing spot (no loss of the precision MFS-011/MFS-014/MFS-022 already provide). For example:

  ```text
  Merrasjärvi
    ├── Koiraranta
    ├── Pohjoislahti
    └── Ruovikkoniemi
  ```

* **Likely domain term:** `WaterBody`. No existing project terminology or documentation (ADR-0004, MFS-004, `fishing_spots`' current implementation) names or anticipates this concept today, so this is a newly proposed term, not a renaming of something already established.
* **Intended model:**

  ```text
  WaterBody
    ├── FishingSpot
    ├── FishingSpot
    └── FishingSpot
  ```

  Each `FishingSpot` would belong to exactly one `WaterBody`; a `WaterBody` may have one or more fishing spots. The concept must support lakes, ponds, rivers, and sea areas — not lakes only.
* **Goals:**
  - Every fishing spot belongs to a water body.
  - Catches keep referencing their exact fishing spot, unchanged.
  - Statistics (the `statistics` feature — MFS-019 through MFS-022) can group and display catches by water body, alongside the existing per-species, per-lure, and per-fishing-spot groupings, without removing any of them.
  - Catch Details and other detailed catch views continue showing the exact fishing spot, not only the parent water body.
  - Future water-body-specific statistics and recommendations become possible (see §3.6 and §4).
* **Staged identification path (roadmap-level intent, not yet scoped):**
  - First version: the angler selects an existing water body, or creates a new one, while adding a fishing spot — following the same explicit, user-driven creation pattern already established for fishing spots themselves (MFS-005).
  - The app should reuse and suggest previously created nearby water bodies where practical, rather than always requiring the angler to create a new one.
  - Later enhancement: automatic water-body detection from map coordinates, using suitable geospatial boundary data. No specific external dataset or API is chosen at this time — that is a research question for whichever future MFS/ADR takes this on, likely requiring a new ADR given the same kind of external-data-source question already unresolved for Weather / Environmental Data (§3.2).
  - Automatic detection, whenever it exists, must be treated as a suggestion the angler can confirm or correct — never an authoritative, silent assignment.
* **Depends on:** MFS-004 (Fishing Spot Foundation) and ADR-0004 (Fishing Spot Domain), whose current initial `FishingSpot` fields (`id`, `name`, `latitude`, `longitude`, `createdAt`) would need an additive parent reference; MFS-022 (Fishing Spot Statistics), whose existing per-spot statistics this work must not break.
* **Status:** Candidate. Newly identified; not yet scoped, drafted, or approved. Placed first among the three newly identified items in this section because the later two candidates (§3.5, §3.6) are described as eventually benefiting from water-body grouping, not the reverse.

### 3.5 Lure Catalog Expansion and Data Management

* **Intent:** Substantially expand the built-in Lure Catalog (MFS-015) with a much larger selection of real lure brands, models, sizes, weights, colors, and variants, and establish a maintainable way to author that data — rather than growing it as scattered, hardcoded entries in production code, the way the current development seed dataset (`lure_catalog_seed_data.dart`, approximately 3–5 `LureModel`s and 10–20 `LureVariant`s per MFS-015 FR-7) is intentionally small and explicitly identified as development-only, not production data.
* **Goals:**
  - Verify that the existing `LureModel`/`LureVariant` model (MFS-015's Conceptual Data Model) scales cleanly to a much larger catalog before large-scale data entry begins — MFS-015's own Performance Expectations already anticipated growth to "thousands of variants" via lazy/virtualized rendering and no eager startup load, but that anticipation has not yet been validated against a real, large dataset.
  - Avoid maintaining a large catalog as scattered hardcoded production-code entries.
  - Consider a maintainable, structured import or seed-data workflow (for example, JSON or CSV), without requiring a network connection to load it.
  - Preserve the catalog's existing offline-first operation and its read-only, shared-reference-data character (MFS-015) — this is data-authoring/tooling work, not a change to the catalog's ownership model or read-only nature.
  - Prepare catalog metadata for future lure recommendations (§3.6). Relevant future lure metadata may include: lure type, size, weight, running depth, color family, natural versus high-visibility coloration, contrast, flash, vibration/action, and suitable depth or cover. This is a roadmap-level list of candidate metadata, not a schema design — the final data model remains a future Technical Design decision.
* **Depends on:** MFS-015 (Lure Catalog Foundation) and MFS-018 (Lure Catalog UX Improvements) — both complete, so the existing model and browsing/filtering UX are the actual foundation this work would validate and extend, not replace.
* **Status:** Candidate. Newly identified; not yet scoped, drafted, or approved.

### 3.6 Condition-Based Lure Guidance (Rule-Based)

* **Intent:** Help anglers choose suitable lure types, colors, and properties for their current fishing conditions, through an offline-first, rule-based guidance system. The initial version is explicitly rule-based, not AI — see [Later Roadmap](#4-later-roadmap) for the later, data-driven/AI-assisted personalization path this foundation could eventually support.
* **Possible inputs:** water clarity or darkness, weather and light conditions, time of day, fishing depth, vegetation versus open water, target species, and season or water temperature where available.
* **Possible outputs:** recommended lure types; recommended color and contrast properties; recommended action or vibration; explanations for why those properties suit the stated conditions; and matching lures from the angler's own Personal Tackle Box (MFS-016) — not the full Lure Catalog, consistent with the Personal Tackle Box's existing "what the user owns, not the full catalog" principle (MFS-016).
* **Depends on:** §3.5 (Lure Catalog Expansion and Data Management), for the richer per-lure metadata this guidance would reason over; MFS-016 (Personal Tackle Box), complete, to match recommendations against lures the angler actually owns; the still-unresolved Weather / Environmental Data candidate (§3.2), for any input relying on live/forecast weather rather than angler-entered conditions.
* **Status:** Candidate. Newly identified; not yet scoped, drafted, or approved. Distinct from the existing "Smart Lure / Fishing Recommendations" candidate (§3.3): that item recommends from the angler's own accumulated catch history, while this item recommends from stated/observed conditions via fixed rules, requiring no catch history and no AI. See [Later Roadmap](#4-later-roadmap) for how a future personalization layer could eventually connect the two.

---

## 4. Later Roadmap

Broader future directions, well beyond the near-term list above. These are themes the existing documentation acknowledges as plausible future territory — not approved scope, not sequenced, and not assigned to any milestone number.

* **Cloud synchronization.** Named across the codebase as the reason the Repository pattern exists (ADR-0001, `docs/architecture.md`), and listed in `README.md` as "planned for later" (Supabase). Every feature shipped so far (MFS-013, MFS-015, MFS-016) has explicitly excluded it from its own scope.
* **Account support.** Listed as out of scope for the MVP in the project charter and in MFS-004/MFS-006, but noted there as something that "may be added in future versions." A likely prerequisite for cloud synchronization and multi-device use.
* **Multi-device use.** Not separately documented, but a natural corollary of cloud synchronization and account support once both exist — the local-first data model would need a defined sync/conflict strategy first.
* **Sharing / community features.** The project charter explicitly excludes "Community features" from the MVP (future candidate); MFS-013 separately excludes "photo sharing" for Catch Photos. Any shared-catch or shared-fishing-spot capability would fall under this same, currently out-of-scope theme.
* **Expanded recommendation engine.** The narrower "Smart Lure / Fishing Recommendations" candidate in the near-term list (§3.3) is the first step; the project charter's long-term goal describes a broader "smart fishing companion that learns from the user's own fishing history," which is a larger, later theme than any single near-term milestone. The rule-based Condition-Based Lure Guidance candidate (§3.6) is this theme's other near-term building block: a later personalization layer could build on it using the angler's own catch history (converging with §3.3), water-body-specific results (depending on §3.4, Water Bodies and Fishing Spot Hierarchy), weather and environmental data (depending on the still-unresolved §3.2 Weather candidate), anonymized aggregate data if multi-user functionality is ever introduced (depending on the Cloud Synchronization/Account Support/Multi-Device themes below), and an AI or learned ranking layer only once enough trustworthy data exists to support one. None of this is scoped, and the rule-based foundation in §3.6 is explicitly designed not to depend on any of it.
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
