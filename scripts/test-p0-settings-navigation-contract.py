#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
registry = (ROOT / "modules/settings/SettingsPageRegistry.qml").read_text(encoding="utf-8")
data = (ROOT / "modules/settings/SettingsPageRegistryData.qml").read_text(encoding="utf-8")
bar = (ROOT / "modules/settings/BarConfigHugOnly.qml").read_text(encoding="utf-8")
quick = (ROOT / "modules/settings/QuickConfigHugOnly.qml").read_text(encoding="utf-8")
system = (ROOT / "modules/settings/GeneralConfigCore.qml").read_text(encoding="utf-8")

def require(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise SystemExit(f"FAIL: P0 settings contract: {message}: {needle}")

def forbid(text: str, needle: str, message: str) -> None:
    if needle in text:
        raise SystemExit(f"FAIL: P0 settings contract: {message}: {needle}")

# Public Settings routes must use the supported Hug-only facades, while legacy
# implementation files remain loadable only behind those compatibility facades.
require(registry, 'component: "modules/settings/QuickConfigHugOnly.qml"',
        "Quick Settings no longer routes through the Hug-only facade")
require(registry, 'component: "modules/settings/BarConfigHugOnly.qml"',
        "Bar Settings no longer routes through the Hug-only facade")
require(registry, 'Config.setNestedValue("bar.cornerStyle", 0)',
        "legacy Bar cornerStyle is no longer normalized to Hug")

# The public Bar facade owns the Screen Edge controls required by the v1.0 gate.
for needle in [
    'title: Translation.tr("Screen Edge")',
    'text: Translation.tr("Screen edge width (px)")',
    'Config.setNestedValue("appearance.screenEdge.width", value)',
    'text: Translation.tr("Screen edge shadow")',
    '"appearance.screenEdge.physicalShadow.enabled"',
    '"appearance.screenEdge.physicalShadow.size"',
    '"appearance.screenEdge.physicalShadow.opacity"',
]:
    require(bar, needle, "public Bar Settings lost a Screen Edge control")

# Search must be useful before lazy page materialization and must not advertise
# retired Float/Rectangle corner-style controls that the public facade hides.
for needle in [
    'section: Translation.tr("Screen Edge")',
    'label: Translation.tr("Screen edge width (px)")',
    'label: Translation.tr("Screen edge shadow")',
    'description: Translation.tr("Configure Screen Edge and connected surface shadows")',
]:
    require(data, needle, "static Settings search lost Screen Edge discoverability")
forbid(data, 'label: Translation.tr("Corner style")',
       "static search still exposes the retired corner-style selector")
forbid(data, 'description: Translation.tr("Bar corner style: hug, float or rectangle")',
       "static search still describes retired Float/Rectangle Bar surfaces")

# Quick Settings must continue hiding its retired Bar style card.
require(quick, 'Translation.tr("Bar style")',
        "Quick Settings Hug facade lost its retired-control filter")
require(quick, 'item.visible = false',
        "Quick Settings no longer hides the retired Bar style card")
forbid(quick, 'opacity: root._hugUiReady ? 1 : 0',
       "Quick Settings must not hide the whole page behind a zero-delay compatibility timer")
forbid(quick, 'property bool _hugUiReady:',
       "Quick Settings retained the blank-page readiness gate")

# Fan Control must remain reachable from the real System page and static search.
require(system, '{ displayName: Translation.tr("Fan Control"), icon: "mode_fan", value: "fan" }',
        "System task navigator lost Fan Control")
require(system, 'settingsTaskSection: "fan"',
        "System page lost the Fan Control section")
require(system, 'ThinkFanService.applyProfile(',
        "Fan Control no longer uses the shared ThinkFanService backend")
require(data, 'section: Translation.tr("Fan Control")',
        "static Settings search lost Fan Control")
require(data, 'keywords: ["fan", "fan control", "thinkfan", "thermal", "cooling", "rpm", "temperature", "system"]',
        "Fan Control search keywords drifted")

print("PASS: P0 Settings routes, Screen Edge discoverability and Fan Control ownership")
