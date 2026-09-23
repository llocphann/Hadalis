import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "widgets"

ContentPage {
    id: root
    settingsPageIndex: 31
    settingsPageName: Translation.tr("Diagnostics")

    readonly property int targetCount:
        CodeWorkflowRuntime.activeCatalog.length
    readonly property int collisionCount:
        CodeWorkflowRuntime.identityCollisions.length
    readonly property var evidence: RuntimeDiagnosticsSession.evidence
    readonly property var systemEvidence: root.evidence?.system ?? null
    readonly property var shellEvidence: root.evidence?.shell ?? null
    readonly property var networkEvidence: root.evidence?.network ?? null
    readonly property var discoveryEvidence: root.evidence?.discovery ?? null
    readonly property var runtimeSnapshot: CodeWorkflowRuntime.snapshot()
    readonly property var runtimeRecords:
        root.runtimeSnapshot?.records ?? []
    readonly property var cpuCores:
        root.systemEvidence?.cpu?.coresPercent ?? []
    readonly property var cpuCoreNames:
        root.systemEvidence?.cpu?.coreNames ?? []
    readonly property string samplerError:
        String(root.evidence?.sampler?.error ?? "")
    readonly property bool sessionHasError:
        RuntimeDiagnosticsSession.remoteError.length > 0
        || RuntimeDiagnosticsSession.evidenceError.length > 0
        || root.samplerError.length > 0
    readonly property bool samplerRunning:
        root.evidence?.sampler?.running === true

    function sessionStateLabel(): string {
        if (!RuntimeDiagnosticsSession.pageCurrent)
            return Translation.tr("Sampling paused")
        if (root.sessionHasError)
            return Translation.tr("Sampling error")
        if (!root.samplerRunning || root.systemEvidence === null)
            return Translation.tr("Starting sampler")
        return Translation.tr("Sampling live")
    }

    function percentOf(used, total): var {
        if (used === null || used === undefined
                || total === null || total === undefined)
            return null
        const usedValue = Number(used)
        const totalValue = Number(total)
        if (!Number.isFinite(usedValue)
                || !Number.isFinite(totalValue)
                || totalValue <= 0)
            return null
        return Math.max(0, Math.min(100, usedValue / totalValue * 100))
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

    function formatLoadAverage(values): string {
        if (!Array.isArray(values) || values.length === 0)
            return Translation.tr("Load") + " —"
        return Translation.tr("Load") + " "
            + values.slice(0, 3)
                .map(value => Number(value).toFixed(2))
                .join("  ")
    }

    function sampleIntervalLabel(): string {
        const ms = Number(root.evidence?.status?.sampleIntervalMs)
        if (!Number.isFinite(ms) || ms <= 0)
            return "—"
        if (ms >= 1000) {
            const seconds = ms / 1000
            return (Math.round(seconds) === seconds
                ? seconds.toFixed(0) : seconds.toFixed(1)) + " s"
        }
        return Math.round(ms) + " ms"
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

    function provenance(source): string {
        if (!source)
            return ""
        const scope = String(source?.scope ?? "")
        const method = String(source?.method ?? "")
        const confidence = String(source?.confidence ?? "")
        return [scope, method, confidence]
            .filter(value => value.length > 0)
            .join(" · ")
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

    SettingsCardSection {
        expanded: true
        icon: "monitoring"
        title: Translation.tr("Live diagnostics")

        SettingsGroup {
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: sessionLayout.implicitHeight + 24
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1
                border.color: root.sessionHasError
                    ? Appearance.colors.colError
                    : RuntimeDiagnosticsSession.pageCurrent
                        ? Qt.rgba(
                            Appearance.colors.colPrimary.r,
                            Appearance.colors.colPrimary.g,
                            Appearance.colors.colPrimary.b,
                            0.46)
                        : Appearance.colors.colOutline

                RowLayout {
                    id: sessionLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        width: 9
                        height: 9
                        radius: 5
                        color: root.sessionHasError
                            ? Appearance.colors.colError
                            : RuntimeDiagnosticsSession.pageCurrent
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colSubtext
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        StyledText {
                            text: root.sessionStateLabel()
                            color: Appearance.colors.colOnLayer1
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.sampleIntervalLabel() + " "
                                + Translation.tr("kernel sampling · stops automatically when this page is not current")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                            wrapMode: Text.WordWrap
                        }
                    }

                    ColumnLayout {
                        spacing: 0

                        StyledText {
                            Layout.alignment: Qt.AlignRight
                            text: Translation.tr("Uptime") + " "
                                + root.formatUptime(
                                    root.systemEvidence?.uptimeSeconds)
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignRight
                            text: String((root.evidence?.history ?? []).length)
                                + " " + Translation.tr("samples")
                            color: Appearance.colors.colPrimary
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: RuntimeDiagnosticsSession.remoteError.length > 0
                text: Translation.tr("Runtime bridge error") + " · "
                    + RuntimeDiagnosticsSession.remoteError
                color: Appearance.colors.colError
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: RuntimeDiagnosticsSession.evidenceError.length > 0
                text: Translation.tr("Runtime evidence error") + " · "
                    + RuntimeDiagnosticsSession.evidenceError
                color: Appearance.colors.colError
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.samplerError.length > 0
                text: Translation.tr("Sampler error") + " · "
                    + root.samplerError
                color: Appearance.colors.colError
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "memory"
        title: Translation.tr("System")

        SettingsGroup {
            GridLayout {
                Layout.fillWidth: true
                columns: width >= 760 ? 2 : 1
                columnSpacing: 10
                rowSpacing: 10

                BtopMetricPanel {
                    Layout.fillWidth: true
                    title: Translation.tr("CPU")
                    subtitle: root.formatLoadAverage(
                        root.systemEvidence?.cpu?.loadAverage)
                    value: root.systemEvidence?.cpu?.percent ?? null
                    detail: Translation.tr("Hadalis") + " · "
                        + root.formatPercent(root.shellEvidence?.cpu?.percent)
                        + "   ·   " + Translation.tr("uptime") + " "
                        + root.formatUptime(
                            root.systemEvidence?.uptimeSeconds)
                    samples: root.historyValues("systemCpuPercent")
                    provenance: root.provenance(root.systemEvidence?.cpu)
                }

                BtopMetricPanel {
                    Layout.fillWidth: true
                    title: Translation.tr("Memory")
                    subtitle: Translation.tr("Physical RAM")
                    value: root.systemRamPercent()
                    detail: root.formatKiB(
                            root.systemEvidence?.memory?.valuesKiB?.MemUsed)
                        + " / "
                        + root.formatKiB(
                            root.systemEvidence?.memory?.valuesKiB?.MemTotal)
                    samples: root.historyValues("systemRamPercent")
                    accentColor: Appearance.colors.colSecondary
                    provenance: root.provenance(root.systemEvidence?.memory)
                }

                BtopMetricPanel {
                    Layout.fillWidth: true
                    title: Translation.tr("Swap")
                    subtitle: Translation.tr("System swap")
                    value: root.systemSwapPercent()
                    detail: root.formatKiB(
                            root.systemEvidence?.memory?.valuesKiB?.SwapUsed)
                        + " / "
                        + root.formatKiB(
                            root.systemEvidence?.memory?.valuesKiB?.SwapTotal)
                    samples: root.historyValues("systemSwapPercent")
                    accentColor: Appearance.colors.colTertiary
                    provenance: root.provenance(root.systemEvidence?.memory)
                }

                BtopMetricPanel {
                    Layout.fillWidth: true
                    title: Translation.tr("GPU")
                    subtitle: Translation.tr("Hadalis DRM client peak")
                    value: root.shellEvidence?.gpu?.available === true
                        ? root.shellGpuBusy() : null
                    detail: root.shellEvidence?.gpu?.available === true
                        ? root.formatKiB(root.shellGpuMemoryKiB())
                            + " " + Translation.tr("resident")
                        : Translation.tr("DRM fdinfo unavailable")
                    samples: root.historyValues("shellGpuPeakPercent")
                    accentColor: Appearance.colors.colTertiary
                    provenance: root.provenance(root.shellEvidence?.gpu)
                }

                BtopNetworkPanel {
                    Layout.fillWidth: true
                    title: Translation.tr("Network") + " · "
                        + Translation.tr("non-loopback")
                    rx: root.formatRate(
                        root.networkEvidence?.aggregateNonLoopback
                            ?.rxBytesPerSec)
                    tx: root.formatRate(
                        root.networkEvidence?.aggregateNonLoopback
                            ?.txBytesPerSec)
                    rxSamples: root.historyValues("rxBytesPerSec")
                    txSamples: root.historyValues("txBytesPerSec")
                    rxTotal: root.formatBytes(
                        root.networkEvidence?.aggregateNonLoopback?.rxBytes)
                    txTotal: root.formatBytes(
                        root.networkEvidence?.aggregateNonLoopback?.txBytes)
                    provenance: root.provenance(root.networkEvidence)
                }

                BtopNetworkPanel {
                    Layout.fillWidth: true
                    title: Translation.tr("Hadalis disk I/O")
                    rxLabel: Translation.tr("READ")
                    txLabel: Translation.tr("WRITE")
                    rxPrefix: "R "
                    txPrefix: "W "
                    rx: root.formatRate(
                        root.shellEvidence?.io?.rates?.readBytesPerSec)
                    tx: root.formatRate(
                        root.shellEvidence?.io?.rates?.writeBytesPerSec)
                    rxSamples: root.historyValues("shellReadBytesPerSec")
                    txSamples: root.historyValues("shellWriteBytesPerSec")
                    rxTotal: root.formatBytes(
                        root.shellEvidence?.io?.counters?.read_bytes)
                    txTotal: root.formatBytes(
                        root.shellEvidence?.io?.counters?.write_bytes)
                    provenance: root.provenance(root.shellEvidence?.io)
                }
            }

            BtopInterfaceTable {
                Layout.fillWidth: true
                interfaces: root.networkEvidence?.interfaces ?? ({})
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.cpuCores.length > 0
                implicitHeight: coreColumn.implicitHeight + 24
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1
                border.color: Qt.rgba(
                    Appearance.colors.colPrimary.r,
                    Appearance.colors.colPrimary.g,
                    Appearance.colors.colPrimary.b,
                    0.34)

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
                            text: Translation.tr("CPU cores")
                            color: Appearance.colors.colOnLayer1
                            font.weight: Font.DemiBold
                        }

                        Item { Layout.fillWidth: true }

                        StyledText {
                            text: String(root.cpuCores.length)
                                + " " + Translation.tr("logical")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    BtopCoreGrid {
                        Layout.fillWidth: true
                        cores: root.cpuCores
                        coreNames: root.cpuCoreNames
                        columns: width >= 760 ? 8
                            : width >= 520 ? 6
                            : width >= 360 ? 4 : 2
                    }
                }
            }

            BtopRuntimePanel {
                Layout.fillWidth: true
                title: Translation.tr("Hadalis runtime")
                pid: root.shellEvidence?.pid
                    ? String(root.shellEvidence.pid) : "—"
                cpu: root.formatPercent(root.shellEvidence?.cpu?.percent)
                memory: root.formatKiB(
                    root.shellEvidence?.memory?.valuesKiB?.Pss
                        ?? root.shellEvidence?.memory?.valuesKiB?.Rss)
                memoryLabel:
                    root.shellEvidence?.memory?.valuesKiB?.Pss !== null
                    && root.shellEvidence?.memory?.valuesKiB?.Pss !== undefined
                        ? "PSS" : "RSS"
                readRate: root.formatRate(
                    root.shellEvidence?.io?.rates?.readBytesPerSec)
                writeRate: root.formatRate(
                    root.shellEvidence?.io?.rates?.writeBytesPerSec)
                gpu: root.shellEvidence?.gpu?.available === true
                    ? root.formatPercent(root.shellGpuBusy()) : "—"
                gpuMemory: root.shellEvidence?.gpu?.available === true
                    ? root.formatKiB(root.shellGpuMemoryKiB()) : "—"
            }

            BtopProcessTable {
                Layout.fillWidth: true
                processes: root.shellEvidence?.children ?? []
                maxRows: 12
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("No synthetic per-QML resource estimates.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "view_list"
        title: Translation.tr("Runtime targets")

        SettingsGroup {
            BtopTargetTable {
                Layout.fillWidth: true
                targets: CodeWorkflowRuntime.activeCatalog
                records: root.runtimeRecords
                maxRows: 18
                selectedTargetId: CodeWorkflowSession.selectedTargetId
                onTargetActivated: (targetId, instanceId) =>
                    CodeWorkflowSession.selectTarget(
                        targetId, instanceId)
            }

            BtopTargetInspector {
                Layout.fillWidth: true
                descriptor: CodeWorkflowRuntime.descriptor(
                    CodeWorkflowSession.selectedTargetId)
                records: root.runtimeRecords
                events: root.runtimeSnapshot?.events ?? []
                selectedInstanceId:
                    CodeWorkflowSession.selectedInstanceId
                onInstanceActivated: instanceId =>
                    CodeWorkflowSession.selectTarget(
                        CodeWorkflowSession.selectedTargetId,
                        instanceId)
                onOpenWorkflowRequested:
                    SettingsPageRegistry.navigateToKey(
                        "code-workflow", "")
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Workflow-owned identities · no synthetic target metrics.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "account_tree"
        title: Translation.tr("Workflow identity")

        SettingsGroup {
            GridLayout {
                Layout.fillWidth: true
                columns: width >= 680 ? 3 : 1
                columnSpacing: 10
                rowSpacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 74
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1
                    border.color: Appearance.colors.colOutline

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 2

                        StyledText {
                            text: Translation.tr("Targets")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        StyledText {
                            text: String(root.targetCount)
                            color: Appearance.colors.colPrimary
                            font.weight: Font.DemiBold
                            font.pixelSize: Appearance.font.pixelSize.large
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 74
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1
                    border.color: Appearance.colors.colOutline

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 2

                        StyledText {
                            text: Translation.tr("Source boundaries")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        StyledText {
                            text: root.discoveryEvidence?.status === "ready"
                                ? String(root.discoveryEvidence?.boundaryCount ?? 0)
                                : "—"
                            color: Appearance.colors.colPrimary
                            font.weight: Font.DemiBold
                            font.pixelSize: Appearance.font.pixelSize.large
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 74
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1
                    border.color: root.collisionCount === 0
                        ? Appearance.colors.colOutline
                        : Appearance.colors.colError

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 2

                        StyledText {
                            text: Translation.tr("Identity collisions")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        StyledText {
                            text: String(root.collisionCount)
                            color: root.collisionCount === 0
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colError
                            font.weight: Font.DemiBold
                            font.pixelSize: Appearance.font.pixelSize.large
                        }
                    }
                }
            }

            BtopCoveragePanel {
                Layout.fillWidth: true
                status: String(root.discoveryEvidence?.status ?? "idle")
                boundaryCounts:
                    root.discoveryEvidence?.boundaryCounts ?? ({})
                filesScanned: Number(
                    root.discoveryEvidence?.filesScanned ?? 0)
                cacheHits: Number(
                    root.discoveryEvidence?.cacheHits ?? 0)
            }

            StyledText {
                Layout.fillWidth: true
                visible: String(root.discoveryEvidence?.error ?? "").length > 0
                text: Translation.tr("Runtime boundary index error") + " · "
                    + String(root.discoveryEvidence?.error ?? "")
                color: Appearance.colors.colError
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: root.discoveryEvidence?.status === "ready"
                    ? Translation.tr("Matched source boundaries") + " · "
                        + String(root.discoveryEvidence?.reconciliation
                            ?.matchedBoundaryCount ?? 0)
                        + "   ·   "
                        + Translation.tr("Source-only") + " · "
                        + String(root.discoveryEvidence?.reconciliation
                            ?.unmatchedBoundaryCount ?? 0)
                        + "   ·   "
                        + String(root.discoveryEvidence?.filesScanned ?? 0)
                        + " " + Translation.tr("QML files")
                    : Translation.tr("Runtime boundary index") + " · "
                        + String(root.discoveryEvidence?.status ?? "idle")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.discoveryEvidence?.status === "ready"
                text: Translation.tr("Source boundaries are parser evidence, not proof that a component executed.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
                wrapMode: Text.WordWrap
            }
        }
    }
}
