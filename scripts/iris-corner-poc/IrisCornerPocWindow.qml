pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var modelData

    function envReal(name, fallback) {
        const value = Number(Quickshell.env(name))
        return Number.isFinite(value) ? value : fallback
    }

    readonly property string edgeName: {
        const value = String(Quickshell.env("HADALIS_IRIS_POC_EDGE") || "top").toLowerCase()
        return ["top", "bottom", "left", "right"].includes(value) ? value : "top"
    }
    readonly property string geometryMode: {
        const value = String(Quickshell.env("HADALIS_IRIS_POC_MODE") || "card-owner").toLowerCase()
        return value === "edge-reach" ? value : "card-owner"
    }
    readonly property bool horizontal: root.edgeName === "top" || root.edgeName === "bottom"
    readonly property real sourceT:
        Math.max(0, Math.min(1, root.envReal("HADALIS_IRIS_POC_SOURCE_T", 0.5)))
    readonly property real ownerThickness:
        Math.max(16, root.envReal("HADALIS_IRIS_POC_OWNER_THICKNESS", 56))
    readonly property real popupWidth:
        Math.max(120, root.envReal("HADALIS_IRIS_POC_POPUP_WIDTH", 380))
    readonly property real popupHeight:
        Math.max(120, root.envReal("HADALIS_IRIS_POC_POPUP_HEIGHT", 300))
    readonly property real popupRadius:
        Math.max(0, root.envReal("HADALIS_IRIS_POC_POPUP_RADIUS", 48))
    readonly property real weld:
        Math.max(0, root.envReal("HADALIS_IRIS_POC_WELD", 4))
    readonly property real fuse:
        Math.max(0, root.envReal("HADALIS_IRIS_POC_FUSE", 56))
    readonly property bool showGuides:
        String(Quickshell.env("HADALIS_IRIS_POC_GUIDES") || "1") !== "0"

    readonly property real semanticX: {
        if (root.edgeName === "left")
            return root.ownerThickness - root.weld
        if (root.edgeName === "right")
            return root.width - root.ownerThickness - root.popupWidth + root.weld
        const raw = root.sourceT * root.width - root.popupWidth / 2
        return Math.max(8, Math.min(root.width - root.popupWidth - 8, raw))
    }
    readonly property real semanticY: {
        if (root.edgeName === "top")
            return root.ownerThickness - root.weld
        if (root.edgeName === "bottom")
            return root.height - root.ownerThickness - root.popupHeight + root.weld
        const raw = root.sourceT * root.height - root.popupHeight / 2
        return Math.max(8, Math.min(root.height - root.popupHeight - 8, raw))
    }
    readonly property rect semanticPopup:
        Qt.rect(root.semanticX, root.semanticY, root.popupWidth, root.popupHeight)

    // iRiS Stage edge pieces grow only their field shape into the owner. Cards
    // such as Control Center instead use a small negative placement gap (weld).
    readonly property real edgeReach:
        Math.min(root.popupWidth, root.popupHeight) / 2 + 1
    readonly property rect fieldPopup: {
        let x = root.semanticPopup.x
        let y = root.semanticPopup.y
        let w = root.semanticPopup.width
        let h = root.semanticPopup.height
        if (root.geometryMode !== "edge-reach")
            return Qt.rect(x, y, w, h)
        if (root.edgeName === "top") {
            y -= root.edgeReach
            h += root.edgeReach
        } else if (root.edgeName === "bottom") {
            h += root.edgeReach
        } else if (root.edgeName === "left") {
            x -= root.edgeReach
            w += root.edgeReach
        } else {
            w += root.edgeReach
        }
        return Qt.rect(x, y, w, h)
    }

    readonly property var ownerShape: {
        const pad = root.fuse * 2
        if (root.edgeName === "top")
            return { x: -pad, y: 0, width: root.width + 2 * pad,
                height: root.ownerThickness, radius: 0, fuse: 0, id: "owner" }
        if (root.edgeName === "bottom")
            return { x: -pad, y: root.height - root.ownerThickness,
                width: root.width + 2 * pad, height: root.ownerThickness,
                radius: 0, fuse: 0, id: "owner" }
        if (root.edgeName === "left")
            return { x: 0, y: -pad, width: root.ownerThickness,
                height: root.height + 2 * pad, radius: 0, fuse: 0, id: "owner" }
        return { x: root.width - root.ownerThickness, y: -pad,
            width: root.ownerThickness, height: root.height + 2 * pad,
            radius: 0, fuse: 0, id: "owner" }
    }

    readonly property var popupShape: ({
        x: root.fieldPopup.x,
        y: root.fieldPopup.y,
        width: root.fieldPopup.width,
        height: root.fieldPopup.height,
        radius: root.popupRadius,
        fuse: root.fuse,
        id: "popup",
        joins: "owner"
    })

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

    WlrLayershell.namespace: "hadalis:iris-corner-poc"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
        id: emptyInput
        width: 0
        height: 0
        visible: false
    }
    mask: Region { item: emptyInput }

    IrisCornerField {
        anchors.fill: parent
        shapes: [root.ownerShape, root.popupShape]
        tint: "#f4c542"
        smoothing: root.fuse
    }

    // Diagnostic guides are not part of the field. They show the semantic
    // popup rect so hidden field overlap cannot be mistaken for content motion.
    Rectangle {
        visible: root.showGuides
        x: root.semanticPopup.x
        y: root.semanticPopup.y
        width: root.semanticPopup.width
        height: root.semanticPopup.height
        color: "transparent"
        border.width: 2
        border.color: "#57d3ff"
        radius: root.popupRadius
        z: 10
    }

    Rectangle {
        visible: root.showGuides
        color: "#ff4fd8"
        z: 11
        x: root.edgeName === "right" ? root.width - root.ownerThickness
            : root.edgeName === "left" ? root.ownerThickness - 1 : 0
        y: root.edgeName === "bottom" ? root.height - root.ownerThickness
            : root.edgeName === "top" ? root.ownerThickness - 1 : 0
        width: root.horizontal ? root.width : 1
        height: root.horizontal ? 1 : root.height
    }

    Text {
        visible: root.showGuides
        z: 12
        x: 18
        y: root.edgeName === "top" ? root.ownerThickness + 16 : 18
        color: "white"
        font.pixelSize: 16
        text: "iRiS v2.31 field · " + root.geometryMode
            + " · " + root.edgeName
            + " · fuse " + Math.round(root.fuse)
            + " · weld " + Math.round(root.weld)
    }

    Component.onCompleted: console.info(
        "HADALIS_IRIS_POC",
        JSON.stringify({
            output: root.screen?.name ?? "",
            mode: root.geometryMode,
            edge: root.edgeName,
            semanticPopup: root.semanticPopup,
            fieldPopup: root.fieldPopup,
            owner: root.ownerShape,
            popup: root.popupShape,
            reach: root.edgeReach
        })
    )
}
