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

    }
}
