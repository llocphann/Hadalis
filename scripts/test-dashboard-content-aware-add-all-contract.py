#!/usr/bin/env python3
from pathlib import Path
t=(Path(__file__).resolve().parents[1]/"modules/dashboard/DashboardCanvas.qml").read_text()
for needle in [
    "preferredWidth:360, maxWidth:420",
    "preferredWidth:430, maxWidth:500",
    "preferredWidth:400, maxWidth:460",
    "preferredHeights:{media:330,weather:250}",
    'growPriority:["notifications","todo","agenda","calendar"]',
    "Preserve breathing room on tall dashboards",
    "const growOrder=[1,0,2]",
]:
    assert needle in t, needle
assert "extraHeight * (weights[index] / weightTotal)" not in t
print("dashboard content-aware add-all contract: ok")
