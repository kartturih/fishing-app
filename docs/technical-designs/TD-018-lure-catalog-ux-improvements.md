# TD-018 — Lure Catalog UX Improvements

## Status

Draft

## Related Specification

* MFS-018: Lure Catalog UX Improvements

---

## Goal

Reorganize the Lure Catalog's browsing and add-to-tackle-box presentation around lure models instead of individual variants, and correct the add-photo dialog's dismissal behavior — entirely within the presentation layer, with no change to the domain model, database schema, or repository contracts of `lure_catalog` or `personal_tackle_box`.

The implementation shall satisfy MFS-018.

---

## Scope

Implement:

* a model-grouped Lure Catalog browsing list, computed in-memory from the existing `browse()` result
* a new Lure Model Details view listing every non-retired variant of one model
* a new compact Color Variant row (image, color, length, weight, owned indicator, add action)
* reuse of the existing, unmodified `LureDetailsPage` as the reachable full-detail view for a single variant
* a corrected add-photo dialog that distinguishes an explicit "no photo" choice from a dismissal, and never completes an add on dismissal
* one additive, backward-compatible parameter on `AddToTackleBoxAction` so it can be told a variant's owned state instead of querying it itself
* navigation wiring changes in `LureCatalogListPage`/`LureToolsPage`/`MapScreen` required by the above
* **(added during implementation)** one new, read-only `LureCatalogRepository` method, `getVariantsForModel(String lureModelId)`, returning a model's complete set of non-retired variants — required to satisfy MFS-018 FR-6 once testing showed the original in-memory-grouping-only design could not. See **Implementation Notes**.
* tests

Do **not** implement:

* any change to `LureCatalogRepository`'s or `PersonalTackleBoxRepository`'s **existing** public method signatures, query shape, or return types (`browse()`, `getEntryById()`, `getDistinctManufacturers()`, `getDistinctLureTypes()`, and every `PersonalTackleBoxRepository` method are all unchanged; only one new method is added, per above)
* any change to the `LureModel`/`LureVariant`/`LureCatalogEntry`/`TackleBoxEntry`/`TackleBoxItem` domain models
* any database schema or migration change
* search, filter, or sort redesign — the existing `browse()` call, its parameters, and its result ordering are reused exactly as they are
* variant filtering within a model, favorites, stock status, or quick-add shortcuts (MFS-018 Future Extensions)
* any change to the Personal Tackle Box's own browsing view (`PersonalTackleBoxPage`) or Owned Entry Detail view

---

## Key Design Decisions

This section answers the questions most likely to be raised in review, before the detailed sections implement them.

**1. Grouping by model is computed in memory from the existing `browse()` result — no new repository method.** `browse()` already returns every non-retired variant across every model in one query, sorted manufacturer → model (case-insensitive) → variant id (TD-015). That ordering is exactly what a single linear pass needs to group adjacent rows into models, with no `GROUP BY` and no second query — the identical technique TD-016 already established for `PersonalTackleBoxPage`'s manufacturer → model grouping (its own Key Design Decision 3). This milestone reuses that precedent a second time, now inside `lure_catalog` itself.

**2. `LureModelDetailsPage` itself still receives its variants as already-loaded data — it does not query the repository.** The widget remains exactly as originally designed: a `StatelessWidget` whose `variants` and `modelEntry` are constructor parameters, not a load-on-open query, mirroring `LureDetailsPage`'s own existing design: *"the entry is already fully resolved by whichever `browse()`/`getEntryById()` call produced it, so there is no load-on-open query and no repository dependency."* Lure Model Details is a `StatelessWidget` for the same reason.
>
> **Revised during implementation** — this Key Design Decision originally continued: *"When the browsing list groups `browse()`'s result by model, it already holds every variant belonging to every model in memory... opening a model's details costs zero additional repository calls."* That claim proved incorrect and has been removed. `browse()`'s search filter matches at the individual variant row (not the model), so once a search or filter is active, the in-memory grouped result no longer contains every variant of a matched model — only the ones that happened to satisfy the search. Passing that narrowed list straight into `LureModelDetailsPage` would violate MFS-018 FR-6 ("Opening a Lure Model's Details view always shows the complete, unfiltered set of that model's non-retired variants, regardless of what search text or filters were active"). See **Implementation Notes** for the approved fix: `LureCatalogListPage` now performs one `LureCatalogRepository.getVariantsForModel()` call when a model row is opened, and passes *that* result into `LureModelDetailsPage` instead of the in-memory group. This is one query at open time, not zero — but `LureModelDetailsPage` itself is unaffected: it is still hydrated from already-resolved constructor data, still queries nothing itself, and is still correctly a `StatelessWidget` (Key Design Decision 10 is unchanged).

**3. `LureDetailsPage` is not modified at all.** MFS-018 FR-5 requires every field MFS-015 FR-4 already made displayable (running depth, buoyancy, manufacturer color code) to remain reachable from a variant row. Rather than duplicating that rendering into the new compact row, tapping a Color Variant row (away from its add action) pushes the existing, completely unchanged `LureDetailsPage` for that one variant. It is opened without an `actionsBuilder` from this call site — the add action already lives on the row that opened it, so no AppBar action is needed there. This is the smallest possible design: an existing, working, already-tested component is reused for one of its two prior responsibilities (full single-variant read view) unchanged, while its other prior responsibility (the single AppBar add action) is superseded by the new per-row add action.

**4. `AddToTackleBoxAction` gains one new optional parameter, `initialIsOwned`, default `null`.** Used unmodified (per-page, single-variant) from any future direct-single-variant-view use case, it queries `isOwned()` itself exactly as today. Used per-row inside Lure Model Details — where the owned state for *every* variant of the model is already sitting in memory (see Key Design Decision 5) — the caller supplies `initialIsOwned` directly, skipping the query entirely. This is the same "one optional parameter, default preserves existing behavior" pattern already used repeatedly in this codebase (`LureDetailsPage.actionsBuilder`, `PersonalTackleBoxPage.onSelect`/`embedded`). The alternative — a new, separate per-row add widget duplicating `AddToTackleBoxAction`'s add/photo/retry/snackbar logic — was rejected as an unnecessary abstraction for a change this narrow.

**5. The already-loaded owned-ids set is reused for every row of every model — never queried per row.** `LureCatalogListPage` already loads the full set of owned `LureVariant.id`s once per catalog load (`loadOwnedLureVariantIds`, MFS-016/TD-016's existing owned-badge mechanism). That same set is threaded down into Lure Model Details and, from there, into each row's `initialIsOwned`. This is what makes Key Design Decision 4 possible without reintroducing the N+1 pattern a naive per-row `isOwned()` call would create.

**6. The add-photo dialog's dismissal bug is fixed by adding a value, not by adding dismissal-interception logic.** Today, `showTackleBoxPhotoSourceDialog` returns `TackleBoxPhotoSource?`, and both an explicit "No Photo" tap and a barrier-dismiss/back-press resolve to the same `null` — the caller cannot tell them apart, and currently treats both as "proceed without a photo." The fix adds a third enum value, `TackleBoxPhotoSource.none`, that "No Photo" now returns explicitly; `null` becomes unambiguous shorthand for "nothing was chosen — cancel," which barrier-dismiss, system back (Flutter's default `DialogRoute` behavior, unchanged), and a new explicit Cancel option all consistently produce. No `PopScope`/back-interception code is added — the dialog's own dismiss mechanics were already correct; only the caller's interpretation of `null` was wrong.

