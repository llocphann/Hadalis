pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    Layout.fillWidth: true
    implicitHeight: dateTimeRow.implicitHeight + 24
    
    // Reactive property to force date re-evaluation
    property int _tick: 0
    readonly property date _currentDate: { _tick; return new Date() }

    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    border.width: 0
    border.color: "transparent"

    RowLayout {
        id: dateTimeRow
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                text: Qt.formatDateTime(root._currentDate, "dddd")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colPrimary
            }

            StyledText {
                text: Qt.formatDateTime(root._currentDate, "MMMM d, yyyy")
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                text: Translation.tr("Uptime") + ": " + DateTime.uptime
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
            }
        }

        StyledText {
            text: DateTime.time
            font.pixelSize: Appearance.font.pixelSize.huge * 1.5
            font.weight: Font.Light
            font.family: Appearance.font.family.numbers
            color: Appearance.colors.colOnLayer1
        }
    }

    Timer {
        interval: 60000  // Update every minute (day/date don't need second precision)
        running: GlobalStates.controlPanelOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: root._tick++
    }
}
