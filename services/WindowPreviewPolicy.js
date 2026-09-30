// Preserve successful snapshots for their window ID and Niri session.
// The URL timestamp is a revision for explicit refresh, not a TTL.
function needsCapture(cached) {
    return !cached || typeof cached.path !== "string" || cached.path.length === 0
}

// An explicit successful capture advances its URL revision even when the clock
// has not ticked. Idle time is not an invalidation criterion.
function nextRevision(previous, now) {
    const oldRevision = Number.isFinite(Number(previous)) ? Math.floor(Number(previous)) : 0
    const clockRevision = Number.isFinite(Number(now)) ? Math.floor(Number(now)) : 0
    return Math.max(oldRevision + 1, clockRevision)
}

function previewUrl(cached) {
    return needsCapture(cached) ? "" : "file://" + cached.path + "?" + cached.timestamp
}

// Only visible, unique compositor windows can occupy the decoded-image budget.
function boundedWindowIds(ids, limit) {
    const result = []
    const seen = new Set()
    if (!Array.isArray(ids)) return result
    const maximum = Math.max(0, Math.floor(Number(limit) || 0))
    if (maximum === 0) return result
    for (const rawId of ids) {
        const id = Number(rawId)
        if (!Number.isSafeInteger(id) || id <= 0 || seen.has(id)) continue
        seen.add(id)
        result.push(id)
        if (result.length >= maximum) break
    }
    return result
}
