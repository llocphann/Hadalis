import QtQuick
import "WullScene.js" as Scene
import "CompanionMotion.js" as Motion

// One visible body. The next resident emerges from the same water opening
// only after the outgoing body has completely disappeared.
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
    readonly property bool paired: false
    property string outgoing: "aqua"
    readonly property string incoming: Motion.other(outgoing)
    property var replacementPlacement: ({qualified:false})
    readonly property real progress: active ? Math.max(0,Math.min(1,1-actor.presentation)) : 0
    readonly property bool pulling: active && outgoing==="aqua"
    signal characterChosen(string character)
    signal starting()
    function begin(exiting=false): bool {
        if (active || !enabledPolicy || !presence.qualified || !presence.visitActive || actor.presentation<.99
                || presence.dragging || presence.traveling || presence.directed || actor.gesturing || actor.hovered || interactionHeld) return false
        const point=Scene.annotate(presence.scene,presence.position(),presence.emergenceEdge,
            presence.placement.kind,presence.placement.key)
        if (!point.qualified || !point.grounded) return false
        offer.stop();due=false;outgoing=actor.character
        replacementPlacement=point;active=true;starting()
        presence.beginTurn(outgoing==="octo" ? "sink" : "pulled")
        return true
    }
    function finish(): void {
        if (!active || actor.presentation>0 || actor.visible) return
        const next=incoming,point=replacementPlacement
        active=false
        characterChosen(next)
        presence.finishTurn(point)
        if(eligible)offer.restart()
    }
    function cancel(): void {
        offer.stop();due=false
        if(!active)return
        active=false;presence.handoffActive=false
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
            if(root.active && (!Scene.clearAt(root.presence.scene,root.replacementPlacement)
                    || !Scene.supportAt(root.presence.scene,root.replacementPlacement,root.replacementPlacement.edge)))root.cancel()
        }
    }
    Connections {
        target:root.actor
        function onPresentationChanged(): void {if(root.active && root.actor.presentation===0)Qt.callLater(root.finish)}
    }
    Timer {id:offer;objectName:"companionTurnDeadline";interval:root.offerInterval;repeat:false;onTriggered:{root.due=true;root.offerTurn()}}
}
