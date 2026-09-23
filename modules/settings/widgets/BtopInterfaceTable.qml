import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var interfaces: ({})
    property bool includeLoopback: false
    readonly property bool showTotalColumn: width >= 520

    function formatRate(value): string {
        if (value === null || value === undefined)
            return "—"
        const bytes = Number(value)
        if (!Number.isFinite(bytes) || bytes < 0)
            return "—"
        if (bytes >= 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GiB/s"
        if (bytes >= 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MiB/s"
        if (bytes >= 1024)
            return (bytes / 1024).toFixed(1) + " KiB/s"
        return bytes.toFixed(0) + " B/s"
    }

    function formatBytes(value): string {
        if (value === null || value === undefined)
            return "—"
        const bytes = Number(value)
        if (!Number.isFinite(bytes) || bytes < 0)
            return "—"
        if (bytes >= 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GiB"
        if (bytes >= 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MiB"
        if (bytes >= 1024)
            return (bytes / 1024).toFixed(1) + " KiB"
        return bytes.toFixed(0) + " B"
    }

    readonly property var rows: {
        const source = root.interfaces ?? ({})
        const result = []
        for (const name of Object.keys(source)) {
            if (!root.includeLoopback && name === "lo")
                continue
            const data = source[name] ?? ({})
            const rxRate = data.rxBytesPerSec === null
                    || data.rxBytesPerSec === undefined
                ? null : Number(data.rxBytesPerSec)
            const txRate = data.txBytesPerSec === null
                    || data.txBytesPerSec === undefined
                ? null : Number(data.txBytesPerSec)
            result.push({
                name: name,
                rxBytes: Number(data.rxBytes ?? 0),
                txBytes: Number(data.txBytes ?? 0),
                rxBytesPerSec: rxRate !== null
                    && Number.isFinite(rxRate) ? rxRate : null,
                txBytesPerSec: txRate !== null
                    && Number.isFinite(txRate) ? txRate : null,
                activity: (rxRate !== null && Number.isFinite(rxRate)
                        ? rxRate : 0)
                    + (txRate !== null && Number.isFinite(txRate)
                        ? txRate : 0)
            })
        }
        result.sort((left, right) =>
            right.activity - left.activity
                || String(left.name).localeCompare(String(right.name)))
        return result
    }

    implicitHeight: interfaceColumn.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.color: Appearance.colors.colOutline

        ColumnLayout {
            id: interfaceColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 8

                StyledText {
                    Layout.fillWidth: true
                    text: "Interfaces"
                    color: Appearance.colors.colOnLayer1
                    font.weight: Font.DemiBold
                }

                StyledText {
                    text: String(root.rows.length)
                    color: Appearance.colors.colPrimary
                    font.weight: Font.DemiBold
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1.2
                    text: "IFACE"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: "RX"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: "TX"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }

                StyledText {
                    visible: root.showTotalColumn
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: "TOTAL"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colOutline
                opacity: 0.65
            }

            Repeater {
                model: root.rows

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    spacing: 8

                    StyledText {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1.2
                        text: String(modelData.name)
                        color: Appearance.colors.colOnLayer1
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: "↓ " + root.formatRate(
                            modelData.rxBytesPerSec)
                        color: Appearance.colors.colPrimary
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideLeft
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: "↑ " + root.formatRate(
                            modelData.txBytesPerSec)
                        color: Appearance.colors.colSecondary
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideLeft
                    }

                    StyledText {
                        visible: root.showTotalColumn
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: root.formatBytes(
                            modelData.rxBytes + modelData.txBytes)
                        color: Appearance.colors.colSubtext
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideLeft
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.rows.length === 0
                Layout.topMargin: 8
                text: "No non-loopback interfaces"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }
}
