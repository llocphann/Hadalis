#!/usr/bin/env python3
from pathlib import Path
t=(Path(__file__).resolve().parents[1]/"modules/dashboard/DashboardCanvas.qml").read_text()
for needle in [
    "preferredWidth:320, maxWidth:370",
    "preferredWidth:420, maxWidth:510",
    "preferredWidth:520, maxWidth:640",
    "preferredHeights:{media:455,weather:245}",
    'growPriority:["calendar","todo","notifications","agenda"]',
    "Preserve breathing room on tall dashboards",
    "const growOrder=[2,1,0]",
]:
    assert needle in t, needle
assert "extraHeight * (weights[index] / weightTotal)" not in t
print("dashboard content-aware add-all contract: ok")
