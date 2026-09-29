pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Runtime readiness registry for concrete, frame-ready Abyss prompt hosts.
// Configuration saying "abyssPerimeter" is enabled is not enough: a QML
// load/type/shader failure must not make Confirmation believe a
// renderer exists.
Singleton {
    id: root

    property var entries: []

    readonly property bool available: root.entries.length > 0

    function registerHost(item, outputName): void {
        if (!item)
            return
        const name = String(outputName ?? "")
        if (!name)
            return
        const existing = root.entries.find(entry => entry?.item === item)
        if (existing && String(existing?.outputName ?? "") === name)
            return

        const next = root.entries.filter(entry => entry?.item !== item)
        next.push({ item: item, outputName: name })
        root.entries = next
    }

    function unregisterHost(item): void {
        if (!item)
            return
        const next = root.entries.filter(entry => entry?.item !== item)
        if (next.length !== root.entries.length)
            root.entries = next
    }

    function hasOutput(outputName): bool {
        const name = String(outputName ?? "")
        if (!name)
            return false
        return root.entries.some(entry =>
            entry?.item !== null
            && entry?.item !== undefined
            && String(entry?.outputName ?? "") === name)
    }
}
