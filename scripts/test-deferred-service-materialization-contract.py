#!/usr/bin/env python3
"""Regression contract for capability-aware deferred service materialization."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SHELL = (ROOT / "shell.qml").read_text(encoding="utf-8")


def body(function_name: str) -> str:
    match = re.search(
        rf"function\s+{re.escape(function_name)}\s*\([^)]*\)\s*:\s*void\s*\{{(.*?)\n    \}}",
        SHELL,
        re.S,
    )
    if not match:
        raise AssertionError(f"missing function {function_name}")
    return match.group(1)


def main() -> None:
    deferred = body("_ensureDeferredFeatureServices")
    late = body("_ensureLateFeatureServices")

    assert "Config.options?.bar?.weather?.enable ?? false" in deferred
    assert "root._weatherService = Weather" in deferred

    assert "Config.options?.calendar?.externalSync?.enable ?? false" in late
    assert "root._calendarSyncService = CalendarSync" in late
    assert "Config.options?.appearance?.typography?.syncWithSystem ?? true" in late
    assert "root._fontSyncService = FontSyncService" in late
    assert "if (!root._lateFeaturesReady)" in late

    # These are intentionally still eager after the first frame because they own
    # IPC/global policy or preserve the current preview latency contract.
    for required in (
        "root._gameModeService = GameMode;",
        "root._windowPreviewService = WindowPreviewService;",
        "root._voiceSearchService = VoiceSearch;",
        "root._shellUpdatesService = ShellUpdates;",
        "root._autostartService = Autostart;",
    ):
        assert required in SHELL, f"required eager deferred service missing: {required}"

    # CavaTheme is consumer-lazy when ordinary shell visualizers need only its
    # palette, but the explicit external CAVA theming feature owns a track-change
    # side effect and must keep the singleton resident while enabled.
    assert "Config.options?.appearance?.wallpaperTheming?.enableCava ?? false" in deferred
    assert "root._cavaThemeService = CavaTheme" in deferred
    assert "property var _cavaThemeService" in SHELL

    # The feature-gated services must have exactly one explicit shell assignment,
    # all inside the helper functions above.
    assert SHELL.count("root._weatherService = Weather") == 1
    assert SHELL.count("root._cavaThemeService = CavaTheme") == 1
    assert SHELL.count("root._calendarSyncService = CalendarSync") == 1
    assert SHELL.count("root._fontSyncService = FontSyncService") == 1

    config_changed = re.search(
        r"function\s+onConfigChanged\(\)\s*:\s*void\s*\{(.*?)\n        \}",
        SHELL,
        re.S,
    )
    assert config_changed, "missing Config.onConfigChanged handler"
    config_body = config_changed.group(1)
    assert "root._ensureDeferredFeatureServices()" in config_body
    assert "root._ensureLateFeatureServices()" in config_body

    assert "GlobalStates.deferredPanelsReady = true;" in SHELL
    assert "root._ensureDeferredFeatureServices();" in SHELL
    assert "root._lateFeaturesReady = true;" in SHELL
    assert "root._ensureLateFeatureServices();" in SHELL

    print("deferred service materialization contract: ok")


if __name__ == "__main__":
    main()
