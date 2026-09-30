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

    }
}
