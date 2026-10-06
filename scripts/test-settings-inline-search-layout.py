#!/usr/bin/env python3
"""Guard in-content Settings search and flat palette-tinted navigation."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


shared = read("modules/common/widgets/SettingsLiveSearchResults.qml")
qmldir = read("modules/common/widgets/qmldir")
assert "SettingsLiveSearchResults 1.0 SettingsLiveSearchResults.qml" in qmldir
for token in (
    "readonly property bool searching:",
    "signal activated(var entry)",
    "signal closeRequested()",
    "function focusResults()",
    "function activateCurrent()",
    "onCountChanged: currentIndex = count > 0 ? 0 : -1",
    "text: Translation.tr(\"Search results\")",
    "text: Translation.tr(\"No results found\")",
):
    assert token in shared, f"shared live search lost {token}"

for path, query, results, view, host, entry in (
    ("settings.qml", "settingsSearchText", "settingsSearchResults",
     "settingsLiveSearch", "pagesStack", "openSearchResult"),
    ("modules/settings/SettingsOverlay.qml", "overlaySearchText",
     "overlaySearchResults", "overlayLiveSearch", "overlayPagesHost",
     "openOverlaySearchResult"),
    ("modules/settings/SettingsFocus.qml", "searchText",
     "searchResults", "focusLiveSearch", "pageHost", "openSearchResult"),
):
    source = read(path)
    for token in (
        "SettingsLiveSearchResults {",
        f"id: {view}",
        f"query: root.{query}",
        f"results: root.{results}",
        f"{view}.focusResults()",
        f"{view}.activateCurrent()",
        f"onActivated: entry => root.{entry}(entry)",
    ):
        assert token in source, f"{path}: live content contract missing {token}"
    assert "onCloseRequested:" in source
    assert f"id: {host}" in source

window = read("settings.qml")
overlay = read("modules/settings/SettingsOverlay.qml")
focus = read("modules/settings/SettingsFocus.qml")
waffle = read("modules/waffle/settings/WSettingsContent.qml")
for path, source, order_token in (
    ("Window", window, "SettingsPageRegistry.navigationPageIndexes(root.easyMode)"),
    ("Overlay", overlay, "SettingsPageRegistry.navigationPageIndexes(false)"),
):
    assert order_token in source, f"{path}: flat navigation order missing {order_token}"
    for token in (
        "readonly property var navPageOrder: visibleNavItems.map",
        "spacing: SettingsMaterialPreset.navItemSpacing",
        "implicitHeight: SettingsMaterialPreset.navItemHeight",
        "buttonRadius: Math.min(width, height) / 2",
        "SettingsMaterialPreset.navigationIconColor(",
        "colBackgroundToggled: Appearance.colors.colPrimaryContainer",
    ):
        assert token in source, f"{path}: flat navigation contract missing {token}"
    for token in (
        'type: "header"',
        "function toggleNavGroup(",
        "groupIsExpanded",
        "groupPageIndices",
        "sharedNavIndicator",
    ):
        assert token not in source, f"{path}: grouped navigation returned: {token}"


for token in ("settingsSearchOverlay", "searchResultsCard", "resultsListView",
              "id: noResultsCard"):
    assert token not in window, f"Window still shows floating search: {token}"
for token in ("overlaySearchResultsOverlay", "overlaySearchResultsCard",
              "overlayResultsList", "searchDebounceTimer"):
    assert token not in overlay, f"Overlay still shows floating/stale search: {token}"
assert "root.recomputeOverlaySearchResults()" in overlay
for token in ("id: resultsCard", "id: noResultsPill"):
    assert token not in focus, f"Focus still overlays results: {token}"

for token in ("id: waffleLiveSearchView", "id: waffleLiveResults",
              "visible: root.searchText.trim().length === 0",
              "text: Translation.tr(\"Search results\")",
              "text: Translation.tr(\"No results found\")"):
    assert token in waffle, f"Waffle in-content search missing {token}"
assert "id: searchResultsDropdown" not in waffle
assert "searchResultsList" not in waffle

arrangement = read("modules/settings/SettingsArrangement.qml")
assert "layoutSchemaVersion: 11" in arrangement
assert "sourceVersion < 8 && untouchedStock" in arrangement
assert "owner.get(page)" in arrangement
assert "seen.has(page)" in arrangement

print("Settings inline search, geometry and v11 navigation migration: PASS")
