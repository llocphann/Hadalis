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
assert "function finishIfReleased(): void" in presenter
assert "onRequestVisibleChanged" in presenter
assert "ConfirmationService.finishPresentation(root.requestId)" in presenter

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
assert "visible: modelData?.visible !== false" in content
assert "enabled: modelData?.enabled !== false" in content
assert "function _actionUsable(action): bool" in service
assert "if (!root._actionUsable(action))" in service
assert "root._actionUsable(action)" in service
assert "function cancelAction(): var" in service
assert "if (!root._actionUsable(cancelAction))" in service
for forbidden in ("NumberAnimation", "ScaleAnimator", "OpacityAnimator"):
    assert forbidden not in content
    assert forbidden not in presenter

# Existing closeConfirm backend provides the real action callback.
assert 'owner: "closeConfirm"' in close
assert "ConfirmationService.enqueue({" in close
assert "function _snapshotWindow(win): var" in close
assert "NiriService.windows ?? []" in close
assert "function _outputNameForWindow(win): string" in close
assert "NiriService.workspaces?.[win?.workspace_id]" in close
assert "outputName: outputName" in close
assert "root.dialogScreen = root._screenForOutput(outputName)" in close
assert "callback: () => root.closeWindowFast(snapshot)" in close
assert 'Quickshell.execDetached(["niri", "msg", "action", "close-window"' in close
assert 'Config.options?.panelFamily === "abyss"' in close
assert "active: root.dialogVisible" in close

# Queue content remains latched until the popup visual tail is gone.
assert "function cancelOwned(owner): void" in service
assert "function finishPresentation(requestId): void" in service
assert "root.currentRequest = null" in service
assert "Qt.callLater(root._activateNext)" in service

print("Abyss confirmation popup contract: ok")
