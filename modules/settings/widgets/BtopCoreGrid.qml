import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var cores: []
    property int columns: 4

    implicitHeight: grid.implicitHeight

    GridLayout {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        columns: Math.max(1, root.columns)
        columnSpacing: 8
        rowSpacing: 6

        Repeater {
            model: root.cores

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1
                border.color: Appearance.colors.colOutline

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {
                            text: "C" + index
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }

                        Item { Layout.fillWidth: true }

                        StyledText {
                            text: modelData !== null
                                && modelData !== undefined
                                && Number.isFinite(Number(modelData))
                                ? Math.round(Number(modelData)) + "%" : "—"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Appearance.colors.colLayer2

                        Rectangle {
                            width: modelData !== null
                                && modelData !== undefined
                                && Number.isFinite(Number(modelData))
                                ? parent.width * Math.max(
                                    0, Math.min(1, Number(modelData) / 100))
                                : 0
                            height: parent.height
                            radius: parent.radius
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }
        }
    }
}
