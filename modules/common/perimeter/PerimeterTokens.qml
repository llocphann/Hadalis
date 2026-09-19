pragma Singleton
import QtQuick
import qs.modules.common

QtObject {
    // One radius owner for the physical Screen Edge and every connected-surface
    // contact corner. The default matches Caelestia border.rounding=25.
    readonly property real frameRadius: {
        const revision = Config.revision
        return Math.max(0, Math.min(96,
            Number(Config.options?.appearance?.screenEdge?.radius ?? 25)))
    }

    readonly property real outerRadius: 22
    readonly property real neckRadius: 14

    // Caelestia's blob defaults keep panel rounding and smooth-union strength
    // separate from border rounding. Hadalis cannot share one SDF group across
    // independent layer-shell windows, so direct Screen Edge contacts reuse the
    // exact physical frame radius/quarter-circle instead of approximating the
    // SDF union with an ellipse.
    readonly property real smoothUnionRadius: 20
    readonly property real popupRadius: 28
    readonly property real joinFlareRadius: frameRadius

    // Shared popup reveal is a short directional slide from the owning edge.
    readonly property real revealSlideDistance: 18
    readonly property real connectorWidth: 40
    readonly property real connectorLength: 8
    readonly property real seamOverlap: 2
    readonly property real borderWidth: 1
    readonly property real blurExpansion: 24
    readonly property real screenMargin: 4
}
