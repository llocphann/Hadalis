pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property string conflictPolicy: "exclusive-per-output"
    property var routes: ({})

    signal opened(string outputName, var route)
    signal updated(string outputName, var route)
    signal closed(string outputName, var route, string reason)
    signal backRequested(string outputName, var route)

    function current(outputName) {
        return root.routes[String(outputName)] || null
    }

    function isOpen(outputName) {
        return root.current(outputName) !== null
    }

    function _routeAnchorKey(route) {
        if (!route)
            return ""
        return AnchorRegistry.keyFor(route.output,
            route.sourceInstance, route.surface)
    }

    function _rectHasArea(rect) {
        return rect && rect.width > 0 && rect.height > 0
    }

    function _sameRect(a, b) {
        return a && b
            && a.x === b.x && a.y === b.y
            && a.width === b.width && a.height === b.height
    }

    function _normalize(route) {
        const outputName = String(route?.output ?? route?.outputName ?? "")
        const sourceInstance = String(route?.sourceInstance ?? "")
        const slot = String(route?.slot ?? route?.slotId ?? "")
        const surface = String(route?.surface ?? "default")
        if (!outputName || !sourceInstance || !PerimeterTopology.isValidSlot(slot))
            return null

        const expectedEdge = PerimeterTopology.edgeForSlot(slot)
        const edge = String(route?.edge ?? expectedEdge)
        if (edge !== expectedEdge)
            return null

        // AnchorRegistry is the geometry authority. Never accept a caller-owned
        // anchor snapshot here: it can already be stale by the time a surface
        // opens, and it may not use output-local coordinates.
        const anchor = AnchorRegistry.lookup(outputName, sourceInstance, surface)
        if (!anchor
                || String(anchor.slotId ?? "") !== slot
                || String(anchor.coordinateSpace ?? "") !== "output-local"
                || !root._rectHasArea(anchor.rect)) {
            return null
        }

        return {
            output: outputName,
            family: String(route?.family ?? "default"),
            surface: surface,
            page: String(route?.page ?? ""),
            sourceInstance: sourceInstance,
            slot: slot,
            edge: edge,
            anchorRect: anchor.rect
        }
    }

    function _onAnchorChanged(key, record) {
        const outputName = String(record?.outputName ?? "")
        const active = root.current(outputName)
        if (!active || root._routeAnchorKey(active) !== String(key ?? ""))
            return false

        const slot = String(record?.slotId ?? "")
        const rect = record?.rect
        if (!PerimeterTopology.isValidSlot(slot)
                || String(record?.coordinateSpace ?? "") !== "output-local"
                || !root._rectHasArea(rect)) {
            return root.close(outputName, "source-hidden")
        }

        const edge = PerimeterTopology.edgeForSlot(slot)
        if (active.slot === slot && active.edge === edge
                && root._sameRect(active.anchorRect, rect)) {
            return false
        }

        const nextRoute = Object.assign({}, active, {
            slot: slot,
            edge: edge,
            anchorRect: rect
        })
        const next = Object.assign({}, root.routes)
        next[outputName] = nextRoute
        root.routes = next
        root.updated(outputName, nextRoute)
        return true
    }

    function _onAnchorRemoved(key) {
        const anchorKey = String(key ?? "")
        for (const outputName of Object.keys(root.routes)) {
            const active = root.routes[outputName]
            if (root._routeAnchorKey(active) === anchorKey)
                return root.close(outputName, "source-hidden")
        }
        return false
    }

    function open(route) {
        const normalized = root._normalize(route)
        if (!normalized)
            return false

        const outputName = normalized.output
        const previous = root.current(outputName)
        const next = Object.assign({}, root.routes)
        next[outputName] = normalized

        // Commit the authoritative state before lifecycle signals fire. This
        // keeps observers from reading a stale previous route during replacement
        // and avoids a transient no-route gap on the output.
        root.routes = next
        if (previous)
            root.closed(outputName, previous, "replaced")
        root.opened(outputName, normalized)
        return true
    }

    function close(outputName, reason) {
        const name = String(outputName)
        const previous = root.current(name)
        if (!previous)
            return false

        const next = Object.assign({}, root.routes)
        delete next[name]
        root.routes = next
        root.closed(name, previous, String(reason || "explicit"))
        return true
    }

    function dismiss(outputName, reason) {
        const value = String(reason || "explicit")
        const allowed = ["escape", "backdrop", "focus-loss", "source-hidden", "explicit"]
        return root.close(outputName, allowed.includes(value) ? value : "explicit")
    }

    function toggle(route) {
        const normalized = root._normalize(route)
        if (!normalized)
            return false

        const active = root.current(normalized.output)
        const same = active
            && active.family === normalized.family
            && active.surface === normalized.surface
            && active.sourceInstance === normalized.sourceInstance
        return same
            ? root.close(normalized.output, "toggle")
            : root.open(normalized)
    }

    function back(outputName) {
        const name = String(outputName)
        const route = root.current(name)
        if (!route)
            return false
        if (route.page.length > 0) {
            root.backRequested(name, route)
            return true
        }
        return root.close(name, "back")
    }

    property var _anchorRegistryConnections: Connections {
        target: AnchorRegistry
        function onChanged(key, record) {
            root._onAnchorChanged(key, record)
        }
        function onRemoved(key) {
            root._onAnchorRemoved(key)
        }
    }
}
