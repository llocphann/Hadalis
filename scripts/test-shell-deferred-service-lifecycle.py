#!/usr/bin/env python3
"""Regression contract for demand-driven Tier-3 optional services."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SHELL = ROOT / "shell.qml"


def main() -> int:
    text = SHELL.read_text(encoding="utf-8")

    required = (
        "function _ensureCavaThemeService(): void",
        "GlobalStates.deferredPanelsReady",
        "Config.options?.appearance?.wallpaperTheming?.enableCava ?? false",
        "root._cavaThemeService = CavaTheme",
        "root._ensureCavaThemeService();",
    )
    for needle in required:
        if needle not in text:
            raise AssertionError(f"shell optional-service contract missing: {needle}")

    tier = re.search(
        r'id: deferredInitTimer(?P<body>.*?)\n\s*\}\n\n\s*Connections',
        text,
        flags=re.S,
    )
    if not tier:
        raise AssertionError("could not isolate Tier-3 deferred init")
    body = tier.group("body")
    if "root._cavaThemeService = CavaTheme;" in body:
        raise AssertionError("Tier 3 must not eagerly instantiate disabled CavaTheme")
    if body.find("GlobalStates.deferredPanelsReady = true;") > body.find("root._ensureCavaThemeService();"):
        raise AssertionError("Cava demand gate must run after deferred services become eligible")

    config = re.search(
        r"Connections \{\s*\n\s*target: Config(?P<body>.*?)\n\s*\}",
        text,
        flags=re.S,
    )
    if not config or "root._ensureCavaThemeService()" not in config.group("body"):
        raise AssertionError("config changes must activate CavaTheme when enabled later")

    print("shell deferred service lifecycle contract: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
