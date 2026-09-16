#!/usr/bin/env python3
"""Apply explicitly reviewed locale-value replacements fail-closed.

Each manifest entry records the exact catalog value reviewed as `from` and the
intended replacement as `to`. The operation aborts if the locale drifted, if a
key is absent from the canonical catalog, or if the replacement violates the
canonical placeholder/markup contract.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
TRANSLATIONS = ROOT / "translations"
L10N_PATH = Path(__file__).with_name("l10n.py")
LOCALE_RE = re.compile(r"^[A-Za-z]{2,3}_[A-Za-z]{2,3}$")


def _load_l10n():
    spec = importlib.util.spec_from_file_location("l10n_for_reviewed_replacements", L10N_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load l10n helper: {L10N_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _read_text_preserving_newlines(path: Path) -> str:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return handle.read()


def _write_text_atomic(path: Path, text: str) -> None:
    fd, tmp_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        tmp_path.chmod(path.stat().st_mode & 0o7777)
        os.replace(tmp_path, path)
    except BaseException:
        try:
            tmp_path.unlink(missing_ok=True)
        finally:
            raise


def _json_literal(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def _render_reviewed_replacements(
    target_path: Path,
    replacements: dict[str, dict[str, str]],
) -> str:
    text = _read_text_preserving_newlines(target_path)

    for key, replacement in replacements.items():
        key_literal = _json_literal(key)
        old_literal = _json_literal(replacement["from"])
        new_literal = _json_literal(replacement["to"])
        pattern = re.compile(
            rf"(?P<prefix>{re.escape(key_literal)}[\t\r\n ]*:[\t\r\n ]*)"
            rf"{re.escape(old_literal)}"
        )
        matches = list(pattern.finditer(text))
        if len(matches) != 1:
            raise ValueError(
                f"catalog serialization drifted for {key!r}; expected exactly one "
                f"reviewed key/value literal, found {len(matches)}"
            )
        text = pattern.sub(
            lambda match: f"{match.group('prefix')}{new_literal}",
            text,
            count=1,
        )

    parsed = json.loads(text)
    if not isinstance(parsed, dict):
        raise ValueError("updated catalog must remain a JSON object")
    for key, replacement in replacements.items():
        if parsed.get(key) != replacement["to"]:
            raise ValueError(f"failed to render reviewed replacement for {key!r}")

    return text


def load_manifest(path: Path) -> tuple[str, dict[str, dict[str, str]]]:
    data = _load_json(path)
    if not isinstance(data, dict):
        raise ValueError("replacement manifest must be a JSON object")

    locale = data.get("locale")
    replacements = data.get("replacements")
    if not isinstance(locale, str) or not LOCALE_RE.fullmatch(locale):
        raise ValueError("replacement manifest has an invalid locale")
    if locale == "en_US":
        raise ValueError("reviewed replacements cannot target the canonical locale")
    if not isinstance(replacements, dict) or not replacements:
        raise ValueError("replacement manifest must contain replacements")

    normalized: dict[str, dict[str, str]] = {}
    for key, entry in replacements.items():
        if not isinstance(key, str) or not key:
            raise ValueError("replacement manifest contains an empty/non-string key")
        if not isinstance(entry, dict) or set(entry) != {"from", "to"}:
            raise ValueError(f"replacement for {key!r} must contain exactly from/to")
        old = entry.get("from")
        new = entry.get("to")
        if not isinstance(old, str) or not isinstance(new, str) or not new:
            raise ValueError(f"replacement for {key!r} has invalid from/to values")
        if old == new:
            raise ValueError(f"replacement for {key!r} is a no-op")
        normalized[key] = {"from": old, "to": new}

    return locale, normalized


def _inspect_manifest(
    manifest_path: Path,
    translations_dir: Path = TRANSLATIONS,
) -> tuple[str, dict[str, dict[str, str]], Path, dict[str, str], str]:
    locale, replacements = load_manifest(manifest_path)
    source_path = translations_dir / "en_US.json"
    target_path = translations_dir / f"{locale}.json"
    if not source_path.is_file():
        raise ValueError(f"canonical catalog missing: {source_path}")
    if not target_path.is_file():
        raise ValueError(f"target catalog missing: {target_path}")

    source = _load_json(source_path)
    target = _load_json(target_path)
    if not isinstance(source, dict) or not isinstance(target, dict):
        raise ValueError("catalogs must be JSON objects")

    l10n = _load_l10n()
    states: set[str] = set()
    for key, replacement in replacements.items():
        if key not in source:
            raise ValueError(f"reviewed replacement key absent from en_US: {key!r}")
        if key not in target:
            raise ValueError(f"reviewed replacement key absent from {locale}: {key!r}")
        if not l10n.placeholders_match(source[key], replacement["to"]):
            raise ValueError(
                f"reviewed replacement violates placeholder/markup contract for {key!r}"
            )

        current = target[key]
        if current == replacement["from"]:
            states.add("pending")
        elif current == replacement["to"]:
            states.add("applied")
        else:
            raise ValueError(
                f"{locale} drifted for {key!r}; expected reviewed from/to values "
                f"{replacement['from']!r} or {replacement['to']!r}, found {current!r}"
            )

    if len(states) != 1:
        raise ValueError(
            f"{locale} reviewed replacement manifest is partially applied: {sorted(states)}"
        )

    return locale, replacements, target_path, target, states.pop()


def reviewed_manifest_state(
    manifest_path: Path,
    translations_dir: Path = TRANSLATIONS,
) -> tuple[str, str, int]:
    locale, replacements, _target_path, _target, state = _inspect_manifest(
        manifest_path, translations_dir
    )
    return locale, state, len(replacements)


def apply_manifest(
    manifest_path: Path,
    translations_dir: Path = TRANSLATIONS,
    *,
    backup: bool = True,
    check_only: bool = False,
) -> int:
    locale, replacements, target_path, _target, state = _inspect_manifest(
        manifest_path, translations_dir
    )
    if state != "pending":
        raise ValueError(f"{locale}: reviewed replacements are already applied")

    # Render before honoring --check so a dry-run validates the exact serialized
    # key/value literals that a byte-preserving apply must replace, not only the
    # equivalent values produced by json.load().
    updated_text = _render_reviewed_replacements(target_path, replacements)

    if check_only:
        print(f"ok - {locale}: {len(replacements)} reviewed replacements are applicable")
        return len(replacements)

    if backup:
        backup_path = target_path.with_suffix(target_path.suffix + ".bak")
        shutil.copy2(target_path, backup_path)
        print(f"Created backup: {backup_path}")

    _write_text_atomic(target_path, updated_text)
    print(f"{locale}: applied {len(replacements)} reviewed replacements")
    return len(replacements)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path, help="reviewed replacement manifest")
    parser.add_argument(
        "--translations-dir",
        type=Path,
        default=TRANSLATIONS,
        help="catalog directory (default: repository translations/)",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="validate pending replacements without writing")
    mode.add_argument("--status", action="store_true", help="report pending/applied state without writing")
    parser.add_argument("--no-backup", action="store_true", help="do not create .bak")
    args = parser.parse_args()

    if args.status:
        locale, state, count = reviewed_manifest_state(args.manifest, args.translations_dir)
        print(f"{locale}: {state} ({count} reviewed replacements)")
        return 0

    apply_manifest(
        args.manifest,
        args.translations_dir,
        backup=not args.no_backup,
        check_only=args.check,
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
        print(f"apply-reviewed-replacements: {exc}", file=sys.stderr)
        raise SystemExit(2)
