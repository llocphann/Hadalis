// EasyEffects is a processing sink. Volume controls must target its actual
// output without replacing that default sink or rebuilding the DSP pipeline.
function isEffectsSink(node) {
    const props = node?.properties ?? {}
    return String(props["node.name"] ?? node?.name ?? "") === "easyeffects_sink"
        || String(props["application.id"] ?? "") === "com.github.wwmm.easyeffects"
        || (String(props["node.virtual"] ?? "false") === "true"
            && String(props["monitor.passthrough"] ?? "false") === "true")
}

function outputDevice(text) {
    let section = ""
    for (const line of String(text ?? "").split(/\r?\n/)) {
        const trimmed = line.trim()
        if (trimmed.startsWith("[")) {
            section = trimmed.slice(1, -1)
        } else if (section === "StreamOutputs" && trimmed.startsWith("outputDevice=")) {
            return trimmed.slice("outputDevice=".length).trim().replace(/^"(.*)"$/, "$1")
        }
    }
    return ""
}

function resolveSink(node, nodes, links, configuredNames) {
    if (!node?.audio || !isEffectsSink(node))
        return node
    const physical = nodes.filter(candidate => candidate?.isSink && candidate.audio
        && !candidate.isStream && !isEffectsSink(candidate))
    const props = node.properties ?? {}

    // A PipeWire driver-id can name the effects sink itself. Only a distinct,
    // existing output is a mapping; never guess the first hardware device.
    const driverId = Number(props["node.driver-id"] ?? 0)
    const driver = physical.find(candidate => Number(candidate.id) === driverId)
    // Follow the directed output links of the effects group while it is active.
    // Idle EasyEffects may have no links at all, so retain an exact configured
    // device-name fallback below. Cycles and duplicate channel links are bounded.
    const group = String(props["node.link-group"] ?? props["node.group"] ?? "")
    const reached = new Set([Number(node.id)])
    if (group) {
        for (const candidate of nodes) {
            const candidateProps = candidate.properties ?? {}
            if (String(candidateProps["node.link-group"] ?? candidateProps["node.group"] ?? "") === group)
                reached.add(Number(candidate.id))
        }
    }
    for (let pass = 0; pass < nodes.length; pass++) {
        let changed = false
        for (const link of links) {
            const sourceId = Number(link?.source?.id ?? 0)
            const targetId = Number(link?.target?.id ?? 0)
            if (sourceId > 0 && targetId > 0 && reached.has(sourceId) && !reached.has(targetId)) {
                reached.add(targetId)
                changed = true
            }
        }
        if (!changed)
            break
    }
    const linked = physical.filter(candidate => reached.has(Number(candidate.id)))
    if (linked.length === 1)
        return linked[0]
    const configured = (linked.length ? linked : physical).filter(candidate =>
        configuredNames.includes(String(candidate.properties?.["node.name"] ?? candidate.name ?? "")))
    if (configured.length === 1)
        return configured[0]
    // driver-id can also be a graph clock owner, so an actual link or explicit
    // route takes precedence. Use the legacy mapping only without either.
    return linked.length === 0 && configured.length === 0 && driver ? driver : node
}
