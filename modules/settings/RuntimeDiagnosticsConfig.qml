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

    function systemRamPercent(): var {
        const used = Number(
            root.systemEvidence?.memory?.valuesKiB?.MemUsed)
        const total = Number(
            root.systemEvidence?.memory?.valuesKiB?.MemTotal)
        if (!Number.isFinite(used)
                || !Number.isFinite(total)
                || total <= 0)
            return null
        return Math.max(0, Math.min(100, used / total * 100))
    }

    function formatPercent(value): string {
        const number = Number(value)
        return Number.isFinite(number) ? number.toFixed(1) + "%" : "—"
    }

    function formatKiB(value): string {
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

    function shellGpuBusy(): real {
        const engines = root.shellEvidence?.gpu?.engineBusyPercent ?? ({})
        let peak = -1
        for (const key of Object.keys(engines)) {
            const value = Number(engines[key])
            if (Number.isFinite(value))
                peak = Math.max(peak, value)
        }
        return peak
    }

    function shellGpuMemoryKiB(): real {
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
        return found ? total : -1
    }

    function metricLine(label: string, value: string): string {
        return label + "  " + value
    }

    SettingsCardSection {
        expanded: true
        icon: "monitoring"
        title: Translation.tr("Runtime diagnostics")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: RuntimeDiagnosticsSession.pageCurrent
                    ? Translation.tr("Diagnostics session active")
                    : Translation.tr("Diagnostics session inactive")
                color: RuntimeDiagnosticsSession.pageCurrent
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Sampling is leased only while this page is current. Leaving the page stops diagnostics work even if Settings keeps this page cached.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
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
                visible: String(root.evidence?.sampler?.error ?? "").length > 0
                text: Translation.tr("Sampler error") + " · "
                    + String(root.evidence?.sampler?.error ?? "")
                color: Appearance.colors.colError
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "memory"
        title: Translation.tr("Resource probes")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("CPU · RAM · Swap · GPU · Network")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 720 ? 2 : 1
                columnSpacing: 10
                rowSpacing: 10
                visible: root.systemEvidence !== null

                BtopMetricPanel {
                    Layout.fillWidth: true
                    title: Translation.tr("System CPU")
                    value: root.systemEvidence?.cpu?.percent ?? null
                    detail: Translation.tr("Shell") + " · "
                        + root.formatPercent(root.shellEvidence?.cpu?.percent)
                    samples: (root.evidence?.history ?? [])
                        .map(point => Number(point?.systemCpuPercent))
                        .filter(value => Number.isFinite(value))
                }

                BtopMetricPanel {
                    Layout.fillWidth: true
                    title: Translation.tr("System RAM")
                    value: root.systemRamPercent()
                    detail: root.formatKiB(
                            root.systemEvidence?.memory?.valuesKiB?.MemUsed)
                        + " / "
                        + root.formatKiB(
                            root.systemEvidence?.memory?.valuesKiB?.MemTotal)
                    samples: (root.evidence?.history ?? [])
                        .map(point => Number(point?.systemRamPercent))
                        .filter(value => Number.isFinite(value))
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("CPU")
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: root.formatPercent(root.systemEvidence?.cpu?.percent)
                        + " " + Translation.tr("system")
                        + " · "
                        + root.formatPercent(root.shellEvidence?.cpu?.percent)
                        + " " + Translation.tr("shell")
                    color: Appearance.colors.colSubtext
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("RAM")
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: root.formatKiB(
                            root.systemEvidence?.memory?.valuesKiB?.MemUsed)
                        + " / "
                        + root.formatKiB(
                            root.systemEvidence?.memory?.valuesKiB?.MemTotal)
                        + " " + Translation.tr("system")
                        + " · "
                        + root.formatKiB(
                            root.shellEvidence?.memory?.valuesKiB?.Pss
                                ?? root.shellEvidence?.memory?.valuesKiB?.Rss)
                        + " " + Translation.tr("shell PSS")
                    color: Appearance.colors.colSubtext
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Swap")
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: root.formatKiB(
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
                    color: Appearance.colors.colSubtext
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("GPU")
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: root.shellEvidence?.gpu?.available === true
                        ? root.formatPercent(root.shellGpuBusy())
                            + " " + Translation.tr("shell engine peak")
                            + " · "
                            + root.formatKiB(root.shellGpuMemoryKiB())
                            + " " + Translation.tr("resident")
                        : Translation.tr("DRM fdinfo unavailable")
                    color: Appearance.colors.colSubtext
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Network")
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: "↓ "
                        + root.formatRate(
                            root.networkEvidence?.aggregateNonLoopback
                                ?.rxBytesPerSec)
                        + "   ↑ "
                        + root.formatRate(
                            root.networkEvidence?.aggregateNonLoopback
                                ?.txBytesPerSec)
                        + " " + Translation.tr("system")
                    color: Appearance.colors.colSubtext
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Shell disk I/O")
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: "R "
                        + root.formatRate(
                            root.shellEvidence?.io?.rates?.readBytesPerSec)
                        + "   W "
                        + root.formatRate(
                            root.shellEvidence?.io?.rates?.writeBytesPerSec)
                    color: Appearance.colors.colSubtext
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Provenance: system CPU /proc/stat · memory /proc/meminfo · shell CPU schedstat · shell memory smaps_rollup (status fallback) · shell I/O /proc/<pid>/io · shell GPU DRM fdinfo · network /proc/net/dev.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Per-component CPU, RAM, Swap, GPU and Network are not reported until a reviewed attribution method exists.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "account_tree"
        title: Translation.tr("Workflow identity")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Canonical targets") + " · "
                    + String(root.targetCount)
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                Layout.fillWidth: true
                text: root.collisionCount === 0
                    ? Translation.tr("No canonical identity collisions detected")
                    : Translation.tr("Identity collisions") + " · "
                        + String(root.collisionCount)
                color: root.collisionCount === 0
                    ? Appearance.colors.colSubtext
                    : Appearance.colors.colError
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: root.discoveryEvidence?.status === "ready"
                    ? Translation.tr("Runtime boundaries") + " · "
                        + String(root.discoveryEvidence?.boundaryCount ?? 0)
                        + " · " + String(root.discoveryEvidence?.filesScanned ?? 0)
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
                text: Translation.tr("Canonical source matches") + " · "
                    + String(root.discoveryEvidence?.reconciliation?.matchedBoundaryCount ?? 0)
                    + " · " + Translation.tr("source-only boundaries") + " · "
                    + String(root.discoveryEvidence?.reconciliation?.unmatchedBoundaryCount ?? 0)
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

            StyledText {
                Layout.fillWidth: true
                text: root.shellEvidence?.pid
                    ? Translation.tr("Main shell PID") + " · "
                        + String(root.shellEvidence.pid)
                    : Translation.tr("Waiting for main-shell sample")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }
}
