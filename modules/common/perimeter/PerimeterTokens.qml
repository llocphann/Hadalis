pragma Singleton
import QtQuick
import qs.modules.common

QtObject {
    readonly property real outerRadius: 22
    readonly property real neckRadius: 14

    // BAR-SCREEN-EDGE-CORNER-LOCK: this is the only user-adjustable
    // corner parameter for the physical Screen Edge + normal ii Bar perimeter.
    // The default remains Caelestia border.rounding=25. Do not create a second
    // Bar endpoint radius or orientation-specific corner token.
    readonly property real frameRadius: {
        const revision = Config.revision
        return Math.max(0, Math.min(96,
            Number(Config.options?.appearance?.screenEdge?.radius ?? 25)))
    }

    // Base iRiS smooth-union radius for non-popup connected surfaces.
    // StyledPopup has a separately user-adjustable radius below so changing a
    // Bar popup does not reshape Sidebar/Dashboard/Dock contact geometry.
    readonly property real irisFuseDepth: 30

    readonly property real popupFuseDepth: {
        const revision = Config.revision
        return Math.max(0, Math.min(64,
            Number(Config.options?.appearance?.screenEdge?.popupConnectionRadius ?? 30)))
    }
    // G2 upstream-relative morphology overlaps every joined owner by 3 logical
    // px for SDF continuity, while Overlay paint/input still starts at the
    // actual owner boundary.
    readonly property real irisWeldDepth: 3

    // Free-corner radius used by connected popup body geometry.
    readonly property real popupRadius: 28

    readonly property real revealSlideDistance: 18
    readonly property real connectorWidth: 40
    readonly property real connectorLength: 8
    readonly property real seamOverlap: 2
    readonly property real borderWidth: 1
    readonly property real blurExpansion: 24
    readonly property real screenMargin: 4
}
