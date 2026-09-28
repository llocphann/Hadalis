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
assert "root.flow.submit(response)" in impl
assert "cancelAuthenticationRequest()" in impl
assert "property var queue" not in impl
assert "onAuthenticationFailed" in impl
assert "onIsResponseRequiredChanged" in impl

for token in ("actionId", "responseVisible", "responseRequired", "failed",
              "supplementaryMessage", "identities", "identityLabel",
              "detailsText", "busy", "canSubmit"):
    assert token in svc
assert "PopupAnchorRegistry.resolve(hint)" in svc
assert 'GlobalStates.resolveOutputName("", [])' in svc
assert "function selectNextIdentity()" in svc
assert "console.log(response" not in svc
assert "console.log(response" not in impl

for old in (material, waffle):
    assert "const response = inputField.text" in old
    assert old.index('inputField.text = ""') < old.index("PolkitService.submit(response)")
    assert "PolkitService.submit(inputField.text)" not in old

print("Polkit AuthFlow backend/security contract: ok")
