import QtQuick
import qs.modules.bar

StyledPopup {
    id: root

    WeatherPopupContent {
        id: weatherContent
        anchors.centerIn: parent
        // The presentation window spans the owning output. Responsive sizing
        // stays on the active StyledPopup path instead of a retired perimeter
        // weather surface.
        compact: (root.presentationWindow?.width ?? 1920) < weatherContent.compactBreakpoint
        // root.active includes the retract linger, so close motion finishes
        // before the resident weather content goes fully idle.
        presentationActive: root.active
    }
}
