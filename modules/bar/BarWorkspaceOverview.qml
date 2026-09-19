pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.overview

// Workspace Overview opened from a Bar workspace hover.
//
// StyledPopup owns the layer-shell window, Bar attachment, slide-under motion,
// Screen Edge joins, shadow and hover bridge. The Overview widgets render only
// their content plane here so there is one connected surface, not a popup card
// nested inside another popup card.
StyledPopup {
    id: root

    required property bool dockHovered
    property string barPosition: "top"
    property Item anchorItem
    property bool previewOpen: false
    property var workspaceId: null

    hoverTarget: root.anchorItem
    hoverActivates: false
    alternativeVisibleCondition: root.previewOpen
    popupBackgroundMargin: 0

    function close(): void {
        root.previewOpen = false
    }

    function showWorkspace(workspaceId: var, button: Item): void {
        root.workspaceId = workspaceId
        root.anchorItem = button
        WindowPreviewService.captureForTaskView()
        root.previewOpen = true
    }

    onAnchorItemChanged: {
        if (root.previewOpen && !root.anchorItem)
            root.close()
    }

    Item {
        id: overviewContent
        implicitWidth: overviewLoader.item?.implicitWidth ?? 1
        implicitHeight: overviewLoader.item?.implicitHeight ?? 1

        Timer {
            interval: Config.options?.overview?.workspaceHover?.closeDelayMs ?? 220
            running: root.previewOpen
                && !root.popupHovered
                && !root.dockHovered
            onTriggered: root.close()
        }

        Loader {
            id: overviewLoader
            anchors.fill: parent
            active: root.previewOpen
            sourceComponent: CompositorService.isNiri ? niriOverview : hyprOverview
        }

        Component {
            id: niriOverview
            OverviewNiriWidget {
                panelWindow: root.presentationWindow
                    ?? root.anchorItem?.QsWindow?.window
                presentationActive: root.previewOpen
                embeddedSurface: true
                preferredWorkspaceId: root.workspaceId
                onPresentationCloseRequested: root.close()
            }
        }

        Component {
            id: hyprOverview
            OverviewWidget {
                panelWindow: root.presentationWindow
                    ?? root.anchorItem?.QsWindow?.window
                presentationActive: root.previewOpen
                embeddedSurface: true
                preferredWorkspaceId: root.workspaceId
                onPresentationCloseRequested: root.close()
            }
        }
    }
}
