#!/usr/bin/env python3
"""Regression contract for the v1.0 Material-only global style boundary."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THEME_SERVICE = ROOT / "services" / "ThemeService.qml"


def require(text: str, token: str) -> None:
    if token not in text:
        raise AssertionError(f"ThemeService.qml is missing required Material-only contract token: {token!r}")


def forbid(text: str, token: str) -> None:
    if token in text:
        raise AssertionError(f"ThemeService.qml still contains retired global-style routing: {token!r}")


def main() -> None:
    text = THEME_SERVICE.read_text(encoding="utf-8")

    for token in (
        'readonly property string supportedGlobalStyle: "material"',
        'function normalizeGlobalStyle(): void',
        'Config.setNestedValue("appearance.globalStyle", root.supportedGlobalStyle)',
        'function setGlobalStyle(styleId: string): void',
        'if (styleId !== root.supportedGlobalStyle)',
        'root.normalizeGlobalStyle()',
    ):
        require(text, token)

    # The compatibility setter may remain for old callers, but it must never
    # persist the requested legacy style or resurrect per-style shell geometry.
    for token in (
        '"appearance.globalStyle": styleId',
        'const cards = styleId === "cards"',
        'case "cards":',
        'case "aurora":',
        'case "inir":',
        'case "angel":',
        'case "regalia":',
        'case "zzz":',
        'case "cookie":',
    ):
        forbid(text, token)

    print("Material-only global style contract: PASS")


if __name__ == "__main__":
    main()
