# MFS-016 — Personal Tackle Box Foundation

## Status

Implemented — architecture-reviewed, all automated tests passing, and physical Android verification completed. See TD-016 for the technical design and `docs/project-status.md` for the verification record.

## Related

- Depends on: MFS-015 — Lure Catalog Foundation
- Future: MFS-017 — Assign Lure to Catch

---

## Summary

Introduce the **Personal Tackle Box**: the set of lure color variants a specific user actually owns.

The global Lure Catalog (MFS-015) is a shared, read-only reference library of commercially available lure products. It answers "what lures exist." The Personal Tackle Box answers a different question — "what lures do I have" — and is entirely user-owned, local data.

This milestone lets the user browse the catalog, deliberately add a specific color variant to their own tackle box, optionally attach a personal photo of the physical item they own, browse their owned lures grouped by manufacturer and model, and remove entries they no longer own. It does not introduce quantity tracking, notes, purchase history, or any connection to catch logging.

---

## Goal

Establish the Personal Tackle Box as the foundation that future fishing workflows — catch logging, statistics, recommendations, analytics — will build on, so that those features operate against **what the user owns**, never against the full global catalog.

Concretely, this milestone must:

- Introduce a `TackleBoxEntry` domain concept representing ownership of one specific `LureVariant`.
- Let the user add a catalog variant to their tackle box through an explicit, deliberate action.
- Let the user optionally attach a personal photo to an owned entry.
- Let the user browse their tackle box, grouped by manufacturer and model rather than as a flat variant list.
- Let the user remove an owned entry, including cleanup of its personal photo.
- Keep the Lure Catalog itself completely unchanged and still read-only.
- Work fully offline, consistent with every other feature in the application.

---

## Product Principles

- **Offline-first.** Every capability in this milestone must work with no network connection.
- **The catalog is a library, not an inventory.** Browsing the catalog never implies ownership. Ownership exists only in the Personal Tackle Box.
- **Ownership is explicit.** Viewing or selecting a color must never silently create an owned entry. Adding a lure requires a deliberate, distinct user action.
- **Feature-first architecture.** The Personal Tackle Box is its own feature, owning its own data, distinct from the Lure Catalog feature and the future Catch feature integration.
- **Keep the scope intentionally small.** This milestone models ownership and nothing else — no speculative functionality, no unnecessary complexity.
- **Grouped by reality, not by row count.** A tackle box is naturally organized by manufacturer and model, not as a flat list of individually named rows; the browsing experience must reflect that.

---

## User Stories

**As an angler**
I want to add a specific lure color I own to my personal tackle box
So that the app reflects lures I actually have, not just the full catalog.

**As an angler**
I want to attach a photo of my own copy of a lure
So that I can visually recognize the specific item I own, including wear or modifications not shown in the catalog photo.

**As an angler**
I want to skip adding a photo when adding a lure
So that adding a lure to my tackle box is never blocked by not having a photo ready.

**As an angler**
I want to browse my tackle box grouped by manufacturer and model
So that I can find what I own the same way I think about my gear, without scanning a long flat list.

**As an angler**
I want to remove a lure from my tackle box
So that the app stays accurate when I lose, retire, or give away a lure.

**As an angler**
I want my tackle box to keep working even if a catalog entry is later retired
So that removing a product from the catalog doesn't silently break or hide the gear I own.

---

## Conceptual Data Model

This section defines the concepts at the specification level. Exact Drift table design, indexing, and identifier format are Technical Design (TD-016) concerns.

### TackleBoxEntry

```text
TackleBoxEntry
├── id
├── lureVariantId       (required — references LureVariant, MFS-015)
├── personalPhotoReference (optional — a reference to a user-owned photo file)
├── addedAt              (required)
├── createdAt
└── updatedAt
```

A `TackleBoxEntry` represents ownership of exactly one `LureVariant`. It does not duplicate any catalog data (manufacturer, model name, color, dimensions, etc.) — that information is always resolved by looking up the referenced `LureVariant`, the same way `Catch` resolves `FishingSpot` data by reference rather than by copy.

