pragma Singleton

import QtQuick
import qs.modules.common

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
        const surface = AnchorRegistry.surfaceName(route?.surface)
        if (!outputName || !sourceInstance || !PerimeterTopology.isValidSlot(slot)
                || !PerimeterConfig.validate(outputName)) {
            return null
        }

        const expectedEdge = PerimeterTopology.edgeForSlot(slot)
        const edge = String(route?.edge ?? expectedEdge)
        if (edge !== expectedEdge)
            return null

        // Route placement and module identity come from the persisted perimeter
        // configuration. A stale publisher must not make an old slot/module
        // authoritative after the same instance ID has been reconfigured.
        const configuredSlot = PerimeterConfig.placementForInstance(
            outputName, sourceInstance)
        const descriptor = PerimeterConfig.instanceDescriptor(
            outputName, sourceInstance)
        const configuredModule = String(descriptor?.moduleId ?? "")
        if (configuredSlot !== slot || !configuredModule)
            return null

        // AnchorRegistry is the geometry authority. Never accept a caller-owned
        // anchor snapshot here: it can already be stale by the time a surface
        // opens, and it may not use output-local coordinates.
        const anchor = AnchorRegistry.lookup(outputName, sourceInstance, surface)
        if (!anchor
                || String(anchor.slotId ?? "") !== slot
                || String(anchor.moduleId ?? "") !== configuredModule
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
            sourceModule: configuredModule,
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
                || String(record?.moduleId ?? "") !== active.sourceModule
                || String(record?.coordinateSpace ?? "") !== "output-local"
                || !root._rectHasArea(rect)) {
            return root.close(outputName, "source-hidden")
        }

        // Persisted placement remains authoritative while an instance moves.
        // During declarative reflow the old publisher can still emit geometry
        // with the same registry key for one turn; ignore that stale record
        // rather than letting it move the route back to the old slot.
        if (!PerimeterConfig.validate(outputName))
            return root.close(outputName, "source-hidden")
        const configuredSlot = PerimeterConfig.placementForInstance(
            outputName, active.sourceInstance)
        const descriptor = PerimeterConfig.instanceDescriptor(
            outputName, active.sourceInstance)
        if (!PerimeterTopology.isValidSlot(configuredSlot)
                || String(descriptor?.moduleId ?? "") !== active.sourceModule) {
            return root.close(outputName, "source-hidden")
        }
        if (slot !== configuredSlot) {
            if (configuredSlot !== active.slot)
                return false
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

    function _closeAfterPlacementMove(outputName, anchorKey, sourceInstance, surface) {
        Qt.callLater(() => {
            const active = root.current(outputName)
            if (!active
                    || active.sourceInstance !== sourceInstance
                    || active.surface !== surface
                    || root._routeAnchorKey(active) !== anchorKey) {
                return
            }

            // A slot move destroys the old hosted publisher and creates a new
            // one with the same output/instance/surface key. Give that synchronous
            // declarative reflow one event-loop turn before treating the temporary
            // registry gap as a genuinely hidden source.
            const replacement = AnchorRegistry.lookup(outputName,
                sourceInstance, surface)
            if (!replacement)
                root.close(outputName, "source-hidden")
        })
    }

    function _onAnchorRemoved(key) {
        const anchorKey = String(key ?? "")
        for (const outputName of Object.keys(root.routes)) {
            const active = root.routes[outputName]
            if (root._routeAnchorKey(active) !== anchorKey)
                continue

            const configuredSlot = PerimeterConfig.validate(outputName)
                ? PerimeterConfig.placementForInstance(outputName,
                    active.sourceInstance)
                : ""
            if (PerimeterTopology.isValidSlot(configuredSlot)
                    && configuredSlot !== active.slot) {
                root._closeAfterPlacementMove(outputName, anchorKey,
                    active.sourceInstance, active.surface)
                return true
            }
            return root.close(outputName, "source-hidden")
        }
        return false
    }

    function _onConfigRevisionChanged() {
        // Config changes can invalidate a route before the hosted source has had
        // a chance to destroy its publisher. Fail closed for invalid/unplaced
        // sources, while leaving valid slot moves to the anchor handoff path.
        for (const outputName of Object.keys(root.routes)) {
            const active = root.routes[outputName]
            if (!PerimeterConfig.validate(outputName)) {
                root.close(outputName, "source-hidden")
                continue
            }

            const configuredSlot = PerimeterConfig.placementForInstance(
                outputName, active.sourceInstance)
            if (!PerimeterTopology.isValidSlot(configuredSlot)) {
                root.close(outputName, "source-hidden")
                continue
            }

            const descriptor = PerimeterConfig.instanceDescriptor(
                outputName, active.sourceInstance)
            if (String(descriptor?.moduleId ?? "") !== active.sourceModule)
                root.close(outputName, "source-hidden")
        }
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

    property var _configConnections: Connections {
        target: Config
        function onRevisionChanged() {
            root._onConfigRevisionChanged()
        }
    }
}
