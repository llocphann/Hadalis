import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property var processes: []
    property int maxRows: 12
    property bool compactMode: false
    readonly property bool showPidColumn: !root.compactMode && width >= 420
    readonly property bool showSwapColumn: !root.compactMode && width >= 520
    readonly property var processRows:
        Array.isArray(root.processes) ? root.processes : []
    readonly property var visibleProcesses:
        root.processRows.slice(0, Math.max(0, root.maxRows))
    readonly property var processDepths: root.buildProcessDepths()

    function buildProcessDepths(): var {
        const byPid = ({})
        for (const item of root.processRows) {
            const pid = String(item?.pid ?? "")
            if (pid.length > 0)
                byPid[pid] = item
        }
        const depths = ({})
        for (const item of root.processRows) {
            const pid = String(item?.pid ?? "")
            if (pid.length === 0)
                continue
            let depth = 0
            let parent = String(item?.parentPid ?? "")
            const seen = ({})
            while (parent.length > 0 && byPid[parent] && !seen[parent]) {
                seen[parent] = true
                depth++
                parent = String(byPid[parent]?.parentPid ?? "")
            }
            depths[pid] = depth
        }
        return depths
    }
    function depthFor(process): int {
        const depth = Number(root.processDepths[String(process?.pid ?? "")] ?? 0)
        return Number.isFinite(depth) ? Math.max(0, depth) : 0
    }
    function formatPercent(value): string {
        if (value === null || value === undefined)
            return "—"
        const number = Number(value)
        return Number.isFinite(number) ? number.toFixed(1) + "%" : "—"
    }
    function cpuFraction(process): real {
        const value = Number(process?.cpu?.percent)
        return Number.isFinite(value)
            ? Math.max(0, Math.min(1, value / 100)) : 0
    }
    function formatKiB(value): string {
        if (value === null || value === undefined)
            return "—"
        const kib = Number(value)
        if (!Number.isFinite(kib) || kib < 0)
            return "—"
        if (kib >= 1024 * 1024)
            return (kib / (1024 * 1024)).toFixed(2) + " GiB"
        if (kib >= 1024)
            return (kib / 1024).toFixed(1) + " MiB"
        return kib.toFixed(0) + " KiB"
    }

    implicitHeight: processColumn.implicitHeight + (root.compactMode ? 16 : 24)

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: root.compactMode ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
        border.width: 1
        border.color: Qt.rgba(
            Appearance.colors.colPrimary.r,
            Appearance.colors.colPrimary.g,
            Appearance.colors.colPrimary.b,
            root.compactMode ? 0.16 : 0.34)

        ColumnLayout {
            id: processColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.compactMode ? 8 : 12
            spacing: 0

            StyledText {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: root.compactMode
                    ? Translation.tr("Top helper processes")
                    : Translation.tr("Shell descendants")
                color: Appearance.colors.colOnLayer1
                font.weight: Font.DemiBold
            }
            StyledText {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: root.compactMode
                Layout.bottomMargin: 5
                text: Translation.tr("Kernel process CPU · RSS")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
                elide: Text.ElideRight
            }

            RowLayout {
                visible: !root.compactMode
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                Layout.topMargin: 7
                spacing: 8
                StyledText {
                    textFormat: Text.PlainText
                    visible: root.showPidColumn
                    Layout.preferredWidth: 64
                    text: "PID"
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }
                StyledText {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: "COMM"
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }
                StyledText {
                    textFormat: Text.PlainText
                    Layout.preferredWidth: 72
                    horizontalAlignment: Text.AlignRight
                    text: "CPU"
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }
                StyledText {
                    textFormat: Text.PlainText
                    Layout.preferredWidth: 86
                    horizontalAlignment: Text.AlignRight
                    text: "RSS"
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }
                StyledText {
                    textFormat: Text.PlainText
                    visible: root.showSwapColumn
                    Layout.preferredWidth: 86
                    horizontalAlignment: Text.AlignRight
                    text: "SWAP"
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }
            }
            Rectangle {
                Layout.fillWidth: true
                visible: !root.compactMode
                height: 1
                color: Appearance.colors.colOutline
                opacity: 0.65
            }

            Repeater {
                model: root.visibleProcesses
                delegate: Item {
                    id: processRow
                    Layout.fillWidth: true
                    implicitHeight: 38
                    required property var modelData
                    required property int index
                    readonly property int processDepth: root.depthFor(processRow.modelData)

                    RowLayout {
                        visible: root.compactMode
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: 34
                        spacing: 7
                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: 6
                            color: Appearance.colors.colLayer1
                            StyledText {
                                anchors.centerIn: parent
                                textFormat: Text.PlainText
                                text: String(processRow.index + 1)
                                color: Appearance.colors.colPrimary
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -2
                            StyledText {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                text: String(processRow.modelData?.command ?? "—")
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                elide: Text.ElideMiddle
                            }
                            StyledText {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                text: "PID " + String(processRow.modelData?.pid ?? "—")
                                color: Appearance.colors.colSubtext
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.smallest
                            }
                        }
                        ColumnLayout {
                            Layout.preferredWidth: 76
                            spacing: 2
                            StyledText {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: "CPU " + root.formatPercent(
                                    processRow.modelData?.cpu?.percent)
                                color: Appearance.colors.colPrimary
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 3
                                radius: 2
                                color: Appearance.colors.colLayer1
                                Rectangle {
                                    width: parent.width * root.cpuFraction(processRow.modelData)
                                    height: parent.height
                                    radius: parent.radius
                                    color: Appearance.colors.colPrimary
                                }
                            }
                        }
                        StyledText {
                            textFormat: Text.PlainText
                            Layout.preferredWidth: 92
                            horizontalAlignment: Text.AlignRight
                            text: "RSS " + root.formatKiB(
                                processRow.modelData?.memory?.valuesKiB?.Rss)
                            color: Appearance.colors.colSubtext
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.smallest
                        }
                    }

                    RowLayout {
                        visible: !root.compactMode
                        anchors.fill: parent
                        spacing: 8
                        StyledText {
                            textFormat: Text.PlainText
                            visible: root.showPidColumn
                            Layout.preferredWidth: 64
                            text: String(processRow.modelData?.pid ?? "—")
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                        StyledText {
                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            text: "  ".repeat(processRow.processDepth)
                                + (processRow.processDepth > 0 ? "↳ " : "")
                                + String(processRow.modelData?.command ?? "—")
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideMiddle
                        }
                        StyledText {
                            textFormat: Text.PlainText
                            Layout.preferredWidth: 72
                            horizontalAlignment: Text.AlignRight
                            text: root.formatPercent(processRow.modelData?.cpu?.percent)
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colPrimary
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                        StyledText {
                            textFormat: Text.PlainText
                            Layout.preferredWidth: 86
                            horizontalAlignment: Text.AlignRight
                            text: root.formatKiB(
                                processRow.modelData?.memory?.valuesKiB?.Rss)
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                        StyledText {
                            textFormat: Text.PlainText
                            visible: root.showSwapColumn
                            Layout.preferredWidth: 86
                            horizontalAlignment: Text.AlignRight
                            text: root.formatKiB(
                                processRow.modelData?.memory?.valuesKiB?.Swap)
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        visible: !root.compactMode
                        height: 1
                        color: Appearance.colors.colOutline
                        opacity: 0.35
                    }
                }
            }

            StyledText {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: root.processRows.length === 0
                Layout.topMargin: root.compactMode ? 6 : 10
                text: Translation.tr("No shell child processes")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
            StyledText {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: root.processRows.length > root.visibleProcesses.length
                Layout.topMargin: 3
                text: "+" + String(root.processRows.length - root.visibleProcesses.length)
                    + " " + Translation.tr("more processes")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
            }
            StyledText {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: !root.compactMode
                Layout.topMargin: 8
                text: "/proc/<pid>/comm · task schedstat · /proc/<pid>/status"
                color: Appearance.colors.colSubtext
                opacity: 0.78
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smallest
                elide: Text.ElideRight
            }
        }
    }
}
