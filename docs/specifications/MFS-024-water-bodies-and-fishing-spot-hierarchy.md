# MFS-024 — Water Bodies and Fishing Spot Hierarchy

## Status

Implemented — architecture-reviewed, all automated tests passing (735/735), `flutter analyze` clean (8 pre-existing/accepted info-level lints, none introduced by this milestone), and physical Android verification completed. See TD-024 for the technical design and its Implementation Notes for full detail, and `docs/project-status.md` for the verification record. One acceptance item was deliberately deferred: FR-17's gentle, non-blocking post-migration reorganization hint (the hint *text/UI* only) was postponed per TD-024's Key Design Decision 8, since this project currently has no production users for whom the reassurance matters; the underlying migration itself (FR-14 — every pre-existing fishing spot automatically receiving its own correctly named water body) is fully implemented and verified. Reintroducing the hint is recommended before any release to real external users.

## Related

- Depends on: MFS-004 — Fishing Spot Foundation (the `FishingSpot` domain model this milestone adds a parent relationship to) and ADR-0004 — Fishing Spot Domain (the domain-modeling precedent this milestone follows and extends)
- Depends on: MFS-005 — Create Fishing Spot (the creation flow this milestone inserts a new step into)
- Depends on: MFS-007 — Edit Fishing Spot (the existing Fishing Spot Details bottom sheet this milestone adds a new editing action to)
- Depends on: MFS-008 — Delete Fishing Spot (the existing deletion behavior this milestone must not change, and the precedent this milestone's own new deletion rule is evaluated against)
- Depends on: MFS-009 — Catch Foundation (the `FishingSpot 1 ──── * Catch` relationship this milestone's own `WaterBody 1 ──── * FishingSpot` relationship mirrors, and the existing cascade-delete precedent this milestone deliberately does not reuse — see [Conceptual Model](#deletion-rules-a-water-body-does-not-reuse-the-existing-cascade-precedent))
- Related: MFS-019 through MFS-022 — Statistics (the existing per-species, per-lure, and per-exact-fishing-spot statistics this milestone's display changes touch; see [Conceptual Model](#which-existing-screens-are-affected))
- Related: MFS-014 — Catch Details View (a display surface this milestone optionally extends; see [Conceptual Model](#which-existing-screens-are-affected))
- Precedes: future water-body-level statistics, lure guidance, and recommendation features named in `docs/roadmap.md` §3.4–3.6, none of which are in scope here

---

## Purpose

Introduce a parent concept above `FishingSpot` — a **water body** — representing the broader lake, pond, river, reservoir, sea/coastal area, or other user-defined water area that one or more exact fishing spots belong to. Today, a single `FishingSpot.name` is asked to carry both meanings at once (the lake *and* the exact spot on it), which makes fishing-spot names either overly long and specific ("Merrasjärvi Koiraranta") or ambiguous when aggregated. This milestone separates the two concepts while preserving every exact fishing spot an angler has already recorded.

---

## User Value

The project charter's Problem Statement asks "How can I keep track of my best fishing spots?" — a question this application already answers at the exact-spot level (MFS-011, MFS-022). It does not yet answer a closely related, one-level-broader version of the same question: "Which *lakes* have actually produced for me?" Today, that question can only be answered by mentally regrouping a list of exact spot names — several of which may share the same lake under different local names ("Koiraranta," "Pohjoislahti," "Ruovikkoniemi" all being places on the same lake, Merrasjärvi). This milestone lets the application do that grouping itself, while an angler continues to record and review the exact place they fished, unchanged.

---

## Scope

### In Scope

- A new `WaterBody` domain concept: a named parent above `FishingSpot`, capable of representing a lake, pond, river, reservoir, sea/coastal area, or another user-defined water area — not lake-specific.
- Every `FishingSpot` created after this milestone belongs to exactly one `WaterBody`.
- Manual, user-confirmed water-body selection when creating a fishing spot: select an existing water body, or create a new one, in addition to naming the exact fishing spot itself.
- Reuse of a previously created water body across multiple fishing spots, including simple, practical suggestions of likely-relevant existing water bodies (see [Conceptual Model](#nearby-suggestion-uses-only-data-already-in-the-local-database)) — not automatic geospatial detection.
- Letting the angler change an existing fishing spot's water body after creation.
- A safe, defined product rule for deleting a water body, distinct from the existing fishing-spot deletion rule.
- A specified, purely automatic migration for existing fishing spots, focused on data integrity and continued usability — plus an optional, gradual, user-initiated way to reorganize them under shared water bodies afterward, never a mandatory first-launch step.
- A minimal water-body management surface: view existing water bodies, rename one, see which fishing spots belong to it, and delete it once empty.
- Identification of which existing screens display a fishing spot's name today, and which of those should show the water body instead or in addition (see [Conceptual Model](#which-existing-screens-are-affected)).
- Fully offline operation for every first-version capability.

### Out of Scope

See [Out of Scope](#out-of-scope-1) for the complete list. Notably: automatic water-body detection from coordinates, any external geospatial dataset or API, polygon boundaries, lake metadata downloads, depth contours, weather or water-quality data, shared/collaborative water bodies, AI recommendations, advanced water-body analytics, nationwide lake database import, a map-navigation redesign, and global catch search.

---

## User Stories

**As an angler**
I want to give the lake I'm fishing on its own name, separate from the exact spot I'm standing at
So that "Merrasjärvi" and "Koiraranta" can both be recorded, instead of forcing me to squeeze both into one fishing spot name.

**As an angler**
I want to reuse a lake I've already named when I add another spot on the same lake
So that I don't end up with several unrelated-looking fishing spots that are secretly all the same lake.

**As an angler**
I want my catch statistics to group by lake, not by every exact spot I've ever marked on it
So that "Merrasjärvi: 12 catches" is more useful to me than four separate one- or two-catch entries under four spot names.

**As an angler**
I want my catch details to still show exactly where I caught the fish
So that I don't lose the precision I already rely on today.

**As an angler**
I want to correct which lake a fishing spot belongs to, if I set it up wrong
So that I can fix a mistake without having to delete and recreate the fishing spot and lose its catch history.

**As an angler upgrading from an older version of the app**
I want every fishing spot I already have to keep working exactly as it does today
So that this new feature doesn't put any of my existing data at risk.

---

## Conceptual Model

This section resolves the product-level questions this milestone must answer before Technical Design work begins, following the same discipline established by MFS-021/MFS-022/MFS-023's own Conceptual Model sections. Exact table/column design, identifier scheme, and query strategy remain a Technical Design concern.

### Likely domain term: `WaterBody`

No existing project terminology, ADR, specification, or current implementation names or anticipates this concept. `WaterBody` is proposed as a new term, not a rename of anything established. It is deliberately not called `Lake`, since it must also represent ponds, rivers, reservoirs, sea/coastal areas, and other user-defined water areas.

### Intended hierarchy

```text
WaterBody
  ├── FishingSpot
  ├── FishingSpot
  └── FishingSpot
```

Example:

```text
Merrasjärvi
  ├── Koiraranta
  ├── Pohjoislahti
  └── Ruovikkoniemi
```

Each `FishingSpot` belongs to exactly one `WaterBody`. A `WaterBody` may have one or more fishing spots. A `Catch` is unaffected in shape — it continues to reference exactly one `FishingSpot` (MFS-009), unchanged:

```text
WaterBody 1 ──── * FishingSpot 1 ──── * Catch
```

### The water body is resolved through the fishing spot, not duplicated onto the catch

A `Catch` does not gain a direct water-body reference. Its water body is always obtained by resolving its existing `FishingSpot`, then that fishing spot's `WaterBody` — the same "reference, never duplicate" discipline this application already applies everywhere a catch's related data is displayed (the Statistics feature's own Data Ownership sections state this explicitly for `FishingSpot` and `LureCatalogEntry` data). Duplicating a water-body reference directly onto every catch would let a catch's effective water body silently diverge from its fishing spot's actual, current water body — exactly the kind of duplicated, driftable state this project's architecture already avoids.

### Which existing screens are affected

Based on the current implementation, exactly two places display a fishing spot's name in a way this milestone's product goals bear on, plus one notable gap:

- **`RecordCatchCard`** ([`record_catch_card.dart`](../../lib/features/statistics/presentation/widgets/record_catch_card.dart)), used by Species Statistics (MFS-021)'s Record Catch section, displays the catch's exact fishing spot name as its "location" line — in a context that already spans every fishing spot the species was ever caught at. This is precisely the "overly specific place name in an aggregated view" the product problem describes, and is this milestone's clearest, concrete candidate for showing the water body (in place of, or alongside, the exact spot name).
- **`GeneralCatchStatisticsTab`**'s existing Fishing Spot List ([`general_catch_statistics_tab.dart`](../../lib/features/statistics/presentation/widgets/general_catch_statistics_tab.dart), MFS-022) and its destination, **`FishingSpotStatisticsPage`**, are deliberately scoped to one *exact* fishing spot — that is the entire purpose MFS-022 defined for them. This milestone does not regroup or re-scope either of them to the water-body level; doing so would contradict MFS-022's own stated purpose and is explicitly named as later, separate future value (see [Future Value](#future-value)), not this milestone's own scope.
- **`CatchDetailsPage`** ([`catch_details_page.dart`](../../lib/features/catches/presentation/widgets/catch_details_page.dart)) does not display any location information today at all, despite already receiving the catch's `FishingSpot` as a constructor parameter — it is used only for navigation, never rendered. This is a real gap discovered while reading the current implementation, not an existing behavior this milestone would be "changing." Showing water body and/or exact fishing spot here is therefore a new, optional addition, not a modification of existing behavior — see [Design Notes](#design-notes).

Map markers ([`map_screen.dart`](../../lib/features/map/presentation/map_screen.dart)) already render one marker per `FishingSpot`, never per water body, and this milestone does not change that — a water body is not itself a point on the map and is not assigned its own marker.

### Nearby suggestion uses only data already in the local database

The first version's "suggest previously created nearby water bodies" goal is satisfied using only coordinates the application already stores (every existing `FishingSpot.latitude`/`longitude`), for example by ranking existing water bodies by the distance from the new or edited fishing spot's coordinates to their nearest already-recorded fishing spot. This is a simple, local, offline calculation over data the app already has — not a geospatial boundary/polygon lookup, and not a request to any external service.

This suggestion is meant to be genuinely useful, not merely present. Locally computed nearby water bodies are shown **before** the full list of every existing water body, and when there is one clearly relevant nearby candidate, it may be preselected so the common case — adding another spot on a lake the angler already uses — needs no extra searching. For example:

```text
Nearby water bodies

Merrasjärvi
```

shown ahead of, and clearly distinguished from, the full browsable/searchable list of every water body. The angler must always be able to change the selection or reject a preselected suggestion — this is a convenience default, never an authoritative or final assignment, and never automatic detection. Exact distance thresholds, ranking logic, and how many nearby candidates to show are Technical Design decisions; this specification only requires that the ordering and any preselection are based solely on locally stored coordinates, never on network access, an external dataset, or a polygon boundary.

### Duplicate water-body names are handled the same way duplicate fishing-spot names already are

Fishing spot names are already free text with no uniqueness constraint — two fishing spots may legitimately share a display name today (confirmed directly in MFS-022's own Design Notes and Edge Cases). This milestone treats `WaterBody` names the same way: a name is required and must not be empty or whitespace-only after trimming, but the application does not enforce or attempt to detect true real-world duplicates (the task explicitly warns against overcomplicating this with geographic boundary comparison). Leading/trailing whitespace is trimmed before saving, so `"Merrasjärvi"` and `"  Merrasjärvi  "` are the same stored name, not two different ones. To help an angler avoid *accidentally* creating a near-duplicate, an exact (trimmed, case-insensitive) name match among existing water bodies should be surfaced prominently during selection (see [Nearby Suggestion](#nearby-suggestion-uses-only-data-already-in-the-local-database)) — but creating a second water body that happens to share a name with an existing one must not be blocked, silently merged, or treated as an error.

### Deletion rules: a water body does not reuse the existing cascade precedent

This application already has two different existing foreign-key lifecycle precedents:

- `FishingSpot → Catch`: deleting a fishing spot **cascades**, deleting every catch recorded there (MFS-008/MFS-009's explicit, existing, unchanged behavior).
- `LureVariant → Catch.lureVariantId` / `LureVariant → TackleBoxEntry`: deletion is **restricted** while a reference still exists (established by MFS-016/MFS-017's schema).

A `WaterBody → FishingSpot` deletion is evaluated fresh here, not simply assumed to follow either precedent automatically, because deleting a water body has a meaningfully larger blast radius than either existing case: it would transitively reach every fishing spot on it, and through those, every catch (and each catch's own photos, lure assignment, and notes) ever recorded at any of them — a multi-level cascade with no existing precedent anywhere in this application. Per this milestone's own product requirement to not invent destructive cascade behavior casually, **the specified rule is that a non-empty water body (one that still contains at least one fishing spot) cannot be deleted**. An angler who wants to delete a water body must first move or delete every fishing spot on it — the same "make the container empty first" discipline, one level up, that already governs nothing destructively cascading two levels in this application today. Deleting a fishing spot itself is unaffected by this milestone and continues to cascade-delete its catches exactly as it already does (MFS-008/MFS-009).

An **empty** water body (no fishing spots at all) may be deleted freely, mirroring how deleting a fishing spot with no catches is already unremarkable today.

### Existing-data migration exists for data integrity and continuity, not for grouping

The application already contains fishing spots with no water-body concept at all. Three approaches were considered:

1. **Automatically create one `WaterBody` per existing `FishingSpot`**, named identically to that fishing spot's current, normalized name, and assign the fishing spot to it. Fully automatic, offline, non-destructive, and requires no user action before the upgraded application is usable again — consistent with every migration this project has shipped so far (MFS-013, MFS-015 through MFS-017, MFS-023), all of which are automatic and require no user interaction.
2. **A guided migration/merge wizard** asking the angler to group their existing fishing spots into water bodies on first launch after the upgrade. Could produce the actually-desired grouping immediately, but is a substantially larger, separately designed UX flow, risks blocking or intimidating the angler before the app is usable again, and is a poor fit for this milestone's otherwise minimal, additive scope.
3. **Leave the relationship nullable**, treating "no water body yet" as a valid, displayed state the angler fills in opportunistically. Simplest migration, but directly conflicts with this milestone's own stated goal that "each fishing spot belongs to one water body after the feature is introduced," and risks records that display inconsistently (some grouped, some not) indefinitely.

**Specified requirement:** Option 1. Every existing `FishingSpot` receives an automatically created `WaterBody`, named identically to that fishing spot's current, normalized name at the moment of migration, and the fishing spot's water-body relationship becomes non-null from that point on. Every coordinate, catch, photo, note, and lure link is preserved untouched; the migration runs fully offline; and no fishing spot is ever left without a water body.

This migration's purpose is deliberately narrow: **it exists to preserve data integrity and let the application keep working immediately, not to produce useful statistical grouping on its own.** Immediately after migrating, each old fishing spot still stands alone under its own one-fishing-spot water body — exactly as ungrouped as before. This is an accepted, explicit limitation of the migration itself, not an oversight: producing genuinely useful grouping requires knowing which of the angler's fishing spots actually share a lake, which the migration has no reliable way to infer (see [Migration-Generated Identity](#migration-generated-water-bodies-follow-the-same-naming-rules--no-fuzzy-grouping)). How that grouping is eventually achieved — voluntarily, gradually, by the angler — is addressed next, not by the migration itself.

### Post-migration cleanup is optional, gradual, and never blocking

Once migrated, an angler's fishing spots are safe and immediately usable, but not yet meaningfully grouped. This milestone addresses that with a deliberately light-touch mechanism, not a mandatory wizard:

- After migration, the application gently informs the angler — once, non-modally, and without blocking normal use — that existing fishing spots can be reorganized under shared water bodies for better water-body-level statistics.
- Reorganization is entirely optional. Declining or ignoring it has no effect on any other capability in this application; every existing feature continues to work exactly as it does today whether or not the angler ever reorganizes anything.
- The angler performs reorganization later, at their own pace, from the fishing spot's existing water-body-editing path ([FR-7](#fr-7--edit-an-existing-fishing-spots-water-body)) or the water-body management surface ([FR-16](#fr-16--minimal-water-body-management-surface)) — not from a separate, one-time wizard.
- Reorganizing means moving an existing `FishingSpot` from its automatically created, one-spot water body to a different, already-existing shared `WaterBody` — the same operation as FR-7, performed as many times as the angler chooses.
- Once the last `FishingSpot` has been moved away from an automatically created water body, that water body is empty and may be deleted like any other empty water body, under the ordinary empty-only deletion rule ([FR-12](#fr-12--water-body-deletion-requires-an-empty-water-body)) — it receives no special treatment for having been migration-generated.

There is no mandatory first-launch wizard, and the angler is never required to reorganize any historical data before continuing to use the application.

### Migration-generated water bodies follow the same naming rules — no fuzzy grouping

An automatically created `WaterBody` is named using exactly the same normalization rules as a user-created one (required, non-empty after trimming — [FR-1](#fr-1--water-body-domain-concept)/[FR-3](#fr-3--create-a-water-body-while-creating-a-fishing-spot)). Nothing about being migration-generated makes a water body's name, or its handling, special.

The migration must not attempt to infer that two differently named fishing spots belong to the same lake from partial or fuzzy name similarity. For example, `"Merrasjärvi Koiraranta"` and `"Merrasjärvi Ruovikko"` are **not** automatically merged into one `"Merrasjärvi"` water body during migration, even though a human would likely recognize them as the same lake — the migration has no reliable way to distinguish a genuine shared prefix from a coincidence, and a wrong automatic merge is considerably more disruptive and harder to notice than a temporarily ungrouped fishing spot. The migration deliberately prefers predictable, non-destructive behavior (one water body per existing fishing spot) over any guessed grouping. Merging spots that genuinely do share a lake is left entirely to the angler's own, voluntary post-migration cleanup (above).

---

## Functional Requirements

### FR-1 — Water Body Domain Concept

A `WaterBody` domain concept must exist: a stable, uniquely identified entity with a required, non-empty name (after trimming), capable of representing a lake, pond, river, reservoir, sea/coastal area, or another user-defined water area.

### FR-2 — Fishing Spot Belongs to Exactly One Water Body

Every `FishingSpot` created after this milestone is introduced must belong to exactly one `WaterBody`. The relationship is obtained through the fishing spot; it is not duplicated onto `Catch` (see [Conceptual Model](#the-water-body-is-resolved-through-the-fishing-spot-not-duplicated-onto-the-catch)).

### FR-3 — Create a Water Body While Creating a Fishing Spot

When creating a fishing spot (current-location or select-from-map, MFS-005), the angler must, in addition to placing the location and naming the exact fishing spot, either select an existing water body or create a new one. A water body name is required; an empty or whitespace-only name must be rejected before saving, mirroring the existing fishing-spot-name validation (MFS-005/MFS-007).

### FR-4 — Reuse an Existing Water Body

Once a water body has been created, it must be selectable again for any later fishing spot, without re-entering its name or creating a duplicate entry for the same lake.

### FR-5 — Practical, Nearby-First Water-Body Selection

Existing water bodies must be presented in a way an angler can practically browse and choose from (at minimum a searchable or scrollable list of every existing water body). Locally computed nearby water bodies (see [Conceptual Model](#nearby-suggestion-uses-only-data-already-in-the-local-database)) must be presented before that full list, and a single, clearly relevant nearby candidate may be preselected. In every case, the angler must be able to change the selection or reject a preselected suggestion and pick a different or new water body instead. The suggestion relies only on locally stored coordinates; no network connection, external dataset, or polygon boundary is required. Exact distance thresholds, ranking logic, and selection UI are Technical Design concerns.

### FR-6 — Duplicate Names Are Permitted, Not Silently Merged

Creating a water body whose (trimmed, case-insensitive) name matches an existing one must not be blocked, must not silently reuse the existing entry, and must not error — it creates a second, independent water body, mirroring the existing fishing-spot-name precedent (MFS-022 Design Notes). The selection UI should surface an exact-name match prominently to help the angler choose the existing entry instead, without requiring it.

### FR-7 — Edit an Existing Fishing Spot's Water Body

The angler must be able to change which water body an existing fishing spot belongs to, from the existing Fishing Spot Details bottom sheet (MFS-007). Changing the water body must not alter the fishing spot's coordinates, name, or identifier, and must not alter any catch already recorded there.

### FR-8 — Catches Follow the Fishing Spot's Current Water Body Automatically

After a fishing spot's water body is changed, every catch already recorded at that fishing spot must appear under the newly selected water body in any aggregated, water-body-scoped view, with no per-catch update required — a direct consequence of [FR-2](#fr-2--fishing-spot-belongs-to-exactly-one-water-body)'s "resolved through the fishing spot" relationship.

### FR-9 — Exact-Context Views Continue to Show the Exact Fishing Spot

Every existing view whose entire purpose is one specific fishing spot — Fishing Spot Details (MFS-007), Fishing Spot Statistics (MFS-022) — must continue to show that fishing spot's own exact name, unchanged. These views may additionally show the parent water body as context (for example, as a subtitle), but must not replace the exact fishing spot name with only the water body name.

### FR-10 — Cross-Fishing-Spot Aggregated Views May Show the Water Body

Where a fishing spot's exact name is currently shown only as incidental location context inside a view that already spans multiple fishing spots — concretely, `RecordCatchCard`'s location line within Species Statistics (MFS-021) — the water body name should be shown in that context, per the product goal that aggregated statistics should generally group under the broader water body rather than the exact fishing spot. This milestone does not change what the view aggregates *by* (it still aggregates by species); it changes what location text that view displays.

### FR-11 — Map Markers Remain Exact Fishing Spots

Map markers continue to represent exact fishing spots one-to-one, exactly as today. No marker is introduced for a water body itself, and no existing marker behavior changes.

### FR-12 — Water Body Deletion Requires an Empty Water Body

A water body that still contains one or more fishing spots must not be deletable. The angler must first reassign or delete every fishing spot it contains. An empty water body (no fishing spots) may be deleted, with the same confirmation discipline already required for deleting a fishing spot (MFS-008).

### FR-13 — Fishing Spot Deletion Is Unchanged

Deleting a fishing spot continues to work exactly as it already does (MFS-008/MFS-009): it cascades to delete every catch recorded there, and this milestone introduces no new confirmation, restriction, or behavior on top of that existing flow.

### FR-14 — Existing-Data Migration Preserves Everything Automatically

Every `FishingSpot` that exists at the moment this milestone is introduced must, without requiring any action from the angler, end up belonging to a `WaterBody`. Per the specified migration approach ([Conceptual Model](#existing-data-migration-exists-for-data-integrity-and-continuity-not-for-grouping)), each existing fishing spot receives its own automatically created water body, named identically to that fishing spot's current, normalized name at migration time. No existing fishing spot, coordinate, catch, photo, lure assignment, or note may be altered, renamed, or lost by this migration, and no fishing spot may be left without a water body. This migration's purpose is data integrity and immediate continued usability — it does not itself claim to produce useful water-body-level grouping; see [FR-17](#fr-17--post-migration-reorganization-guidance) for how that is addressed instead.

### FR-15 — Offline Operation

Every capability in this milestone — creating, selecting, reusing, editing, renaming, viewing, and deleting a water body, every display change, and the nearby-suggestion computation — must work with no network connection.

### FR-16 — Minimal Water Body Management Surface

The angler must be able to: view a list of existing water bodies; rename any water body; see which fishing spots currently belong to a given water body; and delete a water body, subject to the empty-only rule ([FR-12](#fr-12--water-body-deletion-requires-an-empty-water-body)). This must remain a minimal, focused surface — not a large standalone browsing feature with its own filters, sorting options, or statistics. Exact navigation and screen design are Technical Design concerns.

### FR-17 — Post-Migration Reorganization Guidance

After migration, the application must inform the angler, gently and without blocking normal use, that existing fishing spots can be reorganized under shared water bodies for better water-body-level statistics. This information must not take the form of a mandatory first-launch wizard, and the angler must never be required to reorganize any historical data before continuing to use the application normally.

### FR-18 — Voluntary Reassignment and Cleanup Deletion

The angler must be able to move an existing fishing spot from its automatically created water body to a different, already-existing shared water body, at any time and at their own pace, using the existing water-body-editing path ([FR-7](#fr-7--edit-an-existing-fishing-spots-water-body)). Once an automatically created water body no longer contains any fishing spot, it must be deletable under the same empty-only rule that governs any other water body ([FR-12](#fr-12--water-body-deletion-requires-an-empty-water-body)) — no separate deletion mechanism is introduced for migration-generated water bodies.

---

## UI Expectations

- The water-body selection/creation step follows the application's existing Material 3 bottom-sheet and form conventions (the same visual language as `FishingSpotNameBottomSheet` and `AddFishingSpotBottomSheet`).
- The new step is inserted into the existing fishing spot creation flow (MFS-005): place/select location → select or create water body → name the exact fishing spot → save. It does not replace or reorder the existing location-selection step.
- The "change water body" action is added to the existing Fishing Spot Details bottom sheet (MFS-007) alongside its existing "Muokkaa nimeä" and "Poista" actions, following that bottom sheet's existing action-list presentation.
- All user-visible text is in Finnish, consistent with the application's existing UI text convention. Exact wording is a Technical Design/implementation concern, not specified here.
- No polygon, map overlay, or boundary visualization of any kind is introduced for a water body in this milestone.

---

## Navigation

This milestone introduces no new top-level page or route. It adds:

- A new step within the existing Add Fishing Spot flow (MFS-005), reached exactly as today (Add Fishing Spot button → creation method → location → **water body selection/creation** → name → save).
- A new action within the existing Fishing Spot Details bottom sheet (MFS-007) to change a fishing spot's water body.
- A minimal water-body management surface (FR-16) letting the angler view existing water bodies, rename one, see its member fishing spots, and delete it when empty — reachable either as its own small screen or from within the water-body selection step itself. Its exact form is a Technical Design concern; this milestone only requires that viewing, renaming, and empty-only deletion (FR-12) are all reachable somewhere in the application, without growing into a large standalone browsing feature.
- A gentle, non-blocking post-migration prompt or message pointing the angler toward this management surface (FR-17) — not a separate wizard flow or a new top-level page.

---

## Data Ownership

- This milestone introduces the `WaterBody` domain concept and extends `FishingSpot` with a water-body reference. Whether `WaterBody` is owned by the existing `fishing_spots` feature (as `FishingSpot` itself already is) or by its own feature directory (mirroring how `catch_photos` is split out from `catches` despite the tight coupling) is a placement question for Technical Design/architecture review — see [Design Notes](#design-notes).
- `Catch`, `CatchPhoto`, `LureCatalogEntry`/`LureVariant`, and `TackleBoxEntry` are unmodified by this milestone; a catch's water body is always resolved via its existing `FishingSpot` reference (FR-2), never stored redundantly.
- The Statistics feature (MFS-019 through MFS-022) is read-only affected: `RecordCatchCard`'s location line changes what it displays (FR-10); no repository, domain model, schema, or aggregation grouping in that feature changes.
- No change to `catch_photos`, `lure_catalog`, or `personal_tackle_box` domain models, schemas, or repository contracts.

---

## Empty, Loading, and Error States

- **No water bodies exist yet** (a fresh install, before migration has run, or immediately after uninstalling all fishing spots — see [Edge Cases](#edge-cases)): the water-body selection step shows a clear "no water bodies yet" state alongside its "create new" action, not an empty-looking blank list.
- **Loading:** while existing water bodies are being read for selection, a clear loading indicator is shown, consistent with this application's existing loading-state convention.
- **Read/save failure:** if reading existing water bodies, creating one, or saving a fishing spot's water body fails (for example, a database error), the application must not crash; the in-progress form retains the angler's entered data and a clear error message is shown, consistent with this application's existing "block, don't discard" convention (MFS-010/MFS-012/MFS-023).
- **Attempting to delete a non-empty water body:** a clear message explains that its fishing spots must be moved or removed first (FR-12), rather than a generic failure or a silent no-op.

---

## Edge Cases

- A water body with exactly one fishing spot behaves identically to any other water body — this is not a degenerate or special case (most water bodies may look exactly like this immediately after migration, per [Conceptual Model](#existing-data-migration-exists-for-data-integrity-and-continuity-not-for-grouping)).
- Two water bodies sharing the same (trimmed, case-insensitive) name each remain independently valid, exactly mirroring the existing accepted behavior for two fishing spots sharing a name (MFS-022).
- Moving a fishing spot to a different water body immediately changes which water body its existing catches appear under in any aggregated view, with no per-catch action required (FR-8).
- Deleting the last remaining fishing spot from a water body leaves that water body empty, not deleted — it must be explicitly deleted afterward if the angler no longer wants it (FR-12).
- A fishing spot's water body can be changed repeatedly with no limit and no loss of catch history.
- Migrating an application with zero existing fishing spots is a valid, trivial case: no water bodies are created, and the angler simply starts using the feature from an empty state.
- A very large number of existing fishing spots (many auto-created, one-fishing-spot water bodies immediately after migration) must not make the water-body selection list unusably slow — the same virtualization/responsiveness discipline already required of the Lure Catalog (MFS-015) applies here at whatever scale this feature actually reaches.
- An automatically created water body that becomes empty after its one fishing spot is voluntarily moved elsewhere (FR-18) may be deleted exactly like any other empty water body — it receives no special treatment for having been migration-generated.
- Two fishing spots whose names share an obvious common prefix (for example, `"Merrasjärvi Koiraranta"` and `"Merrasjärvi Ruovikko"`) are migrated into two separate, unmerged water bodies, not automatically combined — see [Conceptual Model](#migration-generated-water-bodies-follow-the-same-naming-rules--no-fuzzy-grouping).

---

## Accessibility Expectations

- The water-body selection/creation step exposes accessible labels for its list, its "create new" action, and its name input field, consistent with this application's existing form accessibility (Add Catch, Edit Catch, Fishing Spot naming).
- The new "change water body" action in Fishing Spot Details exposes an accessible label consistent with that bottom sheet's existing actions.
- Wherever a water body name is shown alongside or instead of a fishing spot name (FR-9/FR-10), the accessible/semantic label continues to convey the location information it replaces or supplements — never a regression from what is announced today.
- Tap targets and text throughout this milestone follow the application's existing Material 3 sizing and text-scaling conventions.

---

## Feature Ownership and Placement

Following the existing feature-first structure, Repository pattern, and database ownership rules (ADR-0001, ADR-0003, ADR-0004, ADR-0006):

- `WaterBody` is a new persistent domain concept, most naturally placed within the existing `fishing_spots` feature (extending the same domain ADR-0004 already established) — though a separate feature directory is also a defensible option given this project's own precedent of splitting closely coupled concerns (`catch_photos` from `catches`). This is a placement decision for Technical Design/architecture review, not settled here — see [Design Notes](#design-notes).
- No repository interface, DAO, service layer, or use-case layer is introduced, consistent with every prior milestone in this project.
- `FishingSpotRepository` is extended with whatever operations are needed to read/assign a fishing spot's water body; a concrete, equally simple repository for `WaterBody` itself (create, list, delete-when-empty) is introduced following the same pattern.
- Exact implementation design — schema/migration details, identifier scheme, repository method signatures, and widget structure — is a Technical Design concern, out of scope for this specification.

---

## Acceptance Criteria

- A `WaterBody` domain concept exists, with a required, non-empty (post-trim) name, representing any kind of user-defined water area (not lake-specific).
- Every fishing spot created after this milestone belongs to exactly one water body.
- While creating a fishing spot, the angler selects an existing water body or creates a new one, in addition to placing the location and naming the exact spot.
- A previously created water body can be selected again for a new fishing spot without re-entering its name or creating a duplicate.
- Creating a water body whose name matches an existing one (after trimming, case-insensitively) is permitted and creates an independent second entry, not a silent merge or an error.
- The angler can change an existing fishing spot's water body from the Fishing Spot Details bottom sheet, without altering its coordinates, name, or catch history.
- Catches already recorded at a fishing spot appear under its newly selected water body in aggregated views automatically, with no per-catch update.
- Fishing Spot Details and Fishing Spot Statistics continue to show the exact fishing spot name.
- Species Statistics' Record Catch location line shows the water body instead of the exact fishing spot name.
- Map markers remain one per exact fishing spot; no water-body-level marker is introduced.
- A water body containing one or more fishing spots cannot be deleted; an empty water body can be deleted, with confirmation.
- Deleting a fishing spot continues to cascade-delete its catches exactly as it already does today, unaffected by this milestone.
- Every fishing spot that existed before this milestone automatically belongs to its own automatically created water body after upgrading, with no data loss and no required angler action — this migration exists for data integrity and continuity, not to produce useful grouping on its own.
- After migration, the application gently and non-blockingly informs the angler that reorganizing fishing spots under shared water bodies improves water-body-level statistics, without a mandatory first-launch wizard and without requiring reorganization before continuing normal use.
- The angler can move an existing fishing spot to a different, already-existing shared water body at any time, and an automatically created water body that becomes empty as a result can be deleted under the same empty-only rule as any other water body.
- Automatically created water bodies are named using the same normalization rules as user-created ones; migration never merges fishing spots into a shared water body based on inferred or fuzzy name similarity.
- A minimal water-body management surface lets the angler view existing water bodies, rename one, see which fishing spots belong to it, and delete it only when empty.
- Locally computed nearby water bodies are presented before the full list when creating or editing a fishing spot, and a single clearly relevant candidate may be preselected — but the angler can always change or reject it.
- Every capability in this milestone works with no network connection.
- `flutter analyze` passes.
- Automated tests cover: water-body creation (including empty/whitespace-only name rejection and duplicate-name permission), water-body reuse across multiple fishing spots, fishing-spot creation requiring a water body, editing a fishing spot's water body (including that coordinates/name/catches are unaffected), catches resolving their current water body through their fishing spot after it changes, water-body deletion being blocked while non-empty and permitted while empty, fishing-spot deletion behavior remaining unchanged, the existing-data migration (every pre-existing fishing spot ending up with its own correctly named water body, with all existing data intact, and no fuzzy/partial-name merging), nearby-water-body suggestion ordering and optional preselection, the water-body management surface (view, rename, member fishing spots, empty-only deletion), and voluntary post-migration reassignment (moving a fishing spot to a different existing water body and deleting the resulting emptied, automatically created water body).
- Physical Android testing is completed for this milestone.

---

## Out of Scope

- Automatic water-body detection from map coordinates (a named future enhancement — see [Future Value](#future-value) — not this milestone)
- A mandatory first-launch reorganization wizard
- Requiring the angler to reorganize historical fishing spots before continuing to use the application
- Automatic fuzzy or partial-name-based grouping of fishing spots into a shared water body during migration
- Any external geospatial dataset, boundary dataset, or geocoding API
- Polygon or boundary representation of a water body
- Downloading lake metadata of any kind
- Depth contours
- Weather integration
- Water quality data
- Collaborative or shared water bodies
- AI recommendations of any kind
- Advanced water-body analytics (this milestone introduces the hierarchy only; water-body-level statistics are future value, not built here)
- Importing a nationwide or external lake database
- Redesigning map navigation
- Global catch search (MFS-024's previously abandoned scope — unrelated to this milestone, which reuses the MFS-024 identifier only because it is the next available number)
- Re-scoping the existing Fishing Spot List or Fishing Spot Statistics (MFS-022) to group by water body instead of exact fishing spot
- Any change to `Catch`, `CatchPhoto`, `LureCatalogEntry`/`LureVariant`, or `TackleBoxEntry` domain models, schemas, or repository contracts
- A service layer, use-case layer, DAO layer, or repository interface of any kind
- Cloud synchronization

---

## Relationship to Previous MFS Documents

- **MFS-004 (Fishing Spot Foundation)** and **ADR-0004 (Fishing Spot Domain)** established `FishingSpot` as a stable, framework-independent domain entity with its own identifier — the direct precedent this milestone follows for `WaterBody`, one level up.
- **MFS-005 (Create Fishing Spot)** established the current-location/select-from-map creation flow this milestone inserts a water-body step into.
- **MFS-007 (Edit Fishing Spot)** established the Fishing Spot Details bottom sheet this milestone adds a new action to, and its "identifier/coordinates/creation timestamp unchanged" convention, which this milestone's water-body edit follows exactly.
- **MFS-008 (Delete Fishing Spot)** established the existing fishing-spot deletion flow and confirmation pattern, left entirely unchanged by this milestone, and is the precedent this milestone's own, deliberately different water-body deletion rule is evaluated against.
- **MFS-009 (Catch Foundation)** established the `FishingSpot 1 ──── * Catch` relationship and its cascade-delete behavior, both unchanged by this milestone, and is the direct structural precedent for `WaterBody 1 ──── * FishingSpot`.
- **MFS-019 through MFS-022 (Statistics)** established the per-species, per-lure, and per-exact-fishing-spot statistics this milestone touches only at the display level (`RecordCatchCard`'s location line) — no aggregation, repository, or grouping logic in that feature changes.
- **MFS-014 (Catch Details View)** established the read-only Catch Details page this milestone may optionally extend with location display, filling a gap that page has had since MFS-014 shipped, rather than changing existing behavior.

---

## Dependencies

No new external dependencies are required. This milestone reuses the existing stack and patterns:

- Flutter, Dart
- Drift (an additive schema change against the existing database, per ADR-0005), including a non-destructive migration for existing fishing spots
- The existing Repository pattern and feature-first structure (ADR-0001, ADR-0003, ADR-0004, ADR-0006)
- The existing `FishingSpot` domain model, repository, and creation/edit/delete flows (MFS-004/MFS-005/MFS-007/MFS-008)
- The existing `Catch` domain model and its fishing-spot relationship (MFS-009), unmodified
- The Statistics feature's existing presentation conventions (MFS-019 through MFS-022), extended only at the display level

---

## Future Value

This hierarchy is expected to enable, in later milestones (see `docs/roadmap.md` §3.4–§3.6):

- Water-body-level catch statistics (a new grouping axis alongside the existing per-species, per-lure, and per-exact-fishing-spot statistics).
- Best-performing lures per water body.
- Water-body characteristics such as clarity, vegetation, and depth.
- Condition-based lure guidance informed by water-body context.
- Global catch browsing by water body.
- Automatic map-based water-body detection, with angler confirmation, as a later enhancement to the manual selection this milestone introduces.

None of these are built, scoped, or designed by this milestone — they are recorded here only to explain why the hierarchy is being introduced now, not to expand this milestone's own implementation.

---

## Design Notes

This section records the open judgment calls this specification surfaces explicitly rather than resolving unilaterally, following the same discipline established by MFS-022's own Design Notes section.

**Feature ownership placement is not settled here.** `WaterBody` could reasonably live inside the existing `fishing_spots` feature (the same feature that already owns `FishingSpot`) or as its own feature directory that `fishing_spots` depends on. This project has precedent for both patterns — `FishingSpot` and its own foundational concepts live together in `fishing_spots`, while `catch_photos` was split out from `catches` despite being just as tightly coupled. This specification does not choose between them; it is an architecture-review/Technical Design decision, informed by whichever placement keeps `fishing_spots` from growing an unrelated second responsibility versus the overhead of a near-empty second feature directory.

**Catch Details showing location is a genuinely new addition, not a fix.** While researching this specification, `CatchDetailsPage` was found to accept a `FishingSpot` parameter it never renders — Catch Details today shows no location information at all. The task that produced this document's example ("Catch details: Merrasjärvi / Koiraranta") reads naturally as if this already existed. It does not. This specification records the addition as in-scope but optional ("may show," FR-9's context allowance), consistent with the source task's own "where practical" framing, rather than treating it as a required behavior change to an existing display that, in fact, never displayed a location at all.

**The existing-data migration's limited purpose is now made explicit, and paired with a voluntary cleanup path rather than left as an open trade-off.** An earlier draft of this specification flagged the auto-migration's lack of grouping benefit as a question needing separate Technical Lead confirmation before proceeding. This revision resolves that instead of merely flagging it: the migration is now explicitly scoped to data integrity and continuity only ([Conceptual Model](#existing-data-migration-exists-for-data-integrity-and-continuity-not-for-grouping)), and the actual grouping improvement is addressed by a deliberately optional, non-blocking, gradual cleanup mechanism ([Conceptual Model](#post-migration-cleanup-is-optional-gradual-and-never-blocking)) rather than by the migration itself. Nothing about this milestone requires the migration alone to solve the product problem on day one.

**Migration deliberately does not attempt fuzzy name-based grouping.** It would be tempting to auto-detect that `"Merrasjärvi Koiraranta"` and `"Merrasjärvi Ruovikko"` share a lake from their common prefix and merge them automatically. This specification deliberately does not do this: partial-name matching is unreliable (a shared prefix is not proof of a shared lake, and the reverse — two spots on the same lake with unrelated names — is just as common), and a wrong automatic merge is harder for an angler to notice and undo than a temporarily ungrouped fishing spot. Predictable, non-destructive migration is preferred over guessed grouping, exactly as an angler would reasonably expect from a data migration; any real merging is left entirely to the angler's own judgment via the voluntary cleanup path.

**An ADR is recommended before TD-024 proceeds.** Introducing `WaterBody` as a new, foundational, persistent domain entity — with its own feature-ownership question and a new parent-deletion lifecycle rule distinct from this application's two existing foreign-key precedents (cascade for `FishingSpot → Catch`, restrict for `LureVariant` references) — is the same category of decision that originally produced ADR-0004 for `FishingSpot` itself. This specification does not write that ADR, and does not resolve feature-directory ownership (see [Feature Ownership and Placement](#feature-ownership-and-placement)) or any technical persistence detail — those remain for the ADR and Technical Design to settle.
