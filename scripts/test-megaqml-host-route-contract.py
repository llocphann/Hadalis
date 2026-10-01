#!/usr/bin/env python3
"""Source-only real host wiring preflight; NO Qt runtime or vendor operations.

Inspects actual Material/ii, Abyss overlay, SettingsFocus, independent Waffle
host/loader routes and the current read-only pages. Does NOT prove rendering.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
read = lambda name: (root / name).read_text(encoding="utf-8")

def require(path, *markers):
    source = read(path)
    for marker in markers:
        assert marker in source, (path, marker)
    return source

data = require(
    "modules/settings/SettingsPageRegistryData.qml",
    'key:"cloud-storage"',
    'component:"modules/settings/CloudStorageConfig.qml"',
    '[24, 7, 6, 35, 36]', '[24, 7, 6, 36]')
assert data.count('key:"cloud-storage"') == 1

registry = require(
    "modules/settings/SettingsPageRegistry.qml",
    "if (index === 36) return true",
    "function navigateToKey", "root.navigateRequested(")
assert registry.index("if (index === 36) return true") < registry.index(
    "if (root.abyssFamily)")

# Verify the actual three Material host presentations (not inert widget
# stubs) all consume the single registry and route to SettingsPageHost.
for path, pages, selection in (
    ("settings.qml", "root.pages", "root.currentPage"),
    ("modules/settings/SettingsOverlay.qml", "root.overlayPages",
     "root.overlayCurrentPage"),
    ("modules/settings/SettingsFocus.qml", "root.pages", "root.currentPage"),
):
    require(path, "SettingsPageRegistry.pages.map",
            "Quickshell.shellPath(p.component)",
            "SettingsPageHost {", "pages: " + pages,
            "requestedIndex: " + selection,
            "activateSettingsSearchSection")

# The actual host controls Loader residency. Source-level checks cannot
# prove animation visibility or side effects from other production services.
require("modules/settings/SettingsPageHost.qml",
        "required property var pages", "source: root._sourceFor(index)",
        "active: false", "visible: active &&",
        "onStatusChanged: root._handleStatus(index, status)")

waffle = require(
    "waffleSettings.qml", 'key: "cloud-storage"',
    "modules/waffle/settings/pages/WCloudStoragePage.qml",
    "pages: root.pages")
assert waffle.count('key: "cloud-storage"') == 1
require("modules/waffle/settings/WSettingsContent.qml",
        '"cloud-storage"',
        "source: root.pages[index].component",
        "onLoaded: if (index === 19) root.applyPendingCloudSection()",
        "visible: index === root.currentPage && status === Loader.Ready",
        "activateSettingsSearchSection(section)")

require("services/deferred/qmldir",
        "singleton CloudStorageService 1.0 CloudStorageService.qml")
service = require(
    "services/deferred/CloudStorageService.qml",
    "readonly property bool connected: false",
    "readonly property bool liveAuthQualified: false",
    'operation: "detect"')
for path, expected_index in (
    ("modules/settings/CloudStorageConfig.qml", 36),
    ("modules/waffle/settings/pages/WCloudStoragePage.qml", 19),
):
    page = require(path, f"settingsPageIndex: {expected_index}",
                   "CloudStorageService.registerConsumer()",
                   "CloudStorageService.unregisterConsumer()",
                   "onVisibleChanged: root.syncLease()")
    for unsafe in ('"auth_begin"', "mutationProc", "mega-login email"):
        assert unsafe not in page
for unsafe in ('"auth_begin"', "mutationProc", "mega-login email"):
    assert unsafe not in service

print("PASS MegaQML real Settings host route source-only preflight")
