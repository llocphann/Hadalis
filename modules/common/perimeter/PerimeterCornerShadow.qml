pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common.widgets

// Radius-aware shadow for the shell's inverse quarter-circle perimeter corners.
//
// Straight Screen Edge/Bar shadows own only their tangent segments. This
// primitive owns the r×r junction and uses the exact same corner orientation as
// RoundCorner, so the shadow follows the curved silhouette instead of turning
// into a perpendicular rectangular strip at a physical screen corner.
GE.RadialGradient {
    id: root

    required property int corner
    property real cornerRadius: 0
    property real shadowExtent: 0
    property color shadowColor: "transparent"

    readonly property bool isTop:
        corner === RoundCorner.CornerEnum.TopLeft
        || corner === RoundCorner.CornerEnum.TopRight
    readonly property bool isLeft:
        corner === RoundCorner.CornerEnum.TopLeft
        || corner === RoundCorner.CornerEnum.BottomLeft
    readonly property real innerStop: Math.max(0, Math.min(1,
        1 - root.shadowExtent / Math.max(1, root.cornerRadius)))

    width: Math.max(0, root.cornerRadius)
    height: Math.max(0, root.cornerRadius)
    horizontalRadius: Math.max(1, root.cornerRadius)
    verticalRadius: Math.max(1, root.cornerRadius)
    horizontalOffset: root.isLeft ? width / 2 : -width / 2
    verticalOffset: root.isTop ? height / 2 : -height / 2
    visible: root.cornerRadius > 0
        && root.shadowExtent > 0
        && root.shadowColor.a > 0
    cached: false

    gradient: Gradient {
        GradientStop { position: 0; color: "transparent" }
        GradientStop { position: root.innerStop; color: "transparent" }
        GradientStop { position: 1; color: root.shadowColor }
    }
}
