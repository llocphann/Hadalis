#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/IconThemeService.qml"

fail() {
    printf 'icon theme lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$service" || fail "$message"
}

require 'function _startKdeGlobalsSync(themeName: string, skipRestart: bool): void' \
    'gsettings fallback must be able to continue into kdeglobals sync'
require 'function _continueAfterKdeGlobals(themeName: string, skipRestart: bool): void' \
    'kdeglobals fallback must be able to continue into optional KDE integration'
require 'function _startQtSync(themeName: string): void' \
    'optional kwriteconfig stage must have a Qt sync continuation'
require 'function _startGtkSync(themeName: string): void' \
    'qt6ct stage must have a GTK sync continuation'

require 'console.warn("[IconThemeService] gsettings failed to start; continuing icon theme sync")' \
    'gsettings spawn failure must be handled explicitly'
require 'root._startKdeGlobalsSync(gsettingsSetProc.themeName, gsettingsSetProc.skipRestart)' \
    'gsettings spawn failure/exit must continue the pipeline'
require 'console.warn("[IconThemeService] kdeglobals updater failed to start; continuing icon theme sync")' \
    'kdeglobals updater spawn failure must be handled explicitly'
require 'root._continueAfterKdeGlobals(kdeGlobalsUpdateProc.themeName, kdeGlobalsUpdateProc.skipRestart)' \
    'kdeglobals spawn failure/exit must continue the pipeline'

require '"/usr/bin/kwriteconfig6"' \
    'kwriteconfig6 integration command changed unexpectedly'
require '_log("[IconThemeService] kwriteconfig6 unavailable; continuing with Qt/GTK sync")' \
    'missing optional kwriteconfig6 must not stop the pipeline'
require 'root._startQtSync(kwriteconfigProc.themeName)' \
    'kwriteconfig spawn failure/exit must continue into Qt sync'
require 'console.warn("[IconThemeService] qt6ct updater failed to start; continuing with GTK sync")' \
    'qt6ct spawn failure must be handled explicitly'
require 'root._startGtkSync(qt6ctProc.themeName)' \
    'qt6ct spawn failure/exit must continue into GTK sync'

require 'property bool _themesLoaded: false' \
    'icon-theme enumeration must expose cached demand state'
require 'function ensureThemesLoaded(force = false)' \
    'icon-theme enumeration must be demand-driven'
if grep -Fq -- 'function ensureThemesLoaded(force: bool = false): void' "$service"; then
    fail 'icon-theme lazy loader must avoid unsupported typed default parameters'
fi
require 'if (root._themesLoaded && !force)' \
    'icon-theme enumeration must not rescan after the first successful demand load'
require 'root._themesLoaded = true' \
    'icon-theme enumeration must mark even an empty scan complete'
if sed -n '/function ensureInitialized()/,/function ensureThemesLoaded/p' "$service" \
    | grep -Fq -- 'listThemesProc.running = true'; then
    fail 'icon-theme startup initialization must not enumerate themes eagerly'
fi

start_guard_count="$(grep -Fc -- 'property bool startObserved: false' "$service")"
if (( start_guard_count < 4 )); then
    fail "expected at least four startup guards in icon theme pipeline, found $start_guard_count"
fi

printf 'icon theme service lifecycle guards: ok\n'
