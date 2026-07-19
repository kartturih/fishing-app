# MFS-017 — Assign Lure to Catch

## Status

Draft

## Related

- Depends on: MFS-009 — Catch Foundation
- Depends on: MFS-010 — Add Catch
- Depends on: MFS-012 — Edit & Delete Catch
- Depends on: MFS-014 — Catch Details View
- Depends on: MFS-015 — Lure Catalog Foundation
- Depends on: MFS-016 — Personal Tackle Box Foundation
- Future: Lure-Based Catch Statistics (see `docs/roadmap.md`)

---

## Purpose

Let an angler record **which lure they actually own was used to make a catch**, when logging a new catch or editing an existing one.

This milestone connects the two data chains the application has built up separately so far — `Catch` (MFS-009/010/012/014) and the user's `Personal Tackle Box` (MFS-015/016) — without merging them into one feature and without duplicating data between them. A catch may optionally reference one lure from the angler's own tackle box; nothing about this milestone changes how catches or lures otherwise work.

---

## User Value

Anglers have been able to log catches (MFS-009–MFS-014) and track which lures they own (MFS-015/016) as two independent capabilities. This milestone lets those two histories intersect:

- An angler can note which of their own lures caught a fish, at the moment they log it.
- An angler reviewing a past catch can see which lure was used, alongside the rest of that catch's details.
- This becomes the foundation for a later, separate milestone that summarizes catch history by lure (see [Future Extensions](#future-extensions)) — this milestone only creates the reference; it does not summarize or analyze it.

---

## Scope

### In Scope

- An optional reference from a `Catch` to a specific lure the angler owns.
- Assigning a lure when creating a new catch (extends MFS-010's Add Catch flow).
- Assigning, changing, or removing a lure when editing an existing catch (extends MFS-012's Edit & Delete Catch flow).
- Displaying the assigned lure's identifying details in the read-only Catch Details view (fulfils the "lure" display slot MFS-014 already reserved for this — see [Relationship to Previous MFS Documents](#relationship-to-previous-mfs-documents)).
- Reusing the existing Personal Tackle Box browsing experience (MFS-016) as the only way to pick a lure to assign.
- Fully offline operation, consistent with every other feature in the application.

### Out of Scope

See [Out of Scope](#out-of-scope-1) for the complete list. Notably: assigning more than one lure to a single catch, lure-based statistics, showing the assigned lure in the catch list (only in Catch Details), assigning a lure the user does not own, and any change to the Lure Catalog or Personal Tackle Box's own scope or behavior.

---

## User Stories

**As an angler**
I want to record which of my own lures caught a fish when I log the catch
So that my fishing history reflects what actually worked.

**As an angler**
I want to add or change which lure is associated with a catch after the fact
So that I can correct a mistake or fill in a detail I skipped when logging quickly.

**As an angler**
I want to remove a lure from a catch without deleting the catch itself
So that I can undo an incorrect assignment.

**As an angler**
I want to log a catch without assigning a lure at all
So that recording a catch is never blocked or slowed down by this feature.

**As an angler**
I want to see which lure I used when I look back at a catch's details
So that I can remember what worked the next time I'm in similar conditions.

**As an angler**
I want my catch history to still show the correct lure even after I no longer own it
So that removing a lure from my tackle box doesn't erase what I know worked in the past.

---

## Conceptual Relationship

This section resolves, at the product level, the one open question MFS-016 deliberately left for this milestone: whether a `Catch` should reference a `TackleBoxEntry` (an ownership record) or a `LureVariant` (a stable catalog identity). Exact field placement and persistence design remain a Technical Design (TD-017) concern; the relationship itself is a product decision that belongs here.

```text
Personal Tackle Box (owned lures)
        ↓ (assignment is only ever chosen from here)
LureVariant  ← ← ← ← ← ← ← ←  Catch (optional reference)
        ↑
Lure Catalog (shared reference data)
```

**A catch's stored reference points to the catalog `LureVariant`, not to the `TackleBoxEntry`.** Ownership (the Personal Tackle Box) governs *what can be picked at the moment of assignment* — an angler can only assign a lure they currently own — but the catch's own record of "which lure was used" must survive that lure later being removed from the tackle box. `TackleBoxEntry` rows are permanently deleted on removal (MFS-016 FR-8); `LureVariant` identifiers are never deleted, only ever retired-and-still-resolvable (MFS-015, Identity). Anchoring the catch's reference to the `LureVariant` — the same way `Catch` already anchors its fishing-spot reference to `FishingSpot.id` rather than to some other transient record (MFS-009) — is the only choice that keeps a catch's lure history stable and correct after the tackle box changes.

A practical consequence: if an angler removes a lure from their tackle box and later adds the same real-world lure back, the tackle box treats that as a brand-new `TackleBoxEntry` (MFS-016 does not preserve identity across a remove-and-re-add). Because catches reference the catalog variant and not the tackle box entry, this re-adding has no effect whatsoever on any catch that was already assigned that lure — it was never linked to the removed entry in the first place.

This mirrors the "reference, not copy" rule already established by MFS-016 for the Personal Tackle Box's relationship to the Lure Catalog: a `Catch` must never duplicate lure metadata (manufacturer, model name, color, and so on). Manufacturer/model/color information shown for an assigned lure is always resolved live from the Lure Catalog at the time it is displayed, never from a stored snapshot.

---

## Functional Requirements

### FR-1 — Assign a Lure When Logging a New Catch

When adding a new catch (MFS-010), the user must be able to optionally assign a lure from their Personal Tackle Box before saving. Skipping this step must never block or delay saving the catch — an unassigned catch is a fully valid, complete record, exactly as it is today.

### FR-2 — Only Owned Lures Are Assignable

The lure picker must show only lures currently present in the user's Personal Tackle Box (MFS-016). The full Lure Catalog (MFS-015) must not be directly reachable from this flow — an angler cannot assign a lure they have not added to their tackle box first.

### FR-3 — Assign, Change, or Remove a Lure When Editing a Catch

When editing an existing catch (MFS-012), the user must be able to:

- assign a lure to a catch that currently has none,
- change the previously assigned lure to a different owned lure, and
- remove the assignment entirely, leaving the catch with no assigned lure.

These follow the same optional, clearable pattern already established for weight and length in MFS-012 (FR-11 of that milestone).

### FR-4 — Display the Assigned Lure in Catch Details

The read-only Catch Details view (MFS-014) must display the assigned lure's identifying details — at minimum, manufacturer, model, and the color/variant detail that distinguishes it from sibling variants (consistent with how the Lure Catalog and Personal Tackle Box already present a variant, per MFS-015/MFS-016). A catch with no assigned lure must render cleanly, with no empty or broken UI element — the same "missing optional value" discipline used throughout the application.

### FR-5 — No Lure Display in the Catch List

The catch list (MFS-011) is not changed by this milestone. It continues to show only species, measurements, date/time, and the photo thumbnail introduced by MFS-014. Showing lure information in the list is explicitly deferred (see [Out of Scope](#out-of-scope-1)).

### FR-6 — Historical Stability

A catch's assigned lure must remain fully resolvable and correctly displayed even after the referenced lure is later removed from the user's Personal Tackle Box. Removing a `TackleBoxEntry` must never alter, hide, or invalidate any catch that was previously assigned that lure.

### FR-7 — Retired Catalog Variants Remain Resolvable

If the assigned `LureVariant` is no longer part of the actively presented Lure Catalog in a later catalog update (MFS-015's retirement mechanism), the catch's assigned lure must remain visible and correctly displayed, exactly as a retired variant already remains resolvable elsewhere in the application (MFS-016 FR-9).

### FR-8 — One Lure Per Catch

A catch may have at most one assigned lure in this milestone. Assigning a new lure to a catch that already has one must replace the previous assignment, not add a second one. Supporting multiple lures per catch is a future extension, not part of this milestone.

### FR-9 — No Assignment Uniqueness Constraint

Unlike Personal Tackle Box ownership (MFS-016 FR-7, which prevents owning the same catalog variant twice), there is no uniqueness constraint on assignment: the same owned lure may be assigned to any number of different catches, since an angler naturally reuses the same physical lure across many fishing trips.

### FR-10 — Offline Operation

Every capability in this milestone must work with no network connection, consistent with the rest of the application.

---

## UI Expectations

- Assigning a lure is reached through an explicit, clearly labeled action from the Add Catch and Edit Catch flows (e.g. a distinct "select a lure" affordance) — it must not be implicit, and must not happen as a side effect of any other field.
- The lure picker reuses the Personal Tackle Box's existing grouped browsing presentation (by manufacturer, then model, per MFS-016 FR-5) rather than introducing a second, differently organized way to locate an owned lure.
- Once a lure is assigned, the Add/Edit Catch form must show enough identifying detail (manufacturer, model, distinguishing color/variant detail) for the angler to recognize which physical lure is selected, together with a clear way to change or remove the selection before saving.
- If the Personal Tackle Box is empty, the assign action must show a clear message that no lures have been added yet, together with an explicit action that navigates the user directly to the Personal Tackle Box — not merely a message with no way to act on it, and not toward the Lure Catalog directly, consistent with [FR-2](#fr-2--only-owned-lures-are-assignable).
- In Catch Details, the assigned lure is presented as read-only information alongside the catch's other fields, following the same visual and accessibility conventions already used for lure information in the Lure Catalog and Personal Tackle Box (including image fallback: personal photo, then catalog image, then a neutral placeholder, per MFS-016).
- Assigning, changing, or removing a lure is only ever possible through Add Catch or Edit Catch in this milestone. This milestone does not support editing the lure assignment directly from Catch Details, consistent with MFS-014's read-only principle (FR-10 of that milestone); a future milestone may reconsider this without contradicting this specification.

---

## Data Ownership

- This milestone extends the existing **Catches** feature; it does not introduce a new feature directory. The referencing side of a relationship owns the reference, exactly as `Catch` already owns its reference to `FishingSpot.id` (MFS-009) and `TackleBoxEntry` already owns its reference to `LureVariant.id` (MFS-016).
- The Lure Catalog feature (MFS-015) and the Personal Tackle Box feature (MFS-016) remain entirely unmodified by this milestone. Neither gains any new concept of "used in a catch," and neither exposes any new write operation to the Catches feature.
- The Catches feature never duplicates lure catalog data. Manufacturer, model, color, and any other lure detail shown for an assigned lure is resolved live from the Lure Catalog at read time, never stored on the `Catch` itself.
- The Catches feature may read from the Personal Tackle Box (to offer the assignment picker) and from the Lure Catalog (to resolve display details for an assigned lure), following the same read-only, reference-based access pattern already established between Personal Tackle Box and Lure Catalog.

---

## Empty, Loading, and Error States

- **No lure assigned:** the default and fully valid state for any catch, old or new. Catch Details must render with no empty placeholder row for an absent lure.
- **Empty Personal Tackle Box when assigning:** the picker must show a clear message that no lures have been added yet, together with an explicit call-to-action that navigates directly to the Personal Tackle Box — not an empty-looking list, and not a message alone with no way to act on it.
- **Assignment read failure:** if the assigned lure's details cannot be read when displaying a catch, the application must not crash. It must show a clear fallback indication that the lure's details are currently unavailable, consistent with how a missing/unresolvable catalog reference is already handled in MFS-016 (Error Handling — "Referenced catalog variant not found").
- **Save failure while assigning:** if saving a catch fails while a lure assignment is pending, the same catch-save failure handling already defined in MFS-010/MFS-012 applies — the form remains open, entered values (including the pending lure selection) are preserved, and the user can retry.

---

## Edge Cases

- Removing a `TackleBoxEntry` that is assigned to one or more catches must not alter, hide, or break those catches (see [FR-6](#fr-6--historical-stability)).
- Re-adding a previously removed lure to the Personal Tackle Box creates an unrelated `TackleBoxEntry`; it has no effect on catches assigned before the removal, since those reference the stable catalog variant, not the tackle box entry (see [Conceptual Relationship](#conceptual-relationship)).
- A catalog variant retired in a later Lure Catalog update remains fully resolvable in any catch it was already assigned to (see [FR-7](#fr-7--retired-catalog-variants-remain-resolvable)).
- Deleting a catch (MFS-012) removes only that catch. It must have no effect on the Personal Tackle Box, the Lure Catalog, or any other catch — including one assigned the same lure.
- Assigning or changing a lure while a save is already in progress must be prevented, consistent with the duplicate-action safeguards already defined in MFS-012.
- Canceling out of Add Catch or Edit Catch without saving must discard any pending lure selection, exactly as it already discards other unsaved field changes.
- In the unexpected case that an assigned `LureVariant` cannot be resolved at all (not merely retired, but genuinely missing), the catch must still display without crashing, with a clear fallback indication, and must remain fully viewable, editable, and deletable.

---

## Accessibility Expectations

- The lure assignment action must have a clear, unambiguous accessible label distinguishing it from simply viewing a lure.
- The assigned lure, wherever displayed, must expose a semantic label combining manufacturer, model, and distinguishing color/variant detail — not just decorative text — mirroring the accessibility requirement already established for the Lure Catalog (MFS-015) and Personal Tackle Box (MFS-016).
- The "no lure assigned" state must be conveyed accessibly, not only through visual absence.
- Tap targets for the assignment action and picker must meet the application's existing Material 3 sizing conventions.
- All text must respect the existing application theme and support standard system text scaling.

---

## Feature Ownership and Placement

Following the existing feature-first structure and database ownership rules (ADR-0003, ADR-0006), this milestone extends the **Catches** feature:

```text
lib/
└── features/
    └── catches/
        ├── data/
        ├── domain/
        └── presentation/
```

The Catches feature gains a new optional relationship from `Catch` to a `LureVariant` (owned by the Lure Catalog feature, MFS-015). This mirrors the existing, already-established relationship between `Catch` and `FishingSpot` (MFS-009): the referencing feature (`catches`) owns the reference field; the referenced feature (`lure_catalog`) is read from, never modified. The Personal Tackle Box feature (`personal_tackle_box`) is read from only to present the assignment picker and is likewise never modified.

Exact field placement, persistence, and query design are Technical Design (TD-017) concerns.

---

## Acceptance Criteria

- A catch can be created with no assigned lure, exactly as it can be today.
- A catch can be created with exactly one assigned lure, chosen only from the user's current Personal Tackle Box.
- Assigned lure information persists after application restart.
- An existing catch's lure assignment can be added, changed, or removed through Edit Catch.
- The Lure Catalog is never directly reachable from the assignment flow — only owned lures (Personal Tackle Box) can be assigned.
- The read-only Catch Details view displays the assigned lure's manufacturer, model, and distinguishing detail when present, and renders cleanly when absent.
- The catch list is unchanged by this milestone.
- Removing a lure from the Personal Tackle Box does not alter, hide, or break any catch that was previously assigned that lure.
- A retired Lure Catalog variant assigned to a catch remains fully resolvable and correctly displayed.
- The same owned lure can be assigned to any number of different catches.
- A catch has at most one assigned lure.
- Deleting a catch has no effect on the Personal Tackle Box, the Lure Catalog, or any other catch.
- Save failures while assigning preserve the pending selection and allow retry, consistent with existing Add/Edit Catch failure handling.
- The Lure Catalog feature and Personal Tackle Box feature are functionally and structurally unchanged by this milestone.
- Every capability in this milestone works with no network connection.
- `flutter analyze` passes.
- Automated tests cover: assigning a lure at creation, assigning/changing/removing a lure during edit, historical stability after tackle box removal, retired-variant resolution, and Catch Details rendering with and without an assigned lure.

---

## Out of Scope

- Assigning more than one lure to a single catch
- Assigning a lure the user does not currently own (bypassing the Personal Tackle Box)
- Showing the assigned lure in the catch list (Catch Details only, in this milestone)
- Lure-based catch statistics or aggregation of any kind
- Recommendations based on lure/catch history
- Catch notes (a separate, independently deferred future milestone — see MFS-009's Future Milestones and `docs/roadmap.md`)
- Weather or environmental data on catches
- Any change to the Lure Catalog's read-only nature or data model (MFS-015)
- Any change to the Personal Tackle Box's scope, data model, or removal behavior (MFS-016)
- Editing a catch's assigned lure from the catch list directly (must go through Edit Catch, consistent with MFS-012)
- Cloud synchronization

---

## Relationship to Previous MFS Documents

- **MFS-009 (Catch Foundation)** established `Catch` as a framework-independent domain model referencing `FishingSpot.id`, and explicitly listed "Lure information" among its expected Future Milestones. This milestone delivers that, following the same reference-by-id pattern already used for the fishing-spot relationship.
- **MFS-010 (Add Catch)** and **MFS-012 (Edit & Delete Catch)** defined the catch creation and editing flows this milestone extends with an optional lure-assignment step, following the same optional-field, clearable pattern already used there for weight and length.
- **MFS-014 (Catch Details View)** already listed "lure" among the fields its read-only view "must support displaying" (FR-2), without any feature populating it. This milestone is what finally gives that display slot real data.
- **MFS-015 (Lure Catalog Foundation)** established the stable, never-reassigned `LureVariant` identity this milestone anchors its reference to, and explicitly named this milestone in its own Future Extensions.
- **MFS-016 (Personal Tackle Box Foundation)** established that only owned lures may be meaningfully "used," and explicitly left open — for this milestone to resolve — whether a catch should reference a `TackleBoxEntry` or a `LureVariant` (see [Conceptual Relationship](#conceptual-relationship) for the resolution).

---

## Dependencies

No new external dependencies are required. This milestone reuses the existing stack and patterns:

- Flutter, Dart
- Drift (local persistence, per ADR-0005)
- The existing Repository pattern and feature-first structure (ADR-0001, ADR-0003, ADR-0006)
- The existing `Catch` domain model and its established reference-by-id relationship to `FishingSpot` (MFS-009)
- The Lure Catalog domain model and read-only queries from MFS-015
- The Personal Tackle Box domain model, ownership queries, and grouped browsing presentation from MFS-016

---

## Future Extensions

This milestone is expected to support, in later milestones:

- Lure-Based Catch Statistics (which lure produced the most/best catches — the next milestone named in `docs/roadmap.md`)
- Multiple lures assigned to a single catch (e.g. trolling with more than one lure at once)
- Showing assigned-lure information in the catch list, if it proves valuable once this milestone is in real use
- Filtering or sorting catches by assigned lure
- Smart lure or fishing recommendations built on top of accumulated lure/catch history (per `docs/roadmap.md`)
