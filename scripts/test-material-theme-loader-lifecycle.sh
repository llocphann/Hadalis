#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/MaterialThemeLoader.qml"
appearance="$repo_root/modules/common/Appearance.qml"
tools_view="$repo_root/modules/sidebarLeft/ToolsView.qml"
control_wallpaper="$repo_root/modules/controlPanel/WallpaperSection.qml"
waffle_widgets="$repo_root/modules/waffle/widgets/WidgetsContent.qml"

fail() {
    printf 'material theme lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$service" || fail "$message"
}

require 'function _finishGenerator(name: string, code: int, immediateReload: bool, spawnFailed: bool): void' \
    'generator exits and startup failures must share recovery'
require 'else if (code === 0)' \
    'force-apply must remain gated on confirmed successful generation'
require 'root.scheduleReload()' \
    'failed generators must preserve reload safety-net behavior'
require 'delayedExternalApply.restart()' \
    'failed generators must preserve external-apply recovery behavior'

require 'root._finishGenerator("scheme variant", -1, true, true)' \
    'scheme variant startup failure must enter shared recovery'
require 'root._finishGenerator("dark mode", -1, true, true)' \
    'dark-mode startup failure must enter shared recovery'
require 'root._finishGenerator("color invert", -1, false, true)' \
    'color-invert startup failure must enter shared recovery'
require 'root._finishGenerator("scheme variant", code, true, false)' \
    'scheme variant normal exit must use shared recovery'
require 'root._finishGenerator("dark mode", code, true, false)' \
    'dark-mode normal exit must use shared recovery and reload immediately'
require 'root._finishGenerator("color invert", code, false, false)' \
    'color-invert normal exit must use shared recovery'

grep -Fq -- 'MaterialThemeLoader.setDarkMode(!root.m3colors.darkmode)' "$appearance" \
    || fail 'Appearance.toggleDarkMode must use the live MaterialThemeLoader pipeline'
if grep -Fq -- 'ThemeService.regenerateAutoTheme()' "$appearance"; then
    fail 'Appearance.toggleDarkMode must not use the stale config-read regeneration path'
fi
grep -Fq -- 'onToggledByUser: checked => MaterialThemeLoader.setDarkMode(checked)' "$tools_view" \
    || fail 'ToolsView dark-mode switch must use the live MaterialThemeLoader path'
if grep -Fq -- 'Config.setNestedValue("appearance.customTheme.darkmode"' "$tools_view"; then
    fail 'ToolsView must not bypass MaterialThemeLoader with a direct darkmode config write'
fi

for palette_surface in "$control_wallpaper" "$waffle_widgets"; do
    grep -Fq -- 'Config.setNestedValue("appearance.palette.type", newValue)' "$palette_surface" \
        || fail "$palette_surface must persist palette selection"
    grep -Fq -- 'if (!ThemeService.isAutoTheme)' "$palette_surface" \
        || fail "$palette_surface must preserve immediate manual-preset variant application"
    if grep -Fq -- 'wallpaperSwitchScriptPath} --noswitch --type ${newValue}' "$palette_surface"; then
        fail "$palette_surface must not spawn a duplicate auto-theme regeneration"
    fi
done

start_guard_count="$(grep -Fc -- 'property bool startObserved: false' "$service")"
if (( start_guard_count < 3 )); then
    fail "expected startup guards on all three material generators, found $start_guard_count"
fi

printf 'material theme loader lifecycle guards: ok\n'
