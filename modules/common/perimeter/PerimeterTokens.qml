pragma Singleton
import QtQuick
QtObject {
    readonly property real outerRadius: 22
    readonly property real neckRadius: 14

    // Caelestia's current blob defaults (borderconfig.hpp + tokens.hpp):
    // frame rounding 25, circular smooth-union radius 20, panel radius 28.
    // Keep them separate: using one generic radius for all three is what made
    // Hadalis' joins look swollen compared with the reference implementation.
    readonly property real frameRadius: 25
    readonly property real smoothUnionRadius: 20
    readonly property real popupRadius: 28
    readonly property real joinFlareRadius: smoothUnionRadius
    // Shared popup reveal is a short directional slide from the owning edge.
    readonly property real revealSlideDistance: 18
    readonly property real connectorWidth: 40
    readonly property real connectorLength: 8
    readonly property real seamOverlap: 2
    readonly property real borderWidth: 1
    readonly property real blurExpansion: 24
    readonly property real screenMargin: 4
}
