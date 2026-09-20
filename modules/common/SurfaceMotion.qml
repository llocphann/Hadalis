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
    readonly property real dashboardOffset: 24
}
