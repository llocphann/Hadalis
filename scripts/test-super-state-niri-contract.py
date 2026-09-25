#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DAEMON = (ROOT / "scripts/daemon/inir_super_overview_daemon.py").read_text(encoding="utf-8")
SHELL = (ROOT / "shell.qml").read_text(encoding="utf-8")
BAR = (ROOT / "modules/bar/Bar.qml").read_text(encoding="utf-8")
WORKSPACES = (ROOT / "modules/bar/Workspaces.qml").read_text(encoding="utf-8")

def require(text: str, token: str, message: str) -> None:
    if token not in text:
        raise SystemExit(f"super-state contract failed: {message}")

require(DAEMON, 'notify_shell_super_state(True)',
        "Super key-down must reach the shell")
require(DAEMON, 'notify_shell_super_state(False)',
        "Super key-up/device loss must reach the shell")
require(DAEMON, 'run_inir_command("ipc", "overview", function)',
        "daemon must use the existing Niri shell IPC transport")
require(DAEMON, 'super_down_devices = set()',
        "multi-device Super state must not collapse to a single-device boolean")

require(SHELL, 'function superPress(): void {',
        "overview IPC must expose Super press")
require(SHELL, 'GlobalStates.superDown = true',
        "Super press must restore the shared hold state")
require(SHELL, 'function superRelease(): void {',
        "overview IPC must expose Super release")
require(SHELL, 'GlobalStates.superDown = false',
        "Super release must clear the shared hold state")

require(BAR, 'function onSuperDownChanged()',
        "Bar auto-show must remain driven by shared Super state")
require(WORKSPACES, 'function onSuperDownChanged()',
        "workspace-number reveal must remain driven by shared Super state")

for forbidden in ("Quickshell.Hyprland", "HyprlandFocusGrab", "hyprctl"):
    if forbidden in DAEMON or forbidden in SHELL:
        raise SystemExit(
            f"super-state contract failed: retired compositor backend returned: {forbidden}"
        )

print("super-state Niri contract: ok")
