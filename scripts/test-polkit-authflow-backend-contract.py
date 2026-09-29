#!/usr/bin/env python3
from pathlib import Path

r=Path(__file__).resolve().parents[1]
svc=(r/"services/PolkitService.qml").read_text()
impl=(r/"services/PolkitServiceImpl.qml").read_text()
material=(r/"modules/polkit/PolkitContent.qml").read_text()
waffle=(r/"modules/waffle/polkit/WPolkitContent.qml").read_text()

assert "PolkitAgent {" in impl
assert "property int requestSerial: 0" in impl
assert "root.requestSerial += 1" in impl
assert "root.interactionAvailable = root.flow?.isResponseRequired ?? false" in impl
assert "root.flow.submit(response)" in impl
assert "cancelAuthenticationRequest()" in impl
assert "property var queue" not in impl
assert "onAuthenticationFailed" in impl
failed_handler=impl.split("function onAuthenticationFailed()",1)[1].split("function onIsResponseRequiredChanged()",1)[0]
assert "root.flow?.isResponseRequired ?? false" in failed_handler
assert "root.interactionAvailable = true" not in failed_handler
assert "onIsResponseRequiredChanged" in impl
assert "onInputPromptChanged" in impl

# Source disappearance may arrive through two lifecycle signals, but the real
# AuthFlow cancellation must be emitted once per authentication request.
assert "property bool _sourceLossCancelIssued: false" in svc
assert "property int resolvedAnchorRequestSerial: 0" in svc
assert "root.resolvedAnchorRequestSerial = root.requestSerial" in svc
assert "function _cancelActiveForSourceLoss(): void" in svc
assert "function _cancelForSourceLoss(): void" in svc
assert "root._sourceLossCancelIssued = true" in svc
assert "root._sourceLossCancelIssued = false" in svc
assert "root._cancelForSourceLoss()" in svc
source_loss=svc.split("function _cancelForSourceLoss(): void",1)[1].split("onResolvedAnchorUsableChanged",1)[0]
assert "root.resolvedAnchorRequestSerial !== root.requestSerial" in source_loss
assert "root._activeHintResolvedOnce" in source_loss
assert "root.abyssPresentationSuppressed" in source_loss
assert 'Config.options?.panelFamily !== "abyss"' in source_loss
assert 'includes("abyssPerimeter")' in source_loss

for token in ("actionId", "responseVisible", "responseRequired", "failed",
              "supplementaryMessage", "identities", "identityLabel",
              "detailsText", "busy", "canSubmit"):
    assert token in svc
assert "PopupAnchorRegistry.resolve(sourceContext)" in svc
assert "const requestedOutput = GlobalStates.resolveOutputName(" in svc
assert "String(hint?.outputName ?? \"\")" in svc
assert "function selectNextIdentity()" in svc
assert "console.log(response" not in svc
assert "console.log(response" not in impl

for old in (material, waffle):
    assert "function clearResponse(): void" in old
    assert "function cancelAuthentication(): void" in old
    cancel=old.split("function cancelAuthentication(): void",1)[1].split("}",1)[0]
    assert "root.clearResponse()" in cancel
    assert "PolkitService.cancel()" in cancel
    assert cancel.index("root.clearResponse()") < cancel.index("PolkitService.cancel()")
    assert "const response = inputField.text" in old
    assert "inputField.clear()" in old
    assert old.index("inputField.clear()") < old.index("PolkitService.submit(response)")
    assert "PolkitService.submit(inputField.text)" not in old
    assert "inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText" in old
    assert "onRequestSerialChanged" in old
    assert "onActiveChanged" in old
    assert "Component.onDestruction: root.clearResponse()" in old
    # The focused field can consume Escape before the root-level handler.
    # It must therefore route through the scrub-first cancel helper too.
    assert "PolkitService.cancel()" in cancel
    assert old.count("root.cancelAuthentication()") >= 2
    for escape in old.split("Qt.Key_Escape")[1:]:
        handler=escape.split("}",1)[0]
        assert "root.cancelAuthentication()" in handler
        assert "PolkitService.cancel()" not in handler

print("Polkit AuthFlow backend/security contract: ok")
