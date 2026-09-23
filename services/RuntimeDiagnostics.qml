pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Diagnostics is passive by default. Expensive samplers must bind their
    // running/active state to root.samplingEnabled; this service never acquires
    // a lease merely because a Settings page object exists in an LRU cache.
    readonly property int leaseTtlMs: 6000
    readonly property int maxLeases: 16
    property var leases: ({})
    property int revision: 0
    readonly property int leaseCount: Object.keys(root.leases).length
    readonly property bool sessionActive: root.leaseCount > 0
    readonly property bool samplingEnabled: root.sessionActive

    function _clientId(raw): string {
        const id = String(raw ?? "").trim()
        return id.length > 0 && id.length <= 128 ? id : ""
    }

    function acquire(clientId: string): bool {
        const id = root._clientId(clientId)
        if (id.length === 0)
            return false
        const current = root.leases[id] ?? null
        if (!current && root.leaseCount >= root.maxLeases)
            return false
        const next = Object.assign({}, root.leases)
        next[id] = {
            expiresAtMs: Date.now() + root.leaseTtlMs
        }
        root.leases = next
        root.revision += 1
        return true
    }

    function heartbeat(clientId: string): bool {
        const id = root._clientId(clientId)
        if (id.length === 0 || root.leases[id] === undefined)
            return false
        const next = Object.assign({}, root.leases)
        next[id] = {
            expiresAtMs: Date.now() + root.leaseTtlMs
        }
        root.leases = next
        root.revision += 1
        return true
    }

    function release(clientId: string): bool {
        const id = root._clientId(clientId)
        if (id.length === 0 || root.leases[id] === undefined)
            return false
        const next = Object.assign({}, root.leases)
        delete next[id]
        root.leases = next
        root.revision += 1
        return true
    }

    function pruneExpired(): void {
        const now = Date.now()
        const next = Object.assign({}, root.leases)
        let changed = false
        for (const id of Object.keys(next)) {
            if (Number(next[id]?.expiresAtMs ?? 0) > now)
                continue
            delete next[id]
            changed = true
        }
        if (!changed)
            return
        root.leases = next
        root.revision += 1
    }

    function status(): var {
        root.revision
        return {
            active: root.sessionActive,
            samplingEnabled: root.samplingEnabled,
            leaseCount: root.leaseCount,
            leaseTtlMs: root.leaseTtlMs,
            maxLeases: root.maxLeases
        }
    }

    // This is lease cleanup, not a resource sampler, and it is stopped when
    // there is no Diagnostics consumer.
    Timer {
        id: leasePruneTimer
        interval: 1000
        repeat: true
        running: root.sessionActive
        onTriggered: root.pruneExpired()
    }
}
