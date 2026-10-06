#!/usr/bin/env python3
"""Contract for iNiR-derived Settings task navigation inside the Abyss host."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

nav = read("modules/common/widgets/SettingsTaskNavigator.qml")
array = read("modules/common/widgets/ConfigSelectionArray.qml")
button = read("modules/common/widgets/SelectionGroupButton.qml")
page = read("modules/common/widgets/ContentPage.qml")
overlay = read("modules/settings/SettingsOverlay.qml")
embedded = read("modules/abyss/content/AbyssSettingsContent.qml")

assert 'color: Appearance.colors.colLayer1' in nav
assert 'useAbyssPillShape: false' in nav
assert 'property var searchAliases: ({})' in nav
assert 'page.settingsTaskNavigator = root' in nav
assert 'property bool useAbyssPillShape: true' in array
assert 'useAbyssPillShape: root.useAbyssPillShape' in array
assert 'waveFace: root.useAbyssPillShape && Config.options?.panelFamily === "abyss"' in button
assert 'property var settingsTaskNavigator: null' in page

# Presentation ownership is intentionally unchanged: Abyss still embeds the
# mature Settings card in its connected liquid body rather than spawning a
# detached replacement window.
assert 'parent: root.embeddedHost ?? nativeHost.item?.contentItem ?? null' in overlay
assert 'embeddedHost:' in embedded or 'embeddedHost' in embedded

print("PASS: iNiR-style task tabs retained inside the existing Abyss Settings host")
