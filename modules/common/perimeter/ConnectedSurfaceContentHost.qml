import QtQuick

// Shared content host for connected surfaces. Consumers own body sizing and
// content; this item owns the padded placement inside the live morph geometry so
// render, input and content never drift onto separate coordinate calculations.
Item {
    id: root

    required property var geometry
    property real padding: 0

    readonly property real effectivePadding: Math.max(0, root.padding)
    readonly property rect surfaceRect: root.geometry.animatedBodyRect

    x: root.surfaceRect.x + root.effectivePadding
    y: root.surfaceRect.y + root.effectivePadding
    width: Math.max(0,
        root.surfaceRect.width - root.effectivePadding * 2)
    height: Math.max(0,
        root.surfaceRect.height - root.effectivePadding * 2)
    visible: root.geometry.valid && root.geometry.progress > 0
    clip: true
}
