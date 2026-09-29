// Pure identity policy for live confirmation/authentication source anchors.
// This file intentionally knows nothing about QML Items or actions.
function normalize(value) {
    var text = String(value == null ? "" : value).trim().toLowerCase();
    if (text.endsWith(".desktop"))
        text = text.slice(0, -8);
    return text.replace(/[^a-z0-9]+/g, "");
}

function matchScore(left, right) {
    var a = normalize(left);
    var b = normalize(right);
    if (!a || !b)
        return 0;
    if (a === b)
        return 1000 + Math.min(a.length, b.length);
    var entropy = Math.min(a.length, b.length);
    if (entropy >= 5 && (a.endsWith(b) || b.endsWith(a)))
        return 700 + entropy;
    return 0;
}

function kindPriority(kind) {
    kind = String(kind == null ? "" : kind);
    if (kind === "tray")
        return 300;
    if (kind === "bar")
        return 250;
    if (kind === "dock")
        return 200;
    return 0;
}

function placementScore(priority, identityScore, requestedOutput, candidateOutput) {
    var requested = String(requestedOutput == null ? "" : requestedOutput);
    var candidate = String(candidateOutput == null ? "" : candidateOutput);
    var sameOutput = requested.length > 0 && candidate === requested ? 1 : 0;
    // Output affinity outranks surface kind only when the caller supplied a
    // concrete source/output context. This prevents mirrored Tray/Bar/Dock
    // anchors on another monitor from stealing a prompt from the source screen.
    return sameOutput * 1000000000
        + Math.max(0, Number(priority) || 0) * 10000
        + Math.max(0, Number(identityScore) || 0);
}
