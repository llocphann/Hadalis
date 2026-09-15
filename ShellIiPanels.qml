import QtQuick
import Quickshell
import qs
import qs.modules.perimeter

Item {
    id: root

    property bool perimeterFeaturesReady: false

    Component.onCompleted: {
        root.perimeterFeaturesReady = PerimeterFeatureRegistry.registerAll()
        if (!root.perimeterFeaturesReady)
            console.warn("[Perimeter] Failed to register feature module sources")
    }

    LazyLoader {
        loading: root.perimeterFeaturesReady && GlobalStates.deferredPanelsReady
        activeAsync: root.perimeterFeaturesReady && GlobalStates.deferredPanelsReady
        source: "modules/ii/ShellIiPanelsImpl.qml"
    }
}
