#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
config = (ROOT / "modules/common/Config.qml").read_text(encoding="utf-8")
defaults = (ROOT / "defaults/config.json").read_text(encoding="utf-8")
settings = (ROOT / "modules/settings/GeneralConfigCore.qml").read_text(encoding="utf-8")
lock = (ROOT / "modules/lock/Lock.qml").read_text(encoding="utf-8")
migration = (ROOT / "sdata/migrations/052-lock-provider.sh").read_text(encoding="utf-8")

def require(text: str, token: str, message: str) -> None:
    if token not in text:
        raise SystemExit(f"lock provider contract failed: {message}")

require(config, 'property string provider: "quickshell"',
        "typed config must expose the neutral lock provider")
require(defaults, '"provider": "quickshell"',
        "fresh installs must default to the Hadalis/Quickshell locker")

for provider in ("quickshell", "swaylock", "hyprlock"):
    require(settings, f'value: "{provider}"',
            f"Settings must preserve the {provider} lock path")

require(settings, 'Config.setNestedValue("lock.provider", newValue)',
        "provider selection must persist through Config")
require(lock, "function activateConfiguredLock(): void",
        "lock requests must route through provider selection")
require(lock, 'provider === "swaylock"',
        "swaylock provider must remain executable")
require(lock, 'provider === "hyprlock"',
        "hyprlock provider must remain executable on Niri")
require(lock, "root.activateQuickshellLock()",
        "missing external providers must fail safe to the built-in lock")
require(lock, "root.activateConfiguredLock()",
        "startup and IPC lock requests must share provider routing")

require(migration, 'MIGRATION_ID="052-lock-provider"',
        "legacy preference migration must remain append-only")
require(migration, '.lock.useHyprlock == true then "hyprlock"',
        "legacy true preference must survive as hyprlock")
require(migration, 'del(.lock.useHyprlock)',
        "legacy key must be removed after conversion")

for forbidden in ("Quickshell.Hyprland", "CompositorService.isHyprland", "hyprctl"):
    if forbidden in lock:
        raise SystemExit(
            "lock provider contract failed: external locker support must not "
            f"restore a compositor backend ({forbidden})"
        )

print("lock provider Niri contract: ok")
