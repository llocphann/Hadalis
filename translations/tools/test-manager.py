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
        r"tick \` mark": "tick ` mark",
        r"money \$5": "money $5",
    }
    for raw, expected in cases.items():
        actual = module._decode_static_literal(raw)
        if actual != expected:
            raise AssertionError(
                f"literal decode mismatch for {raw!r}: {actual!r} != {expected!r}"
            )

    interpolation_cases = {
        r"Hello ${name}": True,
        r"Literal \${name}": False,
        r"Even \\${name}": True,
        r"Odd \\\${name}": False,
        "plain": False,
    }
    for raw, expected in interpolation_cases.items():
        actual = module._has_template_interpolation(raw)
        if actual != expected:
            raise AssertionError(
                f"template interpolation mismatch for {raw!r}: {actual!r} != {expected!r}"
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
    property string staticTemplate: Translation.tr(`static template`)
    property string dynamicTemplate: Translation.tr(`Hello ${name}`)
    property string escapedInterpolation: Translation.tr(`Literal \${name}`)
    property string escapedBacktick: Translation.tr(`tick \` mark`)
    property string paddedQuoted: Translation.tr("  padded quoted  ")
    property string paddedTemplate: Translation.tr(`  padded template  `)
}
''',
            encoding="utf-8",
        )

        manager = module.TranslationManager(str(translations), str(source))
        extracted = manager.extract_translatable_texts()
        expected_keys = {
            "Café ☺",
            "Emoji 😀",
            r"literal \u263A",
            "static template",
            "Literal ${name}",
            "tick ` mark",
            "  padded quoted  ",
            "  padded template  ",
        }
        if extracted != expected_keys:
            raise AssertionError(
                f"unexpected extracted keys: {sorted(extracted)!r} != {sorted(expected_keys)!r}"
            )

    print("ok - translation extraction preserves static literal semantics")


if __name__ == "__main__":
    main()
