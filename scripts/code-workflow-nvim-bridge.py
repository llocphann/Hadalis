#!/usr/bin/env python3
"""Neovim --embed bridge for Hadalis Code Workflow.

Transport:
  QML -> bridge stdin: newline-delimited JSON commands
  bridge -> QML stdout: newline-delimited JSON state/frame messages
  bridge <-> Neovim: MessagePack-RPC over the embedded process stdio

The bridge intentionally owns MessagePack so Hadalis does not need pynvim or
python-msgpack as a runtime dependency.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import selectors
import signal
import struct
import subprocess
import sys
from typing import Any


class NeedMoreData(Exception):
    pass


class Ext:
    __slots__ = ("type", "data")

    def __init__(self, type_: int, data: bytes):
        self.type = int(type_)
        self.data = bytes(data)

    def __eq__(self, other: object) -> bool:
        return isinstance(other, Ext) and self.type == other.type and self.data == other.data


def _need(data: bytes | bytearray, offset: int, count: int) -> None:
    if len(data) - offset < count:
        raise NeedMoreData()


def unpack_one(data: bytes | bytearray, offset: int = 0) -> tuple[Any, int]:
    _need(data, offset, 1)
    lead = data[offset]
    offset += 1

    if lead <= 0x7F:
        return lead, offset
    if lead >= 0xE0:
        return lead - 0x100, offset
    if 0x80 <= lead <= 0x8F:
        count = lead & 0x0F
        out: dict[Any, Any] = {}
        for _ in range(count):
            key, offset = unpack_one(data, offset)
            value, offset = unpack_one(data, offset)
            out[key] = value
        return out, offset
    if 0x90 <= lead <= 0x9F:
        count = lead & 0x0F
        out = []
        for _ in range(count):
            value, offset = unpack_one(data, offset)
            out.append(value)
        return out, offset
    if 0xA0 <= lead <= 0xBF:
        count = lead & 0x1F
        _need(data, offset, count)
        raw = bytes(data[offset:offset + count])
        return raw.decode("utf-8", "replace"), offset + count

    if lead == 0xC0:
        return None, offset
    if lead == 0xC2:
        return False, offset
    if lead == 0xC3:
        return True, offset
    if lead in (0xC4, 0xC5, 0xC6):
        sizes = {0xC4: (1, ">B"), 0xC5: (2, ">H"), 0xC6: (4, ">I")}
        size_len, fmt = sizes[lead]
        _need(data, offset, size_len)
        count = struct.unpack_from(fmt, data, offset)[0]
        offset += size_len
        _need(data, offset, count)
        return bytes(data[offset:offset + count]), offset + count
    if lead in (0xC7, 0xC8, 0xC9):
        sizes = {0xC7: (1, ">B"), 0xC8: (2, ">H"), 0xC9: (4, ">I")}
        size_len, fmt = sizes[lead]
        _need(data, offset, size_len + 1)
        count = struct.unpack_from(fmt, data, offset)[0]
        offset += size_len
        ext_type = struct.unpack_from(">b", data, offset)[0]
        offset += 1
        _need(data, offset, count)
        return Ext(ext_type, bytes(data[offset:offset + count])), offset + count
    if lead == 0xCA:
        _need(data, offset, 4)
        return struct.unpack_from(">f", data, offset)[0], offset + 4
    if lead == 0xCB:
        _need(data, offset, 8)
        return struct.unpack_from(">d", data, offset)[0], offset + 8
    if lead in (0xCC, 0xCD, 0xCE, 0xCF, 0xD0, 0xD1, 0xD2, 0xD3):
        formats = {
            0xCC: (1, ">B"), 0xCD: (2, ">H"), 0xCE: (4, ">I"), 0xCF: (8, ">Q"),
            0xD0: (1, ">b"), 0xD1: (2, ">h"), 0xD2: (4, ">i"), 0xD3: (8, ">q"),
        }
        size, fmt = formats[lead]
        _need(data, offset, size)
        return struct.unpack_from(fmt, data, offset)[0], offset + size
    if lead in (0xD4, 0xD5, 0xD6, 0xD7, 0xD8):
        sizes = {0xD4: 1, 0xD5: 2, 0xD6: 4, 0xD7: 8, 0xD8: 16}
        count = sizes[lead]
        _need(data, offset, count + 1)
        ext_type = struct.unpack_from(">b", data, offset)[0]
        offset += 1
        return Ext(ext_type, bytes(data[offset:offset + count])), offset + count
    if lead in (0xD9, 0xDA, 0xDB):
        sizes = {0xD9: (1, ">B"), 0xDA: (2, ">H"), 0xDB: (4, ">I")}
        size_len, fmt = sizes[lead]
        _need(data, offset, size_len)
        count = struct.unpack_from(fmt, data, offset)[0]
        offset += size_len
        _need(data, offset, count)
        raw = bytes(data[offset:offset + count])
        return raw.decode("utf-8", "replace"), offset + count
    if lead in (0xDC, 0xDD):
        size_len, fmt = ((2, ">H") if lead == 0xDC else (4, ">I"))
        _need(data, offset, size_len)
        count = struct.unpack_from(fmt, data, offset)[0]
        offset += size_len
        out = []
        for _ in range(count):
            value, offset = unpack_one(data, offset)
            out.append(value)
        return out, offset
    if lead in (0xDE, 0xDF):
        size_len, fmt = ((2, ">H") if lead == 0xDE else (4, ">I"))
        _need(data, offset, size_len)
        count = struct.unpack_from(fmt, data, offset)[0]
        offset += size_len
        out: dict[Any, Any] = {}
        for _ in range(count):
            key, offset = unpack_one(data, offset)
            value, offset = unpack_one(data, offset)
            out[key] = value
        return out, offset

    raise ValueError(f"unsupported MessagePack lead byte 0x{lead:02x}")


def pack(value: Any) -> bytes:
    if value is None:
        return b"\xc0"
    if value is False:
        return b"\xc2"
    if value is True:
        return b"\xc3"
    if isinstance(value, Ext):
        size = len(value.data)
        if size in (1, 2, 4, 8, 16):
            lead = {1: 0xD4, 2: 0xD5, 4: 0xD6, 8: 0xD7, 16: 0xD8}[size]
            return bytes((lead, value.type & 0xFF)) + value.data
        if size <= 0xFF:
            return b"\xc7" + struct.pack(">Bb", size, value.type) + value.data
        if size <= 0xFFFF:
            return b"\xc8" + struct.pack(">Hb", size, value.type) + value.data
        return b"\xc9" + struct.pack(">Ib", size, value.type) + value.data
    if isinstance(value, int):
        if 0 <= value <= 0x7F:
            return bytes((value,))
        if -32 <= value < 0:
            return bytes((value & 0xFF,))
        if 0 <= value <= 0xFF:
            return b"\xcc" + struct.pack(">B", value)
        if 0 <= value <= 0xFFFF:
            return b"\xcd" + struct.pack(">H", value)
        if 0 <= value <= 0xFFFFFFFF:
            return b"\xce" + struct.pack(">I", value)
        if value >= 0:
            return b"\xcf" + struct.pack(">Q", value)
        if -0x80 <= value:
            return b"\xd0" + struct.pack(">b", value)
        if -0x8000 <= value:
            return b"\xd1" + struct.pack(">h", value)
        if -0x80000000 <= value:
            return b"\xd2" + struct.pack(">i", value)
        return b"\xd3" + struct.pack(">q", value)
    if isinstance(value, float):
        return b"\xcb" + struct.pack(">d", value)
    if isinstance(value, str):
        raw = value.encode("utf-8")
        size = len(raw)
        if size <= 31:
            return bytes((0xA0 | size,)) + raw
        if size <= 0xFF:
            return b"\xd9" + struct.pack(">B", size) + raw
        if size <= 0xFFFF:
            return b"\xda" + struct.pack(">H", size) + raw
        return b"\xdb" + struct.pack(">I", size) + raw
    if isinstance(value, (bytes, bytearray)):
        raw = bytes(value)
        size = len(raw)
        if size <= 0xFF:
            return b"\xc4" + struct.pack(">B", size) + raw
        if size <= 0xFFFF:
            return b"\xc5" + struct.pack(">H", size) + raw
        return b"\xc6" + struct.pack(">I", size) + raw
    if isinstance(value, (list, tuple)):
        size = len(value)
        if size <= 15:
            head = bytes((0x90 | size,))
        elif size <= 0xFFFF:
            head = b"\xdc" + struct.pack(">H", size)
        else:
            head = b"\xdd" + struct.pack(">I", size)
        return head + b"".join(pack(item) for item in value)
    if isinstance(value, dict):
        size = len(value)
        if size <= 15:
            head = bytes((0x80 | size,))
        elif size <= 0xFFFF:
            head = b"\xde" + struct.pack(">H", size)
        else:
            head = b"\xdf" + struct.pack(">I", size)
        chunks = [head]
        for key, item in value.items():
            chunks.append(pack(key))
            chunks.append(pack(item))
        return b"".join(chunks)
    raise TypeError(f"cannot MessagePack encode {type(value)!r}")


class StreamDecoder:
    def __init__(self) -> None:
        self.buffer = bytearray()

    def feed(self, chunk: bytes) -> list[Any]:
        self.buffer.extend(chunk)
        out: list[Any] = []
        offset = 0
        while offset < len(self.buffer):
            try:
                value, next_offset = unpack_one(self.buffer, offset)
            except NeedMoreData:
                break
            out.append(value)
            offset = next_offset
        if offset:
            del self.buffer[:offset]
        return out


def _blank_row(width: int) -> list[list[Any]]:
    return [[" ", 0] for _ in range(max(0, width))]


class UiState:
    def __init__(self, cols: int, rows: int) -> None:
        self.cols = max(2, int(cols))
        self.rows = max(2, int(rows))
        self.grid = [_blank_row(self.cols) for _ in range(self.rows)]
        self.cursor_row = 0
        self.cursor_col = 0
        self.mode = "normal"
        self.mode_index = 0
        self.mode_info: list[dict[str, Any]] = []
        self.cursor_style_enabled = False
        self.cursor_visible = True
        self.mouse_enabled = False
        self.default_fg = -1
        self.default_bg = -1
        self.default_sp = -1
        self.highlights: dict[int, dict[str, Any]] = {}
        self.changed_highlights: dict[int, dict[str, Any]] = {}
        self.dirty_rows: set[int] = set(range(self.rows))
        self.defaults_dirty = True
        self.meta_dirty = True
        self.revision = 0

    def resize(self, cols: int, rows: int) -> None:
        cols = max(2, int(cols))
        rows = max(2, int(rows))
        old = self.grid
        new = [_blank_row(cols) for _ in range(rows)]
        for row in range(min(rows, len(old))):
            for col in range(min(cols, len(old[row]))):
                new[row][col] = old[row][col]
        self.cols = cols
        self.rows = rows
        self.grid = new
        self.cursor_row = min(self.cursor_row, rows - 1)
        self.cursor_col = min(self.cursor_col, cols - 1)
        self.dirty_rows.update(range(rows))
        self.meta_dirty = True

    def clear(self) -> None:
        self.grid = [_blank_row(self.cols) for _ in range(self.rows)]
        self.dirty_rows.update(range(self.rows))

    def line(self, row: int, col_start: int, cells: list[Any]) -> None:
        if row < 0 or row >= self.rows:
            return
        col = max(0, int(col_start))
        current_hl = 0
        for item in cells:
            if not isinstance(item, list) or not item:
                continue
            text = str(item[0])
            if len(item) >= 2:
                current_hl = int(item[1])
            repeat = max(1, int(item[2])) if len(item) >= 3 else 1
            for _ in range(repeat):
                if col >= self.cols:
                    break
                self.grid[row][col] = [text, current_hl]
                col += 1
        self.dirty_rows.add(row)

    def scroll(self, top: int, bot: int, left: int, right: int, rows: int, cols: int) -> None:
        top = max(0, int(top))
        bot = min(self.rows, int(bot))
        left = max(0, int(left))
        right = min(self.cols, int(right))
        rows = int(rows)
        cols = int(cols)
        if top >= bot or left >= right or (rows == 0 and cols == 0):
            return

        snapshot = [
            [list(self.grid[r][c]) for c in range(left, right)]
            for r in range(top, bot)
        ]
        for dst_r in range(top, bot):
            for dst_c in range(left, right):
                src_r = dst_r + rows
                src_c = dst_c + cols
                if top <= src_r < bot and left <= src_c < right:
                    self.grid[dst_r][dst_c] = list(
                        snapshot[src_r - top][src_c - left]
                    )
        self.dirty_rows.update(range(top, bot))

    def event(self, name: str, args: list[Any]) -> bool:
        if name == "grid_resize" and len(args) >= 3 and int(args[0]) == 1:
            self.resize(int(args[1]), int(args[2]))
        elif name == "grid_clear" and args and int(args[0]) == 1:
            self.clear()
        elif name == "grid_line" and len(args) >= 5 and int(args[0]) == 1:
            self.line(int(args[1]), int(args[2]), list(args[3]))
        elif name == "grid_scroll" and len(args) >= 7 and int(args[0]) == 1:
            self.scroll(*map(int, args[1:7]))
        elif name == "grid_cursor_goto" and len(args) >= 3 and int(args[0]) == 1:
            self.cursor_row = max(0, min(self.rows - 1, int(args[1])))
            self.cursor_col = max(0, min(self.cols - 1, int(args[2])))
            self.meta_dirty = True
        elif name == "hl_attr_define" and len(args) >= 2:
            hl_id = int(args[0])
            attrs = dict(args[1] or {})
            self.highlights[hl_id] = attrs
            self.changed_highlights[hl_id] = attrs
        elif name == "default_colors_set" and len(args) >= 3:
            self.default_fg = int(args[0])
            self.default_bg = int(args[1])
            self.default_sp = int(args[2])
            self.defaults_dirty = True
        elif name == "mode_info_set" and len(args) >= 2:
            self.cursor_style_enabled = bool(args[0])
            self.mode_info = [
                dict(item or {}) for item in list(args[1] or [])
            ]
            self.meta_dirty = True
        elif name == "mode_change" and args:
            self.mode = str(args[0])
            if len(args) >= 2:
                self.mode_index = max(0, int(args[1]))
            self.meta_dirty = True
        elif name == "busy_start":
            self.cursor_visible = False
            self.meta_dirty = True
        elif name == "busy_stop":
            self.cursor_visible = True
            self.meta_dirty = True
        elif name == "mouse_on":
            self.mouse_enabled = True
            self.meta_dirty = True
        elif name == "mouse_off":
            self.mouse_enabled = False
            self.meta_dirty = True
        return name == "flush"

    def frame(self) -> dict[str, Any] | None:
        if (not self.dirty_rows
                and not self.changed_highlights
                and not self.defaults_dirty
                and not self.meta_dirty):
            return None
        self.revision += 1
        rows = [
            {"row": row, "cells": self.grid[row]}
            for row in sorted(self.dirty_rows)
            if 0 <= row < self.rows
        ]
        cursor_style: dict[str, Any] = {}
        if (self.cursor_style_enabled
                and 0 <= self.mode_index < len(self.mode_info)):
            cursor_style = dict(self.mode_info[self.mode_index] or {})

        frame: dict[str, Any] = {
            "type": "frame",
            "revision": self.revision,
            "cols": self.cols,
            "rows": self.rows,
            "cursorRow": self.cursor_row,
            "cursorCol": self.cursor_col,
            "mode": self.mode,
            "cursorVisible": self.cursor_visible,
            "cursorStyle": cursor_style,
            "mouseEnabled": self.mouse_enabled,
            "dirtyRows": rows,
        }
        if self.changed_highlights:
            frame["highlights"] = {
                str(key): value for key, value in self.changed_highlights.items()
            }
        if self.defaults_dirty:
            frame["defaults"] = {
                "foreground": self.default_fg,
                "background": self.default_bg,
                "special": self.default_sp,
            }
        self.dirty_rows.clear()
        self.changed_highlights.clear()
        self.defaults_dirty = False
        self.meta_dirty = False
        return frame


def emit(payload: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def safe_target(root: Path, raw: str) -> Path:
    target = Path(raw).expanduser().resolve()
    if os.path.commonpath((str(root), str(target))) != str(root):
        raise ValueError("target-outside-shell-root")
    return target


class Bridge:
    def __init__(self, root: Path, target: Path, cols: int, rows: int, nvim: str) -> None:
        self.root = root.resolve()
        self.target = target.resolve()
        self.ui = UiState(cols, rows)
        self.nvim_bin = nvim
        self.nvim: subprocess.Popen[bytes] | None = None
        self.decoder = StreamDecoder()
        self.selector = selectors.DefaultSelector()
        self.next_msgid = 1
        self.pending: dict[int, str] = {}
        self.pending_open: dict[int, Path] = {}
        self.command_buffer = bytearray()
        self.ready = False
        self.stopping = False

    def _rpc(self, message: Any) -> None:
        if not self.nvim or not self.nvim.stdin:
            return
        self.nvim.stdin.write(pack(message))
        self.nvim.stdin.flush()

    def request(self, method: str, params: list[Any], tag: str = "") -> int:
        msgid = self.next_msgid
        self.next_msgid += 1
        self.pending[msgid] = tag or method
        self._rpc([0, msgid, method, params])
        return msgid

    def response(self, msgid: int, error: Any, result: Any) -> None:
        tag = self.pending.pop(msgid, "")
        if error not in (None, False):
            if tag == "open":
                self.pending_open.pop(msgid, None)
            emit({"type": "rpc-error", "request": tag, "error": error})
            if tag == "attach":
                self.stopping = True
            return
        if tag == "open":
            opened = self.pending_open.pop(msgid, None)
            if opened is not None:
                self.target = opened
                emit({
                    "type": "state",
                    "state": "ready",
                    "path": str(opened),
                    "cols": self.ui.cols,
                    "rows": self.ui.rows,
                })
            return
        if tag == "attach":
            self.ready = True
            emit({
                "type": "state",
                "state": "ready",
                "cols": self.ui.cols,
                "rows": self.ui.rows,
                "path": str(self.target),
            })

    def notification(self, method: str, params: list[Any]) -> None:
        if method != "redraw" or not params:
            return
        batch = params[0]
        if not isinstance(batch, list):
            return
        flush_seen = False
        for packed_event in batch:
            if not isinstance(packed_event, list) or not packed_event:
                continue
            name = str(packed_event[0])
            calls = packed_event[1:] or (
                [[]] if name in (
                    "flush", "mouse_on", "mouse_off",
                    "busy_start", "busy_stop") else [])
            for args in calls:
                if not isinstance(args, list):
                    args = []
                flush_seen = self.ui.event(name, args) or flush_seen
        if flush_seen:
            frame = self.ui.frame()
            if frame:
                emit(frame)

    def rpc_message(self, message: Any) -> None:
        if not isinstance(message, list) or not message:
            return
        kind = int(message[0])
        if kind == 1 and len(message) >= 4:
            self.response(int(message[1]), message[2], message[3])
        elif kind == 2 and len(message) >= 3:
            self.notification(str(message[1]), list(message[2] or []))
        elif kind == 0 and len(message) >= 4:
            msgid = int(message[1])
            method = str(message[2])
            self._rpc([1, msgid, f"unsupported-ui-request:{method}", None])

    def command(self, payload: dict[str, Any]) -> None:
        op = str(payload.get("op", ""))
        if op == "input":
            keys = str(payload.get("keys", ""))
            if keys:
                self.request("nvim_input", [keys], "input")
        elif op == "resize":
            cols = max(2, int(payload.get("cols", self.ui.cols)))
            rows = max(2, int(payload.get("rows", self.ui.rows)))
            self.ui.resize(cols, rows)
            self.request("nvim_ui_try_resize", [cols, rows], "resize")
        elif op == "open":
            target = safe_target(self.root, str(payload.get("path", "")))
            lua = "local p=...; vim.cmd.edit(vim.fn.fnameescape(p)); return true"
            msgid = self.request(
                "nvim_exec_lua", [lua, [str(target)]], "open")
            self.pending_open[msgid] = target
        elif op == "save":
            self.request("nvim_command", ["write"], "save")
        elif op == "paste":
            text = str(payload.get("text", ""))
            if text:
                self.request("nvim_paste", [text, False, -1], "paste")
        elif op == "mouse":
            button = str(payload.get("button", "left"))
            action = str(payload.get("action", "press"))
            modifier = str(payload.get("modifier", ""))
            row = max(0, int(payload.get("row", 0)))
            col = max(0, int(payload.get("col", 0)))
            self.request(
                "nvim_input_mouse",
                [button, action, modifier, 0, row, col],
                "mouse")
        elif op == "stop":
            self.stopping = True
        elif op == "ping":
            emit({"type": "pong", "ready": self.ready})

    def start(self) -> int:
        emit({"type": "state", "state": "starting", "path": str(self.target)})
        try:
            self.nvim = subprocess.Popen(
                [self.nvim_bin, "--embed", str(self.target)],
                cwd=str(self.root),
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                bufsize=0,
            )
        except (OSError, ValueError) as exc:
            emit({"type": "state", "state": "unavailable", "error": str(exc)})
            return 127

        assert self.nvim.stdout is not None
        assert self.nvim.stderr is not None
        self.selector.register(sys.stdin.buffer, selectors.EVENT_READ, "command")
        self.selector.register(self.nvim.stdout, selectors.EVENT_READ, "rpc")
        self.selector.register(self.nvim.stderr, selectors.EVENT_READ, "stderr")

        self.request(
            "nvim_set_client_info",
            [
                "Hadalis",
                {"major": 0, "minor": 1, "patch": 0},
                "ui",
                {},
                {
                    "website": "https://github.com/llocphann/Hadalis",
                    "license": "GPL-3.0"
                }
            ],
            "client-info",
        )
        self.request(
            "nvim_ui_attach",
            [self.ui.cols, self.ui.rows, {"rgb": True, "ext_linegrid": True}],
            "attach",
        )

        while not self.stopping:
            if self.nvim.poll() is not None:
                break
            for key, _mask in self.selector.select(timeout=0.25):
                if key.data == "command":
                    raw = os.read(sys.stdin.fileno(), 65536)
                    if not raw:
                        self.stopping = True
                        break
                    self.command_buffer.extend(raw)
                    while b"\n" in self.command_buffer:
                        raw_line, _, remainder = self.command_buffer.partition(b"\n")
                        self.command_buffer = bytearray(remainder)
                        line = raw_line.decode("utf-8", "replace").strip()
                        if not line:
                            continue
                        try:
                            payload = json.loads(line)
                            if isinstance(payload, dict):
                                self.command(payload)
                        except (json.JSONDecodeError, ValueError, TypeError) as exc:
                            emit({"type": "command-error", "error": str(exc)})
                elif key.data == "rpc":
                    chunk = os.read(self.nvim.stdout.fileno(), 65536)
                    if not chunk:
                        self.stopping = True
                        break
                    try:
                        for message in self.decoder.feed(chunk):
                            self.rpc_message(message)
                    except (ValueError, TypeError, struct.error) as exc:
                        emit({"type": "state", "state": "error", "error": f"rpc-decode:{exc}"})
                        self.stopping = True
                        break
                elif key.data == "stderr":
                    chunk = os.read(self.nvim.stderr.fileno(), 65536)
                    if chunk:
                        emit({"type": "stderr", "text": chunk.decode("utf-8", "replace")})

        code = self.nvim.poll()
        if code is None:
            self.nvim.terminate()
            try:
                code = self.nvim.wait(timeout=1.5)
            except subprocess.TimeoutExpired:
                self.nvim.kill()
                code = self.nvim.wait(timeout=1.0)
        emit({"type": "state", "state": "stopped", "exitCode": int(code or 0)})
        return int(code or 0)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--file", required=True)
    parser.add_argument("--cols", type=int, default=80)
    parser.add_argument("--rows", type=int, default=24)
    parser.add_argument("--nvim", default="nvim")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        emit({"type": "state", "state": "unavailable", "error": "shell-root-missing"})
        return 2
    try:
        target = safe_target(root, args.file)
    except ValueError as exc:
        emit({"type": "state", "state": "unavailable", "error": str(exc)})
        return 2

    bridge = Bridge(root, target, args.cols, args.rows, args.nvim)

    def stop_handler(_signum: int, _frame: Any) -> None:
        bridge.stopping = True

    signal.signal(signal.SIGTERM, stop_handler)
    signal.signal(signal.SIGINT, stop_handler)
    return bridge.start()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
