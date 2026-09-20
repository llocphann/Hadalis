#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/WindowPreviewService.qml"
capture_script="$repo_root/scripts/capture-windows.sh"
bar_preview="$repo_root/modules/bar/BarTaskbarPreview.qml"
dock_preview="$repo_root/modules/dock/DockPreview.qml"
workspace_overview="$repo_root/modules/bar/BarWorkspaceOverview.qml"
workspaces="$repo_root/modules/bar/Workspaces.qml"
waffle_preview="$repo_root/modules/waffle/bar/tasks/TaskPreview.qml"
waffle_tasks="$repo_root/modules/waffle/bar/tasks/Tasks.qml"
waffle_bar_popup="$repo_root/modules/waffle/bar/BarPopup.qml"

fail() {
    printf 'window preview lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$service" || fail "$message"
}

require_capture() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$capture_script" || fail "$message"
}

require_bar_preview() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$bar_preview" || fail "$message"
}

require_dock_preview() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$dock_preview" || fail "$message"
}

require_workspaces() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$workspaces" || fail "$message"
}

require_workspace_overview() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$workspace_overview" || fail "$message"
}

require_waffle_preview() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$waffle_preview" || fail "$message"
}

require 'console.warn("[WindowPreviewService] preview directory helper failed to start")' \
    'preview directory startup failure must continue initialization'
require 'console.warn("[WindowPreviewService] session marker reader failed to start")' \
    'session marker startup failure must recover'
require 'console.warn("[WindowPreviewService] session reset helper failed to start")' \
    'session reset startup failure must release session readiness'
require 'console.warn("[WindowPreviewService] preview cache scan failed to start")' \
    'cache scan startup failure must release session readiness'
require 'console.warn("[WindowPreviewService] capture process failed to start")' \
    'capture startup failure must be explicit'
require 'onStarted: captureProcess.startObserved = true' \
    'capture process must record successful startup'
require 'root.capturing = false' \
    'capture startup/exit cleanup must release the capture gate'
require 'Cliphist.suppressRefresh = false' \
    'capture startup/exit cleanup must release clipboard refresh suppression'
require 'root.captureComplete()' \
    'capture failure must notify consumers that the cycle ended'
require 'root._resumeRequestedCapture()' \
    'initialization failures must resume deferred capture requests'

require_capture 'capture_timeout_seconds="${INIR_WINDOW_PREVIEW_CAPTURE_TIMEOUT_SECONDS:-90}"' \
    'window preview capture must have a finite default lifetime'
require_capture 'INIR_CAPTURE_WINDOWS_TIMEOUT_ACTIVE' \
    'window preview timeout wrapper must guard against recursive re-entry'
require_capture 'max_concurrent="${INIR_WINDOW_PREVIEW_CAPTURE_CONCURRENCY:-2}"' \
    'window preview capture must default to bounded two-way concurrency'
require_capture '[[ ! "$max_concurrent" =~ ^[1-4]$ ]]' \
    'window preview capture concurrency override must remain bounded'
require_capture 'exec "$timeout_bin" --signal=TERM --kill-after=5s "${capture_timeout_seconds}s" "$0" "$@"' \
    'window preview capture must execute under the timeout supervisor'

require_bar_preview 'function showWorkspace(workspaceId: var, button: Item): void' \
    'shared Bar preview must expose workspace hover mode'
require_bar_preview 'NiriService.sortToplevels(' \
    'Niri workspace preview must reuse authoritative enriched toplevel mapping'
require_bar_preview 'Hyprland.toplevels?.values ?? []' \
    'Hyprland workspace preview must derive windows from compositor workspace ownership'
require_bar_preview 'values: root.previewToplevels' \
    'app and workspace previews must share one window-preview tile model'
require_workspaces 'workspacePreviewPopup.showWorkspace(workspaceId, button)' \
    'workspace strip must route hover through the shared Bar preview'
require_workspaces 'interval: Config.options?.dock?.hoverPreviewDelay ?? 400' \
    'workspace preview must reuse the existing hover-preview delay'
require_workspaces 'BarWorkspaceOverview {' \
    'workspace strip must use the connected workspace Overview popup by default'
require_workspaces 'Config.options?.overview?.workspaceHover?.delayMs ?? 280' \
    'workspace Overview hover must use its dedicated configurable delay'
require_workspace_overview 'StyledPopup {' \
    'workspace Overview must reuse the shared Bar-connected popup surface'
require_workspace_overview 'OverviewNiriWidget {' \
    'workspace Overview must reuse the Niri Overview renderer'
require_workspace_overview 'OverviewWidget {' \
    'workspace Overview must retain Hyprland Overview support'
require_workspace_overview 'WindowPreviewService.captureForTaskView()' \
    'workspace Overview must preserve the shared preview capture lifecycle'
require_workspaces 'BarTaskbarPreview {' \
    'workspace strip must retain the compact preview fallback when Overview hover is disabled'

require_dock_preview 'const windowIds = []' \
    'Dock preview must build a scoped capture request for the hovered app'
require_dock_preview 'WindowPreviewService.captureForTaskView(windowIds)' \
    'Dock preview must not request a full-session capture for one app hover'
if grep -Fq 'WindowPreviewService.captureForTaskView()' "$dock_preview"; then
    fail 'Dock preview must not capture every window on each app hover'
fi

require_waffle_preview 'BarPopup {' \
    'Waffle task preview must reuse the shared Waffle connected BarPopup'
require_waffle_preview 'root.popupContainsMouse' \
    'Waffle task preview hover bridge must consume BarPopup hover state'
require_waffle_preview 'WindowPreviewService.captureForTaskView()' \
    'Waffle task preview must preserve the existing capture lifecycle'
if grep -Fq 'PopupWindow {' "$waffle_preview"; then
    fail 'Waffle task preview must not retain detached PopupWindow presentation'
fi
if grep -Fq 'anchor.window:' "$waffle_tasks"; then
    fail 'Waffle Tasks must not configure the retired PopupWindow anchor API'
fi
grep -Fq 'readonly property bool popupContainsMouse:' "$waffle_bar_popup" \
    || fail 'Waffle BarPopup must expose popup hover state to task preview lifecycle'

start_guard_count="$(grep -Fc -- 'property bool startObserved: false' "$service")"
if (( start_guard_count < 5 )); then
    fail "expected startup guards for init and capture processes, found $start_guard_count"
fi

printf 'window preview lifecycle guards: ok\n'
