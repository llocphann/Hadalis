pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

// Internal implementation - loaded dynamically by PolkitService.qml
// Do NOT use directly, use PolkitService singleton instead
Scope {
    id: root
    property alias agent: polkitAgent
    property alias active: polkitAgent.isActive
    property alias flow: polkitAgent.flow
    property bool interactionAvailable: false
    property int requestSerial: 0

    function cancel() {
        if (!root.flow)
            return
        root.flow.cancelAuthenticationRequest()
        root.interactionAvailable = false
    }

    function submit(response) {
        if (!root.flow || !(root.flow.isResponseRequired ?? false))
            return
        // Never retain or log an authentication response.
        root.interactionAvailable = false
        root.flow.submit(response)
    }

    function selectIdentity(identity) {
        if (!root.flow || !identity)
            return
        root.interactionAvailable = false
        root.flow.selectedIdentity = identity
    }

    Connections {
        target: root.flow
        function onAuthenticationFailed() {
            root.interactionAvailable = true
        }
        function onIsResponseRequiredChanged() {
            if (root.flow?.isResponseRequired ?? false)
                root.interactionAvailable = true
        }
        function onAuthenticationSucceeded() {
            root.interactionAvailable = false
        }
        function onAuthenticationRequestCancelled() {
            root.interactionAvailable = false
        }
    }

    PolkitAgent {
        id: polkitAgent
        onAuthenticationRequestStarted: {
            root.requestSerial += 1
            root.interactionAvailable = true
        }
    }
}
