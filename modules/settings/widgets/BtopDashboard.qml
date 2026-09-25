import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// One presentation of shell-owned evidence for both Settings families. The
// process table contains shell descendants; target rows use Workflow identity
// and never inherit process metrics without reviewed ownership evidence.
ColumnLayout {
    id: root

    property var evidence: null
    property var targets: []
    property var records: []
    property var events: []
    property string selectedTargetId: ""
    property bool compactMode: false
    property bool showDetails: false
    signal targetActivated(string targetId, string instanceId)

    readonly property var systemEvidence: root.evidence?.system ?? null
    readonly property var shellEvidence: root.evidence?.shell ?? null
    readonly property var networkEvidence: root.evidence?.network ?? null
    readonly property var cpuCores:
        root.systemEvidence?.cpu?.coresPercent ?? []
    readonly property var cpuCoreNames:
        root.systemEvidence?.cpu?.coreNames ?? []

    Layout.fillWidth: true
    spacing: 8

    function percentOf(used, total): var {
        if (used === null || used === undefined
                || total === null || total === undefined)
            return null
        const numerator = Number(used)
        const denominator = Number(total)
        return Number.isFinite(numerator)
                && Number.isFinite(denominator) && denominator > 0
            ? Math.max(0, Math.min(100, numerator / denominator * 100))
            : null
    }

    function systemRamPercent(): var {
        return root.percentOf(
            root.systemEvidence?.memory?.valuesKiB?.MemUsed,
            root.systemEvidence?.memory?.valuesKiB?.MemTotal)
    }

    function systemSwapPercent(): var {
        return root.percentOf(
            root.systemEvidence?.memory?.valuesKiB?.SwapUsed,
            root.systemEvidence?.memory?.valuesKiB?.SwapTotal)
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

    function formatLoadAverage(values): string {
        if (!Array.isArray(values) || values.length === 0)
            return Translation.tr("Load") + " —"
        const normalized = []
        for (const raw of values.slice(0, 3)) {
            if (raw === null || raw === undefined)
                continue
            const value = Number(raw)
            if (Number.isFinite(value) && value >= 0)
                normalized.push(value.toFixed(2))
        }
        return normalized.length > 0
            ? Translation.tr("Load") + " " + normalized.join("  ")
            : Translation.tr("Load") + " —"
    }

    function formatUptime(value): string {
        if (value === null || value === undefined)
            return "—"
        const seconds = Number(value)
        if (!Number.isFinite(seconds) || seconds < 0)
            return "—"
        const totalMinutes = Math.floor(seconds / 60)
        const days = Math.floor(totalMinutes / 1440)
        const hours = Math.floor((totalMinutes % 1440) / 60)
        const minutes = totalMinutes % 60
        if (days > 0)
            return days + "d " + hours + "h"
        if (hours > 0)
            return hours + "h " + minutes + "m"
        return minutes + "m"
    }

    function provenance(source): string {
        if (!source)
            return ""
        return [String(source?.scope ?? ""), String(source?.method ?? ""),
                String(source?.confidence ?? "")]
            .filter(value => value.length > 0).join(" · ")
    }

    function historyValues(key: string): var {
        const history = Array.isArray(root.evidence?.history)
            ? root.evidence.history : []
        const result = []
        for (const point of history) {
            const raw = point ? point[key] : undefined
            if (raw === null || raw === undefined) {
                result.push(null)
                continue
            }
            const value = Number(raw)
            result.push(Number.isFinite(value) ? value : null)
        }
        return result
    }

    function shellGpuBusy(): var {
        const engines = root.shellEvidence?.gpu?.engineBusyPercent ?? ({})
        let peak = null
        for (const key of Object.keys(engines)) {
            const raw = engines[key]
            if (raw === null || raw === undefined)
                continue
            const value = Number(raw)
            if (Number.isFinite(value))
                peak = peak === null ? value : Math.max(peak, value)
        }
        return peak
    }

    function shellGpuMemoryKiB(): var {
        const memory = root.shellEvidence?.gpu?.memoryKiB ?? ({})
        let total = 0
        let found = false
        for (const key of Object.keys(memory)) {
            if (!key.startsWith("resident-"))
                continue
            const value = Number(memory[key])
            if (!Number.isFinite(value))
                continue
            total += value
            found = true
        }
        return found ? total : null
    }

    // Compact Diagnostics is deliberately attribution-oriented. System totals
    // remain visible, but space is reserved for the two kinds of evidence that
    // can actually identify suspects: real child-process CPU/RSS and Workflow
    // lifecycle activity. QML activity is never presented as CPU/RAM.
    GridLayout {
        id: compactMetrics
        visible: root.compactMode
        Layout.fillWidth: true
        columns: width >= 900 ? 4 : 2
        columnSpacing: 6
        rowSpacing: 6

        BtopMetricPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: Translation.tr("CPU")
            subtitle: ""
            value: root.systemEvidence?.cpu?.percent ?? null
            detail: root.formatLoadAverage(
                    root.systemEvidence?.cpu?.loadAverage)
                + " · " + Translation.tr("Hadalis") + " "
                + root.formatPercent(root.shellEvidence?.cpu?.percent)
            samples: root.historyValues("systemCpuPercent")
            graphHeight: 12
            dottedGraph: true
        }

        BtopMetricPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: Translation.tr("Memory")
            value: root.systemRamPercent()
            detail: root.formatKiB(root.systemEvidence?.memory
                    ?.valuesKiB?.MemUsed) + " / "
                + root.formatKiB(root.systemEvidence?.memory
                    ?.valuesKiB?.MemTotal)
            samples: root.historyValues("systemRamPercent")
            graphHeight: 12
            dottedGraph: true
            accentColor: Appearance.colors.colSecondary
        }

        BtopMetricPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: Translation.tr("GPU")
            value: root.shellEvidence?.gpu?.available === true
                ? root.shellGpuBusy() : null
            detail: root.shellEvidence?.gpu?.available === true
                ? root.formatKiB(root.shellGpuMemoryKiB()) + " "
                    + Translation.tr("resident")
                : Translation.tr("DRM fdinfo unavailable")
            samples: root.historyValues("shellGpuPeakPercent")
            graphHeight: 12
            dottedGraph: true
            accentColor: Appearance.colors.colTertiary
        }

        BtopNetworkPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: Translation.tr("Network")
            graphHeight: 12
            dottedGraph: true
            rx: root.formatRate(root.networkEvidence
                ?.aggregateNonLoopback?.rxBytesPerSec)
            tx: root.formatRate(root.networkEvidence
                ?.aggregateNonLoopback?.txBytesPerSec)
            rxSamples: root.historyValues("rxBytesPerSec")
            txSamples: root.historyValues("txBytesPerSec")
        }
    }

    GridLayout {
        id: compactAttribution
        visible: root.compactMode
        Layout.fillWidth: true
        columns: width >= 720 ? 2 : 1
        columnSpacing: 6
        rowSpacing: 6

        BtopActivityTable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            targets: root.targets
            records: root.records
            events: root.events
            maxRows: 4
        }

        BtopProcessTable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            compactMode: true
            processes: root.shellEvidence?.children ?? []
            maxRows: 4
        }
    }

    Rectangle {
        id: compactRuntimeStrip
        visible: root.compactMode
        Layout.fillWidth: true
        implicitHeight: 38
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        border.color: Appearance.colors.colOutline

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 12

            StyledText {
                textFormat: Text.PlainText
                text: Translation.tr("Hadalis")
                color: Appearance.colors.colPrimary
                font.weight: Font.DemiBold
            }

            StyledText {
                textFormat: Text.PlainText
                text: "PID "
                    + (root.shellEvidence?.pid
                        ? String(root.shellEvidence.pid) : "—")
                color: Appearance.colors.colSubtext
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                textFormat: Text.PlainText
                text: "CPU "
                    + root.formatPercent(root.shellEvidence?.cpu?.percent)
                color: Appearance.colors.colOnLayer1
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                textFormat: Text.PlainText
                text: "RAM "
                    + root.formatKiB(root.shellEvidence?.memory?.valuesKiB?.Pss
                        ?? root.shellEvidence?.memory?.valuesKiB?.Rss)
                color: Appearance.colors.colOnLayer1
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            Item { Layout.fillWidth: true }

            StyledText {
                textFormat: Text.PlainText
                visible: compactRuntimeStrip.width >= 760
                text: "I/O R "
                    + root.formatRate(
                        root.shellEvidence?.io?.rates?.readBytesPerSec)
                    + " · W "
                    + root.formatRate(
                        root.shellEvidence?.io?.rates?.writeBytesPerSec)
                color: Appearance.colors.colSubtext
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }

            StyledText {
                textFormat: Text.PlainText
                text: String(
                        root.shellEvidence?.children?.length ?? 0)
                    + " " + Translation.tr("helpers")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }

    GridLayout {
        id: overviewGrid
        visible: !root.compactMode
        Layout.fillWidth: true
        columns: width >= 980 ? 2 : 1
        columnSpacing: 8
        rowSpacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 8

            BtopNetworkPanel {
                Layout.fillWidth: true
                title: Translation.tr("Network")
                graphHeight: 64
                dottedGraph: true
                showDetails: root.showDetails
                rx: root.formatRate(root.networkEvidence
                    ?.aggregateNonLoopback?.rxBytesPerSec)
                tx: root.formatRate(root.networkEvidence
                    ?.aggregateNonLoopback?.txBytesPerSec)
                rxSamples: root.historyValues("rxBytesPerSec")
                txSamples: root.historyValues("txBytesPerSec")
                rxTotal: root.formatBytes(root.networkEvidence
                    ?.aggregateNonLoopback?.rxBytes)
                txTotal: root.formatBytes(root.networkEvidence
                    ?.aggregateNonLoopback?.txBytes)
                provenance: root.provenance(root.networkEvidence)
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 520 ? 2 : 1
                columnSpacing: 8
                rowSpacing: 8

                BtopMetricPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: Translation.tr("Memory")
                    showDetails: root.showDetails
                    subtitle: Translation.tr("Available") + " "
                        + root.formatKiB(root.systemEvidence?.memory
                            ?.valuesKiB?.MemAvailable) + " · "
                        + Translation.tr("Cached") + " "
                        + root.formatKiB(root.systemEvidence?.memory
                            ?.valuesKiB?.Cached)
                    value: root.systemRamPercent()
                    detail: root.formatKiB(root.systemEvidence?.memory
                            ?.valuesKiB?.MemUsed) + " / "
                        + root.formatKiB(root.systemEvidence?.memory
                            ?.valuesKiB?.MemTotal)
                    samples: root.historyValues("systemRamPercent")
                    graphHeight: 20
                    dottedGraph: true
                    accentColor: Appearance.colors.colSecondary
                    provenance: root.provenance(root.systemEvidence?.memory)
                }

                BtopMetricPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: Translation.tr("Swap")
                    showDetails: root.showDetails
                    subtitle: Translation.tr("System swap")
                    value: root.systemSwapPercent()
                    detail: root.formatKiB(root.systemEvidence?.memory
                            ?.valuesKiB?.SwapUsed) + " / "
                        + root.formatKiB(root.systemEvidence?.memory
                            ?.valuesKiB?.SwapTotal)
                    samples: root.historyValues("systemSwapPercent")
                    graphHeight: 20
                    dottedGraph: true
                    accentColor: Appearance.colors.colTertiary
                    provenance: root.provenance(root.systemEvidence?.memory)
                }

                BtopNetworkPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: Translation.tr("Disk I/O")
                    showDetails: root.showDetails
                    rxLabel: Translation.tr("READ")
                    txLabel: Translation.tr("WRITE")
                    rxPrefix: "R "
                    txPrefix: "W "
                    graphHeight: 16
                    dottedGraph: true
                    rx: root.formatRate(root.shellEvidence?.io?.rates
                        ?.readBytesPerSec)
                    tx: root.formatRate(root.shellEvidence?.io?.rates
                        ?.writeBytesPerSec)
                    rxSamples: root.historyValues("shellReadBytesPerSec")
                    txSamples: root.historyValues("shellWriteBytesPerSec")
                    rxTotal: root.formatBytes(root.shellEvidence?.io
                        ?.counters?.read_bytes)
                    txTotal: root.formatBytes(root.shellEvidence?.io
                        ?.counters?.write_bytes)
                    provenance: root.provenance(root.shellEvidence?.io)
                }

                BtopMetricPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: Translation.tr("GPU")
                    showDetails: root.showDetails
                    subtitle: Translation.tr("DRM client peak")
                    value: root.shellEvidence?.gpu?.available === true
                        ? root.shellGpuBusy() : null
                    detail: root.shellEvidence?.gpu?.available === true
                        ? root.formatKiB(root.shellGpuMemoryKiB()) + " "
                            + Translation.tr("resident")
                        : Translation.tr("DRM fdinfo unavailable")
                    samples: root.historyValues("shellGpuPeakPercent")
                    graphHeight: 20
                    dottedGraph: true
                    accentColor: Appearance.colors.colTertiary
                    provenance: root.provenance(root.shellEvidence?.gpu)
                }
            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 8

            BtopProcessTable {
                Layout.fillWidth: true
                processes: root.shellEvidence?.children ?? []
                maxRows: 5
            }

            BtopTargetTable {
                Layout.fillWidth: true
                targets: root.targets
                records: root.records
                maxRows: 5
                selectedTargetId: root.selectedTargetId
                onTargetActivated: (targetId, instanceId) =>
                    root.targetActivated(targetId, instanceId)
            }
        }
    }

    GridLayout {
        id: cpuRow
        visible: !root.compactMode
        Layout.fillWidth: true
        columns: width >= 980 && root.cpuCores.length > 0 ? 2 : 1
        columnSpacing: 8
        rowSpacing: 8

        BtopMetricPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1.6
            Layout.alignment: Qt.AlignTop
            title: Translation.tr("CPU")
            showDetails: root.showDetails
            subtitle: root.formatLoadAverage(
                root.systemEvidence?.cpu?.loadAverage)
            value: root.systemEvidence?.cpu?.percent ?? null
            detail: Translation.tr("Hadalis") + " "
                + root.formatPercent(root.shellEvidence?.cpu?.percent)
            samples: root.historyValues("systemCpuPercent")
            graphHeight: 116
            dottedGraph: true
            provenance: root.provenance(root.systemEvidence?.cpu)
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            visible: root.cpuCores.length > 0
            implicitHeight: coreColumn.implicitHeight + 24
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer1
            border.color: Appearance.colors.colOutline

            ColumnLayout {
                id: coreColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        textFormat: Text.PlainText
                        text: Translation.tr("CPU cores")
                        color: Appearance.colors.colOnLayer1
                        font.weight: Font.DemiBold
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        textFormat: Text.PlainText
                        text: String(root.cpuCores.length) + " "
                            + Translation.tr("logical")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }

                BtopCoreGrid {
                    Layout.fillWidth: true
                    compact: cpuRow.columns === 2
                    cores: root.cpuCores
                    coreNames: root.cpuCoreNames
                    history: root.evidence?.history ?? []
                    columns: cpuRow.columns === 2 ? 2
                        : width >= 900 ? 4 : width >= 620 ? 3 : 2
                }
            }
        }
    }

    RippleButton {
        visible: !root.compactMode
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 132
        implicitHeight: 30
        buttonRadius: height / 2
        buttonText: root.showDetails
            ? Translation.tr("Hide details")
            : Translation.tr("Show details")
        colBackground: Appearance.colors.colLayer1
        colBackgroundHover: Appearance.colors.colLayer1Hover
        onClicked: root.showDetails = !root.showDetails
    }

    BtopInterfaceTable {
        Layout.fillWidth: true
        visible: !root.compactMode && root.showDetails
        interfaces: root.networkEvidence?.interfaces ?? ({})
        maxRows: 3
    }

    BtopRuntimePanel {
        Layout.fillWidth: true
        visible: !root.compactMode && root.showDetails
        title: Translation.tr("Hadalis runtime")
        pid: root.shellEvidence?.pid
            ? String(root.shellEvidence.pid) : "—"
        cpu: root.formatPercent(root.shellEvidence?.cpu?.percent)
        memory: root.formatKiB(root.shellEvidence?.memory?.valuesKiB?.Pss
            ?? root.shellEvidence?.memory?.valuesKiB?.Rss)
        memoryLabel: root.shellEvidence?.memory?.valuesKiB?.Pss !== null
            && root.shellEvidence?.memory?.valuesKiB?.Pss !== undefined
                ? "PSS" : "RSS"
        swap: root.formatKiB(root.shellEvidence?.memory?.valuesKiB?.SwapPss
            ?? root.shellEvidence?.memory?.valuesKiB?.Swap)
        readRate: root.formatRate(root.shellEvidence?.io?.rates
            ?.readBytesPerSec)
        writeRate: root.formatRate(root.shellEvidence?.io?.rates
            ?.writeBytesPerSec)
        gpu: root.shellEvidence?.gpu?.available === true
            ? root.formatPercent(root.shellGpuBusy()) : "—"
        gpuMemory: root.shellEvidence?.gpu?.available === true
            ? root.formatKiB(root.shellGpuMemoryKiB()) : "—"
    }

    StyledText {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        visible: !root.compactMode && root.showDetails
        text: Translation.tr("No synthetic per-QML resource estimates.")
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.smallest
    }
}
