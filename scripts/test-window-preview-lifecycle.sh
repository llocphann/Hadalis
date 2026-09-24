#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/WindowPreviewService.qml"
capture_script="$repo_root/scripts/capture-windows.sh"
bar_preview="$repo_root/modules/bar/BarTaskbarPreview.qml"
workspace_overview="$repo_root/modules/bar/BarWorkspaceOverview.qml"
workspaces="$repo_root/modules/bar/Workspaces.qml"
waffle_preview="$repo_root/modules/waffle/bar/tasks/TaskPreview.qml"
waffle_tasks="$repo_root/modules/waffle/bar/tasks/Tasks.qml"
waffle_bar_popup="$repo_root/modules/waffle/bar/BarPopup.qml"
preview_policy="$repo_root/services/WindowPreviewPolicy.js"
adaptive_preview_policy="$repo_root/services/AdaptivePreviewPolicy.js"
adaptive_preview_service="$repo_root/services/AdaptivePreviewService.qml"
overview_renderer="$repo_root/modules/overview/OverviewNiriWidget.qml"
hypr_overview_window="$repo_root/modules/overview/OverviewWindow.qml"
services_qmldir="$repo_root/services/qmldir"
config_qml="$repo_root/modules/common/Config.qml"

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

# Previously the five-minute TTL forced Niri screenshot-window and a changed
# Image URL on the very next hover, although the window's ID was unchanged.
require 'import "WindowPreviewPolicy.js" as PreviewPolicy' \
    'service must use the shared session-cache policy'
require 'PreviewPolicy.needsCapture(previewCache[id])' \
    'pending capture requests must reuse cached window IDs'
require 'PreviewPolicy.needsCapture(cached)' \
    'capture selection must use session-cache policy'
require 'if (!root._pendingRequestNeedsCapture()) {' \
    'cached hover requests must not start a new capture process'
require 'root._observeWindowSet()' \
    'new compositor windows must be queued before the next hover'
require 'root._handleCaptureOutput(line)' \
    'completed images must be published per-window before process exit'
require 'root._completeCapture(exitCode, exitStatus)' \
    'completed PNGs must survive buffered stdout on process exit'
require_capture "printf 'PREVIEW_READY %s" \
    'capture script must publish a completion record on atomic rename'
require 'function refreshForOverview(windowIds): void {' \
    'Overview must be able to refresh cached visible windows without a global cache reset'
require 'forceRequestedWindowIds' \
    'Overview refresh must use a targeted one-shot force queue'
require 'function captureAllWindows(): void {' \
    'explicit force refresh must remain available'
if grep -Fq 'previewValidityMs' "$service"; then
    fail 'window previews must not expire solely due to wall-clock time'
fi
grep -Fq 'cache: true' "$overview_renderer" \
    || fail 'Overview preview must use the Qt image cache'
grep -Fq 'WindowPreviewService.overviewWarmDecodeWidth' "$overview_renderer" \
    || fail 'Overview must share the resident cache decode width'
grep -Fq 'WindowPreviewService.overviewWarmDecodeHeight' "$overview_renderer" \
    || fail 'Overview must share the resident cache decode height'
grep -Fq 'WindowPreviewService.warmForOverview(windowItems.map(record => record.id))' "$overview_renderer" \
    || fail 'Overview must retain bounded decoded previews across popup teardown'
grep -Fq 'WindowPreviewService.refreshForOverview(ids)' "$overview_renderer" \
    || fail 'Overview presentation must refresh visible long-lived window snapshots'
grep -Fq 'retainWhileLoading: true' "$overview_renderer" \
    || fail 'Overview must retain the previous decoded frame while a refreshed preview loads'
grep -Fq 'property bool _everReady: false' "$overview_renderer" \
    || fail 'Overview preview visibility must remember whether a decoded frame already exists'
grep -Fq 'visible: parent.showPreviews && _everReady' "$overview_renderer" \
    || fail 'Overview refresh must not hide a ready preview merely because the new URL is loading'
if grep -Fq 'visible: parent.showPreviews && status === Image.Ready' "$overview_renderer"; then
    fail 'Overview preview must not blink off during async refresh'
fi

