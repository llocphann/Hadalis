pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    reloadableId: "code-workflow-transaction"

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
    property var preApplyDiagnostics: ({
        status: "not-evaluated",
        ready: false,
        blockers: ["not-evaluated"]
    })

    readonly property bool dirty: root.status !== "clean"
    readonly property bool preApplyReady:
        root.preApplyDiagnostics?.ready === true
    readonly property bool applyEnabled: false
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
        && Quickshell.watchFiles
        && !root.applyLifecycleBusy
        && reloadState.pendingApplyManifestPath.length > 0
    readonly property bool canUndo:
        !previewProcess.running
        && !applyPrepareProcess.running
        && !root.applyLifecycleBusy
        && root.historyIndex >= 0
    readonly property bool canRedo:
        !previewProcess.running
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

        root.history = parsed
        root.historyIndex = Math.max(
            -1,
            Math.min(
                Number(reloadState.historyIndex ?? -1),
                parsed.length - 1))
        root._restoringReloadState = false
        root._reloadStateReady = true
        root._showCommand(root.activeCommand)
        Qt.callLater(root._recoverApplyLifecycle)
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
        if (!root.applyLifecycleReady)
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
        reloadState.pendingApplyReloadOutcome = "none"
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
            reloadState.pendingApplyReloadOutcome = "none"
            root.status = "rollback-waiting-reload"
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
            if (reloadState.pendingApplyReloadOutcome === "completed")
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
        if (previewProcess.running
                || applyPrepareProcess.running
                || root.applyLifecycleBusy)
            return
        root._invalidateApplyHandoff()
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
        return true
    }

    function redoPreview(): bool {
        if (!root.canRedo)
            return false
        root._invalidateApplyHandoff()
        root.historyIndex++
        root._showCommand(root.activeCommand)
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

        root._markHistoryStale(changedPath)
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

    function _startPreview(
        path: string,
        baseSha: string,
        anchor: string,
        nextValue: string,
        replaceIndex: int
    ): bool {
        if (previewProcess.running
                || applyPrepareProcess.running
                || root.applyLifecycleBusy)
            return false

        const nextPath = String(path ?? "")
        const nextSha = String(baseSha ?? "")
        const nextAnchor = String(anchor ?? "")
        const nextReplacement = String(nextValue ?? "")
        if (nextPath.length === 0
                || nextSha.length === 0
                || nextAnchor.length === 0
                || nextReplacement.length === 0)
            return false

        root._invalidateApplyHandoff()
        root._pendingReplaceIndex = replaceIndex
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
            "--replacement", nextReplacement
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
            path, baseSha, anchor, nextValue, -1)
    }

    function regenerate(baseSha: string): bool {
        const command = root.activeCommand
        if (!command)
            return false
        return root._startPreview(
            String(command.sourcePath ?? ""),
            String(baseSha ?? ""),
            String(command.semanticAnchor ?? ""),
            String(command.replacement ?? ""),
            root.historyIndex)
    }

    function _commitPreviewCommand(payload): void {
        const command = {
            kind: "literal-property",
            sourcePath: root.sourcePath,
            baseSha256: root.baseSha256,
            candidateSha256: String(payload?.candidateSha256 ?? ""),
            semanticAnchor: root.semanticAnchor,
            replacement: root.replacement,
            result: payload,
            patch: payload?.patch ?? ({}),
            previewText: String(payload?.preview ?? ""),
            sourceWritable: payload?.sourceWritable === true,
            stale: false,
            staleReason: ""
        }

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

    onHistoryChanged: root._syncReloadState()
    onHistoryIndexChanged: root._syncReloadState()

    PersistentProperties {
        id: reloadState
        reloadableId: "code-workflow-transaction-state"

        // Keep reload handoff primitive/JSON-only. Runtime QObject identities
        // and transient parser byte ranges are never persisted here.
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

        onLoaded: root._restoreReloadState()
        onReloaded: root._restoreReloadState()
    }


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
        }
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

    Process {
        id: previewProcess
        running: false
        stdout: StdioCollector { id: previewStdout }
        stderr: StdioCollector { id: previewStderr }
        onExited: (exitCode, _exitStatus) => root.finish(exitCode)
    }
}
