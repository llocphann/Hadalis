import QtQuick

QtObject {
    id: root
    required property string identity
    property var controller: null
    property var geometry: null
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
