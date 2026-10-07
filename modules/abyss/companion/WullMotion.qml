import QtQuick
import "CompanionMotion.js" as Motion

// Blender authors the 3D rig; scalar F-curves retain the runtime liquid material.
// One local loop clock. Finite actions share the actor's progress clock.
Item {
    id: root
    objectName: "wullLocomotion"
    property string character: "aqua"
    readonly property var curves: Motion.forCharacter(character)
    property bool walking: false
    property bool flying: false
    property string action: ""
    property real progress: -1
    property bool motionEnabled: true
    property real direction: 1
    property real phase: 0
    readonly property string clip: action && curves.clips[action] ? action : walking ? "walk" : flying ? "fly" : "float"
    readonly property real sampledPhase: progress >= 0 ? progress : phase
    readonly property bool active: (action !== "" || walking || flying) && motionEnabled && visible
    property real weight: 0
    readonly property real lift: sample("lift")
    readonly property real roll: sample("roll") * direction
    readonly property real pitch: sample("pitch")
    readonly property real yaw: sample("yaw") * direction
    readonly property real scaleX: 1 + (curves.sample(clip, "scaleX", sampledPhase) - 1) * weight
    readonly property real scaleY: 1 + (curves.sample(clip, "scaleY", sampledPhase) - 1) * weight
    function sample(channel): real {return curves.sample(clip,channel,sampledPhase)*weight}
    function footX(channel): real { return sample(channel) * direction }
    function footZ(channel): real { return sample(channel) }
    function curl(index): real {return 1+(curves.sample(clip,"tentacle"+index+"Curl",sampledPhase)-1)*weight}
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
        from: 0; to: 1; duration: root.curves.clips[root.clip]?.duration ?? root.curves.clips.float.duration
        loops: Animation.Infinite
    }
}
