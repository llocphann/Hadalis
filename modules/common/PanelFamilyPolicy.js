// Pure policy shared by family routing, migration and behavioral tests.
function normalize(family) {
    return ["ii", "waffle", "abyss"].indexOf(family) >= 0 ? family : "ii";
}
function next(family) {
    var order = ["ii", "waffle", "abyss"];
    return order[(order.indexOf(normalize(family)) + 1) % order.length];
}
var abyssPanels = [
    "abyssPerimeter", "abyssBackground", "abyssBar", "abyssDock",
    "abyssSidebarLeft", "abyssSidebarRight", "abyssPopup",
    "abyssNotificationPopup", "abyssNotificationCenter", "abyssOnScreenDisplay",
    "abyssClipboard", "abyssOverview", "abyssLock", "abyssPolkit",
    "abyssSessionScreen", "iiCheatsheet", "iiOnScreenKeyboard", "iiOverlay",
    "iiRegionSelector", "iiTilingOverlay", "iiWallpaperSelector",
    "iiWallpaperLauncher", "iiCoverflowSelector", "iiShellUpdate", "iiRecordingOsd"
];
// Seen-but-disabled panels remain disabled on subsequent visits. A family's
// first explicit visit enables its own defaults, without reviving shared panels
// the user disabled in another family.
function ensure(family, base, enabled, known, visited) {
    family = normalize(family);
    var result = { enabled: enabled.slice(), known: known.slice(), visited: visited.slice() };
    var firstVisit = result.visited.indexOf(family) < 0;
    if (firstVisit) result.visited.push(family);
    for (var i = 0; i < base.length; ++i) {
        var id = base[i];
        var unseen = result.known.indexOf(id) < 0;
        var own = family === "abyss" ? id.indexOf("abyss") === 0
            : family === "waffle" ? id.indexOf("w") === 0 : id.indexOf("ii") === 0;
        if ((unseen || (firstVisit && own)) && result.enabled.indexOf(id) < 0)
            result.enabled.push(id);
        if (unseen) result.known.push(id);
    }
    return result;
}