**7. The photo-retry dialog omits the "no photo" option.** `AddToTackleBoxAction._retryPhoto`'s entire purpose is attaching a photo to an already-created entry; offering "No Photo" there would be a confusing no-op indistinguishable from Cancel. `showTackleBoxPhotoSourceDialog` gains a second optional parameter, `showSkipOption` (default `true`, preserving today's exact three-option-plus-new-Cancel dialog for the initial add), passed as `false` from the retry call site to omit that option.

**8. `LureCatalogListPage.detailsActionsBuilder`'s signature changes; nothing else about its public surface does.** Because actions now live per-row inside Lure Model Details rather than once in a single-variant AppBar, the builder callback threaded in from `MapScreen` changes shape: from `List<Widget> Function(BuildContext, LureCatalogEntry)` (built once, for an AppBar) to a single-widget, per-variant builder (see [§4](#4-lure-model-details-page)). This is the one call-site-visible signature change this milestone makes. It is confined to the boundary between `lure_catalog` and its one caller (`MapScreen`) — `LureDetailsPage.actionsBuilder` itself is untouched (Key Design Decision 3).

**9. `LureCatalogListItem` is refactored and renamed in place, not deleted and replaced.** Reviewed against the alternative (retire the old file, create an entirely new one): `LureCatalogListItem` has exactly one caller — `LureCatalogListPage`'s browsing list — so once that list becomes model-grouped, the old single-variant-row rendering has no remaining caller at all, and there is no reason to keep two behaviors alive under one flexible widget. The existing file's scaffolding (`InkWell`, `Semantics`, `LureImage`, `lureTypeDisplayLabel`, the owned-badge widget) is reused as-is; the only change to its rendering is removing the distinguishing-detail (color/variant/manufacturer-color-code) line, since a model-level row has no single color to show, and reinterpreting its one `isOwned` boolean parameter as "fully owned" rather than "this exact variant owned" — no type change, only a documentation/semantic change at the call site. Because the widget's identity changes from "one row = one variant" to "one row = one model," the file and class are renamed alongside the refactor (`lure_catalog_list_item.dart`/`LureCatalogListItem` → `lure_catalog_model_list_item.dart`/`LureCatalogModelListItem`), so the name continues to describe what it actually renders — keeping a stale name after a real semantic change would itself be a readability regression. This is a rename-and-refactor of one existing file, including its existing test file (assertions rewritten in place for the new rendering), not a delete-and-recreate.

**10. `LureModelDetailsPage` is a `StatelessWidget` because no mutable state belongs to it.** All state this screen's content depends on — the loaded catalog entries, the owned-ids set, active search/filter selections — remains owned by the parent browsing flow (`LureCatalogListPage`'s `State`) and is passed in as constructor data, exactly as `LureDetailsPage` already does for a single variant. This page performs no repository loading of its own (§5) — everything it renders was already resolved before it was constructed — so there is no loading state, no error state, and no refresh action for it to own. The only mutable, in-flight state anywhere on this screen lives inside each row's own `AddToTackleBoxAction` (busy/owned — already a `StatefulWidget` today, unchanged), which is exactly why per-row state must stay scoped to each row rather than be hoisted onto the page (MFS-018 FR-11; see [§8](#8-error-handling)). Making `LureModelDetailsPage` itself stateful would mean holding data it never mutates and never reloads — an unnecessary abstraction this design deliberately avoids.

---

## 1. Overview

This milestone touches presentation only, inside the two features already established:

| Feature | Responsibility in this milestone |
|---|---|
| `lure_catalog` | Owns the model-grouping logic, the new Lure Model Details view, and the new Color Variant row. Its domain model, Drift tables, mapper, and `LureCatalogRepository` are all unmodified. |
| `personal_tackle_box` | Owns the add-to-tackle-box interaction: `AddToTackleBoxAction` (gains one optional parameter) and the add-photo dialog (corrected dismissal behavior, one new enum value, one new optional parameter). Its domain model, Drift table, and `PersonalTackleBoxRepository` are all unmodified. |
| `map` (`MapScreen`/`LureToolsPage`) | Continues to be the one place these two features meet, per TD-016's Key Design Decision 1 — updates the shape of the builder closure it threads between them, per Key Design Decision 8. |

