// Pure production Wull host policy: no Config, processes, or window side effects.
// Each decision is shared by the real Abyss perimeter and the host contract.
function hostActive(sessionVisible, ready, targetOutput, currentOutput, presented, fieldReady) {
    return !!sessionVisible && !!ready
        && typeof targetOutput === "string" && targetOutput.length > 0
        && targetOutput === currentOutput
        && !!presented && !!fieldReady
}

function acceptsInput(active, interactive, itemVisible) {
    return !!active && !!interactive && !!itemVisible
}

// Center the companion in very small viewports instead of returning a margin
// outside the logical output. Normal outputs retain the legacy placement.
function alongPosition(extent, footprint, along) {
    const size = Number(extent)
    if (!Number.isFinite(size) || size <= 0)
        return 0
    const span = Number(footprint)
    const margin = Math.min(size * 0.5,
        Math.max(32, (Number.isFinite(span) ? Math.max(span, 0) : 0) * 0.5 + 12))
    const fraction = Number(along)
    const bounded = Number.isFinite(fraction)
        ? Math.max(0.08, Math.min(0.92, fraction)) : 0.72
    return Math.max(margin, Math.min(size - margin, size * bounded))
}
