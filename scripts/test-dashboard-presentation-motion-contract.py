#!/usr/bin/env python3
"""Regression contract for Dashboard entry slide and Dashboard/Search fade-through."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
dashboard = (ROOT / "modules/overview/OverviewDashboard.qml").read_text(encoding="utf-8")
search = (ROOT / "modules/overview/SearchWidget.qml").read_text(encoding="utf-8")

failures = []

def require(source: str, token: str, label: str) -> None:
    if token not in source:
        failures.append(f"{label}: missing {token!r}")

def forbid(source: str, token: str, label: str) -> None:
    if token in source:
        failures.append(f"{label}: forbidden {token!r}")

# First presentation must paint a closed frame before starting the same immutable
# slide used for later Dashboard entry/retraction.
for token in (
    "property bool _hasPresentedOnce: false",
    "id: firstRevealFrameTimer",
    "interval: 16",
    "root.revealProgress = 0",
    "root.revealProgress = 1",
    "(1 - root.revealProgress) * dashContainer.height",
    "duration: SurfaceMotion.duration",
    "easing.type: SurfaceMotion.easingType",
):
    require(dashboard, token, "Dashboard first-entry slide")

# Search waits for the debounced model, so mode change cannot fade into an empty
# list and then retarget the container height a second time.
for token in (
    "readonly property bool resultsReady:",
    "!searchDebounceTimer.running",
    "root.debouncedSearchText === root.searchingText",
):
    require(search, token, "Search readiness")
for token in (
    "readonly property bool presentingSearch:",
    "root.searching && searchWidget.resultsReady",
    "height: root.presentingSearch",
):
    require(dashboard, token, "Dashboard/Search readiness")

# Internal mode switching is a compact fade-through, not the old broad 50/50
# linear crossfade and not a slide between two separate surfaces.
for token in (
    "readonly property real dashboardOpacity:",
    "readonly property real searchResultsOpacity:",
    "function _smooth01(value): real",
    "opacity: root.dashboardOpacity",
    "resultsOpacity: root.searchResultsOpacity",
    "duration: root.modeTransitionDuration",
    "easing.type: Easing.InOutCubic",
):
    require(dashboard, token, "Dashboard/Search fade-through")
forbid(
    dashboard,
    "resultsOpacity: 1 - root.dashboardProgress",
    "Dashboard/Search fade-through",
)

if failures:
    print("Dashboard presentation motion contract regression(s):")
    for failure in failures:
        print("  - " + failure)
    raise SystemExit(1)

print("Dashboard presentation motion contract: PASS")