**Interaction between Lure Catalog and Personal Tackle Box:** unchanged in kind, only in shape. Today, `lure_catalog` exposes one generic extension point (`LureDetailsPage.actionsBuilder`) that `MapScreen` fills with a `personal_tackle_box`-aware closure, so `lure_catalog` never imports `personal_tackle_box`. This milestone adds a second such extension point one level up the new navigation stack (Lure Model Details' per-variant action builder), filled the same way, for the same reason. Nothing about the one-way dependency direction changes.

---

## 2. Catalog List

### How the list becomes model-based

`LureCatalogListPage` continues to call `widget.repository.browse(...)` exactly as it does today — same parameters, same return type, same call sites (`_load()`, `_refresh()`). The only change is what happens to the result afterward: instead of rendering `_entries` (a flat `List<LureCatalogEntry>`, one per variant) directly into `ListView.builder`, it is first grouped into one summary per model.

### Grouping strategy

A single linear pass over the already-sorted `List<LureCatalogEntry>`, identical in shape to `PersonalTackleBoxPage._buildRows`'s existing boundary-detection pattern:

```dart
final class _LureModelGroup {
  _LureModelGroup(this.modelEntry) : variants = [modelEntry.variant];

  final LureCatalogEntry modelEntry;
  final List<LureVariant> variants;
}

List<_LureModelGroup> _groupByModel(List<LureCatalogEntry> entries) {
  final groups = <_LureModelGroup>[];
  final groupsByModelId = <String, _LureModelGroup>{};

  for (final entry in entries) {
    final modelId = entry.variant.lureModelId;
    final existing = groupsByModelId[modelId];
    if (existing == null) {
      final group = _LureModelGroup(entry);
      groupsByModelId[modelId] = group;
      groups.add(group);
    } else {
      existing.variants.add(entry.variant);
    }
  }
  return groups;
}
```

Grouping is keyed by `LureVariant.lureModelId` — the actual foreign key — not by a `(manufacturer, modelName)` text tuple, so it cannot be confused by two different models that happen to share display text. Every field needed for the model-level row (`manufacturer`, `modelName`, `productFamily`, `lureType`, `modelDefaultImageReference`) is identical across every entry in a group (they all resolve from the same `LureModel` row), so the *first* entry encountered for a given model — the `modelEntry` — supplies all of them; no merging logic is needed.

### Sorting

Unchanged. `browse()`'s existing order (manufacturer → model, case-insensitive → variant id) already places every variant of the same model in one contiguous run, which is exactly what the single-pass grouping above requires, and it means the resulting model groups are already in the correct manufacturer → model display order with no separate sort step.

### Search compatibility

Unchanged at the query level: `_refresh()` still calls `browse(searchText: ..., manufacturer: ..., lureType: ...)` exactly as today, matching against manufacturer, product family, model name, color, variant name, and manufacturer color code (MFS-015 FR-2). The only change to the browsing *list* is presentational: it shows the *distinct set of models* among the matching variant rows, not the matching rows themselves one-for-one. A search that matches only one color of a four-color model still surfaces that model in the list (since the query already returns that one matching variant row, which groups into a one-model, one-visible-variant-so-far group).

**Revised during implementation:** opening that model must then show **all** of its variants, per MFS-018 FR-6, not just the one that matched — but `browse()`'s `WHERE` clause filters at the individual variant row, so a narrowed `browse()` result does not contain a matched model's non-matching sibling variants. The in-memory group therefore cannot supply the full list on its own. See **Implementation Notes** for the approved fix: opening a model now issues one dedicated `LureCatalogRepository.getVariantsForModel(lureModelId)` call, which is unaffected by the active search/filter, guaranteeing every non-retired variant of the model is shown regardless of which one(s) satisfied the search that surfaced it.

### Manufacturer filter compatibility

Unchanged. `getDistinctManufacturers()` and the `manufacturer` parameter of `browse()` are used exactly as today; grouping happens after filtering, so a manufacturer filter simply narrows which model groups appear, with no change to how the filter itself is computed or applied.

### Lure type filter compatibility

Unchanged, for the same reason as the manufacturer filter.

### Owned badge and "hide owned" filter (existing behavior, adapted)

MFS-016/TD-016 already added an owned-badge and a "hide owned" toggle to the flat, per-variant list (`loadOwnedLureVariantIds`, `_ownedVariantIds`, `_hideOwned`). MFS-018 does not ask to remove this, and its FR-12 requires everything not explicitly changed to keep working. Adapted to model-level rows:

* **Owned badge:** a model row shows the existing owned badge only when *every* one of its non-retired variants is already owned ("fully owned"). A partially-owned model shows no badge at the model-row level — its individual variants' owned states are shown once its Color Variants list is open (MFS-018 FR-8), which is the more precise place for partial information to live.
* **"Hide owned" filter:** a model is hidden only when it is fully owned, for the same reason — a partially-owned model still has at least one addable variant, so hiding it would hide something actionable.

Both are computed with a cheap `.every()` over each group's variant ids against the already-loaded `_ownedVariantIds` set, evaluated where the list is built (see [§6](#6-performance) for why this does not need to be memoized).

**Future Improvement — partial-ownership progress display.** This milestone only distinguishes "fully owned" from "not fully owned" at the model-row level, deliberately not a three-state or numeric indicator, since MFS-018 does not ask for one and introducing one now would be speculative. A future refinement could instead show partial-ownership progress directly on the model row — for example "2 / 5 owned" — computed from the same `ownedVariantIds`/group-variants data this milestone already assembles, with no new query. Documentation only; not implemented by this milestone.

---

## 3. Navigation Flow

```text
Current:
Lure Catalog (flat, one row per variant)
        ↓
Lure Details (one variant, full fields, AppBar "Add" action)
        ↓
Add-photo dialog → Personal Tackle Box entry

New:
Lure Catalog (one row per model)
        ↓
Lure Model Details (manufacturer, model, family, type — shown once)
        ↓
Color Variants (image, color, length, weight, owned, Add — per variant)
   ├─ tap the row (not Add) → Lure Details (existing, unchanged: full single-variant fields)
   └─ tap Add → Add-photo dialog → Personal Tackle Box entry
```

**Screen ownership:**

| Screen | Owned by | Status |
|---|---|---|
| Lure Catalog browsing list | `lure_catalog` | Modified (`LureCatalogListPage`) |
| Lure Model Details | `lure_catalog` | New |
| Lure Details (single variant, full fields) | `lure_catalog` | Unchanged |
| Add-photo dialog | `personal_tackle_box` | Modified (`tackle_box_photo_picker.dart`) |
| Personal Tackle Box browsing / Owned Entry Detail | `personal_tackle_box` | Unchanged |

Returning from Lure Model Details to the Lure Catalog list refreshes the owned-ids set exactly as `LureCatalogListPage._openDetails` already does today after returning from a details push — the call site changes (it now awaits `LureModelDetailsPage.open` instead of `LureDetailsPage.open`), but the refresh-on-return behavior is identical in kind.

---

## 4. Lure Model Details Page

A new `StatelessWidget`, `LureModelDetailsPage`, replacing `LureDetailsPage` as the browsing list's push destination. It is deliberately stateless — see Key Design Decision 10 for why no mutable state belongs on this page.

```dart
class LureModelDetailsPage extends StatelessWidget {
  const LureModelDetailsPage({
    super.key,
    required this.modelEntry,
    required this.variants,
    required this.ownedVariantIds,
    this.variantActionBuilder,
  });

  final LureCatalogEntry modelEntry;
  final List<LureVariant> variants;
  final Set<String> ownedVariantIds;

  /// Generic, optional per-variant extension point — the same shape of
  /// touch as `LureDetailsPage.actionsBuilder`, one level up the new
  /// navigation stack. `lure_catalog` still never imports
  /// `personal_tackle_box`.
  final Widget Function(
    BuildContext context,
    LureCatalogEntry variantEntry, {
    required bool initialIsOwned,
  })?
  variantActionBuilder;

  static Future<void> open(
    BuildContext context, {
    required LureCatalogEntry modelEntry,
    required List<LureVariant> variants,
    required Set<String> ownedVariantIds,
    Widget Function(
      BuildContext context,
      LureCatalogEntry variantEntry, {
      required bool initialIsOwned,
    })?
    variantActionBuilder,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LureModelDetailsPage(
          modelEntry: modelEntry,
          variants: variants,
          ownedVariantIds: ownedVariantIds,
          variantActionBuilder: variantActionBuilder,
        ),
      ),
    );
  }
}
```

### Common information

Shown once, at the top, from `modelEntry` (`LureCatalogEntry`): manufacturer, product family (if present), model name, lure type — the exact field subset MFS-018 FR-3 requires, using the existing `lureTypeDisplayLabel` extension unchanged.

### Color Variants section

A clearly labeled section ("Väriversiot" or equivalent Finnish wording, per the existing UI-language convention) followed by the variant list. Each row is built from one `LureVariant` in `variants` plus the *same* `modelEntry`'s model-level fields (needed to reconstruct a full `LureCatalogEntry` for that variant, e.g. to open `LureDetailsPage` on tap):

```dart
LureCatalogEntry _entryFor(LureVariant variant) => LureCatalogEntry(
  variant: variant,
  manufacturer: modelEntry.manufacturer,
  modelName: modelEntry.modelName,
  lureType: modelEntry.lureType,
  productFamily: modelEntry.productFamily,
  modelDefaultImageReference: modelEntry.modelDefaultImageReference,
);
```

**This reconstructed `LureCatalogEntry` is a presentation convenience only, not a new source of truth.** It is assembled entirely from data already held in memory (the row's own `LureVariant` plus `modelEntry`'s already-loaded model-level fields) purely so that `LureDetailsPage` — which expects one `LureCatalogEntry` per its existing, unchanged contract — can render it. It is never persisted, never written back to `LureCatalogRepository` or any other repository, and never treated as an independent record with its own identity beyond the `variant.id` it wraps. The single authoritative source for every field it carries remains the row `browse()` originally returned; `_entryFor` only reshapes already-loaded data to fit an existing widget's constructor, and is called fresh every time it is needed rather than cached anywhere.

### Rendering strategy

`ListView.builder` (or a `SliverList` under a `CustomScrollView` if the common-information header should scroll away with the list — an implementation-time choice with no behavioral consequence), matching the same lazy/virtualized discipline `LureCatalogListPage` already uses for its own list, satisfying MFS-018 FR-9.

### Owned indicator

Per row: `ownedVariantIds.contains(variant.id)`, passed straight through to that row's `variantActionBuilder` call as `initialIsOwned` — no query, per Key Design Decision 5.

### Add interaction

Each row calls `variantActionBuilder?.call(context, _entryFor(variant), initialIsOwned: ownedVariantIds.contains(variant.id))` to obtain the widget it renders in its trailing action slot. When `variantActionBuilder` is `null` (no caller supplied one), the row simply renders with no action slot — the same graceful-omission behavior `LureDetailsPage.actionsBuilder` already has today.

### Scrolling behavior

The whole page scrolls as one unit — common information header plus the Color Variants list — via a single scrollable ancestor (`CustomScrollView` with a non-scrolling header sliver plus a `SliverList`, or a `Column` containing a fixed header and an `Expanded` `ListView.builder`; either satisfies FR-9's lazy-rendering requirement for the list portion, since only the list itself needs virtualization, not the small fixed header above it).

### Accessing variant-specific information when needed

Tapping a row (its content area, not its action slot) pushes the existing `LureDetailsPage` for that variant's full field set — including running depth, buoyancy, and manufacturer color code, none of which the compact row repeats inline — via `LureDetailsPage.open(context, _entryFor(variant))`, with no `actionsBuilder` (Key Design Decision 3). This satisfies MFS-018 FR-5 with zero changes to `LureDetailsPage` itself.

---

## 5. Repository Usage

### Repository responsibilities — revised during implementation

`LureCatalogRepository` continues to own exactly what it owned before this milestone — `ensureSeeded()`, `browse()`, `getEntryById()`, `getDistinctManufacturers()`, `getDistinctLureTypes()` — **plus one new method, `getVariantsForModel(String lureModelId)`**, added during implementation once testing proved the original "group `browse()`'s result, zero additional queries" design violated MFS-018 FR-6 (see **Implementation Notes**). No *existing* method gains a new parameter, and no existing method's query shape or return type changes. `PersonalTackleBoxRepository` continues to own exactly what it owns today: `isOwned()`, `add()`, `getAll()`, `getById()`, `attachPhoto()`, `remove()` — no change.

### Query flow for this milestone

1. `LureCatalogListPage._load()`/`_refresh()`: one `browse()` call (unchanged) + one owned-ids load (unchanged, via `loadOwnedLureVariantIds`, itself one `PersonalTackleBoxRepository.getAll()` call, per TD-016).
2. Grouping the result into models: in memory, zero queries (Key Design Decision 1) — used only to decide which model rows appear in the browsing list and to compute the "fully owned" badge/hide-owned filter, never to supply Lure Model Details' variant list (see step 3).
3. Opening `LureModelDetailsPage`: **one query** — `LureCatalogRepository.getVariantsForModel(lureModelId)` — performed by `LureCatalogListPage._openModelDetails` before pushing the route. This is the one deliberate, documented exception to this milestone's "no additional queries" goal, added specifically to satisfy FR-6 (a search/filter-narrowed in-memory group cannot supply a model's complete variant list). `LureModelDetailsPage` itself still performs no query of its own — it renders whatever list it is constructed with, exactly as originally designed (Key Design Decision 2).
4. Tapping a variant row to see its full detail (`LureDetailsPage`): zero queries — the `LureCatalogEntry` is reconstructed in memory from data already held by `LureModelDetailsPage` (now sourced from step 3's query result instead of step 2's group), exactly as `LureDetailsPage` already expects (it has never queried on open).
5. Adding a variant (`AddToTackleBoxAction`, per row): one `PersonalTackleBoxRepository.add()` call on confirmation, identical to today — the only change is that `isOwned()` is *not* called first when `initialIsOwned` is supplied (Key Design Decision 4), which is one fewer query per row than a naive reuse would cost, not an additional one.

### Avoiding duplicated queries

Steps 2, 4, and 5 above are the concrete answer: nothing already available in memory is re-fetched. Step 3's query is new, but it runs exactly once per model-details open — never once per row, and never repeated for data already in memory (the model-level fields it needs for `LureModelDetailsPage`'s header continue to come from the in-memory group, unchanged).

