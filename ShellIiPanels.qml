import QtQuick
import Quickshell
import qs
import qs.services

Item {
    LazyLoader {
        id: iiPanelsImplLoader
        loading: GlobalStates.deferredPanelsReady
        activeAsync: GlobalStates.deferredPanelsReady
        source: "modules/ii/ShellIiPanelsImpl.qml"

        property CodeWorkflowRuntimeDeclaration workflowDeclaration:
            CodeWorkflowRuntimeDeclaration {
                loader: iiPanelsImplLoader
                panelId: "runtimeIiPanelsImpl"
                targetId: "runtime/ii-panels-impl"
                label: "ii Panels Impl"
                family: "ii"
                sourcePath: "modules/ii/ShellIiPanelsImpl.qml"
                internal: true
                configured: GlobalStates.deferredPanelsReady
                presented: iiPanelsImplLoader.active
            }
    }
}
