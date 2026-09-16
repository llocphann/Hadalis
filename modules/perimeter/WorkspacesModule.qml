import qs.modules.bar
import QtQuick

Item {
    id: root

    property var perimeterContext: null
    property var instanceConfig: ({})

    readonly property bool presented: PerimeterPresentationPolicy.barPresented
    readonly property bool vertical:
        (root.perimeterContext?.orientation ?? "horizontal") === "vertical"

    implicitWidth: root.presented ? workspaces.implicitWidth : 0
    implicitHeight: root.presented ? workspaces.implicitHeight : 0
    visible: root.presented
    enabled: root.presented

    Workspaces {
        id: workspaces
        anchors.centerIn: parent
        vertical: root.vertical
    }
}
