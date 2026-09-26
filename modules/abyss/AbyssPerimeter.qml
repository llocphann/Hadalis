pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.abyss.bar
import qs.modules.abyss.looks
import "looks/AbyssGeometry.js" as Geometry

Scope {
    id: root
    readonly property string barEdge: Geometry.edge(Config.options?.bar?.vertical ?? false, Config.options?.bar?.bottom ?? false)
    function barOnOutput(name): bool {
        return (Config.options?.enabledPanels ?? []).includes("abyssBar")
            && GlobalStates.barOpen
            && Geometry.targets(name, Config.options?.bar?.screenList ?? [], Quickshell.screens.map(s => s.name))
    }
    function outputInsets(name) {
        return Geometry.insets(AbyssStyle.perimeterThickness, root.barEdge, AbyssStyle.barThickness, root.barOnOutput(name))
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: window
            required property var modelData
            readonly property string outputName: modelData?.name ?? ""
            readonly property bool fullscreenCovered: GameMode.hasFullscreenOnOutput(outputName)
            readonly property bool presented: !GlobalStates.screenLocked
                && (!fullscreenCovered || (Config.options?.abyss?.perimeter?.visibleInFullscreen ?? false))
            screen: modelData
            // Keep the Top surface mapped across fullscreen, preserving stack order.
            visible: Config.ready && !GlobalStates.screenLocked
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "hadalis:abyss-perimeter"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }
            Item { id: emptyInput; width: 0; height: 0 }
            mask: Region { item: window.presented && bar.visible ? bar : emptyInput }
            AbyssBar {
                id: bar
                outputName: window.outputName
                edge: root.barEdge
                visible: window.presented && root.barOnOutput(window.outputName)
                x: edge === "right" ? window.width-width : 0
                y: edge === "bottom" ? window.height-height : 0
                width: vertical ? AbyssStyle.barThickness : window.width
                height: vertical ? window.height : AbyssStyle.barThickness
            }
            AbyssField {
                z: -1
                anchors.fill: parent
                visible: window.presented
                edgeInsets: root.outputInsets(window.outputName)
                records: bar.visible ? bar.deformations.map(rec => Geometry.panel(window.width,window.height,edgeInsets,root.barEdge,rec.along+12,rec.span-24,rec.depth,1,0)) : []
            }
        }
    }
    component Reservation: PanelWindow {
        id: reservation
        required property var modelData
        required property string edge
        readonly property bool horizontal: Geometry.horizontal(edge)
        readonly property bool mapped: Config.ready && !GlobalStates.screenLocked
            && !GameMode.hasFullscreenOnOutput(modelData?.name ?? "")
        readonly property real thickness: root.outputInsets(modelData?.name ?? "")[edge]
            + (root.barOnOutput(modelData?.name ?? "") && edge === root.barEdge ? 5 : 0)
        screen: modelData
        visible: mapped
        color: "transparent"
        exclusiveZone: mapped ? thickness : 0
        implicitWidth: horizontal ? 1 : thickness
        implicitHeight: horizontal ? thickness : 1
        WlrLayershell.namespace: "hadalis:abyss-reservation-" + edge
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            top: edge !== "bottom"
            bottom: edge !== "top"
            left: edge !== "right"
            right: edge !== "left"
        }
        mask: Region {}
    }
    Variants { model: Quickshell.screens; Reservation { edge: "top" } }
    Variants { model: Quickshell.screens; Reservation { edge: "bottom" } }
    Variants { model: Quickshell.screens; Reservation { edge: "left" } }
    Variants { model: Quickshell.screens; Reservation { edge: "right" } }
}
