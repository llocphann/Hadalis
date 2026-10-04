#!/usr/bin/env python3
from pathlib import Path
t=(Path(__file__).resolve().parents[1]/"modules/bar/DistroIcon.qml").read_text()
for n in ['text: "waves"',"interval: 2800","AbyssStyle.motionEnabled",
          "root.abyssControlsHoverChanged(hovered)"]:
    assert n in t,n
print("abyss launcher rotating status mark contract: ok")

controls=(Path(__file__).resolve().parents[1]/"modules/abyss/content/AbyssLauncherControlsPopup.qml").read_text()
assert 'Translation.tr("Surface Performance")' in controls
assert 'Translation.tr("Wave Preset")' in controls
assert "Config.options?.abyss?.waves?.preset" in controls
