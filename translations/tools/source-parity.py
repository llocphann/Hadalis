#!/usr/bin/env python3
"""Validate the canonical English translation catalog contract."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "translations" / "en_US.json"


def main() -> int:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit("translations/en_US.json must contain a JSON object")

    empty_keys = [key for key in data if not isinstance(key, str) or not key]
    invalid_values = [key for key, value in data.items() if not isinstance(value, str)]
    if empty_keys:
        raise SystemExit(f"English catalog contains empty/non-string keys: {empty_keys[:10]!r}")
    if invalid_values:
        raise SystemExit(f"English catalog contains non-string values for: {invalid_values[:10]!r}")

    print(f"English source catalog OK: {len(data)} entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
