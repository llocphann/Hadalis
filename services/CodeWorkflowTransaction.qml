pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property bool _restoringReloadState: false
    property bool _reloadStateReady: false
    property string status: "clean"
    property string sourcePath: ""
    property string baseSha256: ""
    property string semanticAnchor: ""
    property string replacement: ""
    property var result: ({})
    property var patch: ({})
    property string previewText: ""
    property string error: ""
    property var applyPreparation: ({})
    property string applyPreparationError: ""
    property var applyLifecycleResult: ({})
    property string applyLifecycleError: ""

    // Semantic preview commands. Patch byte ranges are evidence attached to a
    // command, never the command identity.
    property var history: []
    property int historyIndex: -1
    property int _pendingReplaceIndex: -1
    property string _pendingCommandKind: "literal-property"
    property string _pendingPreviewMode: "literal"
    property string _pendingExpectedCurrent: ""
    property string _pendingConnectGraphTargetId: ""
    property string _pendingConnectTargetId: ""
    property string _pendingDisconnectGraphTargetId: ""
    property string _pendingDisconnectEdgeId: ""
    property int _pendingConnectSafetyIndex: -1
    property string _pendingConnectSafetyCandidateSha: ""
    property int _pendingConnectPreparationIndex: -1
    property string _pendingConnectPreparationCandidateSha: ""
    property var connectPreparationCapability: ({
        status: "not-evaluated",
        ready: false,
        reason: "not-evaluated",
        writeAuthorized: false,
        applyEnabled: false,
        artifactsStaged: false
    })
    property string connectPreparationError: ""
    property var connectLifecycleResult: ({})
    property string connectLifecycleError: ""
    property string disconnectPreparationError: ""
    property var disconnectLifecycleResult: ({})
    property string disconnectLifecycleError: ""
    property var disconnectAuthorizationDiagnostics: ({
        status: "not-authorized",
        ready: false,
        reason: "not-authorized"
    })
    property var connectAuthorizationDiagnostics: ({
        status: "not-authorized",
        ready: false,
        reason: "not-authorized"
    })
    property var connectSafetyDiagnostics: ({
        status: "not-evaluated",
        ready: false,
        reason: "not-evaluated",
        writeAuthorized: false
    })
    property var preApplyDiagnostics: ({
        status: "not-evaluated",
        ready: false,
        blockers: ["not-evaluated"]
    })

    readonly property bool dirty: root.status !== "clean"
    readonly property bool preApplyReady:
        root.preApplyDiagnostics?.ready === true
    readonly property bool applyCommandMatchesHandoff:
        !!root.activeCommand
        && String(root.activeCommand?.kind ?? "") === "literal-property"
        && root.historyIndex === reloadState.pendingApplyHistoryIndex
        && String(root.activeCommand?.sourcePath ?? "")
            === reloadState.pendingApplySourcePath
        && String(root.activeCommand?.baseSha256 ?? "")
            === reloadState.pendingApplyBaseSha256
        && String(root.activeCommand?.candidateSha256 ?? "")
            === reloadState.pendingApplyCandidateSha256
        && String(root.activeCommand?.semanticAnchor ?? "")
            === reloadState.pendingApplySemanticAnchor
        && String(root.activeCommand?.replacement ?? "")
            === reloadState.pendingApplyReplacement
    readonly property bool applyEnabled:
        root.applyLifecycleReady
    readonly property bool applyLifecycleBusy:
        [
            "write-issued",
            "waiting-reload",
            "candidate-verify-issued",
            "rebinding",
            "rollback-pending",
            "rollback-issued",
            "rollback-waiting-reload",
            "rollback-verify-issued"
        ].includes(reloadState.pendingApplyPhase)
        || commitProcess.running
        || verifyProcess.running
        || rollbackProcess.running
    readonly property bool applyLifecycleReady:
        root.applyArtifactsReady
        && root.applyCommandMatchesHandoff
        && Quickshell.watchFiles
        && !root.applyLifecycleBusy
        && !root.connectLifecycleBusy
        && !root.disconnectLifecycleBusy
        && reloadState.pendingApplyManifestPath.length > 0
    readonly property bool previewBusy:
        previewProcess.running || connectPreviewProcess.running
    readonly property bool connectSafetyBusy:
        connectSafetyProcess.running
    readonly property bool connectPreparationBusy:
        connectCapabilityProcess.running || connectPrepareProcess.running
    readonly property bool disconnectPreparationBusy:
        disconnectPrepareProcess.running
    readonly property bool disconnectLifecycleBusy:
        [
            "write-issued",
            "waiting-reload",
            "candidate-verify-issued",
            "postcondition-checking",
            "rollback-pending",
            "rollback-issued",
            "rollback-waiting-reload",
            "rollback-verify-issued"
        ].includes(reloadState.pendingDisconnectPhase)
        || disconnectCommitProcess.running
        || disconnectVerifyProcess.running
        || disconnectRollbackProcess.running
    readonly property string pendingDisconnectPhase:
        reloadState.pendingDisconnectPhase
    readonly property var activeDisconnectPreparation:
        root._disconnectPreparationMatchesCommand(root.activeCommand)
            ? root.activeCommand.disconnectPreparation
            : null
    readonly property bool disconnectArtifactsReady:
        root.activeDisconnectPreparation !== null
    readonly property var activeDisconnectAuthorization:
        root._disconnectAuthorizationMatchesCommand(root.activeCommand)
            ? root.activeCommand.disconnectAuthorization
            : null
    readonly property bool disconnectAuthorizationReady:
        root.activeDisconnectAuthorization !== null
        && root.disconnectArtifactsReady
        && root.activeCommand?.stale !== true
    readonly property bool disconnectPrepareEnabled:
        !!root.activeCommand
        && String(root.activeCommand?.kind ?? "") === "disconnect-binding"
        && String(root.activeCommand?.targetId ?? "") === "bar/clock"
        && String(root.activeCommand?.reviewedEdgeId ?? "")
            === "clock.data.time"
        && String(root.activeCommand?.sourcePath ?? "")
            === "modules/bar/ClockWidget.qml"
        && root.activeCommand?.sourceWritable === true
        && root.status === "preview"
        && root.activeCommand?.stale !== true
        && !root.previewBusy
        && !root.disconnectPreparationBusy
        && !root.disconnectLifecycleBusy
        && !root.connectPreparationBusy
        && !root.connectLifecycleBusy
        && !root.applyLifecycleBusy
        && !root.disconnectArtifactsReady
    readonly property bool disconnectAuthorizeEnabled:
        root.disconnectArtifactsReady
        && root.status === "preview"
        && root.activeCommand?.stale !== true
        && !root.previewBusy
        && !root.disconnectPreparationBusy
        && !root.disconnectLifecycleBusy
        && !root.connectPreparationBusy
        && !root.connectLifecycleBusy
        && !root.applyLifecycleBusy
        && !root.disconnectAuthorizationReady
    readonly property bool disconnectApplyEnabled:
        !!root.activeCommand
        && String(root.activeCommand?.kind ?? "") === "disconnect-binding"
        && root.disconnectAuthorizationReady
        && root.disconnectArtifactsReady
        && root.status === "preview"
        && Quickshell.watchFiles
        && reloadState.pendingDisconnectPhase === "idle"
        && root.activeCommand?.stale !== true
        && !root.previewBusy
        && !root.disconnectPreparationBusy
        && !root.disconnectLifecycleBusy
        && !root.connectPreparationBusy
        && !root.connectLifecycleBusy
        && !root.applyLifecycleBusy
    readonly property bool connectLifecycleBusy:
        [
            "write-issued",
            "waiting-reload",
            "candidate-verify-issued",
            "rebinding",
            "rollback-pending",
            "rollback-issued",
            "rollback-waiting-reload",
            "rollback-verify-issued"
        ].includes(reloadState.pendingConnectPhase)
        || connectCommitProcess.running
        || connectVerifyProcess.running
        || connectRollbackProcess.running
    readonly property string pendingConnectPhase:
        reloadState.pendingConnectPhase
    readonly property var activeConnectSafety:
        root._connectSafetyMatchesCommand(root.activeCommand, false)
            ? root.activeCommand.connectSafety
            : null
    readonly property bool connectSafetySnapshotReady:
        root._connectSafetyMatchesCommand(root.activeCommand, true)
    readonly property var activeConnectPreparation:
        root._connectPreparationMatchesCommand(root.activeCommand)
            ? root.activeCommand.connectPreparation
            : null
    readonly property bool connectArtifactsReady:
        root.activeConnectPreparation !== null
        && root.connectSafetySnapshotReady
    readonly property var activeConnectAuthorization:
        root._connectAuthorizationMatchesCommand(root.activeCommand)
            ? root.activeCommand.connectAuthorization
            : null
    readonly property bool connectAuthorizationReady:
        root.activeConnectAuthorization !== null
        && root.connectArtifactsReady
        && root.connectPreparationCapability?.ready === true
        && root.activeCommand?.stale !== true
    readonly property bool connectAuthorizeEnabled:
        root.connectArtifactsReady
        && root.connectPreparationCapability?.ready === true
        && root.status === "preview"
        && root.activeCommand?.stale !== true
        && !root.previewBusy
        && !root.connectSafetyBusy
        && !root.connectPreparationBusy
        && !root.connectLifecycleBusy
        && !root.disconnectPreparationBusy
        && !root.disconnectLifecycleBusy
        && !root.applyLifecycleBusy
        && !root.connectAuthorizationReady
    readonly property bool connectApplyEnabled:
        !!root.activeCommand
        && String(root.activeCommand?.kind ?? "") === "connect-binding"
        && root.connectAuthorizationReady
        && root.connectArtifactsReady
        && root.connectPreparationCapability?.ready === true
        && root.status === "preview"
        && reloadState.pendingConnectPhase === "idle"
        && root.activeCommand?.stale !== true
        && !root.previewBusy
        && !root.connectSafetyBusy
        && !root.connectPreparationBusy
        && !root.connectLifecycleBusy
        && !root.disconnectPreparationBusy
        && !root.disconnectLifecycleBusy
        && !root.applyLifecycleBusy
    readonly property bool connectPrepareEnabled:
        !!root.activeCommand
        && String(root.activeCommand?.kind ?? "") === "connect-binding"
        && root.status === "preview"
        && root.activeCommand?.stale !== true
        && root.connectPreparationCapability?.ready === true
        && !root.previewBusy
        && !root.connectSafetyBusy
        && !root.connectPreparationBusy
        && !root.connectLifecycleBusy
        && !root.disconnectPreparationBusy
        && !root.disconnectLifecycleBusy
        && !applyPrepareProcess.running
        && !root.applyLifecycleBusy
        && !root.connectArtifactsReady
    readonly property bool canUndo:
        !root.previewBusy
        && !root.connectSafetyBusy
        && !root.connectPreparationBusy
        && !root.connectLifecycleBusy
        && !root.disconnectPreparationBusy
        && !root.disconnectLifecycleBusy
        && !applyPrepareProcess.running
        && !root.applyLifecycleBusy
        && root.historyIndex >= 0
    readonly property bool canRedo:
        !root.previewBusy
        && !root.connectSafetyBusy
        && !root.connectPreparationBusy
        && !root.connectLifecycleBusy
        && !root.disconnectPreparationBusy
        && !root.disconnectLifecycleBusy
        && !applyPrepareProcess.running
        && !root.applyLifecycleBusy
        && root.historyIndex + 1 < root.history.length
    readonly property var activeCommand:
        root.historyIndex >= 0 && root.historyIndex < root.history.length
            ? root.history[root.historyIndex]
            : null
    readonly property string historyLabel:
        root.history.length > 0
            ? (root.historyIndex + 1) + "/" + root.history.length
            : "0/0"
    readonly property string pendingApplyPhase:
        reloadState.pendingApplyPhase
    readonly property bool pendingApplyPrepared:
        reloadState.pendingApplyPhase === "prepared"
    readonly property bool applyArtifactsReady:
        reloadState.pendingApplyPhase === "artifacts-prepared"
    readonly property bool prepareApplyEnabled:
        root.preApplyReady
        && reloadState.pendingApplyPhase === "idle"
        && !applyPrepareProcess.running
        && !root.applyLifecycleBusy
        && !root.connectLifecycleBusy
        && !root.disconnectLifecycleBusy
        && !root.disconnectPreparationBusy

    readonly property string reloadStateJson: JSON.stringify({
        version: 1,
        historyJson: JSON.stringify(root.history ?? []),
        historyIndex: root.historyIndex,
        pendingApplyPhase: reloadState.pendingApplyPhase,
        pendingApplySourcePath: reloadState.pendingApplySourcePath,
        pendingApplyBaseSha256: reloadState.pendingApplyBaseSha256,
        pendingApplyCandidateSha256:
            reloadState.pendingApplyCandidateSha256,
        pendingApplySemanticAnchor:
            reloadState.pendingApplySemanticAnchor,
        pendingApplyReplacement:
            reloadState.pendingApplyReplacement,
        pendingApplyHistoryIndex:
            reloadState.pendingApplyHistoryIndex,
        pendingApplySnapshotPath:
            reloadState.pendingApplySnapshotPath,
        pendingApplyCandidatePath:
            reloadState.pendingApplyCandidatePath,
        pendingApplyManifestPath:
            reloadState.pendingApplyManifestPath,
        pendingApplyReloadOutcome:
            reloadState.pendingApplyReloadOutcome,
        pendingApplyVerifyState:
            reloadState.pendingApplyVerifyState,
        pendingApplyError: reloadState.pendingApplyError,
        pendingConnectPhase: reloadState.pendingConnectPhase,
        pendingConnectGraphTargetId:
            reloadState.pendingConnectGraphTargetId,
        pendingConnectTargetId:
            reloadState.pendingConnectTargetId,
        pendingConnectSourcePath:
            reloadState.pendingConnectSourcePath,
        pendingConnectBaseSha256:
            reloadState.pendingConnectBaseSha256,
        pendingConnectCandidateSha256:
            reloadState.pendingConnectCandidateSha256,
        pendingConnectParentSemanticAnchor:
            reloadState.pendingConnectParentSemanticAnchor,
        pendingConnectInsertedSemanticAnchor:
            reloadState.pendingConnectInsertedSemanticAnchor,
        pendingConnectHistoryIndex:
            reloadState.pendingConnectHistoryIndex,
        pendingConnectManifestPath:
            reloadState.pendingConnectManifestPath,
        pendingConnectManifestSha256:
            reloadState.pendingConnectManifestSha256,
        pendingConnectExternalSourcePath:
            reloadState.pendingConnectExternalSourcePath,
        pendingConnectExternalSourceSha256:
            reloadState.pendingConnectExternalSourceSha256,
        pendingConnectAuthorizationToken:
            reloadState.pendingConnectAuthorizationToken,
        pendingConnectReloadOutcome:
            reloadState.pendingConnectReloadOutcome,
        pendingConnectVerifyState:
            reloadState.pendingConnectVerifyState,
        pendingConnectRollbackRecovery:
            reloadState.pendingConnectRollbackRecovery,
        pendingConnectError:
            reloadState.pendingConnectError,
        pendingDisconnectPhase:
            reloadState.pendingDisconnectPhase,
        pendingDisconnectGraphTargetId:
            reloadState.pendingDisconnectGraphTargetId,
        pendingDisconnectEdgeId:
            reloadState.pendingDisconnectEdgeId,
        pendingDisconnectSourcePath:
            reloadState.pendingDisconnectSourcePath,
        pendingDisconnectBaseSha256:
            reloadState.pendingDisconnectBaseSha256,
        pendingDisconnectCandidateSha256:
            reloadState.pendingDisconnectCandidateSha256,
        pendingDisconnectSemanticAnchor:
            reloadState.pendingDisconnectSemanticAnchor,
        pendingDisconnectHistoryIndex:
            reloadState.pendingDisconnectHistoryIndex,
        pendingDisconnectManifestPath:
            reloadState.pendingDisconnectManifestPath,
        pendingDisconnectManifestSha256:
            reloadState.pendingDisconnectManifestSha256,
        pendingDisconnectAuthorizationToken:
            reloadState.pendingDisconnectAuthorizationToken,
        pendingDisconnectReloadOutcome:
            reloadState.pendingDisconnectReloadOutcome,
        pendingDisconnectVerifyState:
            reloadState.pendingDisconnectVerifyState,
        pendingDisconnectRollbackRecovery:
            reloadState.pendingDisconnectRollbackRecovery,
        pendingDisconnectError:
            reloadState.pendingDisconnectError
    })

    function _syncReloadState(): void {
        if (!root._reloadStateReady || root._restoringReloadState)
            return
        reloadState.historyJson = JSON.stringify(root.history ?? [])
        reloadState.historyIndex = root.historyIndex
    }

    function _restoreReloadState(): void {
        root._restoringReloadState = true
        let parsed = []
        try {
            const decoded = JSON.parse(
                String(reloadState.historyJson ?? "[]"))
            parsed = Array.isArray(decoded) ? decoded : []
        } catch (e) {
            parsed = []
        }

        const connectPhase = String(
            reloadState.pendingConnectPhase ?? "idle")
        const activeConnectPhases = [
            "write-issued",
            "waiting-reload",
            "candidate-verify-issued",
            "rebinding",
            "rollback-pending",
            "rollback-issued",
            "rollback-waiting-reload",
            "rollback-verify-issued"
        ]
        const disconnectPhase = String(
            reloadState.pendingDisconnectPhase ?? "idle")
        const activeDisconnectPhases = [
            "write-issued",
            "waiting-reload",
            "candidate-verify-issued",
            "postcondition-checking",
            "rollback-pending",
            "rollback-issued",
            "rollback-waiting-reload",
            "rollback-verify-issued"
        ]
        root.history = parsed.map((command, index) => {
            let next = command
            if (command?.connectSafety) {
                next = Object.assign({}, next, {
                    connectSafety: Object.assign(
                        {},
                        command.connectSafety,
                        {
                            freshness: "pending",
                            stale: false,
                            staleReason:
                                "cross-generation-reverification-required"
                        })
                })
            }

            const authorization = command?.connectAuthorization
            const preserveAuthorization =
                !!authorization
                && activeConnectPhases.includes(connectPhase)
                && index === Number(
                    reloadState.pendingConnectHistoryIndex ?? -1)
                && String(command?.candidateSha256 ?? "")
                    === String(
                        reloadState.pendingConnectCandidateSha256 ?? "")
                && String(authorization?.authorizationToken ?? "")
                    === String(
                        reloadState.pendingConnectAuthorizationToken ?? "")
            if (authorization && !preserveAuthorization) {
                next = Object.assign({}, next, {
                    connectAuthorization: Object.assign(
                        {},
                        authorization,
                        {
                            status: "expired",
                            authorized: false,
                            reason:
                                "cross-generation-reauthorization-required"
                        })
                })
            }

            const disconnectAuthorization =
                command?.disconnectAuthorization
            const preserveDisconnectAuthorization =
                !!disconnectAuthorization
                && activeDisconnectPhases.includes(disconnectPhase)
                && index === Number(
                    reloadState.pendingDisconnectHistoryIndex ?? -1)
                && String(command?.candidateSha256 ?? "")
                    === String(
                        reloadState.pendingDisconnectCandidateSha256 ?? "")
                && String(
                    disconnectAuthorization?.authorizationToken ?? "")
                    === String(
                        reloadState.pendingDisconnectAuthorizationToken ?? "")
            if (disconnectAuthorization
                    && !preserveDisconnectAuthorization) {
                next = Object.assign({}, next, {
                    disconnectAuthorization: Object.assign(
                        {},
                        disconnectAuthorization,
                        {
                            status: "expired",
                            authorized: false,
                            reason:
                                "cross-generation-reauthorization-required"
                        })
                })
            }
            return next
        })
        root.historyIndex = Math.max(
            -1,
            Math.min(
                Number(reloadState.historyIndex ?? -1),
                parsed.length - 1))
        root._restoringReloadState = false
        root._reloadStateReady = true
        root._showCommand(root.activeCommand)
        Qt.callLater(root._recoverApplyLifecycle)
        Qt.callLater(root._recoverConnectLifecycle)
        Qt.callLater(root._recoverDisconnectLifecycle)
        Qt.callLater(root.reverifyActiveConnectSafety)
        Qt.callLater(root.probeActiveConnectPreparationCapability)
    }

    function restoreReloadStateJson(encoded: string): bool {
        const raw = String(encoded ?? "").trim()
        if (raw.length === 0)
            return false

        let snapshot = null
        try {
            snapshot = JSON.parse(raw)
        } catch (e) {
            return false
        }
        if (!snapshot || Number(snapshot.version ?? 0) !== 1)
            return false

        root._restoringReloadState = true
        reloadState.historyJson = String(
            snapshot.historyJson ?? "[]")
        reloadState.historyIndex = Number(
            snapshot.historyIndex ?? -1)
        reloadState.pendingApplyPhase = String(
            snapshot.pendingApplyPhase ?? "idle")
        reloadState.pendingApplySourcePath = String(
            snapshot.pendingApplySourcePath ?? "")
        reloadState.pendingApplyBaseSha256 = String(
            snapshot.pendingApplyBaseSha256 ?? "")
        reloadState.pendingApplyCandidateSha256 = String(
            snapshot.pendingApplyCandidateSha256 ?? "")
        reloadState.pendingApplySemanticAnchor = String(
            snapshot.pendingApplySemanticAnchor ?? "")
        reloadState.pendingApplyReplacement = String(
            snapshot.pendingApplyReplacement ?? "")
        reloadState.pendingApplyHistoryIndex = Number(
            snapshot.pendingApplyHistoryIndex ?? -1)
        reloadState.pendingApplySnapshotPath = String(
            snapshot.pendingApplySnapshotPath ?? "")
        reloadState.pendingApplyCandidatePath = String(
            snapshot.pendingApplyCandidatePath ?? "")
        reloadState.pendingApplyManifestPath = String(
            snapshot.pendingApplyManifestPath ?? "")
        reloadState.pendingApplyReloadOutcome = String(
            snapshot.pendingApplyReloadOutcome ?? "none")
        reloadState.pendingApplyVerifyState = String(
            snapshot.pendingApplyVerifyState ?? "unknown")
        reloadState.pendingApplyError = String(
            snapshot.pendingApplyError ?? "")
        reloadState.pendingConnectPhase = String(
            snapshot.pendingConnectPhase ?? "idle")
        reloadState.pendingConnectGraphTargetId = String(
            snapshot.pendingConnectGraphTargetId ?? "")
        reloadState.pendingConnectTargetId = String(
            snapshot.pendingConnectTargetId ?? "")
        reloadState.pendingConnectSourcePath = String(
            snapshot.pendingConnectSourcePath ?? "")
        reloadState.pendingConnectBaseSha256 = String(
            snapshot.pendingConnectBaseSha256 ?? "")
        reloadState.pendingConnectCandidateSha256 = String(
            snapshot.pendingConnectCandidateSha256 ?? "")
        reloadState.pendingConnectParentSemanticAnchor = String(
            snapshot.pendingConnectParentSemanticAnchor ?? "")
        reloadState.pendingConnectInsertedSemanticAnchor = String(
            snapshot.pendingConnectInsertedSemanticAnchor ?? "")
        reloadState.pendingConnectHistoryIndex = Number(
            snapshot.pendingConnectHistoryIndex ?? -1)
        reloadState.pendingConnectManifestPath = String(
            snapshot.pendingConnectManifestPath ?? "")
        reloadState.pendingConnectManifestSha256 = String(
            snapshot.pendingConnectManifestSha256 ?? "")
        reloadState.pendingConnectExternalSourcePath = String(
            snapshot.pendingConnectExternalSourcePath ?? "")
        reloadState.pendingConnectExternalSourceSha256 = String(
            snapshot.pendingConnectExternalSourceSha256 ?? "")
        reloadState.pendingConnectAuthorizationToken = String(
            snapshot.pendingConnectAuthorizationToken ?? "")
        reloadState.pendingConnectReloadOutcome = String(
            snapshot.pendingConnectReloadOutcome ?? "none")
        reloadState.pendingConnectVerifyState = String(
            snapshot.pendingConnectVerifyState ?? "unknown")
        reloadState.pendingConnectRollbackRecovery = String(
            snapshot.pendingConnectRollbackRecovery ?? "none")
        reloadState.pendingConnectError = String(
            snapshot.pendingConnectError ?? "")
        reloadState.pendingDisconnectPhase = String(
            snapshot.pendingDisconnectPhase ?? "idle")
        reloadState.pendingDisconnectGraphTargetId = String(
            snapshot.pendingDisconnectGraphTargetId ?? "")
        reloadState.pendingDisconnectEdgeId = String(
            snapshot.pendingDisconnectEdgeId ?? "")
        reloadState.pendingDisconnectSourcePath = String(
            snapshot.pendingDisconnectSourcePath ?? "")
        reloadState.pendingDisconnectBaseSha256 = String(
            snapshot.pendingDisconnectBaseSha256 ?? "")
        reloadState.pendingDisconnectCandidateSha256 = String(
            snapshot.pendingDisconnectCandidateSha256 ?? "")
        reloadState.pendingDisconnectSemanticAnchor = String(
            snapshot.pendingDisconnectSemanticAnchor ?? "")
        reloadState.pendingDisconnectHistoryIndex = Number(
            snapshot.pendingDisconnectHistoryIndex ?? -1)
        reloadState.pendingDisconnectManifestPath = String(
            snapshot.pendingDisconnectManifestPath ?? "")
        reloadState.pendingDisconnectManifestSha256 = String(
            snapshot.pendingDisconnectManifestSha256 ?? "")
        reloadState.pendingDisconnectAuthorizationToken = String(
            snapshot.pendingDisconnectAuthorizationToken ?? "")
        reloadState.pendingDisconnectReloadOutcome = String(
            snapshot.pendingDisconnectReloadOutcome ?? "none")
        reloadState.pendingDisconnectVerifyState = String(
            snapshot.pendingDisconnectVerifyState ?? "unknown")
        reloadState.pendingDisconnectRollbackRecovery = String(
            snapshot.pendingDisconnectRollbackRecovery ?? "none")
        reloadState.pendingDisconnectError = String(
            snapshot.pendingDisconnectError ?? "")
        root._restoringReloadState = false

        root._restoreReloadState()
        return true
    }

    function _disconnectPreparationMatchesCommand(command): bool {
        if (!command
                || command.stale === true
                || String(command.kind ?? "") !== "disconnect-binding"
                || String(command.targetId ?? "") !== "bar/clock"
                || String(command.reviewedEdgeId ?? "")
                    !== "clock.data.time"
                || String(command.sourcePath ?? "")
                    !== "modules/bar/ClockWidget.qml"
                || String(command.expectedCurrent ?? "")
                    !== "DateTime.timeDisplay")
            return false

        const prepared = command.disconnectPreparation
        if (!prepared || Number(prepared.version ?? 0) !== 1)
            return false

        return String(prepared.status ?? "") === "prepared"
            && prepared.stale !== true
            && String(prepared.artifactProof ?? "")
                === "prepared-reviewed-disconnect-artifacts-v1"
            && String(prepared.graphTargetId ?? "")
                === String(command.targetId ?? "")
            && String(prepared.reviewedEdgeId ?? "")
                === String(command.reviewedEdgeId ?? "")
            && String(prepared.sourcePath ?? "")
                === String(command.sourcePath ?? "")
            && String(prepared.baseSha256 ?? "")
                === String(command.baseSha256 ?? "")
            && String(prepared.candidateSha256 ?? "")
                === String(command.candidateSha256 ?? "")
            && String(prepared.semanticAnchor ?? "")
                === String(command.semanticAnchor ?? "")
            && String(prepared.propertyName ?? "") === "text"
            && String(prepared.expectedCurrent ?? "")
                === String(command.expectedCurrent ?? "")
            && String(prepared.resultingState ?? "")
                === "unbound/default"
            && String(prepared.postcondition ?? "")
                === "semantic-anchor-missing"
            && String(prepared.candidatePostconditionStatus ?? "")
                === "missing"
            && String(prepared.manifestPath ?? "").length > 0
            && root._sha256LooksValid(prepared.manifestSha256)
            && prepared.writeAuthorized === false
            && prepared.applyEnabled === false
            && prepared.artifactsStaged === true
            && prepared.productionIntegrated === false
    }

    function _sanitizeDisconnectPreparation(payload): var {
        return {
            version: 1,
            status: "prepared",
            stale: false,
            staleReason: "",
            artifactProof: String(payload?.artifactProof ?? ""),
            graphTargetId: String(payload?.graphTargetId ?? ""),
            reviewedEdgeId: String(payload?.reviewedEdgeId ?? ""),
            transactionId: String(payload?.transactionId ?? ""),
            sourcePath: String(payload?.sourcePath ?? ""),
            baseSha256: String(payload?.baseSha256 ?? ""),
            candidateSha256: String(payload?.candidateSha256 ?? ""),
            semanticAnchor: String(payload?.semanticAnchor ?? ""),
            propertyName: String(payload?.propertyName ?? ""),
            expectedCurrent: String(payload?.expectedCurrent ?? ""),
            resultingState: String(payload?.resultingState ?? ""),
            postcondition: String(payload?.postcondition ?? ""),
            candidatePostconditionStatus: String(
                payload?.candidatePostcondition?.status ?? ""),
            snapshotPath: String(payload?.snapshotPath ?? ""),
            candidatePath: String(payload?.candidatePath ?? ""),
            manifestPath: String(payload?.manifestPath ?? ""),
            manifestSha256: String(payload?.manifestSha256 ?? ""),
            writeAuthorized: false,
            applyEnabled: false,
            artifactsStaged: true,
            productionIntegrated: false
        }
    }

    function prepareDisconnectArtifacts(): bool {
        const command = root.activeCommand
        if (!root.disconnectPrepareEnabled || !command)
            return false

        root.disconnectPreparationError = ""
        disconnectPrepareProcess.command = [
            "python3",
            Quickshell.shellPath(
                "scripts/code-workflow/disconnect_prepare.py"),
            "--edge-id", String(command.reviewedEdgeId ?? ""),
            "--base-sha256", String(command.baseSha256 ?? ""),
            "--expected-candidate-sha256",
                String(command.candidateSha256 ?? ""),
            "--semantic-anchor", String(command.semanticAnchor ?? ""),
            "--state-dir",
                Quickshell.statePath(
                    "code-workflow/disconnect-transactions")
        ]
        disconnectPrepareProcess.running = true
        return true
    }

    function finishDisconnectPreparation(exitCode: int): void {
        const payload = root._parseProcessPayload(
            disconnectPrepareStdout)
        const command = root.activeCommand
        const exact = payload?.protocol === 1
            && String(payload?.status ?? "")
                === "prepared-disconnect-artifacts"
            && !!command
            && String(command.kind ?? "") === "disconnect-binding"
            && String(payload?.graphTargetId ?? "")
                === String(command.targetId ?? "")
            && String(payload?.reviewedEdgeId ?? "")
                === String(command.reviewedEdgeId ?? "")
            && String(payload?.sourcePath ?? "")
                === String(command.sourcePath ?? "")
            && String(payload?.baseSha256 ?? "")
                === String(command.baseSha256 ?? "")
            && String(payload?.candidateSha256 ?? "")
                === String(command.candidateSha256 ?? "")
            && String(payload?.semanticAnchor ?? "")
                === String(command.semanticAnchor ?? "")
            && String(payload?.expectedCurrent ?? "")
                === String(command.expectedCurrent ?? "")
            && String(payload?.propertyName ?? "") === "text"
            && String(payload?.postcondition ?? "")
                === "semantic-anchor-missing"
            && String(payload?.candidatePostcondition?.status ?? "")
                === "missing"
            && payload?.writeAuthorized === false
            && payload?.applyEnabled === false
            && payload?.artifactsStaged === true
            && payload?.productionIntegrated === false

        if (exact) {
            const prepared =
                root._sanitizeDisconnectPreparation(payload)
            const promoted = Object.assign({}, command, {
                disconnectPreparation: prepared
            })
            if (root._disconnectPreparationMatchesCommand(promoted)) {
                const index = root.historyIndex
                const next = root.history.slice()
                next[index] = promoted
                root.history = next
                root.disconnectPreparationError = ""
                root.status = "preview"
                return
            }
        }

        const stderrText = String(
            disconnectPrepareStderr.text ?? "").trim()
        root.disconnectPreparationError = String(
            payload?.detail
            ?? payload?.reason
            ?? stderrText
            ?? ("Disconnect preparation exited " + exitCode))
        root.status = payload?.status === "conflict"
            ? "conflict"
            : "error"
        root.error = root.disconnectPreparationError
    }

    function _disconnectAuthorizationIdentityMatchesCommand(
        command
    ): bool {
        if (!command
                || String(command.kind ?? "") !== "disconnect-binding"
                || !root._disconnectPreparationMatchesCommand(command))
            return false
        const authorization = command.disconnectAuthorization
        const prepared = command.disconnectPreparation
        if (!authorization
                || Number(authorization.version ?? 0) !== 1)
            return false

        return String(authorization.status ?? "") === "authorized"
            && authorization.authorized === true
            && String(authorization.authorizationProof ?? "")
                === "explicit-disconnect-write-authorization-v1"
            && String(authorization.authorizationToken ?? "")
                === "disconnect-authorized:"
                    + String(prepared.transactionId ?? "")
                    + ":" + String(command.candidateSha256 ?? "")
            && String(authorization.graphTargetId ?? "")
                === String(command.targetId ?? "")
            && String(authorization.reviewedEdgeId ?? "")
                === String(command.reviewedEdgeId ?? "")
            && String(authorization.sourcePath ?? "")
                === String(command.sourcePath ?? "")
            && String(authorization.baseSha256 ?? "")
                === String(command.baseSha256 ?? "")
            && String(authorization.candidateSha256 ?? "")
                === String(command.candidateSha256 ?? "")
            && String(authorization.semanticAnchor ?? "")
                === String(command.semanticAnchor ?? "")
            && String(authorization.propertyName ?? "") === "text"
            && String(authorization.expectedCurrent ?? "")
                === String(command.expectedCurrent ?? "")
            && String(authorization.resultingState ?? "")
                === "unbound/default"
            && String(authorization.postcondition ?? "")
                === "semantic-anchor-missing"
            && String(authorization.manifestPath ?? "")
                === String(prepared.manifestPath ?? "")
            && String(authorization.manifestSha256 ?? "")
                === String(prepared.manifestSha256 ?? "")
            && root._sha256LooksValid(authorization.manifestSha256)
            && String(authorization.transactionId ?? "")
                === String(prepared.transactionId ?? "")
            && String(authorization.rollbackGuarantee ?? "")
                === "exact-snapshot-auto-rollback-v1"
    }

    function _disconnectAuthorizationMatchesCommand(command): bool {
        return !!command
            && command.stale !== true
            && root._disconnectPreparationMatchesCommand(command)
            && root._disconnectAuthorizationIdentityMatchesCommand(command)
    }

    function _expireDisconnectAuthorization(
        command,
        reason: string
    ): var {
        const authorization = command?.disconnectAuthorization
        if (!authorization
                || authorization.authorized !== true
                || String(authorization.status ?? "")
                    !== "authorized")
            return command
        return Object.assign({}, command, {
            disconnectAuthorization: Object.assign({}, authorization, {
                status: "expired",
                authorized: false,
                reason: String(reason ?? "authorization-expired")
            })
        })
    }

    function _expireAllDisconnectAuthorizations(
        reason: string
    ): void {
        let changed = false
        const next = root.history.map(command => {
            const expired = root._expireDisconnectAuthorization(
                command, reason)
            if (expired !== command)
                changed = true
            return expired
        })
        if (changed)
            root.history = next
        root.disconnectAuthorizationDiagnostics = ({
            status: "expired",
            ready: false,
            reason: String(reason ?? "authorization-expired")
        })
    }

    function authorizeDisconnectWrite(): bool {
        if (!root.disconnectAuthorizeEnabled)
            return false
        const command = root.activeCommand
        const prepared = root.activeDisconnectPreparation
        if (!command || !prepared)
            return false

        const authorization = {
            version: 1,
            status: "authorized",
            authorized: true,
            reason: "explicit-user-authorization",
            authorizationProof:
                "explicit-disconnect-write-authorization-v1",
            authorizationToken:
                "disconnect-authorized:"
                    + String(prepared.transactionId ?? "")
                    + ":" + String(command.candidateSha256 ?? ""),
            graphTargetId: String(command.targetId ?? ""),
            reviewedEdgeId: String(command.reviewedEdgeId ?? ""),
            sourcePath: String(command.sourcePath ?? ""),
            baseSha256: String(command.baseSha256 ?? ""),
            candidateSha256: String(command.candidateSha256 ?? ""),
            semanticAnchor: String(command.semanticAnchor ?? ""),
            propertyName: "text",
            expectedCurrent: String(command.expectedCurrent ?? ""),
            resultingState: "unbound/default",
            postcondition: "semantic-anchor-missing",
            manifestPath: String(prepared.manifestPath ?? ""),
            manifestSha256: String(prepared.manifestSha256 ?? ""),
            transactionId: String(prepared.transactionId ?? ""),
            rollbackGuarantee:
                "exact-snapshot-auto-rollback-v1"
        }
        const promoted = Object.assign({}, command, {
            disconnectAuthorization: authorization
        })
        if (!root._disconnectAuthorizationMatchesCommand(promoted))
            return false

        const index = root.historyIndex
        if (index < 0 || index >= root.history.length)
            return false
        const next = root.history.slice()
        next[index] = promoted
        root.history = next
        root.disconnectAuthorizationDiagnostics = ({
            status: "authorized",
            ready: true,
            reason: "explicit-user-authorization",
            authorizationToken:
                authorization.authorizationToken
        })
        return true
    }

    function revokeDisconnectAuthorization(
        reason: string
    ): bool {
        if (root.disconnectLifecycleBusy)
            return false
        const command = root.activeCommand
        if (!command?.disconnectAuthorization)
            return false
        const index = root.historyIndex
        if (index < 0 || index >= root.history.length)
            return false

        const next = root.history.slice()
        next[index] = root._expireDisconnectAuthorization(
            command,
            String(reason ?? "user-revoked"))
        root.history = next
        root.disconnectAuthorizationDiagnostics = ({
            status: "expired",
            ready: false,
            reason: String(reason ?? "user-revoked")
        })
        return true
    }

    function _disconnectLifecycleCommandMatchesHandoff(): bool {
        const command = root.activeCommand
        const prepared = command?.disconnectPreparation
        return !!command
            && String(command.kind ?? "") === "disconnect-binding"
            && root.historyIndex
                === reloadState.pendingDisconnectHistoryIndex
            && String(command.targetId ?? "")
                === reloadState.pendingDisconnectGraphTargetId
            && String(command.reviewedEdgeId ?? "")
                === reloadState.pendingDisconnectEdgeId
            && String(command.sourcePath ?? "")
                === reloadState.pendingDisconnectSourcePath
            && String(command.baseSha256 ?? "")
                === reloadState.pendingDisconnectBaseSha256
            && String(command.candidateSha256 ?? "")
                === reloadState.pendingDisconnectCandidateSha256
            && String(command.semanticAnchor ?? "")
                === reloadState.pendingDisconnectSemanticAnchor
            && String(prepared?.manifestPath ?? "")
                === reloadState.pendingDisconnectManifestPath
            && String(prepared?.manifestSha256 ?? "")
                === reloadState.pendingDisconnectManifestSha256
            && root._disconnectAuthorizationIdentityMatchesCommand(
                command)
            && String(
                command?.disconnectAuthorization?.authorizationToken
                    ?? "")
                === reloadState.pendingDisconnectAuthorizationToken
    }

    function stageDisconnectLifecycleHandoff(): bool {
        const command = root.activeCommand
        const prepared = root.activeDisconnectPreparation
        if (!root.disconnectAuthorizationReady
                || !root.disconnectArtifactsReady
                || !command
                || !prepared
                || command.stale === true
                || String(command.kind ?? "") !== "disconnect-binding"
                || !Quickshell.watchFiles
                || root.applyLifecycleBusy
                || root.connectLifecycleBusy
                || root.disconnectLifecycleBusy)
            return false

        reloadState.pendingDisconnectPhase = "prepared"
        reloadState.pendingDisconnectGraphTargetId = String(
            command.targetId ?? "")
        reloadState.pendingDisconnectEdgeId = String(
            command.reviewedEdgeId ?? "")
        reloadState.pendingDisconnectSourcePath = String(
            command.sourcePath ?? "")
        reloadState.pendingDisconnectBaseSha256 = String(
            command.baseSha256 ?? "")
        reloadState.pendingDisconnectCandidateSha256 = String(
            command.candidateSha256 ?? "")
        reloadState.pendingDisconnectSemanticAnchor = String(
            command.semanticAnchor ?? "")
        reloadState.pendingDisconnectHistoryIndex = root.historyIndex
        reloadState.pendingDisconnectManifestPath = String(
            prepared.manifestPath ?? "")
        reloadState.pendingDisconnectManifestSha256 = String(
            prepared.manifestSha256 ?? "")
        reloadState.pendingDisconnectAuthorizationToken = String(
            command.disconnectAuthorization?.authorizationToken ?? "")
        reloadState.pendingDisconnectReloadOutcome = "none"
        reloadState.pendingDisconnectVerifyState = "unknown"
        reloadState.pendingDisconnectRollbackRecovery = "none"
        reloadState.pendingDisconnectError = ""
        return root._disconnectLifecycleCommandMatchesHandoff()
    }

    function clearDisconnectLifecycleHandoff(): void {
        disconnectRollbackReloadFallbackTimer.stop()
        reloadState.pendingDisconnectPhase = "idle"
        reloadState.pendingDisconnectGraphTargetId = ""
        reloadState.pendingDisconnectEdgeId = ""
        reloadState.pendingDisconnectSourcePath = ""
        reloadState.pendingDisconnectBaseSha256 = ""
        reloadState.pendingDisconnectCandidateSha256 = ""
        reloadState.pendingDisconnectSemanticAnchor = ""
        reloadState.pendingDisconnectHistoryIndex = -1
        reloadState.pendingDisconnectManifestPath = ""
        reloadState.pendingDisconnectManifestSha256 = ""
        reloadState.pendingDisconnectAuthorizationToken = ""
        reloadState.pendingDisconnectReloadOutcome = "none"
        reloadState.pendingDisconnectVerifyState = "unknown"
        reloadState.pendingDisconnectRollbackRecovery = "none"
        reloadState.pendingDisconnectError = ""
    }

    function _disconnectPayloadMatchesPending(payload): bool {
        return String(payload?.graphTargetId ?? "")
                === reloadState.pendingDisconnectGraphTargetId
            && String(payload?.reviewedEdgeId ?? "")
                === reloadState.pendingDisconnectEdgeId
            && String(payload?.sourcePath ?? "")
                === reloadState.pendingDisconnectSourcePath
            && String(payload?.baseSha256 ?? "")
                === reloadState.pendingDisconnectBaseSha256
            && String(payload?.candidateSha256 ?? "")
                === reloadState.pendingDisconnectCandidateSha256
            && String(payload?.semanticAnchor ?? "")
                === reloadState.pendingDisconnectSemanticAnchor
            && String(payload?.propertyName ?? "") === "text"
            && String(payload?.expectedCurrent ?? "")
                === "DateTime.timeDisplay"
            && String(payload?.postcondition ?? "")
                === "semantic-anchor-missing"
            && String(payload?.manifestPath ?? "")
                === reloadState.pendingDisconnectManifestPath
            && String(payload?.manifestSha256 ?? "")
                === reloadState.pendingDisconnectManifestSha256
    }

    function _setDisconnectLifecycleFailure(
        phase: string,
        message: string,
        payload
    ): void {
        reloadState.pendingDisconnectPhase = phase
        reloadState.pendingDisconnectError = String(message ?? "")
        root.disconnectLifecycleResult = payload ?? ({})
        root.disconnectLifecycleError = String(message ?? "")
        if (root.activeCommand?.disconnectAuthorization)
            root.revokeDisconnectAuthorization(
                "disconnect-lifecycle-failed")
        root.status = phase.includes("conflict")
            ? "conflict"
            : "error"
        root.error = String(message ?? "")
    }

    function beginAuthorizedDisconnectApply(): bool {
        if (!root.disconnectApplyEnabled)
            return false
        const authorizationToken = String(
            root.activeDisconnectAuthorization?.authorizationToken
                ?? "")
        if (authorizationToken.length === 0)
            return false
        if (!root.beginDisconnectLifecycle())
            return false

        root.disconnectAuthorizationDiagnostics = ({
            status: "consumed",
            ready: false,
            reason: "disconnect-apply-started",
            authorizationToken: authorizationToken
        })
        return true
    }

    function beginDisconnectLifecycle(): bool {
        if (!root.stageDisconnectLifecycleHandoff())
            return false

        reloadState.pendingDisconnectPhase = "write-issued"
        reloadState.pendingDisconnectReloadOutcome = "none"
        reloadState.pendingDisconnectVerifyState = "unknown"
        reloadState.pendingDisconnectRollbackRecovery = "none"
        reloadState.pendingDisconnectError = ""
        root.disconnectLifecycleResult = ({})
        root.disconnectLifecycleError = ""
        root.status = "disconnect-writing"

        disconnectCommitProcess.command = [
            "python3",
            Quickshell.shellPath(
                "scripts/code-workflow/disconnect_commit.py"),
            "commit",
            "--manifest",
            reloadState.pendingDisconnectManifestPath,
            "--manifest-sha256",
            reloadState.pendingDisconnectManifestSha256
        ]
        disconnectCommitProcess.running = true
        return true
    }

    function finishDisconnectCommit(exitCode: int): void {
        if (reloadState.pendingDisconnectPhase
                === "rollback-pending") {
            root._startDisconnectRollback(
                reloadState.pendingDisconnectError)
            return
        }

        const payload = root._parseProcessPayload(
            disconnectCommitStdout)
        if (payload?.status === "written"
                && root._disconnectPayloadMatchesPending(payload)
                && payload?.sourceWritten === true
                && payload?.rollbackRequired === false) {
            root.disconnectLifecycleResult = payload
            root.disconnectLifecycleError = ""
            reloadState.pendingDisconnectPhase = "waiting-reload"
            root.status = "disconnect-waiting-reload"
            if (reloadState.pendingDisconnectReloadOutcome
                    === "completed")
                Qt.callLater(root._startDisconnectCandidateVerify)
            return
        }

        const sourceWritten = payload?.sourceWritten === true
        const stderrText = String(
            disconnectCommitStderr.text ?? "").trim()
        const message = String(
            payload?.reason
            ?? payload?.detail
            ?? stderrText
            ?? ("Disconnect commit exited " + exitCode))
        if (sourceWritten) {
            root._startDisconnectRollback(message)
            return
        }

        root._setDisconnectLifecycleFailure(
            payload?.status === "conflict"
                ? "disconnect-commit-conflict"
                : "disconnect-commit-failed",
            message,
            payload)
    }

    function _startDisconnectCandidateVerify(): void {
        if (disconnectVerifyProcess.running
                || reloadState.pendingDisconnectManifestPath.length === 0)
            return
        reloadState.pendingDisconnectPhase =
            "candidate-verify-issued"
        root.status = "disconnect-verifying"
        disconnectVerifyProcess.command = [
            "python3",
            Quickshell.shellPath(
                "scripts/code-workflow/disconnect_commit.py"),
            "verify",
            "--manifest",
            reloadState.pendingDisconnectManifestPath,
            "--manifest-sha256",
            reloadState.pendingDisconnectManifestSha256
        ]
        disconnectVerifyProcess.running = true
    }

    function _startDisconnectRollbackVerify(): void {
        if (disconnectVerifyProcess.running
                || reloadState.pendingDisconnectManifestPath.length === 0)
            return
        disconnectRollbackReloadFallbackTimer.stop()
        reloadState.pendingDisconnectPhase =
            "rollback-verify-issued"
        root.status = "disconnect-rollback-verifying"
        disconnectVerifyProcess.command = [
            "python3",
            Quickshell.shellPath(
                "scripts/code-workflow/disconnect_commit.py"),
            "verify",
            "--manifest",
            reloadState.pendingDisconnectManifestPath,
            "--manifest-sha256",
            reloadState.pendingDisconnectManifestSha256
        ]
        disconnectVerifyProcess.running = true
    }

    function finishDisconnectVerify(exitCode: int): void {
        const phase = reloadState.pendingDisconnectPhase
        const payload = root._parseProcessPayload(
            disconnectVerifyStdout)
        if (payload?.status !== "verified"
                || !root._disconnectPayloadMatchesPending(payload)) {
            const stderrText = String(
                disconnectVerifyStderr.text ?? "").trim()
            const message = String(
                payload?.reason
                ?? payload?.detail
                ?? stderrText
                ?? ("Disconnect verify exited " + exitCode))
            if (phase === "rollback-verify-issued") {
                root._setDisconnectLifecycleFailure(
                    "disconnect-rollback-conflict",
                    message,
                    payload)
            } else {
                root._startDisconnectRollback(message)
            }
            return
        }

        const state = String(payload?.sourceState ?? "")
        reloadState.pendingDisconnectVerifyState = state
        if (phase === "candidate-verify-issued") {
            if (state !== "candidate-present") {
                if (state === "base-present") {
                    root._setDisconnectLifecycleFailure(
                        "disconnect-commit-failed",
                        "Disconnect source returned to base before candidate verification.",
                        payload)
                } else {
                    root._startDisconnectRollback(
                        "Disconnect candidate verification reported "
                            + state + ".")
                }
                return
            }
            root._beginDisconnectPostconditionCheck()
            return
        }

        if (phase === "rollback-verify-issued") {
            if (state !== "base-present") {
                root._setDisconnectLifecycleFailure(
                    "disconnect-rollback-conflict",
                    "Expected Disconnect rollback base after recovery reload; "
                        + "verify reported " + state,
                    payload)
                return
            }
            root._finalizeDisconnectRollback(payload)
        }
    }

    function _beginDisconnectPostconditionCheck(): void {
        reloadState.pendingDisconnectPhase =
            "postcondition-checking"
        root.status = "disconnect-postcondition"
        CodeWorkflowAnalyzer.request(
            reloadState.pendingDisconnectSourcePath,
            "",
            reloadState.pendingDisconnectSemanticAnchor,
            true)
    }

    function _finishDisconnectPostconditionIfReady(): void {
        if (reloadState.pendingDisconnectPhase
                !== "postcondition-checking")
            return
        if (CodeWorkflowAnalyzer.status === "analyzing"
                || CodeWorkflowAnalyzer.status === "idle")
            return

        const matches = CodeWorkflowAnalyzer.status === "ready"
            && CodeWorkflowAnalyzer.sourcePath
                === reloadState.pendingDisconnectSourcePath
            && CodeWorkflowAnalyzer.semanticAnchor
                === reloadState.pendingDisconnectSemanticAnchor
            && String(CodeWorkflowAnalyzer.result?.sourceSha256 ?? "")
                === reloadState.pendingDisconnectCandidateSha256
            && CodeWorkflowAnalyzer.semanticRebind?.status === "missing"
            && String(
                CodeWorkflowAnalyzer.semanticRebind?.anchor ?? "")
                === reloadState.pendingDisconnectSemanticAnchor
            && CodeWorkflowAnalyzer.diagnostics.length === 0
        if (!matches) {
            root._startDisconnectRollback(
                "Committed Disconnect candidate reloaded, but old "
                    + "semantic anchor did not remain absent.")
            return
        }
        root._finalizeDisconnectSuccess()
    }

    function _markHistoryDisconnectLifecycleResult(
        applied: bool,
        reason: string
    ): void {
        const index = Number(
            reloadState.pendingDisconnectHistoryIndex ?? -1)
        if (index < 0 || index >= root.history.length)
            return
        const next = root.history.slice()
        next[index] = Object.assign({}, next[index], {
            disconnectApplied: applied,
            disconnectAppliedSha256: applied
                ? reloadState.pendingDisconnectCandidateSha256
                : "",
            disconnectRolledBack: !applied,
            stale: true,
            staleReason: reason,
            disconnectPreparation:
                next[index]?.disconnectPreparation
                ? Object.assign(
                    {},
                    next[index].disconnectPreparation,
                    {
                        status: "stale",
                        stale: true,
                        staleReason: reason
                    })
                : next[index]?.disconnectPreparation,
            disconnectAuthorization:
                next[index]?.disconnectAuthorization
                ? Object.assign(
                    {},
                    next[index].disconnectAuthorization,
                    {
                        status: "expired",
                        authorized: false,
                        reason: reason
                    })
                : next[index]?.disconnectAuthorization
        })
        root.history = next
        root.historyIndex = index
    }

    function _finalizeDisconnectSuccess(): void {
        const payload = {
            status: "disconnect-applied",
            sourcePath: reloadState.pendingDisconnectSourcePath,
            sourceSha256:
                reloadState.pendingDisconnectCandidateSha256,
            semanticAnchor:
                reloadState.pendingDisconnectSemanticAnchor,
            postcondition: "semantic-anchor-missing"
        }
        root._markHistoryDisconnectLifecycleResult(
            true,
            "Disconnect candidate applied and old anchor is absent; "
                + "regenerate before editing again.")
        root.clearDisconnectLifecycleHandoff()
        root.disconnectLifecycleResult = payload
        root.disconnectLifecycleError = ""
        root.status = "disconnect-applied"
        root.error = ""
    }

    function _startDisconnectRollback(reason: string): void {
        if (disconnectRollbackProcess.running)
            return
        if (reloadState.pendingDisconnectManifestPath.length === 0) {
            root._setDisconnectLifecycleFailure(
                "disconnect-rollback-failed",
                "Disconnect lifecycle has no prepared manifest for rollback.",
                null)
            return
        }

        reloadState.pendingDisconnectPhase = "rollback-issued"
        reloadState.pendingDisconnectReloadOutcome = "none"
        reloadState.pendingDisconnectVerifyState = "unknown"
        if (String(reason ?? "").length > 0)
            reloadState.pendingDisconnectError = String(reason)
        root.status = "disconnect-rollback-writing"

        disconnectRollbackProcess.command = [
            "python3",
            Quickshell.shellPath(
                "scripts/code-workflow/disconnect_commit.py"),
            "rollback",
            "--manifest",
            reloadState.pendingDisconnectManifestPath,
            "--manifest-sha256",
            reloadState.pendingDisconnectManifestSha256
        ]
        disconnectRollbackProcess.running = true
    }

    function finishDisconnectRollback(exitCode: int): void {
        const payload = root._parseProcessPayload(
            disconnectRollbackStdout)
        if (payload?.status === "rolled-back"
                && root._disconnectPayloadMatchesPending(payload)) {
            root.disconnectLifecycleResult = payload
            root.disconnectLifecycleError = ""
            reloadState.pendingDisconnectPhase =
                "rollback-waiting-reload"
            reloadState.pendingDisconnectReloadOutcome = "none"
            root.status = "disconnect-rollback-waiting-reload"
            disconnectRollbackReloadFallbackTimer.restart()
            return
        }

        const stderrText = String(
            disconnectRollbackStderr.text ?? "").trim()
        root._setDisconnectLifecycleFailure(
            payload?.status === "conflict"
                ? "disconnect-rollback-conflict"
                : "disconnect-rollback-failed",
            String(
                payload?.reason
                ?? payload?.detail
                ?? stderrText
                ?? ("Disconnect rollback exited " + exitCode)),
            payload)
    }

    function _finalizeDisconnectRollback(payload): void {
        const failure = String(
            reloadState.pendingDisconnectError
            ?? "Disconnect lifecycle failed.")
        const recovery = String(
            reloadState.pendingDisconnectRollbackRecovery
            ?? "none")
        const result = {
            status: "disconnect-rolled-back",
            sourcePath: reloadState.pendingDisconnectSourcePath,
            sourceSha256:
                reloadState.pendingDisconnectBaseSha256,
            semanticAnchor:
                reloadState.pendingDisconnectSemanticAnchor,
            lifecycleError: failure,
            recoveryMode: recovery,
            verify: payload
        }
        root._markHistoryDisconnectLifecycleResult(
            false,
            "Disconnect lifecycle failed and exact rollback restored "
                + "the base; regenerate before retrying.")
        root.clearDisconnectLifecycleHandoff()
        root.disconnectLifecycleResult = result
        root.disconnectLifecycleError = failure
        root.status = "disconnect-rollback-complete"
        root.error = failure
    }

    function _recoverDisconnectLifecycle(): void {
        const phase = reloadState.pendingDisconnectPhase
        if (phase === "write-issued"
                || phase === "waiting-reload") {
            root.status = "disconnect-waiting-reload"
            if (reloadState.pendingDisconnectReloadOutcome
                    === "completed")
                root._startDisconnectCandidateVerify()
            return
        }
        if (phase === "candidate-verify-issued") {
            root._startDisconnectCandidateVerify()
            return
        }
        if (phase === "postcondition-checking") {
            root._beginDisconnectPostconditionCheck()
            return
        }
        if (phase === "rollback-pending") {
            root.status = "disconnect-rollback-pending"
            if (!disconnectCommitProcess.running)
                root._startDisconnectRollback(
                    reloadState.pendingDisconnectError)
            return
        }
        if (phase === "rollback-issued"
                || phase === "rollback-waiting-reload") {
            root.status = "disconnect-rollback-waiting-reload"
            if (reloadState.pendingDisconnectReloadOutcome
                    === "completed") {
                root._startDisconnectRollbackVerify()
            } else if (phase === "rollback-waiting-reload") {
                disconnectRollbackReloadFallbackTimer.restart()
            }
            return
        }
        if (phase === "rollback-verify-issued") {
            root._startDisconnectRollbackVerify()
            return
        }
        if ([
                "disconnect-commit-conflict",
                "disconnect-commit-failed",
                "disconnect-rollback-conflict",
                "disconnect-rollback-failed"
            ].includes(phase)) {
            root.disconnectLifecycleError =
                reloadState.pendingDisconnectError
            root.error = reloadState.pendingDisconnectError
            root.status = phase.includes("conflict")
                ? "conflict"
                : "error"
        }
    }

    function _connectLifecycleCommandMatchesHandoff(): bool {
        const command = root.activeCommand
        const prepared = command?.connectPreparation
        return !!command
            && String(command.kind ?? "") === "connect-binding"
            && root.historyIndex === reloadState.pendingConnectHistoryIndex
            && String(command.targetId ?? "")
                === reloadState.pendingConnectGraphTargetId
            && String(command.connectTargetId ?? "")
                === reloadState.pendingConnectTargetId
            && String(command.sourcePath ?? "")
                === reloadState.pendingConnectSourcePath
            && String(command.baseSha256 ?? "")
                === reloadState.pendingConnectBaseSha256
            && String(command.candidateSha256 ?? "")
                === reloadState.pendingConnectCandidateSha256
            && String(command.semanticAnchor ?? "")
                === reloadState.pendingConnectParentSemanticAnchor
            && String(prepared?.insertedSemanticAnchor ?? "")
                === reloadState.pendingConnectInsertedSemanticAnchor
            && String(prepared?.manifestPath ?? "")
                === reloadState.pendingConnectManifestPath
            && String(prepared?.manifestSha256 ?? "")
                === reloadState.pendingConnectManifestSha256
            && String(prepared?.externalSourcePath ?? "")
                === reloadState.pendingConnectExternalSourcePath
            && String(prepared?.externalSourceSha256 ?? "")
                === reloadState.pendingConnectExternalSourceSha256
            && root._connectAuthorizationIdentityMatchesCommand(command)
            && String(
                command?.connectAuthorization?.authorizationToken
                    ?? "")
                === reloadState.pendingConnectAuthorizationToken
    }

    function _connectAuthorizationIdentityMatchesCommand(command): bool {
        if (!command
                || String(command.kind ?? "") !== "connect-binding"
                || !root._connectSafetyMatchesCommand(command, false)
                || !root._connectPreparationMatchesCommand(command))
            return false

        const authorization = command.connectAuthorization
        const safety = command.connectSafety
        const prepared = command.connectPreparation
        const preview = command.result ?? ({})
        if (!authorization
                || Number(authorization.version ?? 0) !== 1)
            return false

        return String(authorization.status ?? "") === "authorized"
            && authorization.authorized === true
            && String(authorization.authorizationProof ?? "")
                === "explicit-connect-write-authorization-v1"
            && String(authorization.authorizationToken ?? "")
                === "connect-authorized:"
                    + String(prepared.transactionId ?? "")
                    + ":" + String(command.candidateSha256 ?? "")
            && String(authorization.targetId ?? "")
                === String(command.targetId ?? "")
            && String(authorization.connectTargetId ?? "")
                === String(command.connectTargetId ?? "")
            && String(authorization.sourcePath ?? "")
                === String(command.sourcePath ?? "")
            && String(authorization.baseSha256 ?? "")
                === String(command.baseSha256 ?? "")
            && String(authorization.candidateSha256 ?? "")
                === String(command.candidateSha256 ?? "")
            && String(authorization.parentSemanticAnchor ?? "")
                === String(command.semanticAnchor ?? "")
            && String(authorization.insertedSemanticAnchor ?? "")
                === String(prepared.insertedSemanticAnchor ?? "")
            && String(authorization.targetProperty ?? "")
                === String(preview.bindingName ?? "")
            && String(authorization.sourceExpression ?? "")
                === String(command.replacement ?? "")
            && String(authorization.manifestPath ?? "")
                === String(prepared.manifestPath ?? "")
            && String(authorization.manifestSha256 ?? "")
                === String(prepared.manifestSha256 ?? "")
            && root._sha256LooksValid(authorization.manifestSha256)
            && String(authorization.transactionId ?? "")
                === String(prepared.transactionId ?? "")
            && String(authorization.externalSourcePath ?? "")
                === String(prepared.externalSourcePath ?? "")
            && String(authorization.externalSourceSha256 ?? "")
                === String(prepared.externalSourceSha256 ?? "")
            && String(authorization.qualificationProof ?? "")
                === String(safety.qualificationProof ?? "")
            && String(authorization.typeCompatibilityProof ?? "")
                === String(safety.typeCompatibilityProof ?? "")
            && String(authorization.cycleSafetyProof ?? "")
                === String(safety.cycleSafetyProof ?? "")
            && String(authorization.proofFreshness ?? "") === "fresh"
            && String(authorization.typeCompatibility ?? "")
                === "unknown-unresolved"
            && String(authorization.cycleStatus ?? "")
                === "unknown-incomplete-projection"
            && String(authorization.rollbackGuarantee ?? "")
                === "exact-snapshot-auto-rollback-v1"
    }

    function _connectAuthorizationMatchesCommand(command): bool {
        return !!command
            && command.stale !== true
            && root._connectSafetyMatchesCommand(command, true)
            && root._connectPreparationMatchesCommand(command)
            && root._connectAuthorizationIdentityMatchesCommand(command)
    }

    function _expireConnectAuthorization(
        command,
        reason: string
    ): var {
        const authorization = command?.connectAuthorization
        if (!authorization
                || authorization.authorized !== true
                || String(authorization.status ?? "")
                    !== "authorized")
            return command
        return Object.assign({}, command, {
            connectAuthorization: Object.assign({}, authorization, {
                status: "expired",
                authorized: false,
                reason: String(reason ?? "authorization-expired")
            })
        })
    }

    function _expireAllConnectAuthorizations(
        reason: string
    ): void {
        let changed = false
        const next = root.history.map(command => {
            const expired = root._expireConnectAuthorization(
                command, reason)
            if (expired !== command)
                changed = true
            return expired
        })
        if (changed)
            root.history = next
        root.connectAuthorizationDiagnostics = ({
            status: "expired",
            ready: false,
            reason: String(reason ?? "authorization-expired")
        })
    }

    function authorizeConnectWrite(): bool {
        if (!root.connectAuthorizeEnabled)
            return false

        const command = root.activeCommand
        const safety = root.activeConnectSafety
        const prepared = root.activeConnectPreparation
        const preview = command?.result ?? ({})
        if (!command || !safety || !prepared)
            return false

        const authorization = {
            version: 1,
            status: "authorized",
            authorized: true,
            reason: "explicit-user-authorization",
            authorizationProof:
                "explicit-connect-write-authorization-v1",
            authorizationToken:
                "connect-authorized:"
                    + String(prepared.transactionId ?? "")
                    + ":" + String(command.candidateSha256 ?? ""),
            targetId: String(command.targetId ?? ""),
            connectTargetId: String(command.connectTargetId ?? ""),
            sourcePath: String(command.sourcePath ?? ""),
            baseSha256: String(command.baseSha256 ?? ""),
            candidateSha256: String(command.candidateSha256 ?? ""),
            parentSemanticAnchor: String(
                command.semanticAnchor ?? ""),
            insertedSemanticAnchor: String(
                prepared.insertedSemanticAnchor ?? ""),
            targetProperty: String(preview.bindingName ?? ""),
            sourceExpression: String(command.replacement ?? ""),
            manifestPath: String(prepared.manifestPath ?? ""),
            manifestSha256: String(prepared.manifestSha256 ?? ""),
            transactionId: String(prepared.transactionId ?? ""),
            externalSourcePath: String(
                prepared.externalSourcePath ?? ""),
            externalSourceSha256: String(
                prepared.externalSourceSha256 ?? ""),
            qualificationProof: String(
                safety.qualificationProof ?? ""),
            typeCompatibilityProof: String(
                safety.typeCompatibilityProof ?? ""),
            cycleSafetyProof: String(
                safety.cycleSafetyProof ?? ""),
            proofFreshness: "fresh",
            typeCompatibility: "unknown-unresolved",
            cycleStatus: "unknown-incomplete-projection",
            rollbackGuarantee:
                "exact-snapshot-auto-rollback-v1"
        }

        const promoted = Object.assign({}, command, {
            connectAuthorization: authorization
        })
        if (!root._connectAuthorizationMatchesCommand(promoted))
            return false

        const index = root.historyIndex
        if (index < 0 || index >= root.history.length)
            return false
        const next = root.history.slice()
        next[index] = promoted
        root.history = next
        root.connectAuthorizationDiagnostics = ({
            status: "authorized",
            ready: true,
            reason: "explicit-user-authorization",
            authorizationToken:
                authorization.authorizationToken
        })
        return true
    }

    function revokeConnectAuthorization(
        reason: string
    ): bool {
        if (root.connectLifecycleBusy)
            return false
        const command = root.activeCommand
        if (!command?.connectAuthorization)
            return false
        const index = root.historyIndex
        if (index < 0 || index >= root.history.length)
            return false

        const next = root.history.slice()
        next[index] = root._expireConnectAuthorization(
            command,
            String(reason ?? "user-revoked"))
        root.history = next
        root.connectAuthorizationDiagnostics = ({
            status: "expired",
            ready: false,
            reason: String(reason ?? "user-revoked")
        })
        return true
    }

    function stageConnectLifecycleHandoff(): bool {
        const command = root.activeCommand
        const prepared = root.activeConnectPreparation
        if (!root.connectAuthorizationReady
                || !root.connectArtifactsReady
                || !command
                || !prepared
                || command.stale === true
                || String(command.kind ?? "") !== "connect-binding"
                || !Quickshell.watchFiles
                || root.applyLifecycleBusy
                || root.connectLifecycleBusy)
            return false

        reloadState.pendingConnectPhase = "prepared"
        reloadState.pendingConnectGraphTargetId = String(
            command.targetId ?? "")
        reloadState.pendingConnectTargetId = String(
            command.connectTargetId ?? "")
        reloadState.pendingConnectSourcePath = String(
            command.sourcePath ?? "")
        reloadState.pendingConnectBaseSha256 = String(
            command.baseSha256 ?? "")
        reloadState.pendingConnectCandidateSha256 = String(
            command.candidateSha256 ?? "")
        reloadState.pendingConnectParentSemanticAnchor = String(
            command.semanticAnchor ?? "")
        reloadState.pendingConnectInsertedSemanticAnchor = String(
            prepared.insertedSemanticAnchor ?? "")
        reloadState.pendingConnectHistoryIndex = root.historyIndex
        reloadState.pendingConnectManifestPath = String(
            prepared.manifestPath ?? "")
        reloadState.pendingConnectManifestSha256 = String(
            prepared.manifestSha256 ?? "")
        reloadState.pendingConnectExternalSourcePath = String(
            prepared.externalSourcePath ?? "")
        reloadState.pendingConnectExternalSourceSha256 = String(
            prepared.externalSourceSha256 ?? "")
        reloadState.pendingConnectAuthorizationToken = String(
            command.connectAuthorization?.authorizationToken ?? "")
        reloadState.pendingConnectReloadOutcome = "none"
        reloadState.pendingConnectVerifyState = "unknown"
        reloadState.pendingConnectRollbackRecovery = "none"
        reloadState.pendingConnectError = ""
        return root._connectLifecycleCommandMatchesHandoff()
    }

    function clearConnectLifecycleHandoff(): void {
        connectRollbackReloadFallbackTimer.stop()
        reloadState.pendingConnectPhase = "idle"
        reloadState.pendingConnectGraphTargetId = ""
        reloadState.pendingConnectTargetId = ""
        reloadState.pendingConnectSourcePath = ""
        reloadState.pendingConnectBaseSha256 = ""
        reloadState.pendingConnectCandidateSha256 = ""
        reloadState.pendingConnectParentSemanticAnchor = ""
        reloadState.pendingConnectInsertedSemanticAnchor = ""
        reloadState.pendingConnectHistoryIndex = -1
        reloadState.pendingConnectManifestPath = ""
        reloadState.pendingConnectManifestSha256 = ""
        reloadState.pendingConnectExternalSourcePath = ""
        reloadState.pendingConnectExternalSourceSha256 = ""
        reloadState.pendingConnectAuthorizationToken = ""
        reloadState.pendingConnectReloadOutcome = "none"
        reloadState.pendingConnectVerifyState = "unknown"
        reloadState.pendingConnectRollbackRecovery = "none"
        reloadState.pendingConnectError = ""
    }

    function _connectPayloadMatchesPending(payload): bool {
        return String(payload?.sourcePath ?? "")
                === reloadState.pendingConnectSourcePath
            && String(payload?.baseSha256 ?? "")
                === reloadState.pendingConnectBaseSha256
            && String(payload?.candidateSha256 ?? "")
                === reloadState.pendingConnectCandidateSha256
            && String(payload?.parentSemanticAnchor ?? "")
                === reloadState.pendingConnectParentSemanticAnchor
            && String(payload?.insertedSemanticAnchor ?? "")
                === reloadState.pendingConnectInsertedSemanticAnchor
            && String(payload?.manifestPath ?? "")
                === reloadState.pendingConnectManifestPath
            && String(payload?.manifestSha256 ?? "")
                === reloadState.pendingConnectManifestSha256
            && String(payload?.externalSourcePath ?? "")
                === reloadState.pendingConnectExternalSourcePath
            && String(payload?.externalSourceSha256 ?? "")
                === reloadState.pendingConnectExternalSourceSha256
    }

    function _setConnectLifecycleFailure(
        phase: string,
        message: string,
        payload
    ): void {
        reloadState.pendingConnectPhase = phase
        reloadState.pendingConnectError = String(message ?? "")
        root.connectLifecycleResult = payload ?? ({})
        root.connectLifecycleError = String(message ?? "")
        if (root.activeCommand?.connectAuthorization)
            root.revokeConnectAuthorization(
                "connect-lifecycle-failed")
        root.status = phase.includes("conflict")
            ? "conflict"
            : "error"
        root.error = String(message ?? "")
    }

    function beginAuthorizedConnectApply(): bool {
        if (!root.connectApplyEnabled)
            return false

        const authorizationToken = String(
            root.activeConnectAuthorization?.authorizationToken ?? "")
        if (authorizationToken.length === 0)
            return false
        if (!root.beginConnectLifecycle())
            return false

        root.connectAuthorizationDiagnostics = ({
            status: "consumed",
            ready: false,
            reason: "connect-apply-started",
            authorizationToken: authorizationToken
        })
        return true
    }

    function beginConnectLifecycle(): bool {
        if (!root.stageConnectLifecycleHandoff())
            return false

        reloadState.pendingConnectPhase = "write-issued"
        reloadState.pendingConnectReloadOutcome = "none"
        reloadState.pendingConnectVerifyState = "unknown"
        reloadState.pendingConnectRollbackRecovery = "none"
        reloadState.pendingConnectError = ""
        root.connectLifecycleResult = ({})
        root.connectLifecycleError = ""
        root.status = "connect-writing"

        connectCommitProcess.command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/connect_commit.py"),
            "commit",
            "--manifest",
            reloadState.pendingConnectManifestPath,
            "--manifest-sha256",
            reloadState.pendingConnectManifestSha256
        ]
        connectCommitProcess.running = true
        return true
    }

    function finishConnectCommit(exitCode: int): void {
        if (reloadState.pendingConnectPhase === "rollback-pending") {
            root._startConnectRollback(
                reloadState.pendingConnectError)
            return
        }

        const payload = root._parseProcessPayload(
            connectCommitStdout)
        if (payload?.status === "written"
                && root._connectPayloadMatchesPending(payload)
                && payload?.sourceWritten === true
                && payload?.rollbackRequired === false
                && String(payload?.dependencyState ?? "")
                    === "fresh") {
            root.connectLifecycleResult = payload
            root.connectLifecycleError = ""
            reloadState.pendingConnectPhase = "waiting-reload"
            root.status = "connect-waiting-reload"
            if (reloadState.pendingConnectReloadOutcome
                    === "completed")
                Qt.callLater(root._startConnectCandidateVerify)
            return
        }

        const sourceWritten = payload?.sourceWritten === true
        const stderrText = String(
            connectCommitStderr.text ?? "").trim()
        const message = String(
            payload?.reason
            ?? payload?.detail
            ?? stderrText
            ?? ("Connect commit exited " + exitCode))

        if (sourceWritten) {
            root._startConnectRollback(message)
            return
        }

        root._setConnectLifecycleFailure(
            payload?.status === "conflict"
                ? "connect-commit-conflict"
                : "connect-commit-failed",
            message,
            payload)
    }

    function _startConnectCandidateVerify(): void {
        if (connectVerifyProcess.running
                || reloadState.pendingConnectManifestPath.length === 0)
            return
        reloadState.pendingConnectPhase = "candidate-verify-issued"
        root.status = "connect-verifying"
        connectVerifyProcess.command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/connect_commit.py"),
            "verify",
            "--manifest",
            reloadState.pendingConnectManifestPath,
            "--manifest-sha256",
            reloadState.pendingConnectManifestSha256
        ]
        connectVerifyProcess.running = true
    }

    function _startConnectRollbackVerify(): void {
        if (connectVerifyProcess.running
                || reloadState.pendingConnectManifestPath.length === 0)
            return
        connectRollbackReloadFallbackTimer.stop()
        reloadState.pendingConnectPhase = "rollback-verify-issued"
        root.status = "connect-rollback-verifying"
        connectVerifyProcess.command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/connect_commit.py"),
            "verify",
            "--manifest",
            reloadState.pendingConnectManifestPath,
            "--manifest-sha256",
            reloadState.pendingConnectManifestSha256
        ]
        connectVerifyProcess.running = true
    }

    function finishConnectVerify(exitCode: int): void {
        const phase = reloadState.pendingConnectPhase
        const payload = root._parseProcessPayload(
            connectVerifyStdout)

        if (payload?.status !== "verified"
                || !root._connectPayloadMatchesPending(payload)) {
            const stderrText = String(
                connectVerifyStderr.text ?? "").trim()
            const message = String(
                payload?.reason
                ?? payload?.detail
                ?? stderrText
                ?? ("Connect verify exited " + exitCode))
            if (phase === "rollback-verify-issued") {
                root._setConnectLifecycleFailure(
                    "connect-rollback-conflict",
                    message,
                    payload)
            } else {
                root._startConnectRollback(message)
            }
            return
        }

        const state = String(payload?.sourceState ?? "")
        reloadState.pendingConnectVerifyState = state

        if (phase === "candidate-verify-issued") {
            if (state !== "candidate-present") {
                if (state === "base-present") {
                    root._setConnectLifecycleFailure(
                        "connect-commit-failed",
                        "Connect source returned to base before candidate verification.",
                        payload)
                } else {
                    root._startConnectRollback(
                        "Connect candidate verification reported "
                            + state + ".")
                }
                return
            }
            if (String(payload?.dependencyState ?? "")
                    !== "fresh") {
                root._startConnectRollback(
                    "Retained Config dependency changed after Connect commit.")
                return
            }
            root._beginConnectSemanticRebind()
            return
        }

        if (phase === "rollback-verify-issued") {
            if (state !== "base-present") {
                root._setConnectLifecycleFailure(
                    "connect-rollback-conflict",
                    "Expected Connect rollback base after recovery reload; "
                        + "verify reported " + state,
                    payload)
                return
            }
            root._finalizeConnectRollback(payload)
        }
    }

    function _beginConnectSemanticRebind(): void {
        reloadState.pendingConnectPhase = "rebinding"
        root.status = "connect-rebinding"
        CodeWorkflowAnalyzer.request(
            reloadState.pendingConnectSourcePath,
            "",
            reloadState.pendingConnectInsertedSemanticAnchor,
            true)
    }

    function _finishConnectSemanticRebindIfReady(): void {
        if (reloadState.pendingConnectPhase !== "rebinding")
            return
        if (CodeWorkflowAnalyzer.status === "analyzing"
                || CodeWorkflowAnalyzer.status === "idle")
            return

        const matches = CodeWorkflowAnalyzer.status === "ready"
            && CodeWorkflowAnalyzer.sourcePath
                === reloadState.pendingConnectSourcePath
            && CodeWorkflowAnalyzer.semanticAnchor
                === reloadState.pendingConnectInsertedSemanticAnchor
            && String(CodeWorkflowAnalyzer.result?.sourceSha256 ?? "")
                === reloadState.pendingConnectCandidateSha256
            && CodeWorkflowAnalyzer.semanticRebind?.status === "resolved"
            && String(
                CodeWorkflowAnalyzer.semanticRebind?.anchor ?? "")
                === reloadState.pendingConnectInsertedSemanticAnchor
            && CodeWorkflowAnalyzer.diagnostics.length === 0

        if (!matches) {
            root._startConnectRollback(
                "Committed Connect candidate reloaded, but inserted "
                    + "semantic anchor rebind did not resolve.")
            return
        }

        root._finalizeConnectSuccess()
    }

    function _markHistoryConnectLifecycleResult(
        applied: bool,
        reason: string
    ): void {
        const index = Number(
            reloadState.pendingConnectHistoryIndex ?? -1)
        if (index < 0 || index >= root.history.length)
            return
        const next = root.history.slice()
        next[index] = Object.assign({}, next[index], {
            connectApplied: applied,
            connectAppliedSha256: applied
                ? reloadState.pendingConnectCandidateSha256
                : "",
            connectRolledBack: !applied,
            stale: true,
            staleReason: reason,
            connectSafety: next[index]?.connectSafety
                ? Object.assign({}, next[index].connectSafety, {
                    freshness: "stale",
                    stale: true,
                    staleReason: reason
                })
                : next[index]?.connectSafety,
            connectPreparation: next[index]?.connectPreparation
                ? Object.assign({}, next[index].connectPreparation, {
                    status: "stale",
                    stale: true,
                    staleReason: reason
                })
                : next[index]?.connectPreparation,
            connectAuthorization: next[index]?.connectAuthorization
                ? Object.assign({}, next[index].connectAuthorization, {
                    status: "expired",
                    authorized: false,
                    reason: reason
                })
                : next[index]?.connectAuthorization
        })
        root.history = next
        root.historyIndex = index
    }

    function _finalizeConnectSuccess(): void {
        const payload = {
            status: "connect-applied",
            sourcePath: reloadState.pendingConnectSourcePath,
            sourceSha256:
                reloadState.pendingConnectCandidateSha256,
            parentSemanticAnchor:
                reloadState.pendingConnectParentSemanticAnchor,
            insertedSemanticAnchor:
                reloadState.pendingConnectInsertedSemanticAnchor
        }
        root._markHistoryConnectLifecycleResult(
            true,
            "Connect candidate applied in internal lifecycle; "
                + "regenerate before editing again.")
        root.clearConnectLifecycleHandoff()
        root.connectLifecycleResult = payload
        root.connectLifecycleError = ""
        root.status = "connect-applied"
        root.error = ""
    }

    function _startConnectRollback(reason: string): void {
        if (connectRollbackProcess.running)
            return
        if (reloadState.pendingConnectManifestPath.length === 0) {
            root._setConnectLifecycleFailure(
                "connect-rollback-failed",
                "Connect lifecycle has no prepared manifest for rollback.",
                null)
            return
        }

        reloadState.pendingConnectPhase = "rollback-issued"
        reloadState.pendingConnectReloadOutcome = "none"
        reloadState.pendingConnectVerifyState = "unknown"
        if (String(reason ?? "").length > 0)
            reloadState.pendingConnectError = String(reason)
        root.status = "connect-rollback-writing"

        connectRollbackProcess.command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/connect_commit.py"),
            "rollback",
            "--manifest",
            reloadState.pendingConnectManifestPath,
            "--manifest-sha256",
            reloadState.pendingConnectManifestSha256
        ]
        connectRollbackProcess.running = true
    }

    function finishConnectRollback(exitCode: int): void {
        const payload = root._parseProcessPayload(
            connectRollbackStdout)
        if (payload?.status === "rolled-back"
                && root._connectPayloadMatchesPending(payload)) {
            root.connectLifecycleResult = payload
            root.connectLifecycleError = ""
            reloadState.pendingConnectPhase =
                "rollback-waiting-reload"
            reloadState.pendingConnectReloadOutcome = "none"
            root.status = "connect-rollback-waiting-reload"
            connectRollbackReloadFallbackTimer.restart()
            return
        }

        const stderrText = String(
            connectRollbackStderr.text ?? "").trim()
        root._setConnectLifecycleFailure(
            payload?.status === "conflict"
                ? "connect-rollback-conflict"
                : "connect-rollback-failed",
            String(
                payload?.reason
                ?? payload?.detail
                ?? stderrText
                ?? ("Connect rollback exited " + exitCode)),
            payload)
    }

    function _finalizeConnectRollback(payload): void {
        const failure = String(
            reloadState.pendingConnectError
            ?? "Connect lifecycle failed.")
        const recovery = String(
            reloadState.pendingConnectRollbackRecovery
            ?? "none")
        const result = {
            status: "connect-rolled-back",
            sourcePath: reloadState.pendingConnectSourcePath,
            sourceSha256: reloadState.pendingConnectBaseSha256,
            parentSemanticAnchor:
                reloadState.pendingConnectParentSemanticAnchor,
            insertedSemanticAnchor:
                reloadState.pendingConnectInsertedSemanticAnchor,
            lifecycleError: failure,
            recoveryMode: recovery,
            verify: payload
        }
        root._markHistoryConnectLifecycleResult(
            false,
            "Connect lifecycle failed and exact rollback restored "
                + "the base; regenerate before retrying.")
        root.clearConnectLifecycleHandoff()
        root.connectLifecycleResult = result
        root.connectLifecycleError = failure
        root.status = "connect-rollback-complete"
        root.error = failure
    }

    function _recoverConnectLifecycle(): void {
        const phase = reloadState.pendingConnectPhase
        if (phase === "write-issued"
                || phase === "waiting-reload") {
            root.status = "connect-waiting-reload"
            if (reloadState.pendingConnectReloadOutcome
                    === "completed")
                root._startConnectCandidateVerify()
            return
        }
        if (phase === "candidate-verify-issued") {
            root._startConnectCandidateVerify()
            return
        }
        if (phase === "rebinding") {
            root._beginConnectSemanticRebind()
            return
        }
        if (phase === "rollback-pending") {
            root.status = "connect-rollback-pending"
            if (!connectCommitProcess.running)
                root._startConnectRollback(
                    reloadState.pendingConnectError)
            return
        }
        if (phase === "rollback-issued"
                || phase === "rollback-waiting-reload") {
            root.status = "connect-rollback-waiting-reload"
            if (reloadState.pendingConnectReloadOutcome
                    === "completed") {
                root._startConnectRollbackVerify()
            } else if (phase === "rollback-waiting-reload") {
                connectRollbackReloadFallbackTimer.restart()
            }
            return
        }
        if (phase === "rollback-verify-issued") {
            root._startConnectRollbackVerify()
            return
        }
        if ([
                "connect-commit-conflict",
                "connect-commit-failed",
                "connect-rollback-conflict",
                "connect-rollback-failed"
            ].includes(phase)) {
            root.connectLifecycleError =
                reloadState.pendingConnectError
            root.error = reloadState.pendingConnectError
            root.status = phase.includes("conflict")
                ? "conflict"
                : "error"
        }
    }

    function _invalidateApplyHandoff(): void {
        if (reloadState.pendingApplyPhase !== "idle")
            root.clearApplyHandoff()
        root.applyPreparation = ({})
        root.applyPreparationError = ""
    }

    function stageApplyHandoff(): bool {
        const command = root.activeCommand
        if (!root.preApplyReady || !command)
            return false
        if (String(command.kind ?? "") !== "literal-property")
            return false

        reloadState.pendingApplyPhase = "prepared"
        reloadState.pendingApplySourcePath = String(
            command.sourcePath ?? "")
        reloadState.pendingApplyBaseSha256 = String(
            command.baseSha256 ?? "")
        reloadState.pendingApplyCandidateSha256 = String(
            command.candidateSha256 ?? "")
        reloadState.pendingApplySemanticAnchor = String(
            command.semanticAnchor ?? "")
        reloadState.pendingApplyReplacement = String(
            command.replacement ?? "")
        reloadState.pendingApplyHistoryIndex = root.historyIndex
        reloadState.pendingApplySnapshotPath = ""
        reloadState.pendingApplyCandidatePath = ""
        reloadState.pendingApplyManifestPath = ""
        reloadState.pendingApplyReloadOutcome = "none"
        reloadState.pendingApplyVerifyState = "unknown"
        reloadState.pendingApplyError = ""
        return true
    }

    function clearApplyHandoff(): void {
        reloadState.pendingApplyPhase = "idle"
        reloadState.pendingApplySourcePath = ""
        reloadState.pendingApplyBaseSha256 = ""
        reloadState.pendingApplyCandidateSha256 = ""
        reloadState.pendingApplySemanticAnchor = ""
        reloadState.pendingApplyReplacement = ""
        reloadState.pendingApplyHistoryIndex = -1
        reloadState.pendingApplySnapshotPath = ""
        reloadState.pendingApplyCandidatePath = ""
        reloadState.pendingApplyManifestPath = ""
        reloadState.pendingApplyReloadOutcome = "none"
        reloadState.pendingApplyVerifyState = "unknown"
        reloadState.pendingApplyError = ""
    }

    function prepareApplyArtifacts(): bool {
        const command = root.activeCommand
        if (!root.prepareApplyEnabled || !command)
            return false
        if (!root.stageApplyHandoff())
            return false

        root.status = "preparing-apply"
        root.applyPreparation = ({})
        root.applyPreparationError = ""

        applyPrepareProcess.command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/apply.py"),
            "--path", String(command.sourcePath ?? ""),
            "--base-sha256", String(command.baseSha256 ?? ""),
            "--expected-candidate-sha256",
                String(command.candidateSha256 ?? ""),
            "--semantic-anchor", String(command.semanticAnchor ?? ""),
            "--replacement", String(command.replacement ?? ""),
            "--state-dir",
                Quickshell.statePath("code-workflow/transactions")
        ]
        applyPrepareProcess.running = true
        return true
    }

    function finishApplyPreparation(exitCode: int): void {
        const raw = String(applyPrepareStdout.text ?? "").trim()
        let payload = null
        try {
            payload = raw.length > 0 ? JSON.parse(raw) : null
        } catch (e) {
            payload = null
        }

        const matchesHandoff = payload?.protocol === 1
            && String(payload?.sourcePath ?? "")
                === reloadState.pendingApplySourcePath
            && String(payload?.baseSha256 ?? "")
                === reloadState.pendingApplyBaseSha256
            && String(payload?.candidateSha256 ?? "")
                === reloadState.pendingApplyCandidateSha256
            && String(payload?.semanticAnchor ?? "")
                === reloadState.pendingApplySemanticAnchor

        if (payload?.status === "prepared-artifacts"
                && matchesHandoff) {
            reloadState.pendingApplyPhase = "artifacts-prepared"
            reloadState.pendingApplySnapshotPath = String(
                payload.snapshotPath ?? "")
            reloadState.pendingApplyCandidatePath = String(
                payload.candidatePath ?? "")
            reloadState.pendingApplyManifestPath = String(
                payload.manifestPath ?? "")
            root.applyPreparation = payload
            root.applyPreparationError = ""
            root.status = "apply-prepared"
            root.preApplyDiagnostics = ({
                status: "not-evaluated",
                ready: false,
                blockers: ["artifacts-prepared"],
                applyEnabled: false
            })
            return
        }

        const stderrText = String(
            applyPrepareStderr.text ?? "").trim()
        root.applyPreparation = payload ?? ({})
        root.applyPreparationError = String(
            payload?.detail
            ?? payload?.reason
            ?? stderrText
            ?? ("apply preparation exited " + exitCode))
        root.clearApplyHandoff()
        root._showCommand(root.activeCommand)
    }


    function _payloadMatchesPending(payload): bool {
        return payload?.protocol === 1
            && String(payload?.sourcePath ?? "")
                === reloadState.pendingApplySourcePath
            && String(payload?.baseSha256 ?? "")
                === reloadState.pendingApplyBaseSha256
            && String(payload?.candidateSha256 ?? "")
                === reloadState.pendingApplyCandidateSha256
            && String(payload?.semanticAnchor ?? "")
                === reloadState.pendingApplySemanticAnchor
    }

    function _parseProcessPayload(collector): var {
        const raw = String(collector.text ?? "").trim()
        if (raw.length === 0)
            return null
        try {
            return JSON.parse(raw)
        } catch (e) {
            return null
        }
    }

    function _setLifecycleFailure(
        phase: string,
        message: string,
        payload
    ): void {
        reloadState.pendingApplyPhase = phase
        reloadState.pendingApplyError = message
        root.applyLifecycleResult = payload ?? ({})
        root.applyLifecycleError = message
        root.status = phase === "commit-conflict"
            || phase === "rollback-conflict"
            ? "conflict"
            : "error"
        root.error = message
    }

    function beginApplyLifecycle(): bool {
        if (!root.applyEnabled)
            return false

        // Persist write-issued before commit.py can touch tracked source. The
        // watcher-driven reload may destroy this generation before onExited.
        reloadState.pendingApplyPhase = "write-issued"
        reloadState.pendingApplyReloadOutcome = "none"
        reloadState.pendingApplyVerifyState = "unknown"
        reloadState.pendingApplyError = ""
        root.applyLifecycleResult = ({})
        root.applyLifecycleError = ""
        root.status = "apply-writing"

        commitProcess.command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/commit.py"),
            "commit",
            "--manifest",
            reloadState.pendingApplyManifestPath
        ]
        commitProcess.running = true
        return true
    }

    function finishCommit(exitCode: int): void {
        if (reloadState.pendingApplyPhase === "rollback-pending") {
            root._startRollback(reloadState.pendingApplyError)
            return
        }

        const payload = root._parseProcessPayload(commitStdout)
        if (payload?.status === "written"
                && root._payloadMatchesPending(payload)) {
            root.applyLifecycleResult = payload
            root.applyLifecycleError = ""
            reloadState.pendingApplyPhase = "waiting-reload"
            root.status = "apply-waiting-reload"
            if (reloadState.pendingApplyReloadOutcome === "completed")
                Qt.callLater(root._startCandidateVerify)
            return
        }

        const stderrText = String(commitStderr.text ?? "").trim()
        const message = String(
            payload?.detail
            ?? payload?.reason
            ?? stderrText
            ?? ("atomic commit exited " + exitCode))
        root._setLifecycleFailure(
            payload?.status === "conflict"
                ? "commit-conflict"
                : "commit-failed",
            message,
            payload)
    }

    function _startCandidateVerify(): void {
        if (verifyProcess.running
                || reloadState.pendingApplyManifestPath.length === 0)
            return

        reloadState.pendingApplyPhase = "candidate-verify-issued"
        root.status = "apply-verifying"
        verifyProcess.command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/commit.py"),
            "verify",
            "--manifest",
            reloadState.pendingApplyManifestPath
        ]
        verifyProcess.running = true
    }

    function _startRollbackVerify(): void {
        if (verifyProcess.running
                || reloadState.pendingApplyManifestPath.length === 0)
            return

        reloadState.pendingApplyPhase = "rollback-verify-issued"
        root.status = "rollback-verifying"
        verifyProcess.command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/commit.py"),
            "verify",
            "--manifest",
            reloadState.pendingApplyManifestPath
        ]
        verifyProcess.running = true
    }

    function finishVerify(exitCode: int): void {
        const phase = reloadState.pendingApplyPhase
        const payload = root._parseProcessPayload(verifyStdout)
        if (payload?.status !== "verified"
                || !root._payloadMatchesPending(payload)) {
            const stderrText = String(verifyStderr.text ?? "").trim()
            root._setLifecycleFailure(
                phase === "rollback-verify-issued"
                    ? "rollback-conflict"
                    : "verify-failed",
                String(
                    payload?.detail
                    ?? payload?.reason
                    ?? stderrText
                    ?? ("atomic verify exited " + exitCode)),
                payload)
            return
        }

        const state = String(payload.state ?? "")
        reloadState.pendingApplyVerifyState = state

        if (phase === "candidate-verify-issued") {
            if (state !== "candidate-present") {
                root._setLifecycleFailure(
                    state === "diverged"
                        ? "commit-conflict"
                        : "verify-failed",
                    "Expected committed candidate after successful reload; "
                        + "verify reported " + state,
                    payload)
                return
            }
            root._beginSemanticRebind()
            return
        }

        if (phase === "rollback-verify-issued") {
            if (state !== "base-present") {
                root._setLifecycleFailure(
                    "rollback-conflict",
                    "Expected rollback base after recovery reload; "
                        + "verify reported " + state,
                    payload)
                return
            }
            root._finalizeRollback(payload)
        }
    }

    function _beginSemanticRebind(): void {
        reloadState.pendingApplyPhase = "rebinding"
        root.status = "apply-rebinding"
        CodeWorkflowAnalyzer.request(
            reloadState.pendingApplySourcePath,
            "",
            reloadState.pendingApplySemanticAnchor,
            true)
    }

    function _finishSemanticRebindIfReady(): void {
        if (reloadState.pendingApplyPhase !== "rebinding")
            return
        if (CodeWorkflowAnalyzer.status === "analyzing"
                || CodeWorkflowAnalyzer.status === "idle")
            return

        const matches = CodeWorkflowAnalyzer.status === "ready"
            && CodeWorkflowAnalyzer.sourcePath
                === reloadState.pendingApplySourcePath
            && CodeWorkflowAnalyzer.semanticAnchor
                === reloadState.pendingApplySemanticAnchor
            && String(CodeWorkflowAnalyzer.result?.sourceSha256 ?? "")
                === reloadState.pendingApplyCandidateSha256
            && CodeWorkflowAnalyzer.semanticRebind?.status === "resolved"
            && String(
                CodeWorkflowAnalyzer.semanticRebind?.anchor ?? "")
                === reloadState.pendingApplySemanticAnchor

        if (!matches) {
            root._setLifecycleFailure(
                "rebind-failed",
                "Committed source reloaded, but semantic anchor rebind "
                    + "did not resolve to the prepared candidate.",
                CodeWorkflowAnalyzer.result)
            return
        }

        root._finalizeApplySuccess()
    }

    function _markHistoryLifecycleResult(
        applied: bool,
        reason: string
    ): void {
        const index = Number(
            reloadState.pendingApplyHistoryIndex ?? -1)
        if (index < 0 || index >= root.history.length)
            return

        const next = root.history.slice()
        next[index] = Object.assign({}, next[index], {
            applied: applied,
            appliedSha256: applied
                ? reloadState.pendingApplyCandidateSha256
                : "",
            applyRolledBack: !applied,
            stale: true,
            staleReason: reason
        })
        root.history = next
        root.historyIndex = index
    }

    function _finalizeApplySuccess(): void {
        const payload = {
            status: "applied",
            sourcePath: reloadState.pendingApplySourcePath,
            sourceSha256: reloadState.pendingApplyCandidateSha256,
            semanticAnchor: reloadState.pendingApplySemanticAnchor
        }
        root._markHistoryLifecycleResult(
            true,
            "Applied successfully; create a new preview against "
                + "the current source before editing again.")
        root.clearApplyHandoff()
        root.applyLifecycleResult = payload
        root.applyLifecycleError = ""
        root.status = "applied"
        root.error = ""
        root.preApplyDiagnostics = ({
            status: "not-evaluated",
            ready: false,
            blockers: ["source-updated"],
            applyEnabled: false
        })
    }

    function _startRollback(reason: string): void {
        if (rollbackProcess.running)
            return
        if (reloadState.pendingApplyManifestPath.length === 0) {
            root._setLifecycleFailure(
                "rollback-failed",
                "Reload failed but no prepared manifest is available "
                    + "for rollback.",
                null)
            return
        }

        reloadState.pendingApplyPhase = "rollback-issued"
        // Preserve "failed" when the candidate reload failed. In that case
        // the running shell never left the base generation, so exact source
        // rollback can be verified without waiting for a redundant watcher
        // generation that Quickshell may suppress.
        reloadState.pendingApplyVerifyState = "unknown"
        if (String(reason ?? "").length > 0)
            reloadState.pendingApplyError = String(reason)
        root.status = "rollback-writing"

        rollbackProcess.command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/commit.py"),
            "rollback",
            "--manifest",
            reloadState.pendingApplyManifestPath
        ]
        rollbackProcess.running = true
    }

    function finishRollback(exitCode: int): void {
        const payload = root._parseProcessPayload(rollbackStdout)
        if (payload?.status === "rolled-back"
                && root._payloadMatchesPending(payload)) {
            root.applyLifecycleResult = payload
            root.applyLifecycleError = ""
            reloadState.pendingApplyPhase = "rollback-waiting-reload"
            root.status = "rollback-waiting-reload"
            if (reloadState.pendingApplyReloadOutcome === "failed"
                    || reloadState.pendingApplyReloadOutcome
                        === "completed")
                Qt.callLater(root._startRollbackVerify)
            return
        }

        const stderrText = String(rollbackStderr.text ?? "").trim()
        root._setLifecycleFailure(
            payload?.status === "conflict"
                ? "rollback-conflict"
                : "rollback-failed",
            String(
                payload?.detail
                ?? payload?.reason
                ?? stderrText
                ?? ("atomic rollback exited " + exitCode)),
            payload)
    }

    function _finalizeRollback(payload): void {
        const failure = String(
            reloadState.pendingApplyError
            ?? "Candidate reload failed.")
        const result = {
            status: "rolled-back",
            sourcePath: reloadState.pendingApplySourcePath,
            sourceSha256: reloadState.pendingApplyBaseSha256,
            semanticAnchor: reloadState.pendingApplySemanticAnchor,
            reloadError: failure,
            verify: payload
        }
        root._markHistoryLifecycleResult(
            false,
            "Apply reload failed and exact rollback restored the base; "
                + "regenerate before retrying.")
        root.clearApplyHandoff()
        root.applyLifecycleResult = result
        root.applyLifecycleError = failure
        root.status = "rollback-complete"
        root.error = failure
        root.preApplyDiagnostics = ({
            status: "blocked",
            ready: false,
            blockers: ["rolled-back-after-reload-failure"],
            applyEnabled: false
        })
    }

    function _recoverApplyLifecycle(): void {
        const phase = reloadState.pendingApplyPhase

        if (phase === "write-issued"
                || phase === "waiting-reload") {
            root.status = "apply-waiting-reload"
            if (reloadState.pendingApplyReloadOutcome === "completed")
                root._startCandidateVerify()
            return
        }
        if (phase === "candidate-verify-issued") {
            root._startCandidateVerify()
            return
        }
        if (phase === "rebinding") {
            root._beginSemanticRebind()
            return
        }
        if (phase === "rollback-pending") {
            root.status = "rollback-pending"
            if (!commitProcess.running)
                root._startRollback(reloadState.pendingApplyError)
            return
        }
        if (phase === "rollback-issued"
                || phase === "rollback-waiting-reload") {
            root.status = "rollback-waiting-reload"
            if (phase === "rollback-waiting-reload"
                    && (reloadState.pendingApplyReloadOutcome === "failed"
                        || reloadState.pendingApplyReloadOutcome
                            === "completed"))
                root._startRollbackVerify()
            return
        }
        if (phase === "rollback-verify-issued") {
            root._startRollbackVerify()
            return
        }
        if ([
                "commit-conflict",
                "commit-failed",
                "verify-failed",
                "rebind-failed",
                "rollback-conflict",
                "rollback-failed"
            ].includes(phase)) {
            root.applyLifecycleError =
                reloadState.pendingApplyError
            root.error = reloadState.pendingApplyError
            root.status = phase.includes("conflict")
                ? "conflict"
                : "error"
        }
    }

    function _handleReloadCompleted(): void {
        const phase = reloadState.pendingApplyPhase
        if (phase === "write-issued"
                || phase === "waiting-reload") {
            reloadState.pendingApplyReloadOutcome = "completed"
            root._startCandidateVerify()
            return
        }
        if (phase === "rollback-issued"
                || phase === "rollback-waiting-reload") {
            reloadState.pendingApplyReloadOutcome = "completed"
            root._startRollbackVerify()
            return
        }

        const connectPhase = reloadState.pendingConnectPhase
        if (connectPhase === "write-issued"
                || connectPhase === "waiting-reload"
                || connectPhase === "candidate-verify-issued") {
            reloadState.pendingConnectReloadOutcome = "completed"
            root._startConnectCandidateVerify()
            return
        }
        if (connectPhase === "rollback-issued"
                || connectPhase === "rollback-waiting-reload"
                || connectPhase === "rollback-verify-issued") {
            if (reloadState.pendingConnectRollbackRecovery
                    === "none")
                reloadState.pendingConnectRollbackRecovery =
                    "watcher"
            reloadState.pendingConnectReloadOutcome = "completed"
            connectRollbackReloadFallbackTimer.stop()
            root._startConnectRollbackVerify()
            return
        }

        const disconnectPhase = reloadState.pendingDisconnectPhase
        if (disconnectPhase === "write-issued"
                || disconnectPhase === "waiting-reload"
                || disconnectPhase === "candidate-verify-issued") {
            reloadState.pendingDisconnectReloadOutcome = "completed"
            root._startDisconnectCandidateVerify()
            return
        }
        if (disconnectPhase === "rollback-issued"
                || disconnectPhase === "rollback-waiting-reload"
                || disconnectPhase === "rollback-verify-issued") {
            if (reloadState.pendingDisconnectRollbackRecovery
                    === "none")
                reloadState.pendingDisconnectRollbackRecovery =
                    "watcher"
            reloadState.pendingDisconnectReloadOutcome = "completed"
            disconnectRollbackReloadFallbackTimer.stop()
            root._startDisconnectRollbackVerify()
        }
    }

    function _handleReloadFailed(errorString: string): void {
        const phase = reloadState.pendingApplyPhase
        const message = String(errorString ?? "Quickshell reload failed")

        if (phase === "write-issued"
                || phase === "waiting-reload"
                || phase === "candidate-verify-issued") {
            reloadState.pendingApplyReloadOutcome = "failed"
            reloadState.pendingApplyError = message
            if (commitProcess.running) {
                reloadState.pendingApplyPhase = "rollback-pending"
                root.status = "rollback-pending"
            } else {
                root._startRollback(message)
            }
            return
        }

        if (phase === "rollback-issued"
                || phase === "rollback-waiting-reload"
                || phase === "rollback-verify-issued") {
            root._setLifecycleFailure(
                "rollback-failed",
                "Rollback source was restored but its watcher reload "
                    + "also failed: " + message,
                null)
            return
        }

        const connectPhase = reloadState.pendingConnectPhase
        if (connectPhase === "write-issued"
                || connectPhase === "waiting-reload"
                || connectPhase === "candidate-verify-issued"
                || connectPhase === "rebinding") {
            reloadState.pendingConnectReloadOutcome = "failed"
            reloadState.pendingConnectError = message
            if (connectCommitProcess.running) {
                reloadState.pendingConnectPhase =
                    "rollback-pending"
                root.status = "connect-rollback-pending"
            } else {
                root._startConnectRollback(message)
            }
            return
        }

        if (connectPhase === "rollback-issued"
                || connectPhase === "rollback-waiting-reload"
                || connectPhase === "rollback-verify-issued") {
            root._setConnectLifecycleFailure(
                "connect-rollback-failed",
                "Connect rollback source was restored but reload "
                    + "also failed: " + message,
                null)
            return
        }

        const disconnectPhase = reloadState.pendingDisconnectPhase
        if (disconnectPhase === "write-issued"
                || disconnectPhase === "waiting-reload"
                || disconnectPhase === "candidate-verify-issued"
                || disconnectPhase === "postcondition-checking") {
            reloadState.pendingDisconnectReloadOutcome = "failed"
            reloadState.pendingDisconnectError = message
            if (disconnectCommitProcess.running) {
                reloadState.pendingDisconnectPhase =
                    "rollback-pending"
                root.status = "disconnect-rollback-pending"
            } else {
                root._startDisconnectRollback(message)
            }
            return
        }
        if (disconnectPhase === "rollback-issued"
                || disconnectPhase === "rollback-waiting-reload"
                || disconnectPhase === "rollback-verify-issued") {
            root._setDisconnectLifecycleFailure(
                "disconnect-rollback-failed",
                "Disconnect rollback source was restored but reload "
                    + "also failed: " + message,
                null)
        }
    }

    function _clearPresentation(): void {
        root.status = "clean"
        root.sourcePath = ""
        root.baseSha256 = ""
        root.semanticAnchor = ""
        root.replacement = ""
        root.result = ({})
        root.patch = ({})
        root.previewText = ""
        root.error = ""
        root.preApplyDiagnostics = ({
            status: "not-evaluated",
            ready: false,
            blockers: ["no-active-preview"]
        })
        root.connectSafetyDiagnostics = ({
            status: "not-evaluated",
            ready: false,
            reason: "no-active-connect-safety",
            writeAuthorized: false
        })
        root.connectPreparationCapability = ({
            status: "not-evaluated",
            ready: false,
            reason: "no-active-connect-preview",
            writeAuthorized: false,
            applyEnabled: false,
            artifactsStaged: false
        })
        root.connectPreparationError = ""
        root.connectLifecycleResult = ({})
        root.connectLifecycleError = ""
        root.connectAuthorizationDiagnostics = ({
            status: "not-authorized",
            ready: false,
            reason: "no-active-authorization"
        })
        root.disconnectPreparationError = ""
        root.disconnectLifecycleResult = ({})
        root.disconnectLifecycleError = ""
        root.disconnectAuthorizationDiagnostics = ({
            status: "not-authorized",
            ready: false,
            reason: "no-active-authorization"
        })
    }

    function _sha256LooksValid(value): bool {
        const rendered = String(value ?? "")
        if (rendered.length !== 64)
            return false
        const alphabet = "0123456789abcdef"
        for (let i = 0; i < rendered.length; ++i) {
            if (!alphabet.includes(rendered[i].toLowerCase()))
                return false
        }
        return true
    }

    function _runtimeRelativeQmlPathLooksValid(value): bool {
        const rendered = String(value ?? "")
        if (rendered.length === 0
                || rendered.startsWith("/")
                || !rendered.endsWith(".qml"))
            return false
        const parts = rendered.split("/")
        if (parts.length === 0)
            return false
        for (const part of parts) {
            if (part.length === 0 || part === "." || part === "..")
                return false
        }
        return true
    }

    function _connectSafetyMatchesCommand(
        command,
        requireFresh: bool
    ): bool {
        if (!command || String(command.kind ?? "") !== "connect-binding")
            return false

        const safety = command.connectSafety
        if (!safety || Number(safety.version ?? 0) !== 1)
            return false

        const preview = command.result ?? ({})
        if (
            String(safety.status ?? "") !== "qualified"
            || String(safety.qualificationProof ?? "")
                !== "qualified-reviewed-connect-research-v1"
            || String(safety.typeCompatibilityProof ?? "")
                !== "compatible-qmllint-proof"
            || String(safety.cycleSafetyProof ?? "")
                !== "acyclic-source-backed-cross-file-closure"
            || String(safety.targetId ?? "")
                !== String(command.targetId ?? "")
            || String(safety.connectTargetId ?? "")
                !== String(command.connectTargetId ?? "")
            || String(safety.sourcePath ?? "")
                !== String(command.sourcePath ?? "")
            || String(safety.baseSha256 ?? "")
                !== String(command.baseSha256 ?? "")
            || String(safety.candidateSha256 ?? "")
                !== String(command.candidateSha256 ?? "")
            || String(safety.parentSemanticAnchor ?? "")
                !== String(command.semanticAnchor ?? "")
            || String(safety.targetProperty ?? "")
                !== String(preview.bindingName ?? "")
            || String(safety.sourceExpression ?? "")
                !== String(command.replacement ?? "")
            || String(safety.typeCompatibility ?? "")
                !== "unknown-unresolved"
            || String(safety.cycleStatus ?? "")
                !== "unknown-incomplete-projection"
            || safety.proofsComposed !== true
            || safety.sourceReverified !== true
            || safety.externalSourceReverified !== true
            || safety.writeAuthorized !== false
            || safety.applyEnabled !== false
            || safety.artifactsStaged !== false
            || safety.productionIntegrated !== false
            || !root._sha256LooksValid(safety.baseSha256)
            || !root._sha256LooksValid(safety.candidateSha256)
            || !root._sha256LooksValid(safety.externalSourceSha256)
            || !root._runtimeRelativeQmlPathLooksValid(safety.sourcePath)
            || !root._runtimeRelativeQmlPathLooksValid(
                safety.externalSourcePath)
            || String(safety.sourcePropertySemanticAnchor ?? "").length === 0
            || String(safety.terminalPropertySemanticAnchor ?? "").length === 0
            || !Array.isArray(safety.dependencyPath)
            || safety.dependencyPath.length === 0
        )
            return false

        for (const item of safety.dependencyPath) {
            if (String(item ?? "").length === 0)
                return false
        }

        if (requireFresh
                && (String(safety.freshness ?? "") !== "fresh"
                    || safety.stale === true))
            return false

        return true
    }

    function _connectPreparationMatchesCommand(command): bool {
        if (!command || String(command.kind ?? "") !== "connect-binding")
            return false

        const prepared = command.connectPreparation
        if (!prepared || Number(prepared.version ?? 0) !== 1)
            return false

        const preview = command.result ?? ({})
        return String(prepared.status ?? "") === "prepared"
            && prepared.stale !== true
            && String(prepared.artifactProof ?? "")
                === "prepared-qualified-connect-artifacts-v1"
            && String(prepared.targetId ?? "")
                === String(command.targetId ?? "")
            && String(prepared.connectTargetId ?? "")
                === String(command.connectTargetId ?? "")
            && String(prepared.sourcePath ?? "")
                === String(command.sourcePath ?? "")
            && String(prepared.baseSha256 ?? "")
                === String(command.baseSha256 ?? "")
            && String(prepared.candidateSha256 ?? "")
                === String(command.candidateSha256 ?? "")
            && String(prepared.parentSemanticAnchor ?? "")
                === String(command.semanticAnchor ?? "")
            && String(prepared.bindingName ?? "")
                === String(preview.bindingName ?? "")
            && String(prepared.expression ?? "")
                === String(command.replacement ?? "")
            && String(prepared.insertedSemanticAnchor ?? "").length > 0
            && String(prepared.transactionId ?? "").length > 0
            && String(prepared.externalSourcePath ?? "").length > 0
            && root._sha256LooksValid(prepared.externalSourceSha256)
            && String(prepared.snapshotPath ?? "").length > 0
            && String(prepared.candidatePath ?? "").length > 0
            && String(prepared.manifestPath ?? "").length > 0
            && root._sha256LooksValid(prepared.manifestSha256)
            && prepared.writeAuthorized === false
            && prepared.applyEnabled === false
            && prepared.artifactsStaged === true
            && prepared.productionIntegrated === false
    }

    function _sanitizeConnectPreparation(payload): var {
        return {
            version: 1,
            status: "prepared",
            stale: false,
            staleReason: "",
            artifactProof: String(payload?.artifactProof ?? ""),
            targetId: String(payload?.targetId ?? ""),
            connectTargetId: String(payload?.connectTargetId ?? ""),
            transactionId: String(payload?.transactionId ?? ""),
            sourcePath: String(payload?.sourcePath ?? ""),
            baseSha256: String(payload?.baseSha256 ?? ""),
            candidateSha256: String(payload?.candidateSha256 ?? ""),
            parentSemanticAnchor: String(
                payload?.parentSemanticAnchor ?? ""),
            insertedSemanticAnchor: String(
                payload?.insertedSemanticAnchor ?? ""),
            bindingName: String(payload?.bindingName ?? ""),
            expression: String(payload?.expression ?? ""),
            externalSourcePath: String(
                payload?.externalSourcePath ?? ""),
            externalSourceSha256: String(
                payload?.externalSourceSha256 ?? ""),
            snapshotPath: String(payload?.snapshotPath ?? ""),
            candidatePath: String(payload?.candidatePath ?? ""),
            manifestPath: String(payload?.manifestPath ?? ""),
            manifestSha256: String(payload?.manifestSha256 ?? ""),
            writeAuthorized: false,
            applyEnabled: false,
            artifactsStaged: true,
            productionIntegrated: false
        }
    }

    function _qualificationPayloadFromPreparation(payload): var {
        const qualification = payload?.qualificationSnapshot
        if (!qualification)
            return null
        return Object.assign({}, qualification, {
            protocol: 1,
            status: "proof"
        })
    }

    function _sanitizeConnectQualification(payload): var {
        const dependencyPath = Array.isArray(payload?.dependencyPath)
            ? payload.dependencyPath.map(item => String(item ?? ""))
            : []

        return {
            version: 1,
            status: "qualified",
            freshness: "pending",
            stale: false,
            staleReason: "",
            qualificationProof: String(
                payload?.qualificationProof ?? ""),
            targetId: String(payload?.targetId ?? ""),
            connectTargetId: String(payload?.connectTargetId ?? ""),
            sourcePath: String(payload?.sourcePath ?? ""),
            baseSha256: String(payload?.baseSha256 ?? ""),
            candidateSha256: String(payload?.candidateSha256 ?? ""),
            parentSemanticAnchor: String(
                payload?.parentSemanticAnchor ?? ""),
            targetProperty: String(payload?.targetProperty ?? ""),
            sourceExpression: String(payload?.sourceExpression ?? ""),
            sourcePropertySemanticAnchor: String(
                payload?.sourcePropertySemanticAnchor ?? ""),
            sourceDeclaredType: String(payload?.sourceDeclaredType ?? ""),
            typeCompatibilityProof: String(
                payload?.typeCompatibilityProof ?? ""),
            cycleSafetyProof: String(payload?.cycleSafetyProof ?? ""),
            dependencyPath: dependencyPath,
            externalModuleUri: String(payload?.externalModuleUri ?? ""),
            externalSourcePath: String(
                payload?.externalSourcePath ?? ""),
            externalSourceSha256: String(
                payload?.externalSourceSha256 ?? ""),
            aliasTargetId: String(payload?.aliasTargetId ?? ""),
            terminalPropertySemanticAnchor: String(
                payload?.terminalPropertySemanticAnchor ?? ""),
            terminalDeclaredType: String(
                payload?.terminalDeclaredType ?? ""),
            terminalValueKind: String(payload?.terminalValueKind ?? ""),
            terminalValueText: String(payload?.terminalValueText ?? ""),
            fallbackLiteral: String(payload?.fallbackLiteral ?? ""),
            oracleTool: String(payload?.oracleTool ?? ""),
            oracleVersion: String(payload?.oracleVersion ?? ""),
            proofsComposed: payload?.proofsComposed === true,
            sourceReverified: payload?.sourceReverified === true,
            externalSourceReverified:
                payload?.externalSourceReverified === true,
            typeCompatibility: String(
                payload?.typeCompatibility ?? ""),
            cycleStatus: String(payload?.cycleStatus ?? ""),
            writeAuthorized: false,
            applyEnabled: false,
            artifactsStaged: false,
            productionIntegrated: false
        }
    }

    function promoteConnectQualification(payload): bool {
        if (root.previewBusy
                || root.connectSafetyBusy
                || root.connectPreparationBusy
                || root.disconnectPreparationBusy
                || root.disconnectLifecycleBusy
                || applyPrepareProcess.running
                || root.applyLifecycleBusy)
            return false

        const command = root.activeCommand
        if (!command
                || root.status !== "preview"
                || command.stale === true
                || String(command.kind ?? "") !== "connect-binding")
            return false

        const preview = command.result ?? ({})
        if (
            payload?.protocol !== 1
            || String(payload?.status ?? "") !== "proof"
            || String(payload?.qualificationProof ?? "")
                !== "qualified-reviewed-connect-research-v1"
            || String(payload?.targetId ?? "")
                !== String(command.targetId ?? "")
            || String(payload?.connectTargetId ?? "")
                !== String(command.connectTargetId ?? "")
            || String(payload?.sourcePath ?? "")
                !== String(command.sourcePath ?? "")
            || String(payload?.baseSha256 ?? "")
                !== String(command.baseSha256 ?? "")
            || String(payload?.candidateSha256 ?? "")
                !== String(command.candidateSha256 ?? "")
            || String(payload?.parentSemanticAnchor ?? "")
                !== String(command.semanticAnchor ?? "")
            || String(payload?.targetProperty ?? "")
                !== String(preview.bindingName ?? "")
            || String(payload?.sourceExpression ?? "")
                !== String(command.replacement ?? "")
            || String(payload?.typeCompatibilityProof ?? "")
                !== "compatible-qmllint-proof"
            || String(payload?.cycleSafetyProof ?? "")
                !== "acyclic-source-backed-cross-file-closure"
            || payload?.proofsComposed !== true
            || payload?.sourceReverified !== true
            || payload?.externalSourceReverified !== true
            || String(payload?.typeCompatibility ?? "")
                !== "unknown-unresolved"
            || String(payload?.cycleStatus ?? "")
                !== "unknown-incomplete-projection"
            || payload?.writeAuthorized !== false
            || payload?.applyEnabled !== false
            || payload?.artifactsStaged !== false
            || payload?.productionIntegrated !== false
        )
            return false

        const snapshot = root._sanitizeConnectQualification(payload)
        const promoted = Object.assign({}, command, {
            connectSafety: snapshot
        })
        if (!root._connectSafetyMatchesCommand(promoted, false))
            return false

        const index = root.historyIndex
        if (index < 0 || index >= root.history.length)
            return false

        const next = root.history.slice()
        next[index] = promoted
        root.history = next
        root.connectSafetyDiagnostics = ({
            status: "pending",
            ready: false,
            reason: "freshness-reverification-required",
            candidateSha256: String(command.candidateSha256 ?? ""),
            writeAuthorized: false
        })
        Qt.callLater(root.reverifyActiveConnectSafety)
        return true
    }

    function _setConnectSafetyFreshness(
        index: int,
        freshness: string,
        stale: bool,
        reason: string
    ): bool {
        if (index < 0 || index >= root.history.length)
            return false

        const command = root.history[index]
        const safety = command?.connectSafety
        if (!safety)
            return false

        const nextSafety = Object.assign({}, safety, {
            freshness: String(freshness ?? ""),
            stale: stale,
            staleReason: String(reason ?? "")
        })
        const next = root.history.slice()
        next[index] = Object.assign({}, command, {
            connectSafety: nextSafety
        })
        root.history = next

        if (index === root.historyIndex) {
            root.connectSafetyDiagnostics = ({
                status: String(freshness ?? ""),
                ready: String(freshness ?? "") === "fresh" && !stale,
                reason: String(reason ?? ""),
                sourcePath: String(nextSafety.sourcePath ?? ""),
                candidateSha256: String(
                    nextSafety.candidateSha256 ?? ""),
                externalSourcePath: String(
                    nextSafety.externalSourcePath ?? ""),
                writeAuthorized: false
            })
        }
        return true
    }

    function _markConnectSafetyStale(path: string): void {
        const changedPath = String(path ?? "")
        if (changedPath.length === 0)
            return

        let changed = false
        const next = root.history.map(command => {
            const safety = command?.connectSafety
            if (!safety || safety.stale === true)
                return command

            const matches = String(safety.sourcePath ?? "") === changedPath
                || String(safety.externalSourcePath ?? "") === changedPath
            if (!matches)
                return command

            changed = true
            const reason =
                "Qualified Connect dependency changed; reprepare before any future write gate."
            const preparation = command?.connectPreparation
            const authorization = command?.connectAuthorization
            return Object.assign({}, command, {
                connectSafety: Object.assign({}, safety, {
                    freshness: "stale",
                    stale: true,
                    staleReason: reason
                }),
                connectPreparation: preparation
                    ? Object.assign({}, preparation, {
                        status: "stale",
                        stale: true,
                        staleReason: reason
                    })
                    : preparation,
                connectAuthorization: authorization
                    ? Object.assign({}, authorization, {
                        status: "expired",
                        authorized: false,
                        reason: reason
                    })
                    : authorization
            })
        })
        if (changed)
            root.history = next

        const active = root.activeCommand?.connectSafety
        if (active?.stale === true) {
            root.connectSafetyDiagnostics = ({
                status: "stale",
                ready: false,
                reason: String(active.staleReason ?? "dependency-changed"),
                writeAuthorized: false
            })
        }
    }

    function _startConnectSafetyFreshnessCheck(command): bool {
        if (root.connectSafetyBusy
                || root.previewBusy
                || applyPrepareProcess.running
                || root.applyLifecycleBusy
                || !command
                || command.stale === true
                || !root._connectSafetyMatchesCommand(command, false))
            return false

        const index = root.historyIndex
        if (index < 0 || index >= root.history.length)
            return false

        const safety = command.connectSafety
        root._pendingConnectSafetyIndex = index
        root._pendingConnectSafetyCandidateSha = String(
            command.candidateSha256 ?? "")
        root._setConnectSafetyFreshness(
            index,
            "pending",
            false,
            "freshness-reverification-running")

        connectSafetyProcess.command = [
            "python3",
            Quickshell.shellPath(
                "scripts/code-workflow/connect_snapshot.py"),
            "--path", String(safety.sourcePath ?? ""),
            "--base-sha256", String(safety.baseSha256 ?? ""),
            "--candidate-sha256",
                String(safety.candidateSha256 ?? ""),
            "--external-path",
                String(safety.externalSourcePath ?? ""),
            "--external-sha256",
                String(safety.externalSourceSha256 ?? "")
        ]
        connectSafetyProcess.running = true
        return true
    }

    function reverifyActiveConnectSafety(): bool {
        const command = root.activeCommand
        if (!command || !command.connectSafety)
            return false
        return root._startConnectSafetyFreshnessCheck(command)
    }

    function finishConnectSafetyFreshness(exitCode: int): void {
        const raw = String(connectSafetyStdout.text ?? "").trim()
        let payload = null
        try {
            payload = raw.length > 0 ? JSON.parse(raw) : null
        } catch (e) {
            payload = null
        }

        const index = root._pendingConnectSafetyIndex
        const pendingCandidate = root._pendingConnectSafetyCandidateSha
        root._pendingConnectSafetyIndex = -1
        root._pendingConnectSafetyCandidateSha = ""

        if (index < 0 || index >= root.history.length)
            return

        const command = root.history[index]
        const safety = command?.connectSafety
        if (!safety
                || String(command?.candidateSha256 ?? "")
                    !== pendingCandidate
                || !root._connectSafetyMatchesCommand(command, false)) {
            root.connectSafetyDiagnostics = ({
                status: "blocked",
                ready: false,
                reason: "connect-safety-command-drifted",
                writeAuthorized: false
            })
            return
        }

        const identityMatches = payload?.protocol === 1
            && String(payload?.sourcePath ?? "")
                === String(safety.sourcePath ?? "")
            && String(payload?.baseSha256 ?? "")
                === String(safety.baseSha256 ?? "")
            && String(payload?.candidateSha256 ?? "")
                === String(safety.candidateSha256 ?? "")
            && String(payload?.externalSourcePath ?? "")
                === String(safety.externalSourcePath ?? "")
            && String(payload?.externalSourceSha256 ?? "")
                === String(safety.externalSourceSha256 ?? "")
            && payload?.writeAuthorized === false
            && payload?.applyEnabled === false
            && payload?.artifactsStaged === false

        if (payload?.status === "fresh"
                && identityMatches
                && payload?.sourceFresh === true
                && payload?.externalSourceFresh === true) {
            root._setConnectSafetyFreshness(
                index,
                "fresh",
                false,
                "qualified-sources-match-snapshot")
            return
        }

        const stderrText = String(connectSafetyStderr.text ?? "").trim()
        root._setConnectSafetyFreshness(
            index,
            "stale",
            true,
            String(
                payload?.reason
                ?? stderrText
                ?? ("connect safety freshness exited " + exitCode)))
    }

    function probeActiveConnectPreparationCapability(): bool {
        if (root.connectPreparationBusy
                || root.previewBusy
                || root.connectSafetyBusy
                || root.connectLifecycleBusy
                || applyPrepareProcess.running
                || root.applyLifecycleBusy)
            return false

        const command = root.activeCommand
        if (!command
                || command.stale === true
                || String(command.kind ?? "") !== "connect-binding") {
            root.connectPreparationCapability = ({
                status: "not-evaluated",
                ready: false,
                reason: "no-active-connect-preview",
                writeAuthorized: false,
                applyEnabled: false,
                artifactsStaged: false
            })
            return false
        }

        root._pendingConnectPreparationIndex = root.historyIndex
        root._pendingConnectPreparationCandidateSha = String(
            command.candidateSha256 ?? "")
        root.connectPreparationCapability = ({
            status: "checking",
            ready: false,
            reason: "capability-check-running",
            writeAuthorized: false,
            applyEnabled: false,
            artifactsStaged: false
        })
        connectCapabilityProcess.command = [
            "python3",
            Quickshell.shellPath(
                "scripts/code-workflow/connect_prepare.py"),
            "--probe",
            "--target-id", String(command.targetId ?? ""),
            "--connect-target-id",
                String(command.connectTargetId ?? "")
        ]
        connectCapabilityProcess.running = true
        return true
    }

    function finishConnectPreparationCapability(exitCode: int): void {
        const raw = String(connectCapabilityStdout.text ?? "").trim()
        let payload = null
        try {
            payload = raw.length > 0 ? JSON.parse(raw) : null
        } catch (e) {
            payload = null
        }

        const index = root._pendingConnectPreparationIndex
        const pendingCandidate =
            root._pendingConnectPreparationCandidateSha
        root._pendingConnectPreparationIndex = -1
        root._pendingConnectPreparationCandidateSha = ""

        if (index < 0 || index >= root.history.length) {
            root.connectPreparationCapability = ({
                status: "blocked",
                ready: false,
                reason: "connect-preview-history-drifted",
                writeAuthorized: false,
                applyEnabled: false,
                artifactsStaged: false
            })
            return
        }

        const command = root.history[index]
        const identityMatches = payload?.protocol === 1
            && String(payload?.status ?? "") === "capability"
            && String(payload?.targetId ?? "")
                === String(command?.targetId ?? "")
            && String(payload?.connectTargetId ?? "")
                === String(command?.connectTargetId ?? "")
            && String(command?.candidateSha256 ?? "")
                === pendingCandidate
            && payload?.writeAuthorized === false
            && payload?.applyEnabled === false
            && payload?.artifactsStaged === false

        if (!identityMatches) {
            const stderrText = String(
                connectCapabilityStderr.text ?? "").trim()
            root.connectPreparationCapability = ({
                status: "blocked",
                ready: false,
                reason: String(
                    payload?.reason
                    ?? stderrText
                    ?? ("capability probe exited " + exitCode)),
                writeAuthorized: false,
                applyEnabled: false,
                artifactsStaged: false
            })
            return
        }

        root.connectPreparationCapability = payload
        if (payload?.ready !== true
                && !root.connectLifecycleBusy
                && root.activeCommand?.connectAuthorization) {
            root.revokeConnectAuthorization(
                "preparation-capability-unavailable")
        }
    }

    function prepareConnectArtifacts(): bool {
        if (!root.connectPrepareEnabled)
            return false

        const command = root.activeCommand
        root._pendingConnectPreparationIndex = root.historyIndex
        root._pendingConnectPreparationCandidateSha = String(
            command.candidateSha256 ?? "")
        root.connectPreparationError = ""
        root.status = "preparing-connect"

        connectPrepareProcess.command = [
            "python3",
            Quickshell.shellPath(
                "scripts/code-workflow/connect_prepare.py"),
            "--target-id", String(command.targetId ?? ""),
            "--connect-target-id",
                String(command.connectTargetId ?? ""),
            "--state-dir",
                Quickshell.statePath(
                    "code-workflow/connect-transactions")
        ]
        connectPrepareProcess.running = true
        return true
    }

    function finishConnectPreparation(exitCode: int): void {
        const raw = String(connectPrepareStdout.text ?? "").trim()
        let payload = null
        try {
            payload = raw.length > 0 ? JSON.parse(raw) : null
        } catch (e) {
            payload = null
        }

        const index = root._pendingConnectPreparationIndex
        const pendingCandidate =
            root._pendingConnectPreparationCandidateSha
        root._pendingConnectPreparationIndex = -1
        root._pendingConnectPreparationCandidateSha = ""

        if (index < 0 || index >= root.history.length) {
            root.connectPreparationError =
                "Connect preview history changed during preparation."
            root._showCommand(root.activeCommand)
            return
        }

        const command = root.history[index]
        const preview = command?.result ?? ({})
        const identityMatches = payload?.protocol === 1
            && String(payload?.status ?? "")
                === "prepared-connect-artifacts"
            && String(payload?.artifactProof ?? "")
                === "prepared-qualified-connect-artifacts-v1"
            && String(payload?.targetId ?? "")
                === String(command?.targetId ?? "")
            && String(payload?.connectTargetId ?? "")
                === String(command?.connectTargetId ?? "")
            && String(payload?.sourcePath ?? "")
                === String(command?.sourcePath ?? "")
            && String(payload?.baseSha256 ?? "")
                === String(command?.baseSha256 ?? "")
            && String(payload?.candidateSha256 ?? "")
                === String(command?.candidateSha256 ?? "")
            && String(command?.candidateSha256 ?? "")
                === pendingCandidate
            && String(payload?.parentSemanticAnchor ?? "")
                === String(command?.semanticAnchor ?? "")
            && String(payload?.bindingName ?? "")
                === String(preview.bindingName ?? "")
            && String(payload?.expression ?? "")
                === String(command?.replacement ?? "")
            && payload?.sourceUnchanged === true
            && payload?.externalSourceReverifiedAtStage === true
            && payload?.writeAuthorized === false
            && payload?.applyEnabled === false
            && payload?.artifactsStaged === true
            && payload?.productionIntegrated === false

        const qualificationPayload =
            root._qualificationPayloadFromPreparation(payload)
        if (identityMatches && qualificationPayload) {
            const safety = Object.assign(
                {},
                root._sanitizeConnectQualification(
                    qualificationPayload),
                {
                    freshness: "fresh",
                    stale: false,
                    staleReason: ""
                })
            const preparation =
                root._sanitizeConnectPreparation(payload)
            const promoted = Object.assign({}, command, {
                connectSafety: safety,
                connectPreparation: preparation
            })
            if (root._connectSafetyMatchesCommand(promoted, true)
                    && root._connectPreparationMatchesCommand(promoted)) {
                const next = root.history.slice()
                next[index] = promoted
                root.history = next
                root.historyIndex = index
                root.connectPreparationError = ""
                root.connectSafetyDiagnostics = ({
                    status: "fresh",
                    ready: true,
                    reason:
                        "qualified-sources-match-prepared-artifacts",
                    sourcePath: String(safety.sourcePath ?? ""),
                    candidateSha256: String(
                        safety.candidateSha256 ?? ""),
                    externalSourcePath: String(
                        safety.externalSourcePath ?? ""),
                    writeAuthorized: false
                })
                root._showCommand(root.activeCommand)
                return
            }
        }

        const stderrText = String(
            connectPrepareStderr.text ?? "").trim()
        root.connectPreparationError = String(
            payload?.detail
            ?? payload?.reason
            ?? stderrText
            ?? ("Connect preparation exited " + exitCode))
        root._showCommand(root.activeCommand)
        Qt.callLater(root.probeActiveConnectPreparationCapability)
    }

    function evaluatePreApply(
        currentPath: string,
        currentSha: string,
        currentAnchor: string,
        analyzerReady: bool,
        currentRebindResolved: bool,
        currentDiagnosticsCount: int
    ): var {
        const command = root.activeCommand
        const blockers = []

        if (!command) {
            blockers.push("no-active-command")
        } else {
            if (root.status !== "preview")
                blockers.push("transaction-not-preview")
            if (String(command.kind ?? "") !== "literal-property")
                blockers.push("write-subset-not-authorized")
            if (command.stale === true)
                blockers.push("preview-stale")
            if (!analyzerReady)
                blockers.push("analyzer-not-ready")
            if (String(currentPath ?? "")
                    !== String(command.sourcePath ?? ""))
                blockers.push("source-selection-mismatch")
            if (String(currentSha ?? "").length === 0
                    || String(currentSha ?? "")
                        !== String(command.baseSha256 ?? ""))
                blockers.push("base-sha-mismatch")
            if (String(currentAnchor ?? "").length === 0
                    || String(currentAnchor ?? "")
                        !== String(command.semanticAnchor ?? ""))
                blockers.push("semantic-anchor-mismatch")
            if (!currentRebindResolved)
                blockers.push("current-semantic-rebind-unresolved")
            if (Number(currentDiagnosticsCount) !== 0)
                blockers.push("parser-diagnostics-present")
            if (command.result?.semanticRebind?.status !== "resolved")
                blockers.push("candidate-semantic-rebind-unresolved")
            const candidateSha = String(
                command.candidateSha256 ?? "")
            if (candidateSha.length === 0)
                blockers.push("candidate-sha-missing")
            else if (candidateSha === String(command.baseSha256 ?? ""))
                blockers.push("candidate-noop")
            if (command.sourceWritable !== true)
                blockers.push("source-read-only")
        }

        const ready = blockers.length === 0
        root.preApplyDiagnostics = ({
            status: ready ? "ready" : "blocked",
            ready: ready,
            blockers: blockers,
            sourcePath: String(command?.sourcePath ?? ""),
            baseSha256: String(command?.baseSha256 ?? ""),
            candidateSha256: String(command?.candidateSha256 ?? ""),
            semanticAnchor: String(command?.semanticAnchor ?? ""),
            sourceWritable: command?.sourceWritable === true,
            analyzerReady: analyzerReady,
            currentRebindResolved: currentRebindResolved,
            currentDiagnosticsCount: Number(currentDiagnosticsCount),
            applyEnabled: false
        })
        return root.preApplyDiagnostics
    }

    function _showCommand(command): void {
        if (!command) {
            root._clearPresentation()
            return
        }

        root.sourcePath = String(command.sourcePath ?? "")
        root.baseSha256 = String(command.baseSha256 ?? "")
        root.semanticAnchor = String(command.semanticAnchor ?? "")
        root.replacement = String(command.replacement ?? "")
        root.result = command.result ?? ({})
        root.patch = command.patch ?? ({})
        root.previewText = String(command.previewText ?? "")
        if (command.stale === true) {
            root.status = "conflict"
            root.error = String(
                command.staleReason
                ?? "Source changed after this preview; regenerate it.")
        } else {
            root.status = "preview"
            root.error = ""
        }
        root.preApplyDiagnostics = ({
            status: "not-evaluated",
            ready: false,
            blockers: ["evaluation-required"]
        })
    }

    function clear(): void {
        if (root.previewBusy
                || root.connectSafetyBusy
                || root.connectPreparationBusy
                || root.connectLifecycleBusy
                || root.disconnectPreparationBusy
                || root.disconnectLifecycleBusy
                || applyPrepareProcess.running
                || root.applyLifecycleBusy)
            return
        root._invalidateApplyHandoff()
        if (reloadState.pendingConnectPhase !== "idle")
            root.clearConnectLifecycleHandoff()
        if (reloadState.pendingDisconnectPhase !== "idle")
            root.clearDisconnectLifecycleHandoff()
        root.history = []
        root.historyIndex = -1
        root._pendingReplaceIndex = -1
        root._clearPresentation()
    }

    function undoPreview(): bool {
        if (!root.canUndo)
            return false
        root._invalidateApplyHandoff()
        root.historyIndex--
        root._showCommand(root.activeCommand)
        Qt.callLater(root.reverifyActiveConnectSafety)
        Qt.callLater(root.probeActiveConnectPreparationCapability)
        return true
    }

    function redoPreview(): bool {
        if (!root.canRedo)
            return false
        root._invalidateApplyHandoff()
        root.historyIndex++
        root._showCommand(root.activeCommand)
        Qt.callLater(root.reverifyActiveConnectSafety)
        Qt.callLater(root.probeActiveConnectPreparationCapability)
        return true
    }

    function _markHistoryStale(path: string): void {
        let changed = false
        const next = root.history.map(command => {
            if (String(command.sourcePath ?? "") !== path
                    || command.stale === true)
                return command
            changed = true
            return Object.assign({}, command, {
                stale: true,
                staleReason:
                    "Source changed after this preview; regenerate it."
            })
        })
        if (changed)
            root.history = next
    }

    function markSourceChanged(path: string): void {
        const changedPath = String(path ?? "")
        if (changedPath.length === 0)
            return

        const phase = reloadState.pendingApplyPhase
        const connectPhase = reloadState.pendingConnectPhase
        const disconnectPhase = reloadState.pendingDisconnectPhase
        const lifecycleOwnsSource = changedPath
                === reloadState.pendingApplySourcePath
            && [
                "write-issued",
                "waiting-reload",
                "candidate-verify-issued",
                "rebinding",
                "rollback-pending",
                "rollback-issued",
                "rollback-waiting-reload",
                "rollback-verify-issued"
            ].includes(phase)

        // The transaction's own atomic replace must be allowed to trigger the
        // one watcher-driven reload. commit.py/rollback verification detects
        // concurrent external edits; do not invalidate our persisted handoff.
        if (lifecycleOwnsSource) {
            if (phase.startsWith("rollback"))
                root.status = "rollback-waiting-reload"
            else
                root.status = "apply-waiting-reload"
            return
        }

        const connectLifecycleOwnsSource = changedPath
                === reloadState.pendingConnectSourcePath
            && [
                "write-issued",
                "waiting-reload",
                "candidate-verify-issued",
                "rebinding",
                "rollback-pending",
                "rollback-issued",
                "rollback-waiting-reload",
                "rollback-verify-issued"
            ].includes(connectPhase)
        if (connectLifecycleOwnsSource) {
            if (connectPhase.startsWith("rollback"))
                root.status = "connect-rollback-waiting-reload"
            else
                root.status = "connect-waiting-reload"
            return
        }

        const disconnectLifecycleOwnsSource = changedPath
                === reloadState.pendingDisconnectSourcePath
            && [
                "write-issued",
                "waiting-reload",
                "candidate-verify-issued",
                "postcondition-checking",
                "rollback-pending",
                "rollback-issued",
                "rollback-waiting-reload",
                "rollback-verify-issued"
            ].includes(disconnectPhase)
        if (disconnectLifecycleOwnsSource) {
            if (disconnectPhase.startsWith("rollback"))
                root.status = "disconnect-rollback-waiting-reload"
            else
                root.status = "disconnect-waiting-reload"
            return
        }

        if (connectPhase !== "idle"
                && changedPath
                    === reloadState.pendingConnectExternalSourcePath) {
            reloadState.pendingConnectError =
                "Retained Config dependency changed during Connect lifecycle."
        }

        root._markHistoryStale(changedPath)
        root._markConnectSafetyStale(changedPath)
        root._markDisconnectArtifactsStale(changedPath)
        if (phase !== "idle"
                && changedPath
                    === reloadState.pendingApplySourcePath) {
            root._invalidateApplyHandoff()
            root._showCommand(root.activeCommand)
        }
        if (changedPath === root.sourcePath
                && root.status === "preview") {
            root.status = "conflict"
            root.error =
                "Source changed after patch preview; regenerate before any future Apply."
            root.preApplyDiagnostics = ({
                status: "blocked",
                ready: false,
                blockers: ["preview-stale"],
                applyEnabled: false
            })
        }
    }

    function _markDisconnectArtifactsStale(path: string): void {
        const changedPath = String(path ?? "")
        if (changedPath.length === 0)
            return
        let changed = false
        const next = root.history.map(command => {
            const prepared = command?.disconnectPreparation
            if (!prepared
                    || String(command.sourcePath ?? "") !== changedPath)
                return command
            changed = true
            return Object.assign({}, command, {
                disconnectPreparation: Object.assign({}, prepared, {
                    status: "stale",
                    stale: true,
                    staleReason:
                        "Disconnect source changed; reprepare before write."
                }),
                disconnectAuthorization:
                    command?.disconnectAuthorization
                    ? Object.assign({}, command.disconnectAuthorization, {
                        status: "expired",
                        authorized: false,
                        reason:
                            "Disconnect source changed; reprepare before write."
                    })
                    : command?.disconnectAuthorization
            })
        })
        if (changed)
            root.history = next
    }

    function _startPreview(
        path: string,
        baseSha: string,
        anchor: string,
        nextValue: string,
        replaceIndex: int,
        commandKind: string,
        previewMode: string,
        expectedCurrent: string
    ): bool {
        if (root.previewBusy
                || root.connectSafetyBusy
                || root.connectPreparationBusy
                || root.connectLifecycleBusy
                || root.disconnectPreparationBusy
                || root.disconnectLifecycleBusy
                || applyPrepareProcess.running
                || root.applyLifecycleBusy)
            return false

        const nextPath = String(path ?? "")
        const nextSha = String(baseSha ?? "")
        const nextAnchor = String(anchor ?? "")
        const nextReplacement = String(nextValue ?? "")
        const nextMode = String(previewMode ?? "")
        const nextExpectedCurrent = String(expectedCurrent ?? "")
        if (nextPath.length === 0
                || nextSha.length === 0
                || nextAnchor.length === 0
                || (nextMode !== "disconnect"
                    && nextReplacement.length === 0)
                || (nextMode === "disconnect"
                    && nextExpectedCurrent.length === 0))
            return false

        root._invalidateApplyHandoff()
        root._pendingReplaceIndex = replaceIndex
        root._pendingCommandKind = String(commandKind ?? "")
        root._pendingPreviewMode = nextMode
        root._pendingExpectedCurrent = nextExpectedCurrent
        root._pendingConnectGraphTargetId = ""
        root._pendingConnectTargetId = ""
        if (nextMode !== "disconnect") {
            root._pendingDisconnectGraphTargetId = ""
            root._pendingDisconnectEdgeId = ""
        }
        if (!["literal-property", "direct-binding", "disconnect-binding"]
                .includes(root._pendingCommandKind)
                || !["literal", "binding", "disconnect"]
                    .includes(root._pendingPreviewMode))
            return false
        root.status = "previewing"
        root.sourcePath = nextPath
        root.baseSha256 = nextSha
        root.semanticAnchor = nextAnchor
        root.replacement = nextReplacement
        root.result = ({})
        root.patch = ({})
        root.previewText = ""
        root.error = ""

        previewProcess.command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/transaction.py"),
            "--path", nextPath,
            "--base-sha256", nextSha,
            "--semantic-anchor", nextAnchor,
            "--replacement", nextReplacement,
            "--expected-current", root._pendingExpectedCurrent,
            "--mode", root._pendingPreviewMode
        ]
        previewProcess.running = true
        return true
    }

    function previewLiteral(
        path: string,
        baseSha: string,
        anchor: string,
        nextValue: string
    ): bool {
        return root._startPreview(
            path,
            baseSha,
            anchor,
            nextValue,
            -1,
            "literal-property",
            "literal",
            "")
    }

    function previewBinding(
        path: string,
        baseSha: string,
        anchor: string,
        nextValue: string
    ): bool {
        return root._startPreview(
            path,
            baseSha,
            anchor,
            nextValue,
            -1,
            "direct-binding",
            "binding",
            "")
    }

    function _startDisconnectPreview(
        path: string,
        baseSha: string,
        anchor: string,
        expectedCurrent: string,
        targetId: string,
        edgeId: string,
        replaceIndex: int
    ): bool {
        root._pendingDisconnectGraphTargetId =
            String(targetId ?? "")
        root._pendingDisconnectEdgeId = String(edgeId ?? "")
        if (root._pendingDisconnectGraphTargetId.length === 0
                || root._pendingDisconnectEdgeId.length === 0)
            return false
        const started = root._startPreview(
            path,
            baseSha,
            anchor,
            "",
            replaceIndex,
            "disconnect-binding",
            "disconnect",
            expectedCurrent)
        if (!started) {
            root._pendingDisconnectGraphTargetId = ""
            root._pendingDisconnectEdgeId = ""
        }
        return started
    }

    function previewDisconnectBinding(
        path: string,
        baseSha: string,
        anchor: string,
        expectedCurrent: string,
        targetId: string,
        edgeId: string
    ): bool {
        return root._startDisconnectPreview(
            path,
            baseSha,
            anchor,
            expectedCurrent,
            targetId,
            edgeId,
            -1)
    }

    function _startConnectPreview(
        targetId: string,
        connectTargetId: string,
        replaceIndex: int
    ): bool {
        if (root.previewBusy
                || root.connectSafetyBusy
                || root.connectPreparationBusy
                || applyPrepareProcess.running
                || root.applyLifecycleBusy)
            return false

        const nextTargetId = String(targetId ?? "")
        const nextConnectTargetId = String(connectTargetId ?? "")
        if (nextTargetId.length === 0 || nextConnectTargetId.length === 0)
            return false

        root._invalidateApplyHandoff()
        root._pendingReplaceIndex = replaceIndex
        root._pendingCommandKind = "connect-binding"
        root._pendingPreviewMode = "connect"
        root._pendingExpectedCurrent = ""
        root._pendingConnectGraphTargetId = nextTargetId
        root._pendingConnectTargetId = nextConnectTargetId
        root.status = "previewing"
        root.sourcePath = ""
        root.baseSha256 = ""
        root.semanticAnchor = ""
        root.replacement = ""
        root.result = ({})
        root.patch = ({})
        root.previewText = ""
        root.error = ""

        connectPreviewProcess.command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/connect_preview.py"),
            "--target-id", nextTargetId,
            "--connect-target-id", nextConnectTargetId
        ]
        connectPreviewProcess.running = true
        return true
    }

    function previewConnectBinding(
        targetId: string,
        connectTargetId: string
    ): bool {
        return root._startConnectPreview(
            targetId, connectTargetId, -1)
    }

    function regenerate(baseSha: string): bool {
        const command = root.activeCommand
        if (!command)
            return false
        const commandKind = String(command.kind ?? "")
        if (commandKind === "connect-binding") {
            return root._startConnectPreview(
                String(command.targetId ?? ""),
                String(command.connectTargetId ?? ""),
                root.historyIndex)
        }
        if (commandKind === "disconnect-binding") {
            return root._startDisconnectPreview(
                String(command.sourcePath ?? ""),
                String(baseSha ?? ""),
                String(command.semanticAnchor ?? ""),
                String(command.expectedCurrent ?? ""),
                String(command.targetId ?? ""),
                String(command.reviewedEdgeId ?? ""),
                root.historyIndex)
        }
        const previewMode = commandKind === "direct-binding"
            ? "binding"
            : "literal"
        return root._startPreview(
            String(command.sourcePath ?? ""),
            String(baseSha ?? ""),
            String(command.semanticAnchor ?? ""),
            String(command.replacement ?? ""),
            root.historyIndex,
            commandKind,
            previewMode,
            String(command.expectedCurrent ?? ""))
    }

    function _storeCommand(command): void {
        if (root._pendingReplaceIndex >= 0
                && root._pendingReplaceIndex < root.history.length) {
            const next = root.history.slice()
            next[root._pendingReplaceIndex] = command
            root.history = next
            root.historyIndex = root._pendingReplaceIndex
        } else {
            const next = root.history.slice(
                0, root.historyIndex + 1)
            next.push(command)
            root.history = next
            root.historyIndex = next.length - 1
        }
        root._pendingReplaceIndex = -1
        root._showCommand(root.activeCommand)
    }

    function _commitPreviewCommand(payload): void {
        root._storeCommand({
            kind: root._pendingCommandKind,
            sourcePath: root.sourcePath,
            baseSha256: root.baseSha256,
            candidateSha256: String(payload?.candidateSha256 ?? ""),
            semanticAnchor: root.semanticAnchor,
            replacement: root.replacement,
            expectedCurrent: root._pendingExpectedCurrent,
            targetId: root._pendingCommandKind === "disconnect-binding"
                ? root._pendingDisconnectGraphTargetId
                : "",
            reviewedEdgeId:
                root._pendingCommandKind === "disconnect-binding"
                    ? root._pendingDisconnectEdgeId
                    : "",
            result: payload,
            patch: payload?.patch ?? ({}),
            previewText: String(payload?.preview ?? ""),
            sourceWritable: payload?.sourceWritable === true,
            stale: false,
            staleReason: ""
        })
    }

    function _commitConnectPreviewCommand(payload): void {
        root._storeCommand({
            kind: "connect-binding",
            targetId: root._pendingConnectGraphTargetId,
            connectTargetId: root._pendingConnectTargetId,
            sourcePath: String(payload?.sourcePath ?? ""),
            baseSha256: String(payload?.baseSha256 ?? ""),
            candidateSha256: String(payload?.candidateSha256 ?? ""),
            semanticAnchor: String(payload?.parentSemanticAnchor ?? ""),
            replacement: String(payload?.expression ?? ""),
            expectedCurrent: "",
            typeCompatibility: String(
                payload?.typeCompatibility ?? "unknown-unresolved"),
            cycleStatus: String(
                payload?.cycleStatus ?? "unknown-incomplete-projection"),
            result: payload,
            patch: payload?.patch ?? ({}),
            previewText: String(payload?.preview ?? ""),
            sourceWritable: false,
            stale: false,
            staleReason: ""
        })
    }

    function finish(exitCode: int): void {
        const raw = String(previewStdout.text ?? "").trim()
        let payload = null
        try {
            payload = raw.length > 0 ? JSON.parse(raw) : null
        } catch (e) {
            payload = null
        }

        const nextStatus = String(payload?.status ?? "error")
        if (payload?.protocol === 1 && nextStatus === "preview") {
            const payloadKind = String(payload?.commandKind ?? "")
            if (payloadKind !== root._pendingCommandKind) {
                root._pendingReplaceIndex = -1
                root.status = "error"
                root.error = "preview-command-kind-mismatch"
                return
            }
            root._commitPreviewCommand(payload)
            return
        }

        root._pendingReplaceIndex = -1
        root.result = payload ?? ({})
        root.patch = payload?.patch ?? ({})
        root.previewText = String(payload?.preview ?? "")

        if (payload?.protocol === 1
                && ["conflict", "unsupported", "unavailable", "invalid-patch"]
                    .includes(nextStatus)) {
            root.status = nextStatus
            root.error = String(
                payload?.detail
                ?? payload?.reason
                ?? nextStatus)
            return
        }

        root.status = "error"
        const stderrText = String(previewStderr.text ?? "").trim()
        root.error = String(
            payload?.detail
            ?? payload?.reason
            ?? stderrText
            ?? ("transaction preview exited " + exitCode))
    }

    function finishConnectPreview(exitCode: int): void {
        const raw = String(connectPreviewStdout.text ?? "").trim()
        let payload = null
        try {
            payload = raw.length > 0 ? JSON.parse(raw) : null
        } catch (e) {
            payload = null
        }

        const nextStatus = String(payload?.status ?? "error")
        const identityMatches = payload?.protocol === 1
            && String(payload?.targetId ?? "")
                === root._pendingConnectGraphTargetId
            && String(payload?.connectTargetId ?? "")
                === root._pendingConnectTargetId
        const previewSafe = nextStatus === "preview"
            && String(payload?.commandKind ?? "") === "connect-binding"
            && String(payload?.sourcePath ?? "").length > 0
            && String(payload?.baseSha256 ?? "").length > 0
            && String(payload?.candidateSha256 ?? "").length > 0
            && String(payload?.parentSemanticAnchor ?? "").length > 0
            && String(payload?.insertedSemanticAnchor ?? "").length > 0
            && String(payload?.typeCompatibility ?? "")
                === "unknown-unresolved"
            && String(payload?.cycleStatus ?? "")
                === "unknown-incomplete-projection"
            && payload?.applyEnabled === false
            && payload?.artifactsStaged === false

        if (identityMatches && previewSafe) {
            root._commitConnectPreviewCommand(payload)
            root._pendingConnectGraphTargetId = ""
            root._pendingConnectTargetId = ""
            Qt.callLater(root.probeActiveConnectPreparationCapability)
            return
        }

        root._pendingReplaceIndex = -1
        root.result = payload ?? ({})
        root.patch = payload?.patch ?? ({})
        root.previewText = String(payload?.preview ?? "")
        root._pendingConnectGraphTargetId = ""
        root._pendingConnectTargetId = ""

        if (payload?.protocol === 1
                && ["blocked", "conflict", "unsupported", "unavailable",
                    "invalid-request", "invalid-patch"].includes(nextStatus)) {
            root.status = nextStatus
            root.error = String(
                payload?.detail
                ?? payload?.reason
                ?? nextStatus)
            return
        }

        root.status = "error"
        const stderrText = String(
            connectPreviewStderr.text ?? "").trim()
        root.error = String(
            payload?.detail
            ?? payload?.reason
            ?? stderrText
            ?? ("connect preview exited " + exitCode))
    }

    onHistoryChanged: root._syncReloadState()
    onHistoryIndexChanged: {
        root._syncReloadState()
        if (!root._restoringReloadState) {
            root._expireAllConnectAuthorizations(
                "history-selection-changed")
            root._expireAllDisconnectAuthorizations(
                "history-selection-changed")
        }
    }

    QtObject {
        id: reloadState

        // In-generation mirror only. Cross-generation persistence is owned by
        // CodeWorkflowReloadBridge under ShellRoot, where Quickshell's reload
        // matcher can pair old/new PersistentProperties instances.
        property string historyJson: "[]"
        property int historyIndex: -1
        property string pendingApplyPhase: "idle"
        property string pendingApplySourcePath: ""
        property string pendingApplyBaseSha256: ""
        property string pendingApplyCandidateSha256: ""
        property string pendingApplySemanticAnchor: ""
        property string pendingApplyReplacement: ""
        property int pendingApplyHistoryIndex: -1
        property string pendingApplySnapshotPath: ""
        property string pendingApplyCandidatePath: ""
        property string pendingApplyManifestPath: ""
        property string pendingApplyReloadOutcome: "none"
        property string pendingApplyVerifyState: "unknown"
        property string pendingApplyError: ""
        property string pendingConnectPhase: "idle"
        property string pendingConnectGraphTargetId: ""
        property string pendingConnectTargetId: ""
        property string pendingConnectSourcePath: ""
        property string pendingConnectBaseSha256: ""
        property string pendingConnectCandidateSha256: ""
        property string pendingConnectParentSemanticAnchor: ""
        property string pendingConnectInsertedSemanticAnchor: ""
        property int pendingConnectHistoryIndex: -1
        property string pendingConnectManifestPath: ""
        property string pendingConnectManifestSha256: ""
        property string pendingConnectExternalSourcePath: ""
        property string pendingConnectExternalSourceSha256: ""
        property string pendingConnectAuthorizationToken: ""
        property string pendingConnectReloadOutcome: "none"
        property string pendingConnectVerifyState: "unknown"
        property string pendingConnectRollbackRecovery: "none"
        property string pendingConnectError: ""
        property string pendingDisconnectPhase: "idle"
        property string pendingDisconnectGraphTargetId: ""
        property string pendingDisconnectEdgeId: ""
        property string pendingDisconnectSourcePath: ""
        property string pendingDisconnectBaseSha256: ""
        property string pendingDisconnectCandidateSha256: ""
        property string pendingDisconnectSemanticAnchor: ""
        property int pendingDisconnectHistoryIndex: -1
        property string pendingDisconnectManifestPath: ""
        property string pendingDisconnectManifestSha256: ""
        property string pendingDisconnectAuthorizationToken: ""
        property string pendingDisconnectReloadOutcome: "none"
        property string pendingDisconnectVerifyState: "unknown"
        property string pendingDisconnectRollbackRecovery: "none"
        property string pendingDisconnectError: ""
    }

    Component.onCompleted: root._restoreReloadState()

    Connections {
        target: Quickshell

        function onReloadCompleted(): void {
            root._handleReloadCompleted()
        }

        function onReloadFailed(errorString): void {
            root._handleReloadFailed(String(errorString ?? ""))
        }
    }

    Connections {
        target: CodeWorkflowAnalyzer

        function onStatusChanged(): void {
            root._finishSemanticRebindIfReady()
            root._finishConnectSemanticRebindIfReady()
            root._finishDisconnectPostconditionIfReady()
        }
    }

    Timer {
        id: disconnectRollbackReloadFallbackTimer
        interval: 1800
        repeat: false
        onTriggered: {
            if (reloadState.pendingDisconnectPhase
                    !== "rollback-waiting-reload"
                    || reloadState.pendingDisconnectReloadOutcome
                        !== "none")
                return
            reloadState.pendingDisconnectRollbackRecovery =
                "explicit-recovery"
            Quickshell.reload(false)
        }
    }

    Timer {
        id: connectRollbackReloadFallbackTimer
        interval: 1800
        repeat: false
        onTriggered: {
            if (reloadState.pendingConnectPhase
                    !== "rollback-waiting-reload"
                    || reloadState.pendingConnectReloadOutcome
                        !== "none")
                return
            reloadState.pendingConnectRollbackRecovery =
                "explicit-recovery"
            Quickshell.reload(false)
        }
    }

    Process {
        id: disconnectPrepareProcess
        running: false
        stdout: StdioCollector { id: disconnectPrepareStdout }
        stderr: StdioCollector { id: disconnectPrepareStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishDisconnectPreparation(exitCode)
    }

    Process {
        id: disconnectCommitProcess
        running: false
        stdout: StdioCollector { id: disconnectCommitStdout }
        stderr: StdioCollector { id: disconnectCommitStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishDisconnectCommit(exitCode)
    }

    Process {
        id: disconnectVerifyProcess
        running: false
        stdout: StdioCollector { id: disconnectVerifyStdout }
        stderr: StdioCollector { id: disconnectVerifyStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishDisconnectVerify(exitCode)
    }

    Process {
        id: disconnectRollbackProcess
        running: false
        stdout: StdioCollector { id: disconnectRollbackStdout }
        stderr: StdioCollector { id: disconnectRollbackStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishDisconnectRollback(exitCode)
    }

    Process {
        id: connectCommitProcess
        running: false
        stdout: StdioCollector { id: connectCommitStdout }
        stderr: StdioCollector { id: connectCommitStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishConnectCommit(exitCode)
    }

    Process {
        id: connectVerifyProcess
        running: false
        stdout: StdioCollector { id: connectVerifyStdout }
        stderr: StdioCollector { id: connectVerifyStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishConnectVerify(exitCode)
    }

    Process {
        id: connectRollbackProcess
        running: false
        stdout: StdioCollector { id: connectRollbackStdout }
        stderr: StdioCollector { id: connectRollbackStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishConnectRollback(exitCode)
    }

    Process {
        id: commitProcess
        running: false
        stdout: StdioCollector { id: commitStdout }
        stderr: StdioCollector { id: commitStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishCommit(exitCode)
    }

    Process {
        id: verifyProcess
        running: false
        stdout: StdioCollector { id: verifyStdout }
        stderr: StdioCollector { id: verifyStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishVerify(exitCode)
    }

    Process {
        id: rollbackProcess
        running: false
        stdout: StdioCollector { id: rollbackStdout }
        stderr: StdioCollector { id: rollbackStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishRollback(exitCode)
    }

    Process {
        id: applyPrepareProcess
        running: false
        stdout: StdioCollector { id: applyPrepareStdout }
        stderr: StdioCollector { id: applyPrepareStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishApplyPreparation(exitCode)
    }

    FileView {
        id: connectSafetySourceWatch
        path: root.activeConnectSafety
            ? Quickshell.shellPath(
                String(root.activeConnectSafety.sourcePath ?? ""))
            : ""
        watchChanges: path.length > 0
        onFileChanged: {
            const relative = String(
                root.activeConnectSafety?.sourcePath ?? "")
            if (relative.length > 0)
                root.markSourceChanged(relative)
        }
    }

    FileView {
        id: connectSafetyExternalWatch
        path: root.activeConnectSafety
            ? Quickshell.shellPath(
                String(root.activeConnectSafety.externalSourcePath ?? ""))
            : ""
        watchChanges: path.length > 0
        onFileChanged: {
            const relative = String(
                root.activeConnectSafety?.externalSourcePath ?? "")
            if (relative.length > 0)
                root.markSourceChanged(relative)
        }
    }

    Process {
        id: previewProcess
        running: false
        stdout: StdioCollector { id: previewStdout }
        stderr: StdioCollector { id: previewStderr }
        onExited: (exitCode, _exitStatus) => root.finish(exitCode)
    }

    Process {
        id: connectSafetyProcess
        running: false
        stdout: StdioCollector { id: connectSafetyStdout }
        stderr: StdioCollector { id: connectSafetyStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishConnectSafetyFreshness(exitCode)
    }

    Process {
        id: connectCapabilityProcess
        running: false
        stdout: StdioCollector { id: connectCapabilityStdout }
        stderr: StdioCollector { id: connectCapabilityStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishConnectPreparationCapability(exitCode)
    }

    Process {
        id: connectPrepareProcess
        running: false
        stdout: StdioCollector { id: connectPrepareStdout }
        stderr: StdioCollector { id: connectPrepareStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishConnectPreparation(exitCode)
    }

    Process {
        id: connectPreviewProcess
        running: false
        stdout: StdioCollector { id: connectPreviewStdout }
        stderr: StdioCollector { id: connectPreviewStderr }
        onExited: (exitCode, _exitStatus) =>
            root.finishConnectPreview(exitCode)
    }
}
