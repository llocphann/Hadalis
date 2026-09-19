import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.bar
import qs.modules.common
import qs.modules.settings
import qs.workflowprobe

ShellRoot {
    id: shell
    readonly property int sourceRevision: 1 // Mutated only in the temporary runtime copy.
    property bool initialized: false
    property int dormantCreations: 0
    property int reloadCompletions: 0
    property bool mediaEnabled: true

    PersistentProperties {
        id: state
        reloadableId: "workflow-phase0-selection"
        property string selectedInstanceId: ""
        property string selectedTargetId: ""
        property var viewport: ({x:31,y:-17,zoom:1.25,subflow:"bar"})
        property bool mediaEnabled: true
        onLoaded: {
            RuntimeRegistry.selectedInstanceId = selectedInstanceId
            RuntimeRegistry.selectedTargetId = selectedTargetId
            RuntimeRegistry.viewport = viewport
            shell.mediaEnabled = mediaEnabled
            shell.initialize()
        }
    }
    Connections {
        target: RuntimeRegistry
        function onSelectedInstanceIdChanged() { state.selectedInstanceId = RuntimeRegistry.selectedInstanceId }
        function onSelectedTargetIdChanged() { state.selectedTargetId = RuntimeRegistry.selectedTargetId }
        function onViewportChanged() { state.viewport = RuntimeRegistry.viewport }
    }
    function initialize() {
        if (initialized || !Config.ready) return
        initialized = true
        Config.blockWrites = true
        Config.options.bar.modules.media = mediaEnabled
        GlobalStates.shellEntryReady = true
        GlobalStates.bootGreetingDone = true
        GlobalStates.barOpen = true
    }
    Connections { target: Config; function onReadyChanged() { shell.initialize() } }
    Connections { target: Quickshell; function onReloadCompleted() { shell.reloadCompletions++ } }
    Bar {}
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
            return JSON.stringify(report)
        }
        function select(instanceId: string): bool { return RuntimeRegistry.select(instanceId) }
        function media(enabled: bool): void {
            shell.mediaEnabled = enabled
            state.mediaEnabled = enabled
            Config.options.bar.modules.media = enabled
        }
        function bar(enabled: bool): void { GlobalStates.barOpen = enabled }
        function bottom(enabled: bool): void { Config.options.bar.bottom = enabled }
        function hold(enabled: bool): void { RuntimeRegistry.pickHold = enabled }
        function lock(enabled: bool): void { GlobalStates.screenLocked = enabled }
        function reload(): void { Quickshell.reload(false) }
    }
}
