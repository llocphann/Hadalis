pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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

    // Screen edge is shell chrome, not a replacement runtime. Keep it on a URL
    // boundary so a presentation regression cannot make the critical root fail.
    LazyLoader {
        active: Config.ready
        source: Qt.resolvedUrl("../../screenCorners/ScreenEdges.qml")
    }

    // Sidebar edge bridges live inside SidebarHost so connector and card share
    // one native surface/output/lifecycle instead of compositor-stitching two
    // independent PanelWindows.
    CriticalPanelLoader {
        identifier: "iiBackground"
        source: Qt.resolvedUrl("../../background/Background.qml")
    }
    CriticalPanelLoader {
        identifier: "iiBar"
        extraCondition: !root.barVertical
        source: Qt.resolvedUrl("../../bar/Bar.qml")
    }
    CriticalPanelLoader {
        identifier: "iiVerticalBar"
        extraCondition: root.barVertical
        source: Qt.resolvedUrl("../../verticalBar/VerticalBar.qml")
    }
    CriticalPanelLoader {
        identifier: "iiDock"
        extraCondition: Config.options?.dock?.enable ?? true
        source: Qt.resolvedUrl("../../dock/Dock.qml")
    }
}
