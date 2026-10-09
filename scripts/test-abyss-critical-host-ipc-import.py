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
assert "GlobalStates.deferredPanelsReady" in critical, (
    "AbyssPerimeter cannot mount during Config.ready before deferred shell readiness"
)
assert "property bool perimeterInitialMountReady: false" in critical
assert "interval: 150" in critical
assert "&& !root.perimeterInitialMountReady" in critical
assert "onTriggered: root.perimeterInitialMountReady = true" in critical
assert "&& root.perimeterInitialMountReady" in critical
assert "&& !root.diagnosticPerimeterUnmounted" in critical
assert "source: \"../AbyssPerimeter.qml\"" in critical
assert "import qs.services" in imports
assert "property bool coldPerimeterRecreated: false" in critical
assert "root.nativeFirstFramesReady" in critical
assert "GlobalStates.abyssColdPerimeterRecreatePending" in critical
assert "perimeterProbeRestore.restart()" in critical
assert "GlobalStates.abyssColdPerimeterRecreatePending = false" in critical
perimeter = (root / "modules/abyss/AbyssPerimeter.qml").read_text()
assert "readonly property bool nativeInputFramesReady:" in perimeter
assert "readonly property bool nativeFieldReady: field.ready" in perimeter
shell = (root / "shell.qml").read_text()
assert 'root.activePanelFamily === "abyss" && !!Quickshell.env("NIRI_SOCKET")' in shell
assert "GlobalStates.abyssColdPerimeterRecreatePending = false" in shell
states = (root / "GlobalStates.qml").read_text()
assert "property bool abyssColdPerimeterRecreatePending: false" in states
print("PASS: critical host IO imports and post-first-frame Niri cold native remount")
