import QtQuick
import Quickshell
import qs.modules.abyss.companion
Window {
    id: root;visible:true;width:880;height:410;color:"#061726"
    property int step:0
    property var poses:[{action:"",phase:0},{action:"walk",phase:.25},{action:"fly",phase:.4},{action:"buttplant",phase:.6},
        {action:"",phase:.3,paired:true},{action:"",phase:.3,paired:true,octoWins:true}]
    Item {
        id:board;width:880;height:410;anchors.centerIn:parent
        Rectangle {anchors.fill:parent;color:root.color}
        Row {
            anchors.centerIn:parent;spacing:80
            Repeater {
                model:["aqua","octo"]
                Item {
                    required property string modelData
                    width:300;height:330
                    Text {anchors.top:parent.top;anchors.horizontalCenter:parent.horizontalCenter;text:modelData==="aqua" ? "Aqua" : "Octo";color:"#adefff";font.pixelSize:24}
                    WaterDropletBody {
                        id:body;objectName:"preview"+parent.modelData
                        anchors.centerIn:parent;scale:3;transformOrigin:Item.Center
                        character:parent.modelData;accentColor:"#25b8fa";effectsEnabled:true;motionEnabled:true
                        motionAction:root.poses[root.step].paired
                            ? parent.modelData==="octo" ? (root.poses[root.step].octoWins ? "pull" : "sink")
                                : (root.poses[root.step].octoWins ? "pulled" : "push")
                            : root.poses[root.step].action
                        motionProgress:root.poses[root.step].phase
                        walkingDirection:parent.modelData==="octo" ? -1 : 1
                    }
                }
            }
        }
    }
    function capture():void {
        board.grabToImage(result=>{
            result.saveToFile(Quickshell.env("COMPANION_PREVIEW_DIR")+"/pose-"+root.step+".png")
            if(root.step===root.poses.length-1){console.log("COMPANION_PREVIEW_PASS");Qt.quit()}
            else {root.step++;delay.start()}
        },Qt.size(880,410))
    }
    Timer {interval:800;running:true;onTriggered:root.capture()}
    Timer {id:delay;interval:300;onTriggered:root.capture()}
}
