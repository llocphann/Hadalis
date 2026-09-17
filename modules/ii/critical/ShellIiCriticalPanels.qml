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
