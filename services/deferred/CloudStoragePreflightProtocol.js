// Strict parser for an explicitly requested STATIC connection preflight.
// Only inert readiness is exposed; no account data, binary paths or vendor output.
function parseConnectPreflightResponse(payload, requestId) {
    if (typeof payload !== "string" || !payload.length || payload.length > 65536
            || typeof requestId !== "string" || !requestId.length)
        throw new Error("invalid preflight response")
    const envelope = JSON.parse(payload)
    // Keep the outer envelope as strict as the result schema: a preflight
    // reply may never smuggle additional account or session metadata.
    const envelopeKeys = ["protocol", "request_id", "ok", "result", "error"].sort()
    if (!envelope || typeof envelope !== "object" || Array.isArray(envelope)
            || JSON.stringify(Object.keys(envelope).sort()) !== JSON.stringify(envelopeKeys)
            || envelope.protocol !== 1 || envelope.request_id !== requestId
            || envelope.ok !== true || envelope.error !== null)
        throw new Error("incompatible preflight envelope")
    const result = envelope.result
    const keys = ["adapter", "probe_kind", "vendor_execution",
        "connection_attempted", "connected", "auth_qualified",
        "account_reads_enabled", "dependencies_ready", "reason"].sort()
    if (!result || typeof result !== "object" || Array.isArray(result)
            || JSON.stringify(Object.keys(result).sort()) !== JSON.stringify(keys)
            || result.adapter !== "inir-mega"
            || result.probe_kind !== "static_connect_preflight"
            || result.vendor_execution !== "blocked_pending_disposable_qualification"
            || result.connection_attempted !== false || result.connected !== false
            || result.auth_qualified !== false || result.account_reads_enabled !== false
            || typeof result.dependencies_ready !== "boolean"
            || result.reason !== (result.dependencies_ready
                ? "installed_vendor_not_qualified" : "dependency_missing"))
        throw new Error("unsafe preflight payload")
    return {dependenciesReady: result.dependencies_ready, reason: result.reason}
}
