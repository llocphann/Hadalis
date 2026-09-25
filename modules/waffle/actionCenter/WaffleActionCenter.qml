import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs
import qs.modules.common

Scope {
    id: root

    property bool panelMapped: false
    readonly property bool allowMultiplePanels:
        Config.options?.waffles?.behavior?.allowMultiplePanels ?? false

    function enforceExclusivity(): void {
        if (!root.allowMultiplePanels && GlobalStates.waffleActionCenterOpen) {
            GlobalStates.searchOpen = false
            GlobalStates.waffleNotificationCenterOpen = false
            GlobalStates.waffleWidgetsOpen = false
        }
    }

    Component.onCompleted: {
        root.panelMapped = GlobalStates.waffleActionCenterOpen
        root.enforceExclusivity()
    }

    Connections {
        target: GlobalStates
        function onWaffleActionCenterOpenChanged() {
            if (GlobalStates.waffleActionCenterOpen)
                root.panelMapped = true
            root.enforceExclusivity()
        }
    }

    PanelWindow {
        id: actionCenterBackdropWindow
        visible: root.panelMapped
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.namespace: "quickshell:wActionCenterBg"
        WlrLayershell.layer: WlrLayer.Top
        color: "transparent"

        Item { id: emptyActionCenterBackdropInput; width: 0; height: 0 }
        mask: Region {
            item: GlobalStates.waffleActionCenterOpen
                ? actionCenterBackdropMouse : emptyActionCenterBackdropInput
        }

        MouseArea {
            id: actionCenterBackdropMouse
            anchors.fill: parent
            enabled: GlobalStates.waffleActionCenterOpen
            onClicked: GlobalStates.waffleActionCenterOpen = false
        }
    }

    PanelWindow {
        id: panelWindow
        visible: root.panelMapped
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:wactionCenter"
        WlrLayershell.layer: WlrLayer.Overlay
        readonly property bool acceptsInput: GlobalStates.waffleActionCenterOpen
        WlrLayershell.keyboardFocus: panelWindow.acceptsInput
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        Item { id: emptyActionCenterPanelInput; width: 0; height: 0 }
        mask: Region {
            item: panelWindow.acceptsInput ? content : emptyActionCenterPanelInput
        }

        anchors {
            bottom: Config.options?.waffles?.bar?.bottom ?? false
            top: !(Config.options?.waffles?.bar?.bottom ?? false)
            right: true
        }

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        ActionCenterContent {
            id: content
            anchors.fill: parent
            presented: GlobalStates.waffleActionCenterOpen
            panelRightAligned: true
            onClosed: {
                if (!GlobalStates.waffleActionCenterOpen)
                    root.panelMapped = false
            }
        }
    }
}
