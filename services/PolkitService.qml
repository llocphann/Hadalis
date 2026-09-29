pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

/**
 * PolkitService - Wrapper that gracefully handles missing Quickshell.Services.Polkit module
 * 
 * The Polkit module is optional in Quickshell and may not be compiled in all builds.
 * This wrapper provides a stub interface when the module is unavailable, preventing
 * the entire shell from failing to load.
 */
Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    // Public API - matches PolkitServiceImpl
    property var agent: impl?.agent ?? null
    property bool active: impl?.active ?? false
    property var flow: impl?.flow ?? null
    property bool interactionAvailable: impl?.interactionAvailable ?? false
    property int requestSerial: impl?.requestSerial ?? 0

    readonly property string actionId: String(flow?.actionId ?? "")
    readonly property string iconName: String(flow?.iconName ?? "")
    readonly property bool responseVisible: flow?.responseVisible ?? false
    readonly property bool responseRequired: flow?.isResponseRequired ?? false
    readonly property bool failed: flow?.failed ?? false
    readonly property string supplementaryMessage:
        String(flow?.supplementaryMessage ?? "").trim()
    readonly property bool supplementaryIsError:
        flow?.supplementaryIsError ?? false
    readonly property var identities: flow?.identities ?? []
    readonly property var selectedIdentity: flow?.selectedIdentity ?? null
    readonly property bool canSubmit:
        root.active && root.interactionAvailable && root.responseRequired
    readonly property bool busy:
        root.active && !root.interactionAvailable
        && !(flow?.isCompleted ?? false)

    property string targetOutputName: ""
    property var resolvedAnchor: null
    property string resolvedAnchorKind: ""
    property bool hadResolvedAnchor: false
    property var _nextSourceHint: null
    readonly property bool resolvedAnchorUsable:
        !root.hadResolvedAnchor
            || PopupAnchorRegistry.isUsable(root.resolvedAnchor)

    readonly property string rawMessage: String(flow?.message ?? "").trim()
    readonly property bool batteryChargeLimitRequest: rawMessage.includes("battery-charge-limit")
    readonly property string cleanMessage: {
        if (batteryChargeLimitRequest)
            return Translation.tr("Do you want to allow this app to make changes to your device?")
        return rawMessage.endsWith(".") ? rawMessage.slice(0, -1) : rawMessage
    }
    readonly property string cleanPrompt: {
        const prompt = String(flow?.inputPrompt ?? "").trim()
        const cleaned = prompt.endsWith(":") ? prompt.slice(0, -1) : prompt
        if (cleaned.length > 0)
            return cleaned
        return flow?.responseVisible
            ? Translation.tr("Input")
            : Translation.tr("Password")
    }
    readonly property string actionLabel: batteryChargeLimitRequest
        ? Translation.tr("Charge limit")
        : Translation.tr("Authentication")

    function identityLabelFor(identity): string {
        if (!identity)
            return ""
        for (const key of ["displayName", "name", "user", "username", "id"]) {
            const value = String(identity?.[key] ?? "").trim()
            if (value.length > 0)
                return value
        }
        const fallback = String(identity ?? "").trim()
        return fallback.startsWith("QVariant(") ? "" : fallback
    }

    readonly property string identityLabel:
        root.identityLabelFor(root.selectedIdentity)
    readonly property string detailsText: {
        const lines = []
        if (root.actionId.length > 0)
            lines.push(Translation.tr("Action") + ": " + root.actionId)
        if (root.identityLabel.length > 0)
            lines.push(Translation.tr("Identity") + ": " + root.identityLabel)
        return lines.join("\n")
    }

    // Optional trusted internal hint for a future backend/native bridge. Current
    // AuthFlow does not expose a requester app id, so ordinary requests leave
    // this unset and intentionally use top-center fallback.
    function hintSource(appId, anchorItem = null, outputName = ""): void {
        root._nextSourceHint = {
            appId: String(appId ?? ""),
            anchorItem: anchorItem,
            outputName: String(outputName ?? "")
        }
    }

    function _latchPresentation(): void {
        const hint = root._nextSourceHint
        root._nextSourceHint = null
        const requestedOutput = GlobalStates.resolveOutputName(
            String(hint?.outputName ?? ""), [])
        const sourceContext = hint
            ? Object.assign({}, hint, { outputName: requestedOutput })
            : null
        const resolved = sourceContext
            ? PopupAnchorRegistry.resolve(sourceContext) : null
        root.resolvedAnchor = resolved?.item ?? null
        root.resolvedAnchorKind = String(resolved?.kind ?? "")
        root.hadResolvedAnchor = root.resolvedAnchor !== null
        const resolvedOutput = String(resolved?.outputName ?? "")
        root.targetOutputName = resolvedOutput.length > 0
            ? resolvedOutput
            : requestedOutput
    }

    onRequestSerialChanged: {
        if (root.requestSerial > 0)
            root._latchPresentation()
    }

    // Whether the Polkit module is available
    readonly property bool available: impl !== null
    
    function cancel(): void {
        if (impl) impl.cancel()
    }
    
    function submit(response: string): void {
        if (impl) impl.submit(response)
    }

    function selectNextIdentity(): void {
        // Identity changes mutate the live AuthFlow. Keep them disabled while
        // the backend is pending/busy; Cancel remains available separately.
        if (!impl || !root.flow || !root.interactionAvailable || root.busy)
            return
        const count = Number(root.identities?.length ?? 0)
        if (count <= 1)
            return
        let current = -1
        for (let index = 0; index < count; ++index) {
            if (root.identities[index] === root.selectedIdentity) {
                current = index
                break
            }
        }
        impl.selectIdentity(root.identities[(current + 1) % count])
    }

    onResolvedAnchorUsableChanged: {
        if (root.active && root.hadResolvedAnchor
                && !root.resolvedAnchorUsable) {
            root.resolvedAnchor = null
            root.cancel()
        }
    }

    Connections {
        target: PopupAnchorRegistry
        function onAnchorRemoved(item): void {
            if (root.active && root.hadResolvedAnchor
                    && root.resolvedAnchor === item) {
                root.resolvedAnchor = null
                root.cancel()
            }
        }
    }
    
    // Private: actual implementation loaded dynamically
    property var impl: null

    function _loadImpl(): void {
        // Try to load the real implementation
        const component = Qt.createComponent("PolkitServiceImpl.qml", Component.Asynchronous)

        function finishCreation() {
            if (component.status === Component.Ready) {
                root.impl = component.createObject(root)
                _log("[PolkitService] Polkit module loaded successfully")
            } else if (component.status === Component.Error) {
                _log("[PolkitService] Polkit module not available - polkit agent disabled")
                _log("[PolkitService] To enable, rebuild quickshell with -DSERVICE_POLKIT=ON")
            }
        }

        if (component.status === Component.Ready || component.status === Component.Error) {
            finishCreation()
        } else {
            component.statusChanged.connect(finishCreation)
        }
    }
    
    Component.onCompleted: {
        if (Quickshell.env("QS_DISABLE_POLKIT") === "1") {
            return
        }
        if (!(Config.options?.modules?.polkit ?? true)) {
            return
        }

        // If another authentication agent already exists, registering will fail and spam warnings.
        // Best-effort detection: if we can see a known agent process, skip our agent.
        polkitAgentCheck.running = true
    }

    Process {
        id: polkitAgentCheck
        running: false
        property bool startObserved: false

        // Note: pidof returns 0 if ANY process exists. A nonzero exit means no known agent.
        command: [
            "/usr/bin/pidof",
            "polkit-gnome-authentication-agent-1",
            "lxqt-policykit-agent",
            "polkit-kde-authentication-agent-1",
            "mate-polkit"
        ]

        onRunningChanged: {
            if (polkitAgentCheck.running) {
                polkitAgentCheck.startObserved = false
                return
            }
            if (polkitAgentCheck.startObserved)
                return

            // FailedToStart does not emit exited; lack of pidof must not disable
            // Hadalis' own authentication agent.
            root._loadImpl()
        }

        onStarted: polkitAgentCheck.startObserved = true

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                // Another agent exists; avoid the Quickshell polkit listener warning.
                return
            }
            root._loadImpl()
        }
    }
}
