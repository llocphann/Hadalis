pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions

// Window preview popout for the bar-embedded taskbar. The outer surface is the
// same connected morph used by every other bar popout; preview cards remain the
// content, not a second floating shell/background.
StyledPopup {
    id: root

    required property bool dockHovered
    property string barPosition: "top"
    property var appEntry
    property Item anchorItem
    property bool previewOpen: false

    // BarTaskbar historically supplied anchor.window to the old PopupWindow.
    // Keep that grouped property as a no-op compatibility input while placement
    // now comes exclusively from StyledPopup + the real anchorItem geometry.
    property QtObject anchor: QtObject {
        property var window: null
    }

    readonly property bool isVertical: barPosition === "left" || barPosition === "right"

    hoverTarget: root.anchorItem
    hoverActivates: false
    alternativeVisibleCondition: root.previewOpen
    popupBackgroundMargin: 0

    function close(): void {
        root.previewOpen = false
    }

    function open(): void {
        root.previewOpen = true
    }

    function show(appEntry: var, button: Item): void {
        root.appEntry = appEntry
        root.anchorItem = button
        WindowPreviewService.captureForTaskView()
        root.open()
    }

    function _sortedToplevels(): list<var> {
        return root.appEntry?.toplevels ?? []
    }

    onAnchorItemChanged: {
        if (root.previewOpen && !root.anchorItem)
            root.close()
    }

    // StyledPopup's default content property is an Item. Keep every non-visual
    // helper under the content Item's `data` list so Connections/Timer are not
    // accidentally assigned to StyledPopup.contentItem during type creation.
    Item {
        id: previewContent
        clip: true
        implicitWidth: root.isVertical
            ? Math.min(184, windowsLayout.implicitWidth)
            : windowsLayout.implicitWidth
        implicitHeight: root.isVertical
            ? windowsLayout.implicitHeight
            : Math.min(144, windowsLayout.implicitHeight)

        Connections {
            target: root.anchorItem
            enabled: root.previewOpen
            function onToplevelsChanged() {
                if ((root.anchorItem?.toplevels?.length ?? 0) === 0)
                    root.close()
            }
        }

        Connections {
            target: ToplevelManager.toplevels
            function onValuesChanged() {
                if (!root.previewOpen || !root.appEntry)
                    return
                const appId = root.appEntry.appId
                if (!appId)
                    return
                const allToplevels = CompositorService.sortedToplevels
                        && CompositorService.sortedToplevels.length
                    ? CompositorService.sortedToplevels
                    : ToplevelManager.toplevels.values
                const current = allToplevels.filter(t => {
                    const id = AppSearch.resolveWindowIdentity(t)
                    return id && id.toLowerCase() === appId
                })
                if (current.length === 0)
                    root.close()
                else
                    root.appEntry = Object.assign({}, root.appEntry, { toplevels: current })
            }
        }

        // Gives the pointer time to travel across the connected shoulder from the
        // taskbar button into the preview content without collapsing the surface.
        Timer {
            interval: 250
            running: root.previewOpen && !root.popupHovered && !root.dockHovered
            onTriggered: root.close()
        }

        // Horizontal bar: previews side by side. Vertical bar: previews stacked.
        GridLayout {
            id: windowsLayout
            anchors.centerIn: parent
            rowSpacing: 8
            columnSpacing: 8
            columns: root.isVertical ? 1 : -1
            rows: root.isVertical ? -1 : 1

            Repeater {
                model: ScriptModel {
                    values: root._sortedToplevels()
                }
                delegate: BarTaskbarWindowPreview {
                    required property var modelData
                    toplevel: modelData
                    onWindowActivated: {
                        if (!(Config.options?.dock?.keepPreviewOnClick ?? false))
                            root.close()
                    }
                }
            }
        }
    }
}
