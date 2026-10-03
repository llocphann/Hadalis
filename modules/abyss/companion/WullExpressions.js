.pragma library

// Semantic vocabulary for the renderer, Rust bridge and future local AI.
var names = ["idle", "happy", "excited", "thinking", "working", "surprised", "sleepy", "sad", "alert"]

function resolve(expression, mood, activity) {
    if (names.indexOf(expression) >= 0) return expression
    if (activity === "error") return "sad"
    if (activity === "warning") return "alert"
    if (activity === "success") return "happy"
    if (activity === "thinking") return "thinking"
    if (activity === "working") return "working"
    if (mood === "sleepy") return "sleepy"
    if (mood === "happy") return "happy"
    if (mood === "concerned") return "sad"
    if (mood === "curious") return "thinking"
    return "idle"
}

function profile(expression) {
    var name = resolve(expression, "calm", "idle")
    return {
        name: name,
        smilingEyes: name === "happy",
        closedEyes: name === "sleepy" || name === "working",
        openMouth: name === "happy" || name === "excited" || name === "surprised",
        worried: name === "sad",
        eyeScale: name === "excited" || name === "surprised" ? 1.1 : 1,
        energy: name === "sleepy" ? 0.08 : name === "excited" ? 0.95 : name === "alert" ? 0.7 : 0.35,
        mark: name === "thinking" ? "?" : name === "surprised" || name === "alert" ? "!" : name === "sleepy" ? "zZ" : "",
        orbit: name === "working",
        shine: name === "happy" || name === "excited",
        squash: name === "sleepy" ? 0.55 : name === "sad" ? 0.22 : name === "excited" ? -0.2 : 0,
        tilt: name === "thinking" ? -0.4 : name === "sad" ? 0.15 : 0
    }
}
