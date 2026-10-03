import QtQuick
import qs.modules.abyss.looks
import "WullScene.js" as Scene

// A contact in the existing field, not a second painted surface or window.
// One finite impulse envelope; the liquid neck shares Wull's presentation clock.
Item {
    id: root
    property var presence: null
    property var actor: null
    property var controller: null
    property bool allowed: false
    readonly property bool enabledPolicy: allowed && presence?.permitted === true
        && actor?.motionEnabled === true && actor?.effectsEnabled === true
    property var impact: null
    property real phase: 1
    property real strength: 0
    property int eventCount: 0
    readonly property bool running: pulse.running
    readonly property var origin: presence?.placement?.contact ?? null
    readonly property real neck: enabledPolicy && origin && actor.visible
        && actor.presentation>.001 && actor.presentation<.999
        ? Math.sin(Math.PI*Math.max(0,Math.min(1,actor.presentation))) : 0
    readonly property vector4d contact: neck>.001
        ? Qt.vector4d(origin.x,origin.y,origin.scale,neck) : Qt.vector4d(0,0,0,0)
    readonly property vector4d contactNormal: neck>.001
        ? Qt.vector4d(origin.nx,origin.ny,0,0) : Qt.vector4d(0,0,0,0)
    readonly property vector4d ripple: enabledPolicy && impact && phase<1
        ? Qt.vector4d(impact.x,impact.y,phase,strength) : Qt.vector4d(0,0,1,0)
    readonly property vector4d rippleNormal: enabledPolicy && impact && phase<1
        ? Qt.vector4d(impact.nx,impact.ny,impact.scale,0) : Qt.vector4d(0,0,0,0)
    function disturb(point, action): void {
        if (!enabledPolicy || !point || ![point.x,point.y,point.nx,point.ny,point.scale].every(Scene.finite)
                || point.scale<=0 || Math.abs(Math.hypot(point.nx,point.ny)-1)>.001) return
        pulse.stop()
        impact=point
        strength=action==="dive" ? 1 : action==="emerge" ? .85 : action==="peek" ? .5 : .32
        phase=0;eventCount++
        pulse.start()
        // The same circular solver that responds to Popup/Sidebar entry carries
        // a small disturbance through the parent screen edge, if waves are on.
        const closing=action==="dive" || action==="depart"
        controller?.impulse(point.sourceEdge,point.sourceAlong,point.span,
            (closing ? -.25 : .3)*strength,1,closing ? "close" : "open")
    }
    function tap(): void {
        if (presence) disturb(Scene.waterContact(presence.scene,presence.placement,presence.position()),"tap")
    }
    function cancel(): void {pulse.stop();phase=1;impact=null;strength=0}
    onEnabledPolicyChanged: if (!enabledPolicy) cancel()
    Connections {
        target: root.presence
        function onWaterInteraction(point, action): void {root.disturb(point,action)}
    }
    NumberAnimation {id:pulse;target:root;property:"phase";to:1;duration:1450}
}
