import QtQuick
import "WullMotionData.js" as Curves

// Blender authors the 3D rig; scalar F-curves retain the runtime liquid material.
// One local animation clock, only while walking. No frame IPC, timers or meshes.
Item {
    id: root
    objectName: "wullLocomotion"
    property bool walking: false
    property bool motionEnabled: true
    property real direction: 1
    property real phase: 0
    readonly property bool active: walking && motionEnabled && visible
    property real weight: active ? 1 : 0
    readonly property real lift: Curves.sample("walk", "lift", phase) * weight
    readonly property real roll: Curves.sample("walk", "roll", phase) * direction * weight
    readonly property real scaleX: 1 + (Curves.sample("walk", "scaleX", phase) - 1) * weight
    readonly property real scaleY: 1 + (Curves.sample("walk", "scaleY", phase) - 1) * weight
    function footX(channel): real { return Curves.sample("walk", channel, phase) * direction * weight }
    function footZ(channel): real { return Curves.sample("walk", channel, phase) * weight }
    Behavior on weight { enabled: root.motionEnabled && root.visible; NumberAnimation { duration: 140 } }
    NumberAnimation on phase {
        running: root.active
        from: 0; to: 1; duration: Curves.clips.walk.duration
        loops: Animation.Infinite
    }
}
