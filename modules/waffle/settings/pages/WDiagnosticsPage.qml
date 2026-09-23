pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 19
    pageTitle: Translation.tr("Diagnostics")
    pageIcon: "info"
    pageDescription: Translation.tr("On-demand runtime resource diagnostics")

    readonly property int targetCount:
        CodeWorkflowRuntime.activeCatalog.length
    readonly property int collisionCount:
        CodeWorkflowRuntime.identityCollisions.length
    readonly property var evidence: RuntimeDiagnosticsSession.evidence
    readonly property var systemEvidence: root.evidence?.system ?? null
    readonly property var shellEvidence: root.evidence?.shell ?? null
    readonly property var networkEvidence: root.evidence?.network ?? null
    readonly property var discoveryEvidence: root.evidence?.discovery ?? null
    readonly property string samplerError:
        String(root.evidence?.sampler?.error ?? "")
    readonly property bool sessionHasError:
        RuntimeDiagnosticsSession.remoteError.length > 0
        || RuntimeDiagnosticsSession.evidenceError.length > 0
        || root.samplerError.length > 0
    readonly property bool samplerRunning:
        root.evidence?.sampler?.running === true
    readonly property bool sessionStalled: root.sampleIsStale()

    function sampleIsStale(): bool {
        const tick = RuntimeDiagnosticsSession.heartbeatTick
        if (tick < 0 || !RuntimeDiagnosticsSession.pageCurrent
                || root.sessionHasError)
            return false
        const heartbeatAge = tick
            - RuntimeDiagnosticsSession.pageOpenedHeartbeatTick
        if (!root.samplerRunning || root.systemEvidence === null)
            return heartbeatAge >= 3
        const sampleAtMs = Number(root.evidence?.sampleAtMs)
        if (!Number.isFinite(sampleAtMs) || sampleAtMs <= 0)
            return heartbeatAge >= 3
        const intervalMs = Number(root.evidence?.status?.sampleIntervalMs)
        const staleAfterMs = Number.isFinite(intervalMs) && intervalMs > 0
            ? Math.max(5000, intervalMs * 4) : 5000
        return Date.now() - sampleAtMs > staleAfterMs
    }

    function sessionStateLabel(): string {
        if (!RuntimeDiagnosticsSession.pageCurrent)
            return Translation.tr("Diagnostics session inactive")
        if (root.sessionHasError)
            return Translation.tr("Diagnostics sampling error")
        if (root.sessionStalled)
            return Translation.tr("Diagnostics sampling stalled")
        if (!root.samplerRunning || root.systemEvidence === null)
            return Translation.tr("Diagnostics sampler starting")
        return Translation.tr("Diagnostics session active")
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

    WSettingsCard {
        title: Translation.tr("Runtime diagnostics")
        icon: "info"

        WSettingsRow {
            label: root.sessionStateLabel()
            description: Translation.tr("Sampling is leased only while this page is current.")
            icon: "info"
        }

        WSettingsRow {
            visible: RuntimeDiagnosticsSession.remoteError.length > 0
            label: Translation.tr("Runtime bridge error")
            description: RuntimeDiagnosticsSession.remoteError
            icon: "info"
        }

        WSettingsRow {
            visible: RuntimeDiagnosticsSession.evidenceError.length > 0
            label: Translation.tr("Runtime evidence error")
            description: RuntimeDiagnosticsSession.evidenceError
            icon: "info"
        }

        WSettingsRow {
            visible: root.samplerError.length > 0
            label: Translation.tr("Sampler error")
            description: root.samplerError
            icon: "info"
        }

        WText {
            Layout.fillWidth: true
            text: Translation.tr("Leaving Diagnostics stops diagnostics-owned sampling immediately; a short server TTL also cleans up crashed standalone Settings clients.")
            color: Looks.colors.subfg
            font.pixelSize: Looks.font.pixelSize.small
            wrapMode: Text.WordWrap
        }
    }

    WSettingsCard {
        title: Translation.tr("CPU · RAM · Swap · GPU · Network")
        icon: "info"

        WSettingsRow {
            label: Translation.tr("CPU")
            description: root.formatPercent(root.systemEvidence?.cpu?.percent)
                + " " + Translation.tr("system")
                + " · "
                + root.formatPercent(root.shellEvidence?.cpu?.percent)
                + " " + Translation.tr("shell")
            icon: "info"
        }

        WSettingsRow {
            label: Translation.tr("RAM")
            description: root.formatKiB(
                    root.systemEvidence?.memory?.valuesKiB?.MemUsed)
                + " / "
                + root.formatKiB(
                    root.systemEvidence?.memory?.valuesKiB?.MemTotal)
                + " " + Translation.tr("system")
                + " · "
                + root.formatKiB(
                    root.shellEvidence?.memory?.valuesKiB?.Pss
                        ?? root.shellEvidence?.memory?.valuesKiB?.Rss)
                + " " + Translation.tr("shell") + " "
                + (root.shellEvidence?.memory?.valuesKiB?.Pss !== null
                    && root.shellEvidence?.memory?.valuesKiB?.Pss !== undefined
                    ? "PSS" : "RSS")
            icon: "apps"
        }

        WSettingsRow {
            label: Translation.tr("Swap")
            description: root.formatKiB(
                    root.systemEvidence?.memory?.valuesKiB?.SwapUsed)
                + " / "
                + root.formatKiB(
                    root.systemEvidence?.memory?.valuesKiB?.SwapTotal)
                + " " + Translation.tr("system")
                + " · "
                + root.formatKiB(
                    root.shellEvidence?.memory?.valuesKiB?.SwapPss
                        ?? root.shellEvidence?.memory?.valuesKiB?.Swap)
                + " " + Translation.tr("shell")
            icon: "apps"
        }

        WSettingsRow {
            label: Translation.tr("GPU")
            description: root.shellEvidence?.gpu?.available === true
                ? root.formatPercent(root.shellGpuBusy())
                    + " " + Translation.tr("shell engine peak")
                    + " · "
                    + root.formatKiB(root.shellGpuMemoryKiB())
                    + " " + Translation.tr("resident")
                : Translation.tr("DRM fdinfo unavailable")
            icon: "info"
        }

        WSettingsRow {
            label: Translation.tr("Network")
            description: "↓ "
                + root.formatRate(
                    root.networkEvidence?.aggregateNonLoopback?.rxBytesPerSec)
                + "   ↑ "
                + root.formatRate(
                    root.networkEvidence?.aggregateNonLoopback?.txBytesPerSec)
                + " " + Translation.tr("system non-loopback")
            icon: "info"
        }

        WSettingsRow {
            label: Translation.tr("Shell disk I/O")
            description: "R "
                + root.formatRate(
                    root.shellEvidence?.io?.rates?.readBytesPerSec)
                + "   W "
                + root.formatRate(
                    root.shellEvidence?.io?.rates?.writeBytesPerSec)
            icon: "info"
        }

        WText {
            Layout.fillWidth: true
            text: Translation.tr("Kernel provenance: system CPU /proc/stat · memory /proc/meminfo · shell CPU schedstat · shell memory smaps_rollup · shell I/O /proc/<pid>/io · shell GPU DRM fdinfo · network /proc/net/dev.")
            textFormat: Text.PlainText
            color: Looks.colors.subfg
            font.pixelSize: Looks.font.pixelSize.small
            wrapMode: Text.WordWrap
        }

        WText {
            Layout.fillWidth: true
            text: Translation.tr("Per-component CPU, RAM, Swap, GPU and Network stay unavailable until reviewed attribution exists.")
            color: Looks.colors.subfg
            font.pixelSize: Looks.font.pixelSize.small
            wrapMode: Text.WordWrap
        }
    }

    WSettingsCard {
        title: Translation.tr("Workflow identity")
        icon: "apps"

        WSettingsRow {
            label: Translation.tr("Canonical targets")
            description: String(root.targetCount)
            icon: "apps"
        }

        WSettingsRow {
            label: Translation.tr("Identity collisions")
            description: String(root.collisionCount)
            icon: "info"
        }

        WSettingsRow {
            label: Translation.tr("Runtime boundaries")
            description: root.discoveryEvidence?.status === "ready"
                ? String(root.discoveryEvidence?.boundaryCount ?? 0)
                    + " · " + String(root.discoveryEvidence?.filesScanned ?? 0)
                    + " " + Translation.tr("QML files")
                : String(root.discoveryEvidence?.status ?? "idle")
            icon: "apps"
        }

        WSettingsRow {
            visible: String(root.discoveryEvidence?.error ?? "").length > 0
            label: Translation.tr("Runtime boundary index error")
            description: String(root.discoveryEvidence?.error ?? "")
            icon: "info"
        }

        WSettingsRow {
            visible: root.discoveryEvidence?.status === "ready"
            label: Translation.tr("Canonical source matches")
            description:
                String(root.discoveryEvidence?.reconciliation?.matchedBoundaryCount ?? 0)
                + " · " + Translation.tr("source-only")
                + " " + String(root.discoveryEvidence?.reconciliation?.unmatchedBoundaryCount ?? 0)
            icon: "apps"
        }

        WText {
            Layout.fillWidth: true
            visible: root.discoveryEvidence?.status === "ready"
            text: Translation.tr("Source boundaries are parser evidence, not proof that a component executed.")
            color: Looks.colors.subfg
            font.pixelSize: Looks.font.pixelSize.small
            wrapMode: Text.WordWrap
        }

        WSettingsRow {
            label: Translation.tr("Main shell PID")
            description: root.shellEvidence?.pid
                ? String(root.shellEvidence.pid)
                : Translation.tr("Waiting for sample")
            icon: "info"
        }
    }
}
