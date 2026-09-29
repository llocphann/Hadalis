#!/usr/bin/env python3
from pathlib import Path

r=Path(__file__).resolve().parents[1]
presenter=(r/"modules/abyss/AbyssConfirmationPresenter.qml").read_text()
content=(r/"modules/abyss/content/AbyssConfirmationContent.qml").read_text()
perimeter=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
close=(r/"modules/closeConfirm/CloseConfirm.qml").read_text()
service=(r/"services/ConfirmationService.qml").read_text()

# Confirmation is a mature StyledPopup, not a detached dialog/window.
assert "StyledPopup {" in presenter
assert 'liquidPresentationKind: "confirmation"' in presenter
assert "keyboardFocus: true" in presenter
assert "exclusiveKeyboardFocus: true" in presenter
assert "closeOnOutsideClick: false" in presenter
assert "PanelWindow" not in presenter
assert "WindowDialog" not in presenter

# Attached source loss cancels/retracts instead of teleporting to fallback.
assert "root.hadResolvedAnchor" in presenter
assert "? ConfirmationService.resolvedAnchor" in presenter
assert ": root.fallbackAnchor" in presenter
assert "function scheduleFinish(requestId): void" in presenter
assert "Qt.callLater(() => ConfirmationService.finishPresentation(id))" in presenter
assert "function finishIfReleased(): void" in presenter
assert "root.scheduleFinish(root.requestId)" in presenter
assert "onRequestVisibleChanged" in presenter
assert "Component.onDestruction:" in presenter
assert "root.ownsRequest && !ConfirmationService.requestVisible" in presenter
active_change=presenter.split("onPresentationActiveChanged:",1)[1].split("AbyssConfirmationContent",1)[0]
assert "ConfirmationService.markPresentationStarted(root.requestId)" in active_change

# Nested source anchors (notably Dock apps) inherit their host Join Edge.
host=(r/"modules/abyss/AbyssBodyHost.qml").read_text()
assert "readonly property string popupJoinedEdge: joinedEdge" in host
assert 'hostedPopup?._liquidAnchor?.popupJoinedEdge ?? ""' in perimeter

# Top-center fallback is a real shared prompt source Item on the same liquid controller.
assert "id: promptFallbackAnchor" in perimeter
assert 'property var liquidController: liquid' in perimeter
assert 'property string attachedEdge: "top"' in perimeter
assert "x: (window.width - width) / 2" in perimeter
assert "AbyssConfirmationPresenter {" in perimeter

# Reuse Abyss primitives/content-fit; no confirmation-only fade/scale animation.
for primitive in ("AbyssLabel", "AbyssButton", "AbyssSeparator"):
    assert primitive in content
assert "minContentWidth" in content and "maxContentWidth" in content
assert "Text.WordWrap" in content
assert "Flow {" in content
assert 'Translation.tr("Hide details")' in content
assert 'Translation.tr("Details")' in content
assert "visible: modelData?.visible !== false" in content
assert "enabled: modelData?.enabled !== false" in content
assert "function _actionUsable(action): bool" in service
assert "if (!force && !root._actionUsable(action))" in service
assert "root._actionUsable(action)" in service
assert "function cancelAction(): var" in service
assert "function _cancelLifecycle(request): void" in service
assert 'root.requestResolved(Number(request._requestId ?? 0), "cancel")' in service
assert "root._invoke(request.onCancel)" in service
force_branch=service.split("function cancel(force = false): void",1)[1].split("// Presenter calls",1)[0]
assert "if (force)" in force_branch
assert "root._cancelLifecycle(request)" in force_branch
for forbidden in ("NumberAnimation", "ScaleAnimator", "OpacityAnimator"):
    assert forbidden not in content
    assert forbidden not in presenter

