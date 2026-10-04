import QtQuick
import "WullScene.js" as Scene

// One controller per existing output window; only the permitted output acts.
// Native visit/wander events plus one sustained-surface deadline drive choices.
Item {
    id: root
    property var scene: null
    property var actor: null
    property bool permitted: false
    property real requestedReveal: 0
    property bool motionEnabled: true
    property bool interactionHeld: false
    property string personality: "balanced"
    property bool directed: false
    property double travelId: 0
    property real travelFraction: 0.5
    property double randomState: Date.now() % 4294967296
    property var placement: ({qualified:false})
    property var destination: ({qualified:false})
    property var waypoints: []
    property int waypoint: 0
    property real targetX: 0
    property real targetY: 0
    property real renderedReveal: 0
    property bool visitActive: false
    property bool traveling: false
    property bool dragging: false
    property bool retreating: false
    property bool releasedFlight: false
    property bool peekIntro: false
    property bool peekOnly: false
    property double fullyPresentSince: 0
    readonly property int minimumFullVisit: 8000
    property double hiddenUntil: 0
    property int exitAttempts: 0
    property var iceOpening: null
    property int annoyance: 0
    property double lastDisturbance: 0
    property double lastBalance: 0
    property bool pointerFresh: false
    property bool pointerReactionsEnabled: true
    property real pointerX: 0
    property real pointerY: 0
    property double nextPointerNotice: 0
    readonly property real pointerNoticeRadius: 420*(scene?.scale ?? 1)
    readonly property real nearbyClickRadius: 460*(scene?.scale ?? 1)
    readonly property bool pointerNearby: pointerFresh && pointerReactionsEnabled
        && permitted && visitActive && motionEnabled && !interactionHeld
        && !dragging && !retreating && !traveling && !directed
        && actor && !actor.gesturing && actor.reactionExpression!=="angry"
        && actor.presentation>.99 && requestedReveal>.99
        && Math.hypot(pointerX-actor.x+(actor.scale-1)*actor.width/2-(scene?.hostWidth ?? 0)/2,
            pointerY-actor.y+(actor.scale-1)*actor.height/2-(scene?.hostHeight ?? 0)/2)<=pointerNoticeRadius
    property real dragVelocityX: 0
    property real dragVelocityY: 0
    property double dragSampleTime: 0
    property int shakeReversals: 0
    property string pendingReaction: ""
    property real avoidX: 0
    property real avoidY: 0
    property string appearClip: "emerge"
    property string hideClip: "dive"
    readonly property real peekReveal: .64
    readonly property bool peeking: renderedReveal>0 && renderedReveal<.99
    property string mode: "fly"
    property int duration: 1000
    property real arc: 0
    property real normalX: 0
    property real normalY: -1
    readonly property real standingAngle: grounded ? emergenceEdge==="top" ? 180 : emergenceEdge==="left" ? 90 : emergenceEdge==="right" ? -90 : 0 : 0
    property real directionX: 1
    property real directionY: 0
    property bool surfaceDue: false
    property bool initialized: false
    readonly property bool qualified: Scene.valid(scene) && placement.qualified
    readonly property bool ballistic: traveling && ["jump","fall"].includes(mode)
    readonly property bool grounded: !dragging && (!traveling || ["walk","run"].includes(mode)) && !!placement.grounded
    readonly property string emergenceEdge: placement.support?.edge ?? placement.edge ?? "top"
    readonly property bool canExplore: permitted && visitActive && requestedReveal>.99
        && motionEnabled && !interactionHeld && !dragging && !retreating && Date.now()>=hiddenUntil
        && actor && !actor.hovered && actor.presentation>.99
    readonly property string surfaceKey: (scene?.surfaces ?? []).map(s=>s.key).join("|")
    signal resetRequested(real x, real y, string edge)
    signal stopRequested()
    signal settled()
    signal waterInteraction(var contact, string action)
    function disturb(action, selected): void {
        const contact=selected?.contact ?? null
        if (permitted && motionEnabled && contact) waterInteraction(contact,action)
    }

    function random(): real {
        randomState = (randomState*1664525+1013904223) % 4294967296
        return randomState/4294967296
    }
    function setReaction(expression, milliseconds = 3000): void {
        if (!actor) return
        actor.reactionExpression=expression
        reactionDeadline.interval=milliseconds;reactionDeadline.restart()
    }
    function chooseAppearance(selected): void {
        appearClip="emerge"
        const n=Scene.normal(selected.edge)
        if (!motionEnabled || !Scene.clearArc(scene,selected,selected,1.10*Math.max(scene.hostWidth,scene.hostHeight),n.nx,n.ny)) return
        const roll=random()
        appearClip=roll<.18 ? "launch" : roll<.32 ? "stuckLaunch" : roll<.46 ? "stuckJump" : roll<.62 ? "faceplant" : roll<.80 ? "buttplant" : "riseJump"
    }
    function position() {
        return actor ? {x:actor.x-(actor.scale-1)*actor.width/2,
            y:actor.y-(actor.scale-1)*actor.height/2} : {x:targetX,y:targetY}
    }
    function clearMotion(): void {
        stopRequested()
        traveling=false; releasedFlight=false; waypoints=[]; waypoint=0
    }
    function hideImmediately(): void {
        clearMotion()
        peekDeadline.stop(); peekIntro=false
        surfaceDeadline.stop(); surfaceDue=false
        recoveryDeadline.stop();reactionDeadline.stop()
        fullVisitDeadline.stop();fullyPresentSince=0
        if (actor) {actor.reactionExpression="";actor.stopGesture()}
        dragging=false; retreating=false; visitActive=false; renderedReveal=0
        resetRequested(targetX,targetY,emergenceEdge)
    }
    function appear(selected): void {
        if (!selected) selected=Scene.appearance(scene,random(),random(),random())
        if (!selected.qualified || !Scene.clearAt(scene,selected)) {hideImmediately();return}
        clearMotion()
        recoveryDeadline.stop()
        fullVisitDeadline.stop();fullyPresentSince=0
        placement=selected; destination=selected
        exitAttempts=0;iceOpening=null;chooseAppearance(selected)
        targetX=selected.x; targetY=selected.y
        retreating=false; visitActive=true
        resetRequested(targetX,targetY,selected.edge)
        peekDeadline.stop()
        peekIntro=motionEnabled && requestedReveal>.99
        peekOnly=peekIntro && random()<.28
        peekDeadline.interval=550+Math.floor(random()*450)
        renderedReveal=peekIntro || requestedReveal<.99 ? peekReveal : requestedReveal
        disturb(peekIntro || requestedReveal<.99 ? "peek" : "emerge",selected)
        scheduleSurface()
    }
    function synchronize(): void {
        if (!initialized) return
        if (!permitted || !Scene.valid(scene)) {hideImmediately();return}
        if (hiddenUntil>Date.now()) {
            if(!recoveryDeadline.running){recoveryDeadline.interval=Math.round(hiddenUntil-Date.now());recoveryDeadline.restart()}
            if (visitActive && !retreating) retreat()
            return
        }
        if (requestedReveal<=0) {
            // Native visit deadlines may expire during a long entrance or a
            // late surface reveal. Finish the entrance and grant a real visit.
            // Policy hides and deliberate peek-only withdrawals remain immediate.
            if (visitActive && !retreating && !peekOnly && !hiddenUntil && actor) {
                if (peekIntro) {peekIntro=false;peekDeadline.stop();renderedReveal=1}
                if (actor.presentation<.99 || !fullyPresentSince) return
                const remaining=minimumFullVisit-(Date.now()-fullyPresentSince)
                if (remaining>0) {fullVisitDeadline.interval=Math.ceil(remaining);fullVisitDeadline.restart();return}
            }
            if (visitActive && !retreating && !dragging) retreat()
            return
        }
        fullVisitDeadline.stop()
        if (!visitActive || retreating) {appear();return}
        if (requestedReveal<.99) {
            peekDeadline.stop(); peekIntro=false; renderedReveal=peekReveal
        } else if (!peekIntro) renderedReveal=requestedReveal
        if (requestedReveal<.99) pause()
    }
    function pause(force = false): void {
        if (!traveling || retreating || (!force && (ballistic || directed || releasedFlight))) return
        const here=position(), support=Scene.supportAt(scene,here)
        targetX=here.x; targetY=here.y
        clearMotion()
        placement=Scene.annotate(scene,here,placement.edge,placement.kind,placement.key)
    }
    function moveTo(selected, exit, preferredMode = ""): bool {
        if (!permitted || !actor || actor.presentation<.99 || dragging || (peekIntro && !exit)) return false
        const here=Object.assign(position(),{edge:emergenceEdge}), route=Scene.path(scene,here,selected)
        if (!route.qualified) return false
        disturb("depart",Scene.annotate(scene,here,placement.edge,placement.kind,placement.key))
        clearMotion()
        destination=selected; mode=exit ? "fly" : route.mode
        if (!exit && route.mode==="walk" && ["run","jump"].includes(preferredMode)) {
            if (preferredMode!=="jump" || Scene.clearArc(scene,here,selected,42*scene.scale,placement.support?.nx ?? 0,placement.support?.ny ?? -1)) mode=preferredMode
        } else if (!exit && preferredMode==="fall" && route.points.length===1
                && Math.abs(here.x-selected.x)<.1 && selected.y>here.y) mode="fall"
        retreating=!!exit; waypoints=route.points; waypoint=0
        traveling=true
        advance()
        return true
    }
    function advance(): void {
        if (!traveling || !permitted || !Scene.valid(scene)) return
        if (waypoint>=waypoints.length) {
            const exiting=retreating
            placement=destination; targetX=placement.x; targetY=placement.y
            traveling=false; releasedFlight=false; waypoints=[]
            if (exiting) {
                if (motionEnabled && exitAttempts===0 && random()<.14 && actor.perform("ice")) {
                    exitAttempts=1;iceOpening=placement;setReaction("surprised",2200);return
                }
                const exitRoll=random()
                hideClip=exitRoll<.40 ? "sink" : exitRoll<.64 ? "fallVanish" : "diveJump"
                const n=Scene.normal(placement.edge)
                if(hideClip==="diveJump" && !Scene.clearArc(scene,placement,placement,.38*Math.max(scene.hostWidth,scene.hostHeight),n.nx,n.ny)) hideClip="sink"
                if (hideClip==="sink" || hideClip==="fallVanish") setReaction("panicked",hideClip==="sink" ? 5600 : 3100)
                disturb(hideClip==="sink" ? "sink" : "dive",placement)
                visitActive=false; renderedReveal=0; surfaceDeadline.stop()
            } else {
                disturb("land",placement)
                if (placement.grounded && ["fall","jump","fly"].includes(mode) && motionEnabled)
                    actor.perform("land")
                settled()
            }
            return
        }
        const here=position(), next=waypoints[waypoint++]
        if (!Scene.clearSegment(scene,here,next)) {hideImmediately();return}
        directionX=next.x-here.x; directionY=next.y-here.y
        const speed=(retreating ? 300 : mode==="walk" ? 16 : mode==="run" ? 32 : 105)*scene.scale
        normalX=mode==="jump" ? placement.support?.nx ?? 0 : 0
        normalY=mode==="jump" ? placement.support?.ny ?? -1 : -1
        arc=mode==="jump" ? 42*scene.scale : mode==="fly" && !retreating
            && Scene.clearArc(scene,here,next,12*scene.scale) ? 12*scene.scale : 0
        duration=mode==="jump" ? 950 : mode==="fall"
            ? Math.max(240,Math.round(Math.sqrt(2*Math.max(0,next.y-here.y)/(1250*scene.scale))*1000))
            : Math.max(180,Math.round(Scene.distance(here,next)/speed*1000))
        targetX=next.x; targetY=next.y
        if (Math.abs(here.x-next.x)<.1 && Math.abs(here.y-next.y)<.1) Qt.callLater(root.arrived)
    }
    function arrived(): void {
        if (!traveling || dragging || !actor || actor.presentation<.99) return
        const here=position()
        if (Math.abs(here.x-targetX)>.2 || Math.abs(here.y-targetY)>.2) return
        advance()
    }
    function retreat(): void {
        peekDeadline.stop(); peekIntro=false
        if (!motionEnabled || !actor) {hideImmediately();return}
        if (actor.presentation<.99) {
            // A peek is already at its water opening: simply retract there.
            disturb("dive",placement)
            clearMotion();visitActive=false;renderedReveal=0;surfaceDeadline.stop();return
        }
        const water=Scene.nearestWater(scene,position(),iceOpening)
        if (!water.qualified || !moveTo(water.placement,true)) hideImmediately()
    }
    function explore(): void {
        if (!canExplore || traveling || directed || travelId===0) return
        const here=position(), support=Scene.supportAt(scene,here)
        let selected
        const roll=random()
        if (support && roll<.85) {
            const horizontal=support.axis==="x",span=horizontal ? scene.hostWidth : scene.hostHeight
            const along=Scene.clamp((horizontal ? here.x : here.y)+(travelFraction-.5)*240*scene.scale,
                support.from,support.to-span)
            selected=Scene.annotate(scene,horizontal ? {x:along,y:here.y} : {x:here.x,y:along},
                support.edge,placement.kind,placement.key)
        } else if (roll<.88) {
            // Float upwards into open space; a later drop/landing may walk again.
            selected=Scene.drop(scene,here.x+(travelFraction-.5)*130*scene.scale,
                here.y-(45+random()*80)*scene.scale,here)
        } else selected=Scene.appearance(scene,random(),random(),travelFraction)
        if (selected.qualified && Scene.distance(here,selected)>10*scene.scale) {
            const gait=random(), length=Scene.distance(here,selected)
            const movement=support && length>=35*scene.scale && length<=160*scene.scale && gait<.22 ? "jump"
                : personality!=="calm" && gait<(personality==="energetic" ? .78 : .48) ? "run" : "walk"
            moveTo(selected,false,movement)
        }
    }
    function scheduleSurface(): void {
        surfaceDeadline.stop(); surfaceDue=false
        if (permitted && visitActive && requestedReveal>.99 && surfaceKey)
            surfaceDeadline.start()
    }
    function offerSurface(): void {
        if (!surfaceDue || !canExplore || traveling || directed) return
        surfaceDue=false
        const candidates=Scene.surfacePoints(scene)
        // One 62% offer after a stable surface has remained open. Hover/task
        // holds defer the offer until released, without a polling timer.
        if (candidates.length && random()<.62)
            moveTo(candidates[Math.min(candidates.length-1,Math.floor(random()*candidates.length))],false)
    }
    function reconcileScene(): void {
        if (!permitted || !Scene.valid(scene)) {hideImmediately();return}
        if (!visitActive && requestedReveal>0 && !retreating) {if(Date.now()>=hiddenUntil)appear();return}
        if (!visitActive || dragging) return
        let from=position()
        const ride=Scene.ride(scene,from,placement)
        if (ride.qualified && Scene.distance(from,ride)>.25) {
            const oldKey=placement.support?.key,delta=Scene.distance(from,ride)
            clearMotion();placement=ride;destination=ride;targetX=ride.x;targetY=ride.y
            actor.carryTo(ride.x+(actor.scale-1)*actor.width/2,ride.y+(actor.scale-1)*actor.height/2)
            if (oldKey!==ride.key || delta>6*scene.scale) balance()
            return
        }
        if (!Scene.clearAt(scene,from)) {
            // A crowded rim may no longer fit. Recover through a clear nearby
            // opening rather than hiding the actor behind a growing body.
            const points=Scene.surfacePoints(scene)
            points.sort((a,b)=>Scene.distance(from,a)-Scene.distance(from,b))
            if (points.length) {
                const safe=points[0];clearMotion();placement=safe;destination=safe;targetX=safe.x;targetY=safe.y
                actor.carryTo(safe.x+(actor.scale-1)*actor.width/2,safe.y+(actor.scale-1)*actor.height/2);balance();return
            }
            hideImmediately();return
        }
        if (traveling) {
            for (let i=Math.max(0,waypoint-1);i<waypoints.length;i++) {
                if (!Scene.clearSegment(scene,from,waypoints[i])
                        || (arc>0 && !Scene.clearArc(scene,from,waypoints[i],arc,normalX,normalY))) {pause(true);return}
                from=waypoints[i]
            }
        } else {
            const support=Scene.supportAt(scene,from)
            placement=Scene.annotate(scene,from,placement.edge,placement.kind,placement.key)
        }
    }
    function beginDrag(): void {
        if (!permitted || !actor || !actor.inputReady || retreating) return
        pause(true);dragging=true;surfaceDeadline.stop()
        shakeReversals=0;dragVelocityX=0;dragVelocityY=0;dragSampleTime=Date.now()
    }
    function dragTo(x,y): void {
        if (!dragging || !permitted) return
        const previous=position(), point=Scene.drop(scene,x,y,previous)
        if (!point.qualified) return
        const now=Date.now(),dt=Math.max(8,now-dragSampleTime)
        const vx=(point.x-previous.x)/dt,vy=(point.y-previous.y)/dt
        if (Math.hypot(vx,vy)>.65*scene.scale && Math.hypot(dragVelocityX,dragVelocityY)>.65*scene.scale
                && vx*dragVelocityX+vy*dragVelocityY<0) {
            shakeReversals++;if (shakeReversals>=4) setReaction("angry",6000)
        }
        dragVelocityX=vx;dragVelocityY=vy;dragSampleTime=now
        directionX=point.x-previous.x; directionY=point.y-previous.y
        placement=point; destination=point; targetX=point.x; targetY=point.y
    }
    function endDrag(): void {
        if (!dragging) return
        dragging=false
        if (shakeReversals>=4) {annoyance=5;setReaction("angry",6000);hideForAWhile();return}
        reconcileScene()
        if (requestedReveal<=0) {retreat();return}
        if (motionEnabled && !placement.grounded) {
            const here=position(), floor=Scene.landingBelow(scene,here)
            if (floor.qualified && floor.y-here.y>60*scene.scale && random()<.55) {
                if (moveTo(floor,false,"fall")) return
            }
            // A released droplet may propel itself away; never walk in mid-air.
            const takeoff=Scene.drop(scene,here.x+(random()-.5)*180*scene.scale,
                here.y-(45+random()*55)*scene.scale,here)
            if (takeoff.qualified && Scene.distance(here,takeoff)>12*scene.scale
                    && moveTo(takeoff,false,"fly")) {releasedFlight=true;return}
            if (floor.qualified && moveTo(floor,false,"fall")) return
        }
        disturb("land",placement)
        if (placement.grounded && motionEnabled) actor.perform("land")
        scheduleSurface()
    }
    function hideForAWhile(): void {
        hiddenUntil=Date.now()+20000+Math.floor(random()*15000)
        recoveryDeadline.interval=Math.round(hiddenUntil-Date.now());recoveryDeadline.restart()
        retreat()
    }
    function evade(): void {
        if (!permitted || dragging || !motionEnabled || actor.presentation<.99) return
        let here=position(),dx=here.x+scene.hostWidth/2-avoidX,dy=here.y+scene.hostHeight/2-avoidY
        if (Math.hypot(dx,dy)<1) {dx=random()<.5 ? -1 : 1;dy=-.4}
        const length=Math.hypot(dx,dy),support=Scene.supportAt(scene,here,emergenceEdge)
        let next
        if (support) {
            const horizontal=support.axis==="x",axis=horizontal ? dx : dy,extent=horizontal ? scene.hostWidth : scene.hostHeight
            const along=Scene.clamp((horizontal ? here.x : here.y)+(axis>=0 ? 1 : -1)*100*scene.scale,support.from,support.to-extent)
            next=Scene.annotate(scene,horizontal ? {x:along,y:here.y} : {x:here.x,y:along},emergenceEdge,placement.kind,placement.key)
        } else next=Scene.drop(scene,here.x+dx/length*110*scene.scale,here.y+dy/length*90*scene.scale,here)
        if (next.qualified && moveTo(next,false,support ? "run" : "fly")) releasedFlight=true
    }
    function nearbyClick(x,y): void {
        if (!permitted || !visitActive || dragging || !motionEnabled || actor.presentation<.2) return
        const here=position()
        if (Math.hypot(x-here.x-scene.hostWidth/2,y-here.y-scene.hostHeight/2)>nearbyClickRadius) return
        const now=Date.now();annoyance=now-lastDisturbance<4500 ? annoyance+1 : 1;lastDisturbance=now
        avoidX=x;avoidY=y;pause(true)
        if (annoyance>=5) {
            setReaction("angry",7000)
            if (random()<.55) hideForAWhile();else evade()
        } else if (random()<.5) {
            setReaction("surprised",2400);pendingReaction="evade";actor.perform("startle")
        } else {setReaction("happy",2500);pendingReaction="";actor.perform("delight")}
    }
    function offerPointerNotice(): void {
        pointerNotice.stop()
        if (!pointerNearby || Date.now()<nextPointerNotice) return
        pointerNotice.interval=650+Math.floor(random()*500)
        pointerNotice.start()
    }
    function noticePointer(): void {
        if (!pointerNearby || Date.now()<nextPointerNotice) return
        const now=Date.now(), chance=personality==="energetic" ? .6 : personality==="calm" ? .25 : .4
        nextPointerNotice=now+12000+Math.floor(random()*13000)
        // Passive presence is not a disturbance. Only explicit clicks and
        // shaking accumulate annoyance; movement/working keep their attention.
        if (random()>chance) return
        const response=random()
        if (response<.22) {
            avoidX=pointerX;avoidY=pointerY;pendingReaction="evade"
            setReaction("surprised",2400);actor.perform("startle")
        } else if (response<.65) {setReaction("happy",2400);actor.perform("wave")}
        else {setReaction("thinking",2200);actor.perform("inspect")}
    }
    function balance(): void {
        if (!motionEnabled || dragging || !visitActive || Date.now()-lastBalance<5500 || !grounded) return
        lastBalance=Date.now()
        if (actor.perform("balance")) setReaction("surprised",1800)
    }
    function gestureFinished(action): void {
        if (action==="ice" && retreating && (requestedReveal<=0 || hiddenUntil>Date.now())) {
            const water=Scene.nearestWater(scene,position(),iceOpening)
            if (water.qualified && moveTo(water.placement,true)) return
            hideClip="sink";disturb("dive",placement);visitActive=false;renderedReveal=0;return
        }
        if (action==="startle" && pendingReaction==="evade") {pendingReaction="";evade()}
        if (action==="balance" && permitted && !dragging && random()<.18) {
            const floor=Scene.landingBelow(scene,position())
            if (floor.qualified && floor.y-position().y>90*scene.scale) {
                setReaction("panicked",2200);moveTo(floor,false,"fall")
            }
        }
    }
    onPermittedChanged: Qt.callLater(root.synchronize)
    onPointerNearbyChanged: root.offerPointerNotice()
    onRequestedRevealChanged: Qt.callLater(root.synchronize)
    onSceneChanged: Qt.callLater(root.reconcileScene)
    onSurfaceKeyChanged: root.scheduleSurface()
    onTravelIdChanged: Qt.callLater(root.explore)
    onInteractionHeldChanged: if (interactionHeld) Qt.callLater(root.pause)
    onCanExploreChanged: {
        if (!canExplore && !retreating) Qt.callLater(root.pause)
        else Qt.callLater(root.offerSurface)
    }
    onMotionEnabledChanged: if (!motionEnabled) {
        peekDeadline.stop();peekIntro=false
        if (requestedReveal>.99 && visitActive) renderedReveal=1
        if (retreating) hideImmediately()
        else pause(true)
    }
    Component.onCompleted: {initialized=true;Qt.callLater(root.synchronize)}
    Connections {
        target: root.actor
        function onGestureCompleted(action): void {root.gestureFinished(action)}
        function onPresentationChanged(): void {
            if (root.visitActive && !root.peekIntro && !root.peekOnly && root.renderedReveal>.99
                    && root.actor.presentation>.99 && !root.fullyPresentSince) {
                root.fullyPresentSince=Date.now()
                Qt.callLater(root.synchronize)
            }
        }
    }
    Timer {id:fullVisitDeadline;objectName:"wullFullVisitDeadline";repeat:false;onTriggered:root.synchronize()}
    Timer {id:reactionDeadline;interval:3000;onTriggered:if(root.actor) root.actor.reactionExpression=""}
    Timer {
        id: pointerNotice
        objectName: "wullPointerNoticeDeadline"
        repeat: false
        onTriggered: root.noticePointer()
    }
    Timer {id:recoveryDeadline;interval:20000;onTriggered:{
        root.hiddenUntil=0
        if(root.permitted && root.requestedReveal>0) root.appear()
    }}
    Connections {
        target: root.actor
        enabled: root.peekIntro && !peekDeadline.running
        function onPresentationChanged(): void {
            if (root.actor && Math.abs(root.actor.presentation-root.peekReveal)<.005) peekDeadline.start()
        }
    }
    Timer {
        id: peekDeadline
        objectName: "wullPeekDeadline"
        repeat: false
        onTriggered: {
            if (root.permitted && root.visitActive && root.requestedReveal>.99) {
                root.peekIntro=false
                if (root.peekOnly) {
                    root.disturb("dive",root.placement);root.visitActive=false;root.renderedReveal=0
                    root.hiddenUntil=Date.now()+2200;recoveryDeadline.interval=2200;recoveryDeadline.restart()
                } else {root.renderedReveal=1;root.disturb("emerge",root.placement)}
            }
        }
    }
    Timer {
        id: surfaceDeadline
        objectName: "wullSurfaceDeadline"
        repeat: false
        interval: 12000
        onTriggered: {root.surfaceDue=true;root.offerSurface()}
    }
}
