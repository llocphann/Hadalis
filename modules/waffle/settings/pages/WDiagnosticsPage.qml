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
    readonly property string primaryError: {
        if (RuntimeDiagnosticsSession.leaseError.length > 0)
            return Translation.tr("Diagnostics lease error") + ": " + RuntimeDiagnosticsSession.leaseError
        if (RuntimeDiagnosticsSession.remoteError.length > 0)
            return Translation.tr("Runtime bridge error") + ": " + RuntimeDiagnosticsSession.remoteError
        if (RuntimeDiagnosticsSession.evidenceError.length > 0)
            return Translation.tr("Diagnostics evidence error") + ": " + RuntimeDiagnosticsSession.evidenceError
        if (root.samplerError.length > 0)
            return Translation.tr("Diagnostics sampler error") + ": " + root.samplerError
        return String(root.discoveryEvidence?.error ?? "")
    }

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
            return Translation.tr("Diagnostics paused")
        if (root.sessionHasError)
            return Translation.tr("Diagnostics error")
        if (root.sessionStalled)
            return Translation.tr("Diagnostics stalled")
        if (!root.samplerRunning || root.systemEvidence === null)
            return Translation.tr("Diagnostics starting")
        return Translation.tr("Diagnostics live")
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

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 42
        radius: 8
        color: Looks.colors.bg2
        border.width: 1
        border.color: root.sessionHasError || root.sessionStalled
            ? Looks.colors.danger
            : Looks.colors.accent

        RowLayout {
            id: statusRow
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                radius: 4
                color: root.sessionHasError || root.sessionStalled
                    ? Looks.colors.danger
                    : root.samplerRunning
                        ? Looks.colors.accent
                        : Looks.colors.subfg
            }

            WText {
                text: root.sessionStateLabel()
                font.weight: Looks.font.weight.stronger
            }

            WText {
                text: Translation.tr("Uptime") + " "
                    + root.formatUptime(
                        root.systemEvidence?.uptimeSeconds)
                color: Looks.colors.subfg
                font.pixelSize: Looks.font.pixelSize.small
            }

            Item { Layout.fillWidth: true }

            WText {
                visible: statusRow.width >= 620
                text: String(root.targetCount) + " "
                    + Translation.tr("targets")
                color: Looks.colors.subfg
                font.pixelSize: Looks.font.pixelSize.small
            }

            WText {
                visible: statusRow.width >= 760
                text: String(root.discoveryEvidence?.boundaryCount ?? 0)
                    + " " + Translation.tr("boundaries")
                color: Looks.colors.subfg
                font.pixelSize: Looks.font.pixelSize.small
            }

            WText {
                visible: statusRow.width >= 900
                text: String(root.collisionCount) + " "
                    + Translation.tr("collisions")
                color: root.collisionCount === 0
                    ? Looks.colors.subfg : Looks.colors.danger
                font.pixelSize: Looks.font.pixelSize.small
            }
        }
    }

    WText {
        Layout.fillWidth: true
        visible: root.primaryError.length > 0
        text: root.primaryError
        color: Looks.colors.danger
        font.pixelSize: Looks.font.pixelSize.small
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    BtopDashboard {
        Layout.fillWidth: true
        compactMode: true
        evidence: root.evidence
        targets: root.runtimeCatalog
        records: root.runtimeRecords
        events: root.runtimeSnapshot?.events ?? []
        selectedTargetId: CodeWorkflowSession.selectedTargetId
    }
}
