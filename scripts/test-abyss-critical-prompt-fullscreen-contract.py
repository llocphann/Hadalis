#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
per=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
assert "readonly property bool fullscreenCovered:" in per
assert "readonly property bool presented: !GlobalStates.screenLocked" in per
assert "visibleInFullscreen" in per
assert "readonly property bool criticalPromptOwned:" in per
assert "ConfirmationService.active" in per
assert "ConfirmationService.targetOutputName === outputName" in per
assert "PolkitService.presentationRetained" not in per
assert "readonly property bool popupFieldPresented:" in per
assert "window.presented || window.criticalPromptOwned" in per
assert "presented: window.popupFieldPresented" in per
assert "visible: window.popupFieldPresented" in per
assert per.count("presentationEnabled: window.popupFieldPresented && field.ready") == 1
assert "AbyssPolkitPresenter {" not in per
assert "open: window.popupFieldPresented && field.ready" in per
assert "WlrLayershell.keyboardFocus: !window.popupFieldPresented" in per
assert "WlrLayershell.layer: window.criticalPromptOwned ? WlrLayer.Overlay" in per
assert "GlobalStates.settingsNativeDialogOpen ? WlrLayer.Bottom" in per
assert "(GlobalStates.settingsNativeDialogOpen && !window.criticalPromptOwned)" in per
for i in range(4):
    assert f"width: window.popupFieldPresented && field.ready ? (liquid.popupInputBounds[{i}]?.width ?? 0) : 0" in per
assert "visible: window.presented && field.ready && (window.editorOpen || root.barOnOutput(window.outputName))" in per
assert "open: window.presented && field.ready && GlobalStates.shellEntryReady" in per
print("Abyss critical confirmation fullscreen contract: ok")
