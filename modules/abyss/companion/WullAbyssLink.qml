import QtQuick
import qs.modules.abyss.looks
import "WullScene.js" as Scene
import "../looks/AbyssWave.js" as Wave

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
        ? Qt.vector4d(origin.nx,origin.ny,actor.leaving && actor.hideClip==="sink" ? 1 : 0,
            actor.leaving ? 1-actor.presentation : actor.presentation) : Qt.vector4d(0,0,0,0)
    readonly property vector4d ripple: enabledPolicy && impact && phase<1
        ? Qt.vector4d(impact.x,impact.y,phase,strength) : Qt.vector4d(0,0,1,0)
    readonly property vector4d rippleNormal: enabledPolicy && impact && phase<1
        ? Qt.vector4d(impact.nx,impact.ny,impact.scale,0) : Qt.vector4d(0,0,0,0)
    function disturb(point, action): void {
        if (!enabledPolicy || !point || ![point.x,point.y,point.nx,point.ny,point.scale].every(Scene.finite)
                || point.scale<=0 || Math.abs(Math.hypot(point.nx,point.ny)-1)>.001) return
        pulse.stop()
        impact=point
        strength=action==="sink" || action==="dive" ? 1 : action==="emerge" ? .85 : action==="peek" ? .5 : .32
        pulse.duration=action==="sink" ? 5800 : 1450
        phase=0;eventCount++
        pulse.start()
        // The same circular solver that responds to Popup/Sidebar entry carries
        // a small disturbance through the parent screen edge, if waves are on.
        const closing=action==="sink" || action==="dive" || action==="depart"
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
    Connections {
        target: root.controller?.waves ?? null
        enabled: root.enabledPolicy && root.presence?.grounded === true
        function onRevisionChanged(): void {
            const waves=root.controller?.waves,state=waves?.simulation,point=root.origin
            if (!waves?.running || !state || !point || Date.now()-root.presence.lastBalance<5500) return
            // Sample the existing solver at the contact, without another frame
            // timer, array copy, IPC message or a new wave implementation.
            const location=Wave.arc(point.sourceEdge,point.sourceAlong,state.width,state.height)/state.length*state.count
            const index=Math.floor(location)%state.count,next=(index+1)%state.count
            const displacement=state.displacement[index]*(1-(location-index))+state.displacement[next]*(location-index)
            if (Math.abs(displacement)>.7*point.scale) root.presence.balance()
        }
    }
    NumberAnimation {id:pulse;target:root;property:"phase";to:1;duration:1450}
}
