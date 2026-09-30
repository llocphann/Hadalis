pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    // SURFACE-MOTION-IMMUTABLE-LOCK
    // Top-level ii shell surfaces are slide-only. These values deliberately do
    // not depend on theme, motion profile, user curve overrides or panel config.
    // Consumers may only gate animation globally via Appearance.animationsEnabled.
    readonly property string mode: "slide"
    readonly property int duration: 300
    readonly property int easingType: Easing.InOutCubic

    // The standalone Dashboard is a large retained surface. Give its entrance
    // a longer deceleration and its exit a shorter acceleration so the motion
    // reads as one continuous glide instead of an InOutCubic midpoint surge.
    // Presentation remains translation-only: no opacity, scale or spring path.
    readonly property int dashboardEnterDuration: 360
    readonly property int dashboardExitDuration: 260
    readonly property int dashboardEnterEasingType: Easing.OutCubic
    readonly property int dashboardExitEasingType: Easing.InCubic
    readonly property real dashboardOffset: 32
}
