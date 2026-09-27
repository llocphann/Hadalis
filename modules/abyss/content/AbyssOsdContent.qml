pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root
    property string outputName: ""
    property string indicatorKind: GlobalStates.abyssOsdKind
    readonly property var output: Quickshell.screens.find(s => s.name === outputName) ?? null
    readonly property var feature: indicator.item
    readonly property real desiredWidth: Math.max(indicator.implicitWidth,message.visible ? message.implicitWidth : 0)
    readonly property real desiredHeight: indicator.implicitHeight+(message.visible ? message.implicitHeight+spacing : 0)
    implicitWidth: desiredWidth
    implicitHeight: desiredHeight
    spacing: 8
    // Preserve the mature icon, dimensions and controls; the field paints the shell.
    Loader {
        id: indicator
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        source: "../../onScreenDisplay/indicators/"+({volume:"Volume",brightness:"Brightness",mic:"Mic",
            media:"Media",keyboardLayout:"KeyboardLayout",voiceSearch:"VoiceSearch"}[root.indicatorKind] ?? "Volume")+"Indicator.qml"
        onLoaded: {
            item.connectedSurface = true
            if (root.indicatorKind === "brightness") item.screen = Qt.binding(() => root.output ?? root.QsWindow.window?.screen)
        }
    }
    StyledText {
        id: message
        Layout.fillWidth: true
        visible: GlobalStates.abyssOsdMessage.length > 0
        text: GlobalStates.abyssOsdMessage
        color: Appearance.colors.colError
        wrapMode: Text.WordWrap
    }
}
