import QtQuick
import qs
import qs.services
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    // Window captured at the moment of trigger (prevents race condition)
    property var targetWindow: null
    property var dialogScreen: null
    property bool dialogVisible: false
    // When a connected request fails over to the standalone renderer, retain
    // its ConfirmationService slot until the standalone dialog resolves. This
    // preserves one-at-a-time queue semantics across renderer handoff.
    property int _standaloneTransferredRequestId: 0

    // Debounce to prevent double-trigger
    property bool _busy: false
    property int _windowListRevision: 0
    Timer {
        id: debounce
        interval: 200
        onTriggered: root._busy = false
    }

    // Config state
    readonly property bool confirmEnabled: Config.options?.closeConfirm?.enabled ?? false
    readonly property bool abyssConfigured:
        Config.options?.panelFamily === "abyss"
        && (Config.options?.enabledPanels ?? []).includes("abyssPerimeter")

    function _abyssPresenterAvailableFor(outputName): bool {
        return root.abyssConfigured
            && AbyssPromptHostRegistry.hasOutput(String(outputName ?? ""))
    }

    function _showStandaloneForRequest(request): void {
        const windowId = Number(request?.sourceWindowId ?? 0)
        const requestId = Number(request?._requestId ?? 0)
        if (windowId <= 0 || requestId <= 0)
            return
        if (!ConfirmationService.beginPresentationHandoff(requestId))
            return

        const cached = (NiriService.windows ?? []).find(candidate =>
            Number(candidate?.id ?? 0) === windowId)
        const snapshot = root._snapshotWindow(cached ?? {
            id: windowId,
            app_id: String(request?.appId ?? ""),
            title: String(request?.appName ?? "")
        })
        root._standaloneTransferredRequestId = requestId
        root.targetWindow = snapshot
        root.dialogScreen = root._screenForOutput(
            ConfirmationService.targetOutputName)
        root.dialogVisible = true
    }

    function _clearStandaloneState(): void {
        root.dialogVisible = false
        root.targetWindow = null
        root.dialogScreen = null
        root._standaloneTransferredRequestId = 0
    }

    function _releaseAbyssRequestIfUnavailable(): void {
        const request = ConfirmationService.currentRequest
        if (String(request?.owner ?? "") !== "closeConfirm")
            return
        const requestId = Number(request?._requestId ?? 0)
        if (root._standaloneTransferredRequestId === requestId)
            return
        if (root._abyssPresenterAvailableFor(
                ConfirmationService.targetOutputName))
            return

        // Preserve the exact semantic request while moving only its renderer.
        // beginPresentationHandoff() hides the connected popup behind a release
        // gate without emitting requestResolved or invoking a cancel callback.
        if (ConfirmationService.requestVisible) {
            root._showStandaloneForRequest(request)
            if (root._standaloneTransferredRequestId === requestId)
                return
        }

        // If the request already resolved, only its owning presenter may
        // release the visual tail. Component teardown and normal popup retract
        // already call finishPresentation(); forcing it here could let a queued
        // successor reuse geometry before the old tail is actually gone.
    }

    onAbyssConfiguredChanged:
        root._releaseAbyssRequestIfUnavailable()

    Connections {
        target: AbyssPromptHostRegistry
        function onEntriesChanged(): void {
            root._releaseAbyssRequestIfUnavailable()
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            if (!root.dialogVisible)
                return
            // Standalone failover is intentionally outside the connected field,
            // so keep its fullscreen host on a live output after hotplug too.
            // _screenForOutput() falls back to the currently focused screen if
            // the request's original output no longer exists.
            const requested = root._standaloneTransferredRequestId > 0
                ? ConfirmationService.targetOutputName : ""
            root.dialogScreen = root._screenForOutput(requested)
        }
    }

    function _snapshotWindow(win): var {
        const snapshot = Object.assign({}, win ?? {})
        const id = Number(snapshot?.id ?? 0)
        if (id <= 0)
            return snapshot

        // triggerWindow() deliberately receives only the race-safe ID/app ID
        // captured by the keybind helper. Presentation metadata may be enriched
        // from Niri's cache as long as it still describes that exact ID.
        const cached = (NiriService.windows ?? []).find(candidate =>
            Number(candidate?.id ?? 0) === id)
        if (!cached)
            return snapshot
        snapshot._observedInWindowList = true
        if (!String(snapshot?.app_id ?? "").length)
            snapshot.app_id = cached.app_id
        if (!String(snapshot?.title ?? "").length)
            snapshot.title = cached.title
        if (snapshot.workspace_id === undefined
                || snapshot.workspace_id === null)
            snapshot.workspace_id = cached.workspace_id
        return snapshot
    }

    function _outputNameForWindow(win): string {
        const workspace = NiriService.workspaces?.[win?.workspace_id] ?? null
        const workspaceOutput = String(workspace?.output ?? "")
        if (workspaceOutput.length > 0)
            return workspaceOutput
        return String(GlobalStates.focusedScreen?.name ?? "")
    }

    function _screenForOutput(outputName): var {
        const name = String(outputName ?? "")
        if (name.length > 0) {
            const screen = Quickshell.screens.find(candidate =>
                String(candidate?.name ?? "") === name)
            if (screen)
                return screen
        }
        return GlobalStates.focusedScreen
    }

    // Fallback: get focused window directly from niri when activeWindow is stale
    Process {
        id: focusedWindowProc
        command: ["niri", "msg", "-j", "focused-window"]
        stdout: SplitParser {
            onRead: line => {
                if (!line?.trim())
                    return;
                try {
                    const win = JSON.parse(line);
                    if (win?.id)
                        root.processWindow(win);
                } catch (e) {}
            }
        }
    }

    function _sameCloseWindowRequest(request, windowId): bool {
        return String(request?.owner ?? "") === "closeConfirm"
            && Number(request?.sourceWindowId ?? 0) === Number(windowId ?? 0)
    }

    function _hasPendingAbyssRequest(windowId): bool {
        const id = Number(windowId ?? 0)
        if (id <= 0)
            return false
        if (root._sameCloseWindowRequest(
                ConfirmationService.currentRequest, id))
            return true
        return (ConfirmationService.queue ?? []).some(request =>
            root._sameCloseWindowRequest(request, id))
    }

    function processWindow(win): void {
        const snapshot = root._snapshotWindow(win)
        if (!root.confirmEnabled) {
            root.closeWindowFast(snapshot);
            return;
        }

        const outputName = root._outputNameForWindow(snapshot)
        if (root.abyssConfigured) {
            const windowId = Number(snapshot?.id ?? 0)
            // All Abyss-family close confirmations enter one semantic queue,
            // even when the connected host is temporarily unavailable. The
            // activation handler hands such requests to the standalone renderer
            // without letting them overlap a connected/queued successor.
            // Repeated close binds for the same window must not create a second
            // prompt/callback transaction while the first is visible, queued,
            // transferred to standalone, or still retracting.
            if (root._hasPendingAbyssRequest(windowId))
                return
            const appId = String(snapshot?.app_id ?? "")
            const title = String(snapshot?.title ?? "")
            const appName = title || appId || Translation.tr("Unknown")
            ConfirmationService.enqueue({
                owner: "closeConfirm",
                sourceWindowId: windowId,
                sourceWindowObserved:
                    snapshot?._observedInWindowList === true,
                sourceWindowRevision: root._windowListRevision,
                appId: appId,
                appName: appName,
                outputName: outputName,
                title: Translation.tr("Close this window?"),
                message: appName,
                actions: [
                    {
                        id: "cancel",
                        label: Translation.tr("Cancel"),
                        role: "cancel",
                        isCancel: true
                    },
                    {
                        id: "close",
                        label: Translation.tr("Close"),
                        role: "default",
                        isDefault: true,
                        callback: () => root.closeWindowFast(snapshot)
                    }
                ]
            })
            return
        }

        // The legacy renderer has one modal slot and no semantic queue. Never
        // overwrite a visible/transferred target with a later close trigger.
        if (root.dialogVisible)
            return
        root.targetWindow = snapshot;
        root.dialogScreen = root._screenForOutput(outputName);
        root.dialogVisible = true;
    }

    function _cancelIfTargetGone(): void {
        const request = ConfirmationService.currentRequest
        if (String(request?.owner ?? "") !== "closeConfirm")
            return
        const requestId = Number(request?._requestId ?? 0)
        const transferred =
            root._standaloneTransferredRequestId > 0
            && root._standaloneTransferredRequestId === requestId
        if (!ConfirmationService.requestVisible && !transferred)
            return

        const windowId = Number(request?.sourceWindowId ?? 0)
        if (windowId <= 0 || !NiriService.windowListReady)
            return
        // A triggerWindow snapshot can be newer than NiriService's batched
        // cache. Do not reject a valid fresh window merely because that cache
        // has not observed it yet. Once the ID was observed, or a newer
        // authoritative windows snapshot arrived after enqueue, absence is real.
        const observed = request?.sourceWindowObserved === true
        const requestRevision = Number(request?.sourceWindowRevision ?? 0)
        if (!observed && root._windowListRevision <= requestRevision)
            return
        const stillExists = (NiriService.windows ?? []).some(candidate =>
            Number(candidate?.id ?? 0) === windowId)
        if (stillExists)
            return

        if (transferred) {
            // The standalone handoff is still the same semantic request. If its
            // captured window vanished, lifecycle-cancel that request without
            // pretending the user clicked its cancel action. Keep the renderer
            // visible if cancellation could not acquire the transaction.
            if (!ConfirmationService.cancelPresentationHandoff(
                    requestId, true))
                return
            root._clearStandaloneState()
            return
        }
        ConfirmationService.cancel()
    }

    Connections {
        target: NiriService
        function onWindowsChanged(): void {
            root._windowListRevision += 1
            root._cancelIfTargetGone()
        }
    }

    Connections {
        target: ConfirmationService
        function onRequestActivated(requestId): void {
            root._cancelIfTargetGone()
            root._releaseAbyssRequestIfUnavailable()
        }
    }

    function _acceptTrigger(): bool {
        if (root._busy)
            return false;
        root._busy = true;
        debounce.restart();
        return true;
    }

    IpcHandler {
        target: "closeConfirm"

        function trigger(): void {
            if (!root._acceptTrigger())
                return;

            // Try cached activeWindow first, fallback to niri query
            const win = NiriService.activeWindow;
            if (win?.id) {
                root.processWindow(win);
            } else {
                focusedWindowProc.running = true;
            }
        }

        function triggerWindow(windowId: int, appId: string): void {
            if (windowId <= 0 || !root._acceptTrigger())
                return;
            root.processWindow({
                id: windowId,
                app_id: appId
            });
        }

        function close(): void {
            ConfirmationService.cancelOwned("closeConfirm")
            root._clearStandaloneState()
        }
    }

    function closeWindowFast(win): void {
        if (!win?.id)
            return;
        const appId = String(win?.app_id ?? "").toLowerCase();
        if (appId === "spotify") {
            MinimizedWindows.minimize(win.id);
            return;
        }
        // Use niri msg directly - more reliable than socket IPC for some apps
        Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(win.id)]);
    }

    function confirmClose(): void {
        const requestId = root._standaloneTransferredRequestId
        if (requestId > 0) {
            // Execute the original queued callback through ConfirmationService;
            // do not bypass it with a second direct close path. If ownership
            // changed unexpectedly, leave the dialog intact rather than close
            // a window outside the semantic transaction.
            if (!ConfirmationService.resolvePresentationHandoff(
                    requestId, "close"))
                return
            root._clearStandaloneState()
            return
        }
        if (targetWindow)
            closeWindowFast(targetWindow)
        root._clearStandaloneState()
    }

    function cancel(): void {
        const requestId = root._standaloneTransferredRequestId
        if (requestId > 0
                && !ConfirmationService.cancelPresentationHandoff(
                    requestId, false))
            return
        root._clearStandaloneState()
    }

    // Dialog UI
    Loader {
        // processWindow() sets dialogVisible only when the connected Abyss
        // perimeter path is unavailable. Keep this renderer as the fail-safe
        // so disabling abyssPerimeter can never create an invisible prompt.
        active: root.dialogVisible

        sourceComponent: PanelWindow {
            screen: root.dialogScreen ?? GlobalStates.focusedScreen

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            color: "transparent"
            WlrLayershell.namespace: "quickshell:closeConfirm"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore

            Loader {
                id: contentLoader
                anchors.fill: parent
                focus: true
                // Both contents declare targetWindow as required, so they must be
                // instantiated from an inline Component. A Loader source URL cannot
                // initialize required properties and fails to Loader.Error, leaving
                // this keyboard-exclusive fullscreen window with no way out.
                sourceComponent: Config.options?.panelFamily === "waffle" ? waffleContent : iiContent
                onLoaded: if (item) item.forceActiveFocus()

                Component {
                    id: iiContent
                    CloseConfirmContent {
                        targetWindow: root.targetWindow
                        onConfirm: root.confirmClose()
                        onCancel: root.cancel()
                    }
                }

                Component {
                    id: waffleContent
                    WCloseConfirmContent {
                        targetWindow: root.targetWindow
                        onConfirm: root.confirmClose()
                        onCancel: root.cancel()
                    }
                }
            }
        }
    }
}
