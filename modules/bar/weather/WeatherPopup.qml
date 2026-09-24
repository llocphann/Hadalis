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
        availableWidth: root.presentationWindow?.width ?? 1920
        availableHeight: root.presentationWindow?.height ?? 1200
        compact: (root.presentationWindow?.width ?? 1920) < weatherContent.compactBreakpoint
    }
}
