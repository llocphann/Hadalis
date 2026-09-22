#!/usr/bin/env python3
"""Guard in-content Settings search, stable selection geometry and group chevrons."""

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
for path, source in (("Window", window), ("Overlay", overlay)):
    for token in (
        "readonly property Item navButton: navBtn",
        "var btn = item.navButton;",
        "btn.mapToItem(navCol, 0, 0).y;",
        "anchors.verticalCenter: parent.verticalCenter",
        "function toggleNavGroup(",
        "onYChanged: Qt.callLater(sharedNavIndicator.updatePosition)",
    ):
        assert token in source, f"{path}: nav alignment contract missing {token}"
    assert "item.children[1]" not in source, f"{path}: positional child lookup returned"
    assert 'navPageOrder: visibleNavItems.filter' not in source, (
        f"{path}: collapsed groups must remain keyboard-reachable"
    )

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
assert "layoutSchemaVersion: 8" in arrangement
assert "sourceVersion < 8 && untouchedStock" in arrangement
assert "owner.get(page)" in arrangement
assert "seen.has(page)" in arrangement

print("Settings inline search, geometry and v8 navigation migration: PASS")
