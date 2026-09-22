// Preserve successful snapshots for their window ID and Niri session.
// The URL timestamp is a revision for explicit refresh, not a TTL.
function needsCapture(cached) {
    return !cached || typeof cached.path !== "string" || cached.path.length === 0
}
