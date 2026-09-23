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
        anchors.fill: parent
        columns: root.columns
        columnSpacing: 8
        rowSpacing: 6

        Repeater {
            model: root.cores

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1
                border.color: Appearance.colors.colOutline

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 1

                    StyledText {
                        text: "C" + index
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 5
                        radius: 3
                        color: Appearance.colors.colLayer2

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, Number(modelData) / 100))
                            height: parent.height
                            radius: parent.radius
                            color: Appearance.colors.colPrimary
                        }
                    }

                    StyledText {
                        text: Math.round(Number(modelData)) + "%"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
        }
    }
}
