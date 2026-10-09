import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

// URL boundaries keep optional presentation errors out of the family entry.
Item {
    id: root

    readonly property bool abyssBackgroundEnabled:
        Config.ready && (Config.options?.enabledPanels ?? []).includes("abyssBackground")

    // Production-host lifecycle experiment: recreate Perimeter but leave
    // the shell, config and current panelFamily unchanged. Unlike toggling
    // PanelWindow.visible, setting LazyLoader.active=false destroys its QML
    // subtree and the native Wayland window owned by that subtree.
    property bool diagnosticPerimeterUnmounted: false
    Timer {
        id: perimeterProbeRestore
        interval: 450
        repeat: false
        onTriggered: root.diagnosticPerimeterUnmounted = false
    }
    IpcHandler {
        target: "abyssHostProbe"
        function status(): string {
            return JSON.stringify({
                family: Config.options?.panelFamily ?? "",
                perimeterLoaded: perimeterLoader.item !== null,
                perimeterActive: perimeterLoader.active,
                diagnosticUnmounted: root.diagnosticPerimeterUnmounted,
                shellEntryReady: GlobalStates.shellEntryReady,
                deferredPanelsReady: GlobalStates.deferredPanelsReady
            })
        }
        function remountPerimeter(): string {
            if ((Config.options?.panelFamily ?? "") !== "abyss"
                    || GlobalStates.abyssEditing || GlobalStates.screenLocked
                    || root.diagnosticPerimeterUnmounted)
                return JSON.stringify({skipped:true, reason:"not safe during current state"})
            root.diagnosticPerimeterUnmounted = true
            perimeterProbeRestore.restart()
            return JSON.stringify({
                skipped:false, experiment:"destroy-recreate-AbyssPerimeter",
                restoreAfterMs:450, familyChanged:false
            })
        }
    }

    LazyLoader {
        id: perimeterLoader
        active: Config.ready
            && (Config.options?.enabledPanels ?? []).includes("abyssPerimeter")
            && !root.diagnosticPerimeterUnmounted
        source: "../AbyssPerimeter.qml"
    }
    LazyLoader {
        active: root.abyssBackgroundEnabled
        source: "../../background/Background.qml"
    }

    // Stable Material kept a dedicated Background-layer wallpaper surface inside
    // Niri's overview backdrop. Abyss folds iiBackground/iiBackdrop into one public
    // background module, so retain that renderer under the same module gate instead
    // of losing wallpaper when Niri zooms the workspace from a hot corner.
    LazyLoader {
        active: root.abyssBackgroundEnabled
            && (Config.options?.background?.backdrop?.enable ?? false)
        source: "../../background/Backdrop.qml"
    }
}
