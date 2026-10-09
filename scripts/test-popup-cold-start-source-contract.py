#!/usr/bin/env python3
"""Cold startup anchor dependency contract; not native Wayland acceptance."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
popup = (root / "modules/bar/StyledPopup.qml").read_text()
runtime = (root / "scripts/test-popup-cold-start-lifecycle-runtime.py").read_text()
for token in (
    "property int _anchorTreeRevision: 0",
    "function startColdAnchorResolution(): void",
    "onParentChanged() { root.startColdAnchorResolution() }",
    "onLiquidControllerChanged() { root.refreshAnchorOwnership() }",
    "const revision = root._anchorTreeRevision",
    "function on_LiquidControllerChanged()",
    "anchorResolveRetry.stop()",
    "remaining <= 0",
    "Qt.callLater(root.startColdAnchorResolution)",
):
    assert token in popup, f"missing cold mount anchor dependency: {token}"
for token in (
    "POPUP_COLD_MOUNT_PASS", "anchor.parent = mounted",
    "mounted.liquidController = null",
    "mounted.liquidController = controller",
    "root.clicks === 0",
):
    assert token in runtime, f"missing native cold/remount test step: {token}"
print("PASS: bounded cold anchor re-resolution and remount regression source")
