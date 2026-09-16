#!/usr/bin/env python3
"""Regression coverage for static translation literal decoding."""

import importlib.util
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANAGER_PATH = ROOT / "translations" / "tools" / "translation-manager.py"


def load_manager_module():
    spec = importlib.util.spec_from_file_location("translation_manager", MANAGER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load translation manager: {MANAGER_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    module = load_manager_module()

    cases = {
        r"Café \u263A": "Café ☺",
        r"Emoji \uD83D\uDE00": "Emoji 😀",
        r"literal \\u263A": r"literal \u263A",
        r"piñata \x21": "piñata !",
        r"line\nnext": "line\nnext",
        r"bad \u12G4": r"bad \u12G4",
    }
    for raw, expected in cases.items():
        actual = module._decode_static_literal(raw)
        if actual != expected:
            raise AssertionError(
                f"literal decode mismatch for {raw!r}: {actual!r} != {expected!r}"
            )

    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        translations = tmp / "translations"
        source = tmp / "source"
        translations.mkdir()
        source.mkdir()
        (source / "Fixture.qml").write_text(
            r'''import QtQuick
Item {
    property string mixed: Translation.tr("Café \u263A")
    property string emoji: Translation.tr("Emoji \uD83D\uDE00")
    property string literalEscape: Translation.tr("literal \\u263A")
}
''',
            encoding="utf-8",
        )

        manager = module.TranslationManager(str(translations), str(source))
        extracted = manager.extract_translatable_texts()
        expected_keys = {"Café ☺", "Emoji 😀", r"literal \u263A"}
        if extracted != expected_keys:
            raise AssertionError(
                f"unexpected extracted keys: {sorted(extracted)!r} != {sorted(expected_keys)!r}"
            )

    print("ok - translation extraction preserves real Unicode while decoding escapes")


if __name__ == "__main__":
    main()
