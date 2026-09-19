import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.bar
import qs.modules.common
import qs.modules.settings
// WORKFLOW_PROBE_IMPORT: prepare-runtime.py replaces this marker only in the
// isolated exported runtime after creating config/workflowprobe/qmldir.

ShellRoot {
    id: shell
    readonly property int sourceRevision: 1 // Mutated only in the temporary runtime copy.
    property bool initialized: false
    property bool persistenceReady: false
    property int dormantCreations: 0
    property int reloadCompletions: 0
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
    Connections { target: Quickshell; function onReloadCompleted() { shell.reloadCompletions++ } }
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
        function reload(): void { Quickshell.reload(false) }
    }
}
