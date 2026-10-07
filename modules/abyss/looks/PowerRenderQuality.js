.pragma library

function abyss(manual, automatic, profile) {
    if (automatic)
        return profile === "power-saver" ? "performance"
            : profile === "performance" ? "quality" : "balanced";
    return ["performance","balanced","quality"].includes(manual)
        ? manual : "balanced";
}

function wull(manual, automatic, profile, shellQuality) {
    if (shellQuality === "performance") return "performance";
    if (automatic) return profile === "power-saver" ? "performance" : "quality";
    // Quality now uses the old Balanced tier; both historic values migrate.
    return manual === "performance" ? "performance" : "quality";
}
