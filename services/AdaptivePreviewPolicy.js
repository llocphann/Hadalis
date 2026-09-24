// Adaptive Overview preview policy.
//
// Pure JavaScript keeps scheduler decisions regression-testable without a
// running compositor or native capture backend.

function normalizeMode(value) {
    const mode = String(value ?? "adaptive").toLowerCase()
    return mode === "snapshot" || mode === "live" || mode === "adaptive"
        ? mode : "adaptive"
}

function boundedLiveLimit(value, fallback) {
    const parsed = Math.floor(Number(value))
    const safeFallback = Math.max(1, Math.floor(Number(fallback) || 1))
    if (!Number.isFinite(parsed))
        return safeFallback
    return Math.max(1, Math.min(16, parsed))
}

function clampActivity(value) {
    const parsed = Number(value)
    if (!Number.isFinite(parsed))
        return 0
    return Math.max(0, Math.min(1, parsed))
}

function boundedThreshold(value, fallback) {
    const parsed = Number(value)
    const safe = Number.isFinite(parsed) ? parsed : Number(fallback)
    return Math.max(0, Math.min(1, Number.isFinite(safe) ? safe : 0))
}

function wantsLive(options) {
    const o = options ?? {}
    if (!o.active || !o.backendAvailable)
        return false

    const mode = normalizeMode(o.mode)
    if (mode === "snapshot")
        return false
    if (mode === "live")
        return true

    // Hover means the user is explicitly inspecting this window.
    if ((o.liveOnHover ?? true) && !!o.hovered)
        return true

    const requireActivityForHints = !!o.requireActivityForHints
    if (!requireActivityForHints) {
        if ((o.liveMediaWindows ?? true) && !!o.mediaPlaying)
            return true
        if ((o.liveFocusedWindow ?? false) && !!o.focused)
            return true
    }

    let threshold = boundedThreshold(o.activityPromotionThreshold, 0.55)
    if (requireActivityForHints && (o.liveMediaWindows ?? true) && !!o.mediaPlaying) {
        threshold = Math.min(
            threshold,
            boundedThreshold(o.mediaActivityPromotionThreshold, threshold)
        )
    }
    if (requireActivityForHints && (o.liveFocusedWindow ?? false) && !!o.focused) {
        threshold = Math.min(
            threshold,
            boundedThreshold(o.focusedActivityPromotionThreshold, threshold)
        )
    }

    return clampActivity(o.activityScore) >= threshold
}

function candidatePriority(options) {
    const o = options ?? {}
    let score = Math.round(clampActivity(o.activityScore) * 1000)
    if (o.focused)
        score += 2000
    if (o.mediaPlaying)
        score += 5000
    if (o.hovered)
        score += 10000
    return score
}

function selectLiveKeys(candidates, limit) {
    const bounded = boundedLiveLimit(limit, 6)
    const rows = (Array.isArray(candidates) ? candidates : [])
        .filter(row => row && row.requested && String(row.key ?? "").length > 0)
        .slice()

    rows.sort((a, b) => {
        const scoreDelta = Number(b.priority ?? 0) - Number(a.priority ?? 0)
        if (scoreDelta !== 0)
            return scoreDelta
        const orderDelta = Number(a.order ?? 0) - Number(b.order ?? 0)
        if (orderDelta !== 0)
            return orderDelta
        return String(a.key).localeCompare(String(b.key))
    })

    const result = []
    const seen = new Set()
    for (const row of rows) {
        const key = String(row.key)
        if (seen.has(key))
            continue
        seen.add(key)
        result.push(key)
        if (result.length >= bounded)
            break
    }
    return result
}
