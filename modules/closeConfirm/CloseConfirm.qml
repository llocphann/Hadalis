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

    // Debounce to prevent double-trigger
    property bool _busy: false
    Timer {
        id: debounce
        interval: 200
        onTriggered: root._busy = false
    }

    // Config state
    readonly property bool confirmEnabled: Config.options?.closeConfirm?.enabled ?? false

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

    function processWindow(win): void {
        const snapshot = root._snapshotWindow(win)
        if (!root.confirmEnabled) {
            root.closeWindowFast(snapshot);
            return;
        }

        const outputName = root._outputNameForWindow(snapshot)
        const abyssAvailable = Config.options?.panelFamily === "abyss"
            && (Config.options?.enabledPanels ?? []).includes("abyssPerimeter")
        if (abyssAvailable) {
            const appId = String(snapshot?.app_id ?? "")
            const title = String(snapshot?.title ?? "")
            const appName = title || appId || Translation.tr("Unknown")
            ConfirmationService.enqueue({
                owner: "closeConfirm",
                sourceWindowId: Number(snapshot?.id ?? 0),
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

        root.targetWindow = snapshot;
        root.dialogScreen = root._screenForOutput(outputName);
        root.dialogVisible = true;
    }

    function _cancelIfTargetGone(): void {
        const request = ConfirmationService.currentRequest
        if (!ConfirmationService.requestVisible
                || String(request?.owner ?? "") !== "closeConfirm")
            return
        const windowId = Number(request?.sourceWindowId ?? 0)
        if (windowId <= 0 || !NiriService.windowListReady)
            return
        const stillExists = (NiriService.windows ?? []).some(candidate =>
            Number(candidate?.id ?? 0) === windowId)
        if (!stillExists)
            ConfirmationService.cancel()
    }

    Connections {
        target: NiriService
        function onWindowsChanged(): void {
            root._cancelIfTargetGone()
        }
    }

    Connections {
        target: ConfirmationService
        function onRequestActivated(requestId): void {
            root._cancelIfTargetGone()
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
            root.dialogVisible = false;
            root.targetWindow = null;
            root.dialogScreen = null;
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
        if (targetWindow) {
            closeWindowFast(targetWindow);
        }
        dialogVisible = false;
        targetWindow = null;
        dialogScreen = null;
    }

    function cancel(): void {
        dialogVisible = false;
        targetWindow = null;
        dialogScreen = null;
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
