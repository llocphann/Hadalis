import QtQuick
import QtTest
import Quickshell
import qs.modules.abyss.companion
import "../../../modules/abyss/companion/WullScene.js" as Scene
Window {
    id:root;visible:true;width:960;height:720;color:"#061726"
    property bool animate:false
    property bool permitted:true
    property bool alternate:false
    property bool held:false
    property string character:"aqua"
    property var blockers:[]
    property var events:[]
    property bool earlySwap:false
    readonly property var scene:({width:width,height:height,hostWidth:112,hostHeight:98,scale:1,
        insets:{top:24,right:24,bottom:24,left:24},records:[],blockers:blockers,surfaces:[]})
    WullPresence {
        id:presence;actor:actor;scene:root.scene;permitted:root.permitted;requestedReveal:1
        motionEnabled:root.animate;pointerReactionsEnabled:false;interactionHeld:root.held
        onResetRequested:(x,y,edge)=>actor.resetTo(x,y,edge)
        onStopRequested:actor.stopTravel()
        onWaterInteraction:(point,action)=>root.events=root.events.concat([action])
    }
    AbyssCompanion {
        id:actor;character:root.character;managedPlacement:true;upright:true;interactive:false
        motionEnabled:root.animate;effectsEnabled:false;connectedWater:true
        targetX:presence.targetX;targetY:presence.targetY;reveal:presence.renderedReveal
        emergenceEdge:presence.emergenceEdge;standingAngle:presence.standingAngle
        appearClip:presence.appearClip;hideClip:presence.hideClip
        travelEnabled:presence.traveling;travelMode:presence.mode;surfaceSupported:presence.grounded
        travelDuration:presence.duration;travelArc:presence.arc
        onTravelCompleted:presence.arrived()
    }
    CompanionTurns {
        id:turns;actor:actor;presence:presence;allowed:root.permitted;alternating:root.alternate
        interactionHeld:root.held
        onCharacterChosen:character=>{if(actor.presentation>0 || actor.visible)root.earlySwap=true;root.character=character}
    }
    CompanionChallenger {id:guest;turns:turns;actor:actor}
    function place(edge):void {
        animate=false;presence.hideImmediately();blockers=[];presence.hiddenUntil=0
        presence.appear(Scene.edgePoint(scene,edge,.5));input.wait(40);animate=true;input.wait(40)
    }
    function check(value,message):void {if(!value)throw new Error(message)}
    function bodies(item):int {
        let count=typeof item.adoptTo==="function" ? 1 : 0
        for(const child of item.children ?? [])count+=bodies(child)
        return count
    }
    TestCase {
        id:input;when:false;optional:true;name:"CompanionTurns"
        function prove():void {
            try {
                root.place("bottom")
                check(!turns.begin() && !guest.active,"single mode spawned a challenger")
                root.alternate=true
                root.held=true;wait(40);check(!turns.begin(),"turn interrupted chat/task")
                root.held=false;wait(40)
                for(const edge of ["bottom","top","left","right"]) {
                    for(const character of ["aqua","octo"]) {
                        root.character=character;root.place(edge)
                        const before=presence.position()
                        check(turns.begin(),"no turn at "+edge+" "+character)
                        wait(50)
                        check(turns.active && !turns.paired && presence.handoffActive,"handoff not held")
                        check(actor.hideClip===(character==="aqua" ? "pulled" : "sink"),"wrong exit")
                        check(actor.curves.clips[actor.hideClip].duration===5600,"duration parity")
                        check(root.bodies(root.contentItem)===1,"expected one Companion body, got "+root.bodies(root.contentItem))
                        check(actor.tentacleGrip===(character==="aqua"),"hidden Octo grip missing")
                        check(!presence.canExplore,"wander during handoff")
                        const next=turns.replacementPlacement
                        check(Scene.distance(before,next)<.1,"replacement moved to a different opening")
                        wait(950)
                        check(root.character===character && Math.abs(actor.gripProgress-(1-actor.presentation))<.005,"early switch or independent grip clock")
                        turns.finish();check(turns.active && root.character===character,"finish replaced a visible companion")
                        tryCompare(turns,"active",false,6000)
                        tryVerify(()=>actor.presentation>.99 && actor.inputReady,2000)
                        check(root.character!==character && actor.presentation>.99 && actor.inputReady,"incoming not adopted")
                        check(!guest.active && !presence.handoffActive,"temporary cast retained")
                        check(Scene.distance(presence.position(),before)<.1,"incoming did not emerge at the old opening")
                        check(!root.earlySwap && root.bodies(root.contentItem)===1,"a body appeared before the loser fully disappeared")
                        check(presence.fullyPresentSince>0 && Date.now()-presence.fullyPresentSince<1500,"no minimum visit after handoff")
                    }
                }
                root.character="aqua";root.place("bottom")
                check(turns.begin(),"cancel setup")
                root.held=true;wait(80)
                check(!turns.active && !guest.active && !presence.handoffActive,"chat did not cancel the fight")
                root.held=false;root.place("bottom");check(turns.begin(),"policy setup")
                root.permitted=false;wait(80)
                check(!actor.visible && !turns.active && !guest.active,"policy hide retained a companion")
                root.permitted=true;root.place("bottom")
                check(turns.begin(),"motion setup");root.animate=false;wait(80)
                check(!turns.active && !guest.active,"reduced motion retained fight")
                root.place("bottom")
                const p=presence.position()
                root.blockers=[{x:2,y:p.y,width:p.x-5,height:98,walkable:false},
                    {x:p.x+117,y:p.y,width:root.width-p.x-119,height:98,walkable:false}]
                wait(60)
                check(turns.begin(true) && !turns.paired && actor.hideClip==="pulled","single-body exchange unnecessarily requires a neighboring slot")
                tryCompare(turns,"active",false,6500)
                tryVerify(()=>actor.presentation>.99,2000)
                root.alternate=false;wait(40);check(!turns.begin(),"disabled alternating still changes cast")
                check(root.events.includes("sink") && root.events.includes("pulled"),"rivalry has no Abyss water impulses")
                console.log("COMPANION_TURNS=PASS fourEdges twoDirections 5600ms oneBody zeroBeforeSwitch sameOpening gripClock minimumVisit heldCancel policyCancel motionCancel crowdedRim")
            } catch(e){console.error("COMPANION_TURNS=FAIL "+e)}
            shutdown.start()
        }
    }
    Timer {id:shutdown;interval:80;onTriggered:Qt.quit()}
    Timer {interval:200;running:true;onTriggered:input.prove()}
}
