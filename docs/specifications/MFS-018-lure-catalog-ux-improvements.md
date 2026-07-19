# MFS-018 — Lure Catalog UX Improvements

## Status

Implemented — architecture-reviewed, all automated tests passing, and physical Android verification completed. See TD-018 for the technical design (including two documented implementation deviations) and `docs/project-status.md` for the verification record.

## Related

- Depends on: MFS-015 — Lure Catalog Foundation
- Depends on: MFS-016 — Personal Tackle Box Foundation
- Refines the browsing/details/add flow described in both of the above; introduces no new data, no new feature, and no change to either milestone's underlying scope.

---

## Purpose

Improve the usability of the Lure Catalog and the "Add to Tackle Box" flow, without changing the underlying architecture, domain model, database schema, or repository contracts established by MFS-015 and MFS-016.

This is a **pure UX milestone**. Every capability described here is a presentation-layer reorganization of data and operations that already exist. Nothing in this milestone requires a new column, a new table, a new repository method signature, or a new query capability beyond what MFS-015/MFS-016 already expose.

---

## User Value

Today, the Lure Catalog's browsing list shows one row per color variant. A single model with several colors (a common case — most lure models ship in many colors) appears as several near-identical rows differing only in a color name, making the list longer and harder to scan than the number of distinct products actually warrants. Separately, the current "Add to Tackle Box" photo step can silently complete — with no photo — if the user dismisses the dialog by tapping outside it, which is not a deliberate choice to skip the photo and risks adding a lure the user did not mean to add yet.

This milestone addresses both:

- Anglers browse a list organized the way they actually think about products — by model, not by every color repeated as its own row — and choose the specific color they want from a dedicated, scannable list once they've found the right model.
- Anglers can safely back out of the "Add to Tackle Box" photo step at any point — by tapping outside the dialog, by the Android back gesture, or by an explicit Cancel — without the lure being added by accident.

---

## Scope

### In Scope

- Reorganizing the Lure Catalog browsing list to show one entry per `LureModel` instead of one entry per `LureVariant`.
- A redesigned Lure Model Details view showing model-level information once, followed by a scrollable Color Variants list covering every non-retired variant of that model.
- Choosing a variant and adding it to the Personal Tackle Box from within that Color Variants list.
- Correcting the "Add to Tackle Box" photo dialog so dismissing it can never silently add a lure.
- Navigation changes required to support the above (the Lure Catalog list → Lure Model Details → Color Variants → Add flow).

### Out of Scope

