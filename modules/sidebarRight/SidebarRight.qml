pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.perimeter
import qs.modules.sidebar
import Quickshell

Scope {
    id: root

    readonly property bool perimeterEnabled: PerimeterCutoverPolicy.enabled
    readonly property var targetScreens: {
        const list = Config.options?.sidebar?.screenList ?? []
        const screens = Quickshell.screens
        if (!list || list.length === 0)
            return screens
        const matched = screens.filter(screen => {
            const screenName = screen?.name ?? ""
            return screenName.length > 0 && list.includes(screenName)
        })
        return matched.length > 0 ? matched : screens
    }

    Variants {
        model: root.perimeterEnabled ? [] : root.targetScreens

        SidebarHost {
            required property var modelData
            edge: "right"
            screen: modelData
        }
    }
}
