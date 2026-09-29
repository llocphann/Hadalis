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
assert "const directSupplied = source?.anchorItem !== null" in registry
assert "if (directSupplied)" in registry
assert "if (!root._validItem(direct))" in registry
direct_block=registry.split("if (directSupplied)",1)[1].split("const wanted =",1)[0]
assert "return null" in direct_block
assert "AnchorPolicy.matchScore(candidate, alias)" in registry
assert "const requestedOutput = String(source?.outputName ?? \"\")" in registry
assert "AnchorPolicy.placementScore(" in registry
assert "let ambiguousBest = false" in registry
assert "if (total === bestScore)" in registry
assert "ambiguousBest = true" in registry
assert "return ambiguousBest ? null : best" in registry
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
assert "const usedIds = []" in service
assert 'const requestedId = String(action?.id ?? "").trim()' in service
assert "while (usedIds.includes(id))" in service
assert 'id = baseId + "-" + suffix++' in service
assert "property bool requestVisible: false" in service
assert "property int _presentationStartedRequestId: 0" in service
assert "property int _presentationReleaseHoldRequestId: 0" in service
assert "property bool _presentationReleaseObservedWhileHeld: false" in service
assert "property int _presentationHandoffRequestId: 0" in service
assert "function markPresentationStarted(requestId): void" in service
assert "function holdPresentationRelease(requestId): bool" in service
hold=service.split("function holdPresentationRelease(requestId): bool",1)[1].split("function releasePresentationHold",1)[0]
assert "root._presentationReleaseHoldRequestId === id" in hold
assert "return true" in hold
assert "root._presentationReleaseObservedWhileHeld = false" in hold
assert hold.index("root._presentationReleaseHoldRequestId === id") < hold.index("root._presentationReleaseObservedWhileHeld = false")
assert "function releasePresentationHold(requestId): void" in service
assert "function beginPresentationHandoff(requestId): bool" in service
assert "function resolvePresentationHandoff(requestId, actionId): bool" in service
assert "function cancelPresentationHandoff(requestId, lifecycle = false): bool" in service
handoff=service.split("function beginPresentationHandoff(requestId): bool",1)[1].split("function resolvePresentationHandoff",1)[0]
assert "root.holdPresentationRelease(id)" in handoff
assert "root._presentationHandoffRequestId = id" in handoff
assert "root.requestVisible = false" in handoff
resolve_handoff=service.split("function resolvePresentationHandoff(requestId, actionId): bool",1)[1].split("function cancelPresentationHandoff",1)[0]
assert "root.requestResolved(id, wanted)" in resolve_handoff
assert "root._invoke(action.callback)" in resolve_handoff
assert "root.releasePresentationHold(id)" in resolve_handoff
cancel_handoff=service.split("function cancelPresentationHandoff(requestId, lifecycle = false): bool",1)[1].split("// Presenter calls",1)[0]
assert "root._invoke(cancelAction.callback)" in cancel_handoff
assert "root._invoke(request.onCancel)" in cancel_handoff
assert "root.releasePresentationHold(id)" in cancel_handoff
assert "function finishPresentation(requestId): void" in service
assert "if (!root.currentRequest || root.requestVisible)" in service
finish=service.split("function finishPresentation(requestId): void",1)[1].split("function _activateNext",1)[0]
assert "root._presentationReleaseHoldRequestId === id" in finish
assert "root._presentationReleaseObservedWhileHeld = true" in finish
release_hold=service.split("function releasePresentationHold(requestId): void",1)[1].split("// Presenter calls",1)[0]
assert "root._presentationStartedRequestId !== id" in release_hold
assert "root.finishPresentation(id)" in release_hold
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
assert "function _cancelLifecycle(request): void" in service
assert "function cancel(force = false): void" in service
assert "function cancelOwned(owner): void" in service
owned=service.split("function cancelOwned(owner): void",1)[1].split("onResolvedAnchorUsableChanged",1)[0]
assert "const ownsCurrent =" in owned
assert "root._presentationHandoffRequestId === root.currentRequestId" in owned
assert "root.cancelPresentationHandoff(root.currentRequestId, true)" in owned
assert "root.cancel(true)" in owned
assert "root._presentationReleaseHoldRequestId" in owned
assert "root.releasePresentationHold(root.currentRequestId)" in owned
assert "onAnchorRemoved(item)" in service
assert "function _outputExists(outputName): bool" in service
assert "function _reconcileOutputTopology(): void" in service
assert "target: Quickshell" in service
assert "function onScreensChanged(): void" in service
assert "Qt.callLater(root._reconcileOutputTopology)" in service
assert "root.currentRequest = Object.assign({}, root.currentRequest" in service

# Generic confirmation state contains no authentication response/secret fields.
for forbidden in ("password", "secret", "responseText", "credential"):
    assert forbidden not in service.lower()

print("confirmation request/anchor foundation contract: ok")
