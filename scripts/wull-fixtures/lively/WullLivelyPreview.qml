import QtQuick
import QtTest
import Quickshell
import qs.modules.abyss.companion
import "../../../modules/abyss/companion/WullScene.js" as Scene

Window {
    id: root
    width: 1100; height: 720; visible: true; color: "#061521"
    property bool allowed: true
    property bool animate: true
    property bool featureOpen: false
    property bool featureIdle: true
    property int opens: 0
    property int closes: 0
    property int handoffs: 0
    property real closeGap: 0
    property string testPhase: "motion"
    readonly property var scene: Scene.fromParticipants({width:width,height:height,
        hostWidth:112,hostHeight:98,scale:1,insets:{top:20,right:20,bottom:20,left:20}},
        featureOpen ? {popup:{surfaceSettled:true,geometry:{edge:"top",surface:{x:430,y:160,width:280,height:220}}}} : {}, [])
    function named(item,name) {
        if (item.objectName===name) return item
        for (const child of item.data ?? item.children ?? []) {const found=named(child,name);if(found)return found}
        return null
    }
    function companionFeaturesIdle(): bool {return featureIdle && !featureOpen}
    function openCompanionFeature(feature): bool {if(!companionFeaturesIdle())return false;opens++;featureOpen=true;return true}
    function ownsCompanionFeature(feature): bool {return featureOpen && featureIdle}
    function closeCompanionFeature(feature): void {
        if (!ownsCompanionFeature(feature)) return
        const r=scene.surfaces.find(s=>s.key===feature.key)?.rect, p=presence.position()
        closeGap=r ? Math.hypot(Math.max(r.x-p.x-scene.hostWidth,p.x-r.x-r.width,0),
            Math.max(r.y-p.y-scene.hostHeight,p.y-r.y-r.height,0)) : -1
        closes++;featureOpen=false
    }
    function releaseCompanionFeature(feature): void {handoffs++}
    function place(x,y): void {
        curiosity.finish(true)
        presence.pause(true)
        animate=false
        presence.appear(Scene.annotate(scene,{x:x,y:y},"bottom","edge","bottom"))
        input.wait(30)
        animate=true
        input.wait(30)
    }
    WullPresence {
        id: presence
        scene: root.scene; actor: actor; permitted: root.allowed
        requestedReveal: 1; motionEnabled: root.animate
        onStopRequested: actor.stopTravel()
        onResetRequested: (px,py,edge)=>actor.resetTo(px,py,edge)
    }
    AbyssCompanion {
        id: actor
        width:112;height:98;managedPlacement:true;upright:true;connectedWater:true
        reveal:presence.renderedReveal;motionEnabled:root.animate;effectsEnabled:false
        edge:presence.emergenceEdge;emergenceEdge:presence.emergenceEdge
        travelEnabled:presence.traveling;travelMode:presence.mode;travelDuration:presence.duration
        travelArc:presence.arc;surfaceSupported:presence.grounded
        standingAngle:presence.standingAngle;appearClip:presence.appearClip;hideClip:presence.hideClip
        travelNormalX:presence.normalX;travelNormalY:presence.normalY
        travelDirection:presence.directionX/Math.max(1,Math.hypot(presence.directionX,presence.directionY))
        travelDirectionY:presence.directionY/Math.max(1,Math.hypot(presence.directionX,presence.directionY))
        targetX:presence.targetX;targetY:presence.targetY
        onTravelCompleted:presence.arrived()
        onHoveredChanged:if(hovered)presence.pause()
        onDragStarted:presence.beginDrag()
        onDragPositionRequested:(x,y)=>presence.dragTo(x,y)
        onDragEnded:presence.endDrag()
    }
    WullCuriosity {
        id: curiosity
        presence:presence;actor:actor;adapter:root
        allowed:root.allowed && root.animate;idle:true
        features:[{kind:"clock",key:"popup",edge:"top",along:400,openGesture:"press",gesture:"inspect"}]
    }
    TestCase {
        id: input
        name:"WullLively";when:false
        function check(value,message): void {if(!value)throw new Error(message)}
        function runChecks() {
            try {
                root.place(480,600)
                check(actor.inputReady && presence.surfaceBound,"actor did not reset into surface-bound mode")
                const body=root.named(actor,"wullLiquidBody"), gait=root.named(actor,"wullLocomotion")
                check(presence.moveTo(Scene.annotate(root.scene,{x:550,y:600},"bottom","edge","bottom"),false,"run"),"run route rejected")
                wait(170);check(actor.walking && gait.clip==="run","run pose not selected")
                check(gait.footZ("foot0Z")>0 || gait.footZ("foot1Z")>0,"run did not move its feet")
                tryCompare(presence,"traveling",false,presence.duration+600)
                check(presence.grounded,"running lost its surface")
                check(presence.moveTo(Scene.annotate(root.scene,{x:620,y:600},"bottom","edge","bottom"),false,"jump"),"jump route rejected")
                wait(360)
                check(presence.mode==="jump" && gait.clip==="jump" && actor.y<575,"jump has no airborne arc")
                check(!body.grounded && !actor.walking,"jump used a floor reflection")
                const jumped=actor.y;wait(120);check(actor.y!==jumped,"jump did not progress")
                tryCompare(presence,"traveling",false,1400)
                check(presence.grounded && Math.abs(actor.y-600)<.2,"jump failed to land")
                tryCompare(actor,"gesturing",false,1000)
                root.place(480,190)
                presence.beginDrag();presence.randomState=0;presence.endDrag()
                wait(70);check(presence.mode==="fall" && gait.clip==="fall","high release did not fall")
                const y0=actor.y;wait(100);const y1=actor.y;wait(100);const y2=actor.y
                check(y2-y1>y1-y0,"fall did not accelerate")
                // Passive hover cannot freeze a falling body; a new grab can.
                presence.pause();check(presence.traveling,"hover suspended gravity")
                presence.beginDrag();wait(30);check(!presence.traveling && presence.dragging,"re-grab did not interrupt gravity")
                presence.randomState=0;presence.endDrag()
                tryCompare(presence,"traveling",false,presence.duration+600)
                check(presence.grounded && actor.gesture==="land","fall lacked a landing reaction")
                tryCompare(actor,"gesturing",false,1000)
                root.place(480,190)
                presence.beginDrag();presence.randomState=1000;presence.endDrag()
                wait(90)
                check(presence.mode==="fall" && !presence.releasedFlight,
                    "slow release reintroduced free-floating flight")
                tryCompare(presence,"traveling",false,presence.duration+600)
                check(presence.grounded,"surface-bound release did not return to a support")
                root.place(360,600)
                presence.beginDrag();wait(16)
                presence.dragTo(520,430)
                check(Math.hypot(presence.dragVelocityX,presence.dragVelocityY)>presence.throwThreshold,
                    "fast pointer motion did not cross throw threshold")
                presence.endDrag();wait(35)
                check(presence.releasedFlight && presence.traveling && presence.mode==="fly"
                    && presence.destination?.grounded===true,
                    "fast drag did not become a bounded throw to grounded geometry")
                const throwDestination=JSON.stringify([presence.destination.x,presence.destination.y])
                tryCompare(presence,"traveling",false,presence.duration+1000)
                check(presence.grounded && !presence.releasedFlight
                    && throwDestination===JSON.stringify([presence.placement.x,presence.placement.y]),
                    "throw did not settle at its verified grounded destination")
                root.animate=false;wait(30)
                check(!actor.moving && !gait.active,"motion-off left a travel clock running")
                const frozen=JSON.stringify([actor.x,actor.y,gait.phase,gait.weight]);wait(120)
                check(frozen===JSON.stringify([actor.x,actor.y,gait.phase,gait.weight]),"disabled clocks did not freeze")
                root.place(280,40)
                root.testPhase="initial curiosity"
                curiosity.lastVisit=0;presence.randomState=2000
                check(curiosity.offer(),"curiosity offer rejected")
                tryCompare(root,"featureOpen",true,6000)
                tryCompare(curiosity,"stage","hold",7000)
                check(root.opens===1 && actor.visible,"owned feature was not explored")
                tryCompare(curiosity,"reachedFeature",true,1000)
                // Cancel the autonomous hold with a real departure route. The
                // borrowed surface closes as Wull leaves, not at a later timeout.
                actor.stopGesture();presence.directed=false
                root.testPhase="distance departure"
                check(presence.moveTo(Scene.edgePoint(root.scene,"bottom",.08),false,"fly"),"departure route rejected")
                tryCompare(root,"featureOpen",false,6000)
                check(root.closes===1 && !curiosity.busy && presence.traveling && root.closeGap>140,
                    "distance close interrupted or preceded the departure animation "+root.closeGap)
                tryCompare(presence,"traveling",false,presence.duration+800)
                root.place(280,40)
                root.testPhase="return close"
                curiosity.lastVisit=0;presence.randomState=2000;check(curiosity.offer(),"return-close curiosity offer rejected")
                tryCompare(curiosity,"stage","hold",9000)
                const deadline=root.named(curiosity,"wullCuriosityDeadline")
                deadline.interval=40;deadline.restart()
                tryCompare(curiosity,"busy",false,6500)
                check(!root.featureOpen && root.closes===2,"owned feature was not closed after return")
                check(!deadline.running && !presence.directed,"finished curiosity retained a deadline/hold")
                root.place(280,40)
                curiosity.lastVisit=0;presence.randomState=2000
                check(curiosity.offer(),"second curiosity offer rejected")
                tryCompare(root,"featureOpen",true,6000)
                curiosity.pointerMoved(500,220)
                check(!curiosity.busy && root.featureOpen && root.closes===2 && root.handoffs===1,
                    "pointer handoff closed a human-owned feature")
                curiosity.lastVisit=0;check(!curiosity.offer(),"existing human UI was replaced")
                root.featureOpen=false;root.place(280,40)
                curiosity.lastVisit=0;presence.randomState=2000;check(curiosity.offer(),"policy case offer rejected")
                root.allowed=false;wait(40)
                check(!curiosity.busy && !actor.visible && !deadline.running && !presence.directed,
                    "policy hide did not cancel curiosity")
                console.log("WULL_LIVELY=PASS run jump surfaceBoundRelease velocityThrow groundedLanding acceleratingFall regrab reducedMotion curiosityGesture distanceClose continuedDeparture ownedClose userHandoff policyHide")
            } catch(error) {console.error("WULL_LIVELY=FAIL "+error+" "+JSON.stringify({phase:root.testPhase,
                stage:curiosity.stage,owned:curiosity.owned,near:curiosity.nearFeature,reached:curiosity.reachedFeature,
                featureOpen:root.featureOpen,closes:root.closes,traveling:presence.traveling,mode:presence.mode,
                here:presence.position(),target:presence.destination}))}
            shutdown.start()
        }
    }
    Timer {interval:100;running:true;onTriggered:input.runChecks()}
    Timer {id:shutdown;interval:150;onTriggered:Qt.quit()}
}
