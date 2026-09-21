#!/usr/bin/env python3
"""Static/runtime-unit tests for the dependency-free Neovim embed bridge."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile


ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / "scripts" / "code-workflow-nvim-bridge.py"
spec = importlib.util.spec_from_file_location("hadalis_nvim_bridge", BRIDGE)
assert spec and spec.loader
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


values = [
    None, True, False, 0, 127, 128, -1, -33, 65535, 2**40,
    1.5, "hello", "λ", b"\x00\xff",
    [1, "x", False],
    {"a": 1, "nested": [2, 3]},
    mod.Ext(2, b"abcd"),
]
for value in values:
    encoded = mod.pack(value)
    decoded, offset = mod.unpack_one(encoded)
    assert offset == len(encoded), (value, offset, len(encoded))
    assert decoded == value, (value, decoded)

decoder = mod.StreamDecoder()
payload = mod.pack([2, "redraw", [[["flush"]]]])
assert decoder.feed(payload[:2]) == []
assert decoder.feed(payload[2:5]) == []
assert decoder.feed(payload[5:]) == [[2, "redraw", [[["flush"]]]]]

ui = mod.UiState(6, 4)
ui.event("default_colors_set", [0xEEEEEE, 0x111111, 0xFF0000, 0, 0])
ui.event("hl_attr_define", [7, {"foreground": 0x00FF00, "bold": True}, {}, []])
ui.event("grid_line", [1, 1, 0, [["a", 7], ["b"], [" ", 0, 2]], False])
ui.event("grid_cursor_goto", [1, 1, 2])
ui.event("mode_change", ["insert", 0])
assert ui.event("flush", [])
frame = ui.frame()
assert frame is not None
assert frame["cursorRow"] == 1 and frame["cursorCol"] == 2
assert frame["mode"] == "insert"
row1 = next(row for row in frame["dirtyRows"] if row["row"] == 1)
assert row1["cells"][:4] == [["a", 7], ["b", 7], [" ", 0], [" ", 0]]
assert frame["highlights"]["7"]["foreground"] == 0x00FF00

# Cursor/mode-only flushes still need a frame even when no cells changed.
ui.event("grid_cursor_goto", [1, 2, 4])
ui.event("mode_change", ["normal", 0])
assert ui.event("flush", [])
meta_frame = ui.frame()
assert meta_frame is not None
assert meta_frame["dirtyRows"] == []
assert meta_frame["cursorRow"] == 2 and meta_frame["cursorCol"] == 4
assert meta_frame["mode"] == "normal"

# No-argument redraw events must still be dispatched by the batched protocol.
bridge_ui = mod.UiState(6, 4)
batch = [["mouse_on"], ["flush"]]
flush_seen = False
for packed_event in batch:
    name = str(packed_event[0])
    calls = packed_event[1:] or (
        [[]] if name in ("flush", "mouse_on", "mouse_off") else [])
    for args in calls:
        flush_seen = bridge_ui.event(name, args) or flush_seen
assert flush_seen is True
assert bridge_ui.frame()["mouseEnabled"] is True

ui.event("mouse_on", [])
assert ui.event("flush", [])
mouse_frame = ui.frame()
assert mouse_frame is not None and mouse_frame["mouseEnabled"] is True
ui.event("mouse_off", [])
assert ui.event("flush", [])
assert ui.frame()["mouseEnabled"] is False

# Positive row scroll copies cells upward inside the end-exclusive region.
ui = mod.UiState(3, 4)
for row, char in enumerate(("a", "b", "c", "d")):
    ui.line(row, 0, [[char, row + 1, 3]])
ui.scroll(0, 4, 0, 3, 1, 0)
assert [ui.grid[r][0][0] for r in range(3)] == ["b", "c", "d"]

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp) / "shell"
    root.mkdir()
    inside = root / "Widget.qml"
    inside.write_text("Item {}\n", encoding="utf-8")
    assert mod.safe_target(root, str(inside)) == inside.resolve()

    outside = Path(tmp) / "outside.qml"
    outside.write_text("Item {}\n", encoding="utf-8")
    try:
        mod.safe_target(root, str(outside))
    except ValueError as exc:
        assert str(exc) == "target-outside-shell-root"
    else:
        raise AssertionError("outside path was accepted")

print("ok - Code Workflow Neovim embed bridge codec/grid contract")
