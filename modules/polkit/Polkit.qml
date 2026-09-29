import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    // Preserve the legacy all-output renderer for non-Abyss families. Under
    // Abyss this component is only the security fail-safe for a missing
    // connected host, so keep that fallback on the AuthFlow's target output
    // instead of duplicating the same password prompt across every monitor.
    readonly property var presentationScreens: {
        const screens = Quickshell.screens ?? []
        if (Config.options?.panelFamily !== "abyss")
            return screens
        const target = String(PolkitService.targetOutputName ?? "")
        if (!target)
            return screens
        const matched = screens.filter(screen =>
            String(screen?.name ?? "") === target)
        return matched.length > 0 ? matched : screens
    }
    
    Loader {
        // Abyss presents the real AuthFlow through its connected popup field.
        // If the perimeter is disabled, retain the existing renderer instead of
        // owning a Polkit request with no visible authentication surface.
        active: PolkitService.available && PolkitService.active
            && !PolkitService.abyssPresentationSuppressed
            && !PolkitService.abyssPresenterAvailable
        sourceComponent: Variants {
            model: root.presentationScreens
            delegate: PanelWindow {
                id: panelWindow
                required property var modelData
                screen: modelData
                
                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                color: "transparent"
                WlrLayershell.namespace: "quickshell:polkit"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                WlrLayershell.layer: WlrLayer.Overlay
                exclusionMode: ExclusionMode.Ignore

                PolkitContent {
                    anchors.fill: parent
                }
            }
        }
    }
}
