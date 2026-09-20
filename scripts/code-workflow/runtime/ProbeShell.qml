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
        // Probe-only persisted evidence for cross-pipeline contention. This
        // survives the owner-triggered Quickshell reload in isolated acceptance.
        property string mutationContentionJson: "{}"
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
            try {
                report.mutationContention =
                    JSON.parse(state.mutationContentionJson)
            } catch (_error) {
                report.mutationContention = ({})
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
                historySummary: CodeWorkflowTransaction.history.map(
                    (command, index) => ({
                        index: index,
                        kind: String(command?.kind ?? ""),
                        sourcePath: String(command?.sourcePath ?? ""),
                        stale: command?.stale === true,
                        staleReason: String(command?.staleReason ?? ""),
                        connectSafetyFreshness: String(
                            command?.connectSafety?.freshness ?? ""),
                        connectPreparationStatus: String(
                            command?.connectPreparation?.status ?? ""),
                        connectAuthorizationStatus: String(
                            command?.connectAuthorization?.status ?? ""),
                        connectAuthorizationAuthorized:
                            command?.connectAuthorization?.authorized === true,
                        bindingPreparationStatus: String(
                            command?.bindingPreparation?.status ?? ""),
                        bindingAuthorizationStatus: String(
                            command?.bindingAuthorization?.status ?? ""),
                        bindingAuthorizationAuthorized:
                            command?.bindingAuthorization?.authorized === true,
                        bindingRolledBack:
                            command?.bindingRolledBack === true,
                        signalActionPreparationStatus: String(
                            command?.signalActionPreparation?.status ?? ""),
                        signalActionAuthorizationStatus: String(
                            command?.signalActionAuthorization?.status ?? ""),
                        signalActionAuthorizationAuthorized:
                            command?.signalActionAuthorization?.authorized === true,
                        signalActionRolledBack:
                            command?.signalActionRolledBack === true,
                        disconnectPreparationStatus: String(
                            command?.disconnectPreparation?.status ?? ""),
                        disconnectAuthorizationStatus: String(
                            command?.disconnectAuthorization?.status ?? ""),
                        disconnectAuthorizationAuthorized:
                            command?.disconnectAuthorization?.authorized === true
                    })),
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
                connectApplyEnabled:
                    CodeWorkflowTransaction.connectApplyEnabled,
                connectAuthorizeEnabled:
                    CodeWorkflowTransaction.connectAuthorizeEnabled,
                connectAuthorizationDiagnostics:
                    CodeWorkflowTransaction.connectAuthorizationDiagnostics,
                activeConnectAuthorization:
                    CodeWorkflowTransaction.activeConnectAuthorization,
                activeConnectSafety:
                    CodeWorkflowTransaction.activeConnectSafety,
                activeConnectPreparation:
                    CodeWorkflowTransaction.activeConnectPreparation,
                bindingPreparationBusy:
                    CodeWorkflowTransaction.bindingPreparationBusy,
                bindingArtifactsReady:
                    CodeWorkflowTransaction.bindingArtifactsReady,
                bindingPreparationError:
                    CodeWorkflowTransaction.bindingPreparationError,
                bindingLifecycleBusy:
                    CodeWorkflowTransaction.bindingLifecycleBusy,
                pendingBindingPhase:
                    CodeWorkflowTransaction.pendingBindingPhase,
                bindingLifecycleError:
                    CodeWorkflowTransaction.bindingLifecycleError,
                bindingLifecycleResult:
                    CodeWorkflowTransaction.bindingLifecycleResult,
                bindingAuthorizationReady:
                    CodeWorkflowTransaction.bindingAuthorizationReady,
                bindingAuthorizeEnabled:
                    CodeWorkflowTransaction.bindingAuthorizeEnabled,
                bindingApplyEnabled:
                    CodeWorkflowTransaction.bindingApplyEnabled,
                bindingAuthorizationDiagnostics:
                    CodeWorkflowTransaction.bindingAuthorizationDiagnostics,
                activeBindingAuthorization:
                    CodeWorkflowTransaction.activeBindingAuthorization,
                activeBindingPreparation:
                    CodeWorkflowTransaction.activeBindingPreparation,
                signalActionPreparationBusy:
                    CodeWorkflowTransaction.signalActionPreparationBusy,
                signalActionArtifactsReady:
                    CodeWorkflowTransaction.signalActionArtifactsReady,
                signalActionPreparationError:
                    CodeWorkflowTransaction.signalActionPreparationError,
                signalActionLifecycleBusy:
                    CodeWorkflowTransaction.signalActionLifecycleBusy,
                pendingSignalActionPhase:
                    CodeWorkflowTransaction.pendingSignalActionPhase,
                signalActionLifecycleError:
                    CodeWorkflowTransaction.signalActionLifecycleError,
                signalActionLifecycleResult:
                    CodeWorkflowTransaction.signalActionLifecycleResult,
                signalActionAuthorizationReady:
                    CodeWorkflowTransaction.signalActionAuthorizationReady,
                signalActionAuthorizeEnabled:
                    CodeWorkflowTransaction.signalActionAuthorizeEnabled,
                signalActionApplyEnabled:
                    CodeWorkflowTransaction.signalActionApplyEnabled,
                signalActionAuthorizationDiagnostics:
                    CodeWorkflowTransaction
                        .signalActionAuthorizationDiagnostics,
                activeSignalActionAuthorization:
                    CodeWorkflowTransaction.activeSignalActionAuthorization,
                activeSignalActionPreparation:
                    CodeWorkflowTransaction.activeSignalActionPreparation,
                disconnectPreparationBusy:
                    CodeWorkflowTransaction.disconnectPreparationBusy,
                disconnectArtifactsReady:
                    CodeWorkflowTransaction.disconnectArtifactsReady,
                disconnectPreparationError:
                    CodeWorkflowTransaction.disconnectPreparationError,
                disconnectLifecycleBusy:
                    CodeWorkflowTransaction.disconnectLifecycleBusy,
                pendingDisconnectPhase:
                    CodeWorkflowTransaction.pendingDisconnectPhase,
                disconnectLifecycleError:
                    CodeWorkflowTransaction.disconnectLifecycleError,
                disconnectLifecycleResult:
                    CodeWorkflowTransaction.disconnectLifecycleResult,
                disconnectAuthorizationReady:
                    CodeWorkflowTransaction.disconnectAuthorizationReady,
                disconnectAuthorizeEnabled:
                    CodeWorkflowTransaction.disconnectAuthorizeEnabled,
                disconnectApplyEnabled:
                    CodeWorkflowTransaction.disconnectApplyEnabled,
                disconnectAuthorizationDiagnostics:
                    CodeWorkflowTransaction.disconnectAuthorizationDiagnostics,
                activeDisconnectAuthorization:
                    CodeWorkflowTransaction.activeDisconnectAuthorization,
                activeDisconnectPreparation:
                    CodeWorkflowTransaction.activeDisconnectPreparation
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
        function workflowBindingAnalyze(): void {
            CodeWorkflowAnalyzer.request(
                "modules/bar/ClockWidget.qml",
                "text: DateTime.timeDisplay",
                "",
                true)
        }
        function workflowBindingAnalyzeBullet(): void {
            CodeWorkflowAnalyzer.request(
                "modules/bar/ClockWidget.qml",
                "text: \"•\"",
                "",
                true)
        }
        function workflowBindingPreview(): bool {
            const anchor = String(
                CodeWorkflowAnalyzer.reviewedAnchor
                    ?.semanticAnchor ?? "")
            const sha = String(
                CodeWorkflowAnalyzer.result?.sourceSha256 ?? "")
            if (anchor.length === 0 || sha.length === 0)
                return false
            return CodeWorkflowTransaction.previewBinding(
                "modules/bar/ClockWidget.qml",
                sha,
                anchor,
                "DateTime.date",
                "bar/clock")
        }
        function workflowBindingPrepare(): bool {
            return CodeWorkflowTransaction.prepareBindingArtifacts()
        }
        function workflowBindingAuthorize(): bool {
            return CodeWorkflowTransaction.authorizeBindingWrite()
        }
        function workflowBindingRevoke(): bool {
            return CodeWorkflowTransaction.revokeBindingAuthorization(
                "probe-user-revoked")
        }
        function workflowBindingApply(): bool {
            return CodeWorkflowTransaction.beginAuthorizedBindingApply()
        }
        function workflowBindingOverridePreparedAnchor(
            anchor: string,
            manifestSha256: string
        ): bool {
            const index = CodeWorkflowTransaction.historyIndex
            const command = CodeWorkflowTransaction.activeCommand
            if (index < 0
                    || !command
                    || !command.bindingPreparation)
                return false
            const next = CodeWorkflowTransaction.history.slice()
            next[index] = Object.assign({}, command, {
                semanticAnchor: String(anchor ?? ""),
                bindingPreparation: Object.assign(
                    {},
                    command.bindingPreparation,
                    {
                        semanticAnchor: String(anchor ?? ""),
                        manifestSha256:
                            String(manifestSha256 ?? "")
                    })
            })
            CodeWorkflowTransaction.history = next
            return true
        }


        function workflowSignalActionPreview(): bool {
            return CodeWorkflowTransaction.previewSignalAction(
                "bar/media",
                "media.signal.doubleClickToggle")
        }
        function workflowSignalActionPrepare(): bool {
            return CodeWorkflowTransaction.prepareSignalActionArtifacts()
        }
        function workflowSignalActionAuthorize(): bool {
            return CodeWorkflowTransaction.authorizeSignalActionWrite()
        }
        function workflowSignalActionRevoke(): bool {
            return CodeWorkflowTransaction.revokeSignalActionAuthorization(
                "probe-user-revoked")
        }
        function workflowSignalActionBeginLifecycle(): bool {
            return CodeWorkflowTransaction.beginSignalActionLifecycle()
        }
        function workflowSignalActionApply(): bool {
            return CodeWorkflowTransaction
                .beginAuthorizedSignalActionApply()
        }
        function workflowSignalActionAnalyzeExistingAction(): void {
            CodeWorkflowAnalyzer.request(
                "modules/bar/Media.qml",
                "function toggleExpanded(): void",
                "",
                true)
        }
        function workflowSignalActionOverridePreparedAnchor(
            anchor: string,
            manifestSha256: string
        ): bool {
            const index = CodeWorkflowTransaction.historyIndex
            const command = CodeWorkflowTransaction.activeCommand
            if (index < 0
                    || !command
                    || !command.signalActionPreparation)
                return false
            const next = CodeWorkflowTransaction.history.slice()
            next[index] = Object.assign({}, command, {
                semanticAnchor: String(anchor ?? ""),
                insertedHandlerSemanticAnchor:
                    String(anchor ?? ""),
                signalActionPreparation: Object.assign(
                    {},
                    command.signalActionPreparation,
                    {
                        insertedHandlerSemanticAnchor:
                            String(anchor ?? ""),
                        manifestSha256:
                            String(manifestSha256 ?? "")
                    })
            })
            CodeWorkflowTransaction.history = next
            return true
        }

        function workflowDisconnectAnalyze(): void {
            CodeWorkflowAnalyzer.request(
                "modules/bar/ClockWidget.qml",
                "text: DateTime.timeDisplay",
                "",
                true)
        }
        function workflowDisconnectAnalyzeDate(): void {
            CodeWorkflowAnalyzer.request(
                "modules/bar/ClockWidget.qml",
                "text: DateTime.date",
                "",
                true)
        }
        function workflowDisconnectPreview(): bool {
            const anchor = String(
                CodeWorkflowAnalyzer.reviewedAnchor
                    ?.semanticAnchor ?? "")
            const sha = String(
                CodeWorkflowAnalyzer.result?.sourceSha256 ?? "")
            if (anchor.length === 0 || sha.length === 0)
                return false
            return CodeWorkflowTransaction.previewDisconnectBinding(
                "modules/bar/ClockWidget.qml",
                sha,
                anchor,
                "DateTime.timeDisplay",
                "bar/clock",
                "clock.data.time")
        }
        function workflowDisconnectPrepare(): bool {
            return CodeWorkflowTransaction.prepareDisconnectArtifacts()
        }
        function workflowDisconnectAuthorize(): bool {
            return CodeWorkflowTransaction.authorizeDisconnectWrite()
        }
        function workflowDisconnectRevoke(): bool {
            return CodeWorkflowTransaction.revokeDisconnectAuthorization(
                "probe-user-revoked")
        }
        function workflowDisconnectApply(): bool {
            return CodeWorkflowTransaction.beginAuthorizedDisconnectApply()
        }
        function workflowDisconnectOverridePreparedAnchor(
            anchor: string,
            manifestSha256: string
        ): bool {
            const index = CodeWorkflowTransaction.historyIndex
            const command = CodeWorkflowTransaction.activeCommand
            if (index < 0
                    || !command
                    || !command.disconnectPreparation)
                return false
            const next = CodeWorkflowTransaction.history.slice()
            next[index] = Object.assign({}, command, {
                semanticAnchor: String(anchor ?? ""),
                disconnectPreparation: Object.assign(
                    {},
                    command.disconnectPreparation,
                    {
                        semanticAnchor: String(anchor ?? ""),
                        manifestSha256:
                            String(manifestSha256 ?? "")
                    })
            })
            CodeWorkflowTransaction.history = next
            return true
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
        function workflowConnectApply(): bool {
            return CodeWorkflowTransaction.beginAuthorizedConnectApply()
        }
        // Probe-only selector. Production history navigation intentionally
        // expires write authorization; V-B needs to retain independently
        // prepared commands so it can exercise the service's defense-in-depth
        // lifecycle serialization guards in one deterministic runtime.
        function workflowTestSelectHistoryIndex(index: int): bool {
            const next = Number(index ?? -1)
            if (next < 0 || next >= CodeWorkflowTransaction.history.length)
                return false
            const restoring =
                CodeWorkflowTransaction._restoringReloadState
            CodeWorkflowTransaction._restoringReloadState = true
            CodeWorkflowTransaction.historyIndex = next
            CodeWorkflowTransaction._showCommand(
                CodeWorkflowTransaction.activeCommand)
            CodeWorkflowTransaction._restoringReloadState = restoring
            if (String(
                    CodeWorkflowTransaction.activeCommand?.kind ?? "")
                    === "connect-binding") {
                Qt.callLater(
                    CodeWorkflowTransaction.reverifyActiveConnectSafety)
                Qt.callLater(
                    CodeWorkflowTransaction
                        .probeActiveConnectPreparationCapability)
            }
            return CodeWorkflowTransaction.historyIndex === next
        }

        function workflowTestSetHistoryIndexQuiet(index: int): bool {
            const next = Number(index ?? -1)
            if (next < 0 || next >= CodeWorkflowTransaction.history.length)
                return false
            const restoring =
                CodeWorkflowTransaction._restoringReloadState
            CodeWorkflowTransaction._restoringReloadState = true
            CodeWorkflowTransaction.historyIndex = next
            CodeWorkflowTransaction._restoringReloadState = restoring
            return CodeWorkflowTransaction.historyIndex === next
        }

        function workflowContentionStartBindingAgainstAll(
            bindingIndex: int,
            disconnectIndex: int,
            connectIndex: int,
            literalIndex: int
        ): bool {
            if (!workflowTestSelectHistoryIndex(bindingIndex))
                return false

            const ownerReady =
                CodeWorkflowTransaction.bindingAuthorizationReady
                && CodeWorkflowTransaction.bindingArtifactsReady
                && CodeWorkflowTransaction.bindingApplyEnabled
            const ownerStarted =
                CodeWorkflowTransaction.beginAuthorizedBindingApply()
            const ownerBusy =
                CodeWorkflowTransaction.bindingLifecycleBusy
            const attempts = ({})

            if (ownerStarted && ownerBusy) {
                workflowTestSetHistoryIndexQuiet(disconnectIndex)
                attempts.disconnect = {
                    authorizationReady:
                        CodeWorkflowTransaction
                            .disconnectAuthorizationReady,
                    artifactsReady:
                        CodeWorkflowTransaction.disconnectArtifactsReady,
                    started:
                        CodeWorkflowTransaction
                            .beginDisconnectLifecycle()
                }

                workflowTestSetHistoryIndexQuiet(connectIndex)
                attempts.connect = {
                    authorizationReady:
                        CodeWorkflowTransaction.connectAuthorizationReady,
                    artifactsReady:
                        CodeWorkflowTransaction.connectArtifactsReady,
                    started:
                        CodeWorkflowTransaction.beginConnectLifecycle()
                }

                workflowTestSetHistoryIndexQuiet(literalIndex)
                attempts.literal = {
                    artifactsReady:
                        CodeWorkflowTransaction.applyArtifactsReady,
                    commandMatches:
                        CodeWorkflowTransaction
                            .applyCommandMatchesHandoff,
                    started:
                        CodeWorkflowTransaction.beginApplyLifecycle()
                }

                workflowTestSetHistoryIndexQuiet(bindingIndex)
            }

            const evidence = {
                ownerReady: ownerReady,
                ownerStarted: ownerStarted,
                ownerBusyAfterStart: ownerBusy,
                pendingBindingPhase:
                    CodeWorkflowTransaction.pendingBindingPhase,
                attempts: attempts
            }
            state.mutationContentionJson = JSON.stringify(evidence)
            return ownerStarted
                && ownerBusy
                && attempts.disconnect?.authorizationReady === true
                && attempts.disconnect?.artifactsReady === true
                && attempts.disconnect?.started === false
                && attempts.connect?.authorizationReady === true
                && attempts.connect?.artifactsReady === true
                && attempts.connect?.started === false
                && attempts.literal?.artifactsReady === true
                && attempts.literal?.commandMatches === true
                && attempts.literal?.started === false
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
