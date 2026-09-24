#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/ScreenTime.qml"
shell_root="$repo_root/shell.qml"
dash_notifications="$repo_root/modules/dashboard/DashNotifications.qml"
dash_pill_tabs="$repo_root/modules/dashboard/DashPillTabBar.qml"

fail() {
    printf 'screen-time lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$service" || fail "$message"
}

require_in() {
    local file="$1"
    local needle="$2"
    local message="$3"
    grep -Fq -- "$needle" "$file" || fail "$message"
}

file_view_count="$(grep -Fc -- 'id: todayFileView' "$service")"
if (( file_view_count != 1 )); then
    fail "expected exactly one todayFileView, found $file_view_count"
fi

require 'function _finishStartupRead(rawText: string): void' \
    'startup history read must have a shared completion path'
require 'onStarted: startupReadProc.startObserved = true' \
    'startup history reader must record successful startup'
require 'console.warn("[ScreenTime] startup history reader failed to start")' \
    'startup history reader must handle spawn failure'
require 'root._finishStartupRead("__NOFILE__")' \
    'startup spawn failure must fall back to an empty current day'
require 'root._loadingToday = false' \
    'startup completion must release the loading gate'
require 'root.ready = true' \
    'startup completion must release the ready gate'

require 'onStarted: rangeReadProc.startObserved = true' \
    'range history reader must record successful startup'
require 'console.warn("[ScreenTime] range history reader failed to start")' \
    'range history reader must handle spawn failure'
require 'root._activeRangeDays = 0' \
    'range reader failure must release the active-range gate'
require 'Qt.callLater(root._startNextRangeRead)' \
    'range reader failure/exit must continue queued history reads'

require '(Config.options?.sidebar?.screenTime?.enable ?? false)' \
    'Screen Time must retain the Sidebar opt-in owner'
require '|| (Config.options?.dashboard?.enable ?? true)' \
    'Dashboard enablement must keep Screen Time tracking alive for Uptime history'

require_in "$shell_root" '|| (Config.options?.dashboard?.enable ?? true)' \
    'shell must materialize ScreenTime when Dashboard owns the Uptime tab'

for token in \
    'DashPillTabBar {' \
    'leftLabel: Translation.tr("Notifications")' \
    'rightLabel: Translation.tr("Uptime")' \
    'readonly property var todayApps:' \
    'ScreenTime.getAppList(1)' \
    'text: DateTime.uptime' \
    'ScreenTime.formatDuration(' \
    'GridLayout {' \
    'columns: root.appColumns' \
    'model: root.visibleApps' \
    'visible: root.currentTab === 1'; do
    require_in "$dash_notifications" "$token" \
        "Dashboard Notifications/Uptime contract missing: $token"
done

if grep -Fq 'Flickable {' "$dash_notifications"; then
    fail 'Dashboard Uptime must remain a fixed non-scrollable composition'
fi

for token in \
    'Shape {' \
    'id: inactiveTabShape' \
    'id: activeTabPill' \
    'Shape.CurveRenderer' \
    'Appearance.colors.colPrimaryContainer' \
    'signal tabRequested(int index)'; do
    require_in "$dash_pill_tabs" "$token" \
        "Dashboard pill tabs must match Todo tab language: $token"
done

printf 'screen-time lifecycle guards: ok\n'
