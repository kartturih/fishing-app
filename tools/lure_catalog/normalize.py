"""Text normalization for duplicate-detection comparisons in the Lure
Catalog authoring tooling. See TD-028 Section 9.

Deliberately conservative: only whitespace shape and Unicode case/form are
normalized. Punctuation, slashes, and hyphens are never touched, since they
can be semantically meaningful in a real manufacturer color name (e.g.
"Red/White" vs. "Red-White" may legitimately be two different products).

This normalization is used only for duplicate-detection comparisons. It is
never written to the generated catalog, never used for display, and is a
distinct concern from the runtime `searchText` matching mechanism in
`lib/features/lure_catalog/data/lure_catalog_search_text.dart` (which solves
a different problem: free-text search, not authoring-time duplicate
detection).
"""

from __future__ import annotations

import re
import unicodedata


def normalize(text: str) -> str:
    """Normalizes `text` for duplicate-detection comparison only."""
    text = unicodedata.normalize("NFKC", text)
    text = text.strip()
    text = re.sub(r"\s+", " ", text)
    return text.casefold()


def model_duplicate_key(manufacturer: str, model_name: str) -> str:
    """Normalized key used to detect two models under one manufacturer that
    describe the same real product (TD-028 Section 9)."""
    return normalize(manufacturer) + " " + normalize(model_name)


def variant_duplicate_key(
    variant_name: str | None,
    color_name: str | None,
    manufacturer_color_code: str | None,
) -> str:
    """Normalized key used to detect two variants under one model that
    describe the same real product variant (TD-028 Section 9). Uses the
    full three-field tuple so that two variants differing in only one
    distinguishing field (e.g. same color, different manufacturer color
    code) are correctly not flagged."""
    return (
        normalize(variant_name or "")
        + " "
        + normalize(color_name or "")
        + " "
        + normalize(manufacturer_color_code or "")
    )
