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
        const resolved = PopupAnchorRegistry.resolve(request)
        const requestedOutput = String(request.outputName ?? "")
        const output = String(resolved?.outputName ?? "").length > 0
            ? String(resolved.outputName)
            : GlobalStates.resolveOutputName(requestedOutput, [])
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

    function resolve(actionId): void {
        if (!root.currentRequest || !root.requestVisible || root.resolving)
            return
        const wanted = String(actionId ?? "")
        const actions = root.currentRequest.actions ?? []
        const action = actions.find(candidate =>
            String(candidate?.id ?? "") === wanted)
        if (!action)
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

    function defaultActionId(): string {
        const actions = root.currentRequest?.actions ?? []
        const preferred = actions.find(action =>
            action?.isDefault === true || action?.role === "default")
        const fallback = actions.find(action =>
            action?.isCancel !== true && action?.role !== "cancel")
        return String(preferred?.id ?? fallback?.id ?? "")
    }

    function cancelActionId(): string {
        const actions = root.currentRequest?.actions ?? []
        const cancel = actions.find(action =>
            action?.isCancel === true || action?.role === "cancel")
        return String(cancel?.id ?? "")
    }

    function acceptDefault(): void {
        const id = root.defaultActionId()
        if (id.length > 0)
            root.resolve(id)
    }

    function cancel(): void {
        if (!root.currentRequest || !root.requestVisible || root.resolving)
            return
        const id = root.cancelActionId()
        if (id.length > 0) {
            root.resolve(id)
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

    Connections {
        target: PopupAnchorRegistry
        function onAnchorRemoved(item): void {
            // An attached prompt must not jump to top-center while visible.
            // Cancel the owned request; a future queued request resolves anew.
            if (root.requestVisible
                    && root.currentRequest?._hadResolvedAnchor === true
                    && root.currentRequest?._resolvedAnchor === item)
                root.cancel()
        }
    }
}
