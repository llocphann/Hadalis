.pragma library

var personalities = ["calm", "balanced", "energetic"]
var frequencies = ["always", "frequent", "occasional", "rare"]
var qualities = ["performance", "balanced", "quality"]

function defaults() {
    return {
        enabled: false, output: "", edge: "auto", along: 0.72, size: 1,
        interactive: true, soundEnabled: false, personality: "balanced",
        appearanceFrequency: "always", animationsEnabled: true,
        effectsEnabled: true, hideInFullscreen: false, renderQuality: "balanced",
        translucency: 0.16, exploreFeatures: true
    }
}

function bounded(value, fallback, minimum, maximum) {
    return typeof value === "number" && Number.isFinite(value)
        ? Math.max(minimum, Math.min(maximum, value)) : fallback
}

function normalize(options) {
    const source = options ?? {}
    const result = defaults()
    for (const key of ["enabled", "interactive", "soundEnabled", "animationsEnabled", "effectsEnabled", "hideInFullscreen", "exploreFeatures"])
        if (typeof source[key] === "boolean") result[key] = source[key]
    // Older persisted placement values are tolerated but no longer pin Wull.
    // Keep schema compatibility while geometry chooses every visit dynamically.
    result.size = bounded(source.size, result.size, 0.65, 1.5)
    result.translucency = bounded(source.translucency, result.translucency, 0, 0.35)
    result.personality = personalities.includes(source.personality) ? source.personality : "balanced"
    result.appearanceFrequency = frequencies.includes(source.appearanceFrequency) ? source.appearanceFrequency : "always"
    result.renderQuality = qualities.includes(source.renderQuality) ? source.renderQuality : "balanced"
    return result
}

function motionScale(personality) {
    return personality === "calm" ? 0.55 : personality === "energetic" ? 1.35 : 1
}

function renderTier(quality, shellQuality) {
    if (shellQuality === "performance") return 0
    const tier = qualities.indexOf(quality)
    return tier < 0 ? 1 : tier
}
