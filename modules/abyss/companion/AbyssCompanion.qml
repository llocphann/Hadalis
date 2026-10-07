import QtQuick
import QtQuick.Shapes
import qs.modules.abyss.looks
import qs.modules.common
import "WullExpressions.js" as Expressions
import "CompanionMotion.js" as Motion
import "WullAttention.js" as Attention

Item {
    id: root
    property string character: "aqua"
    readonly property var curves: Motion.forCharacter(character)
    property bool presentationManaged: false
    property string pairedAction: ""
    property real pairedProgress: -1
    property string edge: "top"
    property real edgeOffset: 120
    property real reveal: 1
    property real gazeX: 0
    property real gazeY: 0
    property real energy: 0.45
    property real bodySquash: 0
    property real bodyStretch: 0
    property real bodyLean: 0
    property real bodyTip: 0
    property real ripple: 0
    property real eyeOpen: 1
    property real mouthCurve: 0.12
    property real pulse: 0
    property string expression: ""
    property string mood: "calm"
    property string activity: "idle"
    property bool interactive: true
    property bool motionEnabled: AbyssStyle.motionEnabled
    property bool effectsEnabled: Appearance.effectsEnabled && AbyssStyle.quality !== "performance"
    property real motionScale: 1
    property string renderQuality: "quality"
    property real translucency: 0.16
    property bool travelEnabled: false
    property string travelMode: "walk"
    property bool surfaceSupported: true
    property int travelDuration: 1000
    property real travelArc: 0
    property real travelNormalX: 0
    property real travelNormalY: -1
    property real standingAngle: 0
    property string appearClip: "emerge"
    property real appearanceOffsetX: 0
    property real appearanceOffsetY: 0
    readonly property bool appearanceArcActive:
        !leaving && !peeking && appearClip!=="emerge"
        && presentation<.999
        && Math.hypot(appearanceOffsetX,appearanceOffsetY)>.1
    readonly property real appearanceJourney: appearanceArcActive ? presentation : 1
    property string hideClip: "dive"
    property string reactionExpression: ""
    readonly property real tangentDirection: travelDirection*Math.cos(standingAngle*Math.PI/180)+travelDirectionY*Math.sin(standingAngle*Math.PI/180)
    property real travelPhase: 0
    property real travelFromX: 0
    property real travelFromY: 0
    property real travelToX: 0
    property real travelToY: 0
    property string gesture: ""
    property real gesturePhase: 1
    readonly property string presentationAction: presentation<.999 && !peeking ? (leaving ? hideClip : appearClip) : ""
    readonly property string motionAction: pairedAction || (dragging ? "drag" : moving ? travelMode : gesture || presentationAction)
    readonly property string faceExpression: Expressions.resolve(reactionExpression || expression,mood,activity)
    property real travelDirection: 1
    property real travelDirectionY: 0
    property bool pointerFresh: false
    property real pointerX: 0
    property real pointerY: 0
    property bool dragEnabled: false
    property bool hardResetting: false
    property real dragStartX: 0
    property real dragStartY: 0
    readonly property bool dragging: dragHandler.active
    property string emergenceEdge: edge
    property bool upright: false
    property bool connectedWater: false
    property real presentation: 0
    readonly property bool peeking: reveal>0 && reveal<.99
    property real floorAlignment: upright && surfaceSupported ? (height/2-34.3)*Math.cos(standingAngle*Math.PI/180) : 0
    property real sideAlignment: upright && surfaceSupported ? -(width/2-34.3)*Math.sin(standingAngle*Math.PI/180) : 0
    Behavior on sideAlignment { enabled: root.motionEnabled && !root.hardResetting; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on floorAlignment { enabled: root.motionEnabled && !root.hardResetting; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    property bool initialized: false
    property bool managedPlacement: false
    property real targetX: 0
    property real targetY: 0
    property string activeEmergenceEdge: emergenceEdge
    property bool leaving: false
    readonly property bool relocating: relocation.running
    readonly property bool inputReady: presentation > 0.99 && reveal > 0.99 && !relocating
        && !hardResetting && (dragging || !managedPlacement || travelEnabled || (Math.abs(x-targetX)<0.1 && Math.abs(y-targetY)<0.1))
    readonly property bool materialReady: droplet.materialReady
    readonly property bool softwareFallback: droplet.softwareFallback
    readonly property bool moving: travelTween.running
    readonly property bool walking: moving && surfaceSupported && ["walk","run"].includes(travelMode)
    readonly property bool flying: dragging || (moving && !walking)
    readonly property bool gesturing: gestureTween.running
    readonly property real viewCos: Math.cos(standingAngle*Math.PI/180)
    readonly property real viewSin: Math.sin(standingAngle*Math.PI/180)
    readonly property var attention: Attention.resolve(moving || dragging,
        travelDirection*viewCos+travelDirectionY*viewSin, -travelDirection*viewSin+travelDirectionY*viewCos,
        pointerFresh || hovered,
        hovered ? droplet.hoverGazeX : pointerX*viewCos+pointerY*viewSin,
        hovered ? droplet.hoverGazeY : -pointerX*viewSin+pointerY*viewCos,
        peeking && emergenceEdge==="left" ? .4 : peeking && emergenceEdge==="right" ? -.4 : gazeX,
        peeking && emergenceEdge==="top" ? .3 : peeking && emergenceEdge==="bottom" ? -.3 : gazeY,
        faceExpression,moving ? tangentDirection : Math.abs(droplet.viewYaw)>=25 ? droplet.viewYaw : 0)
    readonly property real emergenceNormal: leaving
        ? curves.sample(hideClip, "normal", 1-presentation)
        : curves.sample(peeking ? "emerge" : appearClip, "normal", presentation)
    readonly property bool verticalEdge: !upright && (edge === "left" || edge === "right")
    readonly property bool hovered: droplet.hovered
    signal chatRequested()
    signal activated()
    signal settingsRequested()
    signal travelCompleted()
    signal dragStarted()
    signal dragPositionRequested(real x, real y)
    signal dragEnded()
    signal gestureCompleted(string action)
    function stopTravel(): void { travelTween.stop() }
    function stopGesture(): void { gestureTween.stop(); gesture="";gesturePhase=1 }
    function perform(action): bool {
        if (!visible || !motionEnabled || !curves.clips[action] || dragging || moving) return false
        stopGesture();gesture=action;gesturePhase=0
        gestureTween.duration=curves.clips[action].duration;gestureTween.start()
        return true
    }
    function updateTravel(): void {
        const t=travelMode==="jump" ? curves.sample("jump","journey",travelPhase) : travelPhase
        const height=travelArc>0 ? curves.sample(travelMode==="jump" ? "jump" : "fly","height",travelPhase)*travelArc : 0
        x=travelFromX+(travelToX-travelFromX)*t
        y=travelFromY+(travelToY-travelFromY)*t+height*travelNormalY
        x+=height*travelNormalX
    }
    onTravelPhaseChanged: if (moving) updateTravel()
    function present(value): void {
        presentationTween.stop()
        leaving=value<presentation
        if (!motionEnabled || hardResetting) {presentation=value;return}
        presentationTween.from=value>.99 && presentation<.99 && !leaving && appearClip!=="emerge" ? 0 : presentation
        presentationTween.to=value
        presentationTween.duration=leaving ? curves.clips[hideClip].duration : peeking ? 480 : curves.clips[appearClip].duration
        presentationTween.start()
    }
    function carryTo(px,py): void {
        stopTravel();relocation.stop()
        x=px;y=py
    }
    function resetTo(px, py, sourceEdge): void {
        hardResetting=true
        stopTravel(); stopGesture(); relocation.stop(); presentationTween.stop()
        presentation=0; leaving=false; activeEmergenceEdge=sourceEdge
        x=px; y=py
        hardResetting=false
        // Geometry can relocate an already revealed actor without changing
        // reveal's value. Re-arm emergence even when that binding is unchanged.
        Qt.callLater(root.synchronizePresentation)
    }
    function adoptTo(px,py,sourceEdge,value): void {
        hardResetting=true
        stopTravel();stopGesture();relocation.stop();presentationTween.stop()
        x=px;y=py;activeEmergenceEdge=sourceEdge;leaving=false;presentation=value
        hardResetting=false
    }
    function synchronizePresentation(): void { if (!presentationManaged) present(reveal) }
    function checkArrival(): void {
        if (initialized && travelEnabled && !moving && !dragging && !relocating
                && presentation>.99 && Math.abs(x-targetX)<.1 && Math.abs(y-targetY)<.1)
            travelCompleted()
    }
    onMovingChanged: if (!moving) Qt.callLater(root.checkArrival)
    onPresentationChanged: if (presentation>.99) Qt.callLater(root.checkArrival)
    function place(): void {
        if (!initialized || !managedPlacement || hardResetting) return
        if (Math.abs(x-targetX)<0.01 && Math.abs(y-targetY)<0.01) return
        if (dragging || !motionEnabled || reveal <= 0 || presentation < 0.01) {
            stopTravel()
            relocation.stop()
            activeEmergenceEdge = emergenceEdge
            x = targetX; y = targetY
            Qt.callLater(root.checkArrival)
        } else if (travelEnabled) {
            relocation.stop()
            stopGesture()
            activeEmergenceEdge=emergenceEdge
            stopTravel()
            travelFromX=x;travelFromY=y;travelToX=targetX;travelToY=targetY
            travelPhase=0;travelTween.duration=travelDuration
            travelTween.easing.type=travelMode==="fall" ? Easing.InQuad
                : travelMode==="fly" ? Easing.InOutSine : Easing.Linear
            travelTween.start()
        } else {
            stopTravel()
            relocation.restart()
        }
    }
    onTargetXChanged: Qt.callLater(root.place)
    onTargetYChanged: Qt.callLater(root.place)

    implicitWidth: verticalEdge ? 98 : 112
    implicitHeight: verticalEdge ? 112 : 98
    visible: presentation > 0.001
    // The actor itself must not crop jump/stumble entrances that travel
    // sideways beyond its resting footprint. Water-side masking is handled by
    // the directional emergence viewport below.
    clip: false

    onRevealChanged: if (initialized && !presentationManaged) {
        if (reveal <= 0) {
            stopTravel(); stopGesture(); relocation.stop()
            // Arrival changes the selected water edge after the last target
            // position. Dive through that edge, not the old drag/visit origin.
            activeEmergenceEdge=emergenceEdge
        }
        if (!presentationManaged) present(reveal)
    }
    onTravelEnabledChanged: if (!travelEnabled) stopTravel(); else Qt.callLater(root.place)
    Component.onCompleted: {
        initialized = true
        if (managedPlacement) { x=targetX; y=targetY }
        activeEmergenceEdge = emergenceEdge
        if (!presentationManaged) present(reveal)
    }
    onMotionEnabledChanged: if (!motionEnabled) { stopTravel(); stopGesture(); relocation.stop(); synchronizePresentation() }
    // Standalone animation nodes can really be stopped at their current value.
    // Behavior's nested nodes reject stop(), breaking hover/drag interruption.
    NumberAnimation { id: presentationTween; target: root; property: "presentation" }
    NumberAnimation {
        id: travelTween; target: root; property: "travelPhase"; from: 0; to: 1
        onFinished: {root.updateTravel();Qt.callLater(root.checkArrival)}
    }
    NumberAnimation {
        id: gestureTween; target: root; property: "gesturePhase"; from: 0; to: 1
        onFinished: {const action=root.gesture;root.gesture="";root.gestureCompleted(action)}
    }

    DragHandler {
        id: dragHandler
        objectName: "wullDragHandler"
        target: null
        enabled: root.dragEnabled && root.interactive && root.inputReady
        acceptedButtons: Qt.LeftButton
        cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onActiveChanged: {
            if (active) {
                root.dragStartX=root.x; root.dragStartY=root.y
                root.stopTravel(); root.stopGesture(); relocation.stop()
                root.dragStarted()
            } else root.dragEnded()
        }
        onCentroidChanged: if (active) {
            root.dragPositionRequested(root.dragStartX+centroid.scenePosition.x-centroid.scenePressPosition.x,
                root.dragStartY+centroid.scenePosition.y-centroid.scenePressPosition.y)
        }
    }

    // Water rings share the presentation clock and accent, with no new timer.
    Item {
        id: waterRings
        visible: !root.connectedWater && root.motionEnabled && root.effectsEnabled && root.presentation>.001 && root.presentation<.999
        width: 70; height: 13
        x: root.activeEmergenceEdge === "left" ? -width/2 : root.activeEmergenceEdge === "right" ? root.width-width/2 : (root.width-width)/2
        y: root.activeEmergenceEdge === "top" ? -height/2 : root.activeEmergenceEdge === "bottom" ? root.height-height/2 : (root.height-height)/2
        rotation: root.activeEmergenceEdge === "left" || root.activeEmergenceEdge === "right" ? 90 : 0
        opacity: Math.sin(Math.PI*root.presentation)
        scale: .6+root.presentation*.7
        Repeater {
            model: 2
            Shape {
                id: waterRing
                required property int index
                width: 70-index*16; height: 13-index*3
                anchors.centerIn: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"; strokeColor: Qt.alpha(AbyssStyle.accent,.75)
                    strokeWidth: .8
                    startX: 0; startY: waterRing.height/2
                    PathArc { x: waterRing.width; y: waterRing.height/2; radiusX: waterRing.width/2; radiusY: waterRing.height/2 }
                    PathArc { x: 0; y: waterRing.height/2; radiusX: waterRing.width/2; radiusY: waterRing.height/2 }
                }
            }
        }
    }
    SequentialAnimation {
        id: relocation
        ScriptAction { script: root.leaving = true }
        NumberAnimation { target: root; property: "presentation"; to: 0; duration: curves.clips.dive.duration }
        ScriptAction {
            script: {
                root.activeEmergenceEdge = root.emergenceEdge
                root.x = root.targetX; root.y = root.targetY
                root.leaving = false
            }
        }
        NumberAnimation { target: root; property: "presentation"; to: root.reveal; duration: curves.clips.emerge.duration }
    }

    Item {
        id: emergenceViewport
        objectName: "wullEmergenceViewport"
        readonly property real margin: Math.max(180,
            Math.abs(root.appearanceOffsetX)+root.width,
            Math.abs(root.appearanceOffsetY)+root.height)
        x: root.activeEmergenceEdge === "right" ? -margin
            : root.activeEmergenceEdge === "top" || root.activeEmergenceEdge === "bottom" ? -margin : 0
        y: root.activeEmergenceEdge === "bottom" ? -margin
            : root.activeEmergenceEdge === "left" || root.activeEmergenceEdge === "right" ? -margin : 0
        width: root.activeEmergenceEdge === "top" || root.activeEmergenceEdge === "bottom"
            ? root.width+margin*2 : root.width+margin
        height: root.activeEmergenceEdge === "left" || root.activeEmergenceEdge === "right"
            ? root.height+margin*2 : root.height+margin
        // Keep the underwater half hidden, but leave the visible half-plane
        // and tangent direction large enough for faceplant/buttplant/launch
        // poses and the full water-to-landing arc.
        clip: root.presentation < .999 && root.emergenceNormal >= 0

        Item {
            id: emergenceLayer
            width: 76; height: 92
            x: -emergenceViewport.x + (root.width-width)/2 + root.sideAlignment
            y: -emergenceViewport.y + (root.height-height)/2 + root.floorAlignment
            transform: [
            Translate {
                // Jump-style presentation starts at the selected water opening
                // and travels tangentially while the authored normal track
                // supplies the rise/fall, producing a real arc to the landing
                // point instead of a vertical hop in place.
                x: root.emergenceNormal * root.width * (root.activeEmergenceEdge === "left" ? -1 : root.activeEmergenceEdge === "right" ? 1 : 0)
                    + root.appearanceOffsetX * (1-root.appearanceJourney)
                y: root.emergenceNormal * root.height * (root.activeEmergenceEdge === "top" ? -1 : root.activeEmergenceEdge === "bottom" ? 1 : 0)
                    + root.appearanceOffsetY * (1-root.appearanceJourney)
            },
            Scale {
                origin.x: emergenceLayer.width / 2; origin.y: emergenceLayer.height / 2
                xScale: root.presentationAction ? 1 : curves.sample("emerge", "scaleX", root.presentation)
                yScale: root.presentationAction ? 1 : curves.sample("emerge", "scaleY", root.presentation)
            }
        ]
        WaterDropletBody {
            id: droplet
            character: root.character
            width: 76; height: 92
            visible: root.visible
            gazeX: root.attention.x
            gazeY: root.attention.y
            energy: root.energy
            motionEnabled: root.motionEnabled && visible
            motionScale: root.motionScale
            renderQuality: root.renderQuality
            translucency: root.translucency
            walking: root.walking
            flying: root.flying
            motionAction: root.motionAction
            motionProgress: root.pairedProgress>=0 ? root.pairedProgress : root.moving && ["jump","fall"].includes(root.travelMode) ? root.travelPhase
                : root.gesture ? root.gesturePhase : root.presentationAction ? root.leaving ? 1-root.presentation : root.presentation : -1
            grounded: root.surfaceSupported && !root.flying
            dragging: root.dragging
            traveling: root.moving
            walkingDirection: (root.upright ? root.tangentDirection : root.travelDirection) * (root.upright || root.edge === "top" || root.edge === "left" ? 1 : -1)
            viewYaw: root.moving ? (root.walking ? root.tangentDirection : root.travelDirection) * (root.walking ? 32 : 20)
                : root.peeking ? root.emergenceEdge==="left" ? 22 : root.emergenceEdge==="right" ? -22 : 0 : -15
            effectsEnabled: root.effectsEnabled
            stateSquash: root.motionEnabled ? root.bodySquash : 0
            stateStretch: root.motionEnabled ? root.bodyStretch : 0
            stateLean: root.motionEnabled ? root.bodyLean : 0
            stateTip: root.motionEnabled ? root.bodyTip : 0
            ripple: root.ripple
            eyeOpen: root.motionEnabled ? (curves.clips[root.motionAction]?.tracks.eyeOpen
                ? curves.sample(root.motionAction,"eyeOpen",root.pairedProgress>=0 ? root.pairedProgress : root.gesture ? root.gesturePhase : root.leaving ? 1-root.presentation : root.presentation) : root.eyeOpen) : 1
            mouthCurve: root.mouthCurve
            pulse: root.pulse
            expression: root.faceExpression
            reveal: 1
            enabled: root.interactive && root.inputReady
            opacity: Math.min(1, root.presentation * 4)
            orientationAngle: root.upright ? root.standingAngle : root.edge === "left" ? 90 : root.edge === "right" ? -90 : root.edge === "bottom" ? 180 : 0
            // Centered bounds contain the rotated clickable body for all four
            // output edges. Verified in the offscreen four-edge prototype; keep
            // compositor input-mask changes as a separate qualification gate.
            transformOrigin: Item.Center
            anchors.centerIn: parent
            onChatRequested: root.chatRequested()
            onPressed: root.activated()
            onSettingsRequested: root.settingsRequested()
        }
        }
    }
}
