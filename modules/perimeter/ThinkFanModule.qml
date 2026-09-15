import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var perimeterContext: null
    property var instanceConfig: ({})

    readonly property bool vertical:
        (root.perimeterContext?.orientation ?? "horizontal") === "vertical"
    readonly property string statusText: {
        if (ThinkFanService.busy)
            return "…"
        if (!ThinkFanService.stateKnown || !ThinkFanService.available)
            return "—"
        if (ThinkFanService.fanRpm >= 0)
            return String(ThinkFanService.fanRpm)
        return ThinkFanService.active ? "ON" : "FW"
    }

    implicitWidth: statusLoader.item?.implicitWidth ?? 0
    implicitHeight: statusLoader.item?.implicitHeight ?? 0
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: Translation.tr("ThinkFan")
    Accessible.focusable: true

    Keys.onPressed: event => {
        if (event.isAutoRepeat
                || (event.key !== Qt.Key_Return
                    && event.key !== Qt.Key_Enter
                    && event.key !== Qt.Key_Space))
            return
        ThinkFanService.refresh()
        event.accepted = true
    }

    Loader {
        id: statusLoader
        anchors.centerIn: parent
        sourceComponent: root.vertical ? verticalStatus : horizontalStatus
    }

    Component {
        id: horizontalStatus

        RowLayout {
            spacing: 3

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: "mode_fan"
                fill: ThinkFanService.active ? 1 : 0
                iconSize: Appearance.font.pixelSize.normal
                color: ThinkFanService.active
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: root.statusText
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
            }
        }
    }

    Component {
        id: verticalStatus

        ColumnLayout {
            spacing: 1

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "mode_fan"
                fill: ThinkFanService.active ? 1 : 0
                iconSize: Appearance.font.pixelSize.normal
                color: ThinkFanService.active
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.statusText
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ThinkFanService.refresh()
    }
}
