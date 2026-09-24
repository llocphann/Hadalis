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
    property bool showDetails: false
    property bool compactMode: false
    property var rxSamples: []
    property var txSamples: []
    property real graphHeight: 38
    property bool dottedGraph: false
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

    implicitHeight: networkColumn.implicitHeight
        + (root.compactMode ? 18 : 24)

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        border.color: Qt.rgba(
            root.rxColor.r,
            root.rxColor.g,
            root.rxColor.b,
            root.compactMode ? 0.18 : 0.42)

        ColumnLayout {
            id: networkColumn
            anchors.fill: parent
            anchors.margins: root.compactMode ? 9 : 12
            spacing: root.compactMode ? 5 : 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                StyledText {

                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: root.title
                    color: root.compactMode
                        ? Appearance.colors.colOnLayer1 : root.rxColor
                    font.family: Appearance.font.family.monospace
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                GridLayout {
                    id: rateHeader
                    Layout.fillWidth: true
                    columns: width >= 360 ? 2 : 1
                    columnSpacing: 12
                    rowSpacing: 2

                    StyledText {

                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        text: root.rxPrefix + root.rx
                        color: root.rxColor
                        font.family: Appearance.font.family.monospace
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    StyledText {

                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        horizontalAlignment: rateHeader.width >= 360
                            ? Text.AlignRight : Text.AlignLeft
                        text: root.txPrefix + root.tx
                        color: root.txColor
                        font.family: Appearance.font.family.monospace
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
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

                        textFormat: Text.PlainText
                        text: root.rxLabel
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }

                    BtopSparkline {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: root.graphHeight
                        samples: root.rxSamples
                        dotted: root.dottedGraph
                        maxValue: root.graphMax
                        lineColor: root.rxColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 3

                    StyledText {

                        textFormat: Text.PlainText
                        text: root.txLabel
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }

                    BtopSparkline {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: root.graphHeight
                        samples: root.txSamples
                        dotted: root.dottedGraph
                        maxValue: root.graphMax
                        lineColor: root.txColor
                    }
                }
            }

            GridLayout {
                id: totalsGrid
                Layout.fillWidth: true
                visible: root.showDetails
                    && (root.rxTotal.length > 0
                        || root.txTotal.length > 0)
                columns: width >= 360 ? 2 : 1
                columnSpacing: 12
                rowSpacing: 2

                StyledText {

                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: "Σ " + root.rxLabel + " "
                        + (root.rxTotal || "—")
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    elide: Text.ElideRight
                }

                StyledText {

                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    horizontalAlignment: totalsGrid.width >= 360
                        ? Text.AlignRight : Text.AlignLeft
                    text: "Σ " + root.txLabel + " "
                        + (root.txTotal || "—")
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    elide: Text.ElideRight
                }
            }

            StyledText {

                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: root.showDetails
                    && root.provenance.length > 0
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