# Existing closeConfirm backend provides the real action callback.
assert 'owner: "closeConfirm"' in close
assert "ConfirmationService.enqueue({" in close
assert "sourceWindowId: windowId" in close
assert "function _sameCloseWindowRequest(request, windowId): bool" in close
assert "function _hasPendingAbyssRequest(windowId): bool" in close
assert "ConfirmationService.currentRequest" in close
assert "(ConfirmationService.queue ?? []).some" in close
assert "if (root._hasPendingAbyssRequest(windowId))" in close
assert "sourceWindowObserved:" in close
assert "sourceWindowRevision: root._windowListRevision" in close
assert "snapshot._observedInWindowList = true" in close
assert "property int _windowListRevision: 0" in close
assert "function _cancelIfTargetGone(): void" in close
gone=close.split("function _cancelIfTargetGone(): void",1)[1].split("Connections {",1)[0]
assert "root._standaloneTransferredRequestId === requestId" in gone
assert "!ConfirmationService.requestVisible && !transferred" in gone
assert "if (!observed && root._windowListRevision <= requestRevision)" in gone
assert "if (transferred)" in gone
assert "ConfirmationService.cancelPresentationHandoff(" in gone
assert "requestId, true" in gone
assert "if (!ConfirmationService.cancelPresentationHandoff(" in gone
assert "root._clearStandaloneState()" in gone
assert "ConfirmationService.cancel()" in gone
assert "root._windowListRevision += 1" in close
assert "NiriService.windowListReady" in close
assert "Number(candidate?.id ?? 0) === windowId" in close
assert "function onWindowsChanged(): void" in close
assert "function onRequestActivated(requestId): void" in close
activated=close.split("function onRequestActivated(requestId): void",1)[1].split("}",1)[0]
assert "root._cancelIfTargetGone()" in activated
assert "root._releaseAbyssRequestIfUnavailable()" in activated
assert "function _snapshotWindow(win): var" in close
assert "NiriService.windows ?? []" in close
assert "function _outputNameForWindow(win): string" in close
assert "NiriService.workspaces?.[win?.workspace_id]" in close
assert "outputName: outputName" in close
assert "root.dialogScreen = root._screenForOutput(outputName)" in close
assert "callback: () => root.closeWindowFast(snapshot)" in close
assert 'Quickshell.execDetached(["niri", "msg", "action", "close-window"' in close
assert 'Config.options?.panelFamily === "abyss"' in close
assert "readonly property bool abyssConfigured:" in close
assert "function _abyssPresenterAvailableFor(outputName): bool" in close
assert "AbyssPromptHostRegistry.hasOutput" in close
assert "property int _standaloneTransferredRequestId: 0" in close
assert "function _showStandaloneForRequest(request): void" in close
show_transfer=close.split("function _showStandaloneForRequest(request): void",1)[1].split("function _clearStandaloneState",1)[0]
assert "ConfirmationService.beginPresentationHandoff(requestId)" in show_transfer
assert "root._standaloneTransferredRequestId = requestId" in show_transfer
assert "root.dialogVisible = true" in close
assert "function _clearStandaloneState(): void" in close
assert "function _releaseAbyssRequestIfUnavailable(): void" in close
release=close.split("function _releaseAbyssRequestIfUnavailable(): void",1)[1].split("onAbyssConfiguredChanged",1)[0]
assert "ConfirmationService.requestVisible" in release
assert "root._showStandaloneForRequest(request)" in release
assert "root._standaloneTransferredRequestId === requestId" in release
assert "ConfirmationService.cancel(true)" not in release
assert "requestResolved" not in release
assert 'ConfirmationService.cancelOwned("closeConfirm")' not in release
assert "return" in release
assert "ConfirmationService.finishPresentation(requestId)" not in release
confirm_block=close.split("function confirmClose(): void",1)[1].split("function cancel(): void",1)[0]
assert 'ConfirmationService.resolvePresentationHandoff(' in confirm_block
assert 'requestId, "close"' in confirm_block
assert "if (!ConfirmationService.resolvePresentationHandoff(" in confirm_block
assert "closeWindowFast(targetWindow)" in confirm_block
cancel_block=close.split("function cancel(): void",1)[1].split("// Dialog UI",1)[0]
assert "ConfirmationService.cancelPresentationHandoff(" in cancel_block
assert "requestId, false" in cancel_block
assert "&& !ConfirmationService.cancelPresentationHandoff(" in cancel_block
assert "onAbyssConfiguredChanged:" in close
assert "target: AbyssPromptHostRegistry" in close
assert "function onEntriesChanged(): void" in close
assert "target: Quickshell" in close
screens=close.split("target: Quickshell",1)[1].split("function _snapshotWindow",1)[0]
assert "function onScreensChanged(): void" in screens
assert "root.dialogVisible" in screens
assert "ConfirmationService.targetOutputName" in screens
assert "root.dialogScreen = root._screenForOutput(requested)" in screens
assert "if (root.abyssConfigured)" in close
process=close.split("function processWindow(win): void",1)[1].split("function _cancelIfTargetGone",1)[0]
assert "ConfirmationService.enqueue({" in process
assert "root._abyssPresenterAvailableFor(outputName)" not in process
assert "if (root.dialogVisible)" in process
assert "root.targetWindow = snapshot;" in process
assert "active: root.dialogVisible" in close

# Queue content remains latched until the popup visual tail is gone.
assert "function cancelOwned(owner): void" in service
assert "function finishPresentation(requestId): void" in service
assert "root.currentRequest = null" in service
assert "Qt.callLater(root._activateNext)" in service

print("Abyss confirmation popup contract: ok")
