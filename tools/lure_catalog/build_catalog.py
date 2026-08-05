#!/usr/bin/env python3
"""Developer-run build/validation tool for the Lure Catalog's bundled
content. See TD-028 Section 5.

This tool is never run by the app, `flutter analyze`, `flutter test`, or CI
-- exactly like the existing `tools/syke_bathymetry/build_mbtiles.py`
precedent. It reads manufacturer-specific authoring files under
`assets/lure_catalog/source/`, validates them, and merges them into one
bundled, normalized, deterministic asset: `assets/lure_catalog/catalog_v1.json`.

Usage (from this directory):
    python build_catalog.py validate   # run every validation rule; write nothing
    python build_catalog.py build      # validate, then write catalog_v1.json
    python build_catalog.py check      # rebuild in-memory, diff against the committed asset
    python build_catalog.py new-id     # print one fresh UUID v4 for pasting into a source file

No third-party packages are required -- the Python standard library is
sufficient for this tool's entire scope.
"""

from __future__ import annotations

import argparse
import json
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import validators
from normalize import normalize

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent.parent
DEFAULT_SOURCE_DIR = REPO_ROOT / "assets" / "lure_catalog" / "source"
DEFAULT_OUTPUT_FILE = REPO_ROOT / "assets" / "lure_catalog" / "catalog_v1.json"
DEFAULT_CATALOG_VERSION_FILE = REPO_ROOT / "assets" / "lure_catalog" / "catalog_version.json"
KNOWN_LURE_TYPES_FILE = TOOL_DIR / "known_lure_types.json"

# Fields compared when deciding whether two built catalogs have the same
# *content* -- deliberately excludes `generatedAt`, which is an audit
# timestamp that legitimately differs between two builds of identical
# content and must never drive a correctness or drift decision (TD-028
# Section 3: "never used by any reconciliation decision").
CONTENT_KEYS = ("catalogVersion", "models", "variants")


def load_known_lure_types(path: Path = KNOWN_LURE_TYPES_FILE) -> set[str]:
    with path.open("r", encoding="utf-8") as handle:
        return set(json.load(handle))


def load_catalog_version(path: Path = DEFAULT_CATALOG_VERSION_FILE) -> int:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    version = data.get("catalogVersion")
    if not isinstance(version, int) or isinstance(version, bool) or version <= 0:
        raise ValueError(
            f"{path}: catalogVersion must be a positive integer, got {version!r}"
        )
    return version


def load_previous_catalog(path: Path = DEFAULT_OUTPUT_FILE) -> dict[str, Any] | None:
    """Loads the previously committed generated asset, if one exists yet --
    used only by the identity-drift check (TD-028 Section 4/Section 9).
    A fresh catalog with nothing committed yet has nothing to compare
    against; every id is new by definition."""
    if not path.exists():
        return None
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _model_sort_key(model: dict[str, Any]) -> tuple[str, str, str]:
    return (
        normalize(model.get("manufacturer", "")),
        normalize(model.get("modelName", "")),
        model.get("id", ""),
    )


def _variant_sort_key(variant: dict[str, Any]) -> tuple[str, str]:
    return (variant.get("lureModelId", ""), variant.get("id", ""))


def build_catalog_data(
    files: list[tuple[str, Any]],
    catalog_version: int,
    generated_at: str | None = None,
) -> dict[str, Any]:
    """Flattens the nested manufacturer-file authoring structure into the
    flat `models[]`/`variants[]` shape the runtime importer consumes
    (TD-028 Section 3), deterministically sorted (models by manufacturer,
    modelName, id; variants by lureModelId, id -- matching
    `LureCatalogRepository.browse()`'s own existing default sort).

    Assumes `files` has already passed `validators.validate_all` --  this
    function does not itself validate; callers must not call it on invalid
    input.
    """
    models_out: list[dict[str, Any]] = []
    for filename, manufacturer, model in validators.iter_models(files):
        models_out.append(
            {
                "id": model["id"],
                "manufacturer": manufacturer,
                "productFamily": model.get("productFamily"),
                "modelName": model["modelName"],
                "lureType": model["lureType"],
                "defaultImageReference": model.get("defaultImageReference"),
            }
        )

    variants_out: list[dict[str, Any]] = []
    for filename, model, variant in validators.iter_variants(files):
        variants_out.append(
            {
                "id": variant["id"],
                "lureModelId": model["id"],
                "variantName": variant.get("variantName"),
                "colorName": variant.get("colorName"),
                "manufacturerColorCode": variant.get("manufacturerColorCode"),
                "lengthMillimeters": variant.get("lengthMillimeters"),
                "weightGrams": variant.get("weightGrams"),
                "minRunningDepthMillimeters": variant.get("minRunningDepthMillimeters"),
                "maxRunningDepthMillimeters": variant.get("maxRunningDepthMillimeters"),
                "buoyancy": variant.get("buoyancy"),
                "imageReference": variant.get("imageReference"),
            }
        )

    models_out.sort(key=_model_sort_key)
    variants_out.sort(key=_variant_sort_key)

    return {
        "catalogVersion": catalog_version,
        "generatedAt": generated_at or datetime.now(timezone.utc).isoformat(),
        "models": models_out,
        "variants": variants_out,
    }


