#!/usr/bin/env python3
"""Lock ii top-level Popup/Sidebar/Dashboard/Settings presentation to slide-only motion."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def qml_block(source: str, marker: str) -> str:
    start = source.find(marker)
    assert start >= 0, f"missing QML marker: {marker}"
    brace = source.find("{", start)
    assert brace >= 0, f"missing block brace after: {marker}"
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index + 1]
    raise AssertionError(f"unbalanced QML block: {marker}")


surface_motion = read("modules/common/SurfaceMotion.qml")
qmldir = read("modules/common/qmldir")
popup = read("modules/bar/StyledPopup.qml")
sidebar = read("modules/sidebar/SidebarHost.qml")
dashboard = read("modules/dashboard/Dashboard.qml")
overview_dashboard = read("modules/overview/OverviewDashboard.qml")
settings_overlay = read("modules/settings/SettingsOverlay.qml")
settings_focus = read("modules/settings/SettingsFocus.qml")
sidebars_config = read("modules/settings/SidebarsConfig.qml")
config_qml = read("modules/common/Config.qml")
defaults = json.loads(read("defaults/config.json"))

for required in (
    "SURFACE-MOTION-IMMUTABLE-LOCK",
    'readonly property string mode: "slide"',
    "readonly property int duration: 300",
    "readonly property int easingType: Easing.InOutCubic",
    "readonly property real dashboardOffset: 24",
):
    assert required in surface_motion, f"SurfaceMotion invariant missing: {required}"

for forbidden in (
    "Config.", "Appearance.", "BezierSpline", "SpringAnimation",
    "SmoothedAnimation", "overshoot", "bounce", "animationCurve",
    "animationSpeed", "contextualMotionProfile",
):
    assert forbidden not in surface_motion, f"SurfaceMotion became mutable/bouncy: {forbidden}"

assert "singleton SurfaceMotion 1.0 SurfaceMotion.qml" in qmldir

popup_motion = qml_block(popup, "Behavior on offsetScale")
assert "SurfaceMotion.duration" in popup_motion
assert "SurfaceMotion.easingType" in popup_motion
assert "easing.bezierCurve" not in popup_motion
assert "Appearance.animation" not in popup_motion
assert "opacity: 1" in qml_block(popup, "ConnectedSurfaceContentHost {")

assert "readonly property string animationType: SurfaceMotion.mode" in sidebar
assert "Config.options?.sidebar?.animationType" not in sidebar
for forbidden in (
    "animOpacity", "animScale", "animTranslateY", "animScaleX",
    "clipWidth", "useClip", "SequentialAnimation",
):
    assert forbidden not in sidebar, f"Sidebar non-slide presentation returned: {forbidden}"
assert sidebar.count('property: "animTranslateX"') == 2
assert sidebar.count("duration: SurfaceMotion.duration") >= 2
assert sidebar.count("easing.type: SurfaceMotion.easingType") >= 2
assert 'Translation.tr("Sidebar animation")' not in sidebars_config
assert 'Config.setNestedValue("sidebar.animationType"' not in sidebars_config
assert "property string animationType:" not in config_qml
assert "animationType" not in defaults.get("sidebar", {})

dashboard_loader = qml_block(dashboard, "Loader {\n            id: contentLoader")
assert "SurfaceMotion.dashboardOffset" in dashboard_loader
assert dashboard_loader.count('property: "panelTranslateY"') == 2
assert "duration: SurfaceMotion.duration" in dashboard_loader
assert "easing.type: SurfaceMotion.easingType" in dashboard_loader
assert 'property: "opacity"' not in dashboard_loader
assert 'property: "scale"' not in dashboard_loader
assert "opacity: 1" in dashboard_loader
assert "scale: 1" in dashboard_loader
assert "active: panelRoot.visible" in dashboard_loader

overview_motion = qml_block(overview_dashboard, "Behavior on revealProgress")
assert "SurfaceMotion.duration" in overview_motion
assert "SurfaceMotion.easingType" in overview_motion
assert "easing.bezierCurve" not in overview_motion

for name, source, card_marker in (
    ("rail", settings_overlay, "Rectangle {\n                id: settingsCard"),
    ("focus", settings_focus, "Rectangle {\n                id: card"),
):
    reveal = qml_block(source, "Behavior on _surfaceReveal")
    assert "SurfaceMotion.duration" in reveal, f"{name} Settings duration drift"
    assert "SurfaceMotion.easingType" in reveal, f"{name} Settings easing drift"
    assert "easing.bezierCurve" not in reveal, f"{name} Settings curve override returned"

    scrim = qml_block(source, "Rectangle {\n                id: scrimBg")
    assert "Behavior on opacity" not in scrim, f"{name} Settings scrim fade returned"

    glass = qml_block(source, "sourceComponent: GlassBackground {")
    assert "Behavior on opacity" not in glass, f"{name} Settings backdrop fade returned"

    card = qml_block(source, card_marker)
    assert "(1 - root._surfaceReveal) * height" in card
    assert "opacity: 1" in card

rail_card = qml_block(settings_overlay, "Rectangle {\n                id: settingsCard")
assert "Behavior on radius" not in rail_card, "top-level Settings radius bounce returned"

print("ii immutable slide-only surface motion contract: PASS")
