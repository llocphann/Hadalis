import QtQuick
import Quickshell
import qs
import qs.services

Item {
    LazyLoader {
        id: wafflePanelsImplLoader
        loading: GlobalStates.deferredPanelsReady
        activeAsync: GlobalStates.deferredPanelsReady
        source: "modules/waffle/ShellWafflePanelsImpl.qml"

        property CodeWorkflowRuntimeDeclaration workflowDeclaration:
            CodeWorkflowRuntimeDeclaration {
                loader: wafflePanelsImplLoader
                panelId: "runtimeWafflePanelsImpl"
                targetId: "runtime/waffle-panels-impl"
                label: "Waffle Panels Impl"
                family: "waffle"
                sourcePath: "modules/waffle/ShellWafflePanelsImpl.qml"
                internal: true
                configured: GlobalStates.deferredPanelsReady
                presented: wafflePanelsImplLoader.active
            }
    }
}
