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
active_handler=presenter.split("onPresentationActiveChanged:",1)[1].split("Component.onDestruction:",1)[0]
assert "root.ownsOutput" in active_handler
assert "Component.onDestruction:" in presenter

service=(r/"services/PolkitService.qml").read_text()
assert "property bool presentationRetained: false" in service
assert "property int presentationSerial: 0" in service
assert "readonly property bool presentationMatchesActive:" in service
assert "root.presentationSerial === root.requestSerial" in service
assert "function _startPresentationForCurrentRequest(): void" in service
assert "root.presentationSerial = root.requestSerial" in service
assert "root.presentationRetained = true" in service
assert "function finishPresentation(restartIfActive = true): void" in service
assert "restartIfActive && root.active" in service
assert "PolkitService.finishPresentation(false)" in presenter
destruction=presenter.split("Component.onDestruction:",1)[1]
assert "root.ownsOutput" in destruction
assert "root.presentationRetained = false" in service
assert "root.presentationSerial = 0" in service
serial_gate=service.split("onRequestSerialChanged:",1)[1].split("function finishPresentation",1)[0]
assert "root.presentationRetained" in serial_gate
assert "root.presentationSerial !== root.requestSerial" in serial_gate
assert "root.presentationSerial > 0" not in serial_gate
assert "root.abyssPresenterAvailable" in service
assert "onAbyssPresenterAvailableChanged" in service
assert "function _outputExists(outputName): bool" in service
assert "function _reconcileOutputTopology(): void" in service
assert "target: Quickshell" in service
assert "function onScreensChanged(): void" in service
assert "Qt.callLater(root._reconcileOutputTopology)" in service
assert "root.presentationMatchesActive" in service
assert "root.hadResolvedAnchor" in service
assert "root.finishPresentation(true)" in service
assert 'root.targetOutputName = GlobalStates.resolveOutputName("", [])' in service
assert "root.ownsPresentation" in presenter
assert "root.ownsOutput && PolkitService.presentationMatchesActive" in presenter
assert "onOwnsPresentationChanged" in presenter
capture=presenter.split("function captureLiveModel(): void",1)[1].split("}",1)[0]
assert "root.ownsPresentation" in capture
assert 'function hintSource(appId, anchorItem = null, outputName = ""): void' in service
assert "readonly property int sourceHintLifetimeMs: 3000" in service
assert "id: sourceHintExpiry" in service
assert "sourceHintExpiry.restart()" in service
assert "function _takeSourceHint(): var" in service
assert "property var _pendingPresentationHint: null" in service
assert "root._pendingPresentationHint = root._takeSourceHint()" in service
assert "const hint = root._pendingPresentationHint" in service
assert "root._pendingPresentationHint = null" in service
assert "function _latchPresentation(hint = null): void" in service
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
switch_handler=content.split('glyph: "switch_account"',1)[1].split("}",1)[0]
assert "root.clearResponse()" in switch_handler
assert switch_handler.index("root.clearResponse()") < switch_handler.index("PolkitService.selectNextIdentity()")
assert "enabled: PolkitService.interactionAvailable" in content
assert "&& !(root.model?.busy ?? false)" in content
assert "!root.interactionAvailable || root.busy" in service
assert "detailsOpen" in content
assert "AbyssSearchField" in content
catalog=(r/"translations/en_US.json").read_text()
for key in (
    "Authentication required", "Authentication failed. Try again.",
    "Authenticating…", "Authenticate", "Identity", "Switch", "Hide details"
):
    assert f'"{key}":' in catalog
for forbidden in ("ConfirmationService", "GlobalStates", "Config.", "console."):
    assert forbidden not in content
for forbidden in ("NumberAnimation", "ScaleAnimator", "OpacityAnimator"):
    assert forbidden not in presenter
    assert forbidden not in content

print("Abyss Polkit presenter/content contract: ok")
