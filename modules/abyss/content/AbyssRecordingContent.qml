pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.recordingOsd
import qs.services

Item {
    id: root
    property var participant: null
    readonly property var recorder: controls
    readonly property real desiredWidth: controls.controls?.implicitWidth ?? 200
    readonly property real desiredHeight: controls.controls?.implicitHeight ?? 30
    implicitWidth: desiredWidth
    implicitHeight: desiredHeight
    RecordingOsd {
        id: controls
        embeddedMode: true
        embeddedParent: root
        recordingStatus: root.participant?.recordingStatus ?? RecorderStatus
        audioService: root.participant?.audioService ?? Audio
        stopAction: root.participant?.stopAction ?? null
        isVertical: ["left","right"].includes(root.participant?.edge ?? "top")
        presentationVisible: root.participant?.open ?? false
        onDragStarted: root.participant?.beginDrag()
        onDragMoved: translation => root.participant?.moveDrag(translation)
        onDragFinished: translation => root.participant?.finishDrag(translation)
    }
}
