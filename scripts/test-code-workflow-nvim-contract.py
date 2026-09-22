#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "services" / "CodeWorkflowNvim.qml"
BRIDGE = ROOT / "scripts" / "code-workflow-nvim-bridge.py"

def fail(message):
    print("FAIL:", message)
    raise SystemExit(1)

service = SERVICE.read_text(encoding="utf-8")
bridge = BRIDGE.read_text(encoding="utf-8")

for token in (
    "pragma Singleton",
    "stdinEnabled: true",
    "stdout: SplitParser {",
    "nvimBridgeProcess.write(JSON.stringify(payload) + \"\\n\")",
    "function start(targetPath: string, nextCols: int, nextRows: int): bool",
    "property string pendingPath: \"\"",
    "function open(targetPath: string): bool",
    "root.pendingPath = requestedPath",
    "if (root.path === requestedPath || root.pendingPath === requestedPath)",
    "function resize(nextCols: int, nextRows: int): bool",
    "function input(keys: string): bool",
    "function save(): bool",
    "function paste(text: string): bool",
    "property bool cursorVisible: true",
    "property var cursorStyle: ({})",
    "function mouse(",
    "function stop(): void",
    'Quickshell.shellPath("scripts/code-workflow-nvim-bridge.py")',
    'op: "open"',
    'op: "resize"',
    'op: "input"',
    'op: "save"',
    'op: "paste"',
    'op: "mouse"',
):
    if token not in service:
        fail("CodeWorkflowNvim service missing " + token)

for token in (
    'self.request("nvim_ui_attach"',
    '{"rgb": True, "ext_linegrid": True}',
    'if method != "redraw"',
    'name == "grid_line"',
    'name == "grid_scroll"',
    'name == "grid_cursor_goto"',
    'name == "hl_attr_define"',
    'name == "default_colors_set"',
    'name == "mode_info_set"',
    'name == "busy_start"',
    'name == "busy_stop"',
    'name == "mouse_on"',
    'name == "mouse_off"',
    '"nvim_input_mouse"',
    '"nvim_paste"',
    "self.pending_open: dict[int, Path]",
    'if tag == "open":',
    "self.pending_open[msgid] = target",
    '"type": "frame"',
):
    if token not in bridge:
        fail("Neovim bridge missing " + token)

if "pynvim" in bridge or "import msgpack" in bridge:
    fail("Neovim bridge must remain dependency-free")

print("ok - Code Workflow Neovim service/bridge contract")
