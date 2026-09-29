#!/usr/bin/env python3
from pathlib import Path

r=Path(__file__).resolve().parents[1]
per=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
polkit=(r/"services/PolkitService.qml").read_text()

# Ordinary perimeter visibility still obeys fullscreen policy.
assert "readonly property bool fullscreenCovered:" in per
assert "readonly property bool presented: !GlobalStates.screenLocked" in per
assert "visibleInFullscreen" in per

# Critical confirmation/auth presentation gets a popup-field-only override.
assert "readonly property bool criticalPromptOwned:" in per
assert "ConfirmationService.active" in per
assert "ConfirmationService.targetOutputName === outputName" in per
assert "PolkitService.presentationRetained" in per
assert "PolkitService.targetOutputName === outputName" in per
assert "readonly property bool popupFieldPresented:" in per
assert "window.presented || window.criticalPromptOwned" in per

# The controller, field, prompt presenters, focus and popup input participate in
# that override; ordinary Bar/Dock/side bodies remain gated by window.presented.
assert "presented: window.popupFieldPresented" in per
assert "visible: window.popupFieldPresented" in per
assert per.count("presentationEnabled: window.popupFieldPresented && field.ready") == 2
assert "open: window.popupFieldPresented && field.ready" in per
assert "WlrLayershell.keyboardFocus: !window.popupFieldPresented" in per
for i in range(4):
    assert f"width: window.popupFieldPresented && field.ready ? (liquid.popupInputBounds[{i}]?.width ?? 0) : 0" in per
assert "visible: window.presented && field.ready && (window.editorOpen || root.barOnOutput(window.outputName))" in per
assert "open: window.presented && field.ready && GlobalStates.shellEntryReady" in per

# Polkit retains only presentation lifetime after AuthFlow stops, allowing the
# same StyledPopup retract tail while the fullscreen popup field remains alive.
assert "property bool presentationRetained: false" in polkit
assert "function finishPresentation(): void" in polkit

print("Abyss critical prompt fullscreen contract: ok")
