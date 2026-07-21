# MFS-023 — Catch Notes

## Status

Draft

## Related

- Depends on: MFS-009 — Catch Foundation (the `Catch` domain model, `Catches` table, `CatchRepository`, and `CatchMapper` this milestone extends)
- Depends on: MFS-010 — Add Catch (the creation form this milestone adds an input to)
- Depends on: MFS-012 — Edit and Delete Catch (the editing form this milestone adds an input to, and the `EditCatchResult` type this milestone reuses unchanged)
- Depends on: MFS-014 — Catch Details View (the read-only view this milestone's note is displayed in — see [Conceptual Model](#notes-fills-a-section-mfs-014-already-reserved-and-explicitly-left-empty))
- Related: MFS-017 — Assign Lure to Catch (the most recent precedent for adding one new optional field to `Catch` alongside an additive, non-destructive schema migration — the shape this milestone's own migration follows)
- Sequenced after: MFS-022 — Fishing Spot Statistics (`docs/roadmap.md` §3.2 — no hard dependency; sequenced after for product reasons, since richer per-catch notes make reviewing a fishing spot's own catch history more useful)
- Precedes: MFS-024 — Catch Search & Filtering (this milestone's note is explicitly not searchable or filterable; that capability is MFS-024's own scope)

---

## Purpose

Let an angler attach one optional, free-form text note to an individual catch, so they can record practical context that does not fit the existing structured fields (species, weight, length, date/time, lure) — weather or water observations, lure presentation, fish behavior, the exact circumstances of the catch, or anything else worth remembering later.

---

## User Value

The project charter's own Problem Statement asks: "What has worked in similar conditions before?" Every structured field this application already records (species, weight, length, lure) answers a narrow, specific question — none of them can capture the answer to that one, which is usually a short, specific, free-text observation. Catch Notes closes this gap with the simplest possible mechanism: one optional text field per catch, editable wherever the catch itself is already editable, visible wherever the catch itself is already visible.

This milestone was explicitly anticipated three times already: MFS-009's Non-Goals and Future Milestones both named "notes" as expected future scope; MFS-014/TD-014 reserved the final section of Catch Details for it and left it visibly empty; and `docs/roadmap.md` names it directly as this project's next milestone.

---

## Scope

### In Scope

- One optional, nullable, plain-text `notes` field on `Catch`.
- Multiline input, editable during catch creation (MFS-010) and catch editing (MFS-012).
- A maximum of 1000 user-entered characters, measured on the raw input before any normalization (see [Conceptual Model](#the-length-limit-is-measured-on-raw-input-not-on-the-trimmed-value)).
- Leading and trailing whitespace removed before persistence; internal whitespace and line breaks preserved exactly as entered.
- Empty or whitespace-only input, after trimming, stored as `null` — never an empty string.
- Display of the note, in full, as the final section of Catch Details (MFS-014) when present; no section at all when absent.
- Selectable, copyable note text in Catch Details.
- An additive, non-destructive database migration preserving every existing catch.
- Fully offline operation, consistent with the rest of this application.

### Out of Scope

See [Out of Scope](#out-of-scope-1) for the complete list. Notably: searching or filtering by note content (MFS-024), multiple notes per catch, note-specific timestamps or edit history, attachments inside notes, shared/public notes, automatically generated text of any kind, a Catch List note indicator, and markdown or rich-text formatting.

---

## User Stories

**As an angler**
I want to write a short note when I log a catch
So that I can remember the conditions, the lure presentation, or the fish's behavior later, not just its species and size.

**As an angler**
I want to add, change, or remove a note from a catch I already logged
So that I can correct or expand on it after the fact, the same way I already can with any other field on that catch.

**As an angler**
I want to read my note in full when I open a catch's details
So that the context I wrote down is actually useful later, not hidden or truncated.

**As an angler**
I want to copy a note out of a catch's details
So that I can reuse what I wrote — for example, sharing it in a message — without retyping it.

**As an angler**
I want catches I logged before this feature existed to keep working exactly as they do today
So that adding notes doesn't disrupt the fishing history I've already built up.

---

## Conceptual Model

This section resolves the product-level questions this milestone must answer before Technical Design work begins, following the same discipline MFS-021/MFS-022's own Conceptual Model sections already established. Exact query, repository, constant, and widget design remain a Technical Design concern, not addressed here.

### One field, not a new entity

A catch has at most one note, represented as a single nullable field on the existing `Catch` domain model — not a separate `CatchNote` entity, not a list, not a relation. This mirrors MFS-009's own Non-Goals framing ("notes" was already anticipated as a future field on `Catch` itself, alongside weight, length, and — later — lure) and this project's explicit preference for the simplest usable shape over speculative structure.

### Nullable, not an empty string

Consistent with every other optional field already on `Catch` (`weightGrams`, `lengthMillimeters`, `lureVariantId`), the absence of a note is represented as `null`, never as an empty string. This keeps "no note" and "note that was cleared" indistinguishable from "note that was never set" — which is the correct behavior, since nothing in this milestone needs to tell those apart.

### The length limit is measured on raw input, not on the trimmed value

The 1000-character limit applies to the value exactly as the user typed it, before leading/trailing whitespace is trimmed. This keeps the on-screen character counter, the validation message that blocks saving, and the repository's own defensive check all agreeing on the same number at every point in the flow — none of them needs to trim first to know whether the limit has been reached. Trimming can only ever shorten a value, so a value that is valid post-trim was already valid pre-trim; the reverse is not guaranteed to matter, which is exactly why the limit is defined on the larger, simpler quantity.

### Whitespace normalization is deliberately narrow

Only leading and trailing whitespace is removed before persistence. Internal whitespace and line breaks are preserved exactly as entered — this milestone does not collapse blank lines, does not reformat paragraphs, and does not impose any structure on the note's content beyond the length limit itself. A note is exactly what the angler typed, trimmed only at its two ends.

### Persistence must defensively re-validate, not only trust the form

Consistent with how `CatchRepository` already re-validates weight and length with an explicit `ArgumentError` rather than relying solely on the Add/Edit Catch form's own validator (MFS-010/MFS-012), the repository must independently reject a note whose raw length exceeds the limit. The UI validator exists so the angler never reaches that rejection in ordinary use; the repository check exists so the guarantee holds regardless of caller.

### No database-level CHECK constraint is required by this specification

Persistence must prevent a stored note from exceeding the approved limit through the normal repository path (see above) — that is a specification-level requirement. Whether an additional database-level CHECK constraint is also worth adding, the way `weightGrams`/`lengthMillimeters` already have one, is a Technical Design decision, not a product decision this document needs to make.

### Notes fills a section MFS-014 already reserved, and explicitly left empty

MFS-014/TD-014's Catch Details layout already lists a final "Notes" section, and the current implementation ([catch_details_page.dart](../../lib/features/catches/presentation/widgets/catch_details_page.dart)) contains an explicit comment stating that section is intentionally unfilled because `Catch` has never captured the data. This milestone is exactly, and only, the follow-up that fills that already-designed slot — it does not redesign Catch Details, and it does not move, rename, or restyle any other section.

### Absence is silence, not an empty state

When a catch has no note, Catch Details shows nothing for it — no label, no placeholder, no "no notes yet" message — the same convention already used for a catch with no recorded weight or length (MFS-009/MFS-014). A note is not analogous to an empty *list* (which this application does render an empty-state message for, in the Statistics feature); it is analogous to an empty *optional field*, which this application has never given its own empty-state treatment.

### Selectable text is the one deliberate addition beyond the existing display pattern

Every other Catch Details field is plain, non-selectable text. This milestone makes the note specifically selectable/copyable, because it is the one genuinely free-form field in Catch Details an angler might reasonably want to copy elsewhere (for example, into a message). This is a narrow, deliberate exception, not a precedent for making every field selectable.

---

## Functional Requirements

### FR-1 — Domain Field

`Catch` must gain one optional field capable of holding a plain-text note, following the same nullable-optional-field convention already established for `weightGrams`, `lengthMillimeters`, and `lureVariantId` (MFS-009/MFS-017).

### FR-2 — Persistence

The existing catch persistence layer must be able to store and retrieve the note alongside every other catch field, through the existing `CatchRepository`/`CatchMapper`/`Catches` table path (MFS-009) — no new table, no new repository, no new mapper.

### FR-3 — Additive Migration

Adding the note must be implemented as a non-destructive, additive schema change. Every existing catch must survive the migration with no note (i.e. a missing/null value), and no other existing data may be altered, following the exact precedent already set by MFS-017's own schema addition.

### FR-4 — Catch Creation Input

The Add Catch form (MFS-010) must offer an optional, multiline input for the note. Leaving it empty must not block saving.

### FR-5 — Catch Editing: Add, Change, or Clear

The Edit Catch form (MFS-012) must show the catch's existing note (if any), prefilled, and must let the user add a note where none exists, change an existing note, or clear it entirely.

### FR-6 — Clearing Normalizes to Absence

Clearing the note field and saving must result in the catch having no note (per [Conceptual Model](#nullable-not-an-empty-string)) — the same "empty optional field becomes absent" convention already used for clearing weight or length (MFS-012).

### FR-7 — Editing Reuses the Existing Result

Saving a catch whose note was added, changed, or cleared must produce the same successful update result Edit Catch already produces for any other field change (MFS-012's `EditCatchResult`/`CatchUpdated`). No new result type is introduced for this field.

### FR-8 — Length Limit

The note must not exceed 1000 characters of raw, user-entered input, measured before whitespace trimming (per [Conceptual Model](#the-length-limit-is-measured-on-raw-input-not-on-the-trimmed-value)). A note exceeding this limit must not be saveable, and the limit must be communicated to the user before they attempt to save.

### FR-9 — Defensive Persistence-Layer Validation

Independently of the form's own validation, the persistence layer must reject a note exceeding the approved limit, following the same "do not rely on the UI validator alone" discipline already applied to weight and length (MFS-010/MFS-012).

### FR-10 — Whitespace Normalization

Before persistence, leading and trailing whitespace must be removed from the note. Internal whitespace and line breaks must be preserved exactly as entered. If the result after trimming is empty, the catch must be stored with no note, not an empty string.

### FR-11 — Catch Details Display

When a catch has a note, Catch Details (MFS-014) must display it in full, as the final section of the page, in the position MFS-014/TD-014 already reserved for it.

### FR-12 — Absence Handling

When a catch has no note, Catch Details must render no section, label, or placeholder for it — the entire section is omitted, per [Conceptual Model](#absence-is-silence-not-an-empty-state).

### FR-13 — Selectable Display

The displayed note in Catch Details must be selectable and copyable by the user.

### FR-14 — Offline Operation

Every capability in this milestone must work with no network connection, consistent with the rest of this application.

---

## UI Expectations

- The note input is a plain, multiline text field — no rich-text toolbar, no markdown preview, no tagging control.
- In both Add Catch and Edit Catch, the note input is positioned as the final input, immediately above the existing Save/Cancel action row — the last thing the angler fills in before saving, consistent with it being the final section of Catch Details as well.
- The character limit is communicated to the user before they attempt to save (for example, via an on-screen counter), not discovered only after a failed save attempt.
- All user-visible text is Finnish, consistent with the application's existing UI text convention. Exact wording (label text, validation message text) is a Technical Design/implementation concern, not specified here.
- In Catch Details, the note is shown in full — no truncation, no "show more" affordance, no collapsed state — consistent with this project's preference for the simplest usable presentation over added interaction complexity.
- No search field, filter control, or sort control related to notes is shown anywhere in this milestone.

---

## Navigation

This milestone introduces no new page, no new tab, and no new navigation entry point. The note is entered and edited within the existing Add Catch and Edit Catch forms (MFS-010/MFS-012), and displayed within the existing Catch Details view (MFS-014). No navigation flow in this application changes as a result of this milestone.

---

## Data Ownership

- This milestone extends the existing **catches** feature (MFS-009) only; it does not introduce a new feature directory.
- `Catch`, `CatchRepository`, `CatchMapper`, and the `Catches` table remain owned by the `catches` feature, following the existing feature-first structure and database ownership rules (ADR-0001, ADR-0003, ADR-0006).
- No other feature is modified. `catch_photos`, `fishing_spots`, `lure_catalog`, `personal_tackle_box`, and `statistics` are all unaffected: none of their domain models, database schemas, or repository contracts change, and `CatchListItem` (reused unmodified across MFS-011/MFS-014/MFS-019 through MFS-022) does not render the note, so no change is needed there either.
- No new persisted aggregate, cache, or statistic of any kind is introduced anywhere.

---

## Empty, Loading, and Error States

- **No note exists:** Catch Details shows no section for it at all — not an empty state message, per [FR-12](#fr-12--absence-handling) and [Conceptual Model](#absence-is-silence-not-an-empty-state). There is no separate loading state for the note specifically — it is part of the same already-loaded `Catch` object every other Catch Details field already comes from.
- **The note exceeds the length limit:** saving is blocked before any persistence attempt, with a clear message; the entered text remains visible and editable, following the same "block, don't discard" convention already used for invalid weight/length input (MFS-010/MFS-012).
- **General save failure (e.g. a database error):** the existing Add Catch/Edit Catch failure handling applies unchanged — the form remains open, the entered note (along with every other field) remains visible, and the user can retry. No new, note-specific error message is introduced.

---

## Edge Cases

- A catch created before this milestone has no note and displays exactly as it always has — no visual or behavioral change to any existing catch.
- A note consisting only of whitespace or line breaks is stored as no note at all (per [FR-10](#fr-10--whitespace-normalization)); Catch Details shows nothing for it.
- A user clears an existing note and saves: the catch afterward has no note, and Catch Details omits the section entirely the next time it is opened.
- A user edits an unrelated field (e.g. species or weight) without touching the note: the existing note, if any, is preserved unchanged, the same way editing one field already leaves every other field untouched (MFS-012).
- Editing a catch's note, like editing any other field, refreshes the catch's `updatedAt` — no separate, note-specific timestamp is introduced (see [Out of Scope](#out-of-scope-1)).
- Deleting a catch removes its note along with the rest of the catch row — the note has no independent lifecycle, storage, or cleanup step of its own.
- Pasting text far longer than the limit is blocked from saving in exactly the same way as typing it would be — no special-casing of paste versus typed input.

---

## Accessibility Expectations

- The note input's label is exposed through the same accessible labeling mechanism already used by every other Add Catch/Edit Catch field (species, weight, length), consistent with this application's existing form accessibility.
- The displayed note in Catch Details is preceded by a visible, accessible label, consistent with every other labeled row in that view (MFS-011, MFS-014, MFS-020, MFS-021, MFS-022).
- Making the note's displayed text selectable must not remove or degrade its accessibility to assistive technology — the label and the note's content must both remain readable by a screen reader.
- Tap targets and text throughout this milestone follow the application's existing Material 3 sizing and text-scaling conventions.

---

## Feature Ownership and Placement

Following the existing feature-first structure, Repository pattern, and database ownership rules (ADR-0001, ADR-0003, ADR-0006), this milestone extends the **catches** feature (MFS-009) only.

- `CatchRepository` is extended directly — no repository interface, DAO, service layer, or use-case layer is introduced, consistent with every prior Catch milestone (MFS-009, MFS-010, MFS-012, MFS-017).
- No new state-management framework is introduced. Add Catch and Edit Catch remain `StatefulWidget`s using `TextEditingController`s, following the exact pattern already established for every other field on those forms (MFS-010, MFS-012).
- Catch Details continues to require no state-management framework beyond what it already uses (MFS-014).
- Exact implementation design — including where any length-limit constant lives, exact Drift column definition, exact migration code, exact controller/widget structure, and whether a database-level CHECK constraint is added — is a Technical Design concern, out of scope for this specification.

---

## Acceptance Criteria

- `Catch` has an optional note field, following the existing nullable-optional-field convention.
- The persistence layer stores and retrieves the note through the existing `CatchRepository`/`CatchMapper`/`Catches` path.
- The schema migration is additive; every existing catch survives it with no note, and no other existing data is altered.
- Add Catch offers an optional, multiline note input; leaving it empty does not block saving.
- Edit Catch shows the catch's existing note (if any), and lets the user add, change, or clear it.
- Clearing the note and saving results in the catch having no note.
- Saving a note change (add, change, or clear) in Edit Catch produces the existing successful update result — no new result type.
- A note longer than 1000 raw, user-entered characters cannot be saved, and the limit is communicated to the user before a failed save attempt.
- The persistence layer independently rejects a note exceeding the limit, regardless of caller.
- Leading and trailing whitespace is removed before persistence; internal whitespace and line breaks are preserved; an empty-after-trim value is stored as no note.
- Catch Details displays the note, in full, as the final section, only when one exists.
- Catch Details renders no section, label, or placeholder when no note exists.
- The displayed note is selectable and copyable.
- No unrelated Catch feature (list, statistics, search) is modified.
- Every capability in this milestone works with no network connection.
- `flutter analyze` passes.
- Automated tests cover: domain construction with and without a note (including length-limit rejection), repository create/update/round-trip of the note (including the defensive length check and the whitespace-only-input-becomes-null case), the schema migration preserving existing catches, Add Catch input and validation, Edit Catch add/change/clear behavior, Catch Details rendering with and without a note, and selectability of the displayed note.
- Physical Android testing is completed for this milestone.

---

## Out of Scope

- Searching notes (MFS-024 — Catch Search & Filtering)
- Filtering by note content (MFS-024)
- Multiple notes per catch
- Timestamps for individual note edits, distinct from the catch's own existing `updatedAt`
- Note edit history or undo
- Attachments inside notes (photos already exist as a separate, established feature — MFS-013)
- Shared or public notes (no sharing feature exists anywhere in this application)
- Automatic weather-text generation (no weather/environmental data source exists yet — see `docs/roadmap.md` §3.4, unresolved and offline-first-constrained)
- AI-generated summaries or any other AI-generated content
- A notes indicator or preview on the Catch List (`CatchListItem` is not modified by this milestone)
- Markdown rendering, rich-text formatting, or any text styling within the note
- A database-level CHECK constraint enforcing the length limit (a Technical Design decision, not required by this specification — see [Conceptual Model](#no-database-level-check-constraint-is-required-by-this-specification))
- Any change to the `catch_photos`, `fishing_spots`, `lure_catalog`, `personal_tackle_box`, or `statistics` domain models, database schemas, or repository contracts
- Any persisted/stored aggregate, cache, or index related to notes
- A service layer, use-case layer, DAO layer, or repository interface of any kind
- Cloud synchronization

---

## Relationship to Previous MFS Documents

- **MFS-009 (Catch Foundation)** established `Catch`, the `Catches` table, `CatchRepository`, and `CatchMapper` this milestone extends, and explicitly named "notes" as an anticipated future field in its own Non-Goals and Future Milestones sections.
- **MFS-010 (Add Catch)** established the Add Catch form and its "empty optional field saves as absent" convention, which this milestone's note input follows exactly.
- **MFS-012 (Edit and Delete Catch)** established the Edit Catch form, its "clearing an optional field stores it as absent" convention, and the `EditCatchResult`/`CatchUpdated` type this milestone reuses without any new variant.
- **MFS-014 (Catch Details View)**, together with TD-014, reserved the final section of Catch Details for notes and shipped with it explicitly, visibly unfilled — this milestone is precisely that anticipated follow-up, not a redesign of Catch Details.
- **MFS-017 (Assign Lure to Catch)** is the most recent precedent for adding one new optional field to `Catch` alongside a small, additive, non-destructive schema migration — the shape this milestone's own migration follows.
- **MFS-019 through MFS-022 (Statistics)** reuse `CatchListItem`, which this milestone does not modify — the Statistics feature requires no change as a result of this milestone.

---

## Dependencies

No new external dependencies are required. This milestone reuses the existing stack and patterns:

- Flutter, Dart
- Drift (an additive schema migration against the existing `Catches` table, per ADR-0005)
- The existing Repository pattern and feature-first structure (ADR-0001, ADR-0003, ADR-0006)
- The existing `Catch` domain model, `CatchRepository`, and `CatchMapper` (MFS-009)
- The existing Add Catch (MFS-010) and Edit Catch (MFS-012) forms and their established optional-field conventions
- The existing Catch Details view (MFS-014), reused as this milestone's display target

---

## Future Extensions

This milestone is expected to support, in later milestones:

- Searching and filtering by note content (MFS-024).
- A notes preview or indicator on the Catch List, if real usage shows it would be useful.
- A higher character limit, or limited formatting, if real usage ever demonstrates the current limit or plain-text constraint is insufficient.
- Note-specific timestamps or edit history, if a real need for them emerges.
- Automatic weather-text prefill, contingent on the still-unresolved offline environmental-data-source question (`docs/roadmap.md` §3.4).

---

## Design Notes

This section explains the two places this specification makes a deliberate, narrow decision rather than leaving it open, and why.

**The length limit is defined on raw input, not on the trimmed, stored value.** It would be equally possible to measure 1000 characters against the value after trimming. This specification deliberately measures it before trimming instead, so that the on-screen character counter, the validation message, and the repository's own defensive check can all agree on exactly the same number without any of them needing to simulate trimming first. Since trimming can only shorten a value, nothing valid by the raw-input rule can become invalid after trimming — the choice costs nothing and keeps every layer consistent.

**No database-level CHECK constraint is required here.** `weightGrams` and `lengthMillimeters` already have one (MFS-009/TD-009), which could argue for symmetry. This specification does not require it for notes: persistence must prevent an over-limit value through the normal repository path regardless (FR-9), which is the product-level guarantee that actually matters. Whether a CHECK constraint is *also* worth adding is left to TD-023, the same "add when practical" latitude TD-009 already gave itself for the existing numeric constraints — not a requirement this document imposes in advance.
