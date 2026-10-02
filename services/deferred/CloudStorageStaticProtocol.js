// Strict, side-effect-free parser for the static Rust detect result.
// QML receives only booleans; helper paths, stderr and vendor text never escape.
function parseDetectResponse(payload, requestId) {
    if (typeof payload !== "string" || !payload.length || payload.length > 65536
        || typeof requestId !== "string" || !requestId.length)
        throw new Error("invalid response size or request")
    const envelope = JSON.parse(payload)
    const envelopeKeys = ["protocol", "request_id", "ok", "result", "error"].sort()
    if (!envelope || typeof envelope !== "object" || Array.isArray(envelope)
        || JSON.stringify(Object.keys(envelope).sort()) !== JSON.stringify(envelopeKeys)
        || envelope.protocol !== 1 || envelope.request_id !== requestId
        || envelope.ok !== true || envelope.error !== null)
        throw new Error("incompatible static envelope")
    const result = envelope.result
    // Static detection is not a generic vendor result: fail closed if an
    // unexpected or missing key is present in the response at any layer.
    const resultKeys = ["adapter", "probe_kind", "vendor_execution",
        "auth_transport", "secret_argv", "python_mutation_fallback",
        "interactive_shell_available", "server_available", "binaries"].sort()
    const binaryKeys = ["name", "executable", "path"].sort()
    if (!result || typeof result !== "object" || Array.isArray(result)
        || JSON.stringify(Object.keys(result).sort()) !== JSON.stringify(resultKeys)
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
            || Array.isArray(item)
            || JSON.stringify(Object.keys(item).sort()) !== JSON.stringify(binaryKeys)
            || item.name !== names[index] || typeof item.executable !== "boolean"
            || !(item.path === null || typeof item.path === "string"))
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
