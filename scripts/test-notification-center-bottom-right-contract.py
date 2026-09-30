#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STYLED_POPUP = ROOT / "modules" / "bar" / "StyledPopup.qml"
CENTER_POPUP = ROOT / "modules" / "notificationCenter" / "NotificationCenterPopup.qml"
CORNERS = ROOT / "modules" / "screenCorners" / "ScreenCorners.qml"


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


def require(source: str, token: str, message: str) -> None:
    if token not in source:
        fail(message + " (" + token + ")")


styled = STYLED_POPUP.read_text(encoding="utf-8")
center = CENTER_POPUP.read_text(encoding="utf-8")
corners = CORNERS.read_text(encoding="utf-8")

# ScreenCorners is the single physical owner and the feature must stay on the
# actual bottom-right corner.
for token in (
    "readonly property bool shouldShowNotificationCenterCorner:",
    "cornerPanelWindow.isBottomRight",
    "id: notificationCenterCornerLoader",
    "bottom: parent.bottom",
    "right: parent.right",
):
    require(corners, token, "notification center bottom-right corner contract missing")

# A ScreenCorners PanelWindow is only the tiny hit region. Its local x/y begin at
# zero even on the physical trailing edge, so StyledPopup must support pinning
# tangent placement to the full output edge rather than treating those locals as
# output coordinates.
for token in (
    'property string tangentEdgeOverride: ""',
    'root.tangentEdgeOverride === "start" ? 0',
    'root.tangentEdgeOverride === "end"',
    "outputWidth - localWidth",
    "outputHeight - localHeight",
):
    require(styled, token, "shared popup output-edge tangent override missing")

require(center, 'tangentEdgeOverride: "end"',
        "notification center must pin to the trailing tangent edge")

# Keep the center attached to the bottom/right owner axis while tangent placement
# independently stays at the trailing edge. This covers both horizontal bottom
# bars and vertical right bars.
for token in (
    "attachmentEdgeOverride: root.cornerAttachmentEdge",
    "attachmentThicknessOverride: root.cornerAttachmentThickness",
):
    require(center, token, "notification center attachment contract missing")

print("PASS: notification center is anchored to the physical bottom-right")
