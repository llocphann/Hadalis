#!/usr/bin/env python3
"""Regression guard for Dock iRiS body color bindings."""
from pathlib import Path

dock = (Path(__file__).resolve().parents[1] / "modules" / "dock" / "Dock.qml").read_text(encoding="utf-8")
failures = []

for token in (
    "property color surfaceColor:",
    "property color surfaceBorderColor:",
    "Behavior on surfaceColor {",
    "Behavior on surfaceBorderColor {",
    "fillColor: dockVisualBackground.surfaceColor",
    "borderColor: dockVisualBackground.surfaceBorderColor",
):
    if token not in dock:
        failures.append(f"missing {token!r}")

for token in (
    "readonly property color surfaceColor:",
    "readonly property color surfaceBorderColor:",
):
    if token in dock:
        failures.append(f"{token!r} cannot be read-only while a Behavior intercepts assignments")

if failures:
    print("Dock surface color contract regression(s):")
    for failure in failures:
        print("  - " + failure)
    raise SystemExit(1)

print("Dock surface color contract: PASS")
