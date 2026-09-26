import QtQuick
import Quickshell
import qs.modules.common

// URL boundaries keep optional presentation errors out of the family entry.
Item {
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("abyssPerimeter")
        source: "../AbyssPerimeter.qml"
    }
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("abyssBackground")
        source: "../../background/Background.qml"
    }
}
