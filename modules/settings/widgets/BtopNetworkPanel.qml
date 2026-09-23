import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string title: "Network"
    property string rx: "—"
    property string tx: "—"
    property var rxSamples: []
    property var txSamples: []

    implicitHeight: 120

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
                    color: Appearance.colors.colOnLayer1
                    font.weight: Font.DemiDemiBold
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    text: "↓ " + root.rx + "   ↑ " + root.tx
                    color: Appearance.colors.colPrimary
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: "RX"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                    BtopSparkline {
                        Layout.fillWidth: true
                        samples: root.rxSamples
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: "TX"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                    BtopSparkline {
                        Layout.fillWidth: true
                        samples: root.txSamples
                    }
                }
            }
        }
    }
}
