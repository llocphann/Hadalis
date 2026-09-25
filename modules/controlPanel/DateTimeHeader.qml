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
    
    // Reuse the shell-wide minute epoch while this panel is visible. The
    // conditional binding drops the dependency while closed, so the header
    // neither owns a timer nor recomputes hidden date text.
    readonly property int _minuteEpoch: GlobalStates.controlPanelOpen ? DateTime.minuteEpoch : 0
    readonly property date _currentDate: { root._minuteEpoch; return new Date() }

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

}
