#!/usr/bin/env python3
"""Regression tests for locale-drift.py's provenance classification."""

from __future__ import annotations

import importlib.util
import tempfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
MODULE_PATH = TOOLS / "locale-drift.py"


def load_module():
    spec = importlib.util.spec_from_file_location("hadalis_locale_drift", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load locale drift tool: {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_provenance_classification(module) -> None:
    historical = {
        "stable": "Stable label",
        "renamed.old": "Shared source",
        "retired.only": "Removed feature",
        "retained.missing": "Still here",
        "changed.samekey": "Old wording",
    }
    current = {
        "stable": "Stable label",
        "renamed.new": "Shared source",
        "retained.missing": "Still here",
        "new.feature": "Brand new",
        "changed.samekey": "New wording",
    }
    locale = {
        "stable": "Kararlı etiket",
        "renamed.old": "Paylaşılan kaynak",
        "retired.only": "Kaldırılan özellik",
        "changed.samekey": "Eski ifade çevirisi",
        "locale.only": "Yerel özel",
    }

    report = module.build_report(
        historical,
        current,
        locale,
        "tr_TR",
        "historical-ref",
    )

    counts = report["counts"]
    assert counts["historicalCanonical"] == 5
    assert counts["currentCanonical"] == 5
    assert counts["locale"] == 5
    assert counts["retiredCanonical"] == 2
    assert counts["addedCanonical"] == 2
    assert counts["retainedSourceChanged"] == 1
    assert counts["missing"] == 3
    assert counts["extras"] == 3
    assert counts["historicalExtras"] == 2
    assert counts["foreignExtras"] == 1
    assert counts["missingAddedSinceSnapshot"] == 2
    assert counts["missingRetainedFromSnapshot"] == 1
    assert counts["exactValueRenameCandidates"] == 1

    assert report["missingAddedSinceSnapshot"] == ["new.feature", "renamed.new"]
    assert report["missingRetainedFromSnapshot"] == ["retained.missing"]
    assert report["foreignExtras"] == ["locale.only"]
    assert report["retainedSourceChanged"] == [
        {
            "key": "changed.samekey",
            "historicalSource": "Old wording",
            "currentSource": "New wording",
            "translation": "Eski ifade çevirisi",
            "localeHasKey": True,
        }
    ]
    assert report["exactValueRenameCandidates"] == [
        {
            "from": "renamed.old",
            "to": ["renamed.new"],
            "source": "Shared source",
            "translation": "Paylaşılan kaynak",
        }
    ]

    historical_extras = {item["key"]: item for item in report["historicalExtras"]}
    assert historical_extras["renamed.old"]["translation"] == "Paylaşılan kaynak"
    assert historical_extras["renamed.old"]["hasExactRenameCandidate"] is True
    assert historical_extras["retired.only"]["hasExactRenameCandidate"] is False


def test_duplicate_exact_source_candidates(module) -> None:
    report = module.build_report(
        {"old": "Same source"},
        {"new.b": "Same source", "new.a": "Same source"},
        {"old": "Eski"},
        "tr_TR",
        "historical-ref",
    )
    assert report["exactValueRenameCandidates"] == [
        {
            "from": "old",
            "to": ["new.a", "new.b"],
            "source": "Same source",
            "translation": "Eski",
        }
    ]


def test_missing_old_translation_is_not_a_rename_candidate(module) -> None:
    report = module.build_report(
        {"old": "Same source"},
        {"new": "Same source"},
        {},
        "tr_TR",
        "historical-ref",
    )
    assert report["counts"]["exactValueRenameCandidates"] == 0
    assert report["exactValueRenameCandidates"] == []


def test_locale_path_validation(module) -> None:
    with tempfile.TemporaryDirectory() as tmp_name:
        root = Path(tmp_name)
        (root / "tr_TR.json").write_text("{}\n", encoding="utf-8")
        assert module.locale_path(root, "tr_TR") == root / "tr_TR.json"

        try:
            module.locale_path(root, "../outside")
        except ValueError as exc:
            assert "invalid locale name" in str(exc)
        else:
            raise AssertionError("path-like locale escaped locale-name validation")

        try:
            module.locale_path(root, "zz_ZZ")
        except ValueError as exc:
            assert "unknown locale" in str(exc)
        else:
            raise AssertionError("missing locale was accepted")


def main() -> int:
    module = load_module()
    test_provenance_classification(module)
    test_duplicate_exact_source_candidates(module)
    test_missing_old_translation_is_not_a_rename_candidate(module)
    test_locale_path_validation(module)
    print("PASS: locale drift provenance classification is deterministic and non-destructive")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
