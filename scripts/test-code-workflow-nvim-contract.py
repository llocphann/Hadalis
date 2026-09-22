#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "services" / "CodeWorkflowNvim.qml"
BRIDGE = ROOT / "scripts" / "code-workflow-nvim-bridge.py"
SERVICES_QMLDIR = ROOT / "services" / "qmldir"
SETTINGS_QMLDIR = ROOT / "modules" / "settings" / "qmldir"

def fail(message):
    print("FAIL:", message)
    raise SystemExit(1)

service = SERVICE.read_text(encoding="utf-8")
bridge = BRIDGE.read_text(encoding="utf-8")
services_qmldir = SERVICES_QMLDIR.read_text(encoding="utf-8")
settings_qmldir = SETTINGS_QMLDIR.read_text(encoding="utf-8")

for token in (
    "pragma Singleton",
    "stdinEnabled: true",
    "stdout: SplitParser {",
    "nvimBridgeProcess.write(JSON.stringify(payload) + \"\\n\")",
    "function start(targetPath: string, nextCols: int, nextRows: int): bool",
    "property string pendingPath: \"\"",
    "property bool bufferModified: false",
    'if (type === "buffer")',
    "root.bufferModified = message?.modified === true",
    "if (root.bufferModified)",
    '"Modified Neovim buffer · save before switching source"',
    "function open(targetPath: string): bool",
    "root.pendingPath = requestedPath",
    "if (root.path === requestedPath || root.pendingPath === requestedPath)",
    "function resize(nextCols: int, nextRows: int): bool",
    "function input(keys: string): bool",
    "function save(): bool",
    "function paste(text: string): bool",
    "property bool cursorVisible: true",
    "property var cursorStyle: ({})",
    "property var lastDirtyRows: []",
    "property bool fullRepaintRequested: true",
    "const dirtyRowIndexes = []",
    "root.lastDirtyRows = dirtyRowIndexes",
    "const nextCursorStyle =",
    "JSON.stringify(nextCursorStyle)",
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
    "batch = params",
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
    "def install_buffer_watch(self, channel_id: int) -> None:",
    '"hadalis_buffer_state"',
    '"OptionSet"',
    'pattern = "modified"',
    '"nvim_get_api_info"',
    'if tag == "open":',
    "self.pending_open[msgid] = target",
    '"type": "frame"',
):
    if token not in bridge:
        fail("Neovim bridge missing " + token)

if "singleton CodeWorkflowNvim 1.0 CodeWorkflowNvim.qml" not in services_qmldir:
    fail("CodeWorkflowNvim singleton must be exported by qs.services")
if "CodeWorkflowNvimView 1.0 CodeWorkflowNvimView.qml" not in settings_qmldir:
    fail("CodeWorkflowNvimView must be exported by qs.modules.settings")

if "pynvim" in bridge or "import msgpack" in bridge:
    fail("Neovim bridge must remain dependency-free")

print("ok - Code Workflow Neovim service/bridge contract")

if "batch = params[0]" in bridge:
    fail("Neovim redraw batch must not be unwrapped; RPC params already are the update batch")
