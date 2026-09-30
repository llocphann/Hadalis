import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Native ownership only. SettingsOverlay retains the single mature content tree.
PanelWindow {
    property var controller: null
    visible: controller?.settingsOpen || controller?._closeAnimRunning || false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:settingsOverlay"
    WlrLayershell.layer: GlobalStates.settingsNativeDialogOpen ? WlrLayer.Bottom
        : PolkitService.active ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: controller?.settingsOpen
        && !GlobalStates.regionSelectorOpen && !GlobalStates.settingsNativeDialogOpen
        && !PolkitService.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
}
