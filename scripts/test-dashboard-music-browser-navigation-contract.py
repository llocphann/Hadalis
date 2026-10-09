#!/usr/bin/env python3
"""Static guards for dashboard navigation, music queue and Screen Edge source ownership.

Native Niri/Quickshell gesture, audio and focus acceptance remains separate.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding="utf-8")
music = read("modules/dashboard/DashboardMusic.qml")
pages = read("modules/dashboard/DashboardContent.qml")
dashboard = read("modules/dashboard/Dashboard.qml")
header = read("modules/dashboard/DashboardHeader.qml")
weather = read("modules/bar/weather/WeatherBar.qml")
module = read("modules/abyss/bar/AbyssBarModule.qml")
popup = read("modules/bar/StyledPopup.qml")

def expect(source, *tokens):
    for token in tokens:
        assert token in source, f"missing contract token: {token}"

expect(music, 'visible: !root.browseFolderOnly', 'visible: !root.browseGenreOnly',
       'function restoreBrowserColumns(): bool', 'sourceMode = ""',
       'function acceptsPageWheel(x, y): bool',
       'objectName: "musicPlayAll"', 'objectName: "musicPlaySelection"',
       'root.backend.playQueue(root.allResultTracks, 0',
       'root.backend.playQueue(root.selectedTracks, 0',
       'objectName: "musicPlaybackAndQueue"', 'objectName: "musicQueuePanel"',
       'objectName: "musicQueueList"', 'onDoubleClicked: root.backend.playTrackAt(index)',
       'objectName: "musicEqualizer"')
expect(pages, 'function handleEscape(): bool', 'dashboardCanvas.cancelEditMode()',
       'musicPage.item?.restoreBrowserColumns()', 'orientation: Qt.Horizontal',
       'orientation: Qt.Vertical', 'acceptsPageWheel(local.x, local.y)')
expect(dashboard, 'contentLoader.item?.handleEscape()', 'event.accepted = true')
expect(header, 'id: uptime', 'anchors.left: parent.left',
       'id: actions', 'anchors.right: parent.right', 'orientation: Qt.Vertical')
expect(module, 'popup.moduleHoverActive = root.hovered',
       'root.companionPopup.moduleHoverActive = hovered')
expect(popup, 'property bool moduleHoverActive: false',
       'root.moduleHoverActive || root._anchorHover.hovered || root.popupHovered')
assert "openSidebarRight" not in weather, "Weather click still opens Sidebar Right"
assert "sidebarRightRequestedWidget" not in weather, "Weather still routes to Sidebar Right"
print("Dashboard Music, Escape, wheel and hover source contracts: PASS")
