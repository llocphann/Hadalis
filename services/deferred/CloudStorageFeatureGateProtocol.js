// Strict reader for an inert, deny-by-default *policy preview*.
// A preview is never evidence of installed version, connection, or live access.
// Do not expose raw vendor output, paths, account data or returned extra keys.
function parseOfflineFeatureGatePreview(payload, requestId) {
    if (typeof payload !== "string" || !payload.length || payload.length > 65536
            || typeof requestId !== "string" || !requestId.length)
        throw new Error("invalid offline capability preview")
    let envelope
    try { envelope = JSON.parse(payload) }
    catch { throw new Error("invalid offline capability preview") }
    if (!envelope || typeof envelope !== "object" || Array.isArray(envelope)
            || envelope.protocol !== 1 || envelope.request_id !== requestId
            || envelope.ok !== true || envelope.error !== null)
        throw new Error("incompatible offline capability preview")
    const result = envelope.result
    const keys = ["adapter", "probe_kind", "vendor_execution",
        "installed_version_qualified", "connection_attempted",
        "connected", "auth_qualified", "account_reads_enabled",
        "writes_enabled", "domains"].sort()
    const names = ["overview", "drive", "transfers", "sync", "backups",
        "sharing", "contacts", "mounts", "security", "preferences"].sort()
    if (!result || typeof result !== "object" || Array.isArray(result)
            || JSON.stringify(Object.keys(result).sort()) !== JSON.stringify(keys)
            || result.adapter !== "inir-mega"
            || result.probe_kind !== "offline_policy_preview"
            || result.vendor_execution !== "blocked_pending_disposable_qualification"
            || result.installed_version_qualified !== false
            || result.connection_attempted !== false
            || result.connected !== false || result.auth_qualified !== false
            || result.account_reads_enabled !== false
            || result.writes_enabled !== false
            || !result.domains || typeof result.domains !== "object"
            || Array.isArray(result.domains)
            || JSON.stringify(Object.keys(result.domains).sort()) !== JSON.stringify(names))
        throw new Error("unsafe offline capability preview")
    for (const name of names) {
        const entry = result.domains[name]
        if (!entry || typeof entry !== "object" || Array.isArray(entry)
                || JSON.stringify(Object.keys(entry).sort()) !== JSON.stringify(
                    ["read", "reason", "write"])
                || entry.read !== false || entry.write !== false
                || entry.reason !== "installed_version_unqualified")
            throw new Error("unqualified offline capability")
    }
    // Return an explicitly constructed immutable snapshot, never raw vendor data.
    return Object.freeze({
        qualified: false,
        connected: false,
        availableReadDomains: Object.freeze([]),
        availableWriteDomains: Object.freeze([]),
        reason: "installed_version_unqualified"
    })
}
