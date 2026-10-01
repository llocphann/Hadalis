#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
defaults = json.loads((ROOT / "defaults/config.json").read_text())
companion_defaults = defaults["abyss"]["companion"]

assert companion_defaults["enabled"] is False
assert companion_defaults["soundEnabled"] is False
assert companion_defaults["edge"] == "auto"
assert 0.0 < float(companion_defaults["along"]) < 1.0

schema = (ROOT / "modules/common/Config.qml").read_text()
for marker in (
    "property JsonObject companion: JsonObject",
    "property bool enabled: false",
    'property string edge: "auto"',
    "property real along: 0.72",
    "property bool soundEnabled: false",
):
    assert marker in schema, marker

perimeter = (ROOT / "modules/abyss/AbyssPerimeter.qml").read_text()
assert perimeter.count("CompanionBridge {") == 1
assert perimeter.count("AbyssCompanion {") == 1
for marker in (
    "useNativeDispatcher: root.companionEnabled",
    "root.companionTargetOutput === window.outputName",
    "window.companionHostActive && companion.interactive && companion.visible",
    "!Appearance.gameModeMinimal",
    "GameMode.hasFullscreenOnOutput(companionTargetOutput)",
    'companionBridge.sendEvent("click")',
    'companionBridge.sendEvent("hover", hovered)',
):
    assert marker in perimeter, marker

bridge = (ROOT / "modules/abyss/companion/CompanionBridge.qml").read_text()
for marker in (
    "onBackendEnabledChanged",
    "backendProcess.running = false",
    'root.visibility = "hidden"',
    '[nativeDispatchPath, "companion"]',
):
    assert marker in bridge, marker

for path in (ROOT / "modules/abyss/companion").glob("*"):
    if not path.is_file():
        continue
    text = path.read_text(errors="ignore").lower()
    assert "assets/images/mascot" not in text, path
    for extension in (".png", ".gif", ".webp", ".apng", ".mp4", ".webm"):
        assert extension not in text, (path, extension)

# The input mask and reveal both derive from companionHostActive. Readiness
# must gate that shared host condition so a daemon exit drops hit testing at
# once, even while the ordinary reveal animation is settling.
host_gate = perimeter.split(
    "readonly property bool companionHostActive:", 1
)[1].split("function companionAlongPosition()", 1)[0]
for marker in (
    "root.companionSessionVisible",
    "&& companionBridge.ready",
    "root.companionTargetOutput === window.outputName",
    "window.presented && field.ready",
):
    assert marker in host_gate, marker

companion_item = perimeter.split("AbyssCompanion {", 1)[1].split(
    "onActivated:", 1
)[0]
assert "opacity: companionBridge.ready ? 1 : 0" in companion_item
assert "window.companionHostActive && companion.interactive && companion.visible" in perimeter
assert "reveal: !window.companionHostActive ? 0" in perimeter

# The bridge must fail readiness closed on either process termination signal
# but preserve pending show intent through the next initial state handshake.
running_handler = bridge.split("onRunningChanged: {", 1)[1].split(
    "onExited:", 1
)[0]
exit_handler = bridge.split("onExited:", 1)[1]
assert "if (!running)" in running_handler
assert "root.ready = false" in running_handler
assert "root.ready = false" in exit_handler
assert "if (!wasReady && root.requestedVisible)" in bridge
assert 'Qt.callLater(() => root.sendEvent("show"))' in bridge

print("1..1")
print("ok 1 - Wull production attachment remains procedural, single-backend, and default-off")