### Avoiding N+1

The risk this design is deliberately built to avoid: rendering *N* variant rows inside Lure Model Details, each independently calling `isOwned()`, would be exactly one query per row. Key Design Decisions 4 and 5 close this off structurally — `initialIsOwned` is always supplied from the one already-loaded set, so `AddToTackleBoxAction`'s own internal `isOwned()` query path is simply never reached from this call site. `getVariantsForModel()` does not reintroduce this risk: it is called exactly once per model-details open (not once per variant row), the same "one query per screen, not per row" shape every other query in this table already has.

### Avoiding unnecessary repository changes

No repository change was found to be necessary anywhere in this design. Every requirement in MFS-018 is satisfiable with data `browse()` and `getAll()` already return today.

---

## 6. Performance

### Model grouping

O(n) over the currently-loaded, already search/filter-narrowed `_entries` list (see [§2](#2-catalog-list) — grouping runs on whatever `browse()` returned for the *active* query, not the full catalog). For a catalog of the scale MFS-015's own Performance Expectations anticipate (thousands of variants, in the limit), this is the same order of cost `PersonalTackleBoxRepository`'s own grouping-free-but-comparable `_filteredItems`/`_buildRows` pass already accepts today for a smaller (tackle-box-sized) list, without memoization.

### Opening a model (revised during implementation)

`getVariantsForModel(lureModelId)` is one indexed lookup (`lureVariants.lureModelId` — the same foreign key `browse()` already joins on) returning only that one model's non-retired variants, at most a handful of rows even for a large catalog. It runs exactly once per model-details open, triggered by a user tap, not on every `build()` and not once per row — a materially different cost shape from the N+1 pattern this design otherwise avoids (see [§5](#5-repository-usage)'s "Avoiding N+1").

### Large catalogs

Unaffected beyond the grouping pass above: `browse()`'s own query performance is unchanged (MFS-015/TD-015's existing indexing and single-join design), and the number of *models* shown is always less than or equal to the number of *variants* `browse()` returns, so the visible list this milestone renders is never longer than before, and is usually meaingfully shorter.

