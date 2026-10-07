import QtQuick

Loader {
    id:root
    required property var turns
    required property var actor
    active:turns.active && turns.paired
    sourceComponent:AbyssCompanion {
        character:root.turns.incoming
        interactive:false;dragEnabled:false;presentationManaged:true
        reveal:1;presentation:root.turns.guestReveal
        scale:root.actor.scale;transformOrigin:Item.Center
        upright:true;managedPlacement:false;connectedWater:true
        emergenceEdge:root.turns.guestPlacement.edge ?? "bottom"
        standingAngle:emergenceEdge==="top" ? 180 : emergenceEdge==="left" ? 90 : emergenceEdge==="right" ? -90 : 0
        x:root.turns.guestPlacement.x+(scale-1)*implicitWidth/2
        y:root.turns.guestPlacement.y+(scale-1)*implicitHeight/2
        pairedAction:character==="octo" ? "pull" : "push"
        pairedProgress:root.turns.progress
        readonly property real dx:root.turns.presence.targetX-root.turns.guestPlacement.x
        readonly property real dy:root.turns.presence.targetY-root.turns.guestPlacement.y
        travelDirection:dx/Math.max(1,Math.hypot(dx,dy))
        travelDirectionY:dy/Math.max(1,Math.hypot(dx,dy))
        motionEnabled:root.actor.motionEnabled;effectsEnabled:root.actor.effectsEnabled
        motionScale:root.actor.motionScale;renderQuality:root.actor.renderQuality;translucency:root.actor.translucency
        expression:"excited"
    }
}
