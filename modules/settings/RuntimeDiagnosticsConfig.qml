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
    property bool showSourceDetails: false

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
            return Translation.tr("Sampling paused")
        if (root.sessionHasError)
            return Translation.tr("Sampling error")
        if (root.sessionStalled)
            return Translation.tr("Sampling stalled")
        if (!root.samplerRunning || root.systemEvidence === null)
            return Translation.tr("Starting sampler")
        return Translation.tr("Sampling live")
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

    SettingsCardSection {
        expanded: true
        icon: "monitoring"
        title: Translation.tr("Live diagnostics")

        SettingsGroup {
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: sessionLayout.implicitHeight + 20
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1
                border.color: root.sessionHasError || root.sessionStalled
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
                        color: root.sessionHasError || root.sessionStalled
                            ? Appearance.colors.colError
                            : RuntimeDiagnosticsSession.pageCurrent
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colSubtext
                    }

                    StyledText {
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        text: root.sessionStateLabel()
                        color: Appearance.colors.colOnLayer1
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    StyledText {
                        textFormat: Text.PlainText
                        visible: root.samplerRunning
                            && sessionLayout.width >= 420
                        text: root.sampleIntervalLabel()
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }

                    StyledText {
                        textFormat: Text.PlainText
                        text: Translation.tr("Uptime") + " "
                            + root.formatUptime(
                                root.systemEvidence?.uptimeSeconds)
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }

            StyledText {

                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: RuntimeDiagnosticsSession.leaseError.length > 0
                text: Translation.tr("Diagnostics lease error") + " · "
                    + RuntimeDiagnosticsSession.leaseError
                color: Appearance.colors.colError
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            StyledText {

                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: RuntimeDiagnosticsSession.remoteError.length > 0
                text: Translation.tr("Runtime bridge error") + " · "
                    + RuntimeDiagnosticsSession.remoteError
                color: Appearance.colors.colError
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            StyledText {

                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: RuntimeDiagnosticsSession.evidenceError.length > 0
                text: Translation.tr("Runtime evidence error") + " · "
                    + RuntimeDiagnosticsSession.evidenceError
                color: Appearance.colors.colError
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            StyledText {

                textFormat: Text.PlainText
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

    BtopDashboard {
        Layout.fillWidth: true
        evidence: root.evidence
        targets: root.runtimeCatalog
        records: root.runtimeRecords
        selectedTargetId: CodeWorkflowSession.selectedTargetId
        onTargetActivated: (targetId, instanceId) =>
            CodeWorkflowSession.selectTarget(targetId, instanceId)
    }

    SettingsCardSection {
        expanded: true
        icon: "view_list"
        title: Translation.tr("Selected target")

        SettingsGroup {
            BtopTargetInspector {
                Layout.fillWidth: true
                descriptor: root.diagnosticsActive
                    ? CodeWorkflowRuntime.descriptor(
                        CodeWorkflowSession.selectedTargetId)
                    : null
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

                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: root.showSourceDetails
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
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: identityGrid.implicitHeight + 16
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1
                border.color: root.collisionCount === 0
                    ? Appearance.colors.colOutline
                    : Appearance.colors.colError

                GridLayout {
                    id: identityGrid
                    anchors.fill: parent
                    anchors.margins: 8
                    columns: width >= 680 ? 3 : 1
                    columnSpacing: 8
                    rowSpacing: 4

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: Appearance.rounding.normal
                        color: "transparent"
                        border.width: 0

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 2

                            StyledText {

                                textFormat: Text.PlainText
                                text: Translation.tr("Targets")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }

                            StyledText {

                                textFormat: Text.PlainText
                                text: String(root.targetCount)
                                color: Appearance.colors.colPrimary
                                font.weight: Font.DemiBold
                                font.pixelSize: Appearance.font.pixelSize.large
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: Appearance.rounding.normal
                        color: "transparent"
                        border.width: 0

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 2

                            StyledText {

                                textFormat: Text.PlainText
                                text: Translation.tr("Source boundaries")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }

                            StyledText {

                                textFormat: Text.PlainText
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
                        implicitHeight: 52
                        radius: Appearance.rounding.normal
                        color: "transparent"
                        border.width: 0

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 2

                            StyledText {

                                textFormat: Text.PlainText
                                text: Translation.tr("Identity collisions")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }

                            StyledText {

                                textFormat: Text.PlainText
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
            }

            RippleButton {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 154
                implicitHeight: 30
                buttonRadius: height / 2
                buttonText: root.showSourceDetails
                    ? Translation.tr("Hide source details")
                    : Translation.tr("Source details")
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: root.showSourceDetails = !root.showSourceDetails
            }

            BtopCoveragePanel {
                Layout.fillWidth: true
                visible: root.showSourceDetails
                status: String(root.discoveryEvidence?.status ?? "idle")
                boundaryCounts:
                    root.discoveryEvidence?.boundaryCounts ?? ({})
                filesScanned: Number(
                    root.discoveryEvidence?.filesScanned ?? 0)
                cacheHits: Number(
                    root.discoveryEvidence?.cacheHits ?? 0)
            }

            StyledText {

                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: String(root.discoveryEvidence?.error ?? "").length > 0
                text: Translation.tr("Runtime boundary index error") + " · "
                    + String(root.discoveryEvidence?.error ?? "")
                color: Appearance.colors.colError
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            StyledText {

                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: root.showSourceDetails
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

                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: root.showSourceDetails
                    && root.discoveryEvidence?.status === "ready"
                text: Translation.tr("Source boundaries are parser evidence, not proof that a component executed.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
                wrapMode: Text.WordWrap
            }
        }
    }
}
