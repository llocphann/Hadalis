import QtQuick
import "WullScene.js" as Scene

// Semantic wander events only. One finite deadline exists during an owned
// visit; a pointer hand-off releases ownership without dismissing the UI.
Item {
    id: root
    property var presence: null
    property var actor: null
    property var adapter: null
    property var features: []
    property bool allowed: false
    property bool idle: false
    property double eventId: 0
    property double lastVisit: 0
    property int cooldown: 90000
    property string stage: ""
    property var feature: null
    property bool owned: false
    property bool reachedFeature: false
    readonly property bool busy: stage!==""
    readonly property var scene: presence?.scene ?? null
    readonly property string surfaceKey: presence?.surfaceKey ?? ""
    readonly property var featureBounds: {
        if (!owned || !feature) return null
        const key=adapter?.companionSurfaceKey ? adapter.companionSurfaceKey(feature) : feature.key
        return (scene?.surfaces ?? []).find(s=>s.key===key)?.rect ?? null
    }
    readonly property bool nearFeature: {
        if (!featureBounds || !actor || !scene) return false
        const p=presence.position(), r=featureBounds
        const dx=Math.max(r.x-p.x-scene.hostWidth,p.x-r.x-r.width,0)
        const dy=Math.max(r.y-p.y-scene.hostHeight,p.y-r.y-r.height,0)
        return Math.hypot(dx,dy)<=140*scene.scale
    }
    signal visitFinished(string kind, bool handedToUser)

    function finish(closeOwned = false, handedToUser = false, keepMotion = false): void {
        deadline.stop()
        const completedFeature=feature, kind=feature?.kind ?? "", hadOwnership=owned
        owned=false;stage="";feature=null;reachedFeature=false
        if (presence) {presence.directed=false;if (!keepMotion) presence.pause(true)}
        if (actor && !keepMotion) actor.stopGesture()
        // Clear ownership before semantic close signals fire; they describe
        // our own close, not a second human hand-off.
        if (closeOwned && hadOwnership && adapter && adapter.ownsCompanionFeature(completedFeature))
            adapter.closeCompanionFeature(completedFeature)
        else if (hadOwnership && adapter) adapter.releaseCompanionFeature(completedFeature)
        if (kind) visitFinished(kind,handedToUser)
    }
    function yieldToUser(): void { if (busy) finish(false,true) }
    function interrupt(): void { if (busy) finish(true) }
    function containsPoint(x,y): bool {
        const r=featureBounds
        return !!r && x>=r.x-12 && x<=r.x+r.width+12 && y>=r.y-12 && y<=r.y+r.height+12
    }
    function pointerMoved(x,y): void {
        if (containsPoint(x,y)) yieldToUser()
    }
    function checkProximity(): void {
        if (!owned) return
        if (nearFeature) reachedFeature=true
        // The initial approach may start farther away. Once Wull reaches the
        // opened surface, leaving it releases only its own lease and preserves
        // the departure animation. Human hover has already revoked ownership.
        else if (reachedFeature) finish(true,false,true)
    }
    function checkOwnership(): void {
        if (owned && (!adapter || !adapter.ownsCompanionFeature(feature))) finish(false,true)
    }
    function offer(): bool {
        if (!allowed || !idle || busy || !presence?.canExplore || presence.traveling
                || actor.gesturing || !adapter || !adapter.companionFeaturesIdle()
                || !features.length || Date.now()-lastVisit<cooldown) return false
        // Modest chance per existing native decision, with a shared cooldown.
        if (presence.random()>.18) return false
        const candidate=features[Math.min(features.length-1,Math.floor(presence.random()*features.length))]
        const extent=candidate.edge==="top" || candidate.edge==="bottom" ? scene.width : scene.height
        const point=Scene.edgePoint(scene,candidate.edge,candidate.along/extent)
        if (!point.qualified) return false
        lastVisit=Date.now();reachedFeature=false;feature=candidate;stage="approach";presence.directed=true
        deadline.interval=22000;deadline.start()
        if (!presence.moveTo(point,false)) {finish();return false}
        if (!presence.traveling) arrived()
        return true
    }
    function arrived(): void {
        if (!busy || !allowed || !idle || presence.dragging) {if (busy) finish(true);return}
        if (stage==="approach") {
            if (!adapter.companionFeaturesIdle()) {finish();return}
            stage="openGesture"
            if (!actor.perform(feature.openGesture)) finish()
        } else if (stage==="visit") {
            stage="inspect"
            if (!actor.perform(feature.gesture)) startHold()
        } else if (stage==="return") {
            stage="closeGesture"
            if (!actor.perform(feature.openGesture)) finish(true)
        } else if (stage==="depart") finish(true,false,true)
    }
    function gestureFinished(): void {
        if (stage==="openGesture") {
            if (!allowed || !idle || !adapter.companionFeaturesIdle()) {finish();return}
            // Set the stage before the real host mutates its semantic state.
            stage="settling"
            owned=adapter.openCompanionFeature(feature)
            if (!owned) {finish();return}
            deadline.interval=7000;deadline.restart()
            Qt.callLater(root.visitSurface)
        } else if (stage==="inspect") startHold()
        else if (stage==="closeGesture") finish(true)
    }
    function visitSurface(): void {
        if (stage!=="settling" || !owned || actor.presentation<.99) return
        checkOwnership()
        if (!owned) return
        const key=adapter.companionSurfaceKey ? adapter.companionSurfaceKey(feature) : feature.key
        const points=Scene.surfacePoints(scene).filter(p=>p.key===key)
        if (!points.length) return
        points.sort((a,b)=>Scene.distance(presence.position(),a)-Scene.distance(presence.position(),b))
        stage="visit";deadline.interval=22000;deadline.restart()
        if (!presence.moveTo(points[0],false)) startHold()
    }
    function startHold(): void {
        stage="hold";deadline.interval=4000+Math.floor(presence.random()*2500);deadline.restart()
    }
    function returnToEdge(): void {
        checkOwnership()
        if (!owned) return
        const extent=feature.edge==="top" || feature.edge==="bottom" ? scene.width : scene.height
        const point=Scene.edgePoint(scene,feature.edge,feature.along/extent)
        stage="return";deadline.interval=22000;deadline.restart()
        if (!point.qualified || !presence.moveTo(point,false)) finish(true)
    }
    function departureStarted(): void {
        if (!owned || stage!=="depart") return
        // Keep one bounded visit deadline while an external movement leaves
        // the surface. The old hold must not commandeer this new route.
        let from=presence.position(), distance=0
        for (let i=Math.max(0,presence.waypoint-1);i<presence.waypoints.length;i++) {
            const next=presence.waypoints[i];distance+=Scene.distance(from,next);from=next
        }
        const speed=(presence.mode==="walk" ? 16 : presence.mode==="run" ? 32 : 105)*scene.scale
        deadline.interval=Math.min(30000,Math.max(3000,Math.ceil(distance/speed*1000)+2000));deadline.restart()
    }
    function beginDeparture(): void {
        deadline.stop();stage="depart";presence.directed=false
        actor.stopGesture()
        Qt.callLater(root.departureStarted)
    }
    onEventIdChanged: if (eventId>0) root.offer()
    onAllowedChanged: if (!allowed) root.finish(true)
    onIdleChanged: if (!idle) root.finish(true)
    onSurfaceKeyChanged: Qt.callLater(root.visitSurface)
    onNearFeatureChanged: Qt.callLater(root.checkProximity)
    onOwnedChanged: if (owned) Qt.callLater(root.checkProximity)
    Connections {
        target: root.presence
        function onSettled(): void {root.arrived()}
        function onDraggingChanged(): void {if (root.presence.dragging) root.interrupt()}
        function onTravelingChanged(): void {
            if (root.presence.traveling && root.owned && ["settling","inspect","hold"].includes(root.stage)) {
                root.beginDeparture()
            }
        }
    }
    Connections {
        target: root.actor
        function onPresentationChanged(): void {if (root.stage==="settling") root.visitSurface()}
        function onGestureCompleted(action): void {root.gestureFinished()}
        function onHoveredChanged(): void {if (root.actor.hovered) root.interrupt()}
    }
    Timer {
        id: deadline
        objectName: "wullCuriosityDeadline"
        repeat: false
        onTriggered: if (root.stage==="hold") root.returnToEdge(); else root.finish(true,false,root.stage==="depart")
    }
}
