import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

Scope {
    id: picker
    required property var settings
    property string phase: "idle"
    property string lastReason: ""
    property string pendingSelection: ""
    property var saved: ({})
    property var originalOutputs: []
    property int liveOverlays: 0
    property int consumedClicks: 0
    property var lastClick: ({})
    property bool restored: false

    function begin() {
        if (phase !== "idle" || GlobalStates.screenLocked) return false
        const s = RuntimeRegistry.snapshot()
        saved = {open:GlobalStates.settingsOverlayOpen,
            page:settings.overlayCurrentPage,
            viewport:JSON.parse(JSON.stringify(RuntimeRegistry.viewport)),
            selected:RuntimeRegistry.selectedInstanceId}
        originalOutputs = s.outputs.slice()
        // Hold only a Bar that is already resident and on screen.
        RuntimeRegistry.heldOutputs = s.records.filter(r => r.targetId === "bar"
            && r.state === "resident" && r.rect?.eligible && r.rect.y + r.rect.height > 0
            && r.rect.y < (Quickshell.screens.find(s => s.name === r.output)?.height ?? 0))
            .map(r => r.output)
        RuntimeRegistry.pickHold = true
        restored = false
        pendingSelection = ""
        lastReason = ""
        phase = "preparing"
        GlobalStates.settingsOverlayOpen = false
        return true
    }
    function finish(reason, selection) {
        if (phase !== "picking" && phase !== "preparing") return
        pendingSelection = selection || ""
        lastReason = reason
        phase = "restoring"
        // The full click has been consumed before any input surface is removed.
        RuntimeRegistry.pickHold = false
        RuntimeRegistry.heldOutputs = []
    }
    Timer {
        interval: 16
        repeat: true
        running: picker.phase === "preparing" || picker.phase === "restoring"
        onTriggered: {
            if (picker.phase === "preparing" && !picker.settings._panelLoaded) {
                picker.phase = "picking"
            } else if (picker.phase === "restoring" && picker.liveOverlays === 0) {
                if (!picker.restored) {
                    picker.restored = true
                    RuntimeRegistry.viewport = picker.saved.viewport
                    if (picker.saved.open && !GlobalStates.screenLocked)
                        GlobalStates.openSettingsPage(picker.saved.page)
                }
                const ready = !picker.saved.open || GlobalStates.screenLocked
                    || (picker.settings._panelLoaded
                        && picker.settings.overlayCurrentPage === picker.saved.page)
                if (ready) {
                    if (picker.pendingSelection) RuntimeRegistry.select(picker.pendingSelection)
                    picker.phase = "idle"
                }
            }
        }
    }
    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) picker.finish("locked", "")
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() {
            const names = Quickshell.screens.map(s => s.name)
            if (picker.originalOutputs.some(name => !names.includes(name)))
                picker.finish("output-removed", "")
        }
    }
    Variants {
        model: picker.phase === "picking" ? Quickshell.screens : []
        PanelWindow {
            id: overlay
            required property ShellScreen modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell:code-workflow-picker"
            property string hovered: ""
            Component.onCompleted: picker.liveOverlays++
            Component.onDestruction: picker.liveOverlays--
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPositionChanged: event => {
                    overlay.hovered = RuntimeRegistry.hit(overlay.modelData.name, event.x, event.y)
                }
                onClicked: event => {
                    event.accepted = true
                    picker.consumedClicks++
                    picker.lastClick = {x:event.x,y:event.y,output:overlay.modelData.name,
                        hit:RuntimeRegistry.hit(overlay.modelData.name,event.x,event.y)}
                    if (event.button === Qt.RightButton) picker.finish("cancelled", "")
                    else {
                        const target = RuntimeRegistry.hit(overlay.modelData.name, event.x, event.y)
                        if (target) picker.finish("selected", target)
                    }
                }
            }
            Rectangle {
                readonly property var target: RuntimeRegistry.entries[overlay.hovered]
                readonly property rect bounds: target?.geometry ?? Qt.rect(0,0,0,0)
                x: bounds.x; y: bounds.y; width: bounds.width; height: bounds.height
                visible: overlay.hovered.length > 0
                color: "transparent"
                border.color: "cyan"
                border.width: 2
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 80
                text: "Phase 0 picker · right-click to cancel"
                color: "white"
                Accessible.name: text
            }
        }
    }
}
