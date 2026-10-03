import QtQuick
import qs.modules.abyss.looks
import qs.modules.common
import "WullExpressions.js" as Expressions
import "WullMotionData.js" as Curves

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
    property int travelDuration: 1000
    property real travelDirection: 1
    property string emergenceEdge: edge
    property bool upright: false
    property real presentation: 0
    property bool initialized: false
    property bool managedPlacement: false
    property real targetX: 0
    property real targetY: 0
    property string activeEmergenceEdge: emergenceEdge
    property bool leaving: false
    readonly property bool relocating: relocation.running
    readonly property bool inputReady: presentation > 0.99 && reveal > 0.99 && !relocating
        && (!managedPlacement || travelEnabled || (Math.abs(x-targetX)<0.1 && Math.abs(y-targetY)<0.1))
    readonly property bool materialReady: droplet.materialReady
    readonly property bool softwareFallback: droplet.softwareFallback
    readonly property bool walking: travelX.running || travelY.running
    readonly property real emergenceNormal: leaving
        ? Curves.sample("dive", "normal", 1-presentation)
        : Curves.sample("emerge", "normal", presentation)
    readonly property bool verticalEdge: edge === "left" || edge === "right"
    readonly property bool hovered: droplet.hovered
    signal activated()
    signal settingsRequested()
    function stopTravel(): void { travelX.stop(); travelY.stop() }
    function place(): void {
        if (!initialized || !managedPlacement) return
        if (Math.abs(x-targetX)<0.01 && Math.abs(y-targetY)<0.01) return
        if (travelEnabled || !motionEnabled || reveal <= 0 || presentation < 0.01) {
            relocation.stop()
            activeEmergenceEdge = emergenceEdge
            x = targetX; y = targetY
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
        leaving = reveal < presentation
        if (reveal <= 0) { stopTravel(); relocation.stop() }
        presentation = reveal
    }
    onTravelEnabledChanged: if (!travelEnabled) stopTravel()
    Component.onCompleted: {
        initialized = true
        if (managedPlacement) { x=targetX; y=targetY }
        activeEmergenceEdge = emergenceEdge
        presentation = reveal
    }
    onMotionEnabledChanged: if (!motionEnabled) { stopTravel(); relocation.stop(); presentation = reveal }
    onHoveredChanged: if (hovered) { travelX.stop(); travelY.stop() }
    Behavior on presentation {
        enabled: root.motionEnabled
        NumberAnimation { duration: root.leaving ? Curves.clips.dive.duration : Curves.clips.emerge.duration }
    }
    Behavior on x {
        enabled: root.travelEnabled && root.motionEnabled && root.presentation > 0.99
        NumberAnimation { id: travelX; duration: root.travelDuration }
    }
    Behavior on y {
        enabled: root.travelEnabled && root.motionEnabled && root.presentation > 0.99
        NumberAnimation { id: travelY; duration: root.travelDuration }
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
            gazeX: root.gazeX
            gazeY: root.gazeY
            energy: root.energy
            motionEnabled: root.motionEnabled && visible
            motionScale: root.motionScale
            renderQuality: root.renderQuality
            translucency: root.translucency
            walking: root.walking
            walkingDirection: root.travelDirection * (root.upright || root.edge === "top" || root.edge === "left" ? 1 : -1)
            viewYaw: root.walking ? walkingDirection * 32 : -15
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
