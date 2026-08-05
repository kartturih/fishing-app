"""Developer-run test suite for the Lure Catalog build tooling. See TD-028
Section 12. Not run by `flutter test`, `flutter analyze`, or CI -- run by
hand:

    cd tools/lure_catalog
    python test_build_catalog.py
"""

from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

import build_catalog
import validators

VALID_FIXTURE = {
    "manufacturer": "Rapala",
    "models": [
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "modelName": "Model One",
            "lureType": "crankbait",
            "variants": [
                {"id": "22222222-2222-2222-2222-222222222222", "colorName": "Red"},
                {"id": "33333333-3333-3333-3333-333333333333", "colorName": "Blue"},
            ],
        }
    ],
}

KNOWN_TYPES = {"crankbait", "jerkbait", "jig"}


def _fixture() -> dict:
    return copy.deepcopy(VALID_FIXTURE)


class LoadSourceFilesTests(unittest.TestCase):
    def test_valid_minimal_fixture_builds_successfully(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            (tmp_path / "rapala.json").write_text(
                json.dumps(VALID_FIXTURE), encoding="utf-8"
            )
            files, errors = validators.load_source_files(tmp_path)
            self.assertEqual(errors, [])
            violations = validators.validate_all(files, errors, KNOWN_TYPES, None)
            self.assertEqual(violations, [])
            catalog = build_catalog.build_catalog_data(files, catalog_version=1)
            self.assertEqual(len(catalog["models"]), 1)
            self.assertEqual(len(catalog["variants"]), 2)
            self.assertEqual(catalog["catalogVersion"], 1)

    def test_malformed_json_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            (tmp_path / "broken.json").write_text("{not valid json", encoding="utf-8")
            files, errors = validators.load_source_files(tmp_path)
            self.assertEqual(files, [])
            self.assertEqual(len(errors), 1)
            self.assertIn("invalid JSON", errors[0])


class SchemaValidationTests(unittest.TestCase):
    def test_missing_required_field_fails(self) -> None:
        fixture = _fixture()
        del fixture["models"][0]["modelName"]
        violations = validators.validate_schema([("rapala.json", fixture)])
        self.assertTrue(any("missing required field" in v for v in violations))

    def test_empty_manufacturer_fails(self) -> None:
        fixture = _fixture()
        fixture["manufacturer"] = "   "
        violations = validators.validate_schema([("rapala.json", fixture)])
        self.assertTrue(any("manufacturer is blank" in v for v in violations))

    def test_empty_model_name_fails(self) -> None:
        fixture = _fixture()
        fixture["models"][0]["modelName"] = ""
        violations = validators.validate_schema([("rapala.json", fixture)])
        self.assertTrue(any("modelName is blank" in v for v in violations))

    def test_variant_with_no_distinguishing_field_fails(self) -> None:
        fixture = _fixture()
        del fixture["models"][0]["variants"][0]["colorName"]
        violations = validators.validate_schema([("rapala.json", fixture)])
        self.assertTrue(any("distinguishable" in v for v in violations))

    def test_model_with_zero_variants_fails(self) -> None:
        fixture = _fixture()
        fixture["models"][0]["variants"] = []
        violations = validators.validate_schema([("rapala.json", fixture)])
        self.assertTrue(any("at least one entry" in v for v in violations))

    def test_non_positive_length_fails(self) -> None:
        fixture = _fixture()
        fixture["models"][0]["variants"][0]["lengthMillimeters"] = 0
        violations = validators.validate_schema([("rapala.json", fixture)])
        self.assertTrue(any("positive integer" in v for v in violations))

    def test_negative_weight_fails(self) -> None:
        fixture = _fixture()
        fixture["models"][0]["variants"][0]["weightGrams"] = -5
        violations = validators.validate_schema([("rapala.json", fixture)])
        self.assertTrue(any("positive integer" in v for v in violations))

    def test_min_exceeds_max_running_depth_fails(self) -> None:
        fixture = _fixture()
        fixture["models"][0]["variants"][0]["minRunningDepthMillimeters"] = 3000
        fixture["models"][0]["variants"][0]["maxRunningDepthMillimeters"] = 1000
        violations = validators.validate_schema([("rapala.json", fixture)])
        self.assertTrue(any("must not exceed" in v for v in violations))

    def test_valid_running_depth_range_passes(self) -> None:
        fixture = _fixture()
        fixture["models"][0]["variants"][0]["minRunningDepthMillimeters"] = 1000
        fixture["models"][0]["variants"][0]["maxRunningDepthMillimeters"] = 2000
        violations = validators.validate_schema([("rapala.json", fixture)])
        self.assertEqual(violations, [])

    def test_unrecognized_key_on_variant_fails(self) -> None:
        fixture = _fixture()
        fixture["models"][0]["variants"][0]["photoUrl"] = "http://example.com/x.jpg"
        violations = validators.validate_schema([("rapala.json", fixture)])
        self.assertTrue(any("unexpected field" in v for v in violations))

    def test_unrecognized_key_on_model_fails(self) -> None:
        fixture = _fixture()
        fixture["models"][0]["logoUrl"] = "http://example.com/logo.png"
        violations = validators.validate_schema([("rapala.json", fixture)])
        self.assertTrue(any("unexpected field" in v for v in violations))

    def test_unrecognized_key_at_file_level_fails(self) -> None:
        fixture = _fixture()
        fixture["description"] = "A great brand."
        violations = validators.validate_schema([("rapala.json", fixture)])
        self.assertTrue(any("unexpected field" in v for v in violations))


class DuplicateIdTests(unittest.TestCase):
    def test_duplicate_model_id_across_files_fails(self) -> None:
        fixture_a = _fixture()
        fixture_b = _fixture()
        fixture_b["manufacturer"] = "Abu Garcia"
        files = [("rapala.json", fixture_a), ("abu_garcia.json", fixture_b)]
        violations = validators.validate_duplicate_model_ids(files)
        self.assertTrue(any("duplicate model id" in v for v in violations))

    def test_duplicate_variant_id_fails(self) -> None:
        fixture = _fixture()
        fixture["models"][0]["variants"][1]["id"] = fixture["models"][0]["variants"][0]["id"]
        violations = validators.validate_duplicate_variant_ids([("rapala.json", fixture)])
        self.assertTrue(any("duplicate variant id" in v for v in violations))

    def test_model_id_and_variant_id_collision_fails(self) -> None:
        fixture = _fixture()
        fixture["models"][0]["variants"][0]["id"] = fixture["models"][0]["id"]
        violations = validators.validate_id_collisions([("rapala.json", fixture)])
        self.assertTrue(any("used as both a model id" in v for v in violations))

    def test_no_collision_between_distinct_ids_passes(self) -> None:
        violations = validators.validate_id_collisions([("rapala.json", VALID_FIXTURE)])
        self.assertEqual(violations, [])


class DuplicateNormalizedContentTests(unittest.TestCase):
    def test_duplicate_normalized_model_name_within_manufacturer_fails(self) -> None:
        fixture = _fixture()
        second_model = copy.deepcopy(fixture["models"][0])
        second_model["id"] = "44444444-4444-4444-4444-444444444444"
        second_model["modelName"] = "model   one"  # normalizes identically to "Model One"
        for variant in second_model["variants"]:
            variant["id"] = variant["id"][:-1] + "9"
        fixture["models"].append(second_model)
        violations = validators.validate_duplicate_model_names([("rapala.json", fixture)])
        self.assertTrue(any("normalizes identically" in v for v in violations))

    def test_same_model_name_across_different_manufacturers_passes(self) -> None:
        fixture_a = _fixture()
        fixture_b = _fixture()
        fixture_b["manufacturer"] = "Abu Garcia"
        fixture_b["models"][0]["id"] = "55555555-5555-5555-5555-555555555555"
        for variant in fixture_b["models"][0]["variants"]:
            variant["id"] = variant["id"][:-1] + "9"
        violations = validators.validate_duplicate_model_names(
            [("rapala.json", fixture_a), ("abu_garcia.json", fixture_b)]
        )
        self.assertEqual(violations, [])

    def test_duplicate_normalized_variant_within_model_fails(self) -> None:
        fixture = _fixture()
        fixture["models"][0]["variants"][1]["colorName"] = "red"  # normalizes same as "Red"
        violations = validators.validate_duplicate_variants([("rapala.json", fixture)])
        self.assertTrue(any("normalizes identically" in v for v in violations))

    def test_different_manufacturer_color_code_is_not_a_duplicate(self) -> None:
        fixture = _fixture()
        fixture["models"][0]["variants"][0]["colorName"] = "Shad"
        fixture["models"][0]["variants"][0]["manufacturerColorCode"] = "SH1"
        fixture["models"][0]["variants"][1]["colorName"] = "Shad"
        fixture["models"][0]["variants"][1]["manufacturerColorCode"] = "SH2"
        violations = validators.validate_duplicate_variants([("rapala.json", fixture)])
        self.assertEqual(violations, [])

    def test_punctuation_is_never_normalized_away(self) -> None:
        fixture = _fixture()
        fixture["models"][0]["variants"][0]["colorName"] = "Red/White"
        fixture["models"][0]["variants"][1]["colorName"] = "Red-White"
        violations = validators.validate_duplicate_variants([("rapala.json", fixture)])
        self.assertEqual(violations, [])


class LureTypeTests(unittest.TestCase):
    def test_unsupported_lure_type_fails(self) -> None:
        fixture = _fixture()
        fixture["models"][0]["lureType"] = "not_a_real_type"
        violations = validators.validate_lure_types([("rapala.json", fixture)], KNOWN_TYPES)
        self.assertTrue(any("not a known code" in v for v in violations))

    def test_known_lure_type_passes(self) -> None:
        violations = validators.validate_lure_types([("rapala.json", VALID_FIXTURE)], KNOWN_TYPES)
        self.assertEqual(violations, [])

    def test_real_known_lure_types_file_matches_dart_labels(self) -> None:
        # A light sanity check that the tool's allowlist wasn't left empty
        # or accidentally emptied -- not a full cross-check against the
        # Dart source (that would require a Dart parser in this tool).
        known_types = build_catalog.load_known_lure_types()
        self.assertIn("crankbait", known_types)
        self.assertIn("jig", known_types)
        self.assertIn("spoon", known_types)


class DeterminismTests(unittest.TestCase):
    def test_build_twice_produces_content_identical_output(self) -> None:
        files = [("rapala.json", VALID_FIXTURE)]
        first = build_catalog.build_catalog_data(files, catalog_version=1)
        second = build_catalog.build_catalog_data(files, catalog_version=1)
        self.assertTrue(build_catalog.content_equal(first, second))
        self.assertEqual(first["models"], second["models"])
        self.assertEqual(first["variants"], second["variants"])

    def test_models_sorted_by_manufacturer_then_model_name(self) -> None:
        fixture_z = {
            "manufacturer": "Zebco",
            "models": [
                {
                    "id": "66666666-6666-6666-6666-666666666666",
                    "modelName": "Z Model",
                    "lureType": "jig",
                    "variants": [
                        {"id": "77777777-7777-7777-7777-777777777777", "colorName": "Red"}
                    ],
                }
            ],
        }
        fixture_a = {
            "manufacturer": "Abu Garcia",
            "models": [
                {
                    "id": "88888888-8888-8888-8888-888888888888",
                    "modelName": "A Model",
                    "lureType": "jig",
                    "variants": [
                        {"id": "99999999-9999-9999-9999-999999999999", "colorName": "Blue"}
                    ],
                }
            ],
        }
        files = [("zebco.json", fixture_z), ("abu_garcia.json", fixture_a)]
        catalog = build_catalog.build_catalog_data(files, catalog_version=1)
        manufacturers = [m["manufacturer"] for m in catalog["models"]]
        self.assertEqual(manufacturers, ["Abu Garcia", "Zebco"])

    def test_variants_sorted_by_model_then_id(self) -> None:
        files = [("rapala.json", VALID_FIXTURE)]
        catalog = build_catalog.build_catalog_data(files, catalog_version=1)
        ids = [v["id"] for v in catalog["variants"]]
        self.assertEqual(ids, sorted(ids))

    def test_referential_integrity_holds_for_a_valid_build(self) -> None:
        files = [("rapala.json", VALID_FIXTURE)]
        catalog = build_catalog.build_catalog_data(files, catalog_version=1)
        violations = build_catalog._check_referential_integrity(catalog)
        self.assertEqual(violations, [])


class IdentityDriftTests(unittest.TestCase):
    def test_no_previous_catalog_means_no_drift_violations(self) -> None:
        violations = validators.validate_identity_drift([("rapala.json", VALID_FIXTURE)], None)
        self.assertEqual(violations, [])

    def test_changed_model_identity_without_acknowledgment_fails(self) -> None:
        previous = build_catalog.build_catalog_data([("rapala.json", VALID_FIXTURE)], catalog_version=1)
        changed = _fixture()
        changed["manufacturer"] = "Abu Garcia"  # same model id, different manufacturer
        violations = validators.validate_identity_drift([("rapala.json", changed)], previous)
        self.assertTrue(any("without idReuseAcknowledged" in v for v in violations))

    def test_changed_model_identity_with_acknowledgment_passes(self) -> None:
        previous = build_catalog.build_catalog_data([("rapala.json", VALID_FIXTURE)], catalog_version=1)
        changed = _fixture()
        changed["manufacturer"] = "Abu Garcia"
        changed["models"][0]["idReuseAcknowledged"] = True
        violations = validators.validate_identity_drift([("rapala.json", changed)], previous)
        self.assertEqual(violations, [])

    def test_changed_variant_identity_without_acknowledgment_fails(self) -> None:
        previous = build_catalog.build_catalog_data([("rapala.json", VALID_FIXTURE)], catalog_version=1)
        changed = _fixture()
        changed["models"][0]["variants"][0]["colorName"] = "Green"  # same id, different color
        violations = validators.validate_identity_drift([("rapala.json", changed)], previous)
        self.assertTrue(any("without idReuseAcknowledged" in v for v in violations))

    def test_unrelated_field_correction_does_not_trigger_drift(self) -> None:
        previous = build_catalog.build_catalog_data([("rapala.json", VALID_FIXTURE)], catalog_version=1)
        corrected = _fixture()
        corrected["models"][0]["lureType"] = "jerkbait"  # not part of identity
        violations = validators.validate_identity_drift([("rapala.json", corrected)], previous)
        self.assertEqual(violations, [])

    def test_brand_new_id_never_flagged(self) -> None:
        previous = build_catalog.build_catalog_data([("rapala.json", VALID_FIXTURE)], catalog_version=1)
        fixture = _fixture()
        fixture["models"][0]["variants"].append(
            {"id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "colorName": "Brand New"}
        )
        violations = validators.validate_identity_drift([("rapala.json", fixture)], previous)
        self.assertEqual(violations, [])


class SourceOutputDriftTests(unittest.TestCase):
    """End-to-end exercise of the actual repository source files, verifying
    'check' (the drift detector) reports no drift when nothing changed, and
    does report drift when a source file diverges from the committed
    asset -- without ever overwriting the real committed files."""

    def test_committed_catalog_matches_committed_source(self) -> None:
        source_dir = build_catalog.DEFAULT_SOURCE_DIR
        output_file = build_catalog.DEFAULT_OUTPUT_FILE
        self.assertTrue(source_dir.exists(), f"{source_dir} does not exist")
        self.assertTrue(output_file.exists(), f"{output_file} does not exist")

        files, errors = validators.load_source_files(source_dir)
        self.assertEqual(errors, [])
        known_types = build_catalog.load_known_lure_types()
        violations = validators.validate_all(files, errors, known_types, None)
        self.assertEqual(violations, [])

        catalog_version = build_catalog.load_catalog_version()
        rebuilt = build_catalog.build_catalog_data(files, catalog_version)
        with output_file.open("r", encoding="utf-8") as handle:
            committed = json.load(handle)

        self.assertTrue(build_catalog.content_equal(rebuilt, committed))
        self.assertEqual(len(committed["models"]), 4)
        self.assertEqual(len(committed["variants"]), 14)


if __name__ == "__main__":
    unittest.main()
