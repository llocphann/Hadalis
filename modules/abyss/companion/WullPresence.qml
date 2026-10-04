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
    readonly property real peekReveal: .72
    readonly property bool peeking: renderedReveal>0 && renderedReveal<.99
    property string mode: "fly"
    property int duration: 1000
    property real arc: 0
    property real directionX: 1
    property real directionY: 0
    property bool surfaceDue: false
    property bool initialized: false
    readonly property bool qualified: Scene.valid(scene) && placement.qualified
    readonly property bool ballistic: traveling && ["jump","fall"].includes(mode)
    readonly property bool grounded: !dragging && (!traveling || ["walk","run"].includes(mode)) && !!placement.grounded
    readonly property string emergenceEdge: placement.edge ?? "top"
    readonly property bool canExplore: permitted && visitActive && requestedReveal>.99
        && motionEnabled && !interactionHeld && !dragging && !retreating
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
        dragging=false; retreating=false; visitActive=false; renderedReveal=0
        resetRequested(targetX,targetY,emergenceEdge)
    }
    function appear(selected): void {
        if (!selected) selected=Scene.appearance(scene,random(),random(),random())
        if (!selected.qualified || !Scene.clearAt(scene,selected)) {hideImmediately();return}
        clearMotion()
        placement=selected; destination=selected
        targetX=selected.x; targetY=selected.y
        retreating=false; visitActive=true
        resetRequested(targetX,targetY,selected.edge)
        peekDeadline.stop()
        peekIntro=motionEnabled && requestedReveal>.99
        peekDeadline.interval=550+Math.floor(random()*450)
        renderedReveal=peekIntro || requestedReveal<.99 ? peekReveal : requestedReveal
        disturb(peekIntro || requestedReveal<.99 ? "peek" : "emerge",selected)
        scheduleSurface()
    }
    function synchronize(): void {
        if (!initialized) return
        if (!permitted || !Scene.valid(scene)) {hideImmediately();return}
        if (requestedReveal<=0) {
            if (visitActive && !retreating && !dragging) retreat()
            return
        }
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
        const here=position(), route=Scene.path(scene,here,selected)
        if (!route.qualified) return false
        disturb("depart",Scene.annotate(scene,here,placement.edge,placement.kind,placement.key))
        clearMotion()
        destination=selected; mode=exit ? "fly" : route.mode
        if (!exit && route.mode==="walk" && ["run","jump"].includes(preferredMode)) {
            if (preferredMode!=="jump" || Scene.clearArc(scene,here,selected,42*scene.scale)) mode=preferredMode
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
                // The host's Blender dive now goes through the nearest water rim.
                disturb("dive",placement)
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
        const speed=(retreating ? 300 : mode==="walk" ? 32 : mode==="run" ? 70 : 105)*scene.scale
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
        const water=Scene.nearestWater(scene,position())
        if (!water.qualified || !moveTo(water.placement,true)) hideImmediately()
    }
    function explore(): void {
        if (!canExplore || traveling || directed || travelId===0) return
        const here=position(), support=Scene.supportAt(scene,here)
        let selected
        const roll=random()
        if (support && roll<.58) {
            const x=Scene.clamp(here.x+(travelFraction-.5)*320*scene.scale,
                Math.max(2,support.from),Math.min(scene.width-scene.hostWidth-2,support.to-scene.hostWidth))
            selected=Scene.annotate(scene,{x:x,y:here.y},emergenceEdge,placement.kind,placement.key)
        } else if (roll<.78) {
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
        if (!visitActive && requestedReveal>0 && !retreating) {appear();return}
        if (!visitActive || dragging) return
        let from=position()
        if (!Scene.clearAt(scene,from)) {appear();return}
        if (traveling) {
            for (let i=Math.max(0,waypoint-1);i<waypoints.length;i++) {
                if (!Scene.clearSegment(scene,from,waypoints[i])
                        || (arc>0 && !Scene.clearArc(scene,from,waypoints[i],arc))) {pause(true);return}
                from=waypoints[i]
            }
        } else {
            const support=Scene.supportAt(scene,from)
            placement=Scene.annotate(scene,from,placement.edge,placement.kind,placement.key)
        }
    }
    function beginDrag(): void {
        if (!permitted || !actor || !actor.inputReady || retreating) return
        pause(true); dragging=true; surfaceDeadline.stop()
    }
    function dragTo(x,y): void {
        if (!dragging || !permitted) return
        const previous=position(), point=Scene.drop(scene,x,y,previous)
        if (!point.qualified) return
        directionX=point.x-previous.x; directionY=point.y-previous.y
        placement=point; destination=point; targetX=point.x; targetY=point.y
    }
    function endDrag(): void {
        if (!dragging) return
        dragging=false
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
    onPermittedChanged: Qt.callLater(root.synchronize)
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
                root.peekIntro=false;root.renderedReveal=1
                root.disturb("emerge",root.placement)
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
