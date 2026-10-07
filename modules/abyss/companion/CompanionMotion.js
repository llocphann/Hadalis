.pragma library
.import "AquaMotionData.js" as Aqua
.import "OctoMotionData.js" as Octo

// Preserve the public wull IPC/config/history namespace while naming the cast
// Aqua/Octo. The curves are authored by Blender, not runtime sprite assets.
function forCharacter(character) { return character === "octo" ? Octo : Aqua }
function other(character) { return character === "octo" ? "aqua" : "octo" }
function name(character) { return character === "octo" ? "Octo" : "Aqua" }
