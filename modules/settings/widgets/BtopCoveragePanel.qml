import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var boundaryCounts: ({})
    property string status: "idle"
    property int filesScanned: 0
    property int cacheHits: 0

    readonly property var rows: [
        { key: "lifecycle", label: "Lifecycle" },
        { key: "process", label: "Process" },
        { key: "timer", label: "Timer" },
        { key: "network", label: "Network" },
        { key: "file-view", label: "File view" },
        { key: "file-watcher", label: "File watcher" },
        { key: "dynamic-component", label: "Dynamic component" },
        { key: "dynamic-qml-object", label: "Dynamic QML" },
        { key: "dynamic-loader-source", label: "Dynamic loader" }
    ]

    function countFor(key): int {
        const value = Number(root.boundaryCounts
            ? (root.boundaryCounts[key] ?? 0) : 0)
        return Number.isFinite(value) ? Math.max(0, value) : 0
    }

    readonly property int maxCount: {
        let peak = 1
        for (const row of root.rows)
            peak = Math.max(peak, root.countFor(row.key))
        return peak
    }

    implicitHeight: coverageColumn.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        border.color: Qt.rgba(
            Appearance.colors.colSecondary.r,
            Appearance.colors.colSecondary.g,
            Appearance.colors.colSecondary.b,
            0.34)

        ColumnLayout {
            id: coverageColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 7

            RowLayout {
                Layout.fillWidth: true

                StyledText {

                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: "Runtime boundary coverage"
                    color: Appearance.colors.colSecondary
                    font.weight: Font.DemiBold
                }

                StyledText {

                    textFormat: Text.PlainText
                    text: root.status
                    color: root.status === "ready"
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }

            Repeater {
                model: root.rows

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    readonly property int rowCount:
                        root.countFor(modelData.key)

                    StyledText {

                        textFormat: Text.PlainText
                        Layout.preferredWidth: 126
                        text: modelData.label
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Appearance.colors.colLayer2

                        Rectangle {
                            width: parent.width
                                * Math.max(0, Math.min(1,
                                    parent.parent.rowCount
                                        / Math.max(1, root.maxCount)))
                            height: parent.height
                            radius: parent.radius
                            color: Appearance.colors.colSecondary
                        }
                    }

                    StyledText {

                        textFormat: Text.PlainText
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                        text: String(parent.rowCount)
                        color: Appearance.colors.colOnLayer1
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }

            StyledText {

                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: String(root.filesScanned) + " QML · "
                    + String(root.cacheHits) + " cached"
                color: Appearance.colors.colSubtext
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smallest
            }
        }
    }
}
