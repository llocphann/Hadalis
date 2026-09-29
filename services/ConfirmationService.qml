pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs

// Runtime confirmation queue. Requests may contain live callback closures, so
// this state is intentionally not Config/GlobalStates/IPC-serializable.
Singleton {
    id: root

    property var currentRequest: null
    property bool requestVisible: false
    property bool resolving: false
    property var queue: []
    property int _nextRequestId: 0

    readonly property bool active: root.currentRequest !== null
    readonly property int currentRequestId:
        Number(root.currentRequest?._requestId ?? 0)
    readonly property string targetOutputName:
        String(root.currentRequest?._resolvedOutput ?? "")
    readonly property var resolvedAnchor:
        root.currentRequest?._resolvedAnchor ?? null
    readonly property string resolvedAnchorKind:
        String(root.currentRequest?._resolvedAnchorKind ?? "")
    readonly property bool resolvedAnchorUsable:
        root.currentRequest?._hadResolvedAnchor !== true
            || PopupAnchorRegistry.isUsable(root.resolvedAnchor)

    signal requestActivated(int requestId)
    signal requestResolved(int requestId, string actionId)

    function _normalizeActions(actions): var {
        const source = Array.isArray(actions) ? actions : []
        return source.map((action, index) => Object.assign({}, action ?? {}, {
            id: String(action?.id ?? ("action-" + index)),
            label: String(action?.label ?? action?.id ?? ("Action " + (index + 1)))
        }))
    }

    function enqueue(request): int {
        const id = ++root._nextRequestId
        const prepared = Object.assign({}, request ?? {}, {
            _requestId: id,
            actions: root._normalizeActions(request?.actions)
        })
        if (root.currentRequest !== null) {
            const next = root.queue.slice()
            next.push(prepared)
            root.queue = next
        } else {
            root._activate(prepared)
        }
        return id
    }

    function _activate(request): void {
        if (!request)
            return
        // Resolve the requested/focused output before source lookup so mirrored
        // app anchors can prefer the source screen instead of registration order.
        const requestedOutput = GlobalStates.resolveOutputName(
            String(request.outputName ?? ""), [])
        const sourceContext = Object.assign({}, request, {
            outputName: requestedOutput
        })
        const resolved = PopupAnchorRegistry.resolve(sourceContext)
        const output = String(resolved?.outputName ?? "").length > 0
            ? String(resolved.outputName)
            : requestedOutput
        root.currentRequest = Object.assign({}, request, {
            _resolvedAnchor: resolved?.item ?? null,
            _resolvedAnchorKind: String(resolved?.kind ?? ""),
            _resolvedOutput: String(output ?? ""),
            _hadResolvedAnchor: resolved?.item !== null
                && resolved?.item !== undefined
        })
        root.resolving = false
        root.requestVisible = true
        root.requestActivated(root.currentRequestId)
    }

    function _invoke(callback): void {
        if (typeof callback !== "function")
            return
        Qt.callLater(() => callback())
    }

    function _actionUsable(action): bool {
        return action !== null && action !== undefined
            && action.enabled !== false
            && action.visible !== false
    }

    function _resolveAction(action, force = false): void {
        if (!root.currentRequest || !root.requestVisible || root.resolving)
            return
        if (!force && !root._actionUsable(action))
            return
        if (action === null || action === undefined)
            return

        const wanted = String(action?.id ?? "")
        if (!wanted)
            return
        const request = root.currentRequest
        root.resolving = true
        root.requestVisible = false
        root.requestResolved(Number(request._requestId ?? 0), wanted)
        root._invoke(action.callback)
        root._invoke(() => {
            if (typeof request.onResolved === "function")
                request.onResolved(wanted)
        })
    }

    function resolve(actionId): void {
        if (!root.currentRequest || !root.requestVisible || root.resolving)
            return
        const wanted = String(actionId ?? "")
        const actions = root.currentRequest.actions ?? []
        const action = actions.find(candidate =>
            String(candidate?.id ?? "") === wanted)
        root._resolveAction(action, false)
    }

    function defaultActionId(): string {
        const actions = root.currentRequest?.actions ?? []
        const preferred = actions.find(action =>
            root._actionUsable(action)
            && (action?.isDefault === true || action?.role === "default"))
        const fallback = actions.find(action =>
            root._actionUsable(action)
            && action?.isCancel !== true && action?.role !== "cancel")
        return String(preferred?.id ?? fallback?.id ?? "")
    }

    function cancelAction(): var {
        const actions = root.currentRequest?.actions ?? []
        return actions.find(action =>
            action?.isCancel === true || action?.role === "cancel") ?? null
    }

    function cancelActionId(): string {
        const cancel = root.cancelAction()
        return root._actionUsable(cancel) ? String(cancel?.id ?? "") : ""
    }

    function acceptDefault(): void {
        const id = root.defaultActionId()
        if (id.length > 0)
            root.resolve(id)
    }

    function cancel(force = false): void {
        if (!root.currentRequest || !root.requestVisible || root.resolving)
            return
        const cancelAction = root.cancelAction()
        if (cancelAction) {
            if (!force && !root._actionUsable(cancelAction))
                return
            root._resolveAction(cancelAction, force)
            return
        }

        const request = root.currentRequest
        root.resolving = true
        root.requestVisible = false
        root.requestResolved(Number(request._requestId ?? 0), "cancel")
        root._invoke(request.onCancel)
        root._invoke(() => {
            if (typeof request.onResolved === "function")
                request.onResolved("cancel")
        })
    }

    // Presenter calls this only after StyledPopup has released its visual tail.
    // Keeping currentRequest alive until then prevents content/anchor teleport
    // while Pyramid is still retracting.
    function finishPresentation(requestId): void {
        if (!root.currentRequest || root.requestVisible)
            return
        if (Number(requestId) !== root.currentRequestId)
            return
        root.currentRequest = null
        root.resolving = false
        Qt.callLater(root._activateNext)
    }

    function _activateNext(): void {
        if (root.currentRequest !== null || root.queue.length === 0)
            return
        const next = root.queue.slice()
        const request = next.shift()
        root.queue = next
        root._activate(request)
    }

    function cancelOwned(owner): void {
        const key = String(owner ?? "")
        if (!key)
            return
        root.queue = root.queue.filter(request =>
            String(request?.owner ?? "") !== key)
        if (root.requestVisible
                && String(root.currentRequest?.owner ?? "") === key)
            root.cancel()
    }

    onResolvedAnchorUsableChanged: {
        // A retained source Item can become non-presented without being
        // destroyed/unregistered (notably an auto-hidden host). Treat that as
        // source loss and reject in place rather than teleporting to fallback.
        if (root.requestVisible
                && root.currentRequest?._hadResolvedAnchor === true
                && !root.resolvedAnchorUsable)
            root.cancel(true)
    }

    function _outputExists(outputName): bool {
        const wanted = String(outputName ?? "")
        return wanted.length > 0
            && (Quickshell.screens ?? []).some(screen =>
                String(screen?.name ?? "") === wanted)
    }

    function _reconcileOutputTopology(): void {
        if (!root.requestVisible || !root.currentRequest)
            return
        if (root._outputExists(root.targetOutputName))
            return

        // A real attached source disappearing with its output is source loss:
        // cancel rather than teleporting the request to a different app anchor.
        if (root.currentRequest?._hadResolvedAnchor === true) {
            root.cancel(true)
            return
        }

        // A top-center fallback has no source geometry to preserve. If its
        // output is hot-unplugged, keep the same request/callback ownership and
        // move only that fallback presentation to a remaining valid output.
        const replacement = GlobalStates.resolveOutputName(
            String(root.currentRequest?.outputName ?? ""), [])
        if (!replacement || replacement === root.targetOutputName)
            return
        root.currentRequest = Object.assign({}, root.currentRequest, {
            _resolvedOutput: replacement
        })
    }

    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            Qt.callLater(root._reconcileOutputTopology)
        }
    }

    Connections {
        target: PopupAnchorRegistry
        function onAnchorRemoved(item): void {
            // An attached prompt must not jump to top-center while visible.
            // Source loss is lifecycle-forced so a disabled/hidden cancel action
            // cannot strand the request on an anchor that no longer exists.
            if (root.requestVisible
                    && root.currentRequest?._hadResolvedAnchor === true
                    && root.currentRequest?._resolvedAnchor === item)
                root.cancel(true)
        }
    }
}
