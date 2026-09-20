pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property ShellScreen modelData

    function envReal(name, fallback) {
        const parsed = Number(Quickshell.env(name))
        return Number.isFinite(parsed) ? parsed : fallback
    }

    readonly property string edge: {
        const candidate = (Quickshell.env("HADALIS_U1_EDGE") || "top").toLowerCase()
        return ["top", "bottom", "left", "right"].includes(candidate) ? candidate : "top"
    }
    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property real edgeThickness: Math.max(1, envReal("HADALIS_U1_EDGE_THICKNESS", 10))
    readonly property real ownerThickness: Math.max(
        edgeThickness,
        envReal("HADALIS_U1_OWNER_THICKNESS", horizontal ? 40 : 46)
    )
    readonly property real sourceT: Math.max(0, Math.min(1,
        envReal("HADALIS_U1_SOURCE_T", 0.5)))
    readonly property real markerExtent: 120

    screen: modelData
    visible: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "hadalis:u1-owner-probe"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
        id: emptyInput
        width: 0
        height: 0
        visible: false
    }
    mask: Region { item: emptyInput }

    Rectangle {
        id: marker
        color: "#00ff00"

        x: root.horizontal
            ? Math.max(0, Math.min(root.width - width,
                root.width * root.sourceT - width / 2))
            : (root.edge === "left" ? 0 : root.width - width)
        y: root.horizontal
            ? (root.edge === "top" ? 0 : root.height - height)
            : Math.max(0, Math.min(root.height - height,
                root.height * root.sourceT - height / 2))

        width: root.horizontal ? Math.min(root.markerExtent, root.width)
            : Math.min(root.ownerThickness, root.width)
        height: root.horizontal ? Math.min(root.ownerThickness, root.height)
            : Math.min(root.markerExtent, root.height)
    }
}
