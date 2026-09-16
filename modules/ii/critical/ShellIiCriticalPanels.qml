pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.background
import qs.modules.bar
import qs.modules.dock
import qs.modules.perimeter
import qs.modules.verticalBar
import qs.modules.common

Item {
    id: root

    readonly property bool barVertical: Config.options?.bar?.vertical ?? false
    // Opt-in migration seam. This identifier is intentionally absent from the
    // default ii panel family, so existing users stay on legacy chrome until the
    // Connected Perimeter runtime is explicitly enabled.
    readonly property bool perimeterEnabled:
        (Config.options?.enabledPanels ?? []).includes("iiPerimeter")

    component CriticalPanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
            && extraCondition
    }

    LazyLoader {
        active: Config.ready && root.perimeterEnabled
        component: PerimeterRuntime {}
    }

    CriticalPanelLoader { identifier: "iiBackground"; component: Background {} }
    CriticalPanelLoader { identifier: "iiBar"; extraCondition: !root.perimeterEnabled && !root.barVertical; component: Bar {} }
    CriticalPanelLoader { identifier: "iiVerticalBar"; extraCondition: !root.perimeterEnabled && root.barVertical; component: VerticalBar {} }
    CriticalPanelLoader { identifier: "iiDock"; extraCondition: !root.perimeterEnabled && (Config.options?.dock?.enable ?? true); component: Dock {} }
}
