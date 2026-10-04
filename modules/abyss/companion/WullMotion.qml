import QtQuick
import "WullMotionData.js" as Curves

// Blender authors the 3D rig; scalar F-curves retain the runtime liquid material.
// One local loop clock. Finite actions share the actor's progress clock.
Item {
    id: root
    objectName: "wullLocomotion"
    property bool walking: false
    property bool flying: false
    property string action: ""
    property real progress: -1
    property bool motionEnabled: true
    property real direction: 1
    property real phase: 0
    readonly property string clip: action && Curves.clips[action] ? action : walking ? "walk" : flying ? "fly" : "float"
    readonly property real sampledPhase: progress >= 0 ? progress : phase
    readonly property bool active: (action !== "" || walking || flying) && motionEnabled && visible
    property real weight: 0
    readonly property real lift: Curves.sample(clip, "lift", sampledPhase) * weight
    readonly property real roll: Curves.sample(clip, "roll", sampledPhase) * direction * weight
    readonly property real scaleX: 1 + (Curves.sample(clip, "scaleX", sampledPhase) - 1) * weight
    readonly property real scaleY: 1 + (Curves.sample(clip, "scaleY", sampledPhase) - 1) * weight
    function footX(channel): real { return Curves.sample(clip, channel, sampledPhase) * direction * weight }
    function footZ(channel): real { return Curves.sample(clip, channel, sampledPhase) * weight }
    function synchronizeWeight(): void {
        weightBlend.stop()
        if (!motionEnabled || !visible) {weight=0;return}
        weightBlend.from=weight;weightBlend.to=active ? 1 : 0;weightBlend.start()
    }
    onActiveChanged: synchronizeWeight()
    onMotionEnabledChanged: synchronizeWeight()
    onVisibleChanged: synchronizeWeight()
    Component.onCompleted: synchronizeWeight()
    NumberAnimation {id:weightBlend;target:root;property:"weight";duration:140}
    NumberAnimation on phase {
        running: root.active && root.progress < 0
        from: 0; to: 1; duration: Curves.clips[root.clip].duration
        loops: Animation.Infinite
    }
}
