"""Validation rules for Lure Catalog authoring content. See TD-028 Section 5.

Every `validate_*` function returns a list of human-readable violation
strings; an empty list means the rule passed. Nothing in this module writes
any file. `load_source_files` is the only function that touches disk.

Every rule accumulates violations rather than stopping at the first one, so
a single `validate`/`build` run reports every problem found across every
file in one pass (TD-028 Section 5: "fail loudly").
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from normalize import model_duplicate_key, variant_duplicate_key

FILE_REQUIRED_KEYS = {"manufacturer", "models"}
FILE_ALLOWED_KEYS = FILE_REQUIRED_KEYS

MODEL_REQUIRED_KEYS = {"id", "modelName", "lureType", "variants"}
# idReuseAcknowledged is the identity-drift escape hatch (TD-028 Section 9)
# and applies to a model's own identity (manufacturer/modelName) exactly as
# it does to a variant's -- allowed here for that reason, even though
# TD-028's Section 2 schema table only spelled it out for variants.
MODEL_OPTIONAL_KEYS = {"productFamily", "defaultImageReference", "idReuseAcknowledged"}
MODEL_ALLOWED_KEYS = MODEL_REQUIRED_KEYS | MODEL_OPTIONAL_KEYS

VARIANT_REQUIRED_KEYS = {"id"}
VARIANT_DISTINGUISHING_KEYS = {"variantName", "colorName", "manufacturerColorCode"}
VARIANT_OPTIONAL_KEYS = VARIANT_DISTINGUISHING_KEYS | {
    "lengthMillimeters",
    "weightGrams",
    "minRunningDepthMillimeters",
    "maxRunningDepthMillimeters",
    "buoyancy",
    "imageReference",
    "idReuseAcknowledged",
}
VARIANT_ALLOWED_KEYS = VARIANT_REQUIRED_KEYS | VARIANT_OPTIONAL_KEYS

POSITIVE_INT_KEYS = (
    "lengthMillimeters",
    "weightGrams",
    "minRunningDepthMillimeters",
    "maxRunningDepthMillimeters",
)

# Optional string fields that, when present, must be a non-empty string or
# JSON null -- never an empty string. Mirrors the domain-layer convention
# already established elsewhere in this application (e.g. Catch.notes:
# "must not be empty when provided").
OPTIONAL_STRING_KEYS = (
    "productFamily",
    "defaultImageReference",
    "variantName",
    "colorName",
    "manufacturerColorCode",
    "buoyancy",
    "imageReference",
)


def load_source_files(source_dir: Path) -> tuple[list[tuple[str, Any]], list[str]]:
    """Loads every `*.json` file directly under `source_dir`.

    Returns `(files, errors)`: `files` is a list of `(filename, parsed)` for
    every file that parsed as valid JSON (regardless of whether its content
    is otherwise valid -- that is `validate_schema`'s job); `errors` lists a
    human-readable message for every file that failed to parse at all.
    """
    files: list[tuple[str, Any]] = []
    errors: list[str] = []
    for path in sorted(source_dir.glob("*.json")):
        try:
            with path.open("r", encoding="utf-8") as handle:
                parsed = json.load(handle)
        except json.JSONDecodeError as exc:
            errors.append(f"{path.name}: invalid JSON: {exc}")
            continue
        files.append((path.name, parsed))
    return files, errors


def _is_blank(value: Any) -> bool:
    return value is None or (isinstance(value, str) and value.strip() == "")


def validate_schema(files: list[tuple[str, Any]]) -> list[str]:
    """Validates file/model/variant shape: required fields present, no
    unrecognized keys (the structural licensing-boundary enforcement -- see
    TD-028 Section 2/Section 15, there is no field for photography, logos,
    or marketing copy, so any attempt to add one fails here), correct
    types, the distinguishing-information rule, and positive-only
    measurements with a valid running-depth range.
    """
    violations: list[str] = []

    for filename, data in files:
        if not isinstance(data, dict):
            violations.append(f"{filename}: top-level value must be a JSON object")
            continue

        unknown = set(data.keys()) - FILE_ALLOWED_KEYS
        if unknown:
            violations.append(f"{filename}: unexpected field(s) {sorted(unknown)}")
        missing = FILE_REQUIRED_KEYS - set(data.keys())
        if missing:
            violations.append(f"{filename}: missing required field(s) {sorted(missing)}")
            continue

        if _is_blank(data.get("manufacturer")):
            violations.append(f"{filename}: manufacturer is blank")

        models = data.get("models")
        if not isinstance(models, list):
            violations.append(f"{filename}: models must be an array")
            continue

        for model_index, model in enumerate(models):
            violations.extend(
                _validate_model(filename, model_index, model)
            )

    return violations


def _validate_model(filename: str, model_index: int, model: Any) -> list[str]:
    prefix = f"{filename}: models[{model_index}]"
    violations: list[str] = []

    if not isinstance(model, dict):
        return [f"{prefix}: must be a JSON object"]

    unknown = set(model.keys()) - MODEL_ALLOWED_KEYS
    if unknown:
        violations.append(f"{prefix}: unexpected field(s) {sorted(unknown)}")
    missing = MODEL_REQUIRED_KEYS - set(model.keys())
    if missing:
        violations.append(f"{prefix}: missing required field(s) {sorted(missing)}")

    if "id" in model and _is_blank(model.get("id")):
        violations.append(f"{prefix}: id is blank")
    if "modelName" in model and _is_blank(model.get("modelName")):
        violations.append(f"{prefix}: modelName is blank")
    if "lureType" in model and _is_blank(model.get("lureType")):
        violations.append(f"{prefix}: lureType is blank")

    for key in ("productFamily", "defaultImageReference"):
        if key in model and model[key] is not None and _is_blank(model[key]):
            violations.append(f"{prefix}: {key} must not be an empty string (omit or use null)")

    if "idReuseAcknowledged" in model and not isinstance(model["idReuseAcknowledged"], bool):
        violations.append(f"{prefix}: idReuseAcknowledged must be a boolean")

    variants = model.get("variants")
    if not isinstance(variants, list):
        violations.append(f"{prefix}: variants must be an array")
        return violations
    if len(variants) == 0:
        violations.append(f"{prefix}: variants must contain at least one entry")

    model_id = model.get("id") if isinstance(model.get("id"), str) else f"<index {model_index}>"
    for variant_index, variant in enumerate(variants):
        violations.extend(
            _validate_variant(filename, model_id, variant_index, variant)
        )

    return violations


def _validate_variant(
    filename: str, model_id: str, variant_index: int, variant: Any
) -> list[str]:
    prefix = f"{filename}: model {model_id}: variants[{variant_index}]"
    violations: list[str] = []

    if not isinstance(variant, dict):
        return [f"{prefix}: must be a JSON object"]

    unknown = set(variant.keys()) - VARIANT_ALLOWED_KEYS
    if unknown:
        violations.append(f"{prefix}: unexpected field(s) {sorted(unknown)}")
    missing = VARIANT_REQUIRED_KEYS - set(variant.keys())
    if missing:
        violations.append(f"{prefix}: missing required field(s) {sorted(missing)}")

    if "id" in variant and _is_blank(variant.get("id")):
        violations.append(f"{prefix}: id is blank")

    for key in OPTIONAL_STRING_KEYS:
        if key in variant and variant[key] is not None and _is_blank(variant[key]):
            violations.append(f"{prefix}: {key} must not be an empty string (omit or use null)")

    distinguishing_present = any(
        not _is_blank(variant.get(key)) for key in VARIANT_DISTINGUISHING_KEYS
    )
    if not distinguishing_present:
        violations.append(
            f"{prefix}: must have at least one of "
            f"{sorted(VARIANT_DISTINGUISHING_KEYS)} to be distinguishable from its siblings"
        )

    for key in POSITIVE_INT_KEYS:
        if key in variant and variant[key] is not None:
            value = variant[key]
            if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
                violations.append(f"{prefix}: {key} must be a positive integer, got {value!r}")

    min_depth = variant.get("minRunningDepthMillimeters")
    max_depth = variant.get("maxRunningDepthMillimeters")
    if (
        isinstance(min_depth, int)
        and not isinstance(min_depth, bool)
        and isinstance(max_depth, int)
        and not isinstance(max_depth, bool)
        and min_depth > max_depth
    ):
        violations.append(
            f"{prefix}: minRunningDepthMillimeters ({min_depth}) must not exceed "
            f"maxRunningDepthMillimeters ({max_depth})"
        )

    if "idReuseAcknowledged" in variant and not isinstance(
        variant["idReuseAcknowledged"], bool
    ):
        violations.append(f"{prefix}: idReuseAcknowledged must be a boolean")

    return violations


def iter_models(files: list[tuple[str, Any]]):
    """Yields `(filename, model_dict)` for every well-formed model across
    every file, silently skipping anything malformed -- `validate_schema`
    already reports shape problems; the other rules only need to reason
    about records that are structurally usable."""
    for filename, data in files:
        if not isinstance(data, dict):
            continue
        models = data.get("models")
        if not isinstance(models, list):
            continue
        for model in models:
            if isinstance(model, dict):
                yield filename, data.get("manufacturer"), model


def iter_variants(files: list[tuple[str, Any]]):
    """Yields `(filename, model_dict, variant_dict)` for every well-formed
    variant across every file."""
    for filename, _manufacturer, model in iter_models(files):
        variants = model.get("variants")
        if not isinstance(variants, list):
            continue
        for variant in variants:
            if isinstance(variant, dict):
                yield filename, model, variant


def validate_duplicate_model_ids(files: list[tuple[str, Any]]) -> list[str]:
    """Every model id must be unique across the whole catalog, not just
    within one file (TD-028 Section 4)."""
    violations: list[str] = []
    seen: dict[str, str] = {}
    for filename, _manufacturer, model in iter_models(files):
        model_id = model.get("id")
        if not isinstance(model_id, str) or model_id == "":
            continue
        if model_id in seen:
            violations.append(
                f"duplicate model id {model_id!r}: {seen[model_id]} and {filename}"
            )
        else:
            seen[model_id] = filename
    return violations


def validate_duplicate_variant_ids(files: list[tuple[str, Any]]) -> list[str]:
    """Every variant id must be unique across the whole catalog (TD-028
    Section 4)."""
    violations: list[str] = []
    seen: dict[str, str] = {}
    for filename, _model, variant in iter_variants(files):
        variant_id = variant.get("id")
        if not isinstance(variant_id, str) or variant_id == "":
            continue
        if variant_id in seen:
            violations.append(
                f"duplicate variant id {variant_id!r}: {seen[variant_id]} and {filename}"
            )
        else:
            seen[variant_id] = filename
    return violations


def validate_id_collisions(files: list[tuple[str, Any]]) -> list[str]:
    """A model id and a variant id must never collide with each other.
    Different tables, so not a database-level conflict, but needlessly
    confusing and trivially avoidable with fresh UUIDs (TD-028 Section 4)."""
    violations: list[str] = []
    model_ids: dict[str, str] = {}
    for filename, _manufacturer, model in iter_models(files):
        model_id = model.get("id")
        if isinstance(model_id, str) and model_id != "":
            model_ids[model_id] = filename

    for filename, _model, variant in iter_variants(files):
        variant_id = variant.get("id")
        if isinstance(variant_id, str) and variant_id in model_ids:
            violations.append(
                f"id {variant_id!r} used as both a model id ({model_ids[variant_id]}) "
                f"and a variant id ({filename})"
            )
    return violations


def validate_duplicate_model_names(files: list[tuple[str, Any]]) -> list[str]:
    """Two models under the same manufacturer must not normalize to the
    same name (TD-028 Section 9). Scoped per manufacturer: two different
    manufacturers legitimately sharing a model name is not a duplicate."""
    violations: list[str] = []
    seen: dict[tuple[str, str], str] = {}
    for filename, manufacturer, model in iter_models(files):
        model_name = model.get("modelName")
        if not isinstance(manufacturer, str) or not isinstance(model_name, str):
            continue
        key = model_duplicate_key(manufacturer, model_name)
        seen_key = (manufacturer, key)
        if seen_key in seen:
            violations.append(
                f"{filename}: model {model_name!r} normalizes identically to an "
                f"already-seen model under manufacturer {manufacturer!r} "
                f"(normalized key: {key!r})"
            )
        else:
            seen[seen_key] = filename
    return violations


def validate_duplicate_variants(files: list[tuple[str, Any]]) -> list[str]:
    """Two variants under the same model must not normalize to the same
    distinguishing-field tuple (TD-028 Section 9)."""
    violations: list[str] = []
    seen: dict[tuple[str, str], str] = {}
    for filename, model, variant in iter_variants(files):
        model_id = model.get("id")
        if not isinstance(model_id, str):
            continue
        key = variant_duplicate_key(
            variant.get("variantName"),
            variant.get("colorName"),
            variant.get("manufacturerColorCode"),
        )
        seen_key = (model_id, key)
        if seen_key in seen:
            violations.append(
                f"{filename}: model {model_id}: variant {variant.get('id')!r} "
                f"normalizes identically to an already-seen variant under "
                f"the same model (normalized key: {key!r})"
            )
        else:
            seen[seen_key] = filename
    return violations


def validate_lure_types(
    files: list[tuple[str, Any]], known_types: set[str]
) -> list[str]:
    """A model's lureType must be one of the currently known codes (TD-028
    Section 5) -- an authoring-time content-quality gate, distinct from the
    application's own runtime tolerance for an unrecognized code (MFS-015),
    which this check does not narrow in any way."""
    violations: list[str] = []
    for filename, _manufacturer, model in iter_models(files):
        lure_type = model.get("lureType")
        if isinstance(lure_type, str) and lure_type not in known_types:
            violations.append(
                f"{filename}: model {model.get('id')}: lureType {lure_type!r} is not "
                f"a known code (typo? or add it to known_lure_types.json if intentional)"
            )
    return violations


def _record_matches_identity(record: dict[str, Any], other: dict[str, Any], keys: tuple[str, ...]) -> bool:
    return all(record.get(key) == other.get(key) for key in keys)


def validate_identity_drift(
    files: list[tuple[str, Any]], previous_catalog: dict[str, Any] | None
) -> list[str]:
    """An id that already existed in the previously committed
    `catalog_v1.json` must keep the same core identity (a model's
    manufacturer/modelName; a variant's colorName/variantName/
    manufacturerColorCode) unless the record explicitly sets
    `idReuseAcknowledged: true`. Catches an accidental identity swap before
    it ships (TD-028 Section 4/Section 9). No previous catalog (a fresh
    catalog with nothing committed yet) means nothing to compare -- every
    id is new by definition.
    """
    if previous_catalog is None:
        return []

    violations: list[str] = []

    previous_models = {
        m["id"]: m for m in previous_catalog.get("models", []) if isinstance(m, dict) and "id" in m
    }
    previous_variants = {
        v["id"]: v for v in previous_catalog.get("variants", []) if isinstance(v, dict) and "id" in v
    }

    for filename, manufacturer, model in iter_models(files):
        model_id = model.get("id")
        if not isinstance(model_id, str) or model_id not in previous_models:
            continue
        current = {"manufacturer": manufacturer, "modelName": model.get("modelName")}
        if not _record_matches_identity(current, previous_models[model_id], ("manufacturer", "modelName")):
            if not model.get("idReuseAcknowledged", False):
                violations.append(
                    f"{filename}: model {model_id}: manufacturer/modelName changed from "
                    f"{previous_models[model_id].get('manufacturer')!r}/"
                    f"{previous_models[model_id].get('modelName')!r} to "
                    f"{manufacturer!r}/{model.get('modelName')!r} without idReuseAcknowledged"
                )

    for filename, model, variant in iter_variants(files):
        variant_id = variant.get("id")
        if not isinstance(variant_id, str) or variant_id not in previous_variants:
            continue
        distinguishing_keys = ("variantName", "colorName", "manufacturerColorCode")
        if not _record_matches_identity(variant, previous_variants[variant_id], distinguishing_keys):
            if not variant.get("idReuseAcknowledged", False):
                violations.append(
                    f"{filename}: variant {variant_id}: distinguishing fields changed from "
                    f"{[previous_variants[variant_id].get(k) for k in distinguishing_keys]} to "
                    f"{[variant.get(k) for k in distinguishing_keys]} without idReuseAcknowledged"
                )

    return violations


def validate_all(
    files: list[tuple[str, Any]],
    parse_errors: list[str],
    known_types: set[str],
    previous_catalog: dict[str, Any] | None,
) -> list[str]:
    """Runs every validation rule and returns the combined list of
    violations, in a fixed, readable order."""
    violations: list[str] = list(parse_errors)
    violations += validate_schema(files)
    violations += validate_duplicate_model_ids(files)
    violations += validate_duplicate_variant_ids(files)
    violations += validate_id_collisions(files)
    violations += validate_duplicate_model_names(files)
    violations += validate_duplicate_variants(files)
    violations += validate_lure_types(files, known_types)
    violations += validate_identity_drift(files, previous_catalog)
    return violations
