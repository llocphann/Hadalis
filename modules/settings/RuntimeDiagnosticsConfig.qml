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
    bottomContentPadding: 8

    readonly property bool diagnosticsActive:
        RuntimeDiagnosticsSession.pageCurrent
    readonly property var runtimeCatalog: root.diagnosticsActive
        ? CodeWorkflowRuntime.activeCatalog : []
    readonly property int targetCount: root.runtimeCatalog.length
    readonly property int collisionCount: root.diagnosticsActive
        ? CodeWorkflowRuntime.identityCollisions.length : 0
    readonly property var evidence: RuntimeDiagnosticsSession.evidence
    readonly property var systemEvidence: root.evidence?.system ?? null
    readonly property var discoveryEvidence: root.evidence?.discovery ?? null
    readonly property var runtimeSnapshot: root.diagnosticsActive
        ? CodeWorkflowRuntime.snapshot() : ({ records: [], events: [] })
    readonly property var runtimeRecords:
        root.runtimeSnapshot?.records ?? []
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
            return RuntimeDiagnosticsSession.leaseError
        if (RuntimeDiagnosticsSession.remoteError.length > 0)
            return RuntimeDiagnosticsSession.remoteError
        if (RuntimeDiagnosticsSession.evidenceError.length > 0)
            return RuntimeDiagnosticsSession.evidenceError
        if (root.samplerError.length > 0)
            return root.samplerError
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

    // One compact status strip replaces the old expanded live-sampling card.
    // It keeps useful health/identity context visible without consuming a full
    // vertical section above the actual diagnostics.
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 42
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        border.color: root.sessionHasError || root.sessionStalled
            ? Appearance.colors.colError
            : Qt.rgba(
                Appearance.colors.colPrimary.r,
                Appearance.colors.colPrimary.g,
                Appearance.colors.colPrimary.b,
                0.34)

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
                    ? Appearance.colors.colError
                    : root.samplerRunning
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colSubtext
            }

            StyledText {
                textFormat: Text.PlainText
                text: root.sessionStateLabel()
                color: Appearance.colors.colOnLayer1
                font.weight: Font.DemiBold
            }

            StyledText {
                textFormat: Text.PlainText
                text: Translation.tr("Uptime") + " "
                    + root.formatUptime(
                        root.systemEvidence?.uptimeSeconds)
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }

            Item { Layout.fillWidth: true }

            StyledText {
                textFormat: Text.PlainText
                visible: statusRow.width >= 620
                text: String(root.targetCount) + " "
                    + Translation.tr("targets")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                textFormat: Text.PlainText
                visible: statusRow.width >= 760
                text: String(root.discoveryEvidence?.boundaryCount ?? 0)
                    + " " + Translation.tr("boundaries")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                textFormat: Text.PlainText
                visible: statusRow.width >= 900
                text: String(root.collisionCount) + " "
                    + Translation.tr("collisions")
                color: root.collisionCount === 0
                    ? Appearance.colors.colSubtext
                    : Appearance.colors.colError
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }

    StyledText {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        visible: root.primaryError.length > 0
        text: root.primaryError
        color: Appearance.colors.colError
        font.pixelSize: Appearance.font.pixelSize.smallest
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
