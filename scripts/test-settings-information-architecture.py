#!/usr/bin/env python3
"""Regression contract for v7 intent-based Settings navigation and ownership."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(source: str, token: str, name: str) -> None:
    if token not in source:
        raise SystemExit(f"{name}: missing {token!r}")


def forbid(source: str, token: str, name: str) -> None:
    if token in source:
        raise SystemExit(f"{name}: duplicate/retired {token!r}")


def main() -> None:
    data = read("modules/settings/SettingsPageRegistryData.qml")
    registry = read("modules/settings/SettingsPageRegistry.qml")
    arrangement = read("modules/settings/SettingsArrangement.qml")
    group_block = data.split("readonly property var defaultCategories: [", 1)[1].split(
        "readonly property var _arrangement:", 1
    )[0]
    groups = [
        (label, [int(item) for item in numbers.split(",")])
        for label, numbers in re.findall(
            r'\{ label: Translation\.tr\("([^"]+)"\), pages: \[([\d, ]+)\] \}',
            group_block,
        )
    ]
    assert [name for name, _ in groups] == [
        "Home", "Appearance", "Desktop & Layout", "System",
        "Features & Services", "Advanced & Help",
    ], groups
    page_indices = [index for _, pages in groups for index in pages]
    assert len(page_indices) == len(set(page_indices)), "duplicate Material page"
    assert set(page_indices) == set(range(31)) - {18, 19, 21, 27, 28}, (
        "active Material pages must have exactly one default owner", page_indices
    )

    require(arrangement, "layoutSchemaVersion: 7", "navigation migration")
    require(arrangement, "const untouchedStock =", "navigation migration")
    require(arrangement, "SettingsPageRegistry.defaultCategories.map(", "navigation migration")
    require(arrangement, "root.save({ groups: migratedGroups, hidden: migratedHidden })",
            "custom navigation preservation")
    for token in ("function pageIndexForKey(", "function navigateToKey(",
                  "signal navigateRequested("):
        require(registry, token, "stable navigation")
    for path, slot in (
        ("settings.qml", "root.openSearchResult("),
        ("modules/settings/SettingsOverlay.qml", "root.openOverlaySearchResult("),
        ("modules/settings/SettingsFocus.qml", "root.openSearchResult("),
    ):
        source = read(path)
        require(source, "function onNavigateRequested(pageIndex, section)",
                path)
        require(source, slot, path)
        require(source, "function toggleNavGroup(", path)
        require(source, "function revealCurrentNavGroup()", path)

    waffle = read("waffleSettings.qml")
    wcontent = read("modules/waffle/settings/WSettingsContent.qml")
    wkeys = re.findall(r'key: "([^"]+)"', waffle.split("property var pages: [", 1)[1].split(
        "property int currentPage:", 1
    )[0])
    assert len(wkeys) == 19 and len(set(wkeys)) == 19, "Waffle page keys"
    wgroups = wcontent.split("readonly property var navigationGroups: [", 1)[1].split(
        "readonly property var navigationItems:", 1
    )[0]
    grouped = re.findall(r'keys: \[([^\]]+)\]', wgroups)
    grouped_keys = [item for group in grouped for item in re.findall(r'"([^"]+)"', group)]
    assert set(grouped_keys) == set(wkeys) and len(grouped_keys) == len(wkeys), (
        "Waffle groups must include every page exactly once", grouped_keys
    )
    for token in ("model: root.navigationItems",
                  "root.currentPage = navEntry.modelData.pageIndex",
                  "function revealCurrentNavGroup()"):
        require(wcontent, token, "Waffle navigation")

    quick = read("modules/settings/QuickConfig.qml")
    quick_facade = read("modules/settings/QuickConfigHugOnly.qml")
    modules = read("modules/settings/ModulesConfig.qml")
    system = read("modules/settings/GeneralConfigCore.qml")
    sidebars = read("modules/settings/SidebarsConfig.qml")
    services = read("modules/settings/ServicesConfig.qml")
    for token in ('settingsTaskSection: "screen"',
                  'Config.setNestedValue("bar.bottom"',
                  'Config.setNestedValue("bar.vertical"'):
        forbid(quick, token, "Quick ownership")
    forbid(quick_facade, "Timer {", "retired Quick compatibility")
    for path, source, token in (
        ("Modules", modules, 'Config.setNestedValue("appearance.typography.sizeScale"'),
        ("System", system, 'Config.setNestedValue("policies.ai"'),
        ("Sidebars", sidebars, 'Config.setNestedValue("policies.ai"'),
        ("Sidebars", sidebars, 'Config.setNestedValue("policies.weeb"'),
        ("Services", services, 'Config.setNestedValue("bar.modules.weather"'),
    ):
        forbid(source, token, path)
    for path, source in (("Quick", quick), ("Modules", modules),
                         ("System", system), ("Sidebars", sidebars),
                         ("Services", services)):
        require(source, "SettingsPageRegistry.navigateToKey(", path)
    require(data, "pageIndex: 4, pageName: root.pages[4].name,\n"
                  '            section: Translation.tr("Typography"),',
            "scale search destination")
    require(data, "pageIndex: 2, pageName: root.pages[2].name,\n"
                  '            section: Translation.tr("Appearance & Layout"),',
            "Bar search destination")
    print("Settings v7 information architecture, routing and ownership: OK")


if __name__ == "__main__":
    main()
