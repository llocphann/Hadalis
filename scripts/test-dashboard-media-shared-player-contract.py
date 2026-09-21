#!/usr/bin/env python3
"""Keep Dashboard Media on the canonical shared media surface."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
dash = (ROOT / "modules" / "dashboard" / "DashMedia.qml").read_text(encoding="utf-8")
player = (ROOT / "modules" / "mediaControls" / "PlayerControl.qml").read_text(encoding="utf-8")
popup = (ROOT / "modules" / "mediaControls" / "BarMediaPopup.qml").read_text(encoding="utf-8")
canvas = (ROOT / "modules" / "dashboard" / "DashboardCanvas.qml").read_text(encoding="utf-8")
failures = []

def require(source: str, token: str, label: str) -> None:
    if token not in source:
        failures.append(f"{label}: missing {token!r}")

def forbid(source: str, token: str, label: str) -> None:
    if token in source:
        failures.append(f"{label}: forbidden {token!r}")

# Dashboard and Bar popup must converge on PlayerControl rather than carrying
# separate artwork/progress/transport implementations.
for token in (
    "PlayerControl {",
    "visualizerPoints: dashMediaCava.points",
    "visualizerMaxValue:",
    "compactLayout: true",
    "EqualizerPanel {",
):
    require(dash, token, "Dashboard shared media")

for token in (
    "PlayerControl {",
    "visualizerPoints: root.visualizerPoints",
    "EqualizerPanel {",
):
    require(popup, token, "Bar popup shared media")

# PlayerControl is the owner of all five transport actions, progress and CAVA.
for token in (
    'buttonText: Translation.tr("Shuffle")',
    'buttonText: Translation.tr("Previous")',
    'Translation.tr("Pause") : Translation.tr("Play")',
    'buttonText: Translation.tr("Next")',
    'buttonText: Translation.tr("Repeat")',
    "WaveVisualizer {",
    "StyledSlider.Configuration.Wavy",
):
    require(player, token, "Canonical PlayerControl")

# Reintroducing local Dashboard transport/artwork/visualizer code would make the
# surfaces drift again.
for token in (
    "component MediaButton:",
    "GE.OpacityMask",
    "id: artImage",
    "WaveVisualizer {",
    "MprisController.toggleShuffleForPlayer",
    "MprisController.cycleLoopForPlayer",
):
    forbid(dash, token, "Dashboard duplicate media UI")

# DashboardCanvas owns the host lifecycle because DashMedia is reused by both
# standalone Dashboard and embedded Overview. The child property must remain
# writable; making it readonly is a QML compile error at the binding site.
require(dash, "property bool presentationActive:",
        "Dashboard writable presentation lifecycle")
forbid(dash, "readonly property bool presentationActive:",
       "Dashboard writable presentation lifecycle")
require(canvas, "presentationActive: root.presentationActive",
        "DashboardCanvas media lifecycle binding")
require(dash, "active: root.presentationActive && root.hasPlayer",
        "Dashboard shared-player lifecycle")
require(dash, "active: root.presentationActive && root.hasPlayer && root.isPlaying",
        "Dashboard CAVA lifecycle")

if failures:
    print("Dashboard shared media contract regression(s):")
    for failure in failures:
        print("  - " + failure)
    raise SystemExit(1)

print("Dashboard shared media contract: PASS")
