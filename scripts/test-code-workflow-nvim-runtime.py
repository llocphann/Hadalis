#!/usr/bin/env python3
"""Runtime smoke test for the Code Workflow Neovim embed bridge.

The test is hermetic with respect to the user's Neovim config by pointing XDG
state/config/data/cache at a temporary directory. It exits successfully with a
SKIP message when nvim is not installed.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import tempfile
import time


ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / "scripts" / "code-workflow-nvim-bridge.py"
NVIM = shutil.which("nvim")

if not NVIM:
    print("SKIP - nvim is not installed")
    raise SystemExit(0)


def send(proc: subprocess.Popen[str], payload: dict) -> None:
    assert proc.stdin is not None
    proc.stdin.write(json.dumps(payload, separators=(",", ":")) + "\n")
    proc.stdin.flush()


def wait_message(
    proc: subprocess.Popen[str],
    predicate,
    timeout: float = 8.0,
):
    assert proc.stdout is not None
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + timeout
    seen = []
    while time.monotonic() < deadline:
        remaining = max(0.0, deadline - time.monotonic())
        events = selector.select(timeout=min(0.25, remaining))
        if not events:
            if proc.poll() is not None:
                break
            continue
        line = proc.stdout.readline()
        if not line:
            break
        message = json.loads(line)
        seen.append(message)
        if predicate(message):
            return message
    stderr = ""
    if proc.stderr is not None and proc.poll() is not None:
        stderr = proc.stderr.read()
    raise AssertionError(
        f"timed out waiting for bridge message; seen={seen[-8:]} stderr={stderr!r}"
    )


with tempfile.TemporaryDirectory() as tmp:
    temp = Path(tmp)
    shell_root = temp / "shell"
    shell_root.mkdir()
    source = shell_root / "Widget.qml"
    source.write_text("Item {}\n", encoding="utf-8")

    env = dict(os.environ)
    for name in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"):
        path = temp / name.lower()
        path.mkdir()
        env[name] = str(path)
    env["HOME"] = str(temp)

    proc = subprocess.Popen(
        [
            sys.executable,
            str(BRIDGE),
            "--root", str(shell_root),
            "--file", str(source),
            "--cols", "40",
            "--rows", "8",
            "--nvim", NVIM,
        ],
        cwd=shell_root,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        env=env,
    )
    try:
        ready = wait_message(
            proc,
            lambda message:
                message.get("type") == "state"
                and message.get("state") == "ready",
        )
        assert ready["cols"] == 40
        assert ready["rows"] == 8

        first_frame = wait_message(
            proc,
            lambda message:
                message.get("type") == "frame"
                and message.get("cols") == 40
                and message.get("rows") == 8,
        )
        assert isinstance(first_frame.get("dirtyRows"), list)
        visible_text = "".join(
            str(cell[0])
            for row in first_frame["dirtyRows"]
            for cell in row.get("cells", [])
            if isinstance(cell, list) and cell
        )
        assert visible_text.strip(), (
            "Neovim attached but its first redraw frame contained no visible cells"
        )

        send(proc, {"op": "input", "keys": "gg0iHELLO"})
        modified = wait_message(
            proc,
            lambda message:
                message.get("type") == "buffer"
                and message.get("modified") is True,
        )
        assert Path(modified["path"]).resolve() == source.resolve()

        send(proc, {"op": "input", "keys": "<Esc>:w<CR>"})
        saved = wait_message(
            proc,
            lambda message:
                message.get("type") == "buffer"
                and message.get("modified") is False,
        )
        assert Path(saved["path"]).resolve() == source.resolve()
        deadline = time.monotonic() + 8.0
        while time.monotonic() < deadline:
            if source.read_text(encoding="utf-8").startswith("HELLO"):
                break
            if proc.poll() is not None:
                break
            time.sleep(0.05)
        assert source.read_text(encoding="utf-8").startswith("HELLO")

        # GUI clipboard paste uses nvim_paste(), not mapped/raw nvim_input().
        send(proc, {"op": "input", "keys": "Go"})
        send(proc, {"op": "paste", "text": "PASTED\nBLOCK"})
        send(proc, {"op": "input", "keys": "<Esc>:w<CR>"})
        deadline = time.monotonic() + 8.0
        while time.monotonic() < deadline:
            written = source.read_text(encoding="utf-8")
            if "PASTED\nBLOCK" in written:
                break
            if proc.poll() is not None:
                break
            time.sleep(0.05)
        assert "PASTED\nBLOCK" in source.read_text(encoding="utf-8")

        send(proc, {"op": "resize", "cols": 52, "rows": 10})
        resized = wait_message(
            proc,
            lambda message:
                message.get("type") == "frame"
                and message.get("cols") == 52
                and message.get("rows") == 10,
        )
        assert resized["cols"] == 52 and resized["rows"] == 10

        send(proc, {"op": "stop"})
        proc.wait(timeout=5.0)
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2.0)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=2.0)

print("ok - Code Workflow Neovim embed runtime")