### Lazy loading

Both the model-grouped browsing list and the new Color Variants list use `ListView.builder` (or `SliverList`), so off-screen rows are never built, matching the discipline already established for the browsing list today and extending it one level down, per MFS-018 FR-9.

### Rebuild behavior

Grouping is recomputed wherever the list is built (inside `_buildBody()`, alongside the existing `_hideOwned`-based filtering that already runs there today) rather than cached in a separate field. This is deliberately **not** premature optimization to avoid: it mirrors the exact pattern `PersonalTackleBoxPage._filteredItems`/`_buildRows` already use today (recomputed on every `build()`, never memoized), applied to a list whose size is already bounded by the current search/filter result, not the full catalog. If a future catalog scale ever makes this measurably slow, moving the grouping computation into `_load()`/`_refresh()` (alongside where `_entries` itself is already set) is a small, purely additive change — not something this milestone needs to build speculatively.

### Image loading

Unchanged: `LureImage`'s existing `cacheWidth`/`cacheHeight` sizing (decoding at the requested display size, never full source resolution) is reused as-is for both the model-row thumbnail and the Color Variants row thumbnail, just called with a smaller `size` for the more compact row.

### Variant rendering

The Color Variants list only builds visible rows (lazy loading, above); each row's own build cost is a small, fixed amount of work (an image, a few text fields, one action widget) independent of how many variants the model has in total — the same cost profile the existing flat catalog row already has today, just relocated one screen deeper.

---

## 7. Add Flow

### Selecting a variant

The user taps a Color Variant row's Add action (not the row itself, which opens `LureDetailsPage` instead — Key Design Decision 3). This calls into `AddToTackleBoxAction._onAddPressed`, unchanged in structure from today.

### Opening the photo dialog

`showTackleBoxPhotoSourceDialog(context)` (default `showSkipOption: true` for this call site) presents four options: Camera, Gallery, No Photo, Cancel.

### Completing the add

