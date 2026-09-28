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

# Launcher stays on the existing compact segmented-control primitive.
# Each section is one horizontal row: icons stay visible for every option and
# only the selected mode/preset exposes its label.
assert 'text: Translation.tr("Surface Performance")' in content
assert 'text: Translation.tr("Wave Preset")' in content
assert "component CompactChoice: SelectionGroupButton" in content
assert 'buttonText: selected ? labelText : ""' in content
assert "buttonIcon: iconName" in content
assert "toggled: selected" in content
assert content.count("RowLayout {") >= 2
assert content.count("Layout.alignment: Qt.AlignLeft") >= 4
assert "Layout.alignment: Qt.AlignHCenter" not in content
assert "color: Appearance.colors.colLayer0Border" in content
assert "opacity: 0.65" in content
assert "WindowDialogSeparator" not in content
assert "implicitWidth: 260" in content
assert "implicitHeight: 34" in content
assert "AbyssButton" not in content
assert "import qs.services" in content

assert 'Config.setNestedValue("abyss.quality", value)' in content
assert 'updates["abyss.waves." + key]' in content

print("abyss launcher mature-popup + text/icon contract: ok")
