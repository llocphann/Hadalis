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
    "visualizerPoints: []",
    "showVisualizer: false",
    "compactLayout: true",
    "EqualizerPanel {",
):
    require(dash, token, "Dashboard shared media")

for token in (
    "PlayerControl {",
    "visualizerPoints: []",
    "showVisualizer: false",
    "EqualizerPanel {",
):
    require(popup, token, "Bar popup shared media")

# PlayerControl remains the owner of all five transport actions and progress.
# Its optional visualizer stays available for other owners, but Dashboard opts
# out because EqualizerPanel already owns the live analyzer.
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

# Reintroducing local Dashboard transport/artwork/visualizer code or a second
# CAVA subscription would make the surfaces drift again.
for token in (
    "component MediaButton:",
    "GE.OpacityMask",
    "id: artImage",
    "WaveVisualizer {",
    "CavaProcess {",
    "dashMediaCava",
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
require(dash, "active: root.hasPlayer",
        "Dashboard shared-player visual residency")
forbid(dash, "active: root.presentationActive && root.hasPlayer",
       "Dashboard shared-player visual residency")
require(dash, "showVisualizer: false",
        "Dashboard decorative visualizer suppression")
require(dash, "active: root.presentationActive && root.visible",
        "Dashboard equalizer lifecycle")

# The shared control must remain usable in narrow Dashboard tiles: preserve
# both time labels and compact the artwork/transport metrics before overflow.
require(player, "readonly property bool narrowLayout: root.compactLayout && root.width < 340",
        "Narrow shared-player breakpoint")
require(player, "root.narrowLayout ? 82 : 96",
        "Narrow shared-player artwork cap")
if player.count("Layout.minimumWidth: implicitWidth") < 2:
    failures.append("Shared-player time labels must reserve their implicit widths")
for token in (
    "root.narrowLayout ? 22 : (root.compactLayout ? 26 : 30)",
    "root.narrowLayout ? 24 : (root.compactLayout ? 28 : 32)",
    "root.narrowLayout ? 30 : (root.compactLayout ? 34 : 40)",
):
    require(player, token, "Narrow shared-player transport metrics")

if failures:
    print("Dashboard shared media contract regression(s):")
    for failure in failures:
        print("  - " + failure)
    raise SystemExit(1)

print("Dashboard shared media contract: PASS")
