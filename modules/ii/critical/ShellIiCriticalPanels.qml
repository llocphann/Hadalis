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
    // Cut over only when the user requested perimeter and every connected
    // output validates. Invalid/corrupt perimeter state therefore falls back to
    // the legacy chrome instead of leaving the shell without persistent UI.
    readonly property bool perimeterEnabled: PerimeterRuntimePolicy.enabled

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
