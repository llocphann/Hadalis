.pragma library

// Semantic vocabulary for the renderer, Rust bridge and future local AI.
var names = ["idle", "happy", "excited", "thinking", "working", "surprised", "sleepy", "sad", "alert"]
// Shared immutable layouts: changing shimmer must not allocate new arrays.
var dropletSize = [13.5, 14, 11, 6.5, 4, 4.5, 4, 3]
var shineX = [9, 64, 4, 66, 58]
var shineY = [20, 14, 48, 43, 73]
var bubblePhase = [3.35, 0.40, 4.10, 5.40, 4.78, 5.08, 2.50, 0.03]
var focusedExpressions = ["sleepy", "working", "thinking", "sad"]

function resolve(expression, mood, activity) {
    if (names.indexOf(expression) >= 0 || expression==="angry" || expression==="panicked") return expression
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
        worried: name === "sad" || name === "panicked",
        angry: name === "angry",
        eyeScale: name === "excited" || name === "surprised" || name === "panicked" ? 1.1 : 1,
        energy: name === "sleepy" ? 0.08 : name === "excited" ? 0.95 : name === "alert" ? 0.7 : 0.35,
        mark: name === "thinking" ? "?" : name === "surprised" || name === "alert" ? "!" : name === "sleepy" ? "zZ" : "",
        orbit: name === "working",
        shine: name === "happy" || name === "excited",
        squash: name === "sleepy" ? 0.55 : name === "sad" ? 0.22 : name === "excited" ? -0.2 : 0,
        tilt: name === "thinking" ? -0.4 : name === "sad" ? 0.15 : 0
    }
}