def content_equal(a: dict[str, Any], b: dict[str, Any]) -> bool:
    """Compares two built catalogs by content only (`CONTENT_KEYS`),
    ignoring `generatedAt` -- see its module-level docstring."""
    return all(a.get(key) == b.get(key) for key in CONTENT_KEYS)


def _check_referential_integrity(catalog: dict[str, Any]) -> list[str]:
    """Defense-in-depth: every variant's `lureModelId` must resolve to a
    model in the same built catalog (TD-028 Section 5, rule 11). Should be
    structurally guaranteed by `build_catalog_data`'s own construction --
    checked anyway as a safety net against a future bug in this tool."""
    model_ids = {model["id"] for model in catalog["models"]}
    violations = []
    for variant in catalog["variants"]:
        if variant["lureModelId"] not in model_ids:
            violations.append(
                f"variant {variant['id']}: lureModelId {variant['lureModelId']!r} "
                "does not match any model in the built catalog"
            )
    return violations


def _load_and_validate(
    source_dir: Path,
) -> tuple[list[tuple[str, Any]], list[str]]:
    files, parse_errors = validators.load_source_files(source_dir)
    known_types = load_known_lure_types()
    previous_catalog = load_previous_catalog()
    violations = validators.validate_all(
        files, parse_errors, known_types, previous_catalog
    )
    return files, violations


def _print_violations(violations: list[str]) -> None:
    for violation in violations:
        print(f"ERROR: {violation}", file=sys.stderr)
    print(f"\n{len(violations)} violation(s) found.", file=sys.stderr)


def cmd_validate(args: argparse.Namespace) -> int:
    source_dir = Path(args.source_dir)
    files, violations = _load_and_validate(source_dir)
    if violations:
        _print_violations(violations)
        return 1

    model_count = sum(1 for _ in validators.iter_models(files))
    variant_count = sum(1 for _ in validators.iter_variants(files))
    print(
        f"OK: {len(files)} manufacturer file(s), {model_count} model(s), "
        f"{variant_count} variant(s) -- no issues found."
    )
    return 0


def cmd_build(args: argparse.Namespace) -> int:
    source_dir = Path(args.source_dir)
    output_file = Path(args.output)

    files, violations = _load_and_validate(source_dir)
    if violations:
        print("Build refused: validation failed.", file=sys.stderr)
        _print_violations(violations)
        return 1

    catalog_version = load_catalog_version(Path(args.catalog_version_file))
    catalog = build_catalog_data(files, catalog_version)

    integrity_violations = _check_referential_integrity(catalog)
    if integrity_violations:
        print("Build refused: referential integrity check failed.", file=sys.stderr)
        _print_violations(integrity_violations)
        return 1

    output_file.parent.mkdir(parents=True, exist_ok=True)
    with output_file.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(catalog, handle, indent=2, ensure_ascii=False, sort_keys=False)
        handle.write("\n")

    print(
        f"Wrote {output_file} -- catalogVersion {catalog_version}, "
        f"{len(catalog['models'])} model(s), {len(catalog['variants'])} variant(s)."
    )
    return 0


def cmd_check(args: argparse.Namespace) -> int:
    """Drift detector: rebuilds in memory from the current source files and
    compares the result (by content, ignoring `generatedAt`) against the
    committed `catalog_v1.json`. Fails loudly on any difference -- the
    guard against "source changed but nobody re-ran build" (TD-028
    Section 6)."""
    source_dir = Path(args.source_dir)
    output_file = Path(args.output)

    files, violations = _load_and_validate(source_dir)
    if violations:
        print("Check failed: source content is not currently valid.", file=sys.stderr)
        _print_violations(violations)
        return 1

    if not output_file.exists():
        print(
            f"Check failed: {output_file} does not exist yet -- run 'build' first.",
            file=sys.stderr,
        )
        return 1

    catalog_version = load_catalog_version(Path(args.catalog_version_file))
    rebuilt = build_catalog_data(files, catalog_version)
    with output_file.open("r", encoding="utf-8") as handle:
        committed = json.load(handle)

    if content_equal(rebuilt, committed):
        print(f"OK: {output_file} matches the current source files (content-equal).")
        return 0

    print(
        f"DRIFT DETECTED: {output_file} does not match what the current source "
        "files would produce. Run 'build' and commit the result.",
        file=sys.stderr,
    )
    return 1


def cmd_new_id(_args: argparse.Namespace) -> int:
    print(str(uuid.uuid4()))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir", default=str(DEFAULT_SOURCE_DIR), help="Manufacturer authoring source directory"
    )
    parser.add_argument(
        "--output", default=str(DEFAULT_OUTPUT_FILE), help="Generated catalog asset path"
    )
    parser.add_argument(
        "--catalog-version-file",
        default=str(DEFAULT_CATALOG_VERSION_FILE),
        help="Developer-set {\"catalogVersion\": N} control file",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("validate").set_defaults(func=cmd_validate)
    subparsers.add_parser("build").set_defaults(func=cmd_build)
    subparsers.add_parser("check").set_defaults(func=cmd_check)
    subparsers.add_parser("new-id").set_defaults(func=cmd_new_id)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
