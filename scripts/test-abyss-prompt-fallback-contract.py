#!/usr/bin/env python3
from pathlib import Path

r=Path(__file__).resolve().parents[1]
close=(r/"modules/closeConfirm/CloseConfirm.qml").read_text()
polkit=(r/"modules/polkit/Polkit.qml").read_text()
critical=(r/"modules/abyss/critical/ShellAbyssCriticalPanels.qml").read_text()
deferred=(r/"modules/abyss/ShellAbyssPanelsImpl.qml").read_text()
perimeter=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
host_registry=(r/"services/AbyssPromptHostRegistry.qml").read_text()
qmdir=(r/"services/qmldir").read_text()

# closeConfirm only sets dialogVisible on its non-connected fallback path. The
# renderer must therefore remain available even when the selected family is
# Abyss but abyssPerimeter itself is disabled.
assert "readonly property bool abyssConfigured:" in close
assert 'Config.options?.panelFamily === "abyss"' in close
assert 'includes("abyssPerimeter")' in close
assert "function _abyssPresenterAvailableFor(outputName): bool" in close
assert "AbyssPromptHostRegistry.hasOutput" in close
assert "target: AbyssPromptHostRegistry" in close
assert "active: root.dialogVisible" in close
assert 'active: root.dialogVisible && Config.options?.panelFamily !== "abyss"' not in close

# Polkit is security-sensitive: if the connected perimeter is absent, the
# existing real AuthFlow renderer remains available rather than silently
# swallowing an authentication request.
assert "PolkitService.available && PolkitService.active" in polkit
assert "!PolkitService.abyssPresenterAvailable" in polkit
assert 'Config.options?.panelFamily !== "abyss"' not in polkit
assert '!(Config.options?.enabledPanels ?? []).includes("abyssPerimeter")' not in polkit
assert 'source: "../../polkit/Polkit.qml"' in critical
assert 'Config.options?.modules?.polkit ?? true' in critical
assert 'source: "../polkit/Polkit.qml"' not in deferred

# Renderer availability is runtime-observed, not inferred only from config.
assert "singleton AbyssPromptHostRegistry 1.0 AbyssPromptHostRegistry.qml" in qmdir
assert "function registerHost(item, outputName): void" in host_registry
assert "function unregisterHost(item): void" in host_registry
assert "function hasOutput(outputName): bool" in host_registry
assert "AbyssPromptHostRegistry.registerHost(window, window.outputName)" in perimeter
assert "AbyssPromptHostRegistry.unregisterHost(window)" in perimeter

print("Abyss prompt renderer fallback contract: ok")
