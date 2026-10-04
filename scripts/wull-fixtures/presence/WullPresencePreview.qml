import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtTest
import Quickshell
import qs.modules.abyss.companion
import "../../../modules/abyss/companion/WullScene.js" as Scene

Window {
    id: root
    width: 1100; height: 720; visible: true
    title: "Wull — free movement and interaction"
    color: "#04101e"
    readonly property bool testMode: (Quickshell.env("WULL_PRESENCE_TEST") ?? "") === "1"
    readonly property string capture: Quickshell.env("WULL_DESIGN_CAPTURE") ?? ""
    readonly property string frames: Quickshell.env("WULL_DESIGN_FRAMES") ?? ""
    readonly property bool capturePeek: (Quickshell.env("WULL_PRESENCE_CAPTURE_PEEK") ?? "") === "1"
    property bool allowed: true
    property real requested: 1
    property bool animate: true
    property bool leftOpen: false
    property bool rightOpen: false
    property bool popupOpen: false
    property int taps: 0
    property real actorScale: testMode ? 1 : 1.6
    property int frameIndex: 0
    property bool busy: false
    property int walkFrames: 0
    property int flyFrames: 0
    property int dragFrames: 0
    property int clickFrames: 0
    property bool retreatObserved: false
    property bool airborneFloorAbsent: true
    property bool quiet: false
    property string quietSnapshot: ""
    property point dragPoint: Qt.point(0,0)
    readonly property var scene: {
        const surfaces=[]
        if (leftOpen) surfaces.push({key:"leftPanel",edge:"left",rect:{x:20,y:138,width:200,height:350}})
        if (rightOpen) surfaces.push({key:"rightPanel",edge:"right",rect:{x:880,y:138,width:200,height:350}})
        if (popupOpen) surfaces.push({key:"popup",edge:"top",rect:{x:480,y:245,width:250,height:215}})
        return {width:1100,height:720,scale:actorScale,hostWidth:112*actorScale,hostHeight:98*actorScale,
            insets:{top:20,right:20,bottom:20,left:20},records:[],blockers:surfaces.map(s=>s.rect),surfaces:surfaces}
    }
    function named(item,name) {
        if (item.objectName===name) return item
        for (const child of item.data ?? item.children ?? []) {const found=named(child,name);if(found)return found}
        return null
    }
    function require(value,message): void {
        if (!value) {console.error("WULL_PRESENCE_CHECK=FAIL "+message);Qt.quit();throw new Error(message)}
    }
    function clocks(): string {
        const body=named(actor,"wullLiquidBody"), gait=named(actor,"wullLocomotion")
        return JSON.stringify([body.bob,body.sway,body.shimmer,body.orbitPhase,gait.phase,gait.weight])
    }
    function physical() {return presence.position()}
    function walk(): void {
        const p=physical()
        const target=Scene.annotate(scene,{x:p.x-48*actorScale,y:p.y},"bottom","edge","bottom")
        presence.moveTo(target,false)
    }
    function floatUp(): void {
        const p=physical()
        presence.moveTo(Scene.drop(scene,p.x,p.y-48*actorScale,p),false)
    }
    function waitFor(item,property,value,timeout): void {
        try {input.tryCompare(item,property,value,timeout)}
        catch(e) {require(false,"deadline missed: "+property+" "+JSON.stringify({mode:presence.mode,traveling:presence.traveling,presentation:actor.presentation,peekOnly:presence.peekOnly,peekIntro:presence.peekIntro,reveal:presence.renderedReveal,edge:presence.emergenceEdge,x:actor.x,y:actor.y,targetX:presence.targetX,targetY:presence.targetY}))}
    }
    function runChecks(): void {
        const body=named(actor,"wullLiquidBody"), face=named(actor,"wullFace")
        require(actor.peeking && !actor.inputReady && presence.peekIntro,"visit did not peek before emerging")
        root.requested=0;input.wait(850)
        require(!actor.visible && !presence.visitActive && !named(presence,"wullPeekDeadline").running,"peek did not retract into water")
        presence.randomState=3;root.requested=1;input.wait(650)
        require(actor.peeking && !actor.inputReady && presence.peekIntro,"next visit skipped peek")
        waitFor(actor,"inputReady",true,4000)
        require(actor.inputReady && presence.grounded,"initial visit did not land on the lower water rim")
        const normal=body.liquidAccent.hslLightness
        input.mouseMove(body,38,49);input.wait(220)
        require(body.hovered && body.liquidAccent.hslLightness>normal+.01,"real hover did not highlight material")
        input.mouseClick(body,38,49,Qt.LeftButton);input.wait(60)
        require(taps===1 && body.tapPhase<1 && body.tapPulse>.1,"real click did not create feedback")
        input.wait(750);require(body.tapPhase===1 && body.tapPulse===0,"tap did not settle")
        input.mouseMove(body,12,50);input.wait(240)
        require(face.gazeX<-.3,"pointer gaze did not interpolate "+JSON.stringify({face:face.gazeX,body:body.gazeX,hovered:body.hovered,point:body.hoverGazeX,attention:actor.attention,moving:actor.moving,expression:actor.faceExpression,yaw:body.viewYaw}))
        actor.expression="working";input.wait(260)
        require(Math.abs(face.gazeX)<.25,"focused expression chased pointer")
        actor.expression="idle";input.mouseMove(board,10,10);input.wait(100)
        actor.pointerFresh=true;actor.pointerX=1
        walk();input.wait(220)
        require(actor.walking && !actor.flying && actor.attention.x<0,"walk did not look forwards over the pointer")
        input.mouseMove(body,38,49);input.wait(180)
        require(body.hovered && !presence.traveling && !actor.moving && actor.inputReady,"hover did not interrupt walk with input intact")
        const held=physical();input.wait(160)
        require(Scene.distance(held,physical())<.01,"hovered walk kept moving")
        input.mouseMove(board,10,10);input.wait(60)
        walk();waitFor(presence,"traveling",false,presence.duration+600)
        require(!presence.traveling && presence.grounded,"walk did not finish on its surface")
        floatUp();input.wait(150)
        require(actor.flying && !actor.walking && !body.grounded,"airborne movement used footsteps")
        require(named(actor,"wullFloorReflectionSource").sourceItem===null,"airborne Wull drew a floor mirror")
        input.wait(600);require(!presence.traveling && !presence.grounded,"float-up did not settle in air")
        const before=physical(), p=body.mapToItem(board,38,49)
        input.mousePress(board,p.x,p.y,Qt.LeftButton)
        input.mouseMove(board,p.x+35,p.y-12,30,Qt.LeftButton);input.wait(40)
        input.mouseMove(board,p.x+62,p.y-20,30,Qt.LeftButton);input.wait(50)
        require(actor.dragging && presence.dragging && physical().x>before.x+25,"real drag did not move the host")
        input.mouseRelease(board,p.x+62,p.y-20,Qt.LeftButton);input.wait(100)
        require(!actor.dragging && !presence.dragging && taps===1,"drag produced an extra click or retained a grab")
        input.mouseMove(board,10,10);input.wait(80)
        const water=Scene.nearestWater(scene,physical())
        require(water.qualified,"drop had no reachable water")
        presence.randomState=1000;root.requested=0;input.wait(40)
        require(presence.retreating && !actor.interactive,"hide did not seek nearby water and release input")
        waitFor(presence,"traveling",false,presence.duration+600)
        require(actor.activeEmergenceEdge===water.placement.edge && actor.leaving,"dive kept the old emergence edge after arrival")
        waitFor(actor,"visible",false,3000)
        require(!actor.visible && !actor.inputReady && !presence.traveling,"water dive did not vanish")
        const frozen=clocks();input.wait(170)
        require(clocks()===frozen,"hidden motion clocks continued")
        root.requested=1;input.wait(1100)
        root.allowed=false;input.wait(30)
        require(!actor.visible && !actor.inputReady && !presence.visitActive,"policy hide faded with active input")
        root.allowed=true;input.wait(20);presence.peekOnly=false;waitFor(actor,"inputReady",true,5000)
        // A real one-shot deadline tests the sustained-popup offer, with its
        // deterministic fixture seed. Production keeps the twelve-second delay.
        const deadline=named(presence,"wullSurfaceDeadline")
        deadline.interval=100;presence.randomState=3;root.popupOpen=true
        input.wait(160)
        require(presence.traveling || presence.placement.kind==="surface","sustained popup did not offer a destination")
        waitFor(presence,"traveling",false,10000)
        require(!presence.traveling && presence.placement.kind==="surface","popup visit did not settle")
        root.allowed=false;input.wait(40)
        require(!deadline.running && !named(presence,"wullPeekDeadline").running,"hidden presence left a deadline running")
        console.log("WULL_PRESENCE_CHECK=PASS "+JSON.stringify({peek:true,peekRetraction:true,hover:true,hoverInterruptsWalk:true,click:true,gaze:true,walk:true,floatUp:true,drag:true,nearbyWaterDive:true,hiddenClocks:true,policyHide:true,sustainedPopup:true,qtLocalEvents:true,nativeDesktopAcceptance:false}))
        Qt.quit()
    }
    Rectangle {
        id: board
        width: 1100; height: 720; color: "#04101e"
        Rectangle { x: 8; y: 8; width: 1084; height: 704; radius: 24; color: "transparent"; border.color: "#287c9b"; border.width: 3 }
        Text { x: 38; y: 31; text: "Wull, a little drop of life"; color: "#dbf6ff"; font.pixelSize: 32; font.bold: true }
        Text { x: 39; y: 77; text: "Walk on a surface · float in open space · drag anywhere clear · dive into nearby water"; color: "#83d8f5"; font.pixelSize: 16 }
        Rectangle { x: 20; y: 138; width: 200; height: 350; radius: 15; visible: root.leftOpen; color: "#10253b"; border.color: "#4e92b3"; Text { x: 15; y: 20; text: "Left Sidebar"; color: "#c9f3ff"; font.pixelSize: 19 } }
        Rectangle { x: 880; y: 138; width: 200; height: 350; radius: 15; visible: root.rightOpen; color: "#10253b"; border.color: "#4e92b3"; Text { x: 15; y: 20; text: "Right Sidebar"; color: "#c9f3ff"; font.pixelSize: 19 } }
        Rectangle { x: 480; y: 245; width: 250; height: 215; radius: 15; visible: root.popupOpen; color: "#10253b"; border.color: "#4e92b3"; Text { x: 15; y: 20; text: "Connected popup"; color: "#c9f3ff"; font.pixelSize: 19 } }
        Text { x: 330; y: 170; width: 460; text: "Hover for a soft highlight.\nTap for a ripple and a little hop.\nDrag Wull to choose its next resting spot."; color: "#99b9ce"; font.pixelSize: 17; lineHeight: 1.8 }
        Row {
            x: 38; y: 336; spacing: 8
            Repeater {
                model: ["Visit", "Walk", "Float up", "Left Sidebar", "Right Sidebar", "Popup", "Hide"]
                Button {
                    required property string modelData
                    text: modelData
                    onClicked: {
                        if (modelData==="Visit") {root.requested=1;presence.appear()}
                        else if (modelData==="Walk") root.walk()
                        else if (modelData==="Float up") root.floatUp()
                        else if (modelData==="Left Sidebar") root.leftOpen=!root.leftOpen
                        else if (modelData==="Right Sidebar") root.rightOpen=!root.rightOpen
                        else if (modelData==="Popup") root.popupOpen=!root.popupOpen
                        else root.requested=0
                    }
                }
            }
        }
        Text { x: 38; y: 405; text: "State: "+(actor.peeking ? "peeking from water" : actor.dragging ? "dragging" : actor.walking ? "walking" : actor.flying ? "flying" : actor.visible ? presence.grounded ? "resting on water" : "floating" : "hidden"); color: "#75d7f9"; font.pixelSize: 16 }
        Text { x: 38; y: 437; text: "Two feet · two hands · orbital bubbles · live Abyss colors"; color: "#638ea9"; font.pixelSize: 14 }
        AbyssCompanion {
            id: actor
            z: 20; scale: root.actorScale; upright: true
            managedPlacement: true
            targetX: presence.targetX+(scale-1)*implicitWidth/2
            targetY: presence.targetY+(scale-1)*implicitHeight/2
            reveal: presence.renderedReveal
            edge: presence.emergenceEdge; emergenceEdge: presence.emergenceEdge
            surfaceSupported: presence.grounded
            travelEnabled: presence.traveling; travelMode: presence.mode
            travelDuration: presence.duration
            travelDirection: presence.directionX/Math.max(1,Math.hypot(presence.directionX,presence.directionY))
            travelDirectionY: presence.directionY/Math.max(1,Math.hypot(presence.directionX,presence.directionY))
            motionEnabled: root.animate
            interactive: root.allowed && !presence.retreating
            dragEnabled: interactive
            renderQuality: "quality"
            onActivated: root.taps++
            onTravelCompleted: presence.arrived()
            onDragStarted: presence.beginDrag()
            onDragPositionRequested: (px,py)=>presence.dragTo(px-(scale-1)*implicitWidth/2,py-(scale-1)*implicitHeight/2)
            onDragEnded: presence.endDrag()
        }
    }
    WullPresence {
        id: presence
        scene: root.scene; actor: actor
        permitted: root.allowed; requestedReveal: root.requested
        motionEnabled: root.animate; randomState: 3
        onStopRequested: actor.stopTravel()
        onResetRequested: (px,py,edge)=>actor.resetTo(px+(actor.scale-1)*actor.implicitWidth/2,py+(actor.scale-1)*actor.implicitHeight/2,edge)
    }
    TestCase { id: input; when: false; optional: true }
    Timer { interval: 650; running: root.testMode; onTriggered: root.runChecks() }
    Timer {
        id: captureTimer
        interval: root.capturePeek ? 650 : 2200; running: root.capture.length>0
        onTriggered: {
            if (root.capturePeek) {
                if (Math.abs(actor.presentation-presence.peekReveal)>.005) {interval=50;restart();return}
                root.require(presence.peekIntro && actor.peeking && !actor.inputReady,"peek capture skipped its partial emergence")
                console.log("WULL_PRESENCE_PEEK="+JSON.stringify({peek:true,edge:presence.emergenceEdge,reveal:actor.presentation,inputReady:actor.inputReady}))
            }
            board.grabToImage(result=>{root.require(result.saveToFile(root.capture),"image save failed");console.log("WULL_DESIGN_CAPTURE=SAVED");Qt.quit()})
        }
    }
    Timer {
        interval: 18000; running: root.frames.length>0
        onTriggered: console.log("WULL_PRESENCE_CAPTURE_STALLED="+JSON.stringify({frame:root.frameIndex,busy:root.busy,visible:actor.visible,materialReady:actor.materialReady,presentation:actor.presentation,peeking:actor.peeking,traveling:presence.traveling,moving:actor.moving,hovered:actor.hovered,visit:presence.visitActive,permitted:presence.permitted,inputReady:actor.inputReady}))
    }
    Timer {
        interval: 50; repeat: true; running: root.frames.length>0
        onTriggered: {
            if (root.busy || (!actor.materialReady && !actor.softwareFallback) || (root.frameIndex===0 && !actor.inputReady)) return
            const body=root.named(actor,"wullLiquidBody")
            if (root.frameIndex===180) {
                stop()
                const behavior={walkFrames:root.walkFrames,flyFrames:root.flyFrames,dragFrames:root.dragFrames,clickFrames:root.clickFrames,retreat:root.retreatObserved,airborneFloorAbsent:root.airborneFloorAbsent,hiddenClocks:root.quiet,softwareFallback:actor.softwareFallback,qtLocalEvents:true,nativeDesktopAcceptance:false}
                console.log("WULL_PRESENCE_BEHAVIOR="+JSON.stringify(behavior))
                root.require(root.walkFrames>10 && root.flyFrames>4 && root.dragFrames>1
                    && root.clickFrames>0 && root.retreatObserved && root.airborneFloorAbsent
                    && root.quiet && !actor.visible,"motion sequence incomplete")
                console.log("WULL_DESIGN_FRAMES=180_SAVED");Qt.quit();return
            }
            if (root.frameIndex===5) root.walk()
            if (root.frameIndex===42) root.floatUp()
            if (root.frameIndex===58) input.mouseClick(body,38,49,Qt.LeftButton)
            if (root.frameIndex===76) {
                root.dragPoint=body.mapToItem(board,38,49)
                input.mousePress(board,root.dragPoint.x,root.dragPoint.y,Qt.LeftButton)
            }
            if (root.frameIndex===80) input.mouseMove(board,root.dragPoint.x+42,root.dragPoint.y-10,10,Qt.LeftButton)
            if (root.frameIndex===84) input.mouseMove(board,root.dragPoint.x+100,root.dragPoint.y-26,10,Qt.LeftButton)
            if (root.frameIndex===88) input.mouseRelease(board,root.dragPoint.x+100,root.dragPoint.y-26,Qt.LeftButton)
            if (root.frameIndex===95) input.mouseMove(board,10,10)
            if (root.frameIndex===106) root.requested=0
            if (actor.walking) root.walkFrames++
            if (actor.flying) {
                root.flyFrames++
                root.airborneFloorAbsent=root.airborneFloorAbsent && root.named(actor,"wullFloorReflectionSource").sourceItem===null
            }
            if (actor.dragging) root.dragFrames++
            if (body.tapPhase<1) root.clickFrames++
            if (presence.retreating) root.retreatObserved=true
            if (root.frameIndex===150) root.quietSnapshot=root.clocks()
            if (root.frameIndex===170) root.quiet=!actor.visible && root.clocks()===root.quietSnapshot
            root.busy=true
            board.grabToImage(result=>{
                root.require(result.saveToFile(root.frames+"/frame-"+String(root.frameIndex).padStart(3,"0")+".png"),"frame save failed")
                root.frameIndex++;root.busy=false
            })
        }
    }
}
