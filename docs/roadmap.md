# Roadmap

## Last Updated

2026-07-20

---

## 1. Roadmap Principles

* This roadmap is **directional**, not a fixed delivery promise. It communicates likely sequencing and intent, not committed dates.
* Only an approved MFS (Feature Specification) document defines actual feature scope. Nothing in this roadmap should be read as a substitute for one.
* Sequencing follows architectural and product dependencies (e.g. a feature that references catalog or ownership data cannot precede the feature that creates that data), not arrival order or convenience.
* Roadmap items may be reordered, rescoped, split, or dropped after architecture reviews, user testing, or real fishing-trip usage. Nothing past the current milestone is locked in.
* Offline-first operation and the project's existing architecture (feature-first structure, Repository pattern, Drift/SQLite as the local source of truth — see `docs/architecture.md` and ADR-0001/0003/0005/0006) remain governing constraints for every item on this roadmap, near-term or later.

---

## 2. Current Milestone

**MFS-017 (Assign Lure to Catch) and MFS-018 (Lure Catalog UX Improvements) are both complete.** MFS-017 let an angler assign an owned lure (referencing the catalog `LureVariant`, not the `TackleBoxEntry` — see MFS-017's Conceptual Relationship) to a `Catch`, displayed in Catch Details. MFS-018 followed it with a presentation-only reorganization of the Lure Catalog and Personal Tackle Box add flow: the browsing list groups by lure model instead of by variant, a new Lure Model Details view lists every color variant of a selected model, and the add-photo dialog no longer silently completes an add on dismissal. Both are architecture-reviewed, fully tested, and physically verified on Android (see `docs/project-status.md`).

**No next milestone has been selected yet** — no new MFS document has been drafted since MFS-018. The Near-Term Roadmap (§3 below) lists logical future candidates based on dependency readiness and existing documentation; these entries are informational only and do not represent a decision or commitment. A roadmap item is promoted to Current Milestone only once an MFS document has been drafted and approved for it, per this roadmap's own maintenance rule.

---

## 3. Near-Term Roadmap

Proposed logical milestones after MFS-017, ordered by dependency readiness and product value. None of these are scoped yet; none are committed beyond MFS-017.

### 3.1 Lure-Based Catch Statistics

* **Identifier:** Not yet assigned.
* **Intent:** Surface simple statistics about which owned lures produced catches (e.g. most-used lure, catches per lure/lure type).
* **Depends on:** MFS-017 (a catch must be able to reference a lure before lure-based statistics can exist), MFS-016 (Personal Tackle Box).
* **Status:** Candidate. Named as an expected direction in MFS-016's Future Extensions ("Lure-based catch statistics ... built on top of the Personal Tackle Box") and in MFS-017's own Future Extensions section. With MFS-016 and MFS-017 both now complete, the dependency chain (Catch → Lure Catalog → Personal Tackle Box → Assign Lure to Catch) is in place, making this a logical future direction — not yet scoped, drafted, or approved as a milestone.

### 3.2 Catch Notes

* **Identifier:** Not yet assigned.
* **Intent:** Let an angler attach a free-text note to a catch.
* **Depends on:** MFS-009 (Catch Foundation) only — already complete; no dependency on MFS-017.
* **Status:** Candidate. Explicitly listed as an expected follow-up in MFS-009's Future Milestones, but not reinforced by any more recent document, and it currently has no assigned priority relative to the other items below.

### 3.3 General Catch / Fishing Statistics and Analytics

* **Identifier:** Not yet assigned.
* **Intent:** Broader statistics not tied to lures specifically — e.g. catches per fishing spot, per species, or over time.
* **Depends on:** Catch Management (already complete). Independent of MFS-017, though it would naturally sit alongside 3.1 once lure-based statistics exist.
* **Status:** Candidate. Supported by MFS-009's Future Milestones ("Catch Statistics") and the project charter's long-term goal of learning from the user's own fishing history, but scope and boundaries relative to 3.1 are undefined.

### 3.4 Weather / Environmental Data on Catches

* **Intent:** Attach environmental context (e.g. weather conditions) to a catch, to help answer "what has worked in similar conditions before" (project charter, Problem Statement).
* **Depends on:** Catch Foundation (already complete). Would require a new decision on data source, since it is the first candidate that plausibly needs an external data feed — in tension with the offline-first constraint and requiring architectural review (likely a new ADR) before scoping.
* **Status:** Candidate. "Weather information" and "Water conditions" are both explicitly listed as excluded-for-now in MFS-009's Non-Goals (not rejected), and "Environmental data" appears in the README/charter Vision — but no MFS has ever scoped it, and the offline-data-source question is unresolved.

### 3.5 Smart Lure / Fishing Recommendations

* **Intent:** Suggest a lure or approach based on the user's own accumulated catch and tackle-box history.
* **Depends on:** 3.1 (Lure-Based Catch Statistics) and MFS-016 (Personal Tackle Box) at minimum — there is no history to recommend from until those exist.
* **Status:** Candidate — the most speculative item in this list. Named in MFS-016's Future Extensions and the project charter's long-term vision, and explicitly marked "(future)" in the README Vision section, but with no scope, no data model, and dependencies that are themselves not yet built.

---

## 4. Later Roadmap

Broader future directions, well beyond the near-term list above. These are themes the existing documentation acknowledges as plausible future territory — not approved scope, not sequenced, and not assigned to any milestone number.

* **Cloud synchronization.** Named across the codebase as the reason the Repository pattern exists (ADR-0001, `docs/architecture.md`), and listed in `README.md` as "planned for later" (Supabase). Every feature shipped so far (MFS-013, MFS-015, MFS-016) has explicitly excluded it from its own scope.
* **Account support.** Listed as out of scope for the MVP in the project charter and in MFS-004/MFS-006, but noted there as something that "may be added in future versions." A likely prerequisite for cloud synchronization and multi-device use.
* **Multi-device use.** Not separately documented, but a natural corollary of cloud synchronization and account support once both exist — the local-first data model would need a defined sync/conflict strategy first.
* **Sharing / community features.** The project charter explicitly excludes "Community features" from the MVP (future candidate); MFS-013 separately excludes "photo sharing" for Catch Photos. Any shared-catch or shared-fishing-spot capability would fall under this same, currently out-of-scope theme.
* **Expanded recommendation engine.** The narrower "Smart Lure / Fishing Recommendations" candidate in the near-term list (3.5) is the first step; the project charter's long-term goal describes a broader "smart fishing companion that learns from the user's own fishing history," which is a larger, later theme than any single near-term milestone.
* **Richer maps.** MFS-001's Future Extensions already names offline map storage, environmental overlays, custom layers, and route recording as expected later map capabilities. Depth or other environmental overlays would fall under this same theme.
* **Import / export.** Listed as out of scope in MFS-005 and MFS-006, with no committed future date — a plausible later data-portability feature.
* **Advanced analytics.** A deeper, longer-horizon extension of the near-term statistics candidates (3.1, 3.3) — trend analysis across seasons, locations, or conditions, once enough catch history and (if built) environmental data exist.

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
* Weather information, water conditions, notes, lure information at the time — all superseded/being picked up incrementally by MFS-013 (photos, done), MFS-015/016/017 (lures, in progress), and the near-term Catch Notes / Weather candidates above

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
