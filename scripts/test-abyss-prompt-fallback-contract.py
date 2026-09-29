#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
close=(r/"modules/closeConfirm/CloseConfirm.qml").read_text()
perimeter=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
host_registry=(r/"services/AbyssPromptHostRegistry.qml").read_text()
qmdir=(r/"services/qmldir").read_text()
assert "readonly property bool abyssConfigured:" in close
assert 'Config.options?.panelFamily === "abyss"' in close
assert 'includes("abyssPerimeter")' in close
assert "function _abyssPresenterAvailableFor(outputName): bool" in close
assert "AbyssPromptHostRegistry.hasOutput" in close
process=close.split("function processWindow(win): void",1)[1].split("function _cancelIfTargetGone",1)[0]
assert "if (root.abyssConfigured)" in process
assert "ConfirmationService.enqueue({" in process
assert "root._abyssPresenterAvailableFor(outputName)" not in process
assert "property int _standaloneTransferredRequestId: 0" in close
assert "function _showStandaloneForRequest(request): void" in close
assert "cached ?? {" in close
assert "root._standaloneTransferredRequestId = requestId" in close
assert "root.dialogVisible = true" in close
assert "function _clearStandaloneState(): void" in close
assert "ConfirmationService.beginPresentationHandoff(requestId)" in close
assert "ConfirmationService.resolvePresentationHandoff(" in close
assert "ConfirmationService.cancelPresentationHandoff(" in close
assert "target: AbyssPromptHostRegistry" in close
assert "active: root.dialogVisible" in close
assert 'active: root.dialogVisible && Config.options?.panelFamily !== "abyss"' not in close
assert "singleton AbyssPromptHostRegistry 1.0 AbyssPromptHostRegistry.qml" in qmdir
assert "function registerHost(item, outputName): void" in host_registry
assert "const existing = root.entries.find" in host_registry
assert 'String(existing?.outputName ?? "") === name' in host_registry
assert "function unregisterHost(item): void" in host_registry
assert "function hasOutput(outputName): bool" in host_registry
assert "function syncPromptHostRegistration(): void" in perimeter
assert "if (field.ready)" in perimeter
assert "AbyssPromptHostRegistry.registerHost(window, window.outputName)" in perimeter
assert "AbyssPromptHostRegistry.unregisterHost(window)" in perimeter
assert "onReadyChanged: window.syncPromptHostRegistration()" in perimeter
print("Abyss confirmation renderer fallback contract: ok")
