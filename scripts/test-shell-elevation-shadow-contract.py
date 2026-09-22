#!/usr/bin/env python3
"""Guard rounded shell elevation without restoring retired perimeter painters."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, *tokens: str) -> None:
    for token in tokens:
        assert token in text, f"Missing shadow contract: {token}"


edge = source("modules/screenCorners/ScreenEdges.qml")
theme = source("modules/common/Appearance.qml")
popup = source("modules/bar/StyledPopup.qml")
iris = source("modules/common/perimeter/ConnectedSurfaceIrisFrame.qml")
shared = source("modules/common/widgets/StyledRectangularShadow.qml")
sidebar = source("modules/sidebar/SidebarHost.qml")
overview = source("modules/overview/OverviewDashboard.qml")
dashboard = source("modules/dashboard/DashboardContent.qml")
canvas = source("modules/dashboard/DashboardCanvas.qml")
settings = (
    source("modules/settings/SettingsOverlay.qml"),
    source("modules/settings/SettingsFocus.qml"),
)
bars = (
    source("modules/bar/BarContent.qml"),
    source("modules/verticalBar/VerticalBarContent.qml"),
)

# The physical frame owns one inverted silhouette. A blur kernel ceiling
# without shadowBlur does not produce the soft corner falloff.
require(edge,
    "fillRule: ShapePath.OddEvenFill",
    "readonly property bool physicalShadowActive:",
    "layer.enabled: frameShape.physicalShadowActive",
    "shadowEnabled: frameShape.physicalShadowActive",
    "blurMax: Math.max(1, root.physicalShadowSize)",
    "shadowBlur: 1.0",
    "shadowHorizontalOffset: 0",
    "shadowVerticalOffset: 0",
    "Appearance.m3colors.m3shadow",
)
assert edge.count("Shape {") == 1, "The physical frame must remain one shape"
assert "PerimeterCornerShadow" not in edge
assert "RoundCorner {" not in edge

# Transparent materials are not transparent elevation ink.
require(theme, "property color colShadow: Qt.alpha(m3colors.m3shadow, 0.45)")
assert 'property color colShadow: m3colors.transparent' not in theme

# Every connected body samples a live shadow outside the opaque iRiS field.
# The ownership clip prevents shadows leaking across attached Screen Edges.
require(iris,
    "readonly property rect shadowPaintBounds:",
    "root.clipExternalOwners(root.rawShadowBounds, 0)",
    "id: shadowTextureSource",
    "id: isolatedShadow",
    "sourceItem: shadowTextureSource",
    "hideSource: true",
    "live: true",
    "cached: false",
    "id: field",
)
assert iris.index("id: isolatedShadow") < iris.index("id: field")

for surface in (popup, sidebar, overview):
    require(surface, "Appearance.m3colors.m3shadow", "shadowEnabled:")
for surface in settings:
    require(surface,
        "ConnectedSurfaceIrisEdgeSurface {",
        "Appearance.m3colors.m3shadow",
        "screenEdge?.shadow?.size ?? 15",
        "screenEdge?.shadow?.opacity ?? 0.70",
    )
    assert "sourceComponent: StyledRectangularShadow" not in surface

# The normal Bar is part of the physical perimeter, not a second local shadow.
for bar in bars:
    assert "sourceComponent: StyledRectangularShadow" not in bar

# Floating Dashboard and individual cards need distinct shadow owners.
require(dashboard,
    "StyledRectangularShadow {",
    "target: background",
    "Appearance.m3colors.m3shadow",
)
require(canvas,
    "clip: false",
    "id: canvas",
    "id: cardViewport",
    "clip: true",
    "StyledRectangularShadow {",
    "target: cardWrap",
    "z: -1",
    "Appearance.m3colors.m3shadow",
)
assert canvas.index("target: cardWrap") < canvas.index("id: cardViewport")
require(shared,
    "property color color: Appearance.colors.colShadow",
    "cached: !(root.joinTop || root.joinBottom",
)

print("Shell rounded elevation shadow contract: PASS")
