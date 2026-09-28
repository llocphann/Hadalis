#!/usr/bin/env python3
from pathlib import Path

r = Path(__file__).resolve().parents[1]
bar_module = (r / "modules/abyss/bar/AbyssBarModule.qml").read_text()
bar = (r / "modules/abyss/bar/AbyssBar.qml").read_text()
styled = (r / "modules/bar/StyledPopup.qml").read_text()
perimeter = (r / "modules/abyss/AbyssPerimeter.qml").read_text()
content = (r / "modules/abyss/content/AbyssLauncherControlsPopup.qml").read_text()

assert "Shared.StyledPopup {" in bar_module
assert 'liquidPresentationKind: "launcher"' in bar_module
assert "hoverTarget: launcherAnchor" in bar_module
assert 'root.hoverRequest("launcher")' not in bar_module
assert "property string liquidPresentationKind" in styled
assert "hostedPopup?.liquidPresentationKind" in perimeter

assert "popupJoinedEdge: placement?.joinCorner" in bar
assert "hostedPopup?._liquidAnchor?.popupJoinedEdge" in perimeter

assert 'label: "Surface Performance"' in content
assert 'label: "Wave Preset"' in content
assert "component SectionHeading: RowLayout" in content
assert "MaterialSymbol {" in content
assert "StyledText {" in content
assert "SelectionGroupButton {" in content
assert "buttonText:" in content
assert "buttonIcon:" in content
assert "AbyssButton" not in content
assert 'Config.setNestedValue("abyss.quality", value)' in content
assert 'updates["abyss.waves." + key]' in content

print("abyss launcher mature-popup + text/icon contract: ok")
