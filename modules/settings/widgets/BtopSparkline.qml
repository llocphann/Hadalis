import QtQuick
import qs.modules.common

Item {
    id: root

    property var samples: []
    property real maxValue: 100
    property color lineColor: Appearance.colors.colPrimary

    implicitHeight: 34

    Row {
        anchors.fill: parent
        spacing: 1
        Repeater {
            model: root.samples

            Rectangle {
                width: root.samples.length > 0
                    ? Math.max(1, parent.width / root.samples.length)
                    : 0
                height: Math.max(1, parent.height * Math.min(1,
                    Math.max(0, Number(modelData) / Math.max(1, root.maxValue))))
                anchors.bottom: parent.bottom
                color: root.lineColor
                opacity: 0.8
            }
        }
    }
}
