import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root

    readonly property bool allowMultiplePanels:
        Config.options?.waffles?.behavior?.allowMultiplePanels ?? false

    function enforceExclusivity(): void {
        if (!root.allowMultiplePanels && GlobalStates.waffleWidgetsOpen) {
            GlobalStates.searchOpen = false
            GlobalStates.waffleActionCenterOpen = false
            GlobalStates.waffleNotificationCenterOpen = false
        }
    }

    Component.onCompleted: root.enforceExclusivity()

    Connections {
        target: GlobalStates
        function onWaffleWidgetsOpenChanged() {
            root.enforceExclusivity()
        }
    }

    // This component is already owned by ShellWafflePanelsImpl's asynchronous
    // OnDemandPanelLoader. Keep the windows directly in that incubation tree:
    // a nested Loader with active=true forces the heavy WidgetsContent subtree
    // to finish synchronously on the UI thread when the button is clicked.
    PanelWindow {
        visible: GlobalStates.waffleWidgetsOpen
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.namespace: "quickshell:wWidgetsBg"
        WlrLayershell.layer: WlrLayer.Top
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: GlobalStates.waffleWidgetsOpen = false
        }
    }

    PanelWindow {
        id: panelWindow
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:wWidgets"
        WlrLayershell.layer: WlrLayer.Top
        // Never retain input ownership during the loader's close grace.
        readonly property bool acceptsInput: GlobalStates.waffleWidgetsOpen
        WlrLayershell.keyboardFocus: panelWindow.acceptsInput
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        Item { id: emptyWidgetsPanelInput; width: 0; height: 0 }
        mask: Region {
            item: panelWindow.acceptsInput ? content : emptyWidgetsPanelInput
        }

        anchors {
            bottom: Config.options?.waffles?.bar?.bottom ?? false
            top: !(Config.options?.waffles?.bar?.bottom ?? false)
            left: true
        }

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        WidgetsContent {
            id: content
            anchors.fill: parent
            presented: GlobalStates.waffleWidgetsOpen

            onClosed: GlobalStates.waffleWidgetsOpen = false
        }
    }
}
