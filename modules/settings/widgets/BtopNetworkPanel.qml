import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string title: "Network"
    property string rxLabel: "RX"
    property string txLabel: "TX"
    property string rxPrefix: "↓ "
    property string txPrefix: "↑ "
    property string rx: "—"
    property string tx: "—"
    property string rxTotal: ""
    property string txTotal: ""
    property string provenance: ""
    property var rxSamples: []
    property var txSamples: []
    property color rxColor: Appearance.colors.colPrimary
    property color txColor: Appearance.colors.colSecondary

    function peak(samples): real {
        let result = 1
        for (const sample of samples ?? []) {
            if (sample === null || sample === undefined)
                continue
            const value = Number(sample)
            if (Number.isFinite(value))
                result = Math.max(result, value)
        }
        return result
    }

    readonly property real graphMax: Math.max(
        root.peak(root.rxSamples),
        root.peak(root.txSamples))

    implicitHeight: networkColumn.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.color: Qt.rgba(
            root.rxColor.r,
            root.rxColor.g,
            root.rxColor.b,
            0.42)

        ColumnLayout {
            id: networkColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: root.title
                    color: root.rxColor
                    font.family: Appearance.font.family.monospace
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: root.rxPrefix + root.rx
                    color: root.rxColor
                    font.weight: Font.DemiBold
                }

                StyledText {
                    text: root.txPrefix + root.tx
                    color: root.txColor
                    font.family: Appearance.font.family.monospace
                    font.weight: Font.DemiBold
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 3

                    StyledText {
                        text: root.rxLabel
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }

                    BtopSparkline {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        samples: root.rxSamples
                        maxValue: root.graphMax
                        lineColor: root.rxColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 3

                    StyledText {
                        text: root.txLabel
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }

                    BtopSparkline {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        samples: root.txSamples
                        maxValue: root.graphMax
                        lineColor: root.txColor
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.rxTotal.length > 0
                    || root.txTotal.length > 0

                StyledText {
                    Layout.fillWidth: true
                    text: "Σ " + root.rxLabel + " "
                        + (root.rxTotal || "—")
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: "Σ " + root.txLabel + " "
                        + (root.txTotal || "—")
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    elide: Text.ElideLeft
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.provenance.length > 0
                text: root.provenance
                color: Appearance.colors.colSubtext
                opacity: 0.78
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smallest
                elide: Text.ElideRight
            }
        }
    }
}
