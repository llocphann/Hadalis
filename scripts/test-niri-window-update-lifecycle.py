#!/usr/bin/env python3
"""Regression contract for Niri window-update batching hot paths."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "services/NiriService.qml"


def main() -> int:
    text = SERVICE.read_text(encoding="utf-8")

    timer = re.search(
        r"Timer \{\s*\n\s*id: windowsUpdateTimer(?P<body>.*?)\n\s*\}\n\n"
        r"\s*function scheduleWindowsUpdate",
        text,
        flags=re.S,
    )
    if not timer:
        raise AssertionError("could not isolate windowsUpdateTimer")

    body = timer.group("body")
    required = (
        "const orderChanged = _windowOrderDirty",
        "const nextWindows = orderChanged",
        "? sortWindowsByLayout(_pendingWindows)",
        ": _pendingWindows",
        "activeWindow = nextWindows.find(window => window.is_focused) ?? null",
        "if (orderChanged)",
        "windowOrderChanged()",
    )
    for needle in required:
        if needle not in body:
            raise AssertionError(f"Niri window batcher missing contract: {needle}")

    unconditional = re.search(
        r"if \(_windowsDirty\) \{\s*\n\s*const nextWindows = sortWindowsByLayout",
        body,
    )
    if unconditional:
        raise AssertionError("focus/metadata-only batches must not unconditionally sort")

    # Order dirtiness must still cover membership and spatial placement.
    for needle in (
        "_windowOrderDiffers(",
        "previousWindows.length !== nextWindows.length",
        "previous.workspace_id !== window.workspace_id",
        "previousColumn !== nextColumn || previousRow !== nextRow",
    ):
        if needle not in text:
            raise AssertionError(f"order invalidation contract missing: {needle}")

    print("niri window update lifecycle contract: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
