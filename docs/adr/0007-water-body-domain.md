# ADR-0007: Water Body Domain

## Status

Accepted

## Date

2026-07-22

---

## Context

Fishing App represents a fishing location today using a single entity, `FishingSpot` (ADR-0004), holding one plain `name` field alongside its coordinates.

In practice, an angler's "fishing spot" carries two different meanings at once:

- the broader body of water they fished on (a lake, river, reservoir, pond, or sea area), and
- the exact local place on that water where they actually fished.

`FishingSpot.name` is currently asked to represent both at once, since no separate concept exists for the first. This has two direct architectural consequences:

- **Aggregation is unreliable.** Statistics and any future feature that summarizes catches "by water" (MFS-019 through MFS-022; the water-body-level statistics and lure-guidance candidates in `docs/roadmap.md` §3.4–§3.6) have only the exact fishing-spot name to group by. Two fishing spots on the same lake, named differently by the angler, cannot be recognized as the same water — and a fishing-spot name that tries to encode both the lake and the exact spot (e.g. "Merrasjärvi Koiraranta") becomes overly specific exactly where an aggregated view needs it to be general.
- **There is no stable concept for a body of water to attach future data to.** Water-body-level statistics, lure recommendations conditioned on water type, and any future water characteristic (clarity, vegetation, depth) all need something to reference. Today, nothing plays that role — only an exact `FishingSpot`, which is the wrong grain for that data.

MFS-024 specifies the product behavior this ADR makes possible: a new water-body concept above `FishingSpot`. Introducing it is an architectural decision, not merely a feature detail, because it adds a new persistent domain entity and a new parent/child relationship that must be reconciled with this project's existing architecture (ADR-0001, ADR-0003, ADR-0004, ADR-0005, ADR-0006) — in the same way ADR-0004 itself was required before `FishingSpot` could be introduced as more than a map marker.

---

## Decision

Fishing App will introduce **`WaterBody`** as its own persistent domain entity, parent to `FishingSpot`:

- `WaterBody` is the parent of `FishingSpot`.
- Every `FishingSpot` belongs to exactly one `WaterBody`.
- One `WaterBody` may contain many `FishingSpot`s.
- `WaterBody` represents lakes, rivers, reservoirs, ponds, sea areas, and similar bodies of water. It is intentionally generic, not lake-specific — the same "model the real domain concept, not a UI convenience" discipline ADR-0004 already established for `FishingSpot` itself.

```text
WaterBody
    ↓
FishingSpot
    ↓
Catch
```

### Catch Ownership

- `Catch` continues to reference only `FishingSpot` (unchanged from ADR-0004/MFS-009).
- A catch's water body is always resolved *through* its `FishingSpot`, never stored directly on `Catch`.
- `Catch` does not receive a duplicated `waterBodyId`.
- This avoids a duplicated relationship and the data-integrity risk of a catch's own cached water body silently drifting out of sync with its fishing spot's actual, current water body.

### Deletion Policy

- A `WaterBody` that still contains one or more `FishingSpot`s cannot be deleted.
- An empty `WaterBody` (no `FishingSpot`s) may be deleted.
- This establishes a new lifecycle rule for a parent entity in this application — distinct from both existing foreign-key precedents already in place: the cascade-delete rule governing `FishingSpot → Catch` (ADR-0004/MFS-009), and the restrict-while-referenced rule governing `LureVariant → Catch`/`TackleBoxEntry` (MFS-016/MFS-017). See Rationale.

---

## Rationale

**Why a new entity, rather than continuing to overload `FishingSpot.name`.** `FishingSpot` earned its own domain identity in ADR-0004 precisely so that a fishing location would not be defined by how it happens to be displayed. The same reasoning applies one level up: a body of water is a real, independent concept the angler already thinks in terms of ("which lakes have I fished"), and other features (statistics, recommendations) need a stable thing to reference — not a substring convention inside a fishing spot's name.

