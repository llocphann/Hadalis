pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.abyss.looks

Item {
    id: root
    required property string kind
    required property string outputName
    property bool vertical: false
    signal request(string kind)
    property bool resourceLease: false
    function syncResources(): void {
        const needed = visible && kind === "resources"
        if (needed === resourceLease) return
        if (needed) ResourceUsage.keepAlive(false,false)
        else ResourceUsage.releaseKeepAlive(false,false)
        resourceLease = needed
    }
    Component.onCompleted: syncResources()
    onVisibleChanged: syncResources()
    Component.onDestruction: if (resourceLease) ResourceUsage.releaseKeepAlive(false,false)
    readonly property string label: {
        switch(kind) {
        case "distroIcon": return "Abyss"
        case "activeWindow": return ToplevelManager.activeToplevel?.title ?? "Desktop"
        case "resources": return "CPU " + Math.round(ResourceUsage.cpuUsage*100) + "% · RAM " + Math.round(ResourceUsage.memoryUsedPercentage*100) + "%"
        case "media": return MprisController.activePlayer?.trackTitle || "No media"
        case "clock": return DateTime.timeDisplay
        case "battery": return Battery.available ? Math.round(Battery.percentage*100)+"%" : "Power"
        case "weather": return Weather.data.temp
        case "timer": return "Timer"
        case "shellUpdate": return "Updates"
        default: return ""
        }
    }
    readonly property string icon: {
        switch(kind) {
        case "leftSidebarButton": return "left_panel_open"
        case "rightSidebarButton": return "right_panel_open"
        case "distroIcon": return "water"
        case "resources": return "monitoring"
        case "media": return MprisController.activePlayer?.isPlaying ? "music_note" : "pause"
        case "clock": return "schedule"
        case "battery": return Battery.isCharging ? "battery_charging_full" : "battery_full"
        case "weather": return "cloud"
        case "utilButtons": return "tune"
        case "timer": return "timer"
        case "shellUpdate": return "system_update"
        case "taskbar": return "apps"
        default: return ""
        }
    }
    Loader {
        anchors.fill: parent
        source: root.kind === "tray" ? "AbyssTray.qml" : ""
        sourceComponent: root.kind === "workspaces" ? workspaceComponent : root.kind === "tray" ? null : buttonComponent
        onLoaded: if (root.kind === "tray") item.vertical = root.vertical
    }
    Component {
        id: workspaceComponent
        AbyssWorkspaces { outputName: root.outputName; vertical: root.vertical }
    }
    Component {
        id: buttonComponent
        AbyssButton {
            text: root.vertical && root.kind === "clock" ? root.label.replace(/:/g,"\n") : root.label
            glyph: root.vertical && root.kind === "clock" ? "" : root.icon
            compact: root.vertical && root.kind !== "clock"
            font.pixelSize: root.vertical && root.kind === "clock" ? AbyssStyle.fontSize*0.8 : AbyssStyle.fontSize
            description: root.label || root.kind
            onClicked: {
                if (root.kind === "leftSidebarButton") ShellLayoutController.toggleSidebarAtSlot("left",root.outputName)
                else if (root.kind === "rightSidebarButton" || root.kind === "utilButtons") ShellLayoutController.toggleSidebarAtSlot("right",root.outputName)
                else if (root.kind === "distroIcon" || root.kind === "taskbar" || root.kind === "activeWindow") GlobalStates.toggleOverview(root.outputName)
                else if (root.kind === "shellUpdate") ShellUpdates.overlayOpen = !ShellUpdates.overlayOpen
                else if (root.kind === "timer") GlobalStates.controlPanelOpen = true
                else root.request(root.kind)
            }
        }
    }
}
