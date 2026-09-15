#!/usr/bin/env python3
"""Regression coverage for translation-cleaner mutation boundaries."""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CLEANER = ROOT / "translations" / "tools" / "translation-cleaner.py"


def run(*args: str, expect: int = 0) -> subprocess.CompletedProcess:
    result = subprocess.run(
        [sys.executable, str(CLEANER), *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != expect:
        raise AssertionError(
            f"command returned {result.returncode}, expected {expect}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        translations = tmp / "translations"
        source = tmp / "source"
        translations.mkdir()
        source.mkdir()

        en = {
            "Live": "Live",
            "Dynamic": "Dynamic",
            "Retired": "Retired",
            "Protected": "Protected /*keep*/",
        }
        fr = {
            "Live": "Actif",
            "Dynamic": "Dynamique",
            "Retired": "Retiré",
            "Protected": "Protégé",
        }
        write_json(translations / "en_US.json", en)
        write_json(translations / "fr_FR.json", fr)
        (source / "Fixture.qml").write_text(
            'import QtQuick\nItem {\n'
            '    property string live: Translation.tr("Live")\n'
            '    property string dynamicKey: "Dynamic"\n'
            '    property string dynamicValue: Translation.tr(dynamicKey)\n'
            '}\n',
            encoding="utf-8",
        )

        before_en = (translations / "en_US.json").read_bytes()
        before_fr = (translations / "fr_FR.json").read_bytes()
        clean = run(
            "--translations-dir", str(translations),
            "--source-dir", str(source),
            "--clean",
            "--yes",
        )
        if "No files changed" not in clean.stdout:
            raise AssertionError("read-only cleanup did not report its mutation boundary")
        if (translations / "en_US.json").read_bytes() != before_en:
            raise AssertionError("--clean mutated the canonical catalog")
        if (translations / "fr_FR.json").read_bytes() != before_fr:
            raise AssertionError("--clean mutated a target locale")

        prune_file = tmp / "reviewed.json"
        prune_file.write_text('["Retired"]\n', encoding="utf-8")
        run(
            "--translations-dir", str(translations),
            "--source-dir", str(source),
            "--prune-file", str(prune_file),
            "--yes",
            "--no-backup",
        )
        for locale in ("en_US", "fr_FR"):
            data = read_json(translations / f"{locale}.json")
            if "Retired" in data:
                raise AssertionError(f"exact prune did not remove Retired from {locale}")
            if set(data) != {"Live", "Dynamic", "Protected"}:
                raise AssertionError(f"exact prune changed unrelated keys in {locale}")

        protected_before = {
            locale: (translations / f"{locale}.json").read_bytes()
            for locale in ("en_US", "fr_FR")
        }
        rejected = run(
            "--translations-dir", str(translations),
            "--source-dir", str(source),
            "--prune-key", "Protected",
            "--yes",
            "--no-backup",
            expect=2,
        )
        if "protected" not in rejected.stderr.lower() and "protected" not in rejected.stdout.lower():
            raise AssertionError("protected-key refusal was not explained")
        for locale, original in protected_before.items():
            if (translations / f"{locale}.json").read_bytes() != original:
                raise AssertionError(f"rejected protected prune mutated {locale}")

    print("ok - translation cleaner requires reviewed exact keys for deletion")


if __name__ == "__main__":
    main()
