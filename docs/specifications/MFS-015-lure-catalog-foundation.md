# MFS-015 — Lure Catalog Foundation

## Status

Draft

## Related

- Future: MFS-016 — Personal Tackle Box
- Future: MFS-017 — Assign Lure to Catch

---

## Purpose

Establish the foundation for a global, shared **Lure Catalog**: a browsable, searchable, read-only reference dataset describing commercially available lure products.

This milestone introduces the domain model, local persistence, and browsing/search/filter/detail presentation for the catalog. It intentionally does not introduce any concept of a user owning, selecting, or attaching a lure to anything — that begins with MFS-016 (Personal Tackle Box) and MFS-017 (Assign Lure to Catch).

The catalog must be designed so that:

- it can scale from a small development seed set to thousands of product variants without a destructive remodel,
- it can later be kept in sync with a server-managed canonical catalog, and
- it never depends on network access to function.

---

## User Value

Anglers currently have no structured way to look up lure product information inside the app. This milestone delivers immediate, self-contained value:

- Anglers can browse and identify real lure products by manufacturer, series, model, and variant.
- Anglers can search for a lure they own or are considering, entirely offline (e.g. at the lake, in a tackle shop with poor signal).
- The catalog becomes the stable reference point that later milestones (Personal Tackle Box, Assign Lure to Catch, and eventually lure-based statistics) build on, without requiring rework of this foundation.

---

## Scope

### In Scope

