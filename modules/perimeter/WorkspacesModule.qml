import qs.modules.bar
import QtQuick

Item {
    id: root

    property var perimeterContext: null
    property var instanceConfig: ({})

    readonly property bool vertical:
        (root.perimeterContext?.orientation ?? "horizontal") === "vertical"

    implicitWidth: workspaces.implicitWidth
    implicitHeight: workspaces.implicitHeight

    Workspaces {
        id: workspaces
        anchors.centerIn: parent
        vertical: root.vertical
    }
}
