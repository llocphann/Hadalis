import QtQuick
import qs
import qs.services
import qs.modules.common

// No window and no backend: observes the existing shared state, with one
// bounded timeout. The perimeter owns the OSD deformation and its paint.
Item {
    id: root
    readonly property bool configured: Config.ready && (Config.options?.enabledPanels ?? []).includes("abyssOnScreenDisplay")
    property bool initialized: false
    property bool syncing: false
    function hide(): void {
        timeout.stop()
        syncing = true
        GlobalStates.osdVolumeOpen = false
        GlobalStates.osdBrightnessOpen = false
        GlobalStates.osdMicOpen = false
        GlobalStates.osdMediaOpen = false
        GlobalStates.osdKeyboardLayoutOpen = false
        GlobalStates.abyssOsdMessage = ""
        syncing = false
    }
    function show(kind: string, autoHide = true): void {
        if (!configured || !initialized) return
        if (kind === "media" && (!(Config.options?.osd?.mediaEnabled ?? true) || !MprisController.activePlayer)) return
        hide()
        syncing = true
        GlobalStates.abyssOsdKind = kind
        GlobalStates.osdVolumeOpen = kind === "volume" || kind === "voiceSearch"
        GlobalStates.osdBrightnessOpen = kind === "brightness"
        GlobalStates.osdMicOpen = kind === "mic"
        GlobalStates.osdMediaOpen = kind === "media"
        GlobalStates.osdKeyboardLayoutOpen = kind === "keyboardLayout"
        syncing = false
        if (autoHide) timeout.restart()
    }
    Timer { interval: 1500; running: true; onTriggered: root.initialized = true }
    Timer { id: timeout; interval: Math.max(300,Config.options?.osd?.timeout ?? 2000)+(GlobalStates.abyssOsdKind === "media" ? 1000 : 0); onTriggered: root.hide() }
    Connections {
        target: GlobalStates
        function onOsdRequested(kind: string): void { root.show(kind === "current" ? GlobalStates.abyssOsdKind : kind) }
        function onOsdDismissed(): void { root.hide() }
        function onOsdVolumeOpenChanged(): void { if (!root.syncing && GlobalStates.osdVolumeOpen) root.show("volume") }
        function onOsdBrightnessOpenChanged(): void { if (!root.syncing && GlobalStates.osdBrightnessOpen) root.show("brightness") }
        function onOsdMicOpenChanged(): void { if (!root.syncing && GlobalStates.osdMicOpen) root.show("mic") }
        function onOsdMediaOpenChanged(): void { if (!root.syncing && GlobalStates.osdMediaOpen) root.show("media") }
        function onOsdKeyboardLayoutOpenChanged(): void { if (!root.syncing && GlobalStates.osdKeyboardLayoutOpen) root.show("keyboardLayout") }
        function onOsdMediaActionTriggered(action: string): void { if (GlobalStates.osdMediaOpen) root.show("media") }
    }
    Connections { target: Brightness; function onBrightnessChanged(): void { root.show("brightness") } }
    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged(): void { if (Audio.ready && !GameMode.suppressNiriToast) root.show("volume") }
        function onMutedChanged(): void { if (Audio.ready && !GameMode.suppressNiriToast) root.show("volume") }
    }
    Connections {
        target: Audio
        function onMicVolumeChanged(): void { root.show("mic") }
        function onMicMutedChanged(): void { root.show("mic") }
        function onSinkProtectionTriggered(reason: string): void { root.show("volume"); GlobalStates.abyssOsdMessage = reason }
    }
    Connections { target: KeyboardIndicators; function onPopupSequenceChanged(): void { root.show("keyboardLayout") } }
    Connections {
        target: VoiceSearch
        function onRunningChanged(): void {
            if (VoiceSearch.running) root.show("voiceSearch",false)
            else if (GlobalStates.abyssOsdKind === "voiceSearch") timeout.restart()
        }
    }
    Component.onDestruction: hide()
}
