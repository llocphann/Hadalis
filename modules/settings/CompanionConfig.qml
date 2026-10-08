import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property bool embedded: false
    property string activeSection: "overview"
    readonly property int settingsPageIndex: 37
    readonly property string settingsPageName: Translation.tr("Companion")
    readonly property var settingsTaskNavigator: settingsLoader.item?.settingsTaskNavigator ?? null
    implicitHeight: embedded ? (settingsLoader.item?.implicitHeight ?? missing.implicitHeight) : 0
    Loader {
        id: settingsLoader
        anchors.fill: parent
        active: Hadanion.available
        source: Hadanion.settingsSource
        Binding { target: settingsLoader.item; property: "embedded"; value: root.embedded; when: !!settingsLoader.item }
        Binding { target: settingsLoader.item; property: "activeSection"; value: root.activeSection; when: !!settingsLoader.item }
    }
    ColumnLayout {
        id: missing
        visible: !Hadanion.available
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 24 }
        spacing: 16
        StyledText { text: "Companion is available separately as Hadanion."; wrapMode: Text.Wrap; Layout.fillWidth: true }
        RowLayout {
            DialogButton { buttonText: "Get Hadanion"; onClicked: Qt.openUrlExternally("https://github.com/llocphann/Hadanion") }
            DialogButton { buttonText: "Check installation"; onClicked: Hadanion.refresh() }
        }
    }
}
