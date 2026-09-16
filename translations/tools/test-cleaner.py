#!/usr/bin/env python3
"""Regression coverage for translation cleanup and source-parity boundaries."""

import importlib.util
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CLEANER = ROOT / "translations" / "tools" / "translation-cleaner.py"
PARITY = ROOT / "translations" / "tools" / "source-parity.py"
MANAGER = ROOT / "translations" / "tools" / "translation-manager.py"
L10N_TOOL = ROOT / "translations" / "tools" / "l10n.py"
REPLACEMENTS_TOOL = ROOT / "translations" / "tools" / "apply-reviewed-replacements.py"
AUTO_TRANSLATE = ROOT / "translations" / "tools" / "auto-translate.js"
TRANSLATIONS = ROOT / "translations"
REVIEWED_PRUNE = ROOT / "translations" / "l10n" / "retired-shell-prune.json"
TURKISH_PLACEHOLDER_REPAIRS = ROOT / "translations" / "l10n" / "tr_TR-placeholder-repairs.json"


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


def run_parity(*args: str, expect: int = 0) -> subprocess.CompletedProcess:
    result = subprocess.run(
        [sys.executable, str(PARITY), *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != expect:
        raise AssertionError(
            f"source parity returned {result.returncode}, expected {expect}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result


def run_replacements(*args: str, expect: int = 0) -> subprocess.CompletedProcess:
    result = subprocess.run(
        [sys.executable, str(REPLACEMENTS_TOOL), *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != expect:
        raise AssertionError(
            f"reviewed replacement command returned {result.returncode}, expected {expect}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def load_python_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load Python module: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_manager_class():
    return load_python_module(
        MANAGER, "translation_manager_for_cleaner_test"
    ).TranslationManager


def assert_placeholder_contract() -> None:
    l10n = load_python_module(L10N_TOOL, "l10n_for_cleaner_test")

    accepted = [
        (
            "Matches shell surfaces at 50%.",
            "Kabuk yüzeyleriyle %50'de eşleşir.",
        ),
        (
            "100% default; scale 80% - 150%; pavucontrol allows 153%.",
            "%100 varsayılan; ölçek %80 - %150; pavucontrol %153'e izin verir.",
        ),
        (
            "Qt slot %50 at 50%.",
            "Qt yuvası %50, yüzde %50.",
        ),
        (
            "Use <tt>%1superpaste</tt>.",
            "<tt>%1superpaste</tt> kullanın.",
        ),
    ]
    for source, target in accepted:
        if not l10n.placeholders_match(source, target):
            raise AssertionError(
                f"valid localized placeholder/percentage structure was rejected: {source!r} -> {target!r}"
            )

    rejected = [
        ("Usage: install-package <package-name>", "Kullanım: install-package <paket-adı>"),
        ("Qt slot %50", "Qt yuvası %51"),
        ("Value %1", "Değer %2"),
    ]
    for source, target in rejected:
        if l10n.placeholders_match(source, target):
            raise AssertionError(
                f"placeholder mutation was accepted: {source!r} -> {target!r}"
            )


def assert_auto_translate_contract() -> None:
    script = AUTO_TRANSLATE.read_text(encoding="utf-8")
    mapped_locales = set(
        re.findall(r"'([A-Za-z0-9_-]+\.json)'\s*:\s*'[^']+'", script)
    )
    tracked_locales = {
        path.name
        for path in TRANSLATIONS.glob("*.json")
        if path.name != "en_US.json"
    }

    if mapped_locales != tracked_locales:
        missing = sorted(tracked_locales - mapped_locales)
        stale = sorted(mapped_locales - tracked_locales)
        raise AssertionError(
            "auto-translate locale map drifted from tracked catalog: "
            f"missing={missing}, stale={stale}"
        )

    retry_guard = "const maxBatchAttempts = 3;"
    placeholder_guard = "if (!samePlaceholders(sourceData[key], clean)) {"
    percent_contract = [
        "localizedPercentLiterals(source, false)",
        "localizedPercentLiterals(target, true)",
        r"%[1-9]\d?(?!\d)",
    ]
    if retry_guard not in script:
        raise AssertionError("auto-translate retry budget is no longer bounded at three attempts")
    if placeholder_guard not in script:
        raise AssertionError("auto-translate no longer validates placeholder structure")
    for marker in percent_contract:
        if marker not in script:
            raise AssertionError(
                f"auto-translate localized-percentage placeholder contract missing: {marker}"
            )

    guard_offset = script.index(placeholder_guard)
    checkpoint_offset = script.find("writeAtomic(filePath, data);", guard_offset)
    if checkpoint_offset < 0:
        raise AssertionError("auto-translate placeholder validation no longer precedes a checkpoint")


def assert_reviewed_prune_contract() -> None:
    """Keep the pending retired-shell prune set exact until it is applied/removed."""
    if not REVIEWED_PRUNE.exists():
        return

    reviewed = json.loads(REVIEWED_PRUNE.read_text(encoding="utf-8"))
    if not isinstance(reviewed, list) or not reviewed:
        raise AssertionError("retired-shell prune file must be a non-empty JSON array")
    if not all(isinstance(key, str) and key for key in reviewed):
        raise AssertionError("retired-shell prune file contains a non-string or empty key")
    if len(reviewed) != len(set(reviewed)):
        raise AssertionError("retired-shell prune file contains duplicate keys")

    reviewed_keys = set(reviewed)
    source_catalog = read_json(TRANSLATIONS / "en_US.json")
    unknown = reviewed_keys - set(source_catalog)
    if unknown:
        raise AssertionError(
            f"reviewed prune keys are absent from en_US: {sorted(unknown)!r}"
        )

    protected = {
        key
        for key in reviewed_keys
        if source_catalog[key].strip().endswith("/*keep*/")
    }
    if protected:
        raise AssertionError(
            f"reviewed prune keys are protected by /*keep*/: {sorted(protected)!r}"
        )

    for locale_path in sorted(TRANSLATIONS.glob("*.json")):
        locale_catalog = read_json(locale_path)
        missing = reviewed_keys - set(locale_catalog)
        if missing:
            raise AssertionError(
                f"{locale_path.name} is missing reviewed prune keys: {sorted(missing)!r}"
            )

    manager_class = load_manager_class()
    manager = manager_class(str(TRANSLATIONS), str(ROOT))
    live_static_keys = manager.extract_translatable_texts()
    still_live = reviewed_keys & live_static_keys
    if still_live:
        raise AssertionError(
            "reviewed retired-shell keys still have static Translation.tr callsites: "
            f"{sorted(still_live)!r}"
        )


def assert_reviewed_replacement_contract() -> None:
    checked = run_replacements(
        str(TURKISH_PLACEHOLDER_REPAIRS),
        "--translations-dir",
        str(TRANSLATIONS),
        "--check",
    )
    if "3 reviewed replacements are applicable" not in checked.stdout:
        raise AssertionError("Turkish reviewed replacement manifest did not validate")

    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        translations = tmp / "translations"
        translations.mkdir()
        source_value = "Usage: install-package <package-name>"
        old_value = "Kullanım: install-package <paket-adı>"
        new_value = "Kullanım: install-package <package-name>"
        write_json(translations / "en_US.json", {source_value: source_value, "Keep": "Keep"})
        write_json(translations / "tr_TR.json", {source_value: old_value, "Keep": "Koru"})
        manifest = tmp / "repairs.json"
        write_json(
            manifest,
            {
                "locale": "tr_TR",
                "replacements": {
                    source_value: {"from": old_value, "to": new_value},
                },
            },
        )

        run_replacements(
            str(manifest),
            "--translations-dir",
            str(translations),
            "--no-backup",
        )
        repaired = read_json(translations / "tr_TR.json")
        if repaired != {source_value: new_value, "Keep": "Koru"}:
            raise AssertionError(f"reviewed replacement changed unrelated data: {repaired!r}")

        stale = run_replacements(
            str(manifest),
            "--translations-dir",
            str(translations),
            "--no-backup",
            expect=2,
        )
        if "drifted" not in stale.stderr:
            raise AssertionError("stale reviewed replacement did not fail closed")


def main() -> None:
    assert_placeholder_contract()
    assert_auto_translate_contract()
    assert_reviewed_prune_contract()
    assert_reviewed_replacement_contract()

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

        parity = run_parity(
            "--translations-dir", str(translations),
            "--source-dir", str(source),
            "--json",
        )
        report = json.loads(parity.stdout)
        if report["missing"] != []:
            raise AssertionError(f"unexpected missing source keys: {report['missing']}")
        if report["orphans"] != ["Dynamic", "Retired"]:
            raise AssertionError(f"unexpected orphan report: {report['orphans']}")
        if report["keptOrphans"] != ["Protected"]:
            raise AssertionError(f"keep marker was not honored: {report['keptOrphans']}")

        run_parity(
            "--translations-dir", str(translations),
            "--source-dir", str(source),
            "--strict-orphans",
            expect=1,
        )

        missing_fixture = source / "Missing.qml"
        missing_fixture.write_text(
            'import QtQuick\nItem { property string missing: Translation.tr("Missing") }\n',
            encoding="utf-8",
        )
        missing = run_parity(
            "--translations-dir", str(translations),
            "--source-dir", str(source),
            "--json",
            expect=1,
        )
        missing_report = json.loads(missing.stdout)
        if missing_report["missing"] != ["Missing"]:
            raise AssertionError(f"missing live key was not reported: {missing_report['missing']}")
        missing_fixture.unlink()

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

        sync_translations = tmp / "sync-translations"
        sync_translations.mkdir()
        write_json(
            sync_translations / "en_US.json",
            {"Existing": "Existing", "Missing": "Missing"},
        )
        write_json(
            sync_translations / "fr_FR.json",
            {"Existing": "Existant", "Locale only": "Spécifique"},
        )
        sync = run(
            "--translations-dir", str(sync_translations),
            "--source-dir", str(source),
            "--sync",
            "--yes",
            "--no-backup",
        )
        synced_fr = read_json(sync_translations / "fr_FR.json")
        if synced_fr != {
            "Existing": "Existant",
            "Locale only": "Spécifique",
            "Missing": "Missing",
        }:
            raise AssertionError(
                f"additive sync changed existing/extra translations: {synced_fr!r}"
            )
        if "Preserving 1 locale-specific extra keys" not in sync.stdout:
            raise AssertionError("additive sync did not report preserved locale extras")
        if "Structural audit will continue to report them" not in sync.stdout:
            raise AssertionError("additive sync did not explain the remaining audit drift")

    print("ok - translation cleanup and source parity preserve reviewed boundaries")


if __name__ == "__main__":
    main()
