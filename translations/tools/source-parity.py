#!/usr/bin/env python3
"""Compare live Translation.tr(...) callsites with the canonical English catalog.

The source extractor is intentionally reused from translation-manager.py so
catalog maintenance and CI cannot silently disagree about what counts as a
static translation key.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "translations" / "tools"
TRANSLATIONS = ROOT / "translations"
SOURCE = TRANSLATIONS / "en_US.json"
MANAGER_PATH = TOOLS / "translation-manager.py"


def load_manager_class() -> type[Any]:
    spec = importlib.util.spec_from_file_location(
        "hadalis_translation_manager",
        MANAGER_PATH,
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load translation manager: {MANAGER_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.TranslationManager


def load_catalog() -> dict[str, str]:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or not all(
        isinstance(key, str) and isinstance(value, str)
        for key, value in data.items()
    ):
        raise ValueError(f"{SOURCE} must contain a string-to-string JSON object")
    return data


def build_report() -> dict[str, Any]:
    manager_class = load_manager_class()
    manager = manager_class(str(TRANSLATIONS), str(ROOT))
    live_keys = manager.extract_translatable_texts()
    catalog = load_catalog()
    catalog_keys = set(catalog)
    kept_orphans = {
        key
        for key in catalog_keys - live_keys
        if catalog[key].strip().endswith("/*keep*/")
    }
    orphans = catalog_keys - live_keys - kept_orphans
    return {
        "liveKeys": len(live_keys),
        "catalogKeys": len(catalog_keys),
        "missing": sorted(live_keys - catalog_keys),
        "orphans": sorted(orphans),
        "keptOrphans": sorted(kept_orphans),
    }


def print_report(report: dict[str, Any]) -> None:
    print(f"live translation keys: {report['liveKeys']}")
    print(f"English catalog keys: {report['catalogKeys']}")
    print(f"missing live keys: {len(report['missing'])}")
    for key in report["missing"]:
        print(f"  MISSING: {key}")
    print(f"orphan catalog keys: {len(report['orphans'])}")
    for key in report["orphans"]:
        print(f"  ORPHAN: {key}")
    print(f"kept orphan keys: {len(report['keptOrphans'])}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--strict-orphans",
        action="store_true",
        help="also fail when unmarked English keys have no live static callsite",
    )
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()

    report = build_report()
    if args.as_json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print_report(report)

    invalid = bool(report["missing"])
    if args.strict_orphans and report["orphans"]:
        invalid = True
    return 1 if invalid else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"source-parity: {exc}", file=sys.stderr)
        raise SystemExit(2)
