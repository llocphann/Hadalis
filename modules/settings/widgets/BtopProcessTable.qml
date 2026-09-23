import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var processes: []
    property int maxRows: 12
    readonly property bool showSwapColumn: width >= 520

    readonly property var processDepths: root.buildProcessDepths()

    function buildProcessDepths(): var {
        const byPid = ({})
        for (const item of root.processes ?? []) {
            const pid = String(item?.pid ?? "")
            if (pid.length > 0)
                byPid[pid] = item
        }

        const depths = ({})
        for (const item of root.processes ?? []) {
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
        const pid = String(process?.pid ?? "")
        const depth = Number(root.processDepths[pid] ?? 0)
        return Number.isFinite(depth) ? Math.max(0, depth) : 0
    }

    function formatPercent(value): string {
        if (value === null || value === undefined)
            return "—"
        const number = Number(value)
        return Number.isFinite(number) ? number.toFixed(1) + "%" : "—"
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

    readonly property var visibleProcesses:
        Array.isArray(root.processes)
            ? root.processes.slice(0, Math.max(0, root.maxRows))
            : []

    implicitHeight: processColumn.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        border.color: Qt.rgba(
            Appearance.colors.colPrimary.r,
            Appearance.colors.colPrimary.g,
            Appearance.colors.colPrimary.b,
            0.34)

        ColumnLayout {
            id: processColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 8

                StyledText {

                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: "Shell descendants"
                    color: Appearance.colors.colOnLayer1
                    font.weight: Font.DemiBold
                }

                StyledText {

                    textFormat: Text.PlainText
                    text: String(root.processes.length)
                    color: Appearance.colors.colPrimary
                    font.weight: Font.DemiBold
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                spacing: 8

                StyledText {

                    textFormat: Text.PlainText
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
                height: 1
                color: Appearance.colors.colOutline
                opacity: 0.65
            }

            Repeater {
                model: root.visibleProcesses

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 38

                    readonly property var process: modelData
                    readonly property int processDepth:
                        root.depthFor(process)

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        StyledText {

                            textFormat: Text.PlainText
                            Layout.preferredWidth: 64
                            text: String(parent.parent.process?.pid ?? "—")
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        StyledText {

                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            text: "  ".repeat(
                                    parent.parent.processDepth)
                                + (parent.parent.processDepth > 0
                                    ? "↳ " : "")
                                + String(parent.parent.process?.command ?? "—")
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideMiddle
                        }

                        StyledText {

                            textFormat: Text.PlainText
                            Layout.preferredWidth: 72
                            horizontalAlignment: Text.AlignRight
                            text: root.formatPercent(
                                parent.parent.process?.cpu?.percent)
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colPrimary
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        StyledText {

                            textFormat: Text.PlainText
                            Layout.preferredWidth: 86
                            horizontalAlignment: Text.AlignRight
                            text: root.formatKiB(
                                parent.parent.process?.memory
                                    ?.valuesKiB?.Rss)
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
                                parent.parent.process?.memory
                                    ?.valuesKiB?.Swap)
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Appearance.colors.colOutline
                        opacity: 0.35
                    }
                }
            }

            StyledText {

                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: root.processes.length === 0
                Layout.topMargin: 10
                text: "No shell child processes"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {

                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: root.processes.length > root.visibleProcesses.length
                Layout.topMargin: 8
                text: "+" + String(
                    root.processes.length - root.visibleProcesses.length)
                    + " more processes"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {

                textFormat: Text.PlainText
                Layout.fillWidth: true
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
