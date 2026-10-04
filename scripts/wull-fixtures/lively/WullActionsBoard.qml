import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.abyss.companion

Window {
    id: root
    width:1020;height:620;visible:true;color:"#071521"
    property int frame:0
    property bool busy:false
    readonly property string directory:Quickshell.env("WULL_ACTIONS_DIRECTORY") ?? ""
    Rectangle {
        id: board
        width:1020;height:620;color:"#071521"
        Text {x:30;y:20;text:"Wull · Blender motion actions";color:"#bcf4ff";font.pixelSize:25;font.bold:true}
        Text {x:30;y:55;text:"Two feet, two hands · liquid light follows Abyss · existing procedural renderer";color:"#83b6ce";font.pixelSize:15}
        Repeater {
            id: cells
            model:["run","fly","jump","drag","fall","wave"]
            Rectangle {
                id: cell
                required property string modelData
                required property int index
                x:24+(index%3)*334;y:94+Math.floor(index/3)*255
                width:320;height:240;radius:16;color:"#091b2b";border.color:"#235470"
                property real pose:0
                Text {x:18;y:14;text:cell.modelData.charAt(0).toUpperCase()+cell.modelData.slice(1);color:"#94eaff";font.pixelSize:19}
                Rectangle {x:14;y:220;width:292;height:2;radius:1;color:"#3789b5"}
                AbyssCompanion {
                    id: actor
                    x:18;y:122;width:112;height:98;managedPlacement:true;upright:true
                    reveal:1;motionEnabled:true;effectsEnabled:true;renderQuality:"quality"
                    connectedWater:true;travelEnabled:root.frame>0 && cell.index<3 || root.frame>0 && cell.modelData==="fall"
                    travelMode:cell.modelData
                    travelDuration:cell.modelData==="fall" ? 1000 : 1450
                    travelArc:cell.modelData==="jump" ? 42 : cell.modelData==="fly" ? 24 : 0
                    surfaceSupported:cell.modelData==="run" || (cell.modelData==="jump" && !moving)
                    targetX:root.frame>0 ? cell.modelData==="fall" ? 104 : 164 : 18
                    targetY:root.frame>0 ? 122 : cell.modelData==="fall" ? 40 : 122
                    Component.onCompleted: if (cell.modelData==="fall") {x=104;y=40}
                }
                WaterDropletBody {
                    visible:cell.modelData==="drag" || cell.modelData==="wave"
                    x:122;y:126;width:76;height:92;motionEnabled:root.frame>0 && visible
                    renderQuality:"quality";effectsEnabled:true
                    motionAction:cell.modelData
                    grounded:cell.modelData==="wave"
                    expression:cell.modelData==="wave" ? "happy" : "surprised"
                }
                Component.onCompleted: if (cell.modelData==="drag" || cell.modelData==="wave") actor.reveal=0
            }
        }
    }
    Timer {
        interval:1200;running:true
        onTriggered:{Appearance.colors.colPrimary="#478dff";root.frame=1;frames.start()}
    }
    Timer {
        id:frames;interval:70;repeat:true
        onTriggered: {
            if (root.busy) return
            root.busy=true
            const number=root.frame
            board.grabToImage(result=>{
                if (!result.saveToFile(root.directory+"/frame-"+String(number).padStart(3,"0")+".png")) {
                    console.error("WULL_ACTIONS_CAPTURE=FAIL");Qt.quit();return
                }
                root.busy=false;root.frame++
                if (root.frame>26){frames.stop();console.log("WULL_ACTIONS_CAPTURE=PASS");shutdown.start()}
            })
        }
    }
    Timer {id:shutdown;interval:150;onTriggered:Qt.quit()}
}
