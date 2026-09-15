pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.background
import qs.modules.bar
import qs.modules.dock
import qs.modules.verticalBar
import qs.modules.common

Item {
    id: root

    readonly property bool barVertical: Config.options?.bar?.vertical ?? false

    component CriticalPanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
            && extraCondition
    }

    CriticalPanelLoader { identifier: "iiBackground"; component: Background {} }
    CriticalPanelLoader { identifier: "iiBar"; extraCondition: !root.barVertical; component: Bar {} }
    CriticalPanelLoader { identifier: "iiVerticalBar"; extraCondition: root.barVertical; component: VerticalBar {} }
    CriticalPanelLoader { identifier: "iiDock"; extraCondition: Config.options?.dock?.enable ?? true; component: Dock {} }
}
