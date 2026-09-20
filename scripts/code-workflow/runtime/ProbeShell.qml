import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.bar
import qs.modules.common
import qs.modules.settings
import qs.services
// WORKFLOW_PROBE_IMPORT: prepare-runtime.py replaces this marker only in the
// isolated exported runtime after creating config/workflowprobe/qmldir.

ShellRoot {
    id: shell

    CodeWorkflowReloadBridge {}

    readonly property int sourceRevision: 1 // Mutated only in the temporary runtime copy.
    property bool initialized: false
    property bool persistenceReady: false
    property int dormantCreations: 0
    property int reloadCompletions: 0
    property int reloadFailures: 0
    property string lastReloadError: ""
    property bool mediaEnabled: true

    PersistentProperties {
        id: state
        reloadableId: "workflow-phase0-selection"
        property string selectedInstanceId: ""
        property string selectedTargetId: ""
        // QJSValue objects belong to the old engine. Persist primitives only.
        property string viewportJson: '{"x":31,"y":-17,"zoom":1.25,"subflow":"bar"}'
        property bool mediaEnabled: true
        onLoaded: {
            RuntimeRegistry.selectedInstanceId = selectedInstanceId
            RuntimeRegistry.selectedTargetId = selectedTargetId
            RuntimeRegistry.viewport = JSON.parse(viewportJson)
            shell.mediaEnabled = mediaEnabled
            shell.persistenceReady = true
            shell.initialize()
        }
    }
    Connections {
        target: RuntimeRegistry
        function onSelectedInstanceIdChanged() { state.selectedInstanceId = RuntimeRegistry.selectedInstanceId }
        function onSelectedTargetIdChanged() { state.selectedTargetId = RuntimeRegistry.selectedTargetId }
        function onViewportChanged() { state.viewportJson = JSON.stringify(RuntimeRegistry.viewport) }
    }
    function initialize() {
        if (initialized || !Config.ready || !persistenceReady) return
        initialized = true
        // Fixture-only config under isolated XDG. Use the normal mirror-aware
        // API: raw JsonAdapter assignment can be overwritten by pending writes.
        Config.setNestedValue("bar.modules.media", mediaEnabled)
        GlobalStates.shellEntryReady = true
        GlobalStates.bootGreetingDone = true
        GlobalStates.barOpen = true
    }
    Connections { target: Config; function onReadyChanged() { shell.initialize() } }
    Connections {
        target: Quickshell
        function onReloadCompleted() { shell.reloadCompletions++ }
        function onReloadFailed(errorString) {
            shell.reloadFailures++
            shell.lastReloadError = String(errorString ?? "")
        }
    }

    ApplyTarget { id: applyTarget }

    FileView {
        path: Quickshell.shellPath("workflowprobe/ApplyTarget.qml")
        watchChanges: true
        printErrors: false
        onFileChanged:
            CodeWorkflowTransaction.markSourceChanged(
                "workflowprobe/ApplyTarget.qml")
    }

    Bar {}
    SettingsOverlay { id: settings }
    PickerProbe { id: picker; settings: settings }
    // Real Quickshell lazy lifecycle sentinel: discovery must never touch item.
    LazyLoader {
        id: dormant
        active: false
        component: QtObject { Component.onCompleted: shell.dormantCreations++ }
    }
    IpcHandler {
        target: "workflowProbe"
        function snapshot(): string {
            const report = RuntimeRegistry.snapshot()
            report.sourceRevision = shell.sourceRevision
            report.ready = shell.initialized
            report.dormantActive = dormant.active
            report.dormantLoading = dormant.loading
            report.dormantCreations = shell.dormantCreations
            report.screenLocked = GlobalStates.screenLocked
            report.barOpen = GlobalStates.barOpen
            report.mediaControlsOpen = GlobalStates.mediaControlsOpen
            report.reloadCompletions = shell.reloadCompletions
            report.reloadFailures = shell.reloadFailures
            report.lastReloadError = shell.lastReloadError
            report.applyTarget = {
                applyFlag: applyTarget.applyFlag,
                rollbackProbe: applyTarget.rollbackProbe,
                conflictProbe: applyTarget.conflictProbe
            }
            report.workflowAnalyzer = {
                status: CodeWorkflowAnalyzer.status,
                sourcePath: CodeWorkflowAnalyzer.sourcePath,
                sourceNeedle: CodeWorkflowAnalyzer.sourceNeedle,
                semanticAnchor: CodeWorkflowAnalyzer.semanticAnchor,
                sourceSha256: String(
                    CodeWorkflowAnalyzer.result?.sourceSha256 ?? ""),
                reviewedAnchor: CodeWorkflowAnalyzer.reviewedAnchor,
                semanticRebind: CodeWorkflowAnalyzer.semanticRebind,
                diagnostics: CodeWorkflowAnalyzer.diagnostics
            }
            report.workflowTransaction = {
                status: CodeWorkflowTransaction.status,
                error: CodeWorkflowTransaction.error,
                historyIndex: CodeWorkflowTransaction.historyIndex,
                historyLength: CodeWorkflowTransaction.history.length,
                preApplyReady: CodeWorkflowTransaction.preApplyReady,
                prepareApplyEnabled:
                    CodeWorkflowTransaction.prepareApplyEnabled,
                applyArtifactsReady:
                    CodeWorkflowTransaction.applyArtifactsReady,
                applyLifecycleReady:
                    CodeWorkflowTransaction.applyLifecycleReady,
                applyLifecycleBusy:
                    CodeWorkflowTransaction.applyLifecycleBusy,
                applyEnabled: CodeWorkflowTransaction.applyEnabled,
                pendingApplyPhase:
                    CodeWorkflowTransaction.pendingApplyPhase,
                applyPreparationError:
                    CodeWorkflowTransaction.applyPreparationError,
                applyLifecycleError:
                    CodeWorkflowTransaction.applyLifecycleError,
                applyLifecycleResult:
                    CodeWorkflowTransaction.applyLifecycleResult,
                activeCommandKind: String(
                    CodeWorkflowTransaction.activeCommand?.kind ?? ""),
                activeCommandSourcePath: String(
                    CodeWorkflowTransaction.activeCommand?.sourcePath ?? ""),
                activeCommandBaseSha256: String(
                    CodeWorkflowTransaction.activeCommand?.baseSha256 ?? ""),
                activeCommandCandidateSha256: String(
                    CodeWorkflowTransaction.activeCommand
                        ?.candidateSha256 ?? ""),
                connectPreparationBusy:
                    CodeWorkflowTransaction.connectPreparationBusy,
                connectPreparationCapability:
                    CodeWorkflowTransaction.connectPreparationCapability,
                connectArtifactsReady:
                    CodeWorkflowTransaction.connectArtifactsReady,
                connectPreparationError:
                    CodeWorkflowTransaction.connectPreparationError,
                connectLifecycleBusy:
                    CodeWorkflowTransaction.connectLifecycleBusy,
                pendingConnectPhase:
                    CodeWorkflowTransaction.pendingConnectPhase,
                connectLifecycleError:
                    CodeWorkflowTransaction.connectLifecycleError,
                connectLifecycleResult:
                    CodeWorkflowTransaction.connectLifecycleResult,
                connectAuthorizationReady:
                    CodeWorkflowTransaction.connectAuthorizationReady,
                connectAuthorizeEnabled:
                    CodeWorkflowTransaction.connectAuthorizeEnabled,
                connectAuthorizationDiagnostics:
                    CodeWorkflowTransaction.connectAuthorizationDiagnostics,
                activeConnectAuthorization:
                    CodeWorkflowTransaction.activeConnectAuthorization,
                activeConnectSafety:
                    CodeWorkflowTransaction.activeConnectSafety,
                activeConnectPreparation:
                    CodeWorkflowTransaction.activeConnectPreparation
            }
            report.mediaActions = RuntimeRegistry.mediaActions
            report.mediaPopupsOpen = Object.values(RuntimeRegistry.entries).some(p =>
                p.targetId === "bar/media" && p.runtimeObject?.barMediaPopupVisible === true)
            report.settingsOpen = GlobalStates.settingsOverlayOpen
            report.settingsLoaded = settings._panelLoaded
            report.settingsPage = settings.overlayCurrentPage
            report.settingsPublishedPage = GlobalStates.settingsOverlayCurrentPage
            report.picker = {phase:picker.phase, overlays:picker.liveOverlays,
                lastReason:picker.lastReason, consumedClicks:picker.consumedClicks,
                keyboardFocus:"None", saved:picker.saved,lastClick:picker.lastClick}
            return JSON.stringify(report)
        }
        function select(instanceId: string): bool { return RuntimeRegistry.select(instanceId) }
        function viewport(encoded: string): void { RuntimeRegistry.viewport = JSON.parse(encoded) }
        function media(enabled: bool): void {
            shell.mediaEnabled = enabled
            state.mediaEnabled = enabled
            Config.setNestedValue("bar.modules.media", enabled)
        }
        function bar(enabled: bool): void { GlobalStates.barOpen = enabled }
        function bottom(enabled: bool): void { Config.setNestedValue("bar.bottom", enabled) }
        function hold(enabled: bool): void { RuntimeRegistry.pickHold = enabled }
        function autoHide(enabled: bool): void { Config.setNestedValue("bar.autoHide.enable", enabled) }
        function settingsOpen(page: int): void { GlobalStates.openSettingsPage(page) }
        function settingsClose(): void { GlobalStates.settingsOverlayOpen = false }
        // Fixture cleanup after the real-click positive control, not an editor action.
        function resetMediaPopups(): void {
            for (const p of Object.values(RuntimeRegistry.entries))
                if (p.targetId === "bar/media" && p.runtimeObject)
                    p.runtimeObject.barMediaPopupVisible = false
        }
        function pick(): bool { return picker.begin() }
        function cancel(): void { picker.finish("cancelled", "") }
        function lock(enabled: bool): void { GlobalStates.screenLocked = enabled }
        function workflowAnalyze(needle: string, anchor: string): void {
            CodeWorkflowAnalyzer.request(
                "workflowprobe/ApplyTarget.qml",
                needle,
                anchor,
                true)
        }
        function workflowPreview(replacement: string): bool {
            const anchor = String(
                CodeWorkflowAnalyzer.reviewedAnchor
                    ?.semanticAnchor ?? "")
            const sha = String(
                CodeWorkflowAnalyzer.result?.sourceSha256 ?? "")
            if (anchor.length === 0 || sha.length === 0)
                return false
            return CodeWorkflowTransaction.previewLiteral(
                "workflowprobe/ApplyTarget.qml",
                sha,
                anchor,
                replacement)
        }
        function workflowEvaluate(): void {
            const analyzerReady =
                CodeWorkflowAnalyzer.status === "ready"
                && CodeWorkflowAnalyzer.sourcePath
                    === "workflowprobe/ApplyTarget.qml"
            CodeWorkflowTransaction.evaluatePreApply(
                "workflowprobe/ApplyTarget.qml",
                analyzerReady
                    ? String(
                        CodeWorkflowAnalyzer.result?.sourceSha256
                            ?? "")
                    : "",
                String(
                    CodeWorkflowAnalyzer.semanticAnchor ?? ""),
                analyzerReady,
                analyzerReady
                    && CodeWorkflowAnalyzer.semanticRebind
                        ?.status === "resolved",
                analyzerReady
                    ? CodeWorkflowAnalyzer.diagnostics.length
                    : -1)
        }
        function workflowPrepare(): bool {
            return CodeWorkflowTransaction.prepareApplyArtifacts()
        }
        function workflowBeginLifecycle(): bool {
            return CodeWorkflowTransaction.beginApplyLifecycle()
        }
        function workflowConnectPreview(): bool {
            return CodeWorkflowTransaction.previewConnectBinding(
                "bar/clock",
                "clock.connect.rootVisible")
        }
        function workflowConnectPrepare(): bool {
            return CodeWorkflowTransaction.prepareConnectArtifacts()
        }
        function workflowConnectAuthorize(): bool {
            return CodeWorkflowTransaction.authorizeConnectWrite()
        }
        function workflowConnectRevoke(): bool {
            return CodeWorkflowTransaction.revokeConnectAuthorization(
                "probe-user-revoked")
        }
        function workflowConnectBeginLifecycle(): bool {
            return CodeWorkflowTransaction.beginConnectLifecycle()
        }
        function workflowUndo(): bool {
            return CodeWorkflowTransaction.undoPreview()
        }
        function workflowRedo(): bool {
            return CodeWorkflowTransaction.redoPreview()
        }
        function workflowConnectOverridePreparedAnchor(
            anchor: string
        ): bool {
            const index = CodeWorkflowTransaction.historyIndex
            const command = CodeWorkflowTransaction.activeCommand
            if (index < 0
                    || !command
                    || !command.connectPreparation)
                return false
            const next = CodeWorkflowTransaction.history.slice()
            next[index] = Object.assign({}, command, {
                connectPreparation: Object.assign(
                    {},
                    command.connectPreparation,
                    { insertedSemanticAnchor: String(anchor ?? "") })
            })
            CodeWorkflowTransaction.history = next
            return true
        }
        function workflowConnectOverridePreparedManifestSha(
            manifestSha256: string
        ): bool {
            const index = CodeWorkflowTransaction.historyIndex
            const command = CodeWorkflowTransaction.activeCommand
            if (index < 0
                    || !command
                    || !command.connectPreparation)
                return false
            const next = CodeWorkflowTransaction.history.slice()
            next[index] = Object.assign({}, command, {
                connectPreparation: Object.assign(
                    {},
                    command.connectPreparation,
                    { manifestSha256: String(manifestSha256 ?? "") })
            })
            CodeWorkflowTransaction.history = next
            return true
        }
        function workflowConnectAnalyze(anchor: string): void {
            CodeWorkflowAnalyzer.request(
                "modules/bar/ClockWidget.qml",
                "visible: root.showDate",
                String(anchor ?? ""),
                true)
        }
        function workflowClear(): void {
            CodeWorkflowTransaction.clear()
        }
        function reload(): void { Quickshell.reload(false) }
    }
}
