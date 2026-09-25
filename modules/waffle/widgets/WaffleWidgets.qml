import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root

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
        // Never retain the compositor-wide exclusive keyboard grab during the
        // close tail. The panel still receives Escape while it is presented.
        WlrLayershell.keyboardFocus: GlobalStates.waffleWidgetsOpen
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            bottom: Config.options?.waffles?.bar?.bottom ?? false
            top: !(Config.options?.waffles?.bar?.bottom ?? false)
            left: true
        }

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        Connections {
            target: GlobalStates
            function onWaffleWidgetsOpenChanged() {
                if (!GlobalStates.waffleWidgetsOpen)
                    content.close()
            }
        }

        WidgetsContent {
            id: content
            anchors.fill: parent

            onClosed: GlobalStates.waffleWidgetsOpen = false
        }
    }
}