See [Out of Scope](#out-of-scope-1) for the complete list. Notably: search redesign, filter redesign, sort redesign, statistics, recommendations, any change to the domain model, database schema, or repository contracts of `lure_catalog` or `personal_tackle_box`, and any change to the Personal Tackle Box's own browsing or Owned Entry Detail views (which already group by manufacturer/model per MFS-016 and are not touched by this milestone).

---

## Product Principles

- **This is a presentation reorganization, not a new feature.** Every field, every operation, and every underlying query this milestone relies on already exists in MFS-015/MFS-016. If achieving a requirement in this document appears to need a schema change or a new repository capability, that requirement is out of scope for this milestone, not a reason to introduce one.
- **Grouping by model is a read-time, presentation-only concern.** This mirrors the exact precedent already established for the Personal Tackle Box's own manufacturer/model grouping (MFS-016): derived from an already-sorted flat query result in a single pass, never a new persisted grouping entity and never a new query shape.
- **Adding a lure must always be a deliberate act.** Dismissing a dialog, backing out of a screen, or any other "I changed my mind" gesture must never be interpreted as an implicit choice to proceed. Only an explicit, affirmative choice (Camera, Gallery, or a clearly labeled "No Photo") completes an add.
- **No information is lost, only reorganized.** Every field the Lure Catalog and Personal Tackle Box already display must remain reachable; this milestone changes *where* and *how* it is grouped, not what exists.

---

## User Stories

**As an angler**
I want the Lure Catalog list to show one row per lure model
So that I can scan the catalog without seeing the same model repeated once per color.

**As an angler**
I want to open a lure model and see every color it comes in
So that I can compare colors, sizes, and weights before deciding which one to add.

**As an angler**
I want to see at a glance which colors of a model I already own
So that I don't have to remember or re-check before adding another one.

**As an angler**
I want to add a specific color straight from that list
So that adding a lure to my tackle box doesn't require an extra screen per color.

**As an angler**
I want backing out of the "add a photo" step — by tapping outside the dialog, using the back gesture, or an explicit Cancel — to never add anything
So that I never end up with a lure in my tackle box that I didn't mean to add yet.

---

## Current Behavior (for contrast)

- The Lure Catalog browsing list (MFS-015 FR-1) shows one row per `LureVariant`; a model with, say, four colors appears as four separate rows.
- Selecting a row opens a read-only details view for that one variant (MFS-015 FR-4), including an "Add to Tackle Box" action for that single color only (MFS-016 FR-3).
- The photo-source dialog shown when adding a lure offers Camera, Gallery, or "No Photo." Dismissing the dialog any other way (tapping outside it, or the system back gesture) currently resolves the same way as choosing "No Photo" — the lure is added anyway, with no photo. This is the specific behavior this milestone corrects.

---

## Functional Requirements

### FR-1 — Catalog List Groups by Lure Model

The Lure Catalog browsing list must show exactly one entry per `LureModel` that has at least one non-retired variant, never one entry per variant. A model with zero non-retired variants must not appear, exactly as today (MFS-015/MFS-016 precedent).

### FR-2 — Selecting a Model Opens Lure Model Details

Selecting a catalog entry from the browsing list opens a Lure Model Details view for that model. This replaces the single-variant Lure Details view MFS-015 FR-4 introduced as the browsing list's destination.

### FR-3 — Model-Level Information Shown Once

The Lure Model Details view must display the model-level information that does not vary between its variants, shown once at the top of the view: manufacturer, model name, product family/series (if present), and lure type. This is a subset of the fields already defined on `LureModel` (MFS-015, Conceptual Data Model) — no new field is introduced.

### FR-4 — Color Variants List

Below the model-level information, the view must show a clearly labeled section (e.g. "Color Variants") listing every non-retired variant of that model. Each row must display, at minimum:

- the variant's image (or a placeholder, per the existing image-fallback behavior)
- the color/variant-distinguishing name
- length (if present)
- weight (if present)
- whether the variant is already in the user's Personal Tackle Box (the owned indicator already established by MFS-016)
- an action to add that specific variant to the Personal Tackle Box

### FR-5 — Full Variant Detail Remains Reachable

MFS-015 FR-4 required a variant's complete field set — including running depth range, buoyancy, and the manufacturer's own color code, when present — to be displayable. This milestone's compact Color Variants row (FR-4) does not repeat all of those fields inline, but every one of them must remain reachable from that row (for example, by tapping the row itself, separately from its add action). No field previously displayable under MFS-015 becomes permanently hidden as a result of this milestone. The exact presentation of this expanded detail — an expandable row, a secondary view, or something else — is a Technical Design decision.

### FR-6 — Opening a Model Always Shows All of Its Variants

Opening a Lure Model's Details view always shows the complete, unfiltered set of that model's non-retired variants, regardless of what search text or filters were active on the browsing list when the model was selected. Search and filtering (unchanged, MFS-015) continue to determine which *models* appear in the browsing list; they never narrow which variants appear once a model's Details view is open.

### FR-7 — Adding a Variant Creates Exactly One Personal Tackle Box Entry

Choosing to add a specific variant from the Color Variants list must create exactly one `TackleBoxEntry` referencing that variant — the same underlying operation MFS-016 FR-3 already defines, reached from a different screen. Nothing about what gets created, or the duplicate-prevention guarantee already enforced at the database layer (MFS-016 FR-7), changes.

### FR-8 — Owned Indicator Per Variant

Each row in the Color Variants list must independently reflect whether that specific variant is already owned, using the same ownership-state mechanism already established by MFS-016 (FR-6's "reflect existing ownership state" requirement) — applied per row instead of once per single-variant page.

### FR-9 — Variant List Scalability

The Color Variants list must use lazy/virtualized rendering, so a model with a large number of variants does not build or hold every row in memory at once — the same discipline MFS-015's Performance Expectations already require of the top-level catalog list, extended one level down.

### FR-10 — Add-Photo Dialog Never Completes an Add on Dismissal

The dialog shown when adding a variant must distinguish between an explicit choice and a dismissal:

- Choosing Camera, Gallery, or an explicit "No Photo" option completes the add, exactly as today.
- Tapping outside the dialog (the modal barrier) must cancel the entire add attempt. No `TackleBoxEntry` is created.
- The Android system back action must have the same effect as tapping outside the dialog: cancel the entire add attempt.
- The dialog must also offer an explicit, clearly labeled Cancel option, distinct from "No Photo," with the same effect.

Only an explicit Camera, Gallery, or "No Photo" choice may result in a `TackleBoxEntry` being created. Every other way of leaving the dialog must leave the tackle box completely unchanged.

### FR-11 — Cancelling One Variant's Add Does Not Affect Others

Because the Color Variants list can show an add action on multiple rows at once, cancelling or dismissing the add-photo dialog for one variant must only affect that variant's row (returning it to its normal, not-yet-owned state). It must not change the loading, owned, or busy state of any other row on the same screen.

### FR-12 — Existing Behavior Otherwise Unchanged

Everything not explicitly changed by this milestone continues to work exactly as already specified: search, filtering by manufacturer/lure type, Finnish (ä/ö) case-insensitive matching, offline operation, the Lure Catalog's read-only nature, and the Personal Tackle Box's own browsing view and Owned Entry Detail view (already grouped by manufacturer/model per MFS-016, and not touched by this milestone).

---

## Navigation

```text
Lure Catalog (browse/search/filter by model)
        ↓
Lure Model Details
  (manufacturer, model name, product family, lure type)
        ↓
Color Variants
  (image, color, length, weight, owned indicator, Add — per variant)
        ↓
[Add pressed on a variant, not yet owned]
        ↓
Add-photo dialog: Camera | Gallery | No Photo | Cancel
  (tapping outside, or system back, behaves exactly like Cancel)
        ↓
Entry saved — confirmation shown; that row now reflects "owned"
```

Tapping a variant row that is already owned must not re-open the add-photo dialog — it reflects its owned state, consistent with the existing already-owned behavior (MFS-016 FR-6).

Adding to the Personal Tackle Box continues to originate only from the Lure Catalog flow (MFS-016 FR-1); this milestone does not add a second, parallel way to reach it.

---

## Empty, Loading, and Error States

- **Model list loading:** while the (now model-grouped) catalog is being read, the browsing view shows a clear loading indicator, exactly as today.
- **Empty search/filter result:** unchanged from MFS-015 — a clear "no results" message, distinct from loading or error states, shown when no model matches the active search/filter.
- **Variant list loading within Lure Model Details:** as implemented, a model's variants are resolved *before* the Lure Model Details view is opened (see TD-018), so the view itself never shows a partial or loading state for its own Color Variants section — by the time it is on screen, its content is already fully resolved. If resolving those variants fails, the browsing list surfaces a clear error message and does not navigate, rather than opening a broken or partially-loaded view.
- **A model with zero non-retired variants:** not expected to occur — such a model is already excluded from the browsing list (FR-1) — but if reached directly, the Color Variants section shows a clear message rather than an empty-looking blank area.
- **Add-photo failure states** (permission denial, pick failure): unchanged from MFS-016 — the add still completes without a photo, with a clear message, exactly as already specified. Only the *dismissal* behavior (FR-10) changes, not error handling.

---

## Accessibility Expectations

- Each entry in the model-grouped browsing list exposes a semantic label combining manufacturer and model name, mirroring MFS-015's existing accessibility requirement.
- Each row in the Color Variants list exposes a semantic label for its color/variant-distinguishing detail; the add action on that same row exposes its own independent accessible label reflecting owned state ("Lisää vieherasiaan" when addable, "Vieherasiassa" when already owned), mirroring MFS-016's existing accessibility requirement for owned-state badges.
- The add action on each variant row has a clear, unambiguous accessible label distinguishing it from merely viewing the row, consistent with MFS-016's existing requirement for the "Add to Tackle Box" action.
- The add-photo dialog's Camera / Gallery / No Photo / Cancel options each have a distinct accessible label.
- Tap targets throughout this milestone meet the application's existing Material 3 sizing conventions, and all text supports standard system text scaling.

---

## Feature Ownership and Placement

This milestone touches presentation only, within the features already established:

- The Lure Catalog browsing list and Lure Model Details view remain owned by the `lure_catalog` feature. Its domain model, data layer, and repository remain unmodified and fully read-only (MFS-015).
- The add-to-tackle-box interaction (per-variant add action, photo dialog) remains owned by the `personal_tackle_box` feature, reached from `lure_catalog`'s presentation layer via the same kind of narrow, generic touch already established in TD-016 (an optional builder/parameter, not a new dependency in the other direction).
- No new feature directory is introduced.

---

## Acceptance Criteria

- The Lure Catalog browsing list shows exactly one entry per lure model with at least one non-retired variant — never one entry per variant.
- Selecting a model opens a Lure Model Details view showing manufacturer, model name, product family (if present), and lure type once.
- Every non-retired variant of that model is visible in the Color Variants list, regardless of any search/filter that was active when the model was opened.
- Each variant row shows its image, color/distinguishing name, length (if present), weight (if present), and its owned status.
- Every field MFS-015 required to be displayable for a variant (including running depth, buoyancy, and manufacturer color code) remains reachable from its row.
- Adding a variant creates exactly one `TackleBoxEntry` referencing that variant — never more than one, and never for the wrong variant.
- Owned variants are clearly and independently identified per row.
- Dismissing the add-photo dialog by tapping outside it never creates a `TackleBoxEntry`.
- The Android back action from the add-photo dialog never creates a `TackleBoxEntry`.
- An explicit Cancel option exists in the add-photo dialog and never creates a `TackleBoxEntry`.
- Choosing Camera, Gallery, or an explicit "No Photo" still completes the add exactly as before.
- Cancelling one variant's add attempt does not change any other variant row's state on the same screen.
- The Color Variants list remains responsive and does not build every row eagerly when a model has many variants.
- No change to the `lure_catalog` or `personal_tackle_box` domain models, database schema, or repository contracts is required or made.
- `flutter analyze` passes.
- Automated tests cover: model-grouped list rendering, opening a model's full variant list, adding a variant from that list, the owned indicator per row, and every dismissal path (tap-outside, system back, explicit Cancel) of the add-photo dialog failing to create an entry.

---

## Out of Scope

- Search redesign
- Filtering redesign
- Sorting redesign
- Statistics or analytics of any kind
- Recommendations
- Any change to the `lure_catalog` domain model, database schema, or repository contract
- Any change to the `personal_tackle_box` domain model, database schema, or repository contract
- Any change to the Personal Tackle Box's own browsing view or Owned Entry Detail view
- Variant filtering within a single model's Color Variants list
- Favorite variants
- Stock/availability status
- Quick-add shortcuts (e.g. adding without opening Lure Model Details)
- Editing or replacing an already-added variant's personal photo (unchanged from MFS-016)
- Cloud synchronization

---

## Relationship to Previous MFS Documents

- **MFS-015 (Lure Catalog Foundation)** defined the browsing list as one row per variant (FR-1) and a single-variant read-only details view (FR-4). This milestone reorganizes both into a model-grouped list and a per-model details view listing all variants, without changing any of the underlying data MFS-015 defined. FR-5 of this document explicitly preserves every field MFS-015 FR-4 required to be displayable.
- **MFS-016 (Personal Tackle Box Foundation)** already sketched an intermediate "Lure Model (color variants)" step in its own Navigation diagram, ahead of "Select a color variant" and the "Add to Tackle Box" action — but the shipped implementation reached that step through a flat, per-variant list rather than a dedicated per-model variant view. This milestone completes that originally-sketched step. MFS-016's ownership-indicator mechanism (FR-6), duplicate-prevention guarantee (FR-7), and the add operation itself (FR-3) are reused unchanged, only reachable from a different screen.
- **TD-016**'s Key Design Decision 3 ("grouping is a presentation-only concern," established for the Personal Tackle Box's own manufacturer/model grouping) is the direct precedent this milestone's model-grouping requirement follows.

---

## Dependencies

No new external dependencies. This milestone reuses the existing stack and patterns:

- Flutter, Dart
- The existing Repository pattern and feature-first structure (ADR-0001, ADR-0003, ADR-0006)
- `LureCatalogRepository`'s existing `browse()`/`getEntryById()` queries (MFS-015/TD-015), unmodified
- `PersonalTackleBoxRepository`'s existing `isOwned()`/`add()` operations (MFS-016/TD-016), unmodified
- The existing image-fallback, accessibility, and Material 3 conventions already established across the Lure Catalog and Personal Tackle Box

---

## Future Extensions

Mentioned here so they are not rediscovered, but explicitly not part of this milestone:

- Filtering variants within a single model's Color Variants list (e.g. by size)
- Favorite variants
- Stock/availability status
- Quick-add shortcuts that skip Lure Model Details entirely
