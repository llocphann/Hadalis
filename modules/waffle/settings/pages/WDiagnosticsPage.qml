pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.settings.widgets
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 19
    pageTitle: Translation.tr("Diagnostics")
    pageIcon: "info"
    pageDescription: Translation.tr("CPU · RAM · Swap · GPU · Network")

    readonly property bool diagnosticsActive:
        RuntimeDiagnosticsSession.pageCurrent
    readonly property var runtimeCatalog: root.diagnosticsActive
        ? CodeWorkflowRuntime.activeCatalog : []
    readonly property int targetCount: root.runtimeCatalog.length
    readonly property var runtimeSnapshot: root.diagnosticsActive
        ? CodeWorkflowRuntime.snapshot() : ({ records: [], events: [] })
    readonly property var runtimeRecords:
        root.runtimeSnapshot?.records ?? []
    readonly property int collisionCount: root.diagnosticsActive
        ? CodeWorkflowRuntime.identityCollisions.length : 0
    readonly property var evidence: RuntimeDiagnosticsSession.evidence
    readonly property var systemEvidence: root.evidence?.system ?? null
    readonly property var shellEvidence: root.evidence?.shell ?? null
    readonly property var discoveryEvidence: root.evidence?.discovery ?? null
    readonly property string samplerError:
        String(root.evidence?.sampler?.error ?? "")
    readonly property bool sessionHasError:
        RuntimeDiagnosticsSession.leaseError.length > 0
        || RuntimeDiagnosticsSession.remoteError.length > 0
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

    WSettingsCard {
        title: Translation.tr("Runtime diagnostics")
        icon: "info"

        WSettingsRow {
            label: root.sessionStateLabel()
            description: Translation.tr("Sampling is leased only while this page is current.")
            icon: "info"
        }

        WSettingsRow {
            visible: RuntimeDiagnosticsSession.leaseError.length > 0
            label: Translation.tr("Diagnostics lease error")
            description: RuntimeDiagnosticsSession.leaseError
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

    }

    BtopDashboard {
        Layout.fillWidth: true
        evidence: root.evidence
        targets: root.runtimeCatalog
        records: root.runtimeRecords
        selectedTargetId: CodeWorkflowSession.selectedTargetId
        onTargetActivated: (targetId, instanceId) =>
            CodeWorkflowSession.selectTarget(targetId, instanceId)
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

            textFormat: Text.PlainText
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
