import QtQuick
import Quickshell
import qs.modules.abyss.companion

// Owned GPU items only. No desktop texture or global pointer sampling.
Window {
    id:root;visible:true;width:420;height:360;color:"#061726"
    property int step:0
    property var states:[{action:"",phase:0,quality:"quality"},
        {action:"buttplant",phase:.6,quality:"quality"},{action:"faceplant",phase:.6,quality:"quality"},
        {action:"",phase:0,quality:"performance"},
        {action:"",phase:0,quality:"quality",amber:true}]
    WaterDropletBody {
        id:body;anchors.centerIn:parent;enabled:false;hoverAmount:0
        character:root.step<root.states.length || root.step>=root.states.length*2 ? "aqua" : "octo"
        readonly property var state:root.step>=root.states.length*2 ? {action:"",phase:0,quality:"quality"} : root.states[root.step%root.states.length]
        tentacleGrip:root.step===root.states.length*2;gripProgress:.6
        accentColor:state.amber ? "#faaa52" : "#25b8fa"
        motionEnabled:true;effectsEnabled:true;renderQuality:state.quality;translucency:.16
        motionAction:state.action;motionProgress:state.phase
    }
    function named(item,name) {
        if(item.objectName===name)return item
        for(const child of item.data ?? item.children ?? []){const match=named(child,name);if(match)return match}
        return null
    }
    function save():void {
        const material=named(body,"wullVolumeMaterial"),gait=named(body,"wullLocomotion")
        const arms=Array.from({length:4},(_,i)=>named(body,"octoTentacle"+i))
        if(!body.materialReady || arms.filter(Boolean).length!==((body.octopus || body.tentacleGrip) ? 4 : 0)
                || named(body,"octoTentacle4") || !!named(body,"wullHand0")===body.octopus
                || !!named(body,"wullFoot1")===body.octopus
                || (body.state.action && (Math.abs(body.modelPitch)<60 || gait.scaleY<.95))) {
            console.error("COMPANION_VOLUME=FAIL real material/limbs/pose");Qt.quit();return
        }
        const reflection=named(body,"wullFloorReflectionSource")
        if((body.detailedEffects && (!reflection.sourceItem || !reflection.live))
                || material.optics.y!==(body.octopus ? 4 : 0)) {
            console.error("COMPANION_VOLUME=FAIL optical source");Qt.quit();return
        }
        if(root.step>=root.states.length*2) {
            const front=named(body,"octoGripFront"),back=named(body,"octoGripBack")
            if(body.tentacleGrip && (!front || !back || front.parent.z<=material.parent.z || back.parent.z>=material.parent.z)) {
                console.error("COMPANION_VOLUME=FAIL grip depth layers");Qt.quit();return
            }
            body.grabToImage(result=>{
                result.saveToFile(Quickshell.env("COMPANION_VOLUME_OUTPUT")+(body.tentacleGrip ? "/gripped.png" : "/ungripped.png"))
                root.advance()
            },Qt.size(512,512))
            return
        }
        material.grabToImage(result=>{
            if(!result.saveToFile(Quickshell.env("COMPANION_VOLUME_OUTPUT")+"/pose-"+root.step+".png")){
                console.error("COMPANION_VOLUME=FAIL save");Qt.quit();return
            }
            if(root.step===root.states.length)root.saveArm(0)
            else root.advance()
        },Qt.size(304,304))
    }
    function saveArm(index):void {
        named(body,"octoTentacleMaterial"+index).grabToImage(result=>{
            if(!result.saveToFile(Quickshell.env("COMPANION_VOLUME_OUTPUT")+"/arm-"+index+".png")){
                console.error("COMPANION_VOLUME=FAIL arm save");Qt.quit();return
            }
            if(index===3)root.advance();else root.saveArm(index+1)
        },Qt.size(256,256))
    }
    function advance():void {
        if(root.step===root.states.length*2+1){console.log("COMPANION_VOLUME=PASS bothRigs fourPlumpOpaqueTentacles reflection twoTiers themeRetint spatialFalls frontBackGrip");shutdown.start()}
        else {root.step++;delay.start()}
    }
    Timer {interval:800;running:true;onTriggered:root.save()}
    Timer {id:delay;interval:240;onTriggered:root.save()}
    Timer {id:shutdown;interval:100;onTriggered:Qt.quit()}
}
