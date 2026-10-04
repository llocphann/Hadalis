import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtTest
import Quickshell
import qs.modules.common
import qs.modules.abyss
import qs.modules.abyss.looks
import qs.modules.abyss.companion
import "../../../modules/abyss/companion/WullScene.js" as Scene

Window {
    id: root
    width: 1100; height: 720; visible: true; color: "#04101e"
    minimumWidth:1100;maximumWidth:1100;minimumHeight:720;maximumHeight:720
    title: "Wull — born from Abyss"
    Component.onCompleted: Quickshell.watchFiles=false
    readonly property bool testMode: (Quickshell.env("WULL_ABYSS_TEST") ?? "")==="1"
    readonly property string capture: Quickshell.env("WULL_DESIGN_CAPTURE") ?? ""
    readonly property bool capturePeek: (Quickshell.env("WULL_PRESENCE_CAPTURE_PEEK") ?? "")==="1"
    readonly property bool waterProof: (Quickshell.env("WULL_ABYSS_WATER_PROOF") ?? "")==="1"
    property int proofStep: 0
    property string testStep: "startup"
    property string surfaceKind: Quickshell.env("WULL_ABYSS_SURFACE") ?? "dock"
    property bool allowed: false
    property real requested: capturePeek ? .46 : 1
    property bool started: false
    property bool captured: false
    property double captureReadyAt: 0
    property real actorScale: testMode ? 1 : 1.6
    readonly property var insets: ({left:18,top:18,right:18,bottom:18})
    readonly property var scene: Scene.fromParticipants({width:width,height:height,
        hostWidth:112*actorScale,hostHeight:98*actorScale,scale:actorScale,
        insets:insets,rimRadius:AbyssStyle.neckRadius},liquid.participants,[])
    function check(value,message): void {
        if (!value) {console.error("WULL_ABYSS_CHECK=FAIL "+message);Qt.quit();throw new Error(message)}
    }
    function target() {
        if (surfaceKind==="edge") return Scene.edgePoint(scene,"bottom",.6)
        const candidates=Scene.surfacePoints(scene).filter(p=>p.key===surfaceKind)
        if (surfaceKind==="leftPanel") return candidates.find(p=>p.edge==="left")
        if (surfaceKind==="rightPanel") return candidates.find(p=>p.edge==="right")
        if (surfaceKind==="styledPopup0" || surfaceKind==="osd") return candidates.find(p=>p.edge==="top")
        return candidates.find(p=>p.grounded) ?? candidates[0]
    }
    function visit(): void {
        allowed=true;requested=capturePeek ? .46 : 1
        if(testMode)presence.randomState=1000
        presence.appear(target())
        if(testMode) {
            // This fixture isolates contact/solver behavior. The alive fixture
            // separately exercises the randomized authored entrances/exits.
            presence.peekOnly=false;presence.appearClip="emerge"
            presence.lastBalance=Date.now()+120000
        }
    }
    function captureField(): void {
        // Frozen actual field uniforms. These controls isolate water pixels
        // from the character's independently animated refraction and bubbles.
        field.grabToImage(result=>{
            const path=root.capture+(root.proofStep===1 ? ".rest.png" : root.proofStep===3 ? ".restored.png" : "")
            root.check(result.saveToFile(path),"could not save field control")
            if (root.proofStep===1) {
                actor.effectsEnabled=true;water.cancel()
                water.impact=presence.placement.contact;water.strength=.85;water.phase=.45
                root.proofStep=2;proofDelay.start()
            } else if (root.proofStep===2) {
                actor.effectsEnabled=false
                root.proofStep=3;proofDelay.start()
            } else {
                console.log("WULL_ABYSS_BEHAVIOR="+JSON.stringify({surface:root.surfaceKind,fieldReady:field.ready,
                    frozenFieldControls:3,contact:presence.placement.contact,nativeDesktopAcceptance:false}))
                console.log("WULL_DESIGN_CAPTURE=SAVED");Qt.quit()
            }
        })
    }
    function change(kind): void {
        allowed=false;surfaceKind=kind
        input.tryVerify(()=>scene.surfaces.some(s=>s.key===kind && s.settled!==false),2500)
        check(scene.surfaces.some(s=>s.key===kind && s.settled!==false),"body did not settle: "+kind)
        visit()
    }
    function runChecks(): void {
        for (const kind of ["dock","settings","leftPanel","rightPanel","styledPopup0","osd","utility"]) {
            testStep=kind+":appear"
            change(kind)
            input.tryVerify(()=>actor.presentation>.6,1500)
            check(water.running && water.neck>.2,"peek did not deform parent water: "+kind)
            check(water.impact.key===kind && water.contact.z>0,"wrong actual contact: "+kind)
            input.tryCompare(actor,"inputReady",true,4000)
            input.wait(1500)
            check(!water.running && water.ripple.w===0 && water.neck===0,"contact did not settle")
            if (presence.grounded) {
                testStep=kind+":walk"
                const point=presence.position()
                const vertical=presence.placement.support.axis==="y"
                const next=Scene.annotate(scene,vertical ? {x:point.x,y:point.y-30} : {x:point.x-30,y:point.y},presence.emergenceEdge,"surface",kind)
                check(presence.moveTo(next,false),"body walk had no route")
                input.wait(100);check(actor.walking,"horizontal body rim did not support walking")
                input.tryCompare(presence,"traveling",false,presence.duration+500)
                check(water.impact.key===kind && water.running,"walking did not disturb actual body water")
            }
            testStep=kind+":dive";presence.randomState=1000;requested=0
            input.tryVerify(()=>actor.leaving,1600)
            check(water.impact.key===kind && water.running,"hide did not return to nearby body water: "+kind)
            input.tryCompare(actor,"visible",false,3500)
            input.wait(1500)
            check(!water.running && water.contact.w===0 && water.ripple.w===0,"hidden local impulse never settled")
        }
        testStep="parent waves:ready";change("dock");input.tryCompare(actor,"inputReady",true,4000)
        Config.setNestedValue("abyss.waves.enabled",true)
        presence.lastBalance=0
        water.tap();input.wait(80)
        check(liquid.waves.running && liquid.waves.simulation.traveling.length>0,"parent Edge solver did not receive contact")
        const waveContact=presence.placement.contact
        liquid.impulse(waveContact.sourceEdge,waveContact.sourceAlong,200,1,1,"open")
        testStep="parent waves:balance"
        input.tryVerify(()=>actor.gesture==="balance",2000)
        check(actor.gesture==="balance","existing Edge wave did not prompt balance")
        actor.effectsEnabled=false;input.wait(30)
        check(!water.running && water.ripple.w===0 && water.contact.w===0,"effects-off did not release local motion")
        actor.effectsEnabled=true;water.tap();actor.motionEnabled=false;input.wait(30)
        check(!water.running && water.ripple.w===0,"motion-off did not cancel finite impulse")
        actor.motionEnabled=true;water.tap();allowed=false;input.wait(40)
        check(!actor.visible && !actor.inputReady && !water.running,"policy hide retained input or local water animation")
        allowed=true;input.tryCompare(actor,"inputReady",true,4000)
        liquid.moduleRecords=Array(40).fill(body.record);input.wait(50)
        check(!presence.permitted && !actor.visible && !water.running,"shader capacity overflow retained an unpainted water visit")
        liquid.moduleRecords=[];allowed=false
        liquid.presented=false;input.wait(150)
        check(!liquid.waves.running,"owned Edge solver did not stop before teardown")
        console.log("WULL_ABYSS_CHECK=PASS "+JSON.stringify({realBodyRegistry:true,paintedSurfaceContacts:true,
            dock:true,settings:true,sidebars:true,styledPopupIpc:true,osd:true,utility:true,
            coupledPeek:true,bodyWalk:true,bodyDive:true,finiteLocalImpulse:true,parentEdgeWaves:true,
            effectsOff:true,motionOff:true,policyHide:true,capacityHide:true,nativeDesktopAcceptance:false,gpuPixels:false}))
        Qt.callLater(Qt.quit)
    }
    Item {
        id: board
        anchors.fill: parent
        Rectangle {anchors.fill:parent;z:-2;color:"#04101e"}
        AbyssSurfaceController {
            id: liquid
            outputName:"fixture";outputWidth:root.width;outputHeight:root.height
            presented:root.visible;presentationItem:field;edgeInsets:root.insets
        }
        AbyssField {
            id: field;anchors.fill:parent;z:-1
            records:liquid.records;edgeInsets:root.insets;waveTexture:liquid.waves.texture;waterLink:water
        }
        Text {x:48;y:46;text:"Wull, born from Abyss";font.pixelSize:30;font.bold:true;color:AbyssStyle.specular}
        Text {x:48;y:90;text:"One living water surface. Peek, rise, wander and return.";font.pixelSize:17;color:"#7bc9ee"}
        Row {
            x:48;y:128;spacing:8
            Repeater {
                model:["edge","dock","settings","leftPanel","rightPanel","styledPopup0","osd","utility"]
                Button {required property string modelData;text:modelData;onClicked:{root.allowed=false;root.surfaceKind=modelData;settle.restart()}}
            }
        }
        AbyssBodyHost {
            id: body
            identity:root.surfaceKind;controller:liquid;anchors.fill:parent
            outputName:"fixture"
            edge:root.surfaceKind==="leftPanel" ? "left" : root.surfaceKind==="rightPanel" ? "right"
                : root.surfaceKind==="styledPopup0" || root.surfaceKind==="osd" ? "top" : "bottom"
            edgeInsets:root.insets
            open:root.surfaceKind!=="edge"
            span:root.surfaceKind==="settings" ? 700 : root.surfaceKind==="dock" ? 520
                : root.surfaceKind==="osd" ? 300 : 380
            depth:root.surfaceKind==="dock" ? 82 : root.surfaceKind==="osd" ? 74 : 220
            along:(edge==="left" || edge==="right" ? root.height : root.width)/2-span/2
            embeddedItem: Item {
                parent:body.contentParent
                width:body.contentParent.width;height:body.contentParent.height
                Text {anchors.centerIn:parent;text:root.surfaceKind==="dock" ? "◉     ▣     ♫     ◇     ⚙     ▤"
                    : root.surfaceKind==="settings" ? "Settings\n\nAppearance     ·     Behavior     ·     Rendering" : root.surfaceKind;
                    font.pixelSize:root.surfaceKind==="dock" ? 28 : 21;color:AbyssStyle.specular;horizontalAlignment:Text.AlignHCenter}
            }
        }
        WullPresence {
            id: presence
            scene:root.scene;actor:actor;permitted:root.allowed && liquid.records.length<=field.capacity;requestedReveal:root.requested
            motionEnabled:actor.motionEnabled
            onStopRequested:actor.stopTravel()
            onResetRequested:(x,y,edge)=>actor.resetTo(x+(root.actorScale-1)*actor.width/2,y+(root.actorScale-1)*actor.height/2,edge)
        }
        WullAbyssLink {id:water;actor:actor;presence:presence;controller:liquid;allowed:root.allowed}
        AbyssCompanion {
            id: actor;z:24;scale:root.actorScale
            edge:presence.emergenceEdge;emergenceEdge:presence.emergenceEdge;upright:true;managedPlacement:true;connectedWater:true
            reveal:presence.renderedReveal;interactive:root.allowed && !presence.retreating;dragEnabled:interactive
            travelEnabled:presence.traveling;travelMode:presence.mode;surfaceSupported:presence.grounded
            standingAngle:presence.standingAngle;appearClip:presence.appearClip;hideClip:presence.hideClip
            travelArc:presence.arc;travelNormalX:presence.normalX;travelNormalY:presence.normalY
            travelDuration:presence.duration;travelDirection:presence.directionX/Math.max(1,Math.hypot(presence.directionX,presence.directionY))
            travelDirectionY:presence.directionY/Math.max(1,Math.hypot(presence.directionX,presence.directionY))
            targetX:presence.targetX+(scale-1)*width/2;targetY:presence.targetY+(scale-1)*height/2
            onTravelCompleted:presence.arrived()
            onActivated:water.tap()
            onDragStarted:presence.beginDrag()
            onDragPositionRequested:(x,y)=>presence.dragTo(x-(scale-1)*width/2,y-(scale-1)*height/2)
            onDragEnded:presence.endDrag()
        }
    }
    TestCase {id:input;parent:board;name:"WullAbyssOwnedSurface";when:false}
    Timer {id:settle;interval:420;onTriggered:root.visit()}
    Timer {id:proofDelay;interval:280;onTriggered:root.captureField()}
    Timer {
        interval:100;running:!root.started;repeat:true
        onTriggered: if (root.surfaceKind==="edge" || root.scene.surfaces.some(s=>s.settled!==false)) {
            root.started=true
            if (root.testMode) {
                try {root.runChecks()}
                catch(error){console.error("WULL_ABYSS_CHECK=FAIL "+root.testStep+" "+error);failureExit.start()}
            }
            else root.visit()
        }
    }
    Timer {id:failureExit;interval:150;onTriggered:Qt.quit()}
    Timer {
        interval:80;running:root.capture.length>0 && root.started && !root.captured;repeat:true
        onTriggered: if (field.ready && actor.materialReady
                && (root.capturePeek ? Math.abs(actor.presentation-presence.peekReveal)<.005 : actor.inputReady)) {
            if (root.waterProof) {
                root.captured=true;actor.effectsEnabled=false
                root.proofStep=1;proofDelay.start()
                return
            }
            if (!root.captureReadyAt) {
                presence.disturb(root.capturePeek ? "peek" : "land",presence.placement)
                root.captureReadyAt=Date.now()
                return
            }
            if (Date.now()-root.captureReadyAt<700) return
            root.captured=true
            board.grabToImage(result=>{
                root.check(result.saveToFile(root.capture),"could not save own-item image")
                console.log("WULL_ABYSS_BEHAVIOR="+JSON.stringify({surface:root.surfaceKind,contact:presence.placement.contact,
                    presentation:actor.presentation,fieldReady:field.ready,materialReady:actor.materialReady,
                    neck:water.neck,impulseActive:water.running,impulsePhase:water.phase,
                    sharedField:true,nativeDesktopAcceptance:false}))
                console.log("WULL_DESIGN_CAPTURE=SAVED");Qt.quit()
            })
        }
    }
}
