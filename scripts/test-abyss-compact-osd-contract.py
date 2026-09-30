#!/usr/bin/env python3
from pathlib import Path

r = Path(__file__).resolve().parents[1]
content = (r / "modules/abyss/content/AbyssOsdContent.qml").read_text()
ctrl = (r / "modules/abyss/AbyssOsdController.qml").read_text()

assert 'if (GlobalStates.osdVolumeOpen) kinds.push("volume")' in content
assert 'if (GlobalStates.osdBrightnessOpen) kinds.push("brightness")' in content
assert 'if (GlobalStates.osdMicOpen) kinds.push("mic")' in content
assert 'if (GlobalStates.osdKeyboardLayoutOpen) kinds.push("keyboardLayout")' in content
assert "RowLayout" in content and "spacing: 10" in content
assert 'const compact=["volume","brightness","mic","keyboardLayout"]' in ctrl
assert "Keep already-active compact" in ctrl
print("concurrent compact Abyss OSD contract: ok")
