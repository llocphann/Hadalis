import QtQuick
import Quickshell
import qs.modules.abyss.companion
import "../../../modules/abyss/companion/WullScene.js" as Scene

// Capture only this owned GPU board. The water strip is a preview backdrop;
// production Abyss field/input acceptance is a separate qualification.
Window {
    id: root;visible:true;width:880;height:410;color:"#061726"
    property bool animate:false
    property string character:"aqua"
    property int frame:0
    property int completed:0
    property bool earlySwitch:false
    Item {
        id:board;width:880;height:410;anchors.centerIn:parent
        Rectangle {anchors.fill:parent;color:root.color}
        Rectangle {x:0;y:386;width:parent.width;height:24;color:"#103c54"}
        Rectangle {x:0;y:386;width:parent.width;height:1;color:"#68d7ff";opacity:.6}
        Text {x:24;y:24;text:root.character==="aqua" ? "Aqua" : "Octo";font.pixelSize:24;color:"#adefff"}
        readonly property var scene:({width:width,height:height,hostWidth:224,hostHeight:196,scale:2,
            insets:{top:24,right:24,bottom:24,left:24},records:[],blockers:[],surfaces:[]})
        WullPresence {
            id:presence;actor:actor;scene:board.scene;permitted:true;requestedReveal:1
            motionEnabled:root.animate;pointerReactionsEnabled:false
            onResetRequested:(x,y,edge)=>actor.resetTo(x+56,y+49,edge)
            onStopRequested:actor.stopTravel()
        }
        AbyssCompanion {
            id:actor;character:root.character;scale:2;managedPlacement:true;upright:true;interactive:false
            motionEnabled:root.animate;effectsEnabled:true;connectedWater:true
            targetX:presence.targetX+56;targetY:presence.targetY+49;reveal:presence.renderedReveal
            emergenceEdge:presence.emergenceEdge;standingAngle:presence.standingAngle
            appearClip:presence.appearClip;hideClip:presence.hideClip
            travelEnabled:presence.traveling;travelMode:presence.mode;surfaceSupported:presence.grounded
            travelDuration:presence.duration;travelArc:presence.arc
            onTravelCompleted:presence.arrived()
        }
        CompanionTurns {
            id:turns;actor:actor;presence:presence;allowed:true;alternating:true
            onCharacterChosen:character=>{
                root.earlySwitch=root.earlySwitch || actor.presentation>0 || actor.visible
                root.character=character;root.completed++
                if(root.completed===1)second.start();else finish.start()
            }
        }
        CompanionChallenger {turns:turns;actor:actor}
    }
    function capture():void {
        board.grabToImage(result=>{
            result.saveToFile(Quickshell.env("COMPANION_TURN_PREVIEW")+"/frame-"+String(root.frame++).padStart(3,"0")+".png")
        },Qt.size(880,410))
    }
    Timer {interval:500;running:true;onTriggered:{presence.appear(Scene.edgePoint(board.scene,"bottom",.5));begin.start()}}
    Timer {id:begin;interval:250;onTriggered:{root.animate=true;turns.begin();captureTimer.start()}}
    Timer {id:captureTimer;interval:140;repeat:true;onTriggered:root.capture()}
    Timer {id:second;interval:1400;onTriggered:turns.begin()}
    Timer {id:finish;interval:1400;onTriggered:{captureTimer.stop();root.capture();shutdown.start()}}
    Timer {id:shutdown;interval:250;onTriggered:{console.log("COMPANION_TURN_PREVIEW="+(root.earlySwitch ? "FAIL" : "PASS")+" frames="+root.frame);Qt.quit()}}
}