**Why the deletion rule is "block while non-empty" rather than cascade.** Deleting a `FishingSpot` today already cascades to delete every `Catch` recorded there — a single-level, well-understood blast radius. Extending that same cascade one level further, from `WaterBody`, would reach every `FishingSpot` on it and, through those, every `Catch` (and each catch's own photos, lure assignment, and notes) ever recorded at any of them — a multi-level cascade with no existing precedent anywhere in this application, triggered by deleting something that is, conceptually, the least specific and most easily created entity in the hierarchy. Requiring a `WaterBody` to be empty before it can be deleted keeps its deletion exactly as low-risk as deleting any other empty container already is, and requires an explicit, visible action (moving or deleting its fishing spots) before anything is lost — consistent with this project's general preference for predictable, non-destructive behavior over convenient but surprising cascades.

---

## Consequences

### Positive

- Clearer domain model: the difference between "the lake" and "the exact spot" becomes real, explicit data, not an implicit convention buried in how an angler happens to phrase a fishing spot's name.
- Reusable water bodies across many fishing spots.
- Cleaner, more meaningful statistics: aggregation can occur at the level anglers actually think in (the water body), without discarding the exact-spot precision this application already relies on for Catch Details and per-spot statistics.
- Enables future AI/recommendation and condition-based lure-guidance features that need to reason about a body of water as a whole (`docs/roadmap.md` §3.4–§3.6).
- Reduced duplication: the same lake is represented once, not re-described inside every fishing spot's own name.

### Trade-offs

- One additional persistent entity and its own lifecycle to maintain.
- One more relationship to reason about (`WaterBody → FishingSpot`, alongside the existing `FishingSpot → Catch`).
- Migration complexity: every existing `FishingSpot` must be reconciled with the new, required relationship without losing or corrupting any existing data.
- Additional management UI is required (creating, selecting, renaming, and deleting a `WaterBody`) beyond what `FishingSpot` alone ever required.

---

## Alternatives Considered

### Store the water-body name directly on `Catch`

Rejected. Duplicates the same water-body name across every catch at a spot, lets that name drift inconsistently across catches at the very same fishing spot, and produces no reusable, addressable entity that other features (statistics, recommendations) could reference — only a repeated string.

### Continue using only `FishingSpot`, with no separate water-body concept

Rejected. This is the status quo, and it is exactly the limitation this ADR exists to resolve: `FishingSpot.name` cannot represent two different things (the lake and the exact spot) without sacrificing precision on one or the other, and no future statistics or recommendation feature gains a stable concept to reason about a body of water by.

### Infer water bodies automatically from map coordinates using an external geospatial dataset

Rejected for this decision. It would introduce a network or external-data dependency in tension with this project's offline-first architecture (ADR-0001, `docs/architecture.md`), require selecting and vetting a specific dataset or API before any of this feature could ship, and risk producing an authoritative-feeling assignment the angler cannot easily correct. Manual, user-confirmed water-body selection is adopted instead. Automatic detection remains a plausible future enhancement *on top of* the domain entity established here (`docs/roadmap.md` §3.4), not a reason to defer introducing `WaterBody` itself.

---

## Implementation Notes

- Product behavior for this feature is specified by MFS-024.
- Technical implementation — schema and migration mechanics, exact repository/query design, and feature-directory placement of `WaterBody` — is described by TD-024, not this ADR.
- This ADR documents why `WaterBody` exists as a domain concept and how it relates architecturally to `FishingSpot` and `Catch`. It deliberately does not specify database tables, columns, identifier schemes, or code structure.

---

## Scope

This decision defines:

- The existence of `WaterBody` as a persistent domain entity.
- Its parent relationship to `FishingSpot`.
- That `Catch` continues to reference only `FishingSpot`, with `WaterBody` always resolved through it, never duplicated.
- The deletion-lifecycle rule for `WaterBody`.

This decision does not define:

- Database schema or migration mechanics.
- Repository or query implementation.
- Feature-directory ownership/placement of `WaterBody` (the existing `fishing_spots` feature versus a new feature) — left to TD-024/architecture review, per MFS-024's own Design Notes.
- Automatic water-body detection technology or data source.
- UI/navigation design for water-body management.

These topics are addressed by MFS-024 (product behavior) and will be addressed by TD-024 (technical design).
