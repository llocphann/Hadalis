import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.services.deferred
import qs
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root

    property bool panelMapped: false
    readonly property bool allowMultiplePanels:
        Config.options?.waffles?.behavior?.allowMultiplePanels ?? false

    function enforceExclusivity(): void {
        if (!root.allowMultiplePanels && GlobalStates.searchOpen) {
            GlobalStates.waffleActionCenterOpen = false
            GlobalStates.waffleNotificationCenterOpen = false
            GlobalStates.waffleWidgetsOpen = false
        }
    }

    Component.onCompleted: {
        root.panelMapped = GlobalStates.searchOpen
        root.enforceExclusivity()
    }

    Connections {
        target: GlobalStates
        function onSearchOpenChanged() {
            if (GlobalStates.searchOpen)
                root.panelMapped = true
            root.enforceExclusivity()
        }
    }

    // Keep both windows directly in the outer asynchronous OnDemandPanelLoader.
    // A nested Loader with active=true completes this heavyweight start-menu
    // subtree synchronously in the click handler and can stall the render loop.
    PanelWindow {
        visible: root.panelMapped
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.namespace: "quickshell:wStartMenuBg"
        WlrLayershell.layer: WlrLayer.Top
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: GlobalStates.searchOpen = false
        }
    }

    PanelWindow {
        id: panelWindow
        visible: root.panelMapped
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:wStartMenu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: GlobalStates.searchOpen
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        // Adaptive minimum size based on preset
        property string preset: Config.options.waffles?.startMenu?.sizePreset ?? "normal"
        property int minW: preset === "mini" ? 200 : preset === "compact" ? 280 : 360
        property int minH: preset === "mini" ? 200 : preset === "compact" ? 280 : 300

        anchors {
            bottom: Config.options?.waffles?.bar?.bottom ?? true
            top: !(Config.options?.waffles?.bar?.bottom ?? true)
            left: Config.options?.waffles?.bar?.leftAlignApps ?? false
        }

        implicitWidth: Math.max(minW, content.implicitWidth)
        implicitHeight: Math.max(minH, content.implicitHeight)

        StartMenuContent {
            id: content
            anchors.fill: parent
            focus: true
            presented: GlobalStates.searchOpen

            onClosed: {
                if (!GlobalStates.searchOpen)
                    root.panelMapped = false
                LauncherSearch.query = ""
            }
        }
    }
}
