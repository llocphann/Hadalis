pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.services
import qs.modules.common.widgets
import qs.modules.abyss.looks
import "WullCloudOrbit.js" as Orbit

Item {
    id: root
    required property Item actor
    required property real outputWidth
    required property real outputHeight
    property bool allowed: false
    property bool revealed: false
    readonly property bool hovered: obsidian.hovered || ai.hovered
    readonly property Item obsidianTarget: obsidian
    readonly property Item aiTarget: ai
    readonly property bool eligible: allowed && actor.visible && actor.inputReady && revealed
        && !WullMind.conversationOpen && !WullMind.contextOpen
    readonly property var orbit: eligible ? Orbit.layout(outputWidth,outputHeight,{
        x:actor.x,y:actor.y,width:actor.width,height:actor.height,scale:actor.scale,
        sideAlignment:actor.sideAlignment ?? 0,floorAlignment:actor.floorAlignment ?? 0,
        edge:actor.edge ?? "bottom"}) : {available:false,nodes:[]}
    width: outputWidth; height: outputHeight
    z: 241
    visible: eligible && orbit.available
    onAllowedChanged: if(!allowed)revealed=false
    onHoveredChanged: if(hovered)hide.stop();else hide.restart()
    Connections {
        target:root.actor
        function onHoveredChanged():void {
            if(root.actor.hovered) {root.revealed=true;hide.stop()}
            else hide.restart()
        }
    }
    Timer { id:hide; interval:450; onTriggered:if(!root.actor.hovered && !root.hovered)root.revealed=false }
    component Cloud: Item {
        id:cloud
        required property string kind
        required property int orbitIndex
        readonly property var placement: root.orbit.nodes[orbitIndex]
        readonly property bool hovered: nodeHover.hovered || button.buttonHovered
        x: placement?.x ?? 0; y: placement?.y ?? 0
        width: placement?.width ?? 38; height: placement?.height ?? 33.25
        HoverHandler { id:nodeHover;enabled:root.visible;blocking:false;cursorShape:Qt.PointingHandCursor }
        Shape {
            objectName: cloud.kind==="obsidian" ? "wullObsidianCloudShape" : "wullAiCloudShape"
            anchors.centerIn:parent
            width:48; height:42; scale:cloud.width/48
            ShapePath {
                strokeWidth:1.1
                strokeColor:Qt.alpha(AbyssStyle.accent,cloud.hovered ? .88 : .48)
                fillGradient: LinearGradient {
                    x1:0; y1:6; x2:0; y2:39
                    GradientStop { position:0; color:Qt.alpha(AbyssStyle.surfaceRaised,cloud.hovered ? 1 : .94) }
                    GradientStop { position:1; color:Qt.alpha(AbyssStyle.surfaceDeep,.96) }
                }
                startX:11; startY:33
                PathCubic {x:3;y:25;control1X:5;control1Y:34;control2X:2;control2Y:30}
                PathCubic {x:8;y:17;control1X:2;control1Y:20;control2X:4;control2Y:17}
                PathCubic {x:15;y:10;control1X:7;control1Y:13;control2X:11;control2Y:9}
                PathCubic {x:26;y:8;control1X:18;control1Y:2;control2X:25;control2Y:3}
                PathCubic {x:37;y:15;control1X:33;control1Y:5;control2X:39;control2Y:10}
                PathCubic {x:45;y:24;control1X:43;control1Y:14;control2X:47;control2Y:20}
                PathCubic {x:38;y:33;control1X:47;control1Y:31;control2X:44;control2Y:35}
                PathCubic {x:26;y:35;control1X:36;control1Y:39;control2X:29;control2Y:39}
                PathCubic {x:11;y:33;control1X:22;control1Y:39;control2X:15;control2Y:38}
            }
        }
        RippleButton {
            id:button;objectName:cloud.kind==="obsidian" ? "wullObsidianAction" : "wullAiAction"
            anchors.fill:parent;buttonRadius:height/2
            colBackground:"transparent";colBackgroundHover:"transparent";colRipple:AbyssStyle.accent
            Accessible.name:cloud.kind==="obsidian" ? "Daily check-in and schedule" : "AI chat"
            onClicked:cloud.kind==="obsidian" ? WullMind.openContext() : WullMind.openChat()
            contentItem:Item {
                Image {
                    id:appIcon;anchors.centerIn:parent
                    width:cloud.width*.4;height:width;source:cloud.kind==="obsidian" ? Quickshell.iconPath("obsidian",true) : ""
                    visible:status===Image.Ready
                }
                MaterialSymbol {
                    anchors.centerIn:parent
                    visible:!appIcon.visible;iconSize:cloud.width*.4;color:AbyssStyle.accent
                    text:cloud.kind==="obsidian" ? "diamond" : "auto_awesome"
                }
            }
        }
    }
    Cloud { id:obsidian;kind:"obsidian";orbitIndex:0 }
    Cloud { id:ai;kind:"ai";orbitIndex:1 }
}
