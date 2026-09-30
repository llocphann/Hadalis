#!/usr/bin/env python3
from pathlib import Path
t=(Path(__file__).resolve().parents[1]/"modules/bar/DistroIcon.qml").read_text()
for n in ['text: "waves"',"interval: 2800","AbyssStyle.motionEnabled",
          "Surface Performance: %1","Wave Preset: %2",
          "Config.options?.abyss?.waves?.preset"]:
    assert n in t,n
print("abyss launcher rotating status mark contract: ok")
