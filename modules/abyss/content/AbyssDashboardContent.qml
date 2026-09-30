import QtQuick
import QtQuick.Layouts
import qs.modules.dashboard

Item {
    id: root
    property var participant: null
    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        DashboardEditToolbar {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: root.width
            canvasController: content.canvasController
        }
        DashboardContent {
            id: content
            Layout.fillWidth: true; Layout.fillHeight: true
            embeddedSurface: true
            presentationActive: root.participant?.open ?? true
            screenWidth: root.participant?.width ?? 1920
            screenHeight: root.participant?.height ?? 1080
        }
    }
}
