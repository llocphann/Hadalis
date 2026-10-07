pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.services
import qs.modules.common.widgets
import qs.modules.abyss.looks

Item {
    id: root
    required property Item actor
    required property real outputWidth
    required property real outputHeight
    property bool allowed: false
    property bool revealed: false
    readonly property bool hovered: hover.hovered
    readonly property real actorScale: Math.max(.1,Number(actor.scale)||1)
    readonly property real centerX: actor.x+actor.width/2
    readonly property real visualTop: actor.y+(actor.height-actor.height*actorScale)/2
    readonly property real visualBottom: visualTop+actor.height*actorScale
    width: 148; height: 66
    x: Math.max(8,Math.min(outputWidth-width-8,centerX-width/2))
    y: visualTop-height-4>=8 ? visualTop-height-4 : Math.min(outputHeight-height-8,visualBottom+4)
    z: 241
    visible: allowed && actor.visible && actor.inputReady && revealed
        && !WullMind.conversationOpen && !WullMind.contextOpen
    onAllowedChanged: if(!allowed)revealed=false
    Connections {
        target:root.actor
        function onHoveredChanged():void {
            if(root.actor.hovered) {root.revealed=true;hide.stop()}
            else hide.restart()
        }
    }
    HoverHandler { id:hover; onHoveredChanged: if(hovered)hide.stop();else hide.restart() }
    Timer { id:hide; interval:450; onTriggered:if(!root.actor.hovered && !root.hovered)root.revealed=false }
    component Cloud: Item {
        id:cloud
        required property string kind
        width:68; height:60
        Shape {
            anchors.fill:parent
            ShapePath {
                strokeWidth:0; strokeColor:"transparent"
                fillColor:button.hovered ? AbyssStyle.surfaceRaised : AbyssStyle.surface
                startX:12;startY:48
                PathCubic {x:8;y:24;control1X:-4;control1Y:47;control2X:-2;control2Y:24}
                PathCubic {x:38;y:13;control1X:7;control1Y:0;control2X:32;control2Y:0}
                PathCubic {x:57;y:24;control1X:52;control1Y:6;control2X:64;control2Y:15}
                PathCubic {x:56;y:48;control1X:74;control1Y:27;control2X:72;control2Y:48}
                PathLine {x:12;y:48}
            }
        }
        RippleButton {
            id:button;objectName:cloud.kind==="obsidian" ? "wullObsidianAction" : "wullAiAction"
            anchors.fill:parent; buttonRadius:25
            colBackground:"transparent";colBackgroundHover:"transparent";colRipple:AbyssStyle.accent
            Accessible.name:cloud.kind==="obsidian" ? "Daily check-in and schedule" : "AI chat"
            onClicked:cloud.kind==="obsidian" ? WullMind.openContext() : WullMind.openChat()
            contentItem:Item {
                Image {
                    id:appIcon;anchors.centerIn:parent;anchors.verticalCenterOffset:-4
                    width:24;height:24;source:cloud.kind==="obsidian" ? Quickshell.iconPath("obsidian",true) : ""
                    visible:status===Image.Ready
                }
                MaterialSymbol {
                    anchors.centerIn:parent;anchors.verticalCenterOffset:-4
                    visible:!appIcon.visible;iconSize:24;color:AbyssStyle.accent
                    text:cloud.kind==="obsidian" ? "diamond" : "auto_awesome"
                }
            }
        }
    }
    Cloud {kind:"obsidian";x:0}
    Cloud {kind:"ai";x:80}
}
