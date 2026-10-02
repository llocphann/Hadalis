#!/usr/bin/env python3
"""Bounded source/behavior safety contract, NOT a visual resemblance verdict.

The four original maintainer references are separately required before a
subjective approval. This test never creates or publishes reference imagery.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
body = (ROOT / "modules/abyss/companion/WaterDropletBody.qml").read_text()
host = (ROOT / "modules/abyss/companion/AbyssCompanion.qml").read_text()
perimeter = (ROOT / "modules/abyss/AbyssPerimeter.qml").read_text()
style = (ROOT / "modules/abyss/looks/AbyssStyle.qml").read_text()
defaults = json.loads((ROOT / "defaults/config.json").read_text())

# Wull stays generated from actual geometry in the live QML scene.
assert "import QtQuick.Shapes" in body
assert not re.search(r"\b(?:Image|AnimatedImage|AnimatedSprite|SpriteSequence|Video)\s*\{", body)
assert not re.search(r"(?:\.png|\.gif|\.webp|\.apng|\.jpg|mascot/manifest)", body, re.I)
outline = body.split("    Shape {\n        anchors.fill: parent", 1)[1].split(
    "    Rectangle {\n        width: 17", 1
)[0]
assert outline.count("PathCubic {") == 6, "six-lobe procedural plump outline required"
assert "root.width * 0.035" in outline and "root.width * 0.965" in outline, (
    "plump lateral outline must not regress to the old narrow body"
)
for token in ("AbyssStyle.accent", "AbyssStyle.surfaceRaised",
              "AbyssStyle.surfaceDeep", "AbyssStyle.specular",
              "AbyssStyle.textColor"):
    assert token in body and ("property color " + token.split(".")[-1]) in style, token

# Paired expressive eyes each get multiple light catches; blush is subtle.
eye = body.split("// Larger paired eyes and layered moving catchlights", 1)[1].split(
    "// Two small warm cheek glints", 1
)[0]
assert eye.count("model: 2") == 1
assert "width: 14; height: 18" in eye
assert "root.eyeOpen" in eye
assert "root.gazeX" in eye and "root.gazeY" in eye
assert eye.count("AbyssStyle.specular") >= 2, "two eye specular layers"
cheeks = body.split("// Two small warm cheek glints", 1)[1].split(
    "        Shape {\n            width: 24; height: 12", 1
)[0]
assert "model: 2" in cheeks and "radius: 2.5" in cheeks
assert "root.pulse" in cheeks, "cheeks must respond to expressions"
for token in ("SpringAnimation", "stateSquash", "stateStretch",
              "stateLean", "stateTip", "on eyeOpen", "on mouthCurve",
              "SequentialAnimation on bob", "SequentialAnimation on sway"):
    assert token in body, token
assert "property real orientationAngle: 0" in body
assert "rotation: orientationAngle + sway" in body
assert body.count("id: faceOverlay") == 1
assert "rotation: -root.orientationAngle" in body
assert 'orientationAngle: root.edge === "left" ? 90' in host
assert 'rotation: root.edge' not in host
assert 'anchors.verticalCenter: root.verticalEdge ? parent.verticalCenter : undefined' in host
assert 'anchors.left: root.edge === "left" ? parent.left : undefined' in host
assert 'anchors.right: root.edge === "right" ? parent.right : undefined' in host
assert "running: root.motionEnabled" in body
assert "root.motionEnabled && AbyssStyle.quality" in body
assert "Timer {" not in body

# Geometric artwork must not expand or bypass the separate production mask.
assert "implicitWidth: 76" in body and "implicitHeight: 92" in body
assert "implicitWidth: verticalEdge ? 98 : 112" in host
assert "implicitHeight: verticalEdge ? 112 : 98" in host
assert 'anchors.top: root.edge === "bottom" ? parent.top : undefined' in host
assert 'anchors.bottom: root.edge === "top" ? parent.bottom : undefined' in host
assert "anchors.bottomMargin" not in host
assert "width: root.verticalEdge ? 10 : 28" in host
assert "height: root.verticalEdge ? 28 : 10" in host
assert "color: AbyssStyle.surface" in host
assert "border.color: Qt.alpha(AbyssStyle.specular, 0.08" in host
assert perimeter.count("AbyssCompanion {") == 1
assert perimeter.count("CompanionBridge {") == 1
assert 'WullHostPolicy.acceptsInput(window.companionHostActive, companion.interactive, companion.visible)' in perimeter
assert defaults["abyss"]["companion"]["enabled"] is False
print("WULL_PROCEDURAL_VISUAL_SOURCE_SAFETY_PASS")