`TackleBoxEntry` deliberately does not include a quantity, price, condition, or notes field. Owning a lure is a boolean fact represented by the existence of the entry itself, not a quantity to be tracked.

### Personal photo, not catalog photo

`personalPhotoReference` belongs to the `TackleBoxEntry`, never to the `LureVariant` or `LureModel`. It follows the same storage convention already established for `CatchPhoto` (MFS-013): a reference to an application-owned file, never embedded binary data and never a path into the original camera roll or gallery. A `TackleBoxEntry` with no personal photo simply has `personalPhotoReference == null` and falls back to displaying the catalog's own product image, when one exists.

### Grouped presentation, not a new grouping entity

The Personal Tackle Box browsing view presents owned entries grouped by manufacturer, then by model, then by the owned variants under that model:

```text
Rapala
    X-Rap 10
        Firetiger
        Silver
Westin
    Swim
        Official Roach
```

This grouping is a **presentation/query concern**, derived at read time from each `TackleBoxEntry`'s referenced `LureVariant` → `LureModel` → manufacturer chain. It does not require a new persisted grouping entity. The main tackle box list must never present one flat row per owned variant with manufacturer/model repeated on every row.

### Identity and referential integrity

`TackleBoxEntry.lureVariantId` references `LureVariant.id` as defined in MFS-015. Because catalog identifiers are stable and never reassigned to a different real-world product (MFS-015, [Identity](../specifications/MFS-015-lure-catalog-foundation.md#identity)), a `TackleBoxEntry` can safely hold a long-lived reference without needing to duplicate catalog fields defensively.

A `TackleBoxEntry` must never be filtered out, hidden, or blocked from loading based on any current or future "active/retired" status of its referenced catalog variant. This milestone does not add a retired/active flag to the catalog — that remains a possible future catalog concern — but the tackle box query design must not preclude it, and must not assume every referenced `LureVariant` is still an actively promoted catalog entry.

### Catalog synchronization by reference, not by copy

The Personal Tackle Box stores only a reference to a `LureVariant` — it never stores a copy of catalog metadata. This is an architectural property of the feature, not an implementation detail:

- catalog metadata (manufacturer, product family, model name, color, dimensions, images, and so on) is never duplicated into `TackleBoxEntry` or anywhere else in the Personal Tackle Box feature,
- manufacturer/model/variant information shown anywhere in the Personal Tackle Box is always read live from the current Lure Catalog at query time, never from a stored snapshot,
- because ownership is expressed purely as a reference, a future catalog update (a new seed revision, or a future server sync per MFS-015) automatically becomes visible everywhere the owned entry is shown, with no extra step, and
- no synchronization or migration logic is required in the Personal Tackle Box feature when catalog metadata changes — there is nothing to keep in sync, because nothing catalog-owned is ever copied.

This is the same reference-not-copy relationship `Catch` already has with `FishingSpot`, applied here to `TackleBoxEntry` and `LureVariant`.

---

## Functional Requirements

### FR-1 — Browse Catalog as the Entry Point for Adding

Adding a lure to the Personal Tackle Box always starts from the existing, unmodified Lure Catalog browsing and details experience (MFS-015). This milestone does not introduce a second, parallel way to look up lure products.

### FR-2 — Choose a Color Variant Without Owning It

Opening a lure model and viewing its available color variants must never, by itself, create a `TackleBoxEntry`. Selecting or previewing a color is inspection, not ownership.

### FR-3 — Add a Variant to the Personal Tackle Box

From a specific color variant, the user must be able to trigger an explicit, unambiguous "Add to Tackle Box" action.

Triggering this action must:

- create a `TackleBoxEntry` referencing that `LureVariant`, and
- offer the user the option to attach a personal photo before the entry is finalized, or skip that step.

If the variant is already present in the tackle box, the action must not create a duplicate (see FR-7) and must instead reflect the existing ownership state.

### FR-4 — Personal Photo Capture

When adding a lure, the user must be able to:

- take a new photo using the device camera,
- choose an existing photo from the device gallery, or
- skip adding a photo entirely.

Skipping must never block or delay adding the lure. A `TackleBoxEntry` with no personal photo is a fully valid, complete entry.

### FR-5 — Browse the Personal Tackle Box

The user must be able to open a Personal Tackle Box view listing every owned entry, grouped by manufacturer and then by model, as described in [Conceptual Data Model](#conceptual-data-model).

### FR-6 — Owned Entry Detail View

Selecting an owned variant must open an Owned Entry Detail view. This is a presentation layer over the existing `TackleBoxEntry` and its referenced `LureVariant` — not a separate feature — and in this milestone its purpose is limited to:

- displaying the resolved catalog details for the owned lure (manufacturer, model, color, and other available `LureVariant` fields, per MFS-015),
- displaying the entry's personal photo, when present, and
- providing the "Remove from Tackle Box" action (FR-8).

This screen exists to support the current add/browse/remove flow and to give the feature a natural place to grow into later, not to introduce new functionality now. Future capabilities such as replacing the personal photo, adding notes, purchase information, or condition are explicitly out of scope for MFS-016 (see [Out of Scope](#out-of-scope)) and are not implied by this view's existence.

### FR-7 — Duplicate Prevention

One catalog `LureVariant` can exist at most once inside a given user's Personal Tackle Box. The application must prevent creating a second `TackleBoxEntry` for a `LureVariant` that is already owned, both at the UI level (the add action must reflect that the variant is already owned) and at the data level (uniqueness must be enforced independently of the UI).

### FR-8 — Remove an Owned Entry

The user must be able to remove a `TackleBoxEntry` from their tackle box. Removal must require confirmation, consistent with other destructive actions in the application (e.g. photo deletion in MFS-013).

Removing an entry must delete its `TackleBoxEntry` record and, when present, its personal photo file. It must never delete or modify the referenced `LureVariant` or any other catalog data.

### FR-9 — Retired Catalog Variants Remain Usable

If a `LureVariant` referenced by a `TackleBoxEntry` is no longer part of the actively presented catalog in a future catalog update, the corresponding `TackleBoxEntry` must:

- remain visible in the Personal Tackle Box,
- remain fully usable (viewable, and eligible for future features such as catch logging), and
- remain removable.

Nothing in this milestone may cause an owned entry to silently disappear because of a change to shared catalog data.

### FR-10 — Offline Operation

Every capability in this milestone — browsing, adding, photo capture/selection, browsing owned entries, and removal — must work with no network connection, consistent with the rest of the application.

---

## Search

Locating a lure to add to the Personal Tackle Box reuses the existing Lure Catalog search and filter capability defined in MFS-015 (FR-2, FR-3) unchanged. This milestone does not introduce a second, tackle-box-specific search implementation.

The Personal Tackle Box browsing view itself does **not** introduce a dedicated search field in this milestone. A user's tackle box is expected to remain small relative to the full catalog, and the manufacturer/model grouping (FR-5) is expected to be sufficient for locating an owned entry at this scale. Searching within a large personal tackle box is listed under [Future Extensions](#future-extensions) and must not be built speculatively now.

---

## Empty States

- **Empty Personal Tackle Box (no owned lures yet):** the browsing view must show a clear message explaining that no lures have been added yet, with a clear path back to the Lure Catalog to add one. This must be visually distinct from a loading state and from an error state.
- **No personal photo on an entry:** an owned entry without a personal photo must render cleanly, falling back to the catalog's product image when available, or a neutral placeholder when not. This is a normal, expected state — not an error.
- **No color variants available to add:** if a `LureModel` has no variants (should not occur given MFS-015's seed and validation rules, but must be handled defensively), the add flow must not be offered from that model, and no broken or empty add action may be shown.
- **Catalog search/filter empty results** while looking for a lure to add are governed by MFS-015 and are unchanged by this milestone.

---

## Data Requirements

- A framework-independent `TackleBoxEntry` domain concept exists, per [Conceptual Data Model](#conceptual-data-model).
- `TackleBoxEntry.lureVariantId` is required and must reference an existing `LureVariant`.
- `TackleBoxEntry.lureVariantId` must be unique across all tackle box entries — the data layer must enforce this independently of the UI (FR-7).
- `TackleBoxEntry.personalPhotoReference` is optional. Absent means no personal photo, never an empty string or placeholder value.
- `TackleBoxEntry` must not contain a quantity, price, condition, or notes field. Ownership is a boolean fact represented by the entry's existence.
- `TackleBoxEntry.addedAt` records when the user added the lure to their tackle box; `createdAt`/`updatedAt` follow the same conventions used elsewhere in the application (e.g. `Catch`).
- Personal photo files must be stored in application-owned storage, following the same convention as `CatchPhoto` (MFS-013): a relative, application-managed path is stored in the database; no image binary data is stored in SQLite; the original camera/gallery source is never depended upon after the photo is captured or selected.
- Removing a `TackleBoxEntry` must remove its personal photo file, not just its database record (mirrors MFS-013's catch-deletion cleanup requirement).
- No cascading deletion runs from the Lure Catalog into the Personal Tackle Box in this milestone: catalog entries are shipped, read-only reference data that is never deleted by a user action (MFS-015).

---

## Navigation

- A dedicated Personal Tackle Box view is reachable from the application's primary navigation, independent of the Lure Catalog browsing view.
- Adding a lure always originates from the Lure Catalog flow:

```text
Lure Catalog (browse/search)
        ↓
Lure Model (color variants)
        ↓
Select a color variant
        ↓
"Add to Tackle Box" action
        ↓
Optional personal photo step (take photo / choose from gallery / skip)
        ↓
Entry saved — confirmation shown
```

- From the Personal Tackle Box view, selecting an owned entry opens the Owned Entry Detail view (FR-6), combining resolved catalog details with the personal photo. The remove action (FR-8) is available from this view.
- Navigating away from the add flow before completing it (e.g. backing out during the photo step) must not create a partial or draft `TackleBoxEntry`, consistent with the no-draft-records principle already established for catches (MFS-013).

---

## Error Handling

- **Add failure:** if creating a `TackleBoxEntry` fails, no entry is created, no orphaned photo file is left behind, a clear error message is shown, and the user can retry.
- **Duplicate add attempt:** attempting to add a variant already present in the tackle box must not create a second entry or surface a raw database/constraint error; the UI must reflect that the variant is already owned (FR-7).
- **Photo capture/selection failure or denied permission:** the lure can still be added without a photo; a clear message is shown; the add flow is never blocked or aborted by a photo failure alone, consistent with the permission-handling behavior established in MFS-013.
- **Photo storage failure after the entry was created:** the `TackleBoxEntry` remains saved without a photo; the user receives a clear message and can attempt to add a photo again later.
- **Missing or corrupt personal photo file for an existing entry:** the application must not crash; a placeholder is shown in place of the photo; the entry itself, including removal, remains fully usable.
- **Remove failure:** if removal fails, the entry and its photo remain intact, a clear error message is shown, and the user can retry.
- **Referenced catalog variant not found:** in the unexpected case that a `TackleBoxEntry` references a `LureVariant` id that cannot be resolved, the application must not crash; the entry is shown with a clear fallback indication that catalog details are unavailable, and the entry remains removable.

---

## Accessibility

- Grouped tackle box list items must expose a semantic label combining manufacturer, model, and variant-distinguishing detail — not just decorative text — mirroring the accessibility requirement already established for the Lure Catalog (MFS-015).
- The "Add to Tackle Box" action must have a clear, unambiguous accessible label distinguishing it from simply viewing or selecting a color.
- The photo step's three options (camera, gallery, skip) must each have a distinct accessible label.
- Personal photos must have a text alternative for screen reader users; entries with no photo (falling back to catalog image or placeholder) must remain accessible, not just visually indicated.
- The remove confirmation dialog must be fully accessible, including a clear indication that the action is destructive.
- Tap targets throughout this feature must meet the application's existing Material 3 sizing conventions.
- All text must respect the existing application theme and support standard system text scaling.

---

## Feature Ownership and Placement

Following the existing feature-first structure and database ownership rules (ADR-0003, ADR-0006), the Personal Tackle Box is its own feature, distinct from the Lure Catalog feature:

```text
lib/
└── features/
    └── personal_tackle_box/
        ├── data/
        ├── domain/
        └── presentation/
```

The Personal Tackle Box feature owns its `TackleBoxEntry` domain model, its Drift table, its mapper, its repository, and its personal photo file storage lifecycle. It references `LureVariant.id` from the Lure Catalog feature by identifier only — it never duplicates or writes catalog data, and the Lure Catalog feature remains entirely read-only and untouched by this milestone.

---

## Out of Scope

- custom (non-catalog) lures
- favorites
- lure boxes / sub-collections
- tackle boxes inside tackle boxes
- quantity tracking
- purchase price or purchase history tracking
- lure condition tracking
- maintenance tracking
- notes on owned entries
- editing or replacing a personal photo on an already-saved entry (removing and re-adding the entry is the only supported way to change a photo in this milestone)
- search or filtering within the Personal Tackle Box itself
- catch integration / assigning a lure to a catch (MFS-17)
- statistics
- recommendations
- cloud synchronization
- any change to the Lure Catalog's read-only nature or data model

---

## Acceptance Criteria

- A framework-independent `TackleBoxEntry` domain concept exists, referencing a `LureVariant` by id, with an optional personal photo reference and no quantity/price/condition/notes fields.
- The user can browse the Lure Catalog and open a lure model's color variants without creating any tackle box data.
- The user can add a specific color variant to their Personal Tackle Box only through an explicit "Add to Tackle Box" action.
- When adding a lure, the user can take a photo, choose one from the gallery, or skip — and skipping never blocks the add.
- A `LureVariant` can be present in the Personal Tackle Box at most once; the uniqueness constraint is enforced at the data layer, not only in the UI.
- The Personal Tackle Box view lists owned entries grouped by manufacturer, then model, then variant — never as a flat one-row-per-variant list.
- The user can open an owned entry to see resolved catalog details together with its personal photo, when present.
- The user can remove an owned entry, with confirmation required before deletion.
- Removing an entry deletes both its database record and its personal photo file, when one exists.
- A `TackleBoxEntry` whose referenced catalog variant is no longer actively presented in the catalog remains visible, viewable, and removable.
- Personal photos are stored using application-owned storage, following the same convention as `CatchPhoto`; no image binary data is stored in SQLite.
- Backing out of the add flow before completion never leaves a partial or draft `TackleBoxEntry` or an orphaned photo file behind.
- Add failure, photo failure, remove failure, and missing/corrupt photo files are all handled without crashing and without leaving inconsistent data.
- Every capability in this milestone works with no network connection.
- The Lure Catalog feature (MFS-015) is functionally and structurally unchanged by this milestone.
- `flutter analyze` passes.
- Automated tests cover the domain model, repository operations (add, list grouped, get-by-id, remove), duplicate-prevention behavior, and photo lifecycle (create-with-photo, create-without-photo, remove-with-photo-cleanup).

---

## Dependencies

No new external dependencies are required. This milestone reuses the existing stack and patterns:

- Flutter, Dart
- Drift (local persistence, per ADR-0005)
- The existing Repository pattern and feature-first structure (ADR-0001, ADR-0003, ADR-0006)
- The existing camera/gallery photo capture flow and application-owned photo storage pattern established for `CatchPhoto` (MFS-013)
- The Lure Catalog domain model and repository from MFS-015, consumed read-only

---

## Future Extensions

This foundation is expected to support, in later milestones:

- MFS-017 — Assign Lure to Catch, referencing a `TackleBoxEntry` (and/or `LureVariant`) from a `Catch`
- Search and/or filtering within a large Personal Tackle Box
- Replacing or removing a personal photo on an already-saved entry without a full remove-and-re-add
- Reflecting a catalog "retired/active" status, if MFS-015's catalog model ever adds one, as a non-blocking visual indicator on owned entries
- Cloud synchronization of owned entries
- Lure-based catch statistics and recommendations built on top of the Personal Tackle Box rather than the global catalog
