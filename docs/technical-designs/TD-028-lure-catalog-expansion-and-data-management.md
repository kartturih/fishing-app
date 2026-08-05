# TD-028 — Lure Catalog Expansion & Data Management

## Status

Draft (Revision 2 — see [Revision History](#revision-history); no implementation yet)

## Related

- Implements: `docs/specifications/MFS-028-lure-catalog-expansion-and-data-management.md`
- Builds on: MFS-015 / TD-015 (Lure Catalog Foundation — domain model, schema, `ensureSeeded()` reconciliation, identity scheme)
- Must not regress: MFS-016 / TD-016 (Personal Tackle Box), MFS-017 / TD-017 (Assign Lure to Catch), MFS-018 / TD-018 (Lure Catalog UX Improvements), MFS-019 / TD-019 (Lure-Based Catch Statistics)
- Precedent tooling pattern: `tools/syke_bathymetry/` (developer-run Python data-preparation script producing a bundled asset, per TD-027 §20/§21)
- Precedent runtime patterns: `lib/core/map/base_map_preference_store.dart` (`shared_preferences` persistence), `lib/core/map/worldwide_style_factory.dart` (bundled-JSON-asset loading via `rootBundle`/`jsonDecode`)

## Revision History

- **Revision 1** — first draft: authoring/generated-asset schemas, stable-ID policy, developer tooling, runtime import/versioning, retirement semantics, normalization rules, scale/performance assessment, compatibility/migration summary, testing strategy, physical acceptance checklist, content authoring workflow, licensing policy pointer.
- **Revision 2** (documentation-only refinement, no implementation) — added [§11A Migration Plan](#11a-migration-plan), a concrete, numbered implementation checklist formalizing Revision 1's §11 narrative into an execution-ready sequence; and added [§14A Catalog Contribution Guidelines](#14a-catalog-contribution-guidelines), a long-term editorial/content-policy section for future contributors, distinct from §5's mechanical validation rules and §15's legal/licensing boundary. Neither addition changes any architecture, schema, or decision from Revision 1 — see this revision's own compliance check at the end of §14A.

---

## Goal

Replace the Lure Catalog's hand-written Dart seed literals (`lure_catalog_seed_data.dart`, 4 models / 14 variants) with a structured, offline, multi-file authoring source that a small developer-run Python tool validates and merges into one bundled, normalized JSON asset, which the existing `LureCatalogRepository` imports into the unchanged `LureModels`/`LureVariants` Drift tables using a generalized version of the already-shipped `ensureSeeded()` reconciliation mechanism.

The implementation shall satisfy MFS-028. No production Dart code is written by this document; no database schema is changed; no large-scale real lure content is added beyond the minimal fixtures needed to explain and test the design.

---

## Fixed Architectural Decisions (not reconsidered here)

Carried over verbatim from MFS-028 and the task that commissioned this TD. Every decision below is treated as settled; if anything in this document appeared to require reopening one of them, that is flagged explicitly in [§18 Risks](#18-risks-and-mitigations) rather than silently worked around.

1. Bundled structured catalog data (not hand-written Dart) becomes the authoritative catalog source.
2. Runtime remains fully offline — no network access at any point, ever.
3. No backend, remote catalog, or cloud synchronization.
4. Stable opaque IDs are permanent and must never be derived from display names.
5. Existing catalog rows referenced by owned lures or catches must never be deleted.
6. The existing `LureModel → LureVariant` schema (MFS-015/TD-015) continues unchanged.
7. No `Manufacturer` table is introduced.
8. No speculative fields (`discontinued`, `country`, `logo`, `URL`, `EAN`, `SKU`, `release year`, …) are added.
9. Manufacturer photos, logos, and marketing descriptions remain out of scope.
10. Expanding the catalog must never require changing Dart production code.

No finding in this TD contradicts any of these ten. Confirmed in the compliance summary immediately below.

---

## Constraint Compliance Summary

| # | Decision | How this TD satisfies it |
|---|---|---|
| 1 | Bundled structured source | §2/§3: manufacturer JSON files → generated `catalog_v1.json` asset |
| 2 | Fully offline | §7: asset loaded via `rootBundle`, never a network call, at any point |
| 3 | No backend | §5/§7: all tooling is a local developer script; runtime import is local-asset-only |
| 4 | IDs never derived from names | §4: unchanged from MFS-015 — opaque, hand-authored UUIDs |
| 5 | Referenced rows never deleted | §8: retire, never delete — same `retiredAt`/restrict-FK mechanism, generalized |
| 6 | Schema unchanged | §11, §16: zero migration, zero schema version bump, confirmed table-by-table |
| 7 | No `Manufacturer` table | §2/§3: manufacturer stays a plain string field, exactly as today |
| 8 | No speculative fields | §2/§3: authoring and generated schemas list only fields already on `LureModel`/`LureVariant` |
| 9 | No photos/logos/marketing copy | §2 (structural: no such field exists to fill), §5 (validator rejects unknown keys), §15 (documented policy) |
| 10 | No Dart change to add content | §14: the authoring workflow never touches `lib/` |

---

## Current State

Summarized from the existing implementation (`lib/features/lure_catalog/`), unchanged by this TD except where explicitly noted:

- `LureModels`/`LureVariants` Drift tables, schema version 4 (current app schema version: 8 — no change from this milestone).
- `LureModel.id`/`LureVariant.id`: opaque, hand-authored UUID v4 string literals, never derived from text, never generated at runtime (MFS-015 Identity).
- `LureCatalogRepository.ensureSeeded()`: a versioned, idempotent reconciliation already wrapped in one `_database.transaction()` — inserts a seed id with no existing row, corrects a still seed-owned row whose stored `seedVersion` is behind `currentLureCatalogSeedVersion`, never touches a row whose stored `seedVersion` is `null`, and retires (`retiredAt`, never deletes) a still seed-owned variant no longer present in the current seed source. Already tested for idempotency and for never touching a `seedVersion`-null row (`lure_catalog_repository_test.dart`).
- Content today: `lureCatalogSeedModels`/`lureCatalogSeedVariants`, two Dart top-level `List` literals in `lure_catalog_seed_data.dart`, plus `currentLureCatalogSeedVersion = 1`.
- `TackleBoxEntries.lureVariantId` and `Catches.lureVariantId` both reference `LureVariants.id` with `onDelete: KeyAction.restrict` — a `LureVariant` row can never actually be deleted while referenced, by construction. `LureVariants.lureModelId → LureModels.id` uses cascade, but nothing in the codebase ever deletes a `LureModel` row.
- `browse()`/`getEntryById()`/`getVariantsForModel()`/`getDistinctManufacturers()`/`getDistinctLureTypes()`: five existing, unmodified read methods this TD's import path must keep serving correctly.
- Existing indexes: `lure_models_manufacturer`, `lure_models_lure_type`, `lure_variants_lure_model_id`, plus each table's primary-key index.

---

## Key Design Decisions

This section directly answers the design questions MFS-028 raised, in the same style TD-015 used for its own first-draft design questions. The numbered sections later in this document implement these decisions.

### 1. Authoring is per-manufacturer, generation output is flat — matching the existing Drift shape

Manufacturer source files nest `models → variants` for human readability; the generated asset flattens to `models[]` + `variants[]` with an explicit `lureModelId` foreign key on each variant — the same two-list shape `lureCatalogSeedModels`/`lureCatalogSeedVariants` already has today. This keeps the runtime importer's mapping step trivial (JSON → the same domain lists the existing reconciliation loop already consumes) and confines all "human-friendly nesting" complexity to the Python build tool, never the Dart runtime.

### 2. `catalogVersion` is a single integer in the generated JSON, replacing `currentLureCatalogSeedVersion`

The existing per-row `seedVersion` integer column and comparison logic (`storedSeedVersion < currentVersion`) are unchanged. Only where "current version" comes from changes: a Dart constant becomes one field read out of the parsed JSON payload. No schema change.

### 3. Reconciliation logic is generalized, not replaced

`ensureSeeded()`'s insert/correct/never-touch-null/retire-removed rules (MFS-015/TD-015) are the same four rules this TD relies on, extended to also cover a removed *model* (§8) and hardened for scale (§7, §10: batched pre-read + batched writes, still inside one transaction).

### 4. Python, not Dart, for developer tooling — reusing an established pattern

`tools/syke_bathymetry/build_mbtiles.py` is direct, working precedent in this exact repository: a developer-run Python script, never invoked by the app, `flutter analyze`, `flutter test`, or CI, producing a bundled asset that is committed. This TD's tooling (`tools/lure_catalog/`) follows the same shape. Unlike the SYKE tool, it needs zero third-party packages — Python's standard library (`json`, `uuid`, `unicodedata`, `re`) is sufficient.

### 5. Catalog version freshness is tracked outside SQL, using an already-present dependency

`shared_preferences` (already a declared dependency, already used for base-map-selection persistence in `lib/core/map/base_map_preference_store.dart`) stores the last successfully reconciled `catalogVersion` as a plain integer. This answers MFS-028's "represent catalog version metadata without adding unnecessary schema" literally: zero new SQL schema. It is a pure performance fast-path, never a correctness dependency — see §7.

### 6. A model "removed from source" needs no new mechanism

MFS-015 already established that `browse()` and both distinct-value queries filter through `LureVariants.retiredAt IS NULL`, so a model whose every variant is retired already, correctly, stops appearing anywhere — with no model-level flag. This TD relies on that existing, already-documented emergent behavior instead of adding a `LureModels.retiredAt` column (which would be an unjustified schema change). See §8.

### 7. Duplicate/identity-drift detection compares against the previously committed asset, not just within one build

Two content-safety checks (duplicate normalized names, and "an existing id's identity changed without acknowledgment") both need a *before* to compare against. That "before" is simply the `catalog_v1.json` already committed in git — no separate database or state file is needed for the tool itself. See §5, §9.

### 8. No streaming JSON parser, no new database indexes — evidence-based restraint

At the target scale (1,000 models / 10,000 variants / 5–10 MB), a single `jsonDecode` and the existing indexes are both expected to remain adequate on a modern Android device; the one change justified by concrete evidence is import-time batching (10,000 sequential `SELECT`s is the actual, arithmetic-obvious bottleneck; nothing else at this scale is). See §10.

---

## 1. Overview and Folder Structure

```text
assets/
└── lure_catalog/
    ├── source/                          # NEW — authored, committed
    │   ├── rapala.json
    │   ├── abu_garcia.json
    │   ├── storm.json
    │   └── ...
    ├── catalog_v1.json                  # NEW — generated, committed
    ├── placeholder_crankbait.png        # unchanged
    ├── placeholder_jig.png              # unchanged
    ├── placeholder_spoon.png            # unchanged
    └── placeholder_swimbait.png         # unchanged

tools/
└── lure_catalog/                        # NEW — developer tooling, never shipped
    ├── build_catalog.py
    ├── validators.py
    ├── normalize.py
    ├── known_lure_types.json
    ├── test_build_catalog.py
    └── README.md

lib/features/lure_catalog/
├── data/
│   ├── local/
│   │   ├── lure_models_table.dart         # unchanged
│   │   ├── lure_variants_table.dart       # unchanged
│   │   └── lure_catalog_seed_data.dart    # DELETED (§11)
│   ├── lure_catalog_asset_loader.dart     # NEW
│   ├── lure_catalog_version_store.dart    # NEW
│   ├── lure_catalog_mapper.dart           # unchanged
│   ├── lure_catalog_search_text.dart      # unchanged
│   └── lure_catalog_repository.dart       # MODIFIED (§7)
├── domain/                                # unchanged
└── presentation/                          # unchanged
```

`assets/lure_catalog/source/` file names are a developer-organizational convenience (one file per manufacturer keeps diffs small and merge conflicts rare) — they carry no identity meaning. The `manufacturer` field *inside* each file is the actual data; the build tool does not require the filename to match it, though the validator warns (not fails) if they look unrelated, as a light sanity aid, not a rule (see §5).

Why `assets/lure_catalog/catalog_v1.json` rather than the task's illustrative `catalog.json`: this repository already has an established convention for a versioned bundled-asset filename that bumps only when the asset's *shape* changes, not its content — `assets/syke_bathymetry/syke_bathymetry_v1.mbtiles` (TD-027 §25: "bump the version suffix... only if this script's own output schema/attribute shape changes"). `catalog_v1.json` follows that same convention directly, and `LureCatalogAssetLoader.defaultAssetFileName` (§7) mirrors `SykeBathymetryTileSource.defaultAssetFileName`'s existing shape.

---

## 2. Authoring Source Schema (Manufacturer Files)

One JSON object per file, one file per manufacturer, hierarchical for human readability:

```json
{
  "manufacturer": "Rapala",
  "models": [
    {
      "id": "3149d765-a567-49ec-994b-74179d3171c1",
      "modelName": "X-Rap Shad XRS08",
      "productFamily": "X-Rap",
      "lureType": "crankbait",
      "defaultImageReference": "assets/lure_catalog/placeholder_crankbait.png",
      "variants": [
        {
          "id": "442e3a0c-a3f2-49cf-9e8f-751adff94b02",
          "colorName": "Hot Craw",
          "manufacturerColorCode": "HCC",
          "lengthMillimeters": 80,
          "weightGrams": 12,
          "minRunningDepthMillimeters": 1500,
          "maxRunningDepthMillimeters": 2400,
          "buoyancy": "suspending"
        }
      ]
    }
  ]
}
```

### Field rules

**File level**

| Field | Required | Type | Notes |
|---|---|---|---|
| `manufacturer` | yes | non-empty string | Applied to every model in this file at build time — never repeated per model in the source (single point of truth per file, reducing transcription drift) |
| `models` | yes | array | May be empty (an in-progress file contributes nothing — not an error); each entry per below |

**Model object**

| Field | Required | Type | Notes |
|---|---|---|---|
| `id` | yes | non-empty string (UUID v4) | Never auto-generated by the tool — see §4 |
| `modelName` | yes | non-empty string | |
| `lureType` | yes | non-empty string | Must appear in `tools/lure_catalog/known_lure_types.json` (§5) unless deliberately extended there |
| `productFamily` | no | string | |
| `defaultImageReference` | no | string | Local asset path only — see §15 |
| `variants` | yes | array, ≥ 1 entry | A model with zero variants is a validation failure — mirrors MFS-015's existing implicit assumption that every seeded model has variants |

**Variant object**

| Field | Required | Type | Notes |
|---|---|---|---|
| `id` | yes | non-empty string (UUID v4) | Never auto-generated — see §4 |
| `variantName` | conditionally | string | At least one of `variantName`/`colorName`/`manufacturerColorCode` must be present — the same distinguishing-information rule already enforced by MFS-015's domain assert and the DB `CHECK` constraint |
| `colorName` | conditionally | string | |
| `manufacturerColorCode` | conditionally | string | |
| `lengthMillimeters` | no | positive integer | |
| `weightGrams` | no | positive integer | |
| `minRunningDepthMillimeters` | no | positive integer | Must not exceed `maxRunningDepthMillimeters` when both present |
| `maxRunningDepthMillimeters` | no | positive integer | |
| `buoyancy` | no | string | Open string code, exactly as today — no validator allowlist (unlike `lureType`; buoyancy has always tolerated free values and nothing in MFS-015/028 restricts it) |
| `imageReference` | no | string | Local asset path only — see §15 |
| `idReuseAcknowledged` | no | boolean, default `false` | Escape hatch for the identity-drift check — see §9 |

**No `description` field.** MFS-028 explicitly allowed one "only if already part of the current schema" — it is not: neither `LureModel` nor `LureVariant` has ever had a description field. None is added here, per the locked-decision list's explicit "do not add new domain fields merely to make the JSON look richer."

**Strict schema — unknown keys are a validation failure.** A source file containing any key not listed above (for example, a well-meaning `"photoUrl"` or `"logoUrl"`) fails validation immediately. This is a deliberate structural enforcement of the licensing boundary (§15): there is no field to smuggle prohibited content into, and the tool actively rejects an attempt to add one, rather than merely omitting one from documentation.

---

## 3. Generated Catalog Asset Schema

`assets/lure_catalog/catalog_v1.json`, produced only by `build_catalog.py build` (§5), never hand-edited:

```json
{
  "catalogVersion": 1,
  "generatedAt": "2026-08-12T00:00:00Z",
  "models": [
    {
      "id": "3149d765-a567-49ec-994b-74179d3171c1",
      "manufacturer": "Rapala",
      "productFamily": "X-Rap",
      "modelName": "X-Rap Shad XRS08",
      "lureType": "crankbait",
      "defaultImageReference": "assets/lure_catalog/placeholder_crankbait.png"
    }
  ],
  "variants": [
    {
      "id": "442e3a0c-a3f2-49cf-9e8f-751adff94b02",
      "lureModelId": "3149d765-a567-49ec-994b-74179d3171c1",
      "variantName": null,
      "colorName": "Hot Craw",
      "manufacturerColorCode": "HCC",
      "lengthMillimeters": 80,
      "weightGrams": 12,
      "minRunningDepthMillimeters": 1500,
      "maxRunningDepthMillimeters": 2400,
      "buoyancy": "suspending",
      "imageReference": null
    }
  ]
}
```

- `catalogVersion`: a single, monotonically increasing integer. This is the sole driver of reconciliation ("is this content newer than what's stored") — directly replacing `currentLureCatalogSeedVersion`. The build tool never increments it automatically (content changing is not, by itself, evidence the version *should* bump within the same review — a developer may make several source edits before deciding the whole batch is ready to ship as the next version); a developer sets it explicitly in a small `catalog_version.json` control file alongside `source/` (`{"catalogVersion": 2}`), which the build tool reads and copies into the output. This avoids the tool silently deciding version semantics on the developer's behalf.
- `generatedAt`: informational only (audit/debugging), an ISO-8601 UTC timestamp of the build run. **Never used by any reconciliation decision** — only the integer `catalogVersion` drives correctness, exactly as `seedVersion` comparison does today. Stated explicitly to prevent a future contributor from ever wiring wall-clock time into a correctness-sensitive comparison.
- `models`/`variants`: flat arrays, deterministically sorted (§5) — `models` by (`manufacturer` case/locale-normalized, `modelName` normalized, `id`); `variants` by (`lureModelId`, `id`). This exactly matches `browse()`'s own existing default sort tie-breaking (MFS-015/TD-015 §Sorting), so the asset's on-disk order and the app's default display order already agree — not required for correctness, but a deliberate, easy consistency win.
- Every field name matches the existing Drift column names (camelCase, same as the Dart domain types) so the runtime import mapping (§7) is a direct field-for-field copy, not a renaming translation layer.

---

## 4. Stable Identifier Policy

Unchanged in substance from MFS-015/TD-015's Identity and ID Scheme, restated here because it now applies across many files instead of one:

- Every `id` is an opaque UUID v4 string, generated once by a human author and pasted as a literal into a manufacturer source JSON file. Never computed from manufacturer/model/color text. Never generated at runtime, and — new for this TD — **never auto-generated by the build tool either**: `build_catalog.py validate`/`build` treat a missing or empty `id` field as a hard validation failure, rather than silently assigning one. Auto-generating on the developer's behalf would produce a different id on every run for any not-yet-committed entry, breaking determinism (§6) and idempotency (§7) the very first time a developer forgot to save a generated id before re-running the tool.
- **How developers generate a new id:** `python tools/lure_catalog/build_catalog.py new-id` prints one fresh UUID v4 to stdout and does nothing else (no file I/O) — a direct convenience wrapper around Python's own `uuid.uuid4()`, exactly mirroring TD-015's "the `uuid` package is used only as an offline authoring tool... exactly once per entry, by hand," now available as a one-line command instead of requiring a developer to know which Dart snippet to run.
- **Uniqueness scope: the whole catalog, not just one file.** The validator loads every `source/*.json` file and checks model ids for global uniqueness across all of them combined, and variant ids likewise. It additionally checks that no model id and variant id collide with each other (different tables, so not a database-level conflict, but a needless and easily-avoided source of confusion the validator catches for free).
- **Correction never changes an id, by construction.** A text correction is authored as an edit to a field's *value* inside a JSON object whose `id` field is untouched — there is no code path anywhere in this design that ever regenerates or reassigns an id based on content.
- **Id reuse for different real-world content is forbidden**, and is the one identity rule that cannot be verified from a single file in isolation — it requires comparing against what an id previously meant. See §9 for the concrete, mechanical check (the identity-drift check).

---

## 5. Developer Build and Validation Tooling

### Language and dependencies

Python, following this repository's own established precedent (`tools/syke_bathymetry/`) rather than introducing a second tooling language. Zero third-party packages are required — `json`, `uuid`, `unicodedata`, and `re` (all standard library) are sufficient for parsing, id generation, and text normalization. `tools/lure_catalog/requirements.txt` is therefore either omitted or left present-but-empty with a one-line comment explaining why, for consistency with the sibling `tools/syke_bathymetry/requirements.txt` convention.

### Files

- `tools/lure_catalog/build_catalog.py` — CLI entry point.
- `tools/lure_catalog/validators.py` — one function per rule, each returning a list of human-readable violation strings (empty list = passes).
- `tools/lure_catalog/normalize.py` — the normalization function shared by every duplicate-detection rule (§9).
- `tools/lure_catalog/known_lure_types.json` — a small, flat array of currently-known `lureType` codes, kept in sync by hand with `lib/features/lure_catalog/domain/lure_type_labels.dart`'s `_knownLureTypeLabels` keys (see the reconciliation note below).
- `tools/lure_catalog/test_build_catalog.py` — developer-run test suite for the tool itself (§12).
- `tools/lure_catalog/README.md` — usage, workflow, and the licensing policy pointer (§15), mirroring `tools/syke_bathymetry/README.md`'s shape.

### Commands

```bash
cd tools/lure_catalog
python build_catalog.py validate   # runs every rule below; writes nothing; exit 0/1
python build_catalog.py build      # validate, then write assets/lure_catalog/catalog_v1.json; exit 0/1
python build_catalog.py check      # build in-memory, diff against the committed asset; exit 0/1 — drift detector, §6
python build_catalog.py new-id     # print one fresh UUID v4; no file I/O
```

`build` always runs the full `validate` pass first and refuses to write any output if it fails — content is never allowed to reach the bundled asset without passing every rule.

### Validation rules

| # | Rule | Failure example |
|---|---|---|
| 1 | Valid JSON syntax per source file | `rapala.json: line 14: Expecting ',' delimiter` |
| 2 | Valid schema shape; **no unrecognized key** (§2, §15) | `westin.json: models[0]: unexpected field "logoUrl"` |
| 3 | Duplicate model id across the whole catalog | `duplicate model id 3149d765-...: rapala.json and storm.json` |
| 4 | Duplicate variant id across the whole catalog | `duplicate variant id 442e3a0c-...: rapala.json (twice)` |
| 5 | Model id and variant id collide with each other | `id 442e3a0c-... used as both a model id (storm.json) and a variant id (rapala.json)` |
| 6 | Duplicate model name within one manufacturer, normalized (§9) | `rapala.json: "X-Rap Shad XRS08" and "x-rap  shad xrs08" normalize identically` |
| 7 | Duplicate variant within one model, normalized (§9) | `rapala.json, model 3149d765-...: "Hot Craw"/"HCC" and "Hot   Craw"/"HCC" normalize identically` |
| 8 | Empty/blank manufacturer, model name, or (when required) distinguishing variant text | `abu_garcia.json: models[1]: modelName is blank` |
| 9 | Unsupported `lureType` (not in `known_lure_types.json`) | `storm.json: models[2]: lureType "wobler" is not a known code (typo for "wobbler"?)` |
| 10 | Non-positive length/weight/running-depth; `min > max` running depth | `rapala.json: variant 442e3a0c-...: weightGrams must be > 0, got 0` |
| 11 | A variant's `lureModelId` (post-flattening) resolves to an actual model in the same build | defense-in-depth only — structurally near-impossible given nested authoring, checked anyway |
| 12 | Conflicting reuse of an existing id for different content (identity drift, §9) | `variant 442e3a0c-...: manufacturer changed "Rapala" → "Abu Garcia" without idReuseAcknowledged` |
| 13 | Deterministic output (build twice, byte-compare) | developer/CI test, not a per-build check (§6, §12) |
| 14 | Stable sort order | enforced by construction in the `build` step itself (§3) |
| 15 | No manufacturer photography/logo/marketing-copy field | subsumed by rule 2 — there is no such field to check for; an attempt to add one is already a schema violation |

Every rule accumulates its violations rather than stopping at the first — a failed `validate`/`build` run prints every problem found across every file in one pass, each prefixed with the offending file (and JSON path where practical), so a developer fixes everything in one editing pass. Exit code is `0` on full success, `1` on any validation failure, `2` on a usage/argument error — a non-zero exit on any content problem, satisfying "fail loudly."

### `lureType` allowlist — a content-quality gate, not a runtime restriction

MFS-015 deliberately designed `lureType` as an **open** string code specifically so the *running application* never fails, throws, or blocks catalog loading on an unrecognized value (`_humanizeUnknownCode` fallback, already implemented and unchanged by this TD). That runtime tolerance is not weakened here. `known_lure_types.json` is a separate, *authoring-time* gate: it exists to catch typos and casing inconsistencies (`"wobler"` vs `"wobbler"`) before they ship, not to restrict what the schema or the app can ever represent. Extending the catalog with a genuinely new lure type is a deliberate one-line addition to `known_lure_types.json` (and, for a good user-facing label, a corresponding addition to `_knownLureTypeLabels` in the Dart domain layer — a normal content-driven Dart change, not a schema change, and one MFS-028's "no Dart change to add catalog *content*" promise does not cover, since a new lure *type* is new taxonomy, not new catalog content in the model/variant sense).

---

## 6. Generated Asset Policy

- **Output path:** `assets/lure_catalog/catalog_v1.json` (§1).
- **Committed to git:** yes, both the generated asset and the `source/*.json` authoring files. Flutter's asset bundling needs the file present in the repository at build time; CI and every other developer must be able to build the app without running Python or possessing the source files. This mirrors `syke_bathymetry_v1.mbtiles`'s own precedent exactly (that tool's own README: "Commit the regenerated ... file"). Source files are committed too — unlike SYKE's `.cache/` (a re-fetchable, gitignored scratch cache), the lure catalog's `source/*.json` files are original hand-authored content and the maintained source of truth for future edits, directly replacing `lure_catalog_seed_data.dart`'s role as committed, edited-in-place content.
- **Determinism verification:** `test_build_catalog.py` runs `build()` twice against an identical fixture input and asserts byte-identical output (§12). This is a developer/tooling-side test, run manually alongside the rest of `tools/lure_catalog/`'s own suite — not part of `flutter test`.
- **Source/output drift detection:** `python build_catalog.py check` rebuilds in memory from the current `source/*.json` files and byte-compares the result against the committed `catalog_v1.json`, failing loudly on any difference. This is the actual drift guard, and — consistent with the SYKE tool's own explicit non-goal ("never run by the app, by `flutter analyze`/`flutter test`, or by CI") — it is a manually-run developer command, not wired into any Dart-side automation, since this repository's CI has no Python execution stage today and adding one is out of scope for this TD ("do not introduce a complex build system unnecessarily"). A future CI stage could run `check` if the project ever adds Python to CI; that is explicitly not decided or scheduled here.
- **Must developers run the generator manually?** Yes — exactly like `build_mbtiles.py`. Nothing in `flutter run`/`flutter build`/app startup ever invokes Python.
- **Do Dart tests verify the generated output is current?** Not directly (Dart cannot re-derive it without re-implementing the Python build logic, which this TD does not propose). Dart tests instead verify the *committed* asset's internal self-consistency — well-formed JSON, unique ids, every variant's `lureModelId` resolves to a present model, `catalogVersion` present and a positive integer (§12) — which catches a corrupted or half-finished commit even without independently re-deriving the file.

---

## 7. Runtime Import — Loading, Versioning, Transactions

### New files

**`lure_catalog_asset_loader.dart`** — a small, single-purpose class:

```dart
class LureCatalogAssetLoader {
  const LureCatalogAssetLoader();

  static const String defaultAssetFileName =
      'assets/lure_catalog/catalog_v1.json';

  Future<ParsedLureCatalog> load({
    String assetFileName = defaultAssetFileName,
  }) async {
    final raw = await rootBundle.loadString(assetFileName);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ParsedLureCatalog.fromJson(json); // -> catalogVersion, List<LureModel>, List<LureVariant>
  }
}
```

Mirrors the already-established `rootBundle`/`jsonDecode` pattern this codebase already uses elsewhere (`WorldwideStyleFactory`'s MML style-fragment loading). `ParsedLureCatalog.fromJson` performs the direct field-for-field mapping described in §3 into the existing `LureModel`/`LureVariant` domain constructors — no new domain types are introduced; this loader produces exactly the same two lists `lureCatalogSeedModels`/`lureCatalogSeedVariants` already are today, just parsed from JSON instead of written as Dart literals.

**`lure_catalog_version_store.dart`** — modeled directly on `BaseMapPreferenceStore`:

```dart
class LureCatalogVersionStore {
  const LureCatalogVersionStore();

  static const _key = 'lure_catalog_last_reconciled_version';

  /// Returns the last successfully reconciled catalogVersion, or null if
  /// never reconciled (or unreadable — treated the same as never).
  Future<int?> loadLastReconciledVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_key);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastReconciledVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, version);
  }
}
```

**This store is a fast-path cache, never a correctness dependency.** If it is empty, stale, or wrong in either direction, the worst outcome is `ensureSeeded()` doing a full reconciliation pass it could have skipped (a performance cost) or skipping one it technically didn't need to run twice in the same version (already a no-op today via the existing per-row `seedVersion` check) — never an incorrect catalog state. This is why representing catalog version metadata here, outside SQL, satisfies "without adding unnecessary schema" without weakening any guarantee: the *authoritative* per-row freshness check (`storedSeedVersion < currentVersion`) is unchanged and still runs inside the transaction; this store only decides whether to attempt the pass at all.

### `ensureSeeded()`, generalized

```dart
Future<void> ensureSeeded({
  LureCatalogAssetLoader assetLoader = const LureCatalogAssetLoader(),
  LureCatalogVersionStore versionStore = const LureCatalogVersionStore(),
}) async {
  final parsed = await assetLoader.load();

  final lastReconciled = await versionStore.loadLastReconciledVersion();
  if (lastReconciled != null && lastReconciled >= parsed.catalogVersion) {
    return; // fast path: nothing to do, per the last known-good reconciliation
  }

  await _database.transaction(() async {
    final existingModels = await _loadExistingModelsById();     // one batched SELECT
    final existingVariants = await _loadExistingVariantsById(); // one batched SELECT

    for (final model in parsed.models) {
      await _reconcileModel(model, existingModels[model.id], parsed.catalogVersion);
    }
    for (final variant in parsed.variants) {
      await _reconcileVariant(variant, existingVariants[variant.id], parsed.catalogVersion);
    }

    final stillPresentIds = {for (final v in parsed.variants) v.id};
    await _retireRemovedVariants(
      existingVariants: existingVariants,
      stillPresentIds: stillPresentIds,
    );
  }); // single transaction: any thrown exception rolls back everything

  await versionStore.saveLastReconciledVersion(parsed.catalogVersion);
}
```

- `_loadExistingModelsById()`/`_loadExistingVariantsById()` replace what is today up to 10,000+10,000 individual `SELECT ... WHERE id = ?` calls with a small number of batched `SELECT ... WHERE id IN (...)` queries (chunked, e.g. 500 ids per `IN` clause — SQLite has a practical limit on expression-list size), returning `Map<String, LureModelEntity>`/`Map<String, LureVariantEntity>` for O(1) lookup during the reconciliation loop. This is the one import-time change justified purely by arithmetic at target scale (§10) — everything else about the reconciliation *rules* is unchanged from MFS-015/TD-015.
- `_reconcileModel`/`_reconcileVariant` keep exactly the same decision logic as today (insert if absent; skip if `seedVersion` is `null`; skip if `storedSeedVersion >= current`; otherwise update in place, preserving `createdAt`, bumping `updatedAt`, clearing `retiredAt` for a variant) — only their write path changes, using Drift's `batch()` to group the resulting inserts/updates instead of issuing each as its own awaited statement (§10).
- The whole operation remains inside one `_database.transaction()`, exactly as today — see §8 for why this, not per-batch transactions, is the correct choice given "no partial catalog state after a failed import."
- `versionStore.saveLastReconciledVersion()` is called **only after** the transaction commits successfully — if the transaction throws, this line never runs, so the fast-path cache can never claim a version was reconciled when it wasn't.

### When import runs

Unchanged: not at application startup. `ensureSeeded()` is still called from `LureCatalogListPage`'s existing load sequence, immediately before the first `browse()` — exactly the same lazy trigger point MFS-015/TD-015 already established ("must be called before the first `browse()`/`getEntryById()` call each time the catalog is opened; it is not called at application startup"). This milestone does not move that trigger point, so "must not delay unrelated app startup" is satisfied by not changing anything about when it runs, only what it does once it runs.

### Memory: no streaming parser

A single `jsonDecode` of a 5–10 MB string is expected to comfortably fit within a modern Android device's available heap for a Flutter app (typically well over 200 MB before real memory pressure) — a transient few-times-source-size overhead for the parsed tree plus the constructed domain-object lists is normal, not exceptional, for JSON payloads of this size. No streaming/incremental JSON parser is introduced; doing so would be optimization infrastructure without evidence, in tension with the task's explicit restraint instruction. This estimate is treated as a hypothesis, not a guarantee — §13's physical Android checklist includes a real-device memory check as the actual verification.

### Failure behavior

If asset loading fails (missing/corrupt bundled file — should not happen, defensively handled anyway), if `jsonDecode` throws (malformed JSON — should never reach this point if build-time validation did its job, per §5, but handled defensively), or if any row violates a database constraint mid-transaction, the whole `ensureSeeded()` call throws and Drift rolls back the entire transaction automatically — the catalog is left exactly as it was before the attempt, and `versionStore.saveLastReconciledVersion()` is never reached. This propagates to `LureCatalogListPage`'s already-existing `_loadError` handling (MFS-015's existing Empty/Loading/Error States) with **no new UI or error-handling code required** — a failed import is, from the presentation layer's point of view, indistinguishable from any other catalog read failure it already handles.

---

## 8. Update and Retirement Semantics

Extends MFS-015/TD-015's existing four rules (insert / correct / never-touch-null / retire-removed) to the eight scenarios MFS-028 and this task enumerate:

| Scenario | Behavior |
|---|---|
| 1. New model | Inserted, `seedVersion = catalogVersion` |
| 2. New variant | Inserted, `seedVersion = catalogVersion`, `retiredAt = null` |
| 3. Corrected model/variant text | Row updated in place (same `id`), `createdAt` preserved, `updatedAt` bumped, `seedVersion` bumped to current |
| 4. Corrected length/weight/type | Same code path as #3 — reconciliation does not diff field-by-field; any version bump re-writes the row's full content uniformly, exactly as today. No per-field special-casing is introduced. |
| 5. Variant removed from bundled source | Existing seed-owned (`seedVersion` not `null`) variant row whose id is absent from `parsed.variants` is retired (`retiredAt` set), never deleted — unchanged logic, `_retireRemovedVariants` |
| 6. Model removed from bundled source | No new mechanism: every variant of that model is, by definition, also absent from the source and independently retired via #5. The `LureModels` row itself is left in place, untouched — `browse()`/`getDistinctManufacturers()`/`getDistinctLureTypes()` already filter through `LureVariants.retiredAt IS NULL`, so a model with zero non-retired variants already, correctly, stops appearing anywhere, exactly as MFS-015/TD-015 already documented and relied on. No `LureModels.retiredAt` column is added — that would be an unjustified schema change for behavior the existing join-based filtering already provides. |
| 7. Existing user-created or `seedVersion`-null row | Never touched by any import, at any `catalogVersion` — the existing early-exit (`storedSeedVersion == null → return`) is unchanged |
| 8. Import interrupted or failed | Whole transaction rolls back (§7); database is left exactly as before the attempt; `versionStore` is not updated; the next attempt (next catalog open) retries the full reconciliation from the last known-good state |

### Explicit principles

- **Catalog-owned rows may be corrected; non-catalog-owned rows must never be overwritten.** Unchanged from today — the `seedVersion`-null check is the entire mechanism, generalized to mean "not owned by this content-update process" rather than narrowly "not owned by the original one-time seed."
- **Removed catalog variants are retired/hidden, not deleted.** Unchanged, extended to models via the emergent-invisibility mechanism above (no model ever needs deleting either, since none ever was).
- **Historical `Catch` and `TackleBoxEntry` references remain resolvable.** `getEntryById()` still applies no `retiredAt` filter (MFS-015) — unchanged, and re-verified at scale in §12's tests.
- **Retirement is not manufacturer discontinuation.** A retired entry means only "the currently bundled catalog no longer promotes this row" — never a claim about the real-world product's commercial status. Practically: no UI or documentation anywhere describes a retired entry as "discontinued" (none does today), and the design keeps un-retirement fully available — a variant reappearing in a later `catalogVersion` has its `retiredAt` cleared automatically by the ordinary correct/insert path (unchanged from today's `_reconcileVariant`).
- **Models containing referenced/retired variants remain resolvable.** Already guaranteed: `getEntryById()`'s join to `LureModels` carries no retirement filter on either side of the join (there is none to filter on for the model, and none applied for the variant in this specific method) — unchanged, re-verified in §12.
- **No partial catalog state after a failed import.** Guaranteed structurally by the single outer transaction (§7) — not a policy statement layered on top, but a direct consequence of the chosen transaction boundary.

---

## 9. Duplicate Normalization Rules

A single normalization function, used identically for (a) duplicate-model-name-within-manufacturer detection and (b) duplicate-variant-within-model detection, so two developers running the tool independently always get the same result:

```python
def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKC", text)
    text = text.strip()
    text = re.sub(r"\s+", " ", text)
    return text.casefold()
```

In order: Unicode NFKC normalization (handles combining vs. precomposed accented characters, e.g. Finnish ä/ö entered via different input methods, consistently); trim; collapse repeated internal whitespace to one space; Unicode-aware case-folding (`str.casefold()`, stronger than `.lower()` — the same reasoning already applied on the Dart side by the app's own `.toLowerCase()` search-matching choice in `lure_catalog_search_text.dart`, independently arrived at here for a related but distinct concern).

**Deliberately not normalized:** punctuation, slashes, and hyphens. Per the task's explicit conservatism instruction, `"Red/White"`, `"Red-White"`, and `"Red White"` are treated as three *different* strings — collapsing them risks merging two legitimately distinct manufacturer color names that happen to look similar. Only whitespace shape and letter case/form are normalized; nothing structural is.

### Model-duplicate key (scoped per manufacturer file)

```text
key = normalize(manufacturer) + " " + normalize(modelName)
```

Scoped per manufacturer, not globally — two different manufacturers legitimately sharing a model name (e.g. several brands sell a "Minnow") is not a duplicate.

### Variant-duplicate key (scoped per model)

```text
key = normalize(variantName or "") + " " +
      normalize(colorName or "") + " " +
      normalize(manufacturerColorCode or "")
```

Uses the full three-field tuple, not any single field — two variants sharing a `colorName` but differing in `manufacturerColorCode` (a legitimate distinct SKU) are correctly *not* flagged.

**Worked examples**, to make the conservatism concrete:

- `"Hot Craw"` vs. `"Hot   Craw"` (extra internal whitespace) → **flagged** (identical after normalization).
- `"Hot Craw"` vs. `"hot craw"` → **flagged** (case-fold makes them identical).
- `"Hot Craw"` vs. `"Hot Craw (Glow)"` → **not flagged** (different string, full stop).
- `"Red/White"` vs. `"Red-White"` → **not flagged** (punctuation is never touched).

### Identity-drift check (§4, §5 rule 12)

For every id present in both the previously committed `catalog_v1.json` (loaded as the "before" reference) and the newly built output, compare `manufacturer` and `modelName` (for a model id) or the parent model's identity plus the variant's own distinguishing tuple (for a variant id). If either changed and the record does not carry `"idReuseAcknowledged": true` in the current source file, validation fails with a clear message naming the old and new values. This is a deliberately blunt, conservative heuristic — it cannot distinguish "a genuine correction" from "an accidental identity swap" on its own, so it simply forces a human to say which one it is, once, explicitly, in the same commit that makes the change.

---

## 10. Scale and Performance

Verified against the task's stated target: 1,000 models, 10,000 variants, a ~5–10 MB generated asset.

- **Parse memory:** addressed in §7 — no streaming parser; a single `jsonDecode` is expected to be well within normal budget, to be confirmed on a physical device (§13), not merely assumed.
- **Transaction duration — the one evidence-based change:** the current design's cost profile is dominated by per-row `SELECT` round-trips (up to 20,000 for a full reconciliation at target scale) more than by the writes themselves. §7's batched pre-read (a handful of chunked `SELECT ... WHERE id IN (...)` queries instead of up to 20,000 individual ones) directly targets this, the one clearly evidence-justified optimization in this design.
- **Upsert complexity:** O(catalog size) — one batched read pass, one decision-and-write pass over `parsed.models`/`parsed.variants`, one retirement pass over already-seed-owned rows (unchanged shape from today) — no quadratic behavior anywhere.
- **Database indexes — no new index added, deferred to measurement:** re-examined every existing repository method against a 10,000-variant catalog:
  - `browse()`: joins on `lureModelId` (indexed) and filters on `manufacturer`/`lureType` (both indexed); the free-text `LIKE '%term%'` scan against `searchText` has no supporting index today and cannot efficiently be given one (a leading-wildcard `LIKE` cannot use a B-tree index regardless), but a full scan of ~10,000 short text rows is small, fast work for on-device SQLite — an accepted, pre-existing characteristic, not a new problem this milestone introduces. `retiredAt IS NULL` likewise has no dedicated index; at this scale that is not expected to be a real cost, and none is added speculatively.
  - `getVariantsForModel()`, `getEntryById()`, `getDistinctManufacturers()`, `getDistinctLureTypes()`: all filter/join on already-indexed or primary-key columns — no change needed.
  - `LureStatisticsRepository`/`GeneralCatchStatisticsRepository`: bounded by the angler's own catch count (typically dozens to low thousands), not catalog size — catalog growth does not change these repositories' cost profile at all.

  **No index is added by this TD.** Adding one without a measured, on-device reason would be exactly the "optimization infrastructure without evidence" the task warns against. §13's physical Android checklist is the actual gate: if real-device testing at delivered scale shows browse/search/filter responsiveness genuinely degraded, that is a concrete, evidence-backed follow-up (adding an index is a small, additive, non-schema-migration-free... actually it *is* a schema change, since a new `@TableIndex` requires a migration step — so any such follow-up would itself need its own small TD/migration, explicitly deferred, not silently added here).
- **Should all ids be loaded into sets/maps during import?** Yes — this is exactly what the batched pre-read (§7) does: every existing id, with its `seedVersion`/`retiredAt`/`createdAt`, loaded once into an in-memory `Map` before the write loop begins.
- **Do current repository queries remain sufficient?** Yes, per the method-by-method review above — no new query shape or repository method is required by this milestone; only the *import* path changes.

---

## 11. Compatibility and One-Time Migration From the Dart Seed

### What is preserved, unconditionally

- Every existing `LureModel`/`LureVariant` id, verbatim.
- Every `TackleBoxEntry.lureVariantId` and `Catch.lureVariantId` reference, resolving exactly as before.
- Lure Statistics (MFS-019), search/filter/browse (MFS-015/018), and placeholder-image fallback behavior — all unaffected, since no query shape or field semantics changes.
- The database schema — zero migration, zero schema version bump. Confirmed table-by-table: `LureModels`, `LureVariants`, `TackleBoxEntries`, `Catches` are all structurally unchanged by this TD.

### The one-time transition, as two explicit, separately-verifiable steps

**Step 1 — mechanical, lossless transcription (`catalogVersion = 1`).** The current 4 `LureModel`/14 `LureVariant` Dart literals are transcribed into `assets/lure_catalog/source/*.json`, preserving every id, every field value, and every field's presence/absence exactly. The resulting `catalog_v1.json` is built at `catalogVersion = 1` — deliberately the *same* version number `currentLureCatalogSeedVersion` already used. Because reconciliation only writes when `storedSeedVersion < currentVersion`, and every existing installed device already has these rows stored at `seedVersion = 1`, this step is designed to produce **zero writes** against any already-reconciled database: `1 < 1` is `false`. This is a testable acceptance property (§12), not an assumption — a test seeds a database via the *legacy* Dart path, then runs `ensureSeeded()` against `catalog_v1.json`, and asserts no row changed.

**Step 2 — any genuine content correction, as its own deliberate change (`catalogVersion = 2`).** If transcription surfaces an actual content fix (a typo noticed while copying), it does not ride silently inside Step 1's version-1 payload — that would make a real correction invisible to any device that already has `seedVersion = 1` stored (the `1 < 1` comparison would skip it). Any real correction is authored as an explicit, separate `catalogVersion = 2` bump, exactly like any future correction would be — this milestone does not special-case its own first transition.

### Duplicate-row safety during the transition

Guaranteed by the same id-preservation discipline, not by new code: because every id is copied, never regenerated, every model/variant takes the update-in-place path (or, for version 1, the no-write path in the common case), never the insert-as-new path. This is precisely why the identity-drift check (§9) matters most acutely right here — a transcription slip that reused an id for the wrong record is the single most likely way this specific migration could silently go wrong, so it receives the tool's strongest guardrail.

### Deprecating the Dart seed source

Once `catalog_v1.json` is verified equivalent (§12) and the runtime importer (§7) is wired to it, `lure_catalog_seed_data.dart` and `currentLureCatalogSeedVersion` are **deleted**, not left in place as an unused parallel source — consistent with `docs/development-rules.md`'s "avoid duplicate ... business logic" and this project's established practice of removing superseded code rather than accumulating it (e.g. MFS-027's own "the earlier raster-WMTS architecture was fully retired, not merely superseded").

---

## 11A. Migration Plan

*(Added Revision 2.)* This section operationalizes §11's design into a concrete, ordered implementation checklist — the exact sequence to follow when this TD is implemented. It does not introduce any new decision; every step below is a direct execution of a rule already established in §4 (identity), §7 (import), §9 (identity-drift check), §11 (the two-step version discipline), or §12 (regression tests).

1. **Export the existing seed catalog into the new JSON authoring format.** Transcribe `lure_catalog_seed_data.dart`'s current 4 `LureModel`/14 `LureVariant` entries into `assets/lure_catalog/source/*.json`, one file per manufacturer already represented (Rapala, Abu Garcia, Storm), following the schema in §2.
2. **Preserve every existing stable ID exactly.** Every `id` is copied verbatim from the Dart literals into the corresponding JSON object — never regenerated, never reformatted. This is the single most important step in the whole plan: every later guarantee in this checklist (no data loss, no broken references, no duplicate rows) follows directly from this one being done correctly.
3. **Generate `catalog_v1.json`.** Set `catalogVersion = 1` in `catalog_version.json` — deliberately the *same* value `currentLureCatalogSeedVersion` already has today, not a new number (§11 Step 1) — and run `python tools/lure_catalog/build_catalog.py build`.
4. **Validate the generated catalog.** `build` already runs `validate` first (§5) and refuses to write output on failure; confirm a clean run with no reported violations (schema shape, id uniqueness, normalized-duplicate checks, licensing-boundary structural check, and — critically for this step — the identity-drift check in §9 finding no unacknowledged identity change for any transcribed id).
5. **Wire the runtime importer to the new asset, without yet removing the old one.** Point the generalized `ensureSeeded()` (§7) at `catalog_v1.json` via `LureCatalogAssetLoader`. `lure_catalog_seed_data.dart` remains present and unused in the codebase at this point — not yet deleted (see step 8) — so a working fallback still exists until every later step is independently confirmed.
6. **Verify no duplicate rows appear.** Run the zero-write equivalence test (§11 Step 1's core acceptance property, §12): seed a test database via the legacy Dart path, then run `ensureSeeded()` against `catalog_v1.json`, and assert both that no row was inserted, updated, or retired, and that the total row count in `LureModels`/`LureVariants` is unchanged before and after.
7. **Verify existing `Catch` and `TackleBoxEntry` references still resolve.** Run the reference-resolution tests (§12): a `TackleBoxEntry.lureVariantId` and a `Catch.lureVariantId` set up against the legacy Dart-seeded catalog both continue to resolve to the same lure, with the same displayed fields, after the database reconciles against `catalog_v1.json`. Confirm this once more, physically, on a device (§13).
8. **Remove the obsolete Dart seed implementation only after every regression test and the physical check in step 7 pass.** Delete `lure_catalog_seed_data.dart` and `currentLureCatalogSeedVersion` (§11, §16) last, never first — this ordering is deliberate: the old code path is kept available as a known-good reference for as long as the new path is still being independently verified, and is removed only once nothing in the codebase depends on it being correct anymore.

**This plan guarantees, by construction, that no user ever loses data and no ID ever changes.** Step 2 is the mechanism (ids are copied, not regenerated); step 3's unchanged version number is why an already-installed device's reconciliation is a pure no-op rather than a rewrite; steps 6–7 are how that guarantee is *checked*, not merely assumed; and step 8's ordering ensures the only code path ever deleted is one that has already been proven unnecessary.

---

## 12. Testing Strategy

### Developer tooling tests (Python, `tools/lure_catalog/test_build_catalog.py` — run manually, not part of `flutter test`, per §6)

- A valid minimal fixture (one manufacturer, one model, two variants) builds successfully and produces the expected flattened, sorted output.
- Malformed JSON in a source file fails with a non-zero exit and names the file.
- A missing required field (e.g. no `id`, no `modelName`) fails.
- A duplicate model id across two fixture files fails.
- A duplicate variant id fails.
- Two models under one manufacturer whose names normalize identically fail.
- Two variants under one model whose distinguishing tuples normalize identically fail.
- An empty/blank manufacturer, model name, or (when it's the only distinguishing field) variant text fails.
- An unrecognized `lureType` fails; a known one passes.
- A non-positive length/weight/running-depth fails; `min > max` running depth fails.
- An unrecognized/extra JSON key fails (the structural licensing-boundary enforcement).
- Running `build()` twice against identical input produces byte-identical output.
- A fixture where an existing id's `manufacturer`/`modelName` changed from a "previous" reference build, without `idReuseAcknowledged`, fails; the same fixture with the flag set passes.

### Runtime tests (Dart, `flutter test`, using the existing in-memory Drift test-database pattern already established in `lure_catalog_repository_test.dart`/`lure_catalog_database_test.dart`)

- First import against an empty database inserts every model/variant from a test fixture `ParsedLureCatalog`.
- A second import with an unchanged fixture and the same `catalogVersion` performs zero writes (idempotent) — extends the existing `'a second call performs no writes (idempotent)'` test to the new asset-driven path.
- A `catalogVersion` bump with one corrected field updates the seed-owned row in place, preserving `createdAt`, bumping `updatedAt`, keeping the same `id`.
- A row whose stored `seedVersion` is `null` is never written to by any import, at any `catalogVersion` — extends the existing "never modifies a row whose stored `seedVersion` is null" test.
- A variant present in a prior import but absent from a new fixture is retired (`retiredAt` set), excluded from `browse()`, and still resolvable via `getEntryById()`.
- A model whose every variant is retired no longer appears via `browse()`, `getDistinctManufacturers()`, or `getDistinctLureTypes()`, but its info remains resolvable through any of its (retired) variants via `getEntryById()` — new test, exercising §8 scenario 6.
- A `TackleBoxEntry.lureVariantId` and a `Catch.lureVariantId` referencing a since-retired variant both continue to resolve correctly across a catalog import — extends MFS-016/017's existing historical-stability tests to a catalog-content update, not only a tackle-box removal.
- A deliberately-interrupted import (a malformed row injected mid-fixture to force an exception inside the transaction) leaves the database in exactly its pre-import state, verified by re-querying afterward — new test; today's fixture-driven seed data never fails mid-way, so no equivalent test exists yet.
- A large synthetic fixture (1,000 models / 10,000 variants, generated in-test, never committed as a real asset) imports successfully within a documented, generous wall-clock budget — a performance *sanity* test with a loose bound, not a strict benchmark.
- `browse()`/search (including a Finnish ä/ö term)/manufacturer and lure-type filtering/`getVariantsForModel()`/`getDistinctManufacturers()`/`getDistinctLureTypes()` all produce correct, still-deterministically-ordered results against the larger synthetic fixture — regression coverage at scale, not new behavior.
- `LureStatisticsRepository` computation is unaffected by when an import happens relative to when catches are recorded — regression coverage reusing `lure_statistics_repository_test.dart`'s existing pattern.

---

## 13. Physical Android Acceptance Checklist

- App launches and the expanded catalog loads with no added startup delay (import remains lazy, per §7).
- First catalog open (cold `ensureSeeded()` path, full reconciliation) completes in a clearly-loading, not-perceived-as-frozen time; a subsequent open (idempotent, `LureCatalogVersionStore` fast-path) is fast.
- Real-device memory during first import stays within normal bounds (verifying §7/§10's parse-memory estimate against an actual device, not only reasoning about it).
- Manufacturer/model text search returns correct results, including at least one Finnish ä/ö query.
- Manufacturer and lure-type filters remain responsive and reflect the expanded, real option set.
- The Lure Catalog list scrolls smoothly at the delivered scale (lazy/virtualized rendering, per MFS-015's existing Performance Expectations).
- Model → Color Variants browsing (MFS-018) opens correctly and stays responsive for a model with many variants.
- The owned-in-tackle-box indicator still appears correctly per variant.
- Adding a newly-available (not present under the old 4-model seed) lure to the Personal Tackle Box works end-to-end.
- Assigning that lure to a `Catch` (MFS-017) works end-to-end.
- Catch Details correctly resolves and displays the assigned lure.
- Lure Statistics (MFS-019) correctly attributes catches to lures from the expanded catalog.
- Re-launching the app after the catalog transition does not duplicate any row — spot-check that one of the four original seed models still resolves to its original id and content.
- Every one of the above still works with the device in airplane mode.

---

## 14. Content Authoring Workflow

1. Add a new manufacturer file under `assets/lure_catalog/source/<name>.json`, or edit an existing one, following the schema in §2.
2. For any new model/variant, generate a fresh id with `python tools/lure_catalog/build_catalog.py new-id` and paste it into the `id` field. Never reuse an existing id for different content (§4).
3. Run `python tools/lure_catalog/build_catalog.py validate` and fix every reported issue.
4. Run `python tools/lure_catalog/build_catalog.py build`, which re-validates and writes `assets/lure_catalog/catalog_v1.json`.
5. Review the diff of `catalog_v1.json` in version control — deterministic, stable-sorted output (§3, §6) means the diff shows only the intended content change.
6. Run `flutter test` — the committed-asset self-consistency tests (§12) catch a corrupted or half-built asset.
7. Launch the app; the runtime importer (`ensureSeeded()`, §7) reconciles the new `catalogVersion` the next time the catalog is opened.

**A developer adding or correcting catalog content never touches:** `LureCatalogRepository`, `LureCatalogMapper`, either Drift table class, any presentation widget, or any Dart seed list — none of those files change as part of ordinary content growth, satisfying locked decision #10 directly.

---

## 14A. Catalog Contribution Guidelines

*(Added Revision 2.)* Long-term editorial rules for maintaining the catalog, addressed to future contributors — distinct from §5's mechanical validation rules (which catch structural and duplicate errors, not naming-style choices) and §15's legal/licensing boundary (which governs what content is allowed at all, not how allowed content should be worded). A contributor should read §14 (how to submit a change), this section (house style for what goes in it), and §15 (what may never go in it) together.

### Naming and language

- **Manufacturer names always use the manufacturer's own official spelling and capitalization** — exactly as the manufacturer itself presents it (e.g. `"Rapala"`, not `"RAPALA"` or `"rapala"`), never a stylized, abbreviated, or retailer-listing variant.
- **Model names always use the manufacturer's own official product name** — the name the manufacturer itself gives the product, not a contributor's paraphrase and not a retailer's listing title (which frequently appends extra descriptive words that are not actually part of the product name).
- **Color names use the manufacturer's own naming** for that color or pattern (e.g. `"Hot Craw"`, `"Firetiger"`) — not a contributor's own description of what the color looks like.
- **Manufacturer, model, and color names are never translated**, into Finnish or any other language, even though the rest of the application's UI text is Finnish (`docs/development-rules.md`'s UI-text rule governs application UI, not manufacturer-supplied product identifiers). This directly extends MFS-015's own existing principle for `lureType` — "domain identifiers remain in English... UI display names must not be stored in the database" — to manufacturer-supplied names: translating a product's actual name would make the catalog entry unrecognizable against the real, physical product and its packaging, which defeats the purpose of recording it at all.

### Data completeness

- **An unknown value is left absent — never guessed, approximated, or filled with a placeholder.** Represented as an omitted field or explicit JSON `null` (§2), consistent with the existing domain rule already established for the original seed data (MFS-015: "a missing value must never be represented by a placeholder number... it must be stored as absent"), now extended as a standing rule for every future contribution, not only the original 14 variants.
- If a manufacturer's published specification does not state a value (for example, no published weight for a given color), the field stays absent rather than being estimated from a similar variant or measured independently by the contributor. Only a manufacturer-published, or otherwise verifiably sourced, value is entered.

### Measurements and units

- **Length is always recorded in whole millimetres** (`lengthMillimeters`), matching `Catch.lengthMillimeters`'s existing canonical-unit convention — never centimetres or inches, regardless of the unit printed on the manufacturer's own packaging; convert at authoring time, before the value is entered.
- **Weight is always recorded in whole grams** (`weightGrams`), matching `Catch.weightGrams`'s existing canonical-unit convention — never ounces, regardless of the manufacturer's own packaging unit; convert at authoring time.
- Running depth follows the same, already-established millimetre convention (`minRunningDepthMillimeters`/`maxRunningDepthMillimeters`) — unchanged, restated here only for completeness.

### Variant identity

- **One `LureVariant` entry represents exactly one real, independently purchasable manufacturer product variant** — one specific color/size/spec combination the manufacturer actually sells as its own product — never a contributor's own grouping of several real products into one entry, or splitting of one real product into several.

### Stable IDs

- **A stable ID, once published** (merged into `source/*.json` and included in a built `catalog_v1.json`), **is permanent and must never be edited** — not even to "clean it up" or make it more readable. This restates §4's Identity policy as a contribution rule, not only a technical constraint.
- **An existing ID is never reused for a different real-world product, under any circumstance.** §9's identity-drift check exists specifically to catch an accidental violation of this rule before it ships.
- **A new ID is generated** (`python tools/lure_catalog/build_catalog.py new-id`, §4) **only for a genuinely new catalog entry** — never to "re-identify" or replace an existing entry's ID, even if that ID feels inconvenient or was originally assigned by a different contributor.

### Consistency

- **Keep formatting consistent across manufacturers** — capitalization, spacing, and punctuation conventions for names should not vary arbitrarily between one manufacturer's entries and another's, or between contributions made by different people over time. §9's normalization-based duplicate detection is deliberately conservative (§9) and does not, and is not intended to, enforce this on its own — it only catches near-identical duplicates within one manufacturer/model, not general style drift across the catalog. Consistency at this level is an editorial discipline for contributors to uphold directly, called out here for that reason rather than left as an unstated assumption.

### Compliance check for this addition

None of the rules above changes any field, table, identifier scheme, or validation mechanism already decided in Revision 1 — every bullet either restates an existing MFS-015/TD-028 rule in contributor-facing language (naming source of truth, unit conventions, ID permanence) or adds a purely editorial expectation with no mechanical enforcement claimed (naming style consistency, one-variant-per-real-product). No locked decision (front matter, this document) is touched.

---

## 15. Licensing/Content Policy Documentation

MFS-028's "Content Sourcing and Licensing" section remains the single canonical, product-level statement of this policy. This TD adds one authoring-facing restatement, colocated where a future contributor will actually be looking:

- `tools/lure_catalog/README.md` restates the allowed/not-included lists in short form (manufacturer/model names and objective specifications: allowed; product photography, logos, marketing copy, scraped databases: not included without confirmed rights) and links back to MFS-028 as the authoritative source — mirroring exactly how `tools/syke_bathymetry/README.md` documents that tool's own data-sourcing situation, so the convention is consistent across both dev-tooling directories in this repository.
- The mechanical backstop is §2/§5: the authoring schema has no field for photography, logos, or marketing copy, and the validator rejects any attempt to add one as an unrecognized key. Policy and structure enforce the same rule from two directions.

---

## 16. Files Affected — File Plan

### New

```text
assets/lure_catalog/source/*.json                              (authoring fixtures for this TD; real content is future work)
assets/lure_catalog/catalog_v1.json                             (generated)
assets/lure_catalog/catalog_version.json                        (developer-set {"catalogVersion": N} control file, §3)

tools/lure_catalog/build_catalog.py
tools/lure_catalog/validators.py
tools/lure_catalog/normalize.py
tools/lure_catalog/known_lure_types.json
tools/lure_catalog/test_build_catalog.py
tools/lure_catalog/README.md

lib/features/lure_catalog/data/lure_catalog_asset_loader.dart
lib/features/lure_catalog/data/lure_catalog_version_store.dart

test/features/lure_catalog/data/lure_catalog_asset_loader_test.dart
test/features/lure_catalog/data/lure_catalog_version_store_test.dart
test/features/lure_catalog/data/lure_catalog_import_scale_test.dart
```

### Modified

```text
lib/features/lure_catalog/data/lure_catalog_repository.dart     (ensureSeeded() generalized, §7)
test/features/lure_catalog/data/lure_catalog_repository_test.dart (extended coverage, §12)
test/features/lure_catalog/data/lure_catalog_database_test.dart   (asset-driven fixtures instead of Dart-literal fixtures)
```

### Deleted

```text
lib/features/lure_catalog/data/local/lure_catalog_seed_data.dart  (§11 — once catalog_v1.json is verified equivalent)
```

### Explicitly unmodified

`lure_models_table.dart`, `lure_variants_table.dart`, `lure_catalog_mapper.dart`, `lure_catalog_search_text.dart`, every `lure_catalog`/`personal_tackle_box`/`catches`/`statistics` presentation widget, `app_database.dart` (no schema version change).

---

## 17. Implementation Order

1. `tools/lure_catalog/` (validators, normalize, build script, its own tests) — fully testable in isolation, no Dart/Flutter dependency.
2. Transcribe the current 4-model/14-variant seed content into `assets/lure_catalog/source/*.json`; run `build`; verify `catalog_v1.json` is content-equivalent to the existing Dart seed (§11 Step 1).
3. `LureCatalogAssetLoader`, `LureCatalogVersionStore`, and their unit tests.
4. Generalize `LureCatalogRepository.ensureSeeded()` (batched pre-read, batched write, asset-driven content, version-store fast path) — Dart tests per §12.
5. Delete `lure_catalog_seed_data.dart`; update `lure_catalog_database_test.dart`'s fixtures accordingly.
6. Scale/performance sanity test against a large synthetic fixture (§10, §12).
7. `flutter analyze`; full automated test suite.
8. Physical Android testing (§13).
9. Project status / architecture review, per this project's standard workflow (`docs/development-rules.md`).

---

## 18. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| A transcription mistake during the one-time transition (§11) accidentally reuses an id for different content | The identity-drift check (§9) is specifically aimed at this exact failure mode; §12 includes a dedicated transition-equivalence test |
| A future contributor adds a photo/logo/URL field "just this once" | Structurally impossible without a validator failure (§2, §5, §15) — the schema has no such field, and unknown keys are rejected |
| Import-time performance at 10,000-variant scale turns out worse than estimated despite batching | §13's physical-device checklist is the actual gate; batching (§7/§10) is the one change made specifically because the current per-row-SELECT design is arithmetically the obvious bottleneck at this scale |
| A developer forgets to bump `catalogVersion` after a genuine content change | `check` (§6) catches the resulting source/output mismatch before it's committed; §11 documents the two-step (transcribe-then-correct) discipline explicitly to make this mistake harder to make by accident |
| Two developers editing different manufacturer files simultaneously introduce a duplicate id undetected until merge | Validation runs across *all* `source/*.json` files together, so the very next `validate`/`build` run after a merge catches it — no per-file validation blind spot |

No risk identified here required reopening any of the ten locked decisions in this document.

---

## 19. Dependencies

No new external runtime (Dart) package dependency. `dart:convert` (`jsonDecode`) and the already-declared `shared_preferences` package cover everything this TD's runtime side needs. No new Python package dependency either — the standard library is sufficient (§5).

Reused, unmodified: the Repository pattern and feature-first structure (ADR-0001, ADR-0003, ADR-0006), Drift/SQLite (ADR-0005), the existing `LureCatalogRepository` read methods (MFS-015/TD-015, MFS-018/TD-018), and the existing reconciliation rules this TD generalizes rather than replaces.

---

## 20. Validation / Definition of Done

- `tools/lure_catalog/build_catalog.py build` succeeds against a minimal multi-manufacturer fixture and produces a schema-conformant `catalog_v1.json`.
- Every validation rule in §5 has a passing and a failing test case in `test_build_catalog.py`.
- `build_catalog.py check` correctly detects an intentionally introduced source/output mismatch.
- `ensureSeeded()` against the transcribed `catalog_v1.json` produces zero writes against a database already reconciled via the legacy Dart seed path (§11 Step 1's core acceptance property).
- Every automated Dart test in §12 passes.
- `flutter analyze` passes with no new issues.
- The full existing automated test suite continues passing (no regression to Lure Catalog, Personal Tackle Box, Assign Lure to Catch, or Lure Statistics behavior).
- `lure_catalog_seed_data.dart` and `currentLureCatalogSeedVersion` no longer exist in the codebase.
- No change to `app_database.dart`'s `schemaVersion` or `MigrationStrategy`.
- Every item in §13's Physical Android Acceptance Checklist is verified on a physical device.
- Architecture review completed, per `docs/development-rules.md`'s standard feature workflow.

---

## Non-Goals

Restated from MFS-028 for implementation-time clarity, not reopened here:

- Remote or server-managed catalog synchronization.
- User-submitted or community-shared catalog entries.
- Manufacturer photographs, logos, or marketing copy, absent separately confirmed usage rights.
- Automatic web scraping or any unattended external content acquisition.
- Cloud moderation.
- A general-purpose in-app admin or catalog-editing UI.
- A normalized `Manufacturer` entity.
- Any change to the domain model, schema, or repository contract of `personal_tackle_box`, `catches`, or `statistics`.
- Any change to how the catalog is browsed, searched, filtered, or presented (MFS-015/MFS-018 UX is unmodified).
- Adding real, large-scale manufacturer content — this TD designs the pipeline; populating it is separate, ongoing content work using the workflow §14 defines.
