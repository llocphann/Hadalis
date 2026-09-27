pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.dock
import "../looks/AbyssWave.js" as Wave

// Keep the existing app model, menus, preview, launch and drag/reorder behavior.
// Only the surrounding shell is supplied by the output's field.
Item {
    id: root
    property string outputName: ""
    property string edge: "bottom"
    property var participant: null
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property real desiredSpan: (vertical ? content.implicitHeight : content.implicitWidth) + 24
    readonly property bool requestDockShow: apps.requestDockShow
    readonly property var appContent: apps
    function react(position, strength): void {
        if (!participant?.controller) return
        const point = root.mapToItem(participant, position.x, position.y)
        participant.controller.impulse(edge, vertical ? point.y : point.x, 50,
            strength * Wave.bodyStrength(Config.options?.abyss?.waves), 1, "module")
    }
    HoverHandler {
        onHoveredChanged: root.react(point.position, hovered ? .4 : -.15)
    }
    PointHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onActiveChanged: root.react(point.position, active ? 1 : -.3)
    }
    GridLayout {
        id: content
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        rowSpacing: 2; columnSpacing: 2
        DockApps {
            id: apps
            vertical: root.vertical
            dockPosition: root.edge
            parentWindow: root.QsWindow.window
            Layout.preferredHeight: root.vertical ? implicitHeight : 50
            Layout.preferredWidth: root.vertical ? 50 : implicitWidth
        }
        DockButton {
            vertical: root.vertical
            onClicked: GlobalStates.toggleOverview(root.outputName)
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "apps"
                iconSize: 25
                color: Appearance.colors.colOnLayer0
            }
        }
    }
}
