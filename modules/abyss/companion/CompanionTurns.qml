import QtQuick
import "WullScene.js" as Scene
import "CompanionMotion.js" as Motion

// One interactive resident and a short-lived, noninteractive challenger in
// the existing output window. Both rigs read the resident's finite clock.
Item {
    id: root
    required property var presence
    required property var actor
    property bool allowed: false
    property bool alternating: false
    property bool interactionHeld: false
    property int offerInterval: 45000
    readonly property bool enabledPolicy: allowed && alternating && presence.permitted && actor.motionEnabled
    readonly property bool eligible: enabledPolicy && presence.qualified && presence.visitActive
        && presence.requestedReveal>.99 && actor.presentation>.99 && !active
        && !presence.dragging && !presence.traveling && !presence.retreating
        && !presence.directed && !actor.gesturing && !actor.hovered && !interactionHeld
    property bool active: false
    property bool due: false
    property bool paired: false
    property string outgoing: "aqua"
    readonly property string incoming: Motion.other(outgoing)
    property var guestPlacement: ({qualified:false})
    readonly property real progress: active ? Math.max(0,Math.min(1,1-actor.presentation)) : 0
    readonly property real guestReveal: paired ? Math.min(1,progress/.16) : 0
    signal characterChosen(string character)
    signal starting()
    function neighbor(): var {
        const scene=presence.scene,here=presence.position(),support=Scene.supportAt(scene,here,presence.emergenceEdge)
        if (!support) return {qualified:false}
        const horizontal=support.axis==="x",extent=horizontal ? scene.hostWidth : scene.hostHeight
        const preferred=["top","right"].includes(support.edge) ? 1 : -1
        for (const sign of [preferred,-preferred]) {
            const p={x:here.x+(horizontal ? sign*(extent+12*scene.scale) : 0),y:here.y+(horizontal ? 0 : sign*(extent+12*scene.scale))}
            const candidate=Scene.annotate(scene,p,support.edge,presence.placement.kind,presence.placement.key)
            if (candidate.qualified && candidate.grounded && candidate.support?.key===support.key
                    && candidate.support?.edge===support.edge) return candidate
        }
        return {qualified:false}
    }
    function begin(exiting=false): bool {
        if (active || !enabledPolicy || !presence.qualified || !presence.visitActive || actor.presentation<.99
                || presence.dragging || presence.traveling || presence.directed || actor.gesturing || actor.hovered || interactionHeld) return false
        const guest=neighbor()
        // Crowded rims get a sequential exchange. Never overlay a second body
        // on a popup merely to force the rivalry scene to play.
        if (!guest.qualified && !exiting) {due=false;offer.restart();return false}
        offer.stop();due=false;outgoing=actor.character
        guestPlacement=guest.qualified ? guest : presence.placement
        paired=guest.qualified;active=true;starting()
        if(paired)presence.disturb("emerge",guestPlacement)
        presence.beginTurn(paired ? outgoing==="octo" ? "sink" : "pulled" : "dive")
        return true
    }
    function finish(): void {
        if (!active) return
        const next=incoming,point=guestPlacement
        active=false;paired=false
        characterChosen(next)
        presence.finishTurn(point)
        if(eligible)offer.restart()
    }
    function cancel(): void {
        offer.stop();due=false
        if(!active)return
        active=false;paired=false;presence.handoffActive=false
        presence.hideImmediately()
        Qt.callLater(presence.synchronize)
    }
    function offerTurn(): void {if(due && eligible)begin()}
    onEligibleChanged: {
        if(eligible){if(due)Qt.callLater(root.offerTurn);else if(!offer.running)offer.start()}
    }
    onEnabledPolicyChanged: if(!enabledPolicy)cancel()
    onInteractionHeldChanged: if(interactionHeld && active)cancel()
    Connections {
        target:root.presence
        function onVisitActiveChanged(): void {if(!root.presence.visitActive && !root.active){offer.stop();root.due=false}}
        function onHandoffRequested(): void {root.begin(true)}
        function onSceneChanged(): void {
            if(root.active && (!Scene.clearAt(root.presence.scene,root.presence.position())
                    || (root.paired && (!Scene.clearAt(root.presence.scene,root.guestPlacement)
                        || !Scene.supportAt(root.presence.scene,root.guestPlacement,root.guestPlacement.edge)))))root.cancel()
        }
    }
    Connections {
        target:root.actor
        function onPresentationChanged(): void {if(root.active && root.actor.presentation<=.001)Qt.callLater(root.finish)}
    }
    Timer {id:offer;objectName:"companionTurnDeadline";interval:root.offerInterval;repeat:false;onTriggered:{root.due=true;root.offerTurn()}}
}
