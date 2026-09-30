#!/usr/bin/env python3
from pathlib import Path
t=(Path(__file__).resolve().parents[1]/"modules/dashboard/DashboardCanvas.qml").read_text()
for n in [
    "preferredWidth:360, maxWidth:420",
    "github:150,notes:280",
    "notifications:200,agenda:150,todo:220,calendar:220",
    'growPriority:["notifications","todo","agenda","calendar"]',
    "preferredWidth:400, maxWidth:460",
    "preferredHeights:{media:330,weather:250}",
    "const growOrder=[1,0,2]",
]:
    assert n in t,n
assert "preferredWidth:520, maxWidth:640" not in t
print("dashboard prioritized content-aware add-all contract: ok")
