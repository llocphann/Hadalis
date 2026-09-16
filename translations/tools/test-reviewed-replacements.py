#!/usr/bin/env python3
"""Regression tests for fail-closed reviewed locale replacements."""

from __future__ import annotations

import importlib.util
import json
import tempfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
MODULE_PATH = TOOLS / "apply-reviewed-replacements.py"


def load_module():
    spec = importlib.util.spec_from_file_location(
        "hadalis_apply_reviewed_replacements", MODULE_PATH
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load reviewed replacement tool: {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_json(path: Path, data: object) -> None:
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def manifest_data(*, old: str, new: str) -> dict[str, object]:
    key = "Usage: install-package <package-name>"
    return {
        "locale": "tr_TR",
        "replacements": {
            key: {
                "from": old,
                "to": new,
            }
        },
    }


def fixture(root: Path, *, target_value: str, replacement_value: str) -> tuple[Path, Path]:
    translations = root / "translations"
    translations.mkdir()
    key = "Usage: install-package <package-name>"
    write_json(
        translations / "en_US.json",
        {
            key: key,
            "Unrelated": "Unrelated",
        },
    )
    write_json(
        translations / "tr_TR.json",
        {
            key: target_value,
            "Unrelated": "İlgisiz",
        },
    )
    manifest = root / "reviewed.json"
    write_json(
        manifest,
        manifest_data(old=target_value, new=replacement_value),
    )
    return translations, manifest


def test_exact_reviewed_replacement(module) -> None:
    old = "Kullanım: install-package <paket-adı>"
    new = "Kullanım: install-package <package-name>"
    with tempfile.TemporaryDirectory() as tmp_name:
        root = Path(tmp_name)
        translations, manifest = fixture(
            root,
            target_value=old,
            replacement_value=new,
        )

        locale, state, count = module.reviewed_manifest_state(manifest, translations)
        assert (locale, state, count) == ("tr_TR", "pending", 1)
        assert module.apply_manifest(
            manifest,
            translations,
            backup=False,
            check_only=True,
        ) == 1
        assert module.apply_manifest(
            manifest,
            translations,
            backup=False,
            check_only=False,
        ) == 1

        updated = json.loads((translations / "tr_TR.json").read_text(encoding="utf-8"))
        assert updated["Usage: install-package <package-name>"] == new
        assert updated["Unrelated"] == "İlgisiz"
        assert not (translations / "tr_TR.json.bak").exists()
        locale, state, count = module.reviewed_manifest_state(manifest, translations)
        assert (locale, state, count) == ("tr_TR", "applied", 1)


def test_catalog_drift_is_rejected(module) -> None:
    old = "Kullanım: install-package <paket-adı>"
    new = "Kullanım: install-package <package-name>"
    with tempfile.TemporaryDirectory() as tmp_name:
        root = Path(tmp_name)
        translations, manifest = fixture(
            root,
            target_value=old,
            replacement_value=new,
        )
        target = translations / "tr_TR.json"
        data = json.loads(target.read_text(encoding="utf-8"))
        data["Usage: install-package <package-name>"] = "Başka bir değer <paket-adı>"
        write_json(target, data)

        try:
            module.reviewed_manifest_state(manifest, translations)
        except ValueError as exc:
            assert "drifted" in str(exc)
        else:
            raise AssertionError("reviewed replacement accepted an unreviewed catalog value")


def test_placeholder_contract_is_rejected(module) -> None:
    old = "Kullanım: install-package <paket-adı>"
    unsafe = "Kullanım: install-package"
    with tempfile.TemporaryDirectory() as tmp_name:
        root = Path(tmp_name)
        translations, manifest = fixture(
            root,
            target_value=old,
            replacement_value=unsafe,
        )

        try:
            module.reviewed_manifest_state(manifest, translations)
        except ValueError as exc:
            assert "placeholder/markup contract" in str(exc)
        else:
            raise AssertionError("reviewed replacement accepted a missing placeholder")


def test_partial_application_is_rejected(module) -> None:
    first_key = "Usage: install-package <package-name>"
    second_key = "Usage: remove-package <package-name>"
    with tempfile.TemporaryDirectory() as tmp_name:
        root = Path(tmp_name)
        translations = root / "translations"
        translations.mkdir()
        write_json(
            translations / "en_US.json",
            {first_key: first_key, second_key: second_key},
        )
        write_json(
            translations / "tr_TR.json",
            {
                first_key: "Kullanım: install-package <package-name>",
                second_key: "Kullanım: remove-package <paket-adı>",
            },
        )
        manifest = root / "reviewed.json"
        write_json(
            manifest,
            {
                "locale": "tr_TR",
                "replacements": {
                    first_key: {
                        "from": "Kullanım: install-package <paket-adı>",
                        "to": "Kullanım: install-package <package-name>",
                    },
                    second_key: {
                        "from": "Kullanım: remove-package <paket-adı>",
                        "to": "Kullanım: remove-package <package-name>",
                    },
                },
            },
        )

        try:
            module.reviewed_manifest_state(manifest, translations)
        except ValueError as exc:
            assert "partially applied" in str(exc)
        else:
            raise AssertionError("reviewed replacement accepted a partially applied manifest")


def test_live_reviewed_manifest_state(module) -> None:
    translations = TOOLS.parent
    manifest_path = translations / "l10n" / "tr_TR-placeholder-repairs.json"
    locale, state, count = module.reviewed_manifest_state(manifest_path, translations)
    assert locale == "tr_TR"
    assert state in {"pending", "applied"}
    assert count > 0


def main() -> int:
    module = load_module()
    test_exact_reviewed_replacement(module)
    test_catalog_drift_is_rejected(module)
    test_placeholder_contract_is_rejected(module)
    test_partial_application_is_rejected(module)
    test_live_reviewed_manifest_state(module)
    print("PASS: reviewed locale replacements are exact, preserving, and fail-closed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