* **Camera / Gallery chosen:** unchanged from today — the native picker runs; on success, `_add(pendingPhoto)` is called with the picked photo; on native-picker cancellation, permission denial, or pick failure, the existing handling applies unchanged (see [§8](#8-error-handling)).
* **No Photo chosen** (`TackleBoxPhotoSource.none`): `_add(null)` is called directly — the add completes with no photo, exactly as today's behavior for this explicit choice.

Either path results in exactly one `PersonalTackleBoxRepository.add()` call, exactly as today.

### Cancellation

Tapping the new explicit Cancel option pops the dialog with no value (`Navigator.of(context).pop()`), resolving `showTackleBoxPhotoSourceDialog`'s `Future` to `null`. `_onAddPressed` now checks for this and returns immediately — **no call to `_add` at all, and therefore no `PersonalTackleBoxRepository.add()` call.**

### Dialog dismissal

Tapping outside the dialog (the modal barrier) resolves the same `Future` to `null` — Flutter's own default `showDialog` behavior, unchanged. Handled identically to explicit Cancel, above: no add.

### Android back behavior

The system back gesture, while the dialog is showing, pops the dialog's route the same way any unhandled back-press does — resolving to `null`, identical in effect to barrier-dismiss and explicit Cancel. No special back-interception code is added (Key Design Decision 6); the existing default is already correct once the caller stops conflating `null` with "no photo."

**Corrected logic in `_onAddPressed`** (replacing today's `if (source != null) { pick... } ... await _add(pendingPhoto)` unconditional fallthrough):

```dart
final source = await showTackleBoxPhotoSourceDialog(context);
if (!mounted || source == null) {
  return; // Cancel, dismissal, or back — nothing is added.
}

PendingTackleBoxPhoto? pendingPhoto;
if (source != TackleBoxPhotoSource.none) {
  // existing camera/gallery pick logic, unchanged
}
await _add(pendingPhoto);
```

---

## 8. Error Handling

| Scenario | Behavior |
|---|---|
| Image picker cancelled (user backs out of the native camera/gallery UI, not this feature's own dialog) | Unchanged from today: `TackleBoxPhotoPickCancelled` — the add-to-tackle-box action remains available to try again, no entry created. |
| Camera failure (permission denied, platform exception) | Unchanged from today: `TackleBoxPhotoPickPermissionDenied`/`TackleBoxPhotoPickFailed` — a clear message is shown, and the add still completes without a photo (the entry itself is not blocked by a photo failure, per MFS-016's existing Error Handling). |
| Gallery failure | Same as camera failure, above. |
| Add-photo dialog dismissed (barrier tap, system back, or explicit Cancel) | **New, corrected behavior** (this milestone): the entire add attempt is cancelled. No `TackleBoxEntry` is created, no photo is processed, and the row returns to its normal not-yet-owned state, ready to try again. |
| Duplicate add attempts (rapid double-tap on the same row's Add action, or two different rows racing) | Unchanged from today: `AddToTackleBoxAction`'s own `_isBusy` guard prevents a second `_onAddPressed` call while one is in flight for that row; `PersonalTackleBoxRepository.add()`'s existing `isOwned` pre-check plus the database's `uniqueKeys` constraint (MFS-016 FR-7) remain the authoritative, race-safe backstop regardless of which screen the add was triggered from. Because each row owns its own `AddToTackleBoxAction` instance (and therefore its own `_isBusy`), a double-tap on *row A* cannot be blocked or confused by an in-flight add on *row B* — satisfying MFS-018 FR-11. |

---

## 9. Shared Components

Two presentation-only widgets are involved; both are pure — no repository access, no business logic, only rendering and callback invocation.

**`LureCatalogModelListItem`** (`lib/features/lure_catalog/presentation/widgets/lure_catalog_model_list_item.dart`, refactored and renamed from `lure_catalog_list_item.dart`/`LureCatalogListItem` — see Key Design Decision 9)
Renders one model-group's summary row: image (from `modelEntry.modelDefaultImageReference`), manufacturer, model name, lure type, and an optional "fully owned" badge. Takes `modelEntry`, a `fullyOwned` bool, and an `onTap` callback — no knowledge of grouping, ownership computation, or navigation targets. Reuses the existing widget's layout conventions as-is (`LureImage`, `lureTypeDisplayLabel`, the owned-badge pattern); the distinguishing-detail (color/variant/manufacturer-color-code) line is removed, since a model-level row has no single color to show.

**`ColorVariantRow`** (`lib/features/lure_catalog/presentation/widgets/color_variant_row.dart`, new)
Renders one variant's compact row inside Lure Model Details: image (`entry.effectiveImageReference`), color/distinguishing name, length (if present), weight (if present), and a trailing slot for the caller-supplied action widget (built by `variantActionBuilder`, never by this widget itself). Takes an `onTap` for the row-body-tap-opens-`LureDetailsPage` behavior (Key Design Decision 3) separately from the action slot, so the two tap targets never conflict.

Neither widget imports `PersonalTackleBoxRepository`, `AddToTackleBoxAction`, or anything else from `personal_tackle_box` — both receive their action widget, or their owned/fully-owned boolean, as plain data from their caller, preserving `lure_catalog`'s existing read-only, dependency-free posture.

---

## 10. Testing Strategy

Follows the same layered testing philosophy as every prior TD in this project.

**Model grouping** (new, pure-function unit tests, e.g. `lure_catalog_model_grouping_test.dart` or inline in the list page's own test file):
groups a flat list spanning several models correctly; a model with exactly one variant produces a one-variant group; grouping order matches `browse()`'s existing manufacturer → model → variant sort; a variant list containing an unrecognized `lureType` still groups correctly (no special-casing needed, consistent with MFS-015's existing open-string-code tolerance).

**Search compatibility** (`lure_catalog_list_page_test.dart`, extended):
searching for a color unique to one variant of a multi-variant model still surfaces that model in the grouped list; opening that model shows all of its variants, not just the one that matched (MFS-018 FR-6).

**Filters** (`lure_catalog_list_page_test.dart`, extended):
manufacturer/lure-type filters narrow which model groups appear, exactly as they narrow which variant rows appear today.

**Navigation**:
tapping a model row opens Lure Model Details for that model; tapping a variant row's body (not its Add action) opens `LureDetailsPage` for that specific variant; returning from either screen refreshes the owned-ids set and re-renders the grouped list.

**Variant selection**:
tapping Add on a specific row in a multi-variant model's Color Variants list creates a `TackleBoxEntry` for *that* variant only, verified by checking the created entry's `lureVariantId` against the tapped row's variant, not any sibling variant of the same model.

**Owned indicators**:
a model with zero owned variants shows no badge and is not hidden by "hide owned"; a model with some but not all variants owned shows no top-level badge and is not hidden; a model with all variants owned shows the badge and is hidden when "hide owned" is active; inside Lure Model Details, each row's owned state matches `ownedVariantIds` exactly, independent of its sibling rows.

**Add flow**:
Camera/Gallery/No-Photo each still complete the add exactly as today (regression coverage, since the underlying `_add` path is unchanged); a photo failure during add still creates the entry without a photo, unchanged from today.

**Dialog cancellation**:
tapping the new explicit Cancel option creates no `TackleBoxEntry` and leaves the row's state unchanged.

**Dialog dismissal**:
tapping outside the dialog (`tester.tapAt` on the barrier, or `tester.tap(find.byType(ModalBarrier))`) creates no `TackleBoxEntry`; simulating the Android back action (`tester.pageBack()` or an equivalent route-pop) while the dialog is open creates no `TackleBoxEntry`.

**Regression tests**:
existing `AddToTackleBoxAction` tests (already-owned disabled state, camera/gallery/photo-failure paths, retry-on-photo-failure) continue to pass unmodified with `initialIsOwned` omitted (default `null`, preserving today's self-querying behavior); existing `LureDetailsPage` tests are entirely unaffected, since that widget receives no code changes; `LureCatalogListPage`'s existing widget tests are rewritten against the new grouped-list behavior, and `lure_catalog_list_item_test.dart`'s existing assertions are updated in place (renamed alongside its widget, per Key Design Decision 9) to match the new model-row rendering, since the prior single-variant/distinguishing-detail assertions no longer describe the shipped UI.

---

## 11. Risks

| Risk | Category | Mitigation |
|---|---|---|
| An extra tap (Catalog → Model Details → variant row) adds friction versus the old flat list, most noticeably for a model that has only one color. | UX | Accepted, not special-cased: MFS-018's own acceptance criteria require exactly one catalog entry per model with no stated exception for single-variant models, and a quick-add shortcut bypassing this is explicitly named as a *future* extension (MFS-018), not this milestone's problem to solve. Special-casing it now would be exactly the kind of scope creep MFS-018's Product Principles warn against. |
| Recomputing model grouping and "fully owned" status on every `build()` could become measurably slow at very large catalog scale. | Performance | Mitigated by construction: grouping runs only over the already search/filter-narrowed result, not the full catalog (§6), and mirrors an already-accepted, unmemoized precedent (`PersonalTackleBoxPage._filteredItems`). A trivial, purely additive move to compute-once-at-load is available later if ever needed — not built speculatively now. |
| Two "details" pages now exist (`LureModelDetailsPage`, `LureDetailsPage`) with similar names and adjacent responsibilities, which could confuse future maintainers about which one to extend. | Maintainability | Mitigated by clear, MFS-018-matching terminology in both class names and doc comments: "Lure Model Details" (a model's variant list) versus "Lure Details" (one variant's full fields) — the same distinction MFS-018 itself draws throughout. |
| `AddToTackleBoxAction`'s `initialIsOwned`-omitted (self-querying) code path becomes unused by any current call site once `MapScreen` moves entirely to the per-row, `initialIsOwned`-supplied path. | Maintainability | Not a dead path: `LureDetailsPage.actionsBuilder` remains a live, generic extension point that could still construct an `AddToTackleBoxAction` with `initialIsOwned` omitted for any future single-variant-view-with-actions use case, and its existing tests continue to exercise it directly regardless of whether `MapScreen` currently uses that path. |
| Very long manufacturer names, model names, or localized strings (Finnish compound words can run long) could overflow or break the layout of the model row, the Color Variants row, or the common-information header. | UX / Maintainability | Every text field in `LureCatalogModelListItem`, `ColorVariantRow`, and the common-information header must gracefully truncate (`overflow: TextOverflow.ellipsis`, an appropriate `maxLines`) or otherwise adapt (e.g. wrap within a bounded number of lines) rather than overflow the row or force it to an unbounded width — the same discipline already expected of `Text` widgets elsewhere in this application's Material 3 layouts. This is a rendering detail for implementation to apply consistently, not a reason to constrain what manufacturers/models/localized labels may contain. |

---

## 12. Future Compatibility

* **Variant filtering (within a model)** — the Color Variants list is already a simple, in-memory list by the time it renders; adding a size/color filter there would be the same kind of presentation-only, in-memory filtering the top-level search/manufacturer/lure-type filters already use, needing no new query.
* **Favorite variants** — a natural fit for the same trailing action slot `ColorVariantRow` already reserves for the add action; a favorite toggle would be built the same way (a generic, optional builder supplied by whichever future feature owns favorites), following the exact extension-point pattern this milestone already establishes twice over.
* **Recommendations** — would naturally consume the model-grouped read model this milestone introduces (`modelEntry` + `variants`) as its unit of recommendation, rather than a flat variant list.
* **Stock/availability information** — a future nullable field on `LureModel`/`LureVariant` (an MFS-015-level concern, not this one) would slot into `ColorVariantRow`'s existing layout exactly like length/weight already do — one more optional field, no structural change.
* **Quick-add shortcuts** — would reuse the same per-variant `variantActionBuilder` extension point this milestone introduces, just invoked from a different surface (e.g. directly from the top-level model row for models with exactly one variant), rather than needing a new mechanism.
* **Cloud synchronization** — unaffected. This milestone is presentation-only; nothing here touches the repository-hides-the-data-source principle (ADR-0001, ADR-0005) that already governs both features' data layers.

---

## Dependencies

No new external package dependencies. This milestone reuses, unchanged:

* Flutter, Dart
* The existing Repository pattern, feature-first structure, and manual dependency construction (ADR-0001, ADR-0003, ADR-0006)
* `LureCatalogRepository.browse()`/`getDistinctManufacturers()`/`getDistinctLureTypes()` (MFS-015/TD-015), consumed exactly as today, plus its new `getVariantsForModel()` method (added during implementation; see Implementation Notes)
* `PersonalTackleBoxRepository.isOwned()`/`add()`/`getAll()` (MFS-016/TD-016), consumed exactly as today
* `LureImage`, `lureTypeDisplayLabel`, `LureDetailsPage` (MFS-015/TD-015), reused unchanged
* `AddToTackleBoxAction`, `TackleBoxPhotoPicker` (MFS-016/TD-016), extended additively

`flutter_riverpod` is not used by this feature, for the same reasons documented in TD-015/TD-016/TD-017.

---

## Expected Files To Create

```text
lib/features/lure_catalog/presentation/widgets/lure_model_details_page.dart
lib/features/lure_catalog/presentation/widgets/color_variant_row.dart
```

Plus new test files under `test/features/lure_catalog/...` per [§10](#10-testing-strategy).

## Expected Files To Rename And Refactor

```text
lib/features/lure_catalog/presentation/widgets/lure_catalog_list_item.dart
    → lib/features/lure_catalog/presentation/widgets/lure_catalog_model_list_item.dart
    (class LureCatalogListItem → LureCatalogModelListItem; see Key Design Decision 9)

test/features/lure_catalog/presentation/widgets/lure_catalog_list_item_test.dart
    → test/features/lure_catalog/presentation/widgets/lure_catalog_model_list_item_test.dart
    (assertions rewritten in place for the new model-level rendering)
```

Confirm at implementation time that no other file references `LureCatalogListItem` before renaming it (per this document's review, `LureCatalogListPage` is its only caller).

## Expected Files To Modify

```text
lib/features/lure_catalog/presentation/widgets/lure_catalog_list_page.dart      (grouping, push LureModelDetailsPage, adapt owned/hide-owned semantics)
lib/features/lure_catalog/data/lure_catalog_repository.dart                     (added during implementation: new getVariantsForModel() method — see Implementation Notes)
lib/features/lure_catalog/data/lure_catalog_mapper.dart                        (added during implementation: expose variant-row mapping as a public method, reused by getVariantsForModel())
lib/features/personal_tackle_box/presentation/widgets/add_to_tackle_box_action.dart  (initialIsOwned parameter, corrected dismissal handling)
lib/features/personal_tackle_box/presentation/widgets/tackle_box_photo_picker.dart   (TackleBoxPhotoSource.none, explicit Cancel option, showSkipOption parameter)
lib/features/map/presentation/widgets/lure_tools_page.dart                      (thread the retyped per-variant builder)
lib/features/map/presentation/map_screen.dart                                   (retype/rename _buildLureDetailsActions to build one per-variant action)
```

Modify generated Drift files only through code generation — none are expected to change, since no schema changes are made.

---

## Implementation Notes

### Deviation: `getVariantsForModel()` replaces the "zero additional queries" design for opening Lure Model Details

**What was originally designed.** Key Design Decision 2 (as originally written) and §5's query flow claimed that opening `LureModelDetailsPage` costs zero additional repository calls, because grouping `browse()`'s already-loaded result by `lureModelId` would already hold every variant of every model in memory.

**Why it proved invalid.** `LureCatalogRepository.browse()`'s search filter (`lureModels.searchText.like(pattern) | lureVariants.searchText.like(pattern)`) is applied per joined row — i.e. per variant — not per model. When a search matches only one variant of a multi-variant model (e.g. a color unique to that variant), `browse()` returns only that one row; its sibling variants, which did not individually match the search text, are excluded from the result entirely. Grouping that narrowed result by `lureModelId` therefore produces a group containing only the matching variant(s), not the model's complete set. A widget test written against this exact scenario (search for a single unique color, then open the model) demonstrated the bug directly: `LureModelDetailsPage.variants` had length 1 instead of 3. This is a direct violation of **MFS-018 FR-6**, a mandatory functional requirement: *"Opening a Lure Model's Details view always shows the complete, unfiltered set of that model's non-retired variants, regardless of what search text or filters were active on the browsing list when the model was selected."*

**Options considered.**
1. *Keep two in-memory collections in `LureCatalogListPage`* (an unfiltered `_allEntries` alongside the filtered `_entries`), grouping the model's variants from the unfiltered copy at open time. Rejected: this duplicates catalog state client-side, in two collections that would need to be kept consistent with each other and with the repository, for no benefit over just asking the repository — the repository is the single source of truth for this data, not the presentation layer.
2. *Add `LureCatalogRepository.getVariantsForModel(String lureModelId)`* and query it once when a model row is opened. **Chosen.** The repository already has every piece this needs (an index on `lureVariants.lureModelId`, the same foreign key `browse()` already joins on); asking it directly is simpler, keeps the repository as the single source of truth, and requires no new presentation-layer state to keep in sync with anything.

**What changed as a result.**
* `LureCatalogRepository` gains one new method, `getVariantsForModel(String lureModelId)`, returning every non-retired variant of the given model (ordered by variant id, matching `browse()`'s own tertiary sort). `browse()`, `getEntryById()`, `getDistinctManufacturers()`, and `getDistinctLureTypes()` are all unchanged — no existing method's signature, query shape, or return type changed, and no domain model or database schema changed.
* `LureCatalogMapper`'s previously-private `_variantFromRow` is exposed as a public `variantFromRow`, so both `entryFromRows` and the new repository method share the same row-to-domain mapping rather than duplicating it. This is a visibility change only; its behavior is identical.
* `LureCatalogListPage._openModelDetails` now performs one `await widget.repository.getVariantsForModel(...)` call before pushing `LureModelDetailsPage`, and passes that result (not the in-memory group's variants) as `variants`. The in-memory group is still used for everything it originally was — which model rows appear, and the "fully owned"/hide-owned computation — just no longer as the source of a model's variant list once its details are opened. If the query fails, the error is caught, logged, and surfaced as a `SnackBar`; the page is not pushed (mirroring how other async failures in this app degrade — e.g. `AddToTackleBoxAction`'s own error handling — rather than pushing a page with incomplete data).
* `LureModelDetailsPage` itself is **unchanged** by this deviation: it is still constructed with already-resolved `modelEntry`/`variants`/`ownedVariantIds`, still performs no repository access of its own, and is still correctly a `StatelessWidget` (Key Design Decision 10 stands exactly as originally justified). Only its caller's data source changed.

**Why this is an acceptable tradeoff.** `LureCatalogRepository` remains the single source of truth for catalog data — no duplicated or hand-synchronized presentation-layer state was introduced. The additional query occurs exactly once, only when a user opens a model's details (not per row, not per `build()`), so it does not reintroduce the N+1 pattern this design otherwise avoids (see §5's "Avoiding N+1"). Correctness for a mandatory functional requirement (FR-6) is a higher priority than the zero-query goal, which was never itself an MFS-018 requirement — only an internal design aspiration that turned out not to be achievable without either violating FR-6 or duplicating repository-owned state client-side.

### Deviation: `AutomaticKeepAliveClientMixin` on `_LureCatalogListPageState`

**TD-018 originally made no explicit statement about `TabBarView` lifecycle.** Nothing in this document's original text (Key Design Decisions, §1–§12) mentions how `LureCatalogListPage`'s `State` behaves when it is the non-visible tab inside `LureToolsPage`'s `TabBarView` — that lifecycle question was simply outside this document's original scope, since MFS-018/TD-018 is about the browsing list's content and grouping, not the tabbed shell around it (that shell is TD-016's).

**Testing revealed an implicit lifecycle dependency.** While rewriting `lure_tools_page_test.dart`'s pre-existing "switching tabs and back preserves the Lure Catalog manufacturer filter" and "...preserves the Lure Catalog scroll position" tests for the new grouped-list behavior, both started failing. Investigation (A/B testing the exact same tests against the pre-MFS-018 commit via `git stash`) confirmed this milestone's changes cause `TabBarView` to genuinely dispose and recreate `LureCatalogListPage`'s `State` when the user switches to the Personal Tackle Box tab and back — resetting the search text, manufacturer/lure-type filter, hide-owned toggle, and scroll position to their initial values. This reproduced even with the row-rendering temporarily swapped back to a flat, pre-MFS-018-shaped, trivially-rendered list, ruling out the grouping logic, `LureCatalogModelListItem`, and `LureModelDetailsPage` as the direct cause; the exact triggering line was not isolated within a reasonable investigation budget, but the state-loss itself was conclusively confirmed and is new in this milestone (the equivalent pre-MFS-018 test passes reliably against the last commit). `LureCatalogListPage`'s `State` never used `AutomaticKeepAliveClientMixin` even before this milestone — its cross-tab persistence was always an *implicit* dependency on `TabBarView`'s default page-caching behavior happening to keep both tabs' pages alive, never an explicit guarantee. This milestone's changes shifted that incidental timing enough to expose the gap. Both affected tests were written well before MFS-018 (TD-016/`LureToolsPage`), so preserving this behavior is a pre-existing product expectation this document simply never had to make explicit before.

**`AutomaticKeepAliveClientMixin` preserves the intended UX.** `_LureCatalogListPageState` now mixes in `AutomaticKeepAliveClientMixin`, implemented via the normal, textbook pattern for this mixin — nothing custom:

```dart
class _LureCatalogListPageState extends State<LureCatalogListPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // ...unchanged...
  }
}
```

This directly restores the guarantee the three affected tests already assert: the manufacturer filter, search text, hide-owned toggle, and scroll position all now survive switching to the Personal Tackle Box tab and back, exactly as a user would expect.

**This is a Flutter-standard lifecycle solution, not a custom mechanism.** `AutomaticKeepAliveClientMixin` is the framework's own, documented mechanism for exactly this scenario (a `State` that should survive being scrolled off-screen inside a `PageView`/`TabBarView`/lazily-built list). No custom keep-alive tracking, no manual `PageStorage` usage, and no change to how `LureToolsPage` builds its `TabBarView` were introduced — the fix is entirely local to the one `State` class that needed it.

**This is a UX preservation improvement, not an architectural change.** It adds one mixin, one getter override, and one `super.build(context)` call to an existing `State` class — no new repository method, no new domain type, no new widget, no change to feature boundaries, and no change to `LureCatalogRepository`'s responsibilities. It restores behavior the page's own pre-existing test suite already specified as correct; it does not change what the page does, only how reliably its existing behavior survives a tab switch.

---

## Validation

```bash
dart format .
flutter analyze
flutter test
```

All must pass. Confirm before implementing that no other file references `LureCatalogListItem` (see Expected Files To Rename And Refactor).

---

## Definition of Done

* The implementation satisfies all requirements in MFS-018.
* The implementation follows TD-018, or documents and justifies each deviation.
* The Lure Catalog browsing list shows exactly one entry per model with at least one non-retired variant.
* Search, manufacturer filtering, and lure-type filtering all continue to work unchanged, narrowing which models appear.
* Opening a model always shows the complete set of its non-retired variants, regardless of active search/filter.
* Adding a variant from the Color Variants list creates exactly one `TackleBoxEntry`, and only for the tapped variant.
* Owned variants are clearly identified per row inside Lure Model Details; a "fully owned" model is identified at the top-level list.
* After successfully adding a lure, owned indicators (the row's own state inside Lure Model Details, and the "fully owned" badge/hide-owned filter back on the browsing list) update immediately — the user never needs to reopen the catalog or trigger a manual refresh to see the change reflected.
* Dismissing the add-photo dialog by any means (tap-outside, system back, explicit Cancel) never creates a `TackleBoxEntry`.
* Camera, Gallery, and explicit No Photo all still complete the add exactly as before.
* No change was made to any domain model, database schema, or *existing* repository method signature in `lure_catalog` or `personal_tackle_box`. (One new, read-only `LureCatalogRepository` method, `getVariantsForModel()`, was added — a documented deviation; see Implementation Notes.)
* Opening a Lure Model's Details view shows the complete set of its non-retired variants even when the browsing list's active search or filter matched only some of them (MFS-018 FR-6), verified by a dedicated regression test.
* `flutter analyze` passes.
* `flutter test` passes.
* Architecture review is completed.
* Physical Android testing is completed.
