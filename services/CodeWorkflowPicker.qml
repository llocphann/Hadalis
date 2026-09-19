pragma Singleton
import QtQuick
import Quickshell
import qs

Singleton {
    id: root

    property string phase: "idle"
    property string lastReason: ""
    property string pendingSelection: ""
    property var saved: ({})
    property var originalOutputs: []
    property var heldOutputs: []
    property var settingsHosts: ({})
    property int liveOverlays: 0
    property int consumedClicks: 0
    property var lastClick: ({})
    property bool restored: false

    readonly property int runtimeRevision: CodeWorkflowRuntime.revision
    readonly property bool hasLiveTargets: {
        const dependency = root.runtimeRevision
        if (dependency < 0)
            return false
        return CodeWorkflowRuntime.snapshot().records.some(
            record => record.state === "resident")
    }
    readonly property bool settingsPresentationLoaded:
        Object.values(root.settingsHosts).some(host => host.loaded)
    readonly property int settingsPresentationPage: {
        const hosts = Object.values(root.settingsHosts)
        for (const host of hosts)
            if (host.loaded)
                return host.page
        return -1
    }
    readonly property bool canBegin:
        root.phase === "idle"
        && root.settingsPresentationLoaded
        && GlobalStates.settingsOverlayOpen
        && !GlobalStates.screenLocked
        && root.hasLiveTargets

    function reportSettingsHost(hostId: string, loaded: bool, page: int): void {
        const next = Object.assign({}, root.settingsHosts)
        next[hostId] = { loaded: loaded, page: page }
        root.settingsHosts = next
    }

    function removeSettingsHost(hostId: string): void {
        if (!(hostId in root.settingsHosts))
            return
        const next = Object.assign({}, root.settingsHosts)
        delete next[hostId]
        root.settingsHosts = next
    }

    function holdsOutput(outputName: string): bool {
        return (root.phase === "preparing" || root.phase === "picking")
            && root.heldOutputs.includes(outputName)
    }

    function begin(): bool {
        if (!root.canBegin)
            return false

        const snapshot = CodeWorkflowRuntime.snapshot()
        const savedPage = root.settingsPresentationPage >= 0
            ? root.settingsPresentationPage
            : 30

        root.saved = {
            open: GlobalStates.settingsOverlayOpen,
            page: savedPage,
            targetId: CodeWorkflowSession.selectedTargetId,
            instanceId: CodeWorkflowSession.selectedInstanceId,
            outputName: CodeWorkflowSession.outputName,
            panX: CodeWorkflowSession.panX,
            panY: CodeWorkflowSession.panY,
            zoom: CodeWorkflowSession.zoom
        }
        root.originalOutputs = snapshot.outputs.slice()
        root.heldOutputs = snapshot.records.filter(record => {
            if (record.targetId !== "bar"
                    || record.state !== "resident"
                    || !record.rect?.eligible)
                return false
            const screen = Quickshell.screens.find(
                item => item.name === record.output)
            return !!screen
                && record.rect.y + record.rect.height > 0
                && record.rect.y < screen.height
        }).map(record => record.output)

        root.pendingSelection = ""
        root.lastReason = ""
        root.lastClick = ({})
        root.restored = false
        root.phase = "preparing"
        GlobalStates.settingsOverlayOpen = false
        return true
    }

    function finish(reason: string, selection: string): void {
        if (root.phase !== "preparing" && root.phase !== "picking")
            return
        root.pendingSelection = String(selection ?? "")
        root.lastReason = reason
        root.phase = "restoring"
        root.heldOutputs = []
    }

    function recordClick(output: string, x: real, y: real, hit: string): void {
        root.consumedClicks++
        root.lastClick = {
            output: output,
            x: x,
            y: y,
            hit: hit
        }
    }

    function overlayMounted(): void {
        root.liveOverlays++
    }

    function overlayUnmounted(): void {
        root.liveOverlays = Math.max(0, root.liveOverlays - 1)
    }

    function advance(): void {
        if (root.phase === "preparing") {
            if (!root.settingsPresentationLoaded)
                root.phase = "picking"
            return
        }

        if (root.phase !== "restoring" || root.liveOverlays !== 0)
            return

        if (!root.restored) {
            root.restored = true
            CodeWorkflowSession.setViewport(
                Number(root.saved.panX ?? 32),
                Number(root.saved.panY ?? 28),
                Number(root.saved.zoom ?? 1))
            if (root.saved.open && !GlobalStates.screenLocked)
                GlobalStates.openSettingsPage(Number(root.saved.page ?? 30))
        }

        const ready = !root.saved.open
            || GlobalStates.screenLocked
            || (root.settingsPresentationLoaded
                && root.settingsPresentationPage === Number(root.saved.page ?? 30))
        if (!ready)
            return

        if (root.pendingSelection.length > 0) {
            const split = root.pendingSelection.lastIndexOf("@")
            if (split > 0) {
                const targetId = root.pendingSelection.slice(0, split)
                CodeWorkflowSession.selectTarget(
                    targetId, root.pendingSelection)
            }
        }

        root.pendingSelection = ""
        root.originalOutputs = []
        root.heldOutputs = []
        root.saved = ({})
        root.phase = "idle"
    }

    Connections {
        target: GlobalStates
        function onScreenLockedChanged(): void {
            if (GlobalStates.screenLocked)
                root.finish("locked", "")
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            if (root.phase !== "preparing" && root.phase !== "picking")
                return
            const names = Quickshell.screens.map(screen => screen.name)
            if (root.originalOutputs.some(name => !names.includes(name)))
                root.finish("output-removed", "")
        }
    }
}
