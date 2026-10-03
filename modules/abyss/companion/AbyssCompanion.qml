import QtQuick
import QtQuick.Shapes
import qs.modules.abyss.looks
import qs.modules.common
import "WullExpressions.js" as Expressions
import "WullMotionData.js" as Curves
import "WullAttention.js" as Attention

Item {
    id: root
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
    property string renderQuality: "balanced"
    property real translucency: 0.16
    property bool travelEnabled: false
    property string travelMode: "walk"
    property bool surfaceSupported: true
    property int travelDuration: 1000
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
    property real floorAlignment: upright && surfaceSupported ? height-2-((height-92)/2+78.3) : 0
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
    readonly property bool moving: travelX.running || travelY.running
    readonly property bool walking: moving && surfaceSupported && travelMode === "walk"
    readonly property bool flying: dragging || (moving && !walking)
    readonly property var attention: Attention.resolve(moving || dragging,
        travelDirection, travelDirectionY, moving || dragging ? false : pointerFresh,
        moving || dragging ? 0 : pointerX, moving || dragging ? 0 : pointerY,
        peeking && emergenceEdge==="left" ? .4 : peeking && emergenceEdge==="right" ? -.4 : gazeX,
        peeking && emergenceEdge==="top" ? .3 : peeking && emergenceEdge==="bottom" ? -.3 : gazeY,
        Expressions.resolve(expression,mood,activity))
    readonly property real emergenceNormal: leaving
        ? Curves.sample("dive", "normal", 1-presentation)
        : Curves.sample("emerge", "normal", presentation)
    readonly property bool verticalEdge: !upright && (edge === "left" || edge === "right")
    readonly property bool hovered: droplet.hovered
    signal activated()
    signal settingsRequested()
    signal travelCompleted()
    signal dragStarted()
    signal dragPositionRequested(real x, real y)
    signal dragEnded()
    function stopTravel(): void { travelX.stop(); travelY.stop() }
    function present(value): void {
        presentationTween.stop()
        leaving=value<presentation
        if (!motionEnabled || hardResetting) {presentation=value;return}
        presentationTween.from=presentation
        presentationTween.to=value
        presentationTween.duration=leaving ? Curves.clips.dive.duration : peeking ? 480 : Curves.clips.emerge.duration
        presentationTween.start()
    }
    function resetTo(px, py, sourceEdge): void {
        hardResetting=true
        stopTravel(); relocation.stop(); presentationTween.stop()
        presentation=0; leaving=false; activeEmergenceEdge=sourceEdge
        x=px; y=py
        hardResetting=false
    }
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
            activeEmergenceEdge=emergenceEdge
            if (Math.abs(x-targetX)>.01) {
                travelX.stop();travelX.from=x;travelX.to=targetX
                travelX.duration=travelDuration;travelX.start()
            }
            if (Math.abs(y-targetY)>.01) {
                travelY.stop();travelY.from=y;travelY.to=targetY
                travelY.duration=travelDuration;travelY.start()
            }
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
    clip: presentation < 0.999

    onRevealChanged: if (initialized) {
        if (reveal <= 0) {
            stopTravel(); relocation.stop()
            // Arrival changes the selected water edge after the last target
            // position. Dive through that edge, not the old drag/visit origin.
            activeEmergenceEdge=emergenceEdge
        }
        present(reveal)
    }
    onTravelEnabledChanged: if (!travelEnabled) stopTravel(); else Qt.callLater(root.place)
    Component.onCompleted: {
        initialized = true
        if (managedPlacement) { x=targetX; y=targetY }
        activeEmergenceEdge = emergenceEdge
        present(reveal)
    }
    onMotionEnabledChanged: if (!motionEnabled) { stopTravel(); relocation.stop(); present(reveal) }
    // Standalone animation nodes can really be stopped at their current value.
    // Behavior's nested nodes reject stop(), breaking hover/drag interruption.
    NumberAnimation { id: presentationTween; target: root; property: "presentation" }
    NumberAnimation { id: travelX; target: root; property: "x"; onFinished: Qt.callLater(root.checkArrival) }
    NumberAnimation { id: travelY; target: root; property: "y"; onFinished: Qt.callLater(root.checkArrival) }

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
                root.stopTravel(); relocation.stop()
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
        NumberAnimation { target: root; property: "presentation"; to: 0; duration: Curves.clips.dive.duration }
        ScriptAction {
            script: {
                root.activeEmergenceEdge = root.emergenceEdge
                root.x = root.targetX; root.y = root.targetY
                root.leaving = false
            }
        }
        NumberAnimation { target: root; property: "presentation"; to: root.reveal; duration: Curves.clips.emerge.duration }
    }

    Item {
        id: emergenceLayer
        width: 76; height: 92
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.floorAlignment
        transform: [
            Translate {
                x: root.emergenceNormal * root.width * (root.activeEmergenceEdge === "left" ? -1 : root.activeEmergenceEdge === "right" ? 1 : 0)
                y: root.emergenceNormal * root.height * (root.activeEmergenceEdge === "top" ? -1 : root.activeEmergenceEdge === "bottom" ? 1 : 0)
            },
            Scale {
                origin.x: emergenceLayer.width / 2; origin.y: emergenceLayer.height / 2
                xScale: Curves.sample("emerge", "scaleX", root.presentation)
                yScale: Curves.sample("emerge", "scaleY", root.presentation)
            }
        ]
        WaterDropletBody {
            id: droplet
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
            grounded: root.surfaceSupported && !root.flying
            dragging: root.dragging
            traveling: root.moving
            walkingDirection: root.travelDirection * (root.upright || root.edge === "top" || root.edge === "left" ? 1 : -1)
            viewYaw: root.moving ? root.travelDirection * (root.walking ? 32 : 20)
                : root.peeking ? root.emergenceEdge==="left" ? 22 : root.emergenceEdge==="right" ? -22 : 0 : -15
            effectsEnabled: root.effectsEnabled
            stateSquash: root.motionEnabled ? root.bodySquash : 0
            stateStretch: root.motionEnabled ? root.bodyStretch : 0
            stateLean: root.motionEnabled ? root.bodyLean : 0
            stateTip: root.motionEnabled ? root.bodyTip : 0
            ripple: root.ripple
            eyeOpen: root.motionEnabled ? root.eyeOpen : 1
            mouthCurve: root.mouthCurve
            pulse: root.pulse
            expression: Expressions.resolve(root.expression, root.mood, root.activity)
            reveal: 1
            enabled: root.interactive && root.inputReady
            opacity: Math.min(1, root.presentation * 4)
            orientationAngle: root.upright ? 0 : root.edge === "left" ? 90 : root.edge === "right" ? -90 : root.edge === "bottom" ? 180 : 0
            // Centered bounds contain the rotated clickable body for all four
            // output edges. Verified in the offscreen four-edge prototype; keep
            // compositor input-mask changes as a separate qualification gate.
            transformOrigin: Item.Center
            anchors.centerIn: parent
            onPressed: root.activated()
            onSettingsRequested: root.settingsRequested()
        }
    }
}
