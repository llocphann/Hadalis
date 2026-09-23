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
    property string provenance: ""
    property var samples: []
    property real graphHeight: 28
    property color accentColor: Appearance.colors.colPrimary

    implicitHeight: metricColumn.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        border.color: Qt.rgba(
            root.accentColor.r,
            root.accentColor.g,
            root.accentColor.b,
            0.42)

        ColumnLayout {
            id: metricColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        text: root.title
                        font.weight: Font.DemiBold
                        color: root.accentColor
                        elide: Text.ElideRight
                    }
                    StyledText {
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        visible: root.subtitle.length > 0
                        text: root.subtitle
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }
                }

                StyledText {

                    textFormat: Text.PlainText
                    text: root.valueAvailable
                        ? Math.round(root.numericValue) + "%" : "—"
                    color: root.accentColor
                    font.family: Appearance.font.family.monospace
                    font.weight: Font.DemiBold
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
                    color: root.accentColor
                }
            }

            StyledText {

                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: root.detail
                color: Appearance.colors.colSubtext
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }

            BtopSparkline {
                Layout.fillWidth: true
                Layout.preferredHeight: root.graphHeight
                samples: root.samples
                maxValue: 100
                lineColor: root.accentColor
            }

            StyledText {

                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: root.provenance.length > 0
                    ? root.provenance : "—"
                color: Appearance.colors.colSubtext
                opacity: 0.78
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smallest
                elide: Text.ElideRight
            }
        }
    }
}
