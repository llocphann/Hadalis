#!/usr/bin/env python3
"""Static contract for compact Bar Media Popup content budgeting."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
bar = (ROOT / "modules/mediaControls/BarMediaPopup.qml").read_text(encoding="utf-8")
player = (ROOT / "modules/mediaControls/PlayerControl.qml").read_text(encoding="utf-8")
eq = (ROOT / "modules/mediaControls/EqualizerPanel.qml").read_text(encoding="utf-8")

failures = []

def require(source: str, token: str, label: str) -> None:
    if token not in source:
        failures.append(f"{label}: missing {token!r}")

for token in (
    "readonly property bool compactLayout: true",
    "spacing: root.compactLayout ? 6 : 8",
):
    require(bar, token, "BarMediaPopup compact owner")

if bar.count("compactLayout: root.compactLayout") < 2:
    failures.append("BarMediaPopup must pass compactLayout to both PlayerControl and EqualizerPanel")

for token in (
    "property bool compactLayout: false",
    "readonly property real contentMargin: root.compactLayout ? 9 : 12",
    "readonly property real artworkExtent: root.compactLayout",
    "Layout.minimumWidth: 0",
    "implicitHeight: root.compactLayout ? 12 : 16",
    "implicitWidth: root.compactLayout ? 34 : 40",
):
    require(player, token, "PlayerControl compact budget")

for token in (
    "property bool compactLayout: false",
    "implicitHeight: root.compactLayout ? 190 : 214",
    "clip: root.compactLayout",
    "Layout.preferredHeight: root.compactLayout ? 100 : 118",
    "implicitWidth: root.compactLayout ? 22 : 26",
    "implicitWidth: root.compactLayout ? 11 : 13",
    "implicitHeight: root.compactLayout ? 22 : 24",
):
    require(eq, token, "EqualizerPanel compact budget")

if failures:
    print("Bar Media Popup layout contract regression(s):")
    for failure in failures:
        print("  - " + failure)
    raise SystemExit(1)

print("Bar Media Popup layout contract: PASS")
