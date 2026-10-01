// Pure fake-only race guard. Allow a valid third result that finishes before
// the next 40ms UI poll, but never accept an old-generation snapshot.
function stageTwo(s) {
    if (s.sawStaleInstalled || s.backendState === "installed_disconnected")
        return "STALE_INSTALLED"
    if (!s.materialLease || s.waffleLease || s.consumers !== 1)
        return "STALE_LEASE"
    if (s.backendState === "unavailable") return "STALE_UNAVAILABLE"
    if (s.requestSerial === 2) {
        if (s.snapshot !== null) return "STALE_SNAPSHOT"
        if (s.backendState !== "checking") return "STALE_REPLY"
        return "WAIT" // Includes the deferred Qt.callLater gap after read 2 exits.
    }
    if (s.requestSerial !== 3) return "STALE_REPLY"
    if (s.readBusy) {
        if (s.snapshot !== null) return "STALE_SNAPSHOT"
        return s.backendState === "checking" ? "THIRD_PENDING" : "THIRD_START"
    }
    const snap = s.snapshot
    if (s.backendState !== "dependency_missing" || !snap
            || snap.installed !== false || snap.shell !== false
            || snap.server !== false || snap.login !== false
            || snap.whoami !== false || snap.version !== false
            || s.safeError !== "" || s.connected || s.liveAuthQualified)
        return "THIRD_RESULT"
    return "THIRD_FINISHED"
}
