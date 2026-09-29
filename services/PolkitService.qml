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
    // UI residency is separate from AuthFlow activity so Abyss can finish the
    // same slide-under retract after the backend has completed/cancelled.
    property bool presentationRetained: false
    // The serial currently allowed to own the Abyss presenter. Quickshell may
    // activate the next queued AuthFlow synchronously as the previous one
    // completes; keeping this separate prevents content/anchor teleport.
    property int presentationSerial: 0
    readonly property bool presentationMatchesActive:
        root.presentationRetained
        && root.presentationSerial > 0
        && root.presentationSerial === root.requestSerial
    readonly property bool abyssPresentationSuppressed:
        Config.options?.panelFamily === "abyss"
        && GlobalStates.screenLocked
    readonly property bool abyssConfigured:
        Config.options?.panelFamily === "abyss"
        && (Config.options?.enabledPanels ?? []).includes("abyssPerimeter")
        && !root.abyssPresentationSuppressed
    readonly property bool abyssPresenterAvailable:
        root.abyssConfigured
        && root.targetOutputName.length > 0
        && AbyssPromptHostRegistry.hasOutput(root.targetOutputName)

    function _abyssHostAvailableFor(outputName): bool {
        return root.abyssConfigured
            && AbyssPromptHostRegistry.hasOutput(String(outputName ?? ""))
    }

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
    property var _pendingPresentationHint: null
    property bool _sourceLossCancelIssued: false
    readonly property int sourceHintLifetimeMs: 3000
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
    function _clearSourceHint(): void {
        sourceHintExpiry.stop()
        root._nextSourceHint = null
    }

    function hintSource(appId, anchorItem = null, outputName = ""): bool {
        // AuthFlow does not expose a caller token/cookie that a UI hint can
        // bind to. Never accept/overwrite hints while another flow is active:
        // queued Polkit requests could otherwise inherit the wrong app anchor.
        // A rejected hint safely leaves that request on top-center fallback.
        if (root.active || root._nextSourceHint !== null
                || root._pendingPresentationHint !== null)
            return false
        root._nextSourceHint = {
            appId: String(appId ?? ""),
            anchorItem: anchorItem,
            outputName: String(outputName ?? "")
        }
        sourceHintExpiry.restart()
        return true
    }

    function _takeSourceHint(): var {
        sourceHintExpiry.stop()
        const hint = root._nextSourceHint
        root._nextSourceHint = null
        return hint
    }

    function _latchPresentation(hint = null): void {
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

    Timer {
        id: sourceHintExpiry
        interval: root.sourceHintLifetimeMs
        repeat: false
        onTriggered: root._nextSourceHint = null
    }

    function _startPresentationForCurrentRequest(): void {
        if (!root.active || root.requestSerial <= 0)
            return
        // Resolve output/anchor before making the retained presentation
        // visible. In fullscreen this prevents one frame from reusing the
        // previous authentication request's output ownership.
        const hint = root._pendingPresentationHint
        root._pendingPresentationHint = null
        root._latchPresentation(hint)
        if (!root._abyssHostAvailableFor(root.targetOutputName)) {
            // The configured perimeter may have failed to instantiate, or the
            // target output may be between hotplug lifecycles. Leave AuthFlow
            // active and let the critical legacy renderer own visibility.
            root.presentationSerial = 0
            root.presentationRetained = false
            return
        }
        root.presentationSerial = root.requestSerial
        root.presentationRetained = true
    }

    onRequestSerialChanged: {
        if (root.requestSerial <= 0)
            return
        root._sourceLossCancelIssued = false
        // Consume the one-shot hint at AuthFlow start even if presentation is
        // still blocked by the previous visual tail. A later queued request
        // replaces this slot with its own hint (or null), so source identity
        // can never leak across authentication requests.
        root._pendingPresentationHint = root._takeSourceHint()
        // PolkitAgent starts the next queued AuthFlow synchronously. When the
        // previous Abyss popup is still visually resident, revoke semantic
        // ownership first and let that popup finish its retract on the old
        // anchor/output. finishPresentation() starts the new visual request.
        if (root.presentationRetained
                && root.presentationSerial !== root.requestSerial) {
            root.presentationSerial = 0
            return
        }
        root._startPresentationForCurrentRequest()
    }

    function finishPresentation(restartIfActive = true): void {
        if (!root.presentationRetained)
            return
        root.presentationRetained = false
        root.presentationSerial = 0
        if (restartIfActive && root.active && root.requestSerial > 0) {
            Qt.callLater(() => {
                if (root.active && !root.presentationRetained)
                    root._startPresentationForCurrentRequest()
            })
        }
    }

    onAbyssPresenterAvailableChanged: {
        if (!root.active)
            return
        if (root.abyssPresenterAvailable) {
            if (!root.presentationRetained)
                root._startPresentationForCurrentRequest()
            return
        }

        // A live host can disappear even while config still says perimeter is
        // enabled (QML failure, family teardown, output hotplug). Never leave a
        // real AuthFlow hidden behind that optimistic configuration state.
        if (root.presentationRetained) {
            if (root.hadResolvedAnchor)
                root._cancelForSourceLoss()
            else
                root.finishPresentation(false)
        }
    }

    Connections {
        target: AbyssPromptHostRegistry
        function onEntriesChanged(): void {
            // hasOutput() is a function, so explicitly retrigger reconciliation
            // when the registry mutates instead of relying on binding discovery.
            if (!root.active)
                return
            if (root._abyssHostAvailableFor(root.targetOutputName)) {
                if (!root.presentationRetained)
                    root._startPresentationForCurrentRequest()
                return
            }
            if (root.presentationRetained) {
                if (root.hadResolvedAnchor)
                    root._cancelForSourceLoss()
                else
                    root.finishPresentation(false)
            }
        }
    }

    function _outputExists(outputName): bool {
        const wanted = String(outputName ?? "")
        return wanted.length > 0
            && (Quickshell.screens ?? []).some(screen =>
                String(screen?.name ?? "") === wanted)
    }

    function _reconcileOutputTopology(): void {
        if (!root.active)
            return
        if (root._outputExists(root.targetOutputName))
            return

        if (root.presentationMatchesActive) {
            if (root.hadResolvedAnchor) {
                // A trusted attached source vanished with its output. Preserve
                // source-loss semantics and cancel the real AuthFlow.
                root._cancelForSourceLoss()
                return
            }
            // Top-center fallback has no source geometry to preserve. Move the
            // same active AuthFlow to a remaining output after hot-unplug.
            root.targetOutputName = GlobalStates.resolveOutputName("", [])
            return
        }

        if (root.presentationRetained && root.presentationSerial === 0) {
            // A queued successor is waiting for the previous popup tail, but
            // that tail's output no longer exists. Release it immediately and
            // let finishPresentation() start the current AuthFlow presentation.
            root.finishPresentation(true)
            return
        }

        if (!root.presentationRetained && root.abyssPresenterAvailable)
            root._startPresentationForCurrentRequest()
    }

    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            Qt.callLater(root._reconcileOutputTopology)
        }
    }

    onActiveChanged: {
        if (root.active)
            return
        // Outside an active Abyss presenter there is no retract tail to retain.
        // Clearing here prevents an auth request that completed while locked or
        // after a family switch from resurfacing as stale presentation state.
        if (!root.abyssPresenterAvailable) {
            root.presentationRetained = false
            root.presentationSerial = 0
        }
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

    function _cancelForSourceLoss(): void {
        // Source invalidation can be observed both through the live usability
        // binding and registry removal. AuthFlow cancellation is a backend
        // action, so issue it exactly once for this authentication request.
        if (!root.active || !root.hadResolvedAnchor
                || !root.presentationMatchesActive
                || root._sourceLossCancelIssued)
            return
        root._sourceLossCancelIssued = true
        root.resolvedAnchor = null
        root.cancel()
    }

    onResolvedAnchorUsableChanged: {
        if (!root.resolvedAnchorUsable)
            root._cancelForSourceLoss()
    }

    Connections {
        target: PopupAnchorRegistry
        function onAnchorRemoved(item): void {
            if (root.resolvedAnchor === item)
                root._cancelForSourceLoss()
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
