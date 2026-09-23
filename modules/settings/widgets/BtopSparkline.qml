import QtQuick
import qs.modules.common

Item {
    id: root

    property var samples: []
    property real maxValue: 100
    property color lineColor: Appearance.colors.colPrimary

    implicitHeight: 34

    Row {
        id: sparkRow
        anchors.fill: parent
        spacing: root.samples.length > 0
            && width / root.samples.length < 3 ? 0 : 1
        clip: true

        Repeater {
            model: root.samples

            Rectangle {
                width: root.samples.length > 0
                    ? Math.max(0.5,
                        (sparkRow.width
                            - sparkRow.spacing
                                * Math.max(0, root.samples.length - 1))
                        / root.samples.length)
                    : 0
                height: Math.max(1, sparkRow.height * Math.min(1,
                    Math.max(0, Number(modelData) / Math.max(1, root.maxValue))))
                anchors.bottom: parent.bottom
                radius: 1
                color: root.lineColor
                opacity: 0.8
            }
        }
    }
}
