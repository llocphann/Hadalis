#!/usr/bin/env python3
"""Atomic compare-and-swap writer for Code Workflow's inline source editor."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import stat
import sys
import tempfile


EXIT_USAGE = 2
EXIT_CONFLICT = 3
EXIT_IO = 4


def digest(data: bytes) -> str:
    return hashlib.md5(data).hexdigest()


def inside(root: Path, target: Path) -> bool:
    try:
        return os.path.commonpath((str(root), str(target))) == str(root)
    except ValueError:
        return False


def fsync_dir(path: Path) -> None:
    try:
        fd = os.open(path, os.O_DIRECTORY | os.O_RDONLY)
    except OSError:
        return
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def main(argv: list[str]) -> int:
    if len(argv) != 5:
        print("usage: code-workflow-editor-save.py ROOT TARGET EXPECTED_MD5 STAGED", file=sys.stderr)
        return EXIT_USAGE

    root = Path(argv[1]).expanduser().resolve()
    target = Path(argv[2]).expanduser().resolve()
    expected = argv[3].strip().lower()
    staged = Path(argv[4]).expanduser().resolve()

    if not root.is_dir() or not inside(root, target):
        print("target-outside-shell-root", file=sys.stderr)
        return EXIT_USAGE
    if not target.is_file() or not staged.is_file():
        print("source-or-stage-missing", file=sys.stderr)
        return EXIT_IO

    try:
        current = target.read_bytes()
        if digest(current) != expected:
            print("source-conflict", file=sys.stderr)
            return EXIT_CONFLICT

        candidate = staged.read_bytes()
        target_stat = target.stat()
        temp_name = None
        with tempfile.NamedTemporaryFile(
            mode="wb",
            prefix=f".{target.name}.hadalis-editor-",
            suffix=".tmp",
            dir=target.parent,
            delete=False,
        ) as handle:
            temp_name = handle.name
            handle.write(candidate)
            handle.flush()
            os.fsync(handle.fileno())

        temp = Path(temp_name)
        os.chmod(temp, stat.S_IMODE(target_stat.st_mode))
        os.replace(temp, target)
        fsync_dir(target.parent)
        return 0
    except OSError as exc:
        print(f"io-error:{exc}", file=sys.stderr)
        return EXIT_IO
    finally:
        try:
            staged.unlink(missing_ok=True)
        except OSError:
            pass


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
