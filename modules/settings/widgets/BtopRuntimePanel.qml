import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string title: "Hadalis runtime"
    property string pid: "—"
    property string cpu: "—"
    property string memory: "—"
    property string memoryLabel: "PSS"
    property string swap: "—"
    property string readRate: "—"
    property string writeRate: "—"
    property string gpu: "—"
    property string gpuMemory: "—"

    implicitHeight: runtimeColumn.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        border.color: Qt.rgba(
            Appearance.colors.colPrimary.r,
            Appearance.colors.colPrimary.g,
            Appearance.colors.colPrimary.b,
            0.42)

        ColumnLayout {
            id: runtimeColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    color: Appearance.colors.colPrimary
                    font.family: Appearance.font.family.monospace
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                StyledText {
                    text: "PID " + root.pid
                    color: Appearance.colors.colPrimary
                    font.family: Appearance.font.family.monospace
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colOutline
                opacity: 0.6
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 520 ? 4 : 2
                columnSpacing: 12
                rowSpacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        text: "CPU"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }
                    StyledText {
                        text: root.cpu
                        color: Appearance.colors.colOnLayer1
                        font.family: Appearance.font.family.monospace
                        font.weight: Font.DemiBold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        text: root.memoryLabel
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }
                    StyledText {
                        text: root.memory
                        color: Appearance.colors.colOnLayer1
                        font.family: Appearance.font.family.monospace
                        font.weight: Font.DemiBold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        text: "GPU"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }
                    StyledText {
                        text: root.gpu
                        color: Appearance.colors.colOnLayer1
                        font.family: Appearance.font.family.monospace
                        font.weight: Font.DemiBold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        text: "GPU RES"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }
                    StyledText {
                        text: root.gpuMemory
                        color: Appearance.colors.colOnLayer1
                        font.family: Appearance.font.family.monospace
                        font.weight: Font.DemiBold
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                StyledText {
                    Layout.fillWidth: true
                    text: "SWAP " + root.swap
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "R " + root.readRate
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "W " + root.writeRate
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }
    }
}
