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

    if "scheduleWindowsUpdate(currentList, false)" not in text:
        raise AssertionError("focus-only events must skip fresh order comparisons")
    if "function scheduleWindowsUpdate(newWindowsList, orderMayChange)" not in text:
        raise AssertionError("window batcher must expose the order-change hint")
    if "if (orderMayChange !== false)" not in text:
        raise AssertionError("order comparison must be gated by the event hint")

    # Workspace snapshots in current niri already carry active_window_id.
    # Never overwrite that fresh compositor value with a stale cached one; the
    # cache is only a compatibility bridge for older snapshots lacking it.
    for needle in (
        "if (ws.active_window_id === undefined",
        "&& oldWs && oldWs.active_window_id !== undefined)",
        "newWorkspaces[ws.id].active_window_id = oldWs.active_window_id",
    ):
        if needle not in text:
            raise AssertionError(f"workspace active-window snapshot contract missing: {needle}")

    if "if (oldWs && oldWs.active_window_id !== undefined)" in text:
        raise AssertionError("fresh workspace active_window_id must not be overwritten unconditionally")

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
