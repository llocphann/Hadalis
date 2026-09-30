pragma ComponentBehavior: Bound

import QtQuick

// Generic acquire/update/release owner for demand-driven services.
// The held value is remembered so release always mirrors the exact lease
// that was acquired, even when the requested value changes while active.
QtObject {
    id: root

    property bool active: false
    property var value
    property var acquire: null
    property var update: null
    property var release: null

    readonly property bool held: root._held
    readonly property var token: root._token

    property bool _completed: false
    property bool _held: false
    property var _token: null
    property var _heldValue

    function _acquire(): void {
        if (root._held || !root.active || typeof root.acquire !== "function")
            return
        const requestedValue = root.value
        root._token = root.acquire(requestedValue)
        root._heldValue = requestedValue
        root._held = true
    }

    function _release(): void {
        if (!root._held)
            return
        const heldToken = root._token
        const heldValue = root._heldValue
        root._held = false
        root._token = null
        root._heldValue = undefined
        if (typeof root.release === "function")
            root.release(heldToken, heldValue)
    }

    function sync(): void {
        if (!root._completed)
            return
        if (root.active)
            root._acquire()
        else
            root._release()
    }

    function syncValue(): void {
        if (!root._completed || !root._held)
            return

        const nextValue = root.value
        if (typeof root.update === "function") {
            const nextToken = root.update(root._token, nextValue, root._heldValue)
            if (nextToken !== undefined)
                root._token = nextToken
            root._heldValue = nextValue
            return
        }

        root._release()
        root._acquire()
    }

    onActiveChanged: root.sync()
    onValueChanged: root.syncValue()

    Component.onCompleted: {
        root._completed = true
        root.sync()
    }

    Component.onDestruction: root._release()
}
