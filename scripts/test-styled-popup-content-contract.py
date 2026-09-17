#!/usr/bin/env python3
"""Guard StyledPopup's Item-only default content contract.

StyledPopup declares `default property Item contentItem`. Non-visual QML objects such as
Connections or Timer therefore cannot be direct children of a StyledPopup root: QML
will try to assign them to contentItem and reject the entire type graph at startup.
Keep such helpers inside the popup's content Item (where Item.data accepts QtObject).
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT_RE = re.compile(r"^\s*StyledPopup\s*\{")
NON_VISUAL_RE = re.compile(
    r"^\s*(Connections|Timer|Binding|Component|QtObject|Instantiator)\s*\{"
)


def tracked_qml_files() -> list[Path]:
    raw = subprocess.check_output(["git", "ls-files", "-z", "--", "*.qml"])
    return [Path(name) for name in raw.decode().split("\0") if name]


def brace_delta(line: str, state: dict[str, object]) -> int:
    """Count structural braces while ignoring comments and quoted strings."""
    delta = 0
    i = 0
    quote = state.get("quote")
    block_comment = bool(state.get("block_comment"))
    escaped = False

    while i < len(line):
        ch = line[i]
        nxt = line[i + 1] if i + 1 < len(line) else ""

        if block_comment:
            if ch == "*" and nxt == "/":
                block_comment = False
                i += 2
                continue
            i += 1
            continue

        if quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
            i += 1
            continue

        if ch == "/" and nxt == "/":
            break
        if ch == "/" and nxt == "*":
            block_comment = True
            i += 2
            continue
        if ch in ('"', "'", "`"):
            quote = ch
            escaped = False
            i += 1
            continue
        if ch == "{":
            delta += 1
        elif ch == "}":
            delta -= 1
        i += 1

    state["quote"] = quote
    state["block_comment"] = block_comment
    return delta


def violations(path: Path) -> list[tuple[int, str]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    state: dict[str, object] = {"quote": None, "block_comment": False}
    depth = 0
    styled_root = False
    found: list[tuple[int, str]] = []

    for line_no, line in enumerate(lines, 1):
        if not styled_root and depth == 0 and ROOT_RE.match(line):
            styled_root = True

        if styled_root and depth == 1:
            match = NON_VISUAL_RE.match(line)
            if match:
                found.append((line_no, match.group(1)))

        depth += brace_delta(line, state)

        if styled_root and depth <= 0:
            break

    return found


def main() -> int:
    failures: list[str] = []
    scanned = 0

    for path in tracked_qml_files():
        text = path.read_text(encoding="utf-8")
        if "StyledPopup" not in text:
            continue
        scanned += 1
        for line_no, object_type in violations(path):
            failures.append(
                f"{path}:{line_no}: direct {object_type} child violates "
                "StyledPopup default property Item contentItem"
            )

    if failures:
        print("StyledPopup content contract failed:")
        for failure in failures:
            print(f"  - {failure}")
        print("Move non-visual helpers inside the popup content Item's data list.")
        return 1

    print(f"StyledPopup content contract passed ({scanned} candidate QML files scanned).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
