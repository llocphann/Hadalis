import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.abyss.companion
import "../../../modules/abyss/companion/WullMotionData.js" as Curves

// Owned GPU comparison board. Runtime poses use the exact exported Blender
// curves and the shipped liquid shader; capture never reads the desktop.
Window {
    id:root
    width:1320;height:870;visible:true;color:"#071521"
    property int frame:0
    property bool busy:false
    readonly property real elapsed:Math.max(0,frame-1)*70
    readonly property string directory:Quickshell.env("WULL_ACTIONS_DIRECTORY") ?? ""
    Rectangle {
        id:board;width:1320;height:870;color:"#071521"
        Text {x:28;y:18;text:"Wull · living water";color:"#bcf4ff";font.pixelSize:26;font.bold:true}
        Text {x:28;y:56;text:"Jump, tumble, push, sink and balance · two hands, two feet · real runtime material";color:"#83b6ce";font.pixelSize:15}
        Repeater {
            model:["riseJump","launch","stuckLaunch","faceplant","diveJump","sink","ice","balance","startle","delight","walk","fly"]
            Rectangle {
                id:cell
                required property string modelData
                required property int index
                x:20+(index%4)*326;y:92+Math.floor(index/4)*255
                width:312;height:242;radius:16;color:"#091b2b";border.color:"#235470";clip:true
                readonly property real phase:["walk","fly"].includes(modelData)
                    ? (root.elapsed%Curves.clips[modelData].duration)/Curves.clips[modelData].duration
                    : Math.min(1,root.elapsed/Curves.clips[modelData].duration)
                readonly property real normal:Curves.sample(modelData,"normal",phase)
                Text {x:16;y:12;z:10;text:({riseJump:"Jump out",launch:"Water launch",stuckLaunch:"Stuck → push",faceplant:"Faceplant",diveJump:"Dive back",sink:"Quicksand",ice:"Icy landing",balance:"Keep balance",startle:"Startled",delight:"Delighted",walk:"Slow walk",fly:"Propelled flight"})[cell.modelData];color:"#94eaff";font.pixelSize:18}
                Rectangle {x:12;y:223;width:288;height:2;radius:1;color:"#3789b5"}
                WaterDropletBody {
                    id:body
                    x:118;y:89+cell.normal*98*1.7;width:76;height:92;scale:1.7
                    motionEnabled:true;effectsEnabled:true;renderQuality:"quality";translucency:.22
                    motionAction:cell.modelData;motionProgress:cell.phase
                    grounded:cell.normal>=-.015 && cell.modelData!=="fly"
                    expression:cell.modelData==="sink" ? "panicked" : ["launch","stuckLaunch","ice","startle","balance"].includes(cell.modelData) ? "surprised" : "happy"
                    eyeOpen:Curves.clips[cell.modelData].tracks.eyeOpen ? Curves.sample(cell.modelData,"eyeOpen",cell.phase) : 1
                }
            }
        }
    }
    Timer {interval:1200;running:true;onTriggered:{Appearance.colors.colPrimary="#478dff";root.frame=1;frames.start()}}
    Timer {
        id:frames;interval:70;repeat:true
        onTriggered:{
            if(root.busy)return
            root.busy=true
            const number=root.frame
            board.grabToImage(result=>{
                if(!result.saveToFile(root.directory+"/frame-"+String(number).padStart(3,"0")+".png")) {
                    console.error("WULL_ACTIONS_CAPTURE=FAIL");Qt.quit();return
                }
                root.busy=false;root.frame++
                if(root.frame>45){frames.stop();console.log("WULL_ACTIONS_CAPTURE=PASS");shutdown.start()}
            })
        }
    }
    Timer {id:shutdown;interval:150;onTriggered:Qt.quit()}
}
