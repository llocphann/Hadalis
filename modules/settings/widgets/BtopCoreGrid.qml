import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var cores: []
    property var coreNames: []
    property var history: []
    property int columns: 4
    property bool compact: false

    function coreLabel(index): string {
        const raw = Array.isArray(root.coreNames)
            && index >= 0 && index < root.coreNames.length
            ? String(root.coreNames[index]) : ""
        if (raw.startsWith("cpu"))
            return "C" + raw.slice(3)
        return raw.length > 0 ? raw : "C" + index
    }

    function samplesForCore(index): var {
        const name = Array.isArray(root.coreNames)
            ? String(root.coreNames[index] ?? "") : ""
        if (name.length === 0)
            return []
        const points = Array.isArray(root.history) ? root.history : []
        return points.map(point => {
            const names = Array.isArray(point?.coreNames)
                ? point.coreNames : []
            const values = Array.isArray(point?.coresPercent)
                ? point.coresPercent : []
            const position = names.indexOf(name)
            if (position < 0 || position >= values.length)
                return null
            const raw = values[position]
            if (raw === null || raw === undefined)
                return null
            const value = Number(raw)
            return Number.isFinite(value)
                ? Math.max(0, Math.min(100, value)) : null
        })
    }

    implicitHeight: grid.implicitHeight

    GridLayout {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        columns: Math.max(1, root.columns)
        columnSpacing: 8
        rowSpacing: root.compact ? 2 : 6

        Repeater {
            model: root.cores

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.compact ? 26 : 74
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1
                border.color: Qt.rgba(
                    Appearance.colors.colPrimary.r,
                    Appearance.colors.colPrimary.g,
                    Appearance.colors.colPrimary.b,
                    0.30)

                ColumnLayout {
                    visible: !root.compact
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {

                            textFormat: Text.PlainText
                            text: root.coreLabel(index)
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }

                        Item { Layout.fillWidth: true }

                        StyledText {

                            textFormat: Text.PlainText
                            text: modelData !== null
                                && modelData !== undefined
                                && Number.isFinite(Number(modelData))
                                ? Math.round(Number(modelData)) + "%" : "—"
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colPrimary
                        }
                    }

                    BtopSparkline {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        samples: root.samplesForCore(index)
                        maxValue: 100
                        lineColor: Appearance.colors.colPrimary
                        fillGraph: false
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

                RowLayout {
                    visible: root.compact
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 6

                    StyledText {
                        textFormat: Text.PlainText
                        Layout.preferredWidth: 24
                        text: root.coreLabel(index)
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }

                    BtopSparkline {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14
                        samples: root.samplesForCore(index)
                        dotted: true
                        maxValue: 100
                        lineColor: Appearance.colors.colPrimary
                        fillGraph: false
                    }

                    StyledText {
                        textFormat: Text.PlainText
                        Layout.preferredWidth: 34
                        horizontalAlignment: Text.AlignRight
                        text: modelData !== null
                            && modelData !== undefined
                            && Number.isFinite(Number(modelData))
                            ? Math.round(Number(modelData)) + "%" : "—"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colPrimary
                    }
                }
            }
        }
    }
}
