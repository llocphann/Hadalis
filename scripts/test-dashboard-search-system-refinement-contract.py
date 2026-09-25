#!/usr/bin/env python3
"""Regression contract for Dashboard search crossfade and System monitor layout."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(source: str, token: str, message: str) -> None:
    if token not in source:
        raise SystemExit(message)


def forbid(source: str, token: str, message: str) -> None:
    if token in source:
        raise SystemExit(message)


search_bar = read("modules/overview/SearchBar.qml")
overview = read("modules/overview/OverviewDashboard.qml")
search = read("modules/overview/SearchWidget.qml")
system = read("modules/dashboard/DashSystem.qml")

song_start = search_bar.index("id: songRecButton")
song_end = search_bar.index("StyledToolTip {", song_start)
song_block = search_bar[song_start:song_end]

forbid(song_block, "MaterialShape {",
       "SongRec must not restore the stray custom MaterialShape geometry.")
forbid(song_block, "RotationAnimation on rotation",
       "SongRec must not create a transformed custom icon scene node.")
forbid(song_block, "contentItem:",
       "SongRec must use the shared IconToolbarButton content renderer.")
require(song_block, 'colBackgroundToggled: "transparent"',
        "SongRec running state must not paint an extra persistent face.")
require(song_block, "? Appearance.colors.colPrimary",
        "SongRec running state must remain visible through icon ink.")

require(overview, "readonly property real dashboardOpacity:",
        "Dashboard content must expose its eased crossfade opacity.")
require(overview, "1 - root._smooth01(root.searchTransitionProgress / 0.44)",
        "Dashboard crossfade must remain derived from search transition progress.")
require(overview, "opacity: root.dashboardOpacity",
        "Dashboard content must consume the eased crossfade instead of sliding away.")
forbid(overview,
       "transform: Translate { y: (1 - root.dashboardProgress) * dashboardViewport.height }",
       "Dashboard/Search transition must not use the old vertical slide.")
require(overview, "readonly property real searchResultsOpacity:",
        "Search results must expose the eased crossfade opacity.")
require(overview, "root._smooth01((root.searchTransitionProgress - 0.22) / 0.78)",
        "Search results crossfade must remain derived from search transition progress.")
require(overview, "resultsOpacity: root.searchResultsOpacity",
        "Search results must consume the eased crossfade against Dashboard content.")
require(search, "property real resultsOpacity: 1",
        "SearchWidget must expose the embedded result-layer opacity.")
require(search, "opacity: root.resultsOpacity",
        "Search results must consume the shared crossfade progress.")

for token in (
    "component MetricTile: Rectangle",
    "component StatusChip: Rectangle",
    "history: ResourceUsage.cpuUsageHistory",
    "history: ResourceUsage.memoryUsageHistory",
    "history: ResourceUsage.gpuUsageHistory",
    "Graph {",
    'label: Translation.tr("Disk")',
    "id: fanPanel",
    'text: Translation.tr("Fan control")',
    "ThinkFanService.fanRpm",
    "ThinkFanService.fanLevel",
    "StyledSwitch {",
):
    require(system, token, f"Dashboard System monitor refinement missing: {token}")
forbid(system, "component VerticalBar:",
       "Dashboard System monitor must not regress to the old three vertical meters.")

print("Dashboard search crossfade + System monitor refinement contract: OK")