node - "$preview_policy" <<'NODE'
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const scope = {};
vm.createContext(scope);
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8'), scope);
const needsCapture = scope.needsCapture;
assert.equal(typeof needsCapture, 'function');
assert.equal(needsCapture(undefined), true, 'first visit captures missing window');
assert.equal(needsCapture({path: ''}), true, 'invalid cache entry captures');
assert.equal(needsCapture({path: '/tmp/window-42.png', timestamp: 1}), false,
    'old but valid window preview survives any idle duration');
assert.equal(needsCapture({path: '/tmp/window-42.png', timestamp: Date.now()}), false,
    'fresh preview is reused without recapture');
assert.equal(needsCapture({path: '/tmp/window-43.png', timestamp: 1}), false,
    'separate window IDs retain independent snapshots');
assert.equal(scope.previewUrl({path: '/tmp/window-42.png', timestamp: 10}),
    'file:///tmp/window-42.png?10', 'URL stays stable on cache hit');
assert.equal(scope.nextRevision(10, 10), 11,
    'force refresh advances URL even within one millisecond');
assert.equal(scope.nextRevision(10, 15), 15, 'later capture advances URL');
assert.equal(scope.previewUrl({path: '/tmp/window-42.png', timestamp: 11}),
    'file:///tmp/window-42.png?11', 'new revision is observable');
assert.deepEqual(Array.from(scope.boundedWindowIds([1, 1, 2, -5, 3, 4], 3)),
    [1, 2, 3], 'resident window list is bounded and deduplicated');
console.log('window preview session-cache behavior: PASS');
NODE

# Adaptive live-preview scheduling is deliberately separate from the Niri PNG
# cache. Niri must not turn screenshot-window into a video transport.
[[ -f "$adaptive_preview_policy" ]] || fail 'missing adaptive preview policy'
[[ -f "$adaptive_preview_service" ]] || fail 'missing adaptive preview scheduler'
grep -Fq 'singleton AdaptivePreviewService 1.0 AdaptivePreviewService.qml' "$services_qmldir" \
    || fail 'adaptive preview scheduler must be registered'
grep -Fq 'property string previewMode: "adaptive"' "$config_qml" \
    || fail 'adaptive preview mode must have a persisted schema default'
grep -Fq 'property int maxLiveWindows: 6' "$config_qml" \
    || fail 'live preview streams must have a bounded default budget'
grep -Fq 'live: root.previewLive' "$hypr_overview_window" \
    || fail 'Hyprland toplevel capture must be controlled by the adaptive scheduler'
grep -Fq 'windowPreview.captureFrame()' "$hypr_overview_window" \
    || fail 'static Hyprland windows must use a single compositor frame'
if grep -Fq 'ScreencopyView {' "$overview_renderer"; then
    fail 'Niri Overview must not fake toplevel live capture with unsupported ScreencopyView sources'
fi

node - "$adaptive_preview_policy" <<'NODE'
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const scope = {};
vm.createContext(scope);
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8'), scope);

assert.equal(scope.normalizeMode('bogus'), 'adaptive');
assert.equal(scope.boundedLiveLimit(99, 6), 16);
assert.equal(scope.wantsLive({
    mode: 'snapshot', active: true, backendAvailable: true, hovered: true
}), false, 'snapshot mode never opens a live stream');
assert.equal(scope.wantsLive({
    mode: 'live', active: true, backendAvailable: false
}), false, 'live mode still requires a real backend');
assert.equal(scope.wantsLive({
    mode: 'adaptive', active: true, backendAvailable: true, hovered: true
}), true, 'hover may promote immediately');
assert.equal(scope.wantsLive({
    mode: 'adaptive', active: true, backendAvailable: true, mediaPlaying: true
}), true, 'playing media is a dynamic-content hint');
assert.equal(scope.wantsLive({
    mode: 'adaptive', active: true, backendAvailable: true, focused: true
}), false, 'focus alone remains a snapshot by default');
assert.equal(scope.wantsLive({
    mode: 'adaptive', active: true, backendAvailable: true,
    activityScore: 0.8, activityPromotionThreshold: 0.55
}), true, 'future motion analyzers can feed the same activity score');
assert.deepEqual(Array.from(scope.selectLiveKeys([
    {key: 'static', requested: false, priority: 99999, order: 1},
    {key: 'media', requested: true, priority: 5000, order: 2},
    {key: 'hover', requested: true, priority: 10000, order: 3},
    {key: 'other', requested: true, priority: 100, order: 4}
], 2)), ['hover', 'media'], 'budget keeps the highest-value live streams');
console.log('adaptive preview policy behavior: PASS');
NODE

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
