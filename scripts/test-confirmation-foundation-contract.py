#!/usr/bin/env python3
from pathlib import Path

r=Path(__file__).resolve().parents[1]
registry=(r/"services/PopupAnchorRegistry.qml").read_text()
service=(r/"services/ConfirmationService.qml").read_text()
tray=(r/"modules/bar/SysTrayItem.qml").read_text()
bar=(r/"modules/bar/BarTaskbarButton.qml").read_text()
dock=(r/"modules/dock/DockAppButton.qml").read_text()
qmdir=(r/"services/qmldir").read_text()

assert "singleton ConfirmationService 1.0 ConfirmationService.qml" in qmdir
assert "singleton PopupAnchorRegistry 1.0 PopupAnchorRegistry.qml" in qmdir

# Source placement is identity/Item based; no action-label interception.
assert "function resolve(source): var" in registry
assert "source.anchorItem" in registry
assert "AnchorPolicy.matchScore(candidate, alias)" in registry
assert 'kind === "tray"' not in registry  # priority policy stays pure/testable
assert "menuEntry" not in registry
assert "Quit" not in registry

# Every visible app surface registers its live Item; tray outranks bar then dock.
assert 'registerAnchor(\n        root, "tray"' in tray
assert 'registerAnchor(root, "bar"' in bar
assert 'registerAnchor(root, "dock"' in dock

# Queue ownership is semantic/visual-tail safe.
assert "property var currentRequest: null" in service
assert "property bool requestVisible: false" in service
assert "function finishPresentation(requestId): void" in service
assert "if (!root.currentRequest || root.requestVisible)" in service
assert "Qt.callLater(root._activateNext)" in service
assert "_resolvedAnchor: resolved?.item ?? null" in service
assert "_resolvedOutput:" in service
assert "onAnchorRemoved(item)" in service
assert "root.cancel()" in service

# Generic confirmation state contains no authentication response/secret fields.
for forbidden in ("password", "secret", "responseText", "credential"):
    assert forbidden not in service.lower()

print("confirmation request/anchor foundation contract: ok")
