#!/usr/bin/env python3
"""Static contract for compact Bar Media Popup content budgeting."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
bar = (ROOT / "modules/mediaControls/BarMediaPopup.qml").read_text(encoding="utf-8")
player = (ROOT / "modules/mediaControls/PlayerControl.qml").read_text(encoding="utf-8")
eq = (ROOT / "modules/mediaControls/EqualizerPanel.qml").read_text(encoding="utf-8")
horizontal_owner = (ROOT / "modules/bar/Media.qml").read_text(encoding="utf-8")
vertical_owner = (ROOT / "modules/verticalBar/VerticalMedia.qml").read_text(encoding="utf-8")

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

# The tab rail is budgeted by BarMediaPopup itself. A single source must not
# inherit the legacy StyledPopup trailing inset from either Bar orientation.
require(bar, "rightMargin: root.tabCount > 1 ? 16 : 0", "BarMediaPopup tab rail budget")
require(bar, "visible: root.tabCount > 1", "BarMediaPopup tab rail visibility")
for owner, label in (
    (horizontal_owner, "Horizontal Bar media popup owner"),
    (vertical_owner, "Vertical Bar media popup owner"),
):
    require(owner, "popupBackgroundMargin: 0", label)
    if "popupBackgroundMargin: Appearance.sizes.elevationMargin" in owner:
        failures.append(f"{label}: legacy trailing background inset must stay disabled")

for token in (
    "property bool compactLayout: false",
    "readonly property bool narrowLayout: root.compactLayout && root.width < 340",
    "? 7 : (root.compactLayout ? 9 : 12)",
    "readonly property real artworkExtent: root.compactLayout",
    "Layout.minimumWidth: implicitWidth",
    "implicitHeight: root.compactLayout ? 12 : 16",
    "implicitWidth: root.narrowLayout ? 30 : (root.compactLayout ? 34 : 40)",
):
    require(player, token, "PlayerControl compact budget")

for token in (
    "property bool compactLayout: false",
    "readonly property int presetStripHeight:",
    "root.compactLayout ? 20 : 22",
    "? (root.showTransportStatus ? 184 : 154)",
    ": (root.showTransportStatus ? 210 : 180)",
    "clip: root.compactLayout",
    "Layout.preferredHeight: root.compactLayout ? 112 : 132",
    "root.compactLayout ? 40 : 44",
    "root.compactLayout ? 11 : 13",
    "implicitHeight: 20",
):
    require(eq, token, "EqualizerPanel compact budget")

if failures:
    print("Bar Media Popup layout contract regression(s):")
    for failure in failures:
        print("  - " + failure)
    raise SystemExit(1)

print("Bar Media Popup layout contract: PASS")
