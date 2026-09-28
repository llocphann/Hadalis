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

# Launcher must use the same mature visible-content path as Battery and the
# embedded Wi-Fi/Bluetooth dialogs. Do not route labels through the retired
# SelectionGroupButton/AbyssButton experiments.
assert 'text: Translation.tr("Surface Performance")' in content
assert 'text: Translation.tr("Wave Preset")' in content
assert "component ChoiceRow: DialogListItem" in content
assert "contentItem: RowLayout {" in content
assert "MaterialSymbol {" in content
assert "StyledText {" in content
assert "text: choice.buttonText" in content
assert 'text: "check"' in content
assert "SelectionGroupButton" not in content
assert "AbyssButton" not in content

# Mature StyledPopup consumers report stable implicit geometry from one visual
# wrapper before Abyss reparents the content into its output-local host.
assert content.lstrip().startswith("import QtQuick")
assert "Item {\n    id: root" in content
assert "implicitHeight: contentColumn.implicitHeight" in content
assert "width: parent ? parent.width : implicitWidth" in content
assert 'Config.setNestedValue("abyss.quality", value)' in content
assert 'updates["abyss.waves." + key]' in content

print("abyss launcher mature-popup + text/icon contract: ok")
