pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.bar

// Waffle task previews now consume the same connected BarPopup surface as
// Waffle menus/tray popouts. WindowPreview tiles and capture lifecycle remain
// unchanged; only the detached PopupWindow shell is retired.
BarPopup {
    id: root

    required property bool tasksHovered
    property var appEntry
    property bool contentResident: false

    closeOnFocusLost: false
    closeOnHoverLost: false
    padding: 0

    function open(): void {
        releaseTimer.stop()
        root.contentResident = true
        root.active = true
        root.captureAppPreviews()
    }

    function show(appEntry: var, button: Item): void {
        root.appEntry = appEntry
        root.anchorItem = button
        root.updateAnchor()
        root.open()
    }

    function captureAppPreviews(): void {
        if (!CompositorService.isNiri)
            return

        const windowIds = []
        for (const tl of root.appEntry?.toplevels ?? []) {
            const id = tl?.niriWindowId
                ?? NiriService.findNiriWindow(tl)?.niriWindow?.id
                ?? -1
            if (id > 0)
                windowIds.push(id)
        }

        if (windowIds.length > 0) {
            WindowPreviewService.initialize()
            WindowPreviewService.captureForTaskView()
        }
    }

    onActiveChanged: {
        if (active) {
            releaseTimer.stop()
            root.contentResident = true
        } else {
            releaseTimer.restart()
        }
    }

    Timer {
        interval: 250
        running: root.active
            && !root.popupContainsMouse
            && !root.tasksHovered
        onTriggered: root.close()
    }

    readonly property bool _anyPanelOpen: GlobalStates.searchOpen
        || GlobalStates.waffleActionCenterOpen
        || GlobalStates.waffleNotificationCenterOpen
        || GlobalStates.waffleWidgetsOpen
        || GlobalStates.waffleAltSwitcherOpen
        || GlobalStates.waffleClipboardOpen
        || GlobalStates.waffleTaskViewOpen

    on_AnyPanelOpenChanged: {
        if (root._anyPanelOpen && root.active)
            root.close()
    }

    Timer {
        id: releaseTimer
        interval: 250
        onTriggered: {
            root.contentResident = false
            root.appEntry = null
        }
    }

    contentItem: Item {
        id: previewContent

        clip: true
        implicitHeight: Math.min(
            Looks.dp(158), previewBranch.item?.implicitHeight ?? 0)
        implicitWidth: previewBranch.item?.implicitWidth ?? 0

        Loader {
            id: previewBranch
            anchors.fill: parent
            active: root.contentResident
            sourceComponent: classicWindows
        }
    }

    Component {
        id: classicWindows

        RowLayout {
            Repeater {
                model: ScriptModel {
                    values: root.appEntry?.toplevels ?? []
                }

                delegate: WindowPreview {
                    required property var modelData
                    toplevel: modelData
                }
            }
        }
    }
}
