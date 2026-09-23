pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

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
    property var latestSample: null
    property double sampleUpdatedAtMs: 0
    property string samplerError: ""
    property var sourceBoundaryReconciliation: ({
        matchedBoundaryCount: 0,
        unmatchedBoundaryCount: 0,
        matchedTargetIds: []
    })

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

    function _reconcileSourceBoundaries(): void {
        if (CodeWorkflowIndex.status !== "ready") {
            root.sourceBoundaryReconciliation = ({
                matchedBoundaryCount: 0,
                unmatchedBoundaryCount: 0,
                matchedTargetIds: []
            })
            return
        }

        const targetsBySource = ({})
        for (const descriptor of CodeWorkflowRuntime.activeCatalog) {
            const targetId = String(descriptor?.targetId ?? "")
            const sourcePath = CodeWorkflowRuntime.relativeSourcePath(
                descriptor?.sourcePath ?? "")
            if (targetId.length === 0 || sourcePath.length === 0)
                continue
            if (!Array.isArray(targetsBySource[sourcePath]))
                targetsBySource[sourcePath] = []
            if (!targetsBySource[sourcePath].includes(targetId))
                targetsBySource[sourcePath].push(targetId)
        }

        let matchedBoundaryCount = 0
        let unmatchedBoundaryCount = 0
        const matchedTargets = ({})
        for (const boundary of CodeWorkflowIndex.boundaries) {
            const sourcePath = CodeWorkflowRuntime.relativeSourcePath(
                boundary?.sourcePath ?? "")
            const targetIds = targetsBySource[sourcePath] ?? []
            if (targetIds.length === 0) {
                unmatchedBoundaryCount++
                continue
            }
            matchedBoundaryCount++
            for (const targetId of targetIds)
                matchedTargets[targetId] = true
        }

        root.sourceBoundaryReconciliation = ({
            matchedBoundaryCount: matchedBoundaryCount,
            unmatchedBoundaryCount: unmatchedBoundaryCount,
            matchedTargetIds: Object.keys(matchedTargets).sort()
        })
    }

    function sourceDiscoverySummary(): var {
        return {
            status: CodeWorkflowIndex.status,
            error: CodeWorkflowIndex.error,
            filesScanned: CodeWorkflowIndex.filesScanned,
            filesParsed: CodeWorkflowIndex.filesParsed,
            cacheHits: CodeWorkflowIndex.cacheHits,
            boundaryCount: CodeWorkflowIndex.boundaryCount,
            boundaryCounts: CodeWorkflowIndex.result?.boundaryCounts ?? ({}),
            liveRuntimeEvidence: false,
            reconciliation: root.sourceBoundaryReconciliation
        }
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

    function _consumeSample(rawLine): void {
        const line = String(rawLine ?? "").trim()
        if (line.length === 0)
            return
        try {
            const sample = JSON.parse(line)
            if (sample?.error) {
                root.samplerError = String(sample.error)
                    + (sample?.detail ? ": " + String(sample.detail) : "")
                return
            }
            if (!sample?.system || !sample?.shell || !sample?.network)
                throw new Error("incomplete diagnostics sample")
            root.latestSample = sample
            root.sampleUpdatedAtMs = Number(sample.atMs ?? Date.now())
            root.samplerError = ""
            root.revision += 1
        } catch (error) {
            root.samplerError =
                "Diagnostics sample decode failed: " + String(error)
        }
    }

    function snapshot(): var {
        root.revision
        return {
            status: root.status(),
            sampleAtMs: root.sampleUpdatedAtMs,
            system: root.latestSample?.system ?? null,
            shell: root.latestSample?.shell ?? null,
            network: root.latestSample?.network ?? null,
            sampler: {
                running: diagnosticsSampler.running,
                error: root.samplerError
            },
            discovery: root.sourceDiscoverySummary()
        }
    }

    onSamplingEnabledChanged: {
        if (root.samplingEnabled) {
            CodeWorkflowIndex.refresh(false)
            return
        }
        // CodeWorkflowIndex is Workflow-owned one-shot discovery, not a
        // resource sampler. Do not cancel a scan that may also be serving a
        // concurrently visible Workflow surface.
        root.latestSample = null
        root.sampleUpdatedAtMs = 0
        root.samplerError = ""
        root.revision += 1
    }

    Connections {
        target: CodeWorkflowIndex
        function onStatusChanged(): void {
            root._reconcileSourceBoundaries()
            root.revision += 1
        }
        function onResultChanged(): void {
            root._reconcileSourceBoundaries()
            root.revision += 1
        }
    }

    Connections {
        target: CodeWorkflowRuntime
        function onRevisionChanged(): void {
            if (CodeWorkflowIndex.status === "ready")
                root._reconcileSourceBoundaries()
        }
    }

    Process {
        id: diagnosticsSampler
        running: root.samplingEnabled
        command: [
            "/usr/bin/env", "python3",
            Quickshell.shellPath("scripts/runtime-diagnostics-sampler.py"),
            "--pid", String(Quickshell.processId),
            "--interval-ms", "1000"
        ]

        stdout: SplitParser {
            onRead: line => root._consumeSample(line)
        }

        stderr: SplitParser {
            onRead: line => {
                const detail = String(line ?? "").trim()
                if (detail.length > 0)
                    root.samplerError = detail
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (root.samplingEnabled && exitCode !== 0)
                root.samplerError =
                    "Runtime Diagnostics sampler exited with " + exitCode
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
