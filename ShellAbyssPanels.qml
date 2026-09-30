import QtQuick
import Quickshell
import qs
import qs.modules.common

Item {
    LazyLoader {
        loading: GlobalStates.deferredPanelsReady
        activeAsync: GlobalStates.deferredPanelsReady
        source: "modules/abyss/ShellAbyssPanelsImpl.qml"
    }
}