- A `LureModel` / `LureVariant` domain model (see [Conceptual Data Model](#conceptual-data-model)).
- Local Drift persistence for the catalog.
- A small, hand-authored local seed catalog for development and testing.
- Browsing the catalog.
- Searching the catalog by text.
- Filtering the catalog, at minimum by manufacturer and lure type.
- A read-only Lure Details view for a single catalog variant.
- Fully offline operation.

### Out of Scope

See [Out of Scope](#out-of-scope) for the complete list. Notably: Personal Tackle Box, assigning a lure to a catch, any user-facing catalog creation/edit/delete, user-uploaded photos, favorites, statistics, recommendations, admin/moderation tooling, external APIs, barcode scanning, and cloud synchronization.

---

## User Stories

**As an angler**
I want to browse a catalog of real lure products
So that I can identify lures I own or am interested in.

**As an angler**
I want to search the catalog by name
So that I can quickly find a specific lure without scrolling.

**As an angler**
I want to filter the catalog by manufacturer and lure type
So that I can narrow down a large catalog to what's relevant to me.

**As an angler**
I want to open a lure's details
So that I can see its manufacturer, series, model, color, size, weight, running depth, and buoyancy at a glance.

**As an angler fishing without signal**
I want the catalog to work fully offline
So that I can look up lure information at the lake.

---

## Conceptual Data Model

This section defines the concepts and their relationships at the specification level. Exact Drift table/column design, indexing, and identifier format are Technical Design (TD-015) concerns.

### Keeping concepts distinct

| Concept | Meaning | Example |
|---|---|---|
| Manufacturer | The company that makes the product | Rapala |
| Product family / series | A named product line, when the manufacturer uses one | X-Rap |
| Model | The specific named/numbered product within a family | X-Rap Shad XRS08 |
| Variant | One specific, independently purchasable catalog entry: a model in one concrete color/size/spec combination | X-Rap Shad XRS08, 8 cm, "Hot Craw" |
| Display name | A derived, human-readable string composed from the above for lists, search results, and titles | "Rapala X-Rap Shad XRS08 — Hot Craw (8 cm)" |

The display name must always be **derivable from structured fields**. It must never be the stored source of truth for identity, search matching, or grouping — it is a presentation convenience, not a data field the rest of the model depends on.

### Two-level structure: LureModel and LureVariant

A lure model may exist in several lengths, weights, colors, buoyancy behaviors, and running-depth ratings. Flattening manufacturer/series/model text onto every single color-and-size row would duplicate the same identifying information across potentially thousands of rows, and would make "how many variants does this model come in" and "browse by model" harder to reason about. A two-level structure avoids this without introducing more normalization than the catalog currently needs:

```text
LureModel
├── id
├── manufacturer            (required)
├── productFamily            (optional — not every manufacturer names a series)
├── modelName                (required)
├── lureType                 (required)
└── defaultImageReference     (optional)

LureVariant
├── id
├── lureModelId              (required — references LureModel)
├── variantName               (optional — manufacturer's own name for this variant, when it uses one distinct from color)
├── colorName                (optional)
├── manufacturerColorCode     (optional — the manufacturer's own variant/color code; not RGB, not a normalized color palette, not an application-defined color category)
├── lengthMillimeters        (optional)
├── weightGrams               (optional)
├── minRunningDepthMillimeters (optional)
├── maxRunningDepthMillimeters (optional)
├── buoyancy                 (optional)
├── imageReference            (optional — overrides the model's default image when present)
├── createdAt
└── updatedAt
```

Every field on `LureVariant` other than its identifier, its `LureModel` reference, and its timestamps is optional. This is deliberate: not every lure type has a meaningful running depth (e.g. a jig), not every product publishes an exact weight, and the catalog must accept incomplete manufacturer data without breaking. A missing value must never be represented by a placeholder number (such as `0`) — it must be stored as absent.

This mirrors the existing measurement convention used by `Catch` (`weightGrams`, `lengthMillimeters`): optional integers in a stable canonical unit, with unit conversion and formatting left to the presentation layer.

### Why a flat variant instead of a third (size vs. color) level

Some manufacturers vary a model along two largely independent axes — size and color — where color does not change the physical dimensions. A fully normalized catalog could model this as a third level (`LureSizeVariant` containing physical specs, further split into `LureColorVariant` for color/image only). This milestone deliberately does not introduce that third level: it would add real complexity for a distinction that varies by manufacturer and is not needed to satisfy any requirement in this milestone. Each `LureVariant` instead carries its own full physical specification, even when that means the same length/weight/depth values are repeated across several color rows of the same model. This redundancy is cheap at the scale this catalog is expected to reach and can be normalized further later — as an additive change — if it ever becomes a real problem.

### Manufacturer as a plain field, not a separate entity

`manufacturer` is stored as a stable text value on `LureModel`, not as its own relational entity with a separate identifier. A normalized `Manufacturer` entity (for logos, canonical spelling, or manufacturer-level metadata) is a reasonable future extension, and nothing in this design prevents adding it later as an additive migration. Introducing it now would be more structure than this milestone needs.

### Lure type

`lureType` is persisted as a **stable string code**, not a closed Dart enum. `FishSpecies` is a fixed, curated biological taxonomy that the application fully controls; `lureType` is not — the set of lure types is effectively open-ended, defined by manufacturers and, eventually, a server-managed catalog. The application must be able to load, browse, search, and filter a `LureModel` whose `lureType` code it does not yet recognize. An unrecognized code must never fail, throw, or block catalog loading.

Known codes may have a localized (Finnish) display label, following the same display-name-extension approach already used for `FishSpecies`. An unrecognized code must still render — for example by falling back to the raw code or a generic label — rather than being rejected.

Representative known codes for the initial seed catalog (not an exhaustive or closed list): `crankbait`, `jerkbait`, `spinnerbait`, `spinner`, `spoon`, `soft_plastic`, `jig`, `swimbait`, `topwater`, `wobbler`.

### Identity

Catalog identity must not depend only on a display name, because display names are derived, can be recomputed, and are not guaranteed unique (two different products can legitimately have similar or identical marketing names). Each `LureModel` and each `LureVariant` must have a stable identifier that:

- is assigned once and never recomputed from other fields,
- does not change if manufacturer/series/model text is corrected or reformatted later,
- is stable enough to be referenced by a future `LureModel`/`LureVariant` from a server-managed catalog, and by future features (Personal Tackle Box, Assign Lure to Catch) without those features needing to change when catalog text changes.

The exact identifier scheme (e.g. a stable authored slug for seed data vs. a future server-issued identifier) is a Technical Design decision.

### Canonical units

Length (`lengthMillimeters`) and running depth (`minRunningDepthMillimeters`, `maxRunningDepthMillimeters`) are stored canonically in whole millimeters; weight (`weightGrams`) is stored canonically in whole grams — the same "store canonical, format for display" approach already used by `Catch`. The presentation layer is responsible for converting these canonical values into user-friendly display units (for example, meters for running depth, centimeters for length), exactly as it already does for `Catch` measurements. This keeps a single, consistent measurement convention across the application rather than introducing a second one for lure data.

### Images

Product images are modeled as a **reference** (e.g. a bundled asset path today, potentially a remote URL after future synchronization), never as embedded binary data — consistent with how `CatchPhoto` stores a relative path rather than image bytes. Resolving a reference into a displayable image is a Technical Design concern.

---

## Functional Requirements

### FR-1 — Browse Catalog

The user must be able to open a Lure Catalog browsing view that lists catalog variants.

The list must support scrolling through the full catalog without requiring all entries to be loaded into memory at once.

### FR-2 — Search Catalog

The user must be able to search the catalog using free text.

Search must match at least: manufacturer, product family/series, model name, and color name.

Search must be case-insensitive and must work fully offline against local data only.

### FR-3 — Filter Catalog

The user must be able to filter the catalog by, at minimum:

- manufacturer
- lure type

Filters must be combinable with each other and with an active search term.

### FR-4 — Lure Details View

Selecting a catalog variant must open a read-only Lure Details view.

The view must display the available structured information: manufacturer, product family/series (if present), model name, lure type, color (if present), length (if present), weight (if present), running depth range (if present), buoyancy (if present), and product image (if present).

Missing optional values must not produce empty or broken UI elements.

### FR-5 — Read-Only Presentation

Nothing in this milestone may allow the user to create, edit, or delete a catalog entry. There are no input fields, no save actions, and no delete actions anywhere in this feature.

### FR-6 — Offline Operation

Every capability in this milestone must work with no network connection. The feature must not depend on external APIs, remote endpoints, or authentication.

### FR-7 — Development Seed Catalog

The initial catalog is populated from a small, hand-authored local seed dataset shipped with the application, sufficient for development and testing.

The seed dataset target for this milestone is approximately:

- 3–5 `LureModel` entries
- 10–20 total `LureVariant` entries across those models
- multiple `lureType` codes represented (not all variants of the same type)
- some variants with intentionally incomplete optional fields (for example, missing weight or missing running depth), so the missing-data handling required elsewhere in this specification is actually exercised
- local placeholder images only, unless real product image usage rights have been separately confirmed — real manufacturer product photography must not be bundled without confirmed rights

The seed dataset must be clearly identified as development data, not a production catalog, and must be structured so it can be replaced or extended later without changing the domain model or repository contract.

---

## Data and Validation Requirements

- `LureModel.manufacturer` and `LureModel.modelName` must not be empty.
- `LureModel.lureType` must be a non-empty stable string code. Unlike `FishSpecies`, an unrecognized `lureType` code must **not** fail, throw, or block catalog loading — the catalog must still load, browse, search, and filter correctly, falling back to a generic/raw-code display label rather than a localized one.
- `LureVariant.lureModelId` must reference an existing `LureModel`.
- Every `LureVariant` must contain enough identifying information to be distinguished from its sibling variants under the same `LureModel`: at least one of `variantName`, `colorName`, or `manufacturerColorCode` must be present.
- All numeric measurement fields (`lengthMillimeters`, `weightGrams`, `minRunningDepthMillimeters`, `maxRunningDepthMillimeters`) must be greater than zero when present; zero must never represent "unknown."
- When both `minRunningDepthMillimeters` and `maxRunningDepthMillimeters` are present, the minimum must not exceed the maximum.
- Absent optional data is represented as `null`, never as an empty string, zero, or a placeholder value.
- `LureVariant` identifiers must be unique and must never be reassigned to a different real-world product.

---

## Search and Filtering Requirements

- Search and filters operate purely on local data; no network round-trip is ever involved.
- An empty search term combined with no active filters must show the full catalog (subject to normal list pagination/virtualization).
- Filtering by manufacturer and filtering by lure type must each be independently clearable.
- Combining a search term with filters must return only entries satisfying all active criteria.
- Result ordering must be stable and predictable (exact ordering — e.g. alphabetical by manufacturer then model — is a Technical Design decision, but it must not vary between identical queries).

---

## Offline Behavior

- The catalog must be fully usable with the device in airplane mode.
- No catalog capability in this milestone may require the user to be signed in, connected, or online.
- The local seed catalog ships with the application; nothing needs to be downloaded before the catalog is usable.

---

## Empty, Loading, and Error States

- **Loading:** while the catalog is being read from local storage, the browse/search/filter view must show a clear loading indicator rather than an empty-looking screen.
- **Empty search/filter result:** when a search or filter combination matches no entries, the view must show a clear "no results" message, distinct from a loading or error state.
- **Read failure:** if the local catalog cannot be read, the application must not crash. It must show a clear error message and must not silently display stale or partial data as if it were complete.
- A genuinely empty catalog (no seed data present at all) is not an expected state in this milestone, but the application must still degrade to the same "no results" presentation rather than crashing or showing a broken layout.

---

## Deletion and Update Expectations for Shared Catalog Data

The catalog is shared product data, not user-owned data. This has direct consequences for this milestone:

- There is no user-facing way to delete a catalog entry. Deletion is not part of this feature's scope at all.
- There is no user-facing way to edit a catalog entry. Editing is not part of this feature's scope at all.
- The only way catalog content changes in this milestone is by shipping an updated seed dataset with a new application build.
- Because catalog identifiers must remain stable (see [Identity](#identity)), a future catalog update (whether a new seed revision or a future server sync) must be able to update or add entries without invalidating identifiers that other features (future Personal Tackle Box, future Assign Lure to Catch) may already reference.
- This milestone does not define a catalog versioning, update-conflict, or moderation strategy — it only requires that nothing in the identity or storage design forecloses building one later.

---

## Accessibility Expectations

- Catalog list items must expose a meaningful semantic label combining manufacturer, model, and variant-distinguishing detail (e.g. color/size) for screen readers — not just the raw display string as decorative text.
- The search field and each filter control must have an accessible label describing its purpose.
- Product images must have a text alternative (e.g. a semantic label describing the product) for screen reader users; a missing/placeholder image must also remain accessible, not just visually indicated.
- Tap targets for list items, filter controls, and the search field must meet the application's existing Material 3 sizing conventions.
- All text must respect the existing application theme and support standard system text scaling.

---

## Performance Expectations

The catalog must be designed to remain responsive as it grows from a handful of development entries to a catalog of thousands of variants:

- The browse list must use lazy/virtualized rendering so off-screen entries are not built or held in memory.
- Product images must be decoded at a size appropriate to their on-screen presentation (thumbnail vs. detail view), not at full source resolution, consistent with the existing image-thumbnail discipline used elsewhere in the application.
- Search and filter operations must remain responsive at catalog scale; the underlying query strategy (e.g. indexing) is a Technical Design concern, but this milestone's data model must not preclude efficient querying.
- The catalog must not be eagerly loaded at application startup. It should only be read once the user actually opens a catalog-related view, so its size does not affect general application startup time.

---

## Feature Ownership and Placement

Following the existing feature-first structure and database ownership rules (ADR-0003, ADR-0006), the Lure Catalog is proposed as its own feature — distinct from a future feature that will own personal, user-specific tackle box data:

```text
lib/
└── features/
    └── lure_catalog/
        ├── data/
        ├── domain/
        └── presentation/
```

The Lure Catalog feature owns its domain models, its Drift tables, its mapper(s), and a repository exposing **read-only** query operations (browse, search, filter, get-by-id). It does not expose create, update, or delete operations to the presentation layer in this milestone, reflecting that this is shared reference data rather than user-owned data.

A future Personal Tackle Box feature (MFS-016) is expected to reference `LureVariant.id` rather than duplicate catalog data, in the same way `Catch` references `FishingSpot.id`.

---

## Acceptance Criteria

- A framework-independent `LureModel` domain concept exists, with `manufacturer`, `productFamily` (optional), `modelName`, `lureType`, and an optional default image reference.
- A framework-independent `LureVariant` domain concept exists, referencing a `LureModel`, with all physical/appearance fields optional except its identifier, model reference, and timestamps.
- Every seeded `LureVariant` has at least one of `variantName`, `colorName`, or `manufacturerColorCode`, so it remains distinguishable from its siblings.
- A local Drift-backed catalog exists, seeded with approximately 3–5 `LureModel` entries and 10–20 `LureVariant` entries spanning multiple lure types, with some optional fields intentionally left blank.
- The user can browse the full seed catalog.
- The user can search the catalog by text matching manufacturer, family/series, model, or color.
- The user can filter the catalog by manufacturer.
- The user can filter the catalog by lure type.
- Search and filters can be combined.
- The user can open a read-only Lure Details view for any catalog variant.
- Missing optional fields render cleanly in both list and details views.
- No creation, editing, or deletion of catalog entries is possible anywhere in the UI.
- The catalog works with no network connection.
- Loading, empty-result, and read-failure states are all handled without crashing.
- Catalog identifiers are stable and independent of display text.
- `flutter analyze` passes.
- Automated tests cover the domain model, repository queries (browse/search/filter/get-by-id), and the browse/details presentation.

---

## Out of Scope

- Personal Tackle Box
- assigning a lure to a catch
- user-created catalog entries
- user-uploaded lure photos
- favorites
- catch statistics
- recommendations
- admin tooling
- catalog moderation
- external APIs
- web scraping
- barcode scanning
- cloud synchronization
- trip-specific tackle boxes
- quantity tracking
- purchase history
- cast or usage tracking

---

## Dependencies

No new external dependencies are required. This milestone reuses the existing stack and patterns:

- Flutter, Dart
- Drift (local persistence, per ADR-0005)
- The existing Repository pattern and feature-first structure (ADR-0001, ADR-0003, ADR-0006)
- The same stable-identifier-with-localized-display-label approach already established for `FishSpecies` — with the difference that `lureType` is an open string code rather than a closed Dart enum, since the catalog must tolerate lure types not yet known to the application

---

## Future Extensions

This foundation is expected to support, in later milestones:

- MFS-016 — Personal Tackle Box (user-owned ownership of specific `LureVariant`s)
- MFS-017 — Assign Lure to Catch (referencing a `LureVariant`, and/or a Tackle Box entry, from a `Catch`)
- Synchronization with a server-managed global catalog, including incremental updates
- A normalized `Manufacturer` entity, if manufacturer-level metadata becomes valuable
- Full-text search improvements if simple text matching becomes a bottleneck at full catalog scale
- Barcode scanning as an alternate way to locate a catalog entry
- Catalog versioning and update/conflict handling once synchronization is introduced
