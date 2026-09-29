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
assert "function _liquidAnchorFor(item): var" in registry
assert "function isUsable(item): bool" in registry
assert "return root._validItem(item)" in registry
assert "function _treeVisibleAndEnabled(item): bool" in registry
assert "function _liquidAnchorPresented(anchor): bool" in registry
assert "anchor.visualResident !== undefined" in registry
assert "const liquidAnchor = root._liquidAnchorFor(item)" in registry
assert "root._treeVisibleAndEnabled(item)" in registry
assert "root._liquidAnchorPresented(liquidAnchor)" in registry
assert "function resolve(source): var" in registry
assert "source?.anchorItem" in registry
assert "AnchorPolicy.matchScore(candidate, alias)" in registry
assert "const requestedOutput = String(source?.outputName ?? \"\")" in registry
assert "AnchorPolicy.placementScore(" in registry
assert 'kind === "tray"' not in registry  # priority policy stays pure/testable
assert "menuEntry" not in registry
assert "Quit" not in registry

# Implicit ownership never relies on human-facing labels.
assert "source.appName" not in registry
tray_registration=tray.split("Component.onCompleted:",1)[1].split("Component.onDestruction:",1)[0]
bar_registration=bar.split("registerAnchor",1)[1].split("], 250)",1)[0]
dock_registration=dock.split("registerAnchor",1)[1].split("], 200)",1)[0]
assert "root.item?.title" not in tray_registration
assert "root.item?.tooltipTitle" not in tray_registration
assert "root.desktopEntry?.name" not in bar_registration
assert "root.desktopEntry?.name" not in dock_registration

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
assert "const requestedOutput = GlobalStates.resolveOutputName(" in service
assert "const sourceContext = Object.assign({}, request" in service
assert "PopupAnchorRegistry.resolve(sourceContext)" in service
assert "_resolvedAnchor: resolved?.item ?? null" in service
assert "_resolvedOutput:" in service
assert "readonly property bool resolvedAnchorUsable:" in service
assert "PopupAnchorRegistry.isUsable(root.resolvedAnchor)" in service
assert "onResolvedAnchorUsableChanged" in service
assert "function _resolveAction(action, force = false): void" in service
assert "function cancel(force = false): void" in service
assert "root.cancel(true)" in service
assert "onAnchorRemoved(item)" in service

# Generic confirmation state contains no authentication response/secret fields.
for forbidden in ("password", "secret", "responseText", "credential"):
    assert forbidden not in service.lower()

print("confirmation request/anchor foundation contract: ok")
