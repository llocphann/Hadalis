#!/usr/bin/env python3
"""Audit a locale against both a historical and the current English schema.

This tool is intentionally read-only. It helps reviewers distinguish locale
entries that came from an older canonical schema from truly foreign extras,
and identifies exact-source rename candidates without deleting or rewriting
translations.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TRANSLATIONS = ROOT / "translations"
CANONICAL_NAME = "en_US.json"
LOCALE_RE = re.compile(r"^[A-Za-z]{2,3}_[A-Za-z]{2,3}$")


def load_catalog(path: Path) -> dict[str, str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or not all(
        isinstance(key, str) and isinstance(value, str)
        for key, value in data.items()
    ):
        raise ValueError(f"{path} must contain a string-to-string JSON object")
    return data


def locale_path(translations_dir: Path, locale: str) -> Path:
    if not LOCALE_RE.fullmatch(locale):
        raise ValueError(f"invalid locale name: {locale!r}")
    path = translations_dir / f"{locale}.json"
    if not path.is_file():
        raise ValueError(f"unknown locale: {locale}")
    return path


def load_historical_catalog(ref: str, translations_dir: Path) -> dict[str, str]:
    try:
        relative = translations_dir.resolve().relative_to(ROOT.resolve())
    except ValueError as exc:
        raise ValueError(
            "--translations-dir must be inside the repository when --historical-ref is used"
        ) from exc

    object_name = f"{ref}:{relative.as_posix()}/{CANONICAL_NAME}"
    proc = subprocess.run(
        ["git", "-C", str(ROOT), "show", object_name],
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        detail = proc.stderr.strip() or f"git show exited {proc.returncode}"
        raise RuntimeError(f"cannot read historical catalog {object_name}: {detail}")

    data = json.loads(proc.stdout)
    if not isinstance(data, dict) or not all(
        isinstance(key, str) and isinstance(value, str)
        for key, value in data.items()
    ):
        raise ValueError(f"historical catalog {object_name} must be a string-to-string JSON object")
    return data


def exact_value_rename_candidates(
    historical: dict[str, str],
    current: dict[str, str],
    locale: dict[str, str],
    old_keys: set[str],
    added: set[str],
) -> list[dict[str, Any]]:
    """Return review-only exact-source candidates backed by a locale translation.

    ``old_keys`` must be keys that are both retired from the current canonical
    schema and still present in the locale. A retired canonical key that the
    locale never translated cannot yield anything useful to migrate and is not
    reported as a candidate.
    """
    added_by_value: dict[str, list[str]] = defaultdict(list)
    for key in added:
        added_by_value[current[key]].append(key)

    candidates: list[dict[str, Any]] = []
    for old_key in sorted(old_keys):
        new_keys = sorted(added_by_value.get(historical[old_key], []))
        if not new_keys:
            continue
        candidates.append(
            {
                "from": old_key,
                "to": new_keys,
                "source": historical[old_key],
                "translation": locale[old_key],
            }
        )
    return candidates


def build_report(
    historical: dict[str, str],
    current: dict[str, str],
    locale: dict[str, str],
    locale_name: str,
    historical_ref: str,
) -> dict[str, Any]:
    historical_keys = set(historical)
    current_keys = set(current)
    locale_keys = set(locale)

    retained = historical_keys & current_keys
    retired = historical_keys - current_keys
    added = current_keys - historical_keys
    missing = current_keys - locale_keys
    extras = locale_keys - current_keys

    historical_extras = extras & historical_keys
    foreign_extras = extras - historical_keys
    missing_added = missing & added
    missing_retained = missing & retained
    retained_source_changed = {
        key for key in retained if historical[key] != current[key]
    }

    candidates = exact_value_rename_candidates(
        historical,
        current,
        locale,
        historical_extras,
        added,
    )
    candidate_from = {item["from"] for item in candidates}

    retired_entries = []
    for key in sorted(historical_extras):
        retired_entries.append(
            {
                "key": key,
                "source": historical[key],
                "translation": locale[key],
                "hasExactRenameCandidate": key in candidate_from,
            }
        )

    changed_entries = [
        {
            "key": key,
            "historicalSource": historical[key],
            "currentSource": current[key],
            "translation": locale.get(key),
            "localeHasKey": key in locale,
        }
        for key in sorted(retained_source_changed)
    ]

    return {
        "locale": locale_name,
        "historicalRef": historical_ref,
        "counts": {
            "historicalCanonical": len(historical_keys),
            "currentCanonical": len(current_keys),
            "locale": len(locale_keys),
            "retainedCanonical": len(retained),
            "retiredCanonical": len(retired),
            "addedCanonical": len(added),
            "retainedSourceChanged": len(retained_source_changed),
            "missing": len(missing),
            "extras": len(extras),
            "historicalExtras": len(historical_extras),
            "foreignExtras": len(foreign_extras),
            "missingAddedSinceSnapshot": len(missing_added),
            "missingRetainedFromSnapshot": len(missing_retained),
            "exactValueRenameCandidates": len(candidates),
        },
        "missingAddedSinceSnapshot": sorted(missing_added),
        "missingRetainedFromSnapshot": sorted(missing_retained),
        "retainedSourceChanged": changed_entries,
        "historicalExtras": retired_entries,
        "foreignExtras": sorted(foreign_extras),
        "exactValueRenameCandidates": candidates,
    }


def print_report(report: dict[str, Any]) -> None:
    counts = report["counts"]
    print(f"locale: {report['locale']}")
    print(f"historical ref: {report['historicalRef']}")
    print(
        "canonical keys: "
        f"{counts['historicalCanonical']} historical -> {counts['currentCanonical']} current"
    )
    print(
        "locale drift: "
        f"{counts['missing']} missing, {counts['extras']} extras "
        f"({counts['historicalExtras']} historical, {counts['foreignExtras']} foreign)"
    )
    print(
        "missing provenance: "
        f"{counts['missingAddedSinceSnapshot']} added since snapshot, "
        f"{counts['missingRetainedFromSnapshot']} retained from snapshot"
    )
    print(f"retained keys with changed source: {counts['retainedSourceChanged']}")
    print(f"exact-source rename candidates: {counts['exactValueRenameCandidates']}")

    for item in report["exactValueRenameCandidates"]:
        targets = ", ".join(item["to"])
        print(f"  RENAME?: {item['from']} -> {targets}")
    for item in report["retainedSourceChanged"]:
        state = "translated" if item["localeHasKey"] else "missing"
        print(f"  SOURCE CHANGED ({state}): {item['key']}")
    for key in report["foreignExtras"]:
        print(f"  FOREIGN EXTRA: {key}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "locale",
        help="locale name without .json, for example tr_TR",
    )
    parser.add_argument(
        "--historical-ref",
        required=True,
        help="git ref whose en_US.json was used to generate the locale",
    )
    parser.add_argument(
        "--translations-dir",
        type=Path,
        default=DEFAULT_TRANSLATIONS,
        help=f"translation catalog directory (default: {DEFAULT_TRANSLATIONS})",
    )
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()

    translations_dir = args.translations_dir.resolve()
    current = load_catalog(translations_dir / CANONICAL_NAME)
    locale = load_catalog(locale_path(translations_dir, args.locale))
    historical = load_historical_catalog(args.historical_ref, translations_dir)
    report = build_report(
        historical,
        current,
        locale,
        args.locale,
        args.historical_ref,
    )

    if args.as_json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print_report(report)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"locale-drift: {exc}", file=sys.stderr)
        raise SystemExit(2)
