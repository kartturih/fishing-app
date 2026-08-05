# MFS-028 — Lure Catalog Expansion & Data Management

## Status

Draft

## Related

- Depends on: MFS-015 — Lure Catalog Foundation
- Depends on: MFS-018 — Lure Catalog UX Improvements (the model-grouped browsing/search/filter experience this milestone's expanded content must remain compatible with)
- Must not regress: MFS-016 — Personal Tackle Box Foundation, MFS-017 — Assign Lure to Catch, MFS-019 — Lure-Based Catch Statistics (all consume catalog data by stable reference and must continue to function unmodified)
- Roadmap: `docs/roadmap.md` §3.5 (Lure Catalog Expansion and Data Management)

---

## Purpose

Grow the Lure Catalog from its current small, hand-authored development seed dataset (4 `LureModel`s, 14 `LureVariant`s — see MFS-015 FR-7) into a substantially larger, real-world catalog of manufacturers, models, and color variants, and establish a maintainable, structured, offline way to author, validate, and update that content over time — without hand-writing large Dart literal lists in production code, and without changing the catalog's existing read-only, shared-reference-data architecture (MFS-015).

This is a **content and data-management milestone**, not a new user-facing feature. It does not change how the catalog is browsed, searched, filtered, or displayed (MFS-015/MFS-018), how lures are owned (MFS-016), how a lure is assigned to a catch (MFS-017), or how lure statistics are computed (MFS-019). Its entire purpose is to make the existing catalog contain enough real, trustworthy data to make those already-shipped features actually useful, and to make growing that data further a repeatable, low-risk process rather than a one-off effort.

---

## User Value

Anglers can already browse, search, filter, own, and assign lures — but with only 4 models in the catalog, none of that is useful for a real tackle box. This milestone directly increases the practical value of four already-shipped milestones (MFS-015/016/017/019) without asking the angler to learn anything new: the catalog simply contains real lures they are likely to actually own.

---

## Scope

### In Scope

- A structured, offline, bundled authoritative catalog content source, replacing hand-written Dart seed literals as the way new catalog content is authored (see [Content Source](#content-source)).
- A safe update mechanism that can insert new entries, correct existing ones, and retire removed ones, generalizing the existing seed-reconciliation mechanism (MFS-015/TD-015 `ensureSeeded()`) into the standing way this catalog is grown and corrected going forward — not a one-time migration.
- Preservation of every existing guarantee Personal Tackle Box (MFS-016) and Catches (MFS-017) already depend on: stable identifiers, no hard deletion, retirement instead of removal, live (never copied) resolution of catalog fields.
- Duplicate prevention for catalog content (no two entries describing the same real-world product).
- A documented, repeatable authoring workflow for future content growth.
- Validation of catalog content before it ships, so malformed or invalid entries are caught before they reach a device.
- A clear content/licensing boundary for what catalog data may be bundled with the application (see [Content Sourcing and Licensing](#content-sourcing-and-licensing)).
- Continued fully offline operation at the larger scale.

### Out of Scope

See [Out of Scope](#out-of-scope-1) for the complete list. Notably: remote/server-managed catalog synchronization, user-submitted or shared catalog entries, manufacturer photographs or logos, automatic web scraping, cloud moderation, a general-purpose in-app admin/editing UI, and any change to the domain models, schema, or repository contracts of `personal_tackle_box`, `catches`, or `statistics`.

---

## Product Principles

- **Content and infrastructure are separate concerns.** This milestone defines how catalog data is authored, validated, and shipped. It does not, by itself, guarantee any specific number of real manufacturers or models are included — acquiring and curating actual product data is ongoing content work that continues after this milestone, using the workflow it establishes.
- **The catalog remains shared, read-only reference data.** Nothing in this milestone gives the application, or the angler, any way to create, edit, or delete a catalog entry from within the app. That remains exclusively a build-time/authoring-time concern, unchanged from MFS-015.
- **References are permanent.** `TackleBoxEntry.lureVariantId` (MFS-016) and `Catch.lureVariantId` (MFS-017) already depend on catalog identifiers that are never reassigned and never hard-deleted (both foreign keys use `onDelete: KeyAction.restrict` against `LureVariants`). This milestone must not introduce any content-update path that could invalidate, orphan, or silently change what an existing reference resolves to.
- **Correction and removal are different from deletion.** Fixing a typo in a manufacturer name updates a row in place; a product being dropped from the authoritative source retires it (as MFS-015's `retiredAt` already does for the seed process). Nothing in this milestone's content lifecycle may ever hard-delete a `LureModel` or `LureVariant` row that could be referenced elsewhere — consistent with the restrict-not-cascade foreign keys already in place.
- **No silent data loss.** An owned lure (Personal Tackle Box) or a historical catch's assigned lure (Catches) must remain fully visible, resolvable, and usable no matter how the catalog content changes underneath it, exactly as MFS-016 FR-9 and MFS-017 FR-6/FR-7 already guarantee for retirement.
- **Smallest robust solution for a single-device, offline-first app.** This milestone explicitly does not introduce a backend, a remote sync protocol, or server-side moderation merely because a future version of the product might want one. See [Out of Scope](#out-of-scope-1).

---

## User Stories

**As an angler**
I want the Lure Catalog to contain a real, useful selection of lures I might actually own
So that browsing, searching, my tackle box, and my catch history are meaningful rather than mostly empty.

**As an angler**
I want an updated catalog (shipped in a future app update) to add and correct lures without disturbing the lures I already own or the catches I've already logged
So that catalog growth never costs me data I've already entered.

**As an angler**
I want the catalog to keep working fully offline as it grows
So that a bigger catalog never becomes a reason the app needs network access.

**As the developer maintaining this catalog**
I want a structured, repeatable way to add and correct catalog content
So that growing the catalog does not mean hand-editing long Dart literal lists in production code.

**As the developer maintaining this catalog**
I want obviously wrong or duplicate content to be caught before it ships
So that a bad entry doesn't reach a real device and doesn't need a full milestone to fix.

---

## Content Source

The current mechanism (MFS-015/TD-015) authors catalog content directly as Dart `LureModel`/`LureVariant` literals in `lure_catalog_seed_data.dart`. This does not scale to hundreds or thousands of variants and mixes catalog *content* with application *source code*.

This milestone's approved direction: the authoritative catalog content source becomes a **structured, bundled data asset (e.g. JSON) shipped inside the application package**, imported and reconciled into the existing Drift tables (`LureModels`/`LureVariants`) at catalog-open time — the same point `ensureSeeded()` already runs at today (MFS-015/TD-015: "not called at application startup," only before the catalog is first used). This is a change to *where content is authored and how it enters the database*, not to the database schema, the domain model, or any existing repository read method (`browse()`, `getEntryById()`, `getVariantsForModel()`, `getDistinctManufacturers()`, `getDistinctLureTypes()`), all of which must continue to work unmodified.

Exact file format, on-disk schema, and parsing approach are Technical Design (TD-028) concerns. This specification requires only that the source be: structured (not free-form prose), bundled with the app (never fetched over the network), and separate from application source code (not a `.dart` file the angler's data depends on being recompiled to change).

---

## Functional Requirements

### FR-1 — Meaningful Catalog Expansion

The catalog must grow substantially beyond its current 4 models / 14 variants. This milestone does not fix an exact target count — real content acquisition is ongoing work — but its acceptance requires a catalog materially larger and more representative of real, purchasable lures than the current development seed set, using the workflow this milestone establishes (see [Content Sourcing and Licensing](#content-sourcing-and-licensing) for what content may actually be included).

### FR-2 — Structured, Offline Content Source

Catalog content is authored in a structured, bundled data source separate from application Dart source code (see [Content Source](#content-source)), never requiring network access to load, validate, or ship.

### FR-3 — Deterministic, Stable Identifiers

Every catalog entry — new or already-shipped — keeps a stable, opaque identifier that is never reassigned to a different real-world product and never derived from display text, exactly as MFS-015's existing Identity rules already require. This milestone's content-growth process must produce identifiers satisfying the same rules the original seed process already follows.

### FR-4 — Safe Catalog Updates

Applying an updated catalog (a newer app build with revised or expanded content) must, for every entry:

- insert it, if it is new;
- correct it in place (same identifier, updated fields), if its content changed; and
- leave it untouched, if nothing changed or if it is no longer owned by this content-update process (for example, a row a future server-managed sync has taken ownership of — see MFS-015's existing `seedVersion`-null handling).

This generalizes the existing `ensureSeeded()` reconciliation (MFS-015/TD-015) from a one-time seeding step into the standing mechanism for all future catalog content growth and correction.

### FR-5 — Stable References From Personal Tackle Box and Catches Are Preserved

No catalog content update introduced by this milestone may alter, invalidate, orphan, or require any migration of an existing `TackleBoxEntry` or `Catch` row. An owned lure and a catch's assigned lure must resolve exactly as they did before the update, unless the specific entry they reference was itself corrected (in which case they must reflect the correction, exactly as already happens today when a seed-owned row is corrected).

### FR-6 — Duplicate Prevention

The catalog content source must not be able to produce two entries describing the same real-world product (same manufacturer, model, and distinguishing variant detail). A mechanism must exist to catch this before content ships — this milestone requires that such duplicates are detectable and preventable, not that a specific algorithm is used (a Technical Design concern).

### FR-7 — Renamed or Corrected Entries Update in Place

Correcting a manufacturer name, model name, color name, or any other field of an already-shipped catalog entry updates that entry's existing row in place, using its existing stable identifier. It must never be represented as deleting the old entry and creating a new one — doing so would break FR-5.

### FR-8 — Removed Entries Are Retired, Never Hard-Deleted

If a future content update no longer includes an entry that a previous version shipped, that entry is retired (as `LureVariants.retiredAt` already does), not deleted. A retired entry disappears from ordinary browsing (`browse()`) but remains fully resolvable by identifier (`getEntryById()`), exactly as already required by MFS-015. This milestone must extend the same retirement discipline consistently as the catalog's standing content-update mechanism (FR-4), not merely as a leftover behavior from the original one-time seed.

### FR-9 — Offline Availability

The expanded catalog, and every mechanism this milestone introduces to manage it, must work with the device in airplane mode, exactly as MFS-015 FR-6 already requires. Nothing in this milestone may introduce a network dependency of any kind, at any point — authoring, validation, bundling, or runtime use.

### FR-10 — Search, Filter, and Browsing Compatibility

The existing browse, search (including Finnish ä/ö case-insensitive matching), manufacturer/lure-type filtering (MFS-015), and model-grouped browsing with a per-model Color Variants list (MFS-018) must continue to work, unmodified in behavior, against the expanded catalog. Performance at the larger scale must satisfy MFS-015's existing Performance Expectations (lazy/virtualized rendering, no eager startup load, responsive search/filter) — those expectations were written anticipating this milestone and must now actually be validated against real data, not just design intent.

### FR-11 — No Regression to Existing Lure Features

Personal Tackle Box (MFS-016), Assign Lure to Catch (MFS-017), and Lure-Based Catch Statistics (MFS-019) must all continue to function exactly as already specified, with no change to their domain models, database schemas, or repository contracts, against the expanded catalog.

### FR-12 — Catalog Content and Licensing Rules

Every field bundled into the application as catalog content must be information the project has the right to redistribute. See [Content Sourcing and Licensing](#content-sourcing-and-licensing) for the specific rules this milestone establishes.

### FR-13 — Content Validation Before Shipping

Catalog content must be validated before it is bundled into an application build — not discovered for the first time at runtime on a user's device. Validation must, at minimum, enforce every data rule MFS-015 already requires of a `LureVariant`/`LureModel` (non-empty required fields, at least one distinguishing field per variant, all measurements strictly positive when present, valid running-depth range ordering) plus this milestone's duplicate-prevention rule (FR-6). This milestone requires that such validation exists and runs before content ships; its exact form (a script, a test, a build step) is a Technical Design concern.

### FR-14 — Physical Android Acceptance at Expanded Scale

Physical Android testing for this milestone must specifically exercise the expanded catalog's real scale — browsing, searching, and filtering performance, and Lure Model Details/Color Variants rendering (MFS-018) — not only functional correctness at the original 4-model development scale.

---

## Data and Validation Requirements

- Every rule already established by MFS-015 for `LureModel`/`LureVariant` applies unchanged to every new or corrected entry: `manufacturer` and `modelName` non-empty; `lureType` a non-empty stable string code; every `LureVariant` distinguishable from its siblings by at least one of `variantName`/`colorName`/`manufacturerColorCode`; every numeric measurement field strictly positive when present, and `null` (never zero or a placeholder) when absent; `minRunningDepthMillimeters` never exceeding `maxRunningDepthMillimeters` when both are present.
- Manufacturer, model, and color names must be entered in a normalized, consistent form (e.g. consistent capitalization and spelling for the same manufacturer across all its entries) — a content-quality requirement, not a new schema constraint.
- Length and weight remain optional at the expanded scale, exactly as MFS-015 already requires; an entry is never excluded from the catalog merely for lacking them.
- No content update introduced by this milestone requires a Drift schema migration by itself — the schema (tables, columns, constraints) established by MFS-015/TD-015 is not changed by this milestone. If real content genuinely cannot be represented by the existing schema, that is an explicit escalation back to a schema-level decision, not something this milestone's content process may work around informally.

---

## Catalog Version Metadata

The application must be able to tell whether its currently stored catalog reflects the content bundled with the currently installed application build, so that a future app update's revised or expanded content is reliably applied. This generalizes the existing per-row `seedVersion` mechanism (MFS-015/TD-015) into the standing way catalog freshness is tracked going forward. Exact representation (a single catalog-wide version, or the existing per-row scheme continued, or both) is a Technical Design decision; this specification requires only that reconciliation remain idempotent (repeated application of the same content version performs no writes, exactly as already required and already tested for the existing seed mechanism) and that it correctly detect and apply a genuinely newer content version.

---

## Content Sourcing and Licensing

This milestone draws a firm line between **technical catalog infrastructure** (in scope here) and **acquiring actual manufacturer content** (an ongoing, separate activity that uses this infrastructure but is not itself completed by this milestone).

- **Manufacturer and model names** are factual identifiers of real products and may be recorded.
- **Objective product specifications** (dimensions, weight, lure type, running depth, buoyancy) are factual data and may be recorded.
- **Manufacturer product photography** must not be bundled with the application unless usage rights have been explicitly confirmed for that specific image — continuing MFS-015 FR-7's existing rule ("real manufacturer product photography must not be bundled without confirmed rights"), now stated as a permanent rule governing all future catalog growth, not only the original seed. Until rights are confirmed for a given product, its `imageReference`/`defaultImageReference` remains a local placeholder (as already established) or absent.
- **Commercial marketing/product descriptions** (manufacturer-written prose) must not be copied verbatim into the catalog. A factual, independently-stated summary of objective specifications is not the same as reproducing marketing copy, and this milestone's content must stay on the factual side of that line.
- **Manufacturer color names** (e.g. "Hot Craw," "Firetiger") are short, functional identifiers a product is actually sold under and may be recorded — the same treatment MFS-015's existing seed data already gives them.
- **Manufacturer logos** must not be bundled with the application under this milestone.
- This milestone does not perform manufacturer-by-manufacturer research or rights clearance itself — that is downstream content-acquisition work using the infrastructure this milestone builds. What it does establish is the rule that content acquisition must follow, so a future contributor (human or AI-assisted) has an unambiguous boundary rather than an implicit assumption that "if it's on the internet, it can be bundled."

---

## Empty, Loading, and Error States

Unchanged in kind from MFS-015: loading, empty search/filter result, and read-failure states continue to apply exactly as already specified. This milestone must not introduce any new failure mode the angler can observe — a larger catalog is still either loading, showing results, showing no results, or showing a read error, with no fifth state.

---

## Accessibility Expectations

Unchanged from MFS-015/MFS-018: semantic labeling, accessible search/filter controls, image text alternatives, and Material 3 tap-target sizing all continue to apply, now exercised against the expanded catalog rather than the 14-variant development set.

---

## Feature Ownership and Placement

This milestone remains inside the existing `lure_catalog` feature; no new feature directory is introduced:

```text
lib/
└── features/
    └── lure_catalog/
        ├── data/
        ├── domain/
        └── presentation/
```

The catalog remains owned exclusively by `lure_catalog`. `personal_tackle_box`, `catches`, and `statistics` continue to read it by reference only, exactly as already established (MFS-016/017/019), and are not modified by this milestone. Any new authoring/validation tooling this milestone requires is development-time infrastructure, not a runtime application feature — its exact placement is a Technical Design decision, but it must not become a new in-app, angler-facing surface (see [Out of Scope](#out-of-scope-1)).

---

## Acceptance Criteria

- The catalog contains substantially more manufacturers, models, and variants than the current 4-model/14-variant development seed set, sourced and validated per [Content Sourcing and Licensing](#content-sourcing-and-licensing).
- Catalog content is authored in a structured, bundled data source separate from application Dart source code, requiring no network access at any point.
- Every existing MFS-015 data-validation rule for `LureModel`/`LureVariant` is enforced for every new and existing entry.
- A duplicate-prevention mechanism exists and prevents two entries from describing the same real-world product.
- Applying an updated catalog inserts new entries, corrects changed entries in place (same identifier), and retires removed entries — never hard-deleting a `LureModel` or `LureVariant` that could be referenced elsewhere.
- Applying the same catalog content twice performs no additional writes (idempotent), consistent with and extending the existing, already-tested `ensureSeeded()` guarantee.
- No existing `TackleBoxEntry` or `Catch` is invalidated, orphaned, or altered by a catalog content update, except to reflect an intentional correction to the specific entry it references.
- A retired catalog entry remains excluded from ordinary browsing but remains resolvable by identifier, exactly as already required by MFS-015.
- Browsing, search (including Finnish ä/ö matching), manufacturer/lure-type filtering, and Lure Model Details/Color Variants browsing (MFS-018) all continue to function correctly and responsively against the expanded catalog.
- Personal Tackle Box (MFS-016), Assign Lure to Catch (MFS-017), and Lure-Based Catch Statistics (MFS-019) all continue to function with no change to their domain models, database schemas, or repository contracts.
- No manufacturer product photography or logo is bundled without confirmed usage rights; unconfirmed entries use the existing local placeholder image convention.
- No Drift schema migration is required by ordinary catalog content growth (adding, correcting, or retiring entries) — only by a genuine, separately-justified model change, which this milestone does not make.
- Content is validated before being bundled into an application build, not only discovered at runtime.
- The catalog remains fully usable with the device in airplane mode.
- `flutter analyze` passes.
- Automated tests cover: content-import/reconciliation behavior (insert, correct, retire, idempotency, never-touch-externally-owned-rows) at a scale representative of the expanded catalog, duplicate detection, and that existing Personal Tackle Box/Catches/Statistics behavior is unaffected.
- Physical Android testing is performed against the actual expanded catalog scale delivered by this milestone (see [FR-14](#fr-14--physical-android-acceptance-at-expanded-scale)), not only the original development seed scale.

---

## Out of Scope

- Remote or server-managed catalog synchronization
- User-submitted or community-shared catalog entries
- Manufacturer product photographs or logos, unless usage rights are separately and explicitly confirmed per entry
- Automatic web scraping or any other automated, unattended content acquisition from external sources
- Cloud moderation or any moderation workflow
- A general-purpose in-app admin or catalog-editing UI — this milestone's content workflow is a development-time process, not an angler-facing or even a runtime capability
- A normalized `Manufacturer` entity (remains a possible future extension, per MFS-015; not required to reach this milestone's scale)
- A third (size vs. color) variant tier (per MFS-015, unchanged)
- Any change to the domain model, database schema, or repository contract of `personal_tackle_box`, `catches`, or `statistics`
- Any change to how the catalog is browsed, searched, filtered, or presented (MFS-015/MFS-018 UX is unmodified)
- Cloud synchronization of any kind

---

## Open Questions for Technical Design

The following are intentionally left unresolved here, as implementation-level Technical Design (TD-028) decisions:

- Exact content source file format and on-disk schema (e.g. JSON structure, one file vs. several).
- Exact duplicate-detection algorithm/heuristic.
- Exact validation tooling mechanism (a standalone script, an automated test, a build step, or some combination).
- The specific target scale for this milestone's first delivered content (FR-1 deliberately sets no fixed number).
- Exact representation of catalog version metadata (single catalog-wide version vs. continuing the existing per-row `seedVersion` scheme, or both).
- Whether a normalized `Manufacturer` entity becomes justified at the scale this milestone actually reaches (default assumption is no, per [Out of Scope](#out-of-scope-1), unless TD-028 finds a concrete reason).

---

## Dependencies

No new external runtime dependencies are required by this specification. This milestone reuses the existing stack and patterns:

- Flutter, Dart
- Drift (existing dependency, per ADR-0005), unchanged schema
- The existing Repository pattern and feature-first structure (ADR-0001, ADR-0003, ADR-0006)
- The existing `LureCatalogRepository` read methods (MFS-015/TD-015, MFS-018/TD-018), unmodified
- The existing versioned, idempotent seed-reconciliation pattern (MFS-015/TD-015 `ensureSeeded()`), generalized rather than replaced

A structured-data parsing approach (e.g. Dart's built-in `dart:convert` for JSON) may be sufficient without a new package dependency; if Technical Design selects a source format requiring a new package (e.g. CSV authoring converted at build time), that is a TD-028 decision, not a product-scope decision made here.

---

## Future Extensions

This milestone is expected to support, in later milestones:

- Remote/server-managed catalog synchronization (named as a long-term direction since MFS-015; still not started by this milestone)
- A normalized `Manufacturer` entity, if manufacturer-level metadata (logos once rights are confirmed, canonical spelling authority) becomes valuable
- Richer per-variant metadata (running depth, color family, contrast, action/vibration) to support Condition-Based Lure Guidance (`docs/roadmap.md` §3.6), which explicitly depends on this milestone
- A documented content-acquisition pass per manufacturer, using the workflow this milestone establishes
