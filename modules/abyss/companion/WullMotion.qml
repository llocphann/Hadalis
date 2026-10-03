import QtQuick
import "WullMotionData.js" as Curves

// Blender authors the 3D rig; scalar F-curves retain the runtime liquid material.
// One local animation clock, only while walking/flying. No frame IPC or meshes.
Item {
    id: root
    objectName: "wullLocomotion"
    property bool walking: false
    property bool flying: false
    property bool motionEnabled: true
    property real direction: 1
    property real phase: 0
    readonly property string clip: walking ? "walk" : "float"
    readonly property bool active: (walking || flying) && motionEnabled && visible
    property real weight: active ? 1 : 0
    readonly property real lift: Curves.sample(clip, "lift", phase) * weight
    readonly property real roll: Curves.sample(clip, "roll", phase) * direction * weight
    readonly property real scaleX: 1 + (Curves.sample(clip, "scaleX", phase) - 1) * weight
    readonly property real scaleY: 1 + (Curves.sample(clip, "scaleY", phase) - 1) * weight
    function footX(channel): real { return Curves.sample(clip, channel, phase) * direction * weight }
    function footZ(channel): real { return Curves.sample(clip, channel, phase) * weight }
    Behavior on weight { enabled: root.motionEnabled && root.visible; NumberAnimation { duration: 140 } }
    NumberAnimation on phase {
        running: root.active
        from: 0; to: 1; duration: Curves.clips[root.clip].duration
        loops: Animation.Infinite
    }
}
