pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.perimeter
import qs.services
import QtQuick
import Quickshell
import Quickshell.Wayland

// Visual-only bridges between the persistent Screen Edge and the two semantic
// sidebars. They deliberately do not depend on Bar position: feature sidebar
// always grows from the left edge; system sidebar always grows from the right.
Scope {
    id: root

    readonly property real bridgeLength: Math.max(1,
        Appearance.sizes.hyprlandGapsOut + PerimeterTokens.seamOverlap)
    readonly property real bridgeExtent: Math.max(
        PerimeterTokens.connectorWidth,
        PerimeterTokens.connectorWidth + PerimeterTokens.outerRadius * 2)

    component BridgeWindow: PanelWindow {
        id: bridgeWindow

        required property ShellScreen modelData
        required property string edge

        readonly property bool isLeftEdge: edge === "left"
        readonly property string outputName: String(modelData?.name ?? "")
        readonly property string panelId: isLeftEdge ? "iiSidebarLeft" : "iiSidebarRight"
        readonly property bool panelEnabled:
            (Config.options?.enabledPanels ?? []).includes(panelId)
        readonly property bool roleOpen: panelEnabled
            && (isLeftEdge ? GlobalStates.sidebarLeftOpen : GlobalStates.sidebarRightOpen)
            && (isLeftEdge
                ? GlobalStates.sidebarLeftPresentationOutput
                : GlobalStates.sidebarRightPresentationOutput) === outputName
        readonly property bool fullscreenCovered: outputName.length > 0
            && GameMode.hasFullscreenOnOutput(outputName)
        readonly property bool mapped: Config.ready
            && roleOpen
            && !GlobalStates.screenLocked
            && !fullscreenCovered

        screen: modelData
        visible: mapped
        updatesEnabled: mapped
        color: "transparent"
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: root.bridgeLength
        implicitHeight: root.bridgeExtent

        WlrLayershell.namespace: isLeftEdge
            ? "hadalis:sidebar-edge-left" : "hadalis:sidebar-edge-right"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            left: bridgeWindow.isLeftEdge
            right: !bridgeWindow.isLeftEdge
        }

        Item {
            id: emptyInput
            width: 0
            height: 0
            visible: false
        }
        mask: Region { item: emptyInput }

        QtObject {
            id: bridgeGeometry
            readonly property string edge: bridgeWindow.edge
            readonly property rect connectorRect: Qt.rect(
                0, 0, bridgeWindow.width, bridgeWindow.height)
            readonly property real connectorSourceExtent: PerimeterTokens.connectorWidth
            readonly property real connectorWidth: PerimeterTokens.connectorWidth
            readonly property real borderWidth: 0
            readonly property bool valid: bridgeWindow.mapped
            readonly property real progress: bridgeWindow.mapped ? 1 : 0
        }

        ConnectedSurfaceConnector {
            geometry: bridgeGeometry
            fillColor: Appearance.colors.colLayer1
            strokeColor: "transparent"
            strokeWidth: 0
        }
    }

    Variants {
        model: Quickshell.screens
        BridgeWindow { edge: "left" }
    }

    Variants {
        model: Quickshell.screens
        BridgeWindow { edge: "right" }
    }
}
