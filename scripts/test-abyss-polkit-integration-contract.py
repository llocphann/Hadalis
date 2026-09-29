#!/usr/bin/env python3
from pathlib import Path

r=Path(__file__).resolve().parents[1]
per=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
legacy=(r/"modules/polkit/Polkit.qml").read_text()
critical=(r/"modules/abyss/critical/ShellAbyssCriticalPanels.qml").read_text()
deferred=(r/"modules/abyss/ShellAbyssPanelsImpl.qml").read_text()
confirm=(r/"modules/abyss/AbyssConfirmationPresenter.qml").read_text()

assert "PolkitService.available && PolkitService.active" in legacy
assert "!PolkitService.abyssPresentationSuppressed" in legacy
assert "!PolkitService.abyssPresenterAvailable" in legacy
assert "readonly property var presentationScreens:" in legacy
assert 'Config.options?.panelFamily !== "abyss"' in legacy
assert "PolkitService.targetOutputName" in legacy
assert "String(screen?.name ?? \"\") === target" in legacy
assert "model: root.presentationScreens" in legacy
assert 'Config.options?.panelFamily !== "abyss"' not in legacy
assert '!(Config.options?.enabledPanels ?? []).includes("abyssPerimeter")' not in legacy
assert 'source: "../../polkit/Polkit.qml"' in critical
assert 'Config.options?.modules?.polkit ?? true' in critical
assert 'source: "../polkit/Polkit.qml"' not in deferred

assert "id: promptFallbackAnchor" in per
assert 'property var liquidController: liquid' in per
assert 'property string attachedEdge: "top"' in per
assert "x: (window.width - width) / 2" in per
assert "AbyssConfirmationPresenter {" in per
assert "AbyssPolkitPresenter {" in per
assert "fallbackAnchor: promptFallbackAnchor" in per

focus_line=next(line for line in per.splitlines()
    if "WlrLayershell.keyboardFocus:" in line)
assert "PolkitService.active" not in focus_line
layer_line=next(line for line in per.splitlines()
    if "WlrLayershell.layer:" in line)
assert "PolkitService.active ? WlrLayer.Top" not in layer_line

# Other interactive surfaces stay blocked while auth is active.
assert "&& !PolkitService.active && !GlobalStates.regionSelectorOpen" in per
assert "|| GlobalStates.settingsNativeDialogOpen || PolkitService.active || GlobalStates.regionSelectorOpen" in per

# Authentication owns focus priority; a normal confirmation pauses and can
# reverse/reopen through its existing StyledPopup motion after Polkit completes.
assert "&& !PolkitService.active" in confirm

print("Abyss Polkit perimeter integration contract: ok")
