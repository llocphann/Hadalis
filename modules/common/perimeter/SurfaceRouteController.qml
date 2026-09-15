pragma Singleton
import QtQuick
QtObject {
    id: root
    readonly property string conflictPolicy: "exclusive-per-output"
    property var routes: ({})
    signal opened(string outputName, var route)
    signal closed(string outputName, var route, string reason)
    signal backRequested(string outputName, var route)
    function current(outputName) { return root.routes[String(outputName)] || null }
    function isOpen(outputName) { return root.current(outputName) !== null }
    function open(route) {
        const outputName = String(route?.output ?? route?.outputName ?? "")
        const sourceInstance = String(route?.sourceInstance ?? "")
        const slot = String(route?.slot ?? route?.slotId ?? "")
        if (!outputName || !sourceInstance || !PerimeterTopology.isValidSlot(slot)) return false
        const edge = String(route?.edge ?? PerimeterTopology.edgeForSlot(slot))
        if (edge !== PerimeterTopology.edgeForSlot(slot)) return false
        const normalized = { output: outputName, family: String(route?.family ?? "default"), surface: String(route?.surface ?? "default"), page: String(route?.page ?? ""), sourceInstance: sourceInstance, slot: slot, edge: edge, anchorRect: route?.anchorRect ?? Qt.rect(0, 0, 0, 0) }
        const previous = root.current(outputName)
        if (previous) root.closed(outputName, previous, "replaced")
        const next = Object.assign({}, root.routes)
        next[outputName] = normalized
        root.routes = next
        root.opened(outputName, normalized)
        return true
    }
    function close(outputName, reason) {
        const name = String(outputName)
        const previous = root.current(name)
        if (!previous) return false
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
        const outputName = String(route?.output ?? route?.outputName ?? "")
        const active = root.current(outputName)
        const same = active && active.family === String(route?.family ?? "default") && active.surface === String(route?.surface ?? "default") && active.sourceInstance === String(route?.sourceInstance ?? "")
        return same ? root.close(outputName, "toggle") : root.open(route)
    }
    function back(outputName) {
        const name = String(outputName)
        const route = root.current(name)
        if (!route) return false
        if (route.page.length > 0) { root.backRequested(name, route); return true }
        return root.close(name, "back")
    }
}
