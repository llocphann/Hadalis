#!/usr/bin/env python3
import json
import re
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
# Inherited development override must not start a disabled production Wull.
production_bridge = perimeter.split("CompanionBridge {", 1)[1].split("}", 1)[0]
assert 'binaryPath: root.companionEnabled ? (Quickshell.env("INIR_COMPANIOND") ?? "") : ""' in production_bridge
assert "useNativeDispatcher: root.companionEnabled" in production_bridge
for marker in (
    "useNativeDispatcher: root.companionEnabled",
    "WullHostPolicy.hostActive(",
    "WullHostPolicy.acceptsInput(window.companionHostActive, companion.interactive, companion.visible && companion.inputReady)",
    "!Appearance.gameModeMinimal",
    "GameMode.hasFullscreenOnOutput(companionTargetOutput)",
    'companionBridge.sendEvent("click")',
    'companionBridge.sendEvent("hover",window.companionHoverHeld)',
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

for path in (ROOT / "modules/abyss/companion").glob("*.qml"):
    text = path.read_text(errors="ignore").lower()
    assert "assets/images/mascot" not in text, path
    # A development grabToImage export is evidence, not runtime pose loading.
    assert not re.search(
        r"\b(?:image|animatedimage|animatedsprite|spritesequence|video)\s*\{",
        text), path

# The input mask and reveal both derive from companionHostActive. Readiness
# must gate that shared host condition so a daemon exit drops hit testing at
# once, even while the ordinary reveal animation is settling.
host_gate = perimeter.split("readonly property bool companionPermission:", 1)[1].split(
    "readonly property bool companionHostActive:", 1)[0]
for marker in (
    "root.companionSessionVisible,companionBridge.ready",
    "root.companionTargetOutput,window.outputName,window.presented,field.ready",
    "!window.companionOccluded",
):
    assert marker in host_gate, marker
assert "window.companionPermission && companionPresence.qualified" in perimeter
assert "permitted: window.companionPermission" in perimeter
companion_item = perimeter.split("AbyssCompanion {", 1)[1].split(
    "onActivated:", 1
)[0]
assert "opacity: companionBridge.ready ? 1 : 0" in companion_item
assert "dragEnabled: interactive" in companion_item
presence = (ROOT / "modules/abyss/companion/WullPresence.qml").read_text()
assert "readonly property bool surfaceBound: true" in presence
assert "function tryThrow(vx, vy): bool" in presence
assert "candidate.grounded" in presence
assert "WullHostPolicy.acceptsInput(window.companionHostActive, companion.interactive, companion.visible && companion.inputReady)" in perimeter
assert "companionPreferences.edge" not in perimeter
assert "reveal: companionPresence.renderedReveal" in perimeter

# The bridge must fail readiness closed on either process termination signal
# but preserve pending show intent through the next initial state handshake.
running_handler = bridge.split("onRunningChanged: {", 1)[1].split(
    "onExited:", 1
)[0]
exit_handler = bridge.split("onExited:", 1)[1]
assert "if (!running)" in running_handler
assert "root.ready = false" in running_handler
assert "root.ready = false" in exit_handler
# Execute the handshake and settings dispatch, including preference-before-show
# ordering, rather than requiring the previous one-line callback spelling.
import subprocess
subprocess.run(["node", str(ROOT / "scripts/test-wull-preferences.cjs")], check=True)

# Unexpected exits retry with a finite exponential budget. Explicit disable
# cancels pending retries, and stale stdout cannot restore an unready host.
for marker in (
    "property int restartAttempts: 0",
    "readonly property int maxRestartAttempts: 4",
    "restartTimer.interval = 500 * Math.pow(2, root.restartAttempts)",
    "root.restartAttempts += 1",
    "restartTimer.stop()",
    "stableConnectionTimer.stop()",
    "root.scheduleRestart()",
    "interval: 30000",
    "if (!root.backendEnabled || !backendProcess.running || !line",
):
    assert marker in bridge, marker
assert bridge.count("root.scheduleRestart()") == 2
assert "root.restartAttempts = 0" in bridge

# Canonical validation must keep exercising the Wull production contract
# while excluding the branch-mutating, manually invoked diagnostic workflow.
validator = (ROOT / "scripts/validate-maintainer-local.sh").read_text()
assert 'scripts/test-wull-manual-perimeter.py)' in validator
assert 'record_skip "MANUAL-DEFERRED: $test_file"' in validator
assert 'run_check "Python regression: $test_file" python3 "$test_file"' in validator

print("1..1")
print("ok 1 - Wull production attachment remains procedural, single-backend, and default-off")
