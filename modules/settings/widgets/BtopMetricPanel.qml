import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string title: "CPU"
    property string subtitle: ""
    property var value: null
    readonly property real numericValue: Number(root.value)
    readonly property bool valueAvailable:
        root.value !== null
        && root.value !== undefined
        && Number.isFinite(root.numericValue)
    property string detail: ""
    property var samples: []

    implicitHeight: 110

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.color: Appearance.colors.colOutline

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: root.title
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    text: root.valueAvailable
                        ? Math.round(root.numericValue) + "%" : "—"
                    color: Appearance.colors.colPrimary
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 8
                radius: 4
                color: Appearance.colors.colLayer2

                Rectangle {
                    width: root.valueAvailable
                        ? parent.width * Math.max(
                            0, Math.min(1, root.numericValue / 100))
                        : 0
                    height: parent.height
                    radius: parent.radius
                    color: Appearance.colors.colPrimary
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.detail
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }

            Row {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                spacing: 2
                Repeater {
                    model: root.samples
                    Rectangle {
                        width: 4
                        height: 22 * Math.max(0.1, modelData / 100)
                        anchors.bottom: parent.bottom
                        color: Appearance.colors.colPrimary
                        opacity: 0.75
                    }
                }
            }
        }
    }
}
