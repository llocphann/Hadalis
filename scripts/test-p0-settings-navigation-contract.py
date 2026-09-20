#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
registry = (ROOT / "modules/settings/SettingsPageRegistry.qml").read_text(encoding="utf-8")
data = (ROOT / "modules/settings/SettingsPageRegistryData.qml").read_text(encoding="utf-8")
bar = (ROOT / "modules/settings/BarConfig.qml").read_text(encoding="utf-8")
quick = (ROOT / "modules/settings/QuickConfig.qml").read_text(encoding="utf-8")
system = (ROOT / "modules/settings/GeneralConfigCore.qml").read_text(encoding="utf-8")

def require(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise SystemExit(f"FAIL: P0 settings contract: {message}: {needle}")

def forbid(text: str, needle: str, message: str) -> None:
    if needle in text:
        raise SystemExit(f"FAIL: P0 settings contract: {message}: {needle}")

# Public Settings pages are Hug-only at source. Compatibility belongs in
# persisted-config migration, not in post-construction recursive UI pruning.
for retired_facade in ("BarConfigHugOnly.qml", "QuickConfigHugOnly.qml"):
    forbid(registry, retired_facade,
           "Settings registry still routes through a retired Hug-only facade")
    if (ROOT / "modules/settings" / retired_facade).exists():
        raise SystemExit(f"FAIL: P0 settings contract: retired facade still exists: {retired_facade}")
require(data, 'component: "modules/settings/QuickConfig.qml"',
        "Quick Settings no longer routes directly to its canonical source")
require(data, 'component: "modules/settings/BarConfig.qml"',
        "Bar Settings no longer routes directly to its canonical source")
require(registry, 'Config.setNestedValue("bar.cornerStyle", 0)',
        "legacy Bar cornerStyle is no longer normalized to Hug")

# The canonical Bar page owns the Screen Edge controls required by the v1.0 gate.
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

# Retired Bar style controls are absent at source; there is no Timer(0) pruning pass.
forbid(quick, 'Translation.tr("Bar style")',
       "Quick Settings still contains the retired Bar style card")
forbid(quick, 'Config.options?.bar?.cornerStyle',
       "Quick Settings still reads retired Bar cornerStyle state")
forbid(bar, 'Translation.tr("Corner style")',
       "Bar Settings still contains the retired corner-style selector")
forbid(bar, 'Translation.tr("Float shadow")',
       "Bar Settings still contains the retired float-shadow toggle")
forbid(bar, 'Translation.tr("Show background")',
       "Bar Settings still contains the retired transparent-background toggle")

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
