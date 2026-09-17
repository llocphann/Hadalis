#!/usr/bin/env python3
"""English-only translation catalog validator."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

TRANSLATIONS_DIR = Path(__file__).resolve().parents[1]
CANONICAL = TRANSLATIONS_DIR / "en_US.json"


def audit_all() -> int:
    catalogs = sorted(path.name for path in TRANSLATIONS_DIR.glob("*.json"))
    if catalogs != ["en_US.json"]:
        raise SystemExit(
            "English-only translation contract violated: expected only "
            f"en_US.json, found {catalogs!r}"
        )

    data = json.loads(CANONICAL.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit("translations/en_US.json must contain a JSON object")

    empty_keys = [key for key in data if not isinstance(key, str) or not key]
    if empty_keys:
        raise SystemExit(f"English catalog contains empty/non-string keys: {empty_keys[:10]!r}")

    invalid_values = [key for key, value in data.items() if not isinstance(value, str)]
    if invalid_values:
        raise SystemExit(
            f"English catalog contains non-string values for: {invalid_values[:10]!r}"
        )

    print(f"English catalog OK: {len(data)} entries")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["audit-all"])
    args = parser.parse_args()
    if args.command == "audit-all":
        return audit_all()
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
