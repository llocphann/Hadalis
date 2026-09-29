#!/usr/bin/env python3
from pathlib import Path

r=Path(__file__).resolve().parents[1]
presenter=(r/"modules/abyss/AbyssPolkitPresenter.qml").read_text()
content=(r/"modules/abyss/content/AbyssPolkitContent.qml").read_text()

assert "StyledPopup {" in presenter
assert 'liquidPresentationKind: "polkit"' in presenter
assert "keyboardFocus: true" in presenter
assert "exclusiveKeyboardFocus: true" in presenter
assert "PanelWindow" not in presenter and "WindowDialog" not in presenter
assert "latchedModel" in presenter
assert "PolkitService.hadResolvedAnchor" in presenter
assert "PolkitService.finishPresentation()" in presenter
assert "Component.onDestruction:" in presenter

service=(r/"services/PolkitService.qml").read_text()
assert "property bool presentationRetained: false" in service
assert "root.presentationRetained = true" in service
assert "function finishPresentation(): void" in service
assert "root.presentationRetained = false" in service
assert 'function hintSource(appId, anchorItem = null, outputName = ""): void' in service
assert "readonly property int sourceHintLifetimeMs: 3000" in service
assert "id: sourceHintExpiry" in service
assert "sourceHintExpiry.restart()" in service
assert "function _takeSourceHint(): var" in service
assert "const hint = root._takeSourceHint()" in service
assert "onTriggered: root._nextSourceHint = null" in service
assert "const requestedOutput = GlobalStates.resolveOutputName(" in service
assert "PopupAnchorRegistry.resolve(sourceContext)" in service
assert "readonly property bool resolvedAnchorUsable:" in service
assert "PopupAnchorRegistry.isUsable(root.resolvedAnchor)" in service
assert "onResolvedAnchorUsableChanged" in service

assert "const response = inputField.text" in content
assert content.index('inputField.text = ""') < content.index("PolkitService.submit(response)")
assert "inputMethodHints: Qt.ImhSensitiveData" in content
assert "Qt.Key_Escape" in content
assert "Qt.Key_Return" in content and "Qt.Key_Enter" in content
assert "onInteractionAvailableChanged" in content
assert "Authentication failed. Try again." in content
assert "selectNextIdentity()" in content
assert "enabled: PolkitService.interactionAvailable" in content
assert "&& !(root.model?.busy ?? false)" in content
assert "!root.interactionAvailable || root.busy" in service
assert "detailsOpen" in content
assert "AbyssSearchField" in content
for forbidden in ("ConfirmationService", "GlobalStates", "Config.", "console."):
    assert forbidden not in content
for forbidden in ("NumberAnimation", "ScaleAnimator", "OpacityAnimator"):
    assert forbidden not in presenter
    assert forbidden not in content

print("Abyss Polkit presenter/content contract: ok")
