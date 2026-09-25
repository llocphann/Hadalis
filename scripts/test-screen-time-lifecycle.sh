#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/ScreenTime.qml"
shell_root="$repo_root/shell.qml"
notification_center="$repo_root/modules/notificationCenter/NotificationCenterPopup.qml"
notification_content="$repo_root/modules/notificationCenter/NotificationCenterContent.qml"
notification_list="$repo_root/modules/common/widgets/NotificationListView.qml"
notification_group="$repo_root/modules/common/widgets/NotificationGroup.qml"
notification_item="$repo_root/modules/common/widgets/NotificationItem.qml"
pill_tabs="$repo_root/modules/common/widgets/PillTabBar.qml"
compact_sidebar="$repo_root/modules/sidebarRight/CompactSidebarRightContent.qml"
bottom_group="$repo_root/modules/sidebarRight/BottomWidgetGroup.qml"

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
    'Screen Time must retain the Waffle/explicit opt-in owner'
require '(Config.options?.panelFamily ?? "ii") !== "waffle"' \
    'Material Activity tracking must stay limited to the ii panel family'
require '.includes("iiScreenCorners")' \
    'Material Activity tracking must follow its ScreenCorners popup host'

require_in "$shell_root" '(Config.options?.panelFamily ?? "ii") !== "waffle"' \
    'shell must limit automatic Activity tracking to the ii family'
require_in "$shell_root" '.includes("iiScreenCorners")' \
    'shell must materialize ScreenTime for the Activity popup host'

for token in \
    'PillTabBar {' \
    'label: Translation.tr("Activity")' \
    'readonly property var todayApps:' \
    'ScreenTime.getAppList(1)' \
    'readonly property var visibleApps: root.todayApps.slice(0, 4)' \
    'value: DateTime.uptime || "--"' \
    'ScreenTime.formatDuration(' \
    'text: Translation.tr("App usage")' \
    'readonly property real usageFraction:' \
    'Layout.preferredHeight: 34' \
    'model: root.visibleApps' \
    'visible: root.selectedTab === 1'; do
    require_in "$notification_center" "$token" \
        "Notification Center Activity contract missing: $token"
done

if grep -Fq 'Flickable {' "$notification_center"; then
    fail 'Activity tab must remain a fixed non-scrollable composition'
fi

for token in \
    'property var tabs: []' \
    'property int currentIndex: 0' \
    'color: Appearance.colors.colPrimaryContainer' \
    'id: centeredTabLabel' \
    'anchors.centerIn: parent' \
    'anchors.right: parent.right' \
    'signal tabSelected(int index)'; do
    require_in "$pill_tabs" "$token" \
        "shared pill-tab contract missing: $token"
done

for token in \
    '!root.popupPresentation && Notifications.list.length > 3' \
    'compactCards: root.popupPresentation' \
    'compactActions: root.popupPresentation' \
    'implicitWidth: root.popupPresentation ? 30 : 36' \
    'text: "delete_sweep"'; do
    require_in "$notification_content" "$token" \
        "compact popup Notifications contract missing: $token"
done

for token in \
    'property bool compactCards: false' \
    'property bool compactActions: false' \
    'spacing: modernCards ? (compactCards ? 6 : 8) : 3'; do
    require_in "$notification_list" "$token" \
        "compact NotificationListView contract missing: $token"
done

for token in \
    'property bool compactLayout: false' \
    'property bool compactActions: false' \
    '? (compactLayout ? 9 : 12) : 10'; do
    require_in "$notification_group" "$token" \
        "compact NotificationGroup contract missing: $token"
done

for token in \
    'property bool compactActions: false' \
    '? (root.compactActions ? 28 : 34)' \
    'iconSize: root.compactActions' \
    'id: copyIcon'; do
    require_in "$notification_item" "$token" \
        "compact notification action contract missing: $token"
done

for sidebar in "$compact_sidebar" "$bottom_group"; do
    if grep -Fq 'ScreenTimeWidget {' "$sidebar"; then
        fail "${sidebar#"$repo_root/"} still hosts standalone Screen Time"
    fi
    if grep -Fq 'id: "screentime"' "$sidebar"; then
        fail "${sidebar#"$repo_root/"} still exposes a Screen Time tab"
    fi
done

printf 'screen-time lifecycle guards: ok\n'
