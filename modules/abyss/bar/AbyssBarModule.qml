pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar as Shared
import qs.modules.bar.weather
import qs.modules.abyss.looks
import qs.modules.abyss.content
import qs.modules.verticalBar as Vertical

// Mature feature controls, with popup ownership discovered from this ancestor.
Item {
    id: root
    required property string kind
    required property string outputName
    property var liquidController: null
    property string attachedEdge: "top"
    property string popupJoinedEdge: ""
    property bool vertical: false
    property bool compact: false
    property real contentScale: 1
    readonly property var feature: content.item
    property var companionPopup: null
    function registerCompanionPopup(popup): void {
        if (!companionPopup) companionPopup = popup
        // The physical Screen Edge module is the pointer source. Descendant
        // MouseAreas must not be able to starve its popup hover request.
        popup.moduleHoverActive = root.hovered
    }
    function unregisterCompanionPopup(popup): void {
        if (companionPopup === popup) companionPopup = null
        popup.moduleHoverActive = false
    }
    readonly property real naturalSpan: {
        const item = feature
        if (!item) return 0
        if (kind === "activeWindow") return vertical ? 48 : Math.min(220,Math.max(60,item.contentImplicitWidth))
        if (kind === "taskbar") return vertical ? Math.max(40,item.dockItems.length*item.itemPitch+item.contentInset)
            : Math.min(320,Math.max(40,item.dockItems.length*item.itemPitch+item.contentInset))
        return vertical ? item.implicitHeight : item.implicitWidth
    }
    readonly property bool hovered: hoverTracker.hovered
    signal interaction(real strength)
    signal request(string kind)
    signal hoverRequest(string kind)
    signal hoverState(string kind, bool hovered)
    HoverHandler {
        id: hoverTracker
        onHoveredChanged: {
            root.interaction(hovered ? .35 : -.15)
            if (root.companionPopup)
                root.companionPopup.moduleHoverActive = hovered
        }
    }
    PointHandler { acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton; onActiveChanged: root.interaction(active ? 1 : -.3) }
    Loader {
        id: content
        anchors.centerIn: parent
        width: root.vertical ? 32*Appearance.fontSizeScale : root.width/Math.max(.01,root.contentScale)
        height: root.vertical ? root.height/Math.max(.01,root.contentScale) : 32*Appearance.fontSizeScale
        scale: root.contentScale
        sourceComponent: root.kind === "resources" ? (root.vertical ? verticalResources : resources)
            : root.kind === "clock" ? (root.vertical ? verticalClock : clock)
            : root.kind === "media" ? (root.vertical ? verticalMedia : media)
            : root.kind === "battery" ? (root.vertical ? verticalBattery : battery)
            : root.kind === "workspaces" ? workspaces : root.kind === "distroIcon" ? distro
            : root.kind === "activeWindow" ? activeWindow : root.kind === "tray" ? tray
            : root.kind === "utilButtons" ? utilities
            : root.kind === "timer" ? timer
            : root.kind === "shellUpdate" ? update : root.kind === "weather" ? weather : taskbar
    }
    Component { id: resources; Shared.Resources {} }
    Component { id: verticalResources; Vertical.Resources {} }
    Component { id: clock; Shared.ClockWidget { showDate: !root.compact && (Config.options?.bar?.verbose ?? true) } }
    Component {
        id: verticalClock
        MouseArea {
            implicitHeight: clock.implicitHeight; implicitWidth: 32
            hoverEnabled: true; acceptedButtons: Qt.NoButton
            Vertical.VerticalClockWidget { id: clock; anchors.fill: parent }
            Shared.ClockCalendarPopup { hoverTarget: parent }
        }
    }
    Component { id: media; Shared.Media { edgeHostedExpansion: true } }
    Component { id: verticalMedia; Vertical.VerticalMedia { edgeHostedExpansion: true } }
    Component { id: battery; Shared.BatteryIndicator {} }
    Component { id: verticalBattery; Vertical.BatteryIndicator {} }
    // Launcher follows the same ownership model as Battery: the source control
    // owns one mature StyledPopup, and Abyss only rehosts that popup into the
    // output field. No GlobalStates generic-popup handoff is involved.
    Component {
        id: distro
        MouseArea {
            id: launcherAnchor
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            implicitWidth: distroIcon.implicitWidth
            implicitHeight: distroIcon.implicitHeight

            Shared.DistroIcon {
                id: distroIcon
                anchors.fill: parent
            }

            Shared.StyledPopup {
                hoverTarget: launcherAnchor
                liquidPresentationKind: "launcher"

                AbyssLauncherControlsPopup {}
            }
        }
    }
    Component { id: activeWindow; Shared.ActiveWindow {} }
    Component {
        id: tray
        Shared.SysTray {
            vertical: root.vertical
            showSeparator: false
            showOverflowMenu: true
            onHoverPopupRequested: kind => root.hoverRequest(kind)
            onConnectivityHoverChanged: (kind, hovered) =>
                root.hoverState(kind, hovered)
        }
    }
    Component {
        id: utilities
        Shared.UtilButtons {
            vertical: root.vertical
            compactRequested: root.compact
            showUtilitiesLauncher:
                Config.options?.bar?.utilButtons?.showUtilitiesLauncher ?? true
            onUtilitiesRequested: root.request("utilities")
            onUtilitiesHoverChanged: hovered => {
                root.hoverState("utilities", hovered)
                if (hovered)
                    root.hoverRequest("utilities")
            }
        }
    }
    Component { id: timer; Shared.TimerIndicator { vertical: root.vertical } }
    Component { id: update; Shared.ShellUpdateIndicator { vertical: root.vertical } }
    Component { id: weather; WeatherBar { vertical: root.vertical } }
    Component {
        id: workspaces
        Shared.Workspaces {
            vertical: root.vertical
            MouseArea {
                anchors.fill: parent; acceptedButtons: Qt.RightButton
                onPressed: GlobalStates.toggleOverview(root.outputName)
            }
        }
    }
    Component { id: taskbar; Shared.BarTaskbar { vertical: root.vertical; barPosition: root.attachedEdge; parentWindow: root.QsWindow.window; slotSize: 32 } }

}
