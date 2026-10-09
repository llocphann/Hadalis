#!/usr/bin/env python3
"""Guard Abyss cold-start critical host QML imports.

Regression for 2026-10-09 owner boot failure:
ShellAbyssCriticalPanels.qml: IpcHandler is not a type
The critical host must import Quickshell.Io whenever it instantiates IpcHandler.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
critical = (root / "modules/abyss/critical/ShellAbyssCriticalPanels.qml").read_text()
imports = [line.strip() for line in critical.splitlines()
           if line.lstrip().startswith("import ")]
assert "IpcHandler {" in critical, "critical-host IPC diagnostic contract changed"
assert "import Quickshell.Io" in imports, (
    "Abyss critical host declares IpcHandler without Quickshell.Io; "
    "this blocks Abyss startup (IpcHandler is not a type)"
)
assert "import Quickshell" in imports
print("PASS: Abyss critical host resolves IpcHandler via Quickshell.Io")
