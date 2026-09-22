pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.waffle.background as WaffleBackgroundModule
import qs.modules.waffle.bar as WaffleBarModule
import qs.modules.waffle.backdrop as WaffleBackdropModule

Item {
    id: root

    component CriticalPanelLoader: LazyLoader {
        id: criticalPanelLoader
        required property string identifier
        property bool extraCondition: true
        property string workflowSourcePath: ""
        readonly property bool enabledPanel: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
            && extraCondition
        active: enabledPanel
        property CodeWorkflowRuntimeDeclaration workflowDeclaration:
            CodeWorkflowRuntimeDeclaration {
                loader: criticalPanelLoader
                panelId: criticalPanelLoader.identifier
                sourcePath: criticalPanelLoader.workflowSourcePath
                configured: criticalPanelLoader.enabledPanel
                presented: criticalPanelLoader.active
            }
    }

    CriticalPanelLoader {
        identifier: "wBar"
        workflowSourcePath: "modules/waffle/bar/WaffleBar.qml"
        component: WaffleBarModule.WaffleBar {}
    }

    CriticalPanelLoader {
        identifier: "wBackground"
        workflowSourcePath: "modules/waffle/background/WaffleBackground.qml"
        component: WaffleBackgroundModule.WaffleBackground {}
    }

    CriticalPanelLoader {
        identifier: "wBackdrop"
        extraCondition: Config.options?.waffles?.background?.backdrop?.enable ?? true
        workflowSourcePath: "modules/waffle/backdrop/WaffleBackdrop.qml"
        component: WaffleBackdropModule.WaffleBackdrop {}
    }
}
