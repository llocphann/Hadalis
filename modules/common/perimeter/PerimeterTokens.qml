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

    // iRiS StyledPopup contact geometry is an exact SDF smooth union validated
    // by the real G1/G2 matrices. Keep its fuse depth independent of the legacy
    // Canvas flare tokens still consumed by Waffle/non-StyledPopup surfaces.
    readonly property real irisFuseDepth: 30
    // G2 upstream-relative morphology overlaps every joined owner by 3 logical
    // px for SDF continuity, while Overlay paint/input still starts at the
    // actual owner boundary.
    readonly property real irisWeldDepth: 3

    // CONNECTED-SURFACE-OUTWARD-FLARE-LOCK (legacy shared consumers only):
    // Sidebar/Dashboard/OSK/Waffle surfaces that have not cut over to iRiS keep
    // the prior outward shoulder contract. ii StyledPopup must not use it.
    readonly property real popupRadius: 28
    readonly property real joinFlareRadius: frameRadius
    readonly property real joinFlareCrossScale: 0.55

    readonly property real revealSlideDistance: 18
    readonly property real connectorWidth: 40
    readonly property real connectorLength: 8
    readonly property real seamOverlap: 2
    readonly property real borderWidth: 1
    readonly property real blurExpansion: 24
    readonly property real screenMargin: 4
}
