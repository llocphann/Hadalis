#!/usr/bin/env python3
from pathlib import Path

r=Path(__file__).resolve().parents[1]
close=(r/"modules/closeConfirm/CloseConfirm.qml").read_text()
polkit=(r/"modules/polkit/Polkit.qml").read_text()

# closeConfirm only sets dialogVisible on its non-connected fallback path. The
# renderer must therefore remain available even when the selected family is
# Abyss but abyssPerimeter itself is disabled.
assert "readonly property bool abyssPresenterAvailable:" in close
assert 'Config.options?.panelFamily === "abyss"' in close
assert 'includes("abyssPerimeter")' in close
assert "active: root.dialogVisible" in close
assert 'active: root.dialogVisible && Config.options?.panelFamily !== "abyss"' not in close

# Polkit is security-sensitive: if the connected perimeter is absent, the
# existing real AuthFlow renderer remains available rather than silently
# swallowing an authentication request.
assert "PolkitService.available && PolkitService.active" in polkit
assert 'Config.options?.panelFamily !== "abyss"' in polkit
assert '!(Config.options?.enabledPanels ?? []).includes("abyssPerimeter")' in polkit

print("Abyss prompt renderer fallback contract: ok")
