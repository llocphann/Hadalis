#!/usr/bin/env python3
"""Regression contract for demand-driven deferred optional services."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SHELL = ROOT / "shell.qml"


def main() -> int:
    text = SHELL.read_text(encoding="utf-8")

    required = (
        "function _ensureThinkFanService(): void",
        'Config.getNestedValue("powerProfiles.fanControl.enabled", false) === true',
        "root._thinkFanService = ThinkFanService",
        "function _ensureCavaThemeService(): void",
        "function _ensureWeatherService(): void",
        "function _ensureFontSyncService(): void",
        "GlobalStates.deferredPanelsReady",
        "Config.options?.appearance?.wallpaperTheming?.enableCava ?? false",
        "root._cavaThemeService = CavaTheme",
        "root._ensureCavaThemeService();",
        "Config.options?.bar?.weather?.enable ?? false",
        "root._weatherService = Weather",
        "root._ensureWeatherService();",
        "Config.options?.appearance?.typography?.syncWithSystem ?? true",
        "root._fontSyncService = FontSyncService",
        "root._ensureFontSyncService();",
        "function _ensureCalendarSyncService(): void",
        "Config.options?.calendar?.externalSync?.enable ?? false",
        "root._calendarSyncService = CalendarSync",
        "root._ensureCalendarSyncService();",
    )
    for needle in required:
        if needle not in text:
            raise AssertionError(f"shell optional-service contract missing: {needle}")

    if "property var _thinkFanService: ThinkFanService" in text:
        raise AssertionError("disabled ThinkFan profile following must not instantiate at root construction")
    completed = re.search(
        r"Component\.onCompleted: \{(?P<body>.*?)\n\s*\}\n\n\s*// Shell entry animation",
        text,
        flags=re.S,
    )
    if not completed or "root._ensureThinkFanService();" not in completed.group("body"):
        raise AssertionError("already-ready Config must activate enabled ThinkFan following")

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
    if "root._weatherService = Weather;" in body:
        raise AssertionError("Tier 3 must not eagerly instantiate disabled Weather")
    if "root._fontSyncService = FontSyncService;" in body:
        raise AssertionError("Tier 3 must not eagerly instantiate disabled FontSyncService")
    if body.find("GlobalStates.deferredPanelsReady = true;") > body.find("root._ensureCavaThemeService();"):
        raise AssertionError("Cava demand gate must run after deferred services become eligible")
    if body.find("GlobalStates.deferredPanelsReady = true;") > body.find("root._ensureWeatherService();"):
        raise AssertionError("Weather demand gate must run after deferred services become eligible")
    if body.find("GlobalStates.deferredPanelsReady = true;") > body.find("root._ensureFontSyncService();"):
        raise AssertionError("Font sync demand gate must run after deferred services become eligible")

    tier4 = re.search(
        r'id: lateFeaturesTimer(?P<body>.*?)\n\s*\}\n\n\s*// Persist boot phase',
        text,
        flags=re.S,
    )
    if not tier4:
        raise AssertionError("could not isolate Tier-4 deferred init")
    tier4_body = tier4.group("body")
    if "root._calendarSyncService = CalendarSync;" in tier4_body:
        raise AssertionError("Tier 4 must not eagerly instantiate disabled CalendarSync")
    if tier4_body.find("root._lateFeaturesReady = true;") > tier4_body.find("root._ensureCalendarSyncService();"):
        raise AssertionError("CalendarSync demand gate must run after Tier 4 becomes eligible")

    config = re.search(
        r"Connections \{\s*\n\s*target: Config(?P<body>.*?)\n\s*\}",
        text,
        flags=re.S,
    )
    if not config or "root._ensureCavaThemeService()" not in config.group("body"):
        raise AssertionError("config changes must activate CavaTheme when enabled later")
    if "root._ensureWeatherService()" not in config.group("body"):
        raise AssertionError("config changes must activate Weather when enabled later")
    if "root._ensureFontSyncService()" not in config.group("body"):
        raise AssertionError("config changes must activate FontSyncService when enabled later")
    if "root._ensureCalendarSyncService()" not in config.group("body"):
        raise AssertionError("config changes must activate CalendarSync when enabled later")
    if "root._ensureThinkFanService()" not in config.group("body"):
        raise AssertionError("config changes must activate ThinkFan following when enabled later")

    ready_connections = re.findall(
        r"Connections \{\s*\n\s*target: Config(?P<body>.*?)\n\s*\}",
        text,
        flags=re.S,
    )
    if not any("function onReadyChanged()" in body
               and "root._ensureThinkFanService()" in body
               for body in ready_connections):
        raise AssertionError("Config readiness must activate enabled ThinkFan following")

    print("shell deferred service lifecycle contract: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
