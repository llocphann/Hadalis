// Strict, side-effect-free parser for the static Rust detect result.
// QML receives only booleans; helper paths, stderr and vendor text never escape.
function parseDetectResponse(payload, requestId) {
    if (typeof payload !== "string" || !payload.length || payload.length > 65536
        || typeof requestId !== "string" || !requestId.length)
        throw new Error("invalid response size or request")
    const envelope = JSON.parse(payload)
    if (!envelope || typeof envelope !== "object" || Array.isArray(envelope)
        || envelope.protocol !== 1 || envelope.request_id !== requestId
        || envelope.ok !== true || envelope.error !== null)
        throw new Error("incompatible static envelope")
    const result = envelope.result
    if (!result || typeof result !== "object" || Array.isArray(result)
        || result.adapter !== "inir-mega"
        || result.probe_kind !== "static_no_vendor_execution"
        || result.vendor_execution !== "auth_blocked_pending_disposable_qualification"
        || result.auth_transport !== "private_pty_fake_qualified"
        || result.secret_argv !== false || result.python_mutation_fallback !== false
        || !Array.isArray(result.binaries))
        throw new Error("unsafe static response")
    const names = ["mega-cmd", "mega-login", "mega-cmd-server", "mega-whoami", "mega-version"]
    if (result.binaries.length !== names.length
        || result.binaries.some((item, index) => !item || typeof item !== "object"
            || Array.isArray(item) || item.name !== names[index]
            || typeof item.executable !== "boolean")
        || result.interactive_shell_available !== result.binaries[0].executable
        || result.server_available !== result.binaries[2].executable)
        throw new Error("inconsistent static binary inventory")
    const shell = result.binaries[0].executable
    const server = result.binaries[2].executable
    return {
        installed: shell && server,
        shell: shell,
        login: result.binaries[1].executable,
        server: server,
        whoami: result.binaries[3].executable,
        version: result.binaries[4].executable
    }
}
