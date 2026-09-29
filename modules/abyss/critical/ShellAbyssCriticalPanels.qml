import QtQuick
import Quickshell
import qs.modules.common

// URL boundaries keep optional presentation errors out of the family entry.
Item {
    id: root

    readonly property bool abyssBackgroundEnabled:
        Config.ready && (Config.options?.enabledPanels ?? []).includes("abyssBackground")

    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("abyssPerimeter")
        source: "../AbyssPerimeter.qml"
    }

    // Authentication is security-critical and cannot depend on the deferred
    // abyssPolkit presentation toggle. Keep the legacy real-AuthFlow renderer
    // available here as the fail-safe when the connected perimeter is disabled.
    // Its own Loader remains dormant while AbyssPerimeter owns presentation.
    LazyLoader {
        active: Config.ready && (Config.options?.modules?.polkit ?? true)
        source: "../../polkit/Polkit.qml"
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
