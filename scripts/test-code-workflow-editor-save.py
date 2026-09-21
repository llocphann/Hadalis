#!/usr/bin/env python3
"""Regression test for Code Workflow's atomic editor writer."""

from __future__ import annotations

import hashlib
from pathlib import Path
import stat
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts" / "code-workflow-editor-save.py"


def md5(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(HELPER), *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp) / "shell"
    root.mkdir()
    target = root / "Widget.qml"
    target.write_text("old\n", encoding="utf-8")
    target.chmod(0o640)

    staged = Path(tmp) / "draft.tmp"
    staged.write_text("new\n", encoding="utf-8")
    result = run(str(root), str(target), md5("old\n"), str(staged))
    assert result.returncode == 0, result.stderr
    assert target.read_text(encoding="utf-8") == "new\n"
    assert stat.S_IMODE(target.stat().st_mode) == 0o640
    assert not staged.exists()

    target.write_text("external\n", encoding="utf-8")
    staged.write_text("draft\n", encoding="utf-8")
    result = run(str(root), str(target), md5("new\n"), str(staged))
    assert result.returncode == 3, result.stderr
    assert target.read_text(encoding="utf-8") == "external\n"
    assert not staged.exists()

    outside = Path(tmp) / "outside.qml"
    outside.write_text("outside\n", encoding="utf-8")
    staged.write_text("bad\n", encoding="utf-8")
    result = run(str(root), str(outside), md5("outside\n"), str(staged))
    assert result.returncode == 2, result.stderr
    assert outside.read_text(encoding="utf-8") == "outside\n"

print("ok - Code Workflow atomic editor save")
