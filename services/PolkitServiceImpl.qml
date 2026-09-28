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
        function onInputPromptChanged() {
            // Multi-turn PAM conversations may replace the prompt while the
            // response-required state stays true (for example a second factor).
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
            // The request exists before PAM necessarily asks for input.
            // Stay in pending state until AuthFlow actually requires a
            // response; fingerprint/other non-text conversations remain busy.
            root.interactionAvailable = root.flow?.isResponseRequired ?? false
        }
    }
}
