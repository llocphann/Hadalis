import QtQuick

QtObject {
    id: root
    required property string identity
    property var controller: null
    property var geometry: null
    // Resting/full record and the current visual placement are presentation
    // snapshots only; the allocator still consumes placementRequest alone.
    property var restingRecord: null
    property var visualPlacement: null
    property var placementRequest: null
    property rect inputBounds: Qt.rect(0,0,0,0)
    property real mass: 1
    property var heldController: null
    property string heldIdentity: ""
    function synchronize(): void {
        if (heldController) heldController.unregisterParticipant(heldIdentity, root)
        heldController = controller
        heldIdentity = identity
        if (heldController) heldController.registerParticipant(heldIdentity, root)
    }
    onControllerChanged: synchronize()
    onIdentityChanged: if (heldController) synchronize()
    Component.onCompleted: synchronize()
    Component.onDestruction: if (heldController) heldController.unregisterParticipant(heldIdentity, root)
}
